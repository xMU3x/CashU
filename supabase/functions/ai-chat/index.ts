// Supabase Edge Function: ai-chat  (حسّاب — مساعد CashU)
// المفاتيح تُقرأ من Supabase Secrets (GROQ_API_KEY + CLOUDFLARE_ACCOUNT_ID / CLOUDFLARE_API_TOKEN + GEMINI_API_KEY) ولا يوجد في التطبيق.
// النشر:  supabase secrets set GROQ_API_KEY=gsk_...   ثم   supabase functions deploy ai-chat
// يعيد {reply, actions[], panel?, suggestions?}. الدالة لا تنفّذ أي شيء: التطبيق هو اللي بينفّذ الأوامر بعد تأكيد المستخدم.
// panel وsuggestions اختياريين (التطبيق القديم بيتجاهلهم). أرقام panel بتتحسب هنا من PANELS_JSON في الـ context — مش من الموديل.
// لو مزود فشل أو اتخطّت مهلته، تكمّل تلقائيًا على اللي بعده. جوه Groq وGemini بنلف على أكتر من موديل الأول
// (كل موديل له حصة يومية منفصلة)، وبعدين ننتقل للمزود اللي بعده. الردود اللي مفيهاش أوامر بتتخزن في كاش
// (جدول ai_chat_cache، صلاحيتها ساعة) عشان تكرار نفس السؤال على نفس البيانات ما يستهلكش طلب جديد.
// الكاش بيحفظ كمان panel وsuggestions في عمود اختياري extra (شغّل supabase/ai_chat_cache_extra.sql) — من غيره الكاش
// بيشتغل زي الأول (reply بس) والبطاقات بتظهر في الردود الجديدة بس.
// وضع mode:"parse" لشاشة «اكتب اللي صرفته»: بيرجّع {"entries":[...]} (من غير كاش).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
// Groq: كل موديل له حصة يومية منفصلة في الباقة المجانية (1,000 طلب/يوم لكل موديل)، فبنلف عليهم قبل الانتقال.
const GROQ_MODELS = ["openai/gpt-oss-120b", "openai/gpt-oss-20b", "qwen/qwen3.8-27b"];
// Cloudflare: الحصة المجانية على مستوى الحساب مش لكل موديل، فمش هتفرق اللفة - موديل واحد يكفي.
const CF_MODELS = ["@cf/openai/gpt-oss-120b"];
const GEMINI_MODELS = ["gemini-2.5-flash", "gemini-2.5-flash-lite"];
const MAX_MSGS = 16;
const MAX_MSG_LEN = 1500;
const MAX_CTX = 7000;
const LIMIT_PER_HOUR = 60;
const CACHE_TTL_MS = 3600_000; // صلاحية الكاش: ساعة
// أوامر مسموحة فقط. ممنوع أي حذف/تعديل إعدادات/نسخ احتياطي/استرجاع: مش موجودين هنا فبيتفلتروا دايمًا.
const ACTIONS = new Set(["add_expense", "add_income", "add_goal", "add_to_goal", "add_loan", "open_page"]);
const EXP_CATS = new Set(["food", "shop", "transport", "bills", "health", "fun", "edu", "home", "other"]);
const INC_CATS = new Set(["salary", "free", "gift", "invest", "other_i"]);
const PAGES = new Set(["goals", "subscriptions", "loans", "assets"]);
const CMP_KEYS = new Set(["spent_month", "income_month", "spent_week"]);
const BRK_KEYS = new Set(["month", "last_month"]);

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

const sha256hex = async (s: string) => {
  const b = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, "0")).join("");
};

const SYSTEM = `You are "Hassab" (حسّاب), the personal finance assistant inside CashU, an Egyptian money-tracking app. Reply in the user's language (default Egyptian Arabic): warm, simple and to the point, like a smart friend who knows their numbers. Never sound like a formal report.

GROUND RULE: use ONLY the APP CONTEXT for any number, balance, transaction, goal, debt, budget, subscription or installment. Never invent or estimate figures. If the context does not contain what the answer needs, say the data is not in front of you and ask a short question instead.

HOW GOOD REPLIES LOOK:
- First line: the direct answer with the most important number(s), in plain digits with the currency from the context.
- Then 1-3 short lines of useful detail: the biggest category, the largest transactions, or a comparison with the previous period whenever the context allows it (this month so far vs the same days of last month; PANELS_JSON has both).
- Keep the whole reply short and skimmable: plain lines, no markdown, no headers, no bullet clutter.
- Do NOT write the follow-up question inside the reply: put it in "suggestions" instead.

PANEL (optional visual card under the reply). Send a SPEC only; the app fills in the numbers itself, so never put numbers inside panel:
- {"type":"comparison","key":"spent_month"|"income_month"|"spent_week"}  for totals of spending/income or any comparison with the previous period.
- {"type":"breakdown","key":"month"|"last_month"}  for "where does my money go" / category split.
Use only these keys, and only when PANELS_JSON in the context has them. Skip the panel for small talk or when you are asking a question.

SUGGESTIONS (optional): 2-3 very short follow-ups (under 35 characters each) written as the user would ask them, related to your reply.

CONTEXT NOTES: LAST_SALARY (if present) lets you estimate the next salary date as the same day next month - say it is an estimate. For questions about enabling bank-SMS tracking, answer only from this guide, never invent steps: Settings > «التتبع التلقائي للرسائل»: allow the SMS permission if asked, link each card/number to its account from «البطاقات والحسابات», and if the bank sends app notifications instead of SMS use the «تطبيق البنك بيبعت إشعار» panel. Messages are analysed on the device and are not stored. If asked for anything beyond this guide, say you are not sure and point to that settings page.

DOING THINGS: use actions only when the user clearly asks to DO something. When you return actions, the reply MUST start by saying the thing is prepared and needs one tap, e.g. "جهزت لك المعاملة، اضغط نفّذ عشان تتحفظ." (adapt: المعاملة / الهدف / الدين). NEVER say you cannot do something the actions below cover, and never tell the user to do it manually - prepare it as an action instead. Allowed actions (args):
- add_expense {amount:number, category: food|shop|transport|bills|health|fun|edu|home|other, note:string, account?:string (id or name)}
- add_income {amount:number, category: salary|free|gift|invest|other_i, note:string, account?:string}
- add_goal {name:string, target:number}
- add_to_goal {goal:string (goal name), amount:number}
- add_loan {dir:"owed"|"owe", person:string, amount:number, days?:number}   (owed = someone owes me, owe = I owe someone)
- open_page {page: goals|subscriptions|loans|assets}
For account: if the user mentions or hints at one (cash/كاش/نقدي = the account of kind cash; a bank or wallet name = that account) put its id or name from ACCOUNTS; otherwise omit it.
The app asks the user to confirm every action before running it. Never propose deleting data, backups, restoring, or changing settings.
If information is missing (e.g. amount), ask a short question and return no actions.
Reply ONLY with JSON: {"reply": string, "actions": [{"name": string, "args": object}], "panel"?: object, "suggestions"?: string[]} (actions may be empty).`;

const PARSE_SYSTEM = `أنت محلل مصاريف ودخل لتطبيق CashU. المستخدم كتب نص حر فيه بند أو أكتر (وجبات، مشتريات، مواصلات، مرتب...). مهمتك تفصل كل بند وتحلله.
ردّ بـ JSON فقط: {"entries":[{"type":"exp"|"inc","amount":number,"category":string,"note":string,"account":string}]}
- type: exp للمصروف (الافتراضي)، inc للدخل (قبضت/استلمت/مرتب/جاني...).
- amount: الرقم الموجود في البند فقط (حوّل الأرقام العربية ١٢٣ لإنجليزية). ممنوع تخترع مبلغ. بند من غير مبلغ يتتجاهل.
- category للمصروف: food|shop|transport|bills|health|fun|edu|home|other. للدخل: salary|free|gift|invest|other_i.
- note: اسم البند نظيف وقصير بدون المبلغ ولا اسم الحساب (مثال: «50 سجق كاش» ← note="سجق", category=food).
- account: الحساب اللي البند اتدفع منه/اتحوّل عليه، مستنتج من كلام المستخدم نفسه ومطابق لواحد من ACCOUNTS (اكتب الـ id أو الاسم زي ما هو). كاش/نقدي/cash ← حساب النوع cash. اسم بنك/محفظة/آخر أرقام الكارت ← الحساب المطابق. لو النص ما ذكرش أي حاجة تدل على حساب سيبه "" (فاضي). ممنوع تفترض حساب افتراضي.
- كل سطر/فاصلة/«و» قبل رقم = بند مستقل. لا تدمج بنود ولا تقسّم بند.
استخدم ACCOUNTS من السياق فقط.`;

type Provider = { id: string; url: string; key: string; models: string[] };

function providers(): Provider[] {
  const out: Provider[] = [];
  const groq = Deno.env.get("GROQ_API_KEY");
  if (groq) out.push({ id: "groq", key: groq, url: "https://api.groq.com/openai/v1/chat/completions", models: GROQ_MODELS });
  const account = Deno.env.get("CLOUDFLARE_ACCOUNT_ID");
  const cf = Deno.env.get("CLOUDFLARE_API_TOKEN");
  if (account && /^[a-f0-9]{32}$/i.test(account) && cf) {
    out.push({
      id: "cloudflare", key: cf,
      url: `https://api.cloudflare.com/client/v4/accounts/${account}/ai/v1/chat/completions`,
      models: CF_MODELS,
    });
  }
  const gemini = Deno.env.get("GEMINI_API_KEY");
  if (gemini) out.push({ id: "gemini", key: gemini, url: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions", models: GEMINI_MODELS });
  return out;
}

// ------------------------------------------------------------------ أدوات تنظيف
// يستخرج JSON حتى لو الموديل لفّه بـ ``` أو كتب كلام قبله/بعده. null = نص عادي.
function extractJson(raw: string): any | null {
  const s = raw.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "").trim();
  try { return JSON.parse(s); } catch { /* نكمل */ }
  const a = s.indexOf("{"), b = s.lastIndexOf("}");
  if (a >= 0 && b > a) {
    try { return JSON.parse(s.slice(a, b + 1)); } catch { /* نكمل */ }
  }
  return null;
}

const num = (v: unknown): number => {
  if (typeof v === "number") return Number.isFinite(v) ? v : NaN;
  if (typeof v === "string") {
    const t = v.replace(/[٠-٩]/g, (d) => String("٠١٢٣٤٥٦٧٨٩".indexOf(d))).replace(/,/g, ".").replace(/[^\d.\-]/g, "");
    const n = parseFloat(t);
    return Number.isFinite(n) ? n : NaN;
  }
  return NaN;
};
const str = (v: unknown, max: number): string => (typeof v === "string" ? v.trim().slice(0, max) : "");
const r2 = (n: number) => Math.round(n * 100) / 100;

function cleanAction(a: any): { name: string; args: Record<string, unknown> } | null {
  if (!a || typeof a.name !== "string" || !ACTIONS.has(a.name) || !a.args || typeof a.args !== "object") return null;
  const g = a.args as Record<string, unknown>;
  switch (a.name) {
    case "add_expense":
    case "add_income": {
      const amount = num(g.amount);
      if (!(amount > 0)) return null;
      const set = a.name === "add_income" ? INC_CATS : EXP_CATS;
      const cat = str(g.category, 20);
      return {
        name: a.name,
        args: {
          amount: r2(amount), category: set.has(cat) ? cat : (a.name === "add_income" ? "other_i" : "other"),
          note: str(g.note, 80), ...(str(g.account, 60) ? { account: str(g.account, 60) } : {}),
        },
      };
    }
    case "add_goal": {
      const target = num(g.target), name = str(g.name, 60);
      return name && target > 0 ? { name: a.name, args: { name, target: r2(target) } } : null;
    }
    case "add_to_goal": {
      const amount = num(g.amount), goal = str(g.goal, 60);
      return goal && amount > 0 ? { name: a.name, args: { goal, amount: r2(amount) } } : null;
    }
    case "add_loan": {
      const amount = num(g.amount), person = str(g.person, 60);
      if (!person || !(amount > 0)) return null;
      const days = num(g.days);
      return {
        name: a.name,
        args: { dir: g.dir === "owe" ? "owe" : "owed", person, amount: r2(amount), ...(days >= 0 ? { days: Math.min(3650, Math.round(days)) } : {}) },
      };
    }
    case "open_page":
      return typeof g.page === "string" && PAGES.has(g.page) ? { name: a.name, args: { page: g.page } } : null;
  }
  return null;
}

// ------------------------------------------------------------------ panel: الأرقام من context (PANELS_JSON) مش من الموديل
function panelsFromContext(ctx: string): any | null {
  const m = ctx.match(/^PANELS_JSON=(.*)$/m);
  if (!m) return null;
  try { return JSON.parse(m[1]); } catch { return null; }
}

function buildPanel(spec: any, data: any): Record<string, unknown> | null {
  if (!spec || typeof spec !== "object" || !data || typeof data !== "object") return null;
  if (spec.type === "comparison" && CMP_KEYS.has(spec.key)) {
    const d = data.cmp?.[spec.key];
    const cur = d?.cur, prev = d?.prev;
    const ca = num(cur?.amt), pa = num(prev?.amt);
    if (!Number.isFinite(ca) || !Number.isFinite(pa)) return null;
    const isSpent = d?.metric !== "income";
    const change = pa > 0 ? Math.round(((ca - pa) / pa) * 1000) / 10 : null;
    return {
      type: "comparison", metric: isSpent ? "spent" : "income", title: str(d?.title, 40) || (isSpent ? "إنفاقك" : "دخلك"),
      current: { label: str(cur?.label, 30), amount: r2(ca), count: Math.max(0, Math.round(num(cur?.n) || 0)) },
      previous: { label: str(prev?.label, 30), amount: r2(pa), count: Math.max(0, Math.round(num(prev?.n) || 0)) },
      change_pct: change,
      good: isSpent ? ca <= pa : ca >= pa, // الأخضر = تحسّن (إنفاق أقل / دخل أعلى)
    };
  }
  if (spec.type === "breakdown" && BRK_KEYS.has(spec.key)) {
    const d = data.brk?.[spec.key];
    const total = num(d?.total);
    if (!Array.isArray(d?.items) || !(total > 0)) return null;
    const items = d.items.slice(0, 12)
      .map((x: any) => ({ cat: str(x?.cat, 24), name: str(x?.name, 30), amount: num(x?.amt) }))
      .filter((x: any) => x.name && x.amount > 0);
    if (items.length === 0) return null;
    const top = items.slice(0, 6);
    const rest = items.slice(6).reduce((s: number, x: any) => s + x.amount, 0);
    if (rest > 0) top.push({ cat: "other", name: "أخرى", amount: rest });
    return {
      type: "breakdown", title: str(d?.title, 40) || "تفصيل مصروفك", period_label: str(d?.label, 30),
      total: r2(total), count: Math.max(0, Math.round(num(d?.n) || 0)),
      items: top.map((x: any) => ({ cat: x.cat, name: x.name, amount: r2(x.amount), pct: Math.round((x.amount / total) * 1000) / 10 })),
    };
  }
  return null;
}

const READY = "جهزت لك المعاملة، اضغط نفّذ عشان تتحفظ.";
const READY_MANY = "جهزت لك المعاملات، اضغط نفّذ عشان تتحفظ.";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return json(401, { error: "unauthorized" });
  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const userClient = createClient(url, anon, { global: { headers: { Authorization: auth } } });
  const { data: u, error: uerr } = await userClient.auth.getUser();
  if (uerr || !u?.user) return json(401, { error: "unauthorized" });
  const uid = u.user.id;

  let payload: { messages?: unknown; context?: unknown; consent?: unknown; mode?: unknown };
  try { payload = await req.json(); } catch { return json(400, { error: "invalid_json" }); }
  if (payload.consent !== true) return json(400, { error: "consent_required" });
  if (!Array.isArray(payload.messages) || payload.messages.length === 0) return json(400, { error: "invalid_input" });
  const msgs = payload.messages.slice(-MAX_MSGS)
    .filter((m: any) => m && (m.role === "user" || m.role === "assistant") && typeof m.content === "string")
    .map((m: any) => ({ role: m.role, content: String(m.content).slice(0, MAX_MSG_LEN) }));
  if (msgs.length === 0 || msgs[msgs.length - 1].role !== "user") return json(400, { error: "invalid_input" });
  const ctx = typeof payload.context === "string" ? payload.context.slice(0, MAX_CTX) : "";
  const parseMode = payload.mode === "parse";

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // كاش: نفس السؤال على نفس البيانات (والرد السابق مفيهوش أوامر) يرجع من غير استهلاك طلب جديد. (مش في وضع parse)
  const cacheKey = await sha256hex(uid + "|" + msgs[msgs.length - 1].content + "|" + ctx);
  if (!parseMode) {
    try {
      let { data: hit, error: herr } = await admin.from("ai_chat_cache").select("reply, extra, created_at").eq("key", cacheKey).maybeSingle();
      if (herr) ({ data: hit } = await admin.from("ai_chat_cache").select("reply, created_at").eq("key", cacheKey).maybeSingle()); // عمود extra لسه مش موجود
      if (hit && Date.now() - new Date(hit.created_at as string).getTime() < CACHE_TTL_MS) {
        console.info(JSON.stringify({ event: "cache_hit" }));
        const ex: any = (hit as any).extra ?? {};
        const body: Record<string, unknown> = { reply: hit.reply, actions: [], cached: true };
        if (ex && typeof ex === "object") {
          if (ex.panel && typeof ex.panel === "object") body.panel = ex.panel;
          if (Array.isArray(ex.suggestions) && ex.suggestions.length > 0) body.suggestions = ex.suggestions;
        }
        return json(200, body);
      }
    } catch { /* الجدول مش موجود لسه أو حصل خطأ - مكملين من غير كاش */ }
  }

  const since = new Date(Date.now() - 3600_000).toISOString();
  const { count, error: cerr } = await admin.from("ai_rate_limit").select("id", { count: "exact", head: true })
    .eq("user_id", uid).gte("created_at", since);
  if (cerr) return json(500, { error: "rate_check_failed" });
  if ((count ?? 0) >= LIMIT_PER_HOUR) return json(429, { error: "rate_limited" });
  await admin.from("ai_rate_limit").insert({ user_id: uid });

  const chain = providers();
  if (chain.length === 0) return json(500, { error: "server_not_configured" });
  const chatMessages = [
    { role: "system", content: (parseMode ? PARSE_SYSTEM : SYSTEM) + "\n\nAPP CONTEXT:\n" + ctx },
    ...(parseMode ? [msgs[msgs.length - 1]] : msgs),
  ];
  let lastErr = "upstream_error";
  for (const p of chain) {
    for (const m of p.models) {
      const ctl = new AbortController();
      const t = setTimeout(() => ctl.abort(), 25000);
      try {
        const body: Record<string, unknown> = {
          model: m, temperature: 0.3, response_format: { type: "json_object" },
          messages: chatMessages,
        };
        if (p.id === "cloudflare") body.max_tokens = 2048;
        if (p.id === "gemini") { body.max_completion_tokens = 2048; body.reasoning_effort = "none"; }
        const r = await fetch(p.url, {
          method: "POST", signal: ctl.signal,
          headers: { Authorization: `Bearer ${p.key}`, "Content-Type": "application/json" },
          body: JSON.stringify(body),
        });
        if (!r.ok) {
          console.warn(JSON.stringify({ event: "provider_failed", provider: p.id, model: m, status: r.status }));
          await r.body?.cancel();
          lastErr = "upstream_error";
          continue;
        }
        const data = await r.json();
        const raw = data?.choices?.[0]?.message?.content;
        const text = typeof raw === "string" ? raw.trim() : "";
        if (!text) { // رد فاضي (موديل تفكير خلّص التوكنز مثلًا) → نكمل على اللي بعده
          console.warn(JSON.stringify({ event: "provider_empty", provider: p.id, model: m }));
          lastErr = "upstream_error";
          continue;
        }
        const out = extractJson(text);

        // ---- وضع التحليل لـ «اكتب اللي صرفته»
        if (parseMode) {
          const entries = (Array.isArray(out?.entries) ? out.entries : []).slice(0, 25)
            .map((e: any) => {
              const amount = num(e?.amount);
              if (!(amount > 0)) return null;
              const inc = e?.type === "inc";
              const cat = str(e?.category, 20);
              return {
                type: inc ? "inc" : "exp", amount: r2(amount),
                category: (inc ? INC_CATS : EXP_CATS).has(cat) ? cat : (inc ? "other_i" : "other"),
                note: str(e?.note, 60), account: str(e?.account, 60),
              };
            })
            .filter((e: unknown) => e !== null);
          console.info(JSON.stringify({ event: "ai_success", provider: p.id, model: m, mode: "parse" }));
          return json(200, { reply: "", actions: [], entries });
        }

        // ---- الدردشة العادية
        const reply0 = out === null ? text.slice(0, 2000) : str(out?.reply, 2000); // نص عادي من الموديل = الرد نفسه
        const actions = (Array.isArray(out?.actions) ? out.actions : []).slice(0, 5)
          .map(cleanAction).filter((a: unknown) => a !== null) as { name: string; args: Record<string, unknown> }[];
        const saving = actions.filter((a) => a.name !== "open_page").length;
        let reply = reply0 || (saving === 0 ? "تمام." : "");
        if (saving > 0 && !reply.includes("جهزت لك")) reply = `${saving > 1 ? READY_MANY : READY}${reply ? " " + reply : ""}`;
        const resp: Record<string, unknown> = { reply, actions };
        const panel = buildPanel(out?.panel, panelsFromContext(ctx));
        if (panel) resp.panel = panel;
        const sug = (Array.isArray(out?.suggestions) ? out.suggestions : [])
          .map((s: unknown) => str(s, 40)).filter((s: string) => s.length > 0).slice(0, 3);
        if (sug.length > 0) resp.suggestions = sug;

        // الردود اللي مفيهاش أوامر بس هي اللي بتتخزن في الكاش (مع البطاقة والاقتراحات لو عمود extra موجود).
        if (actions.length === 0 && reply0) {
          try {
            const extra = { ...(panel ? { panel } : {}), ...(sug.length > 0 ? { suggestions: sug } : {}) };
            const { error: werr } = await admin.from("ai_chat_cache").upsert({ key: cacheKey, user_id: uid, reply, extra });
            if (werr) await admin.from("ai_chat_cache").upsert({ key: cacheKey, user_id: uid, reply }); // من غير extra
          } catch { /* تجاهل */ }
        }
        console.info(JSON.stringify({ event: "ai_success", provider: p.id, model: m }));
        return json(200, resp);
      } catch (_e) {
        console.warn(JSON.stringify({ event: "provider_error", provider: p.id, model: m }));
        lastErr = "timeout_or_failure";
      } finally { clearTimeout(t); }
    }
  }
  return json(lastErr === "timeout_or_failure" ? 504 : 502, { error: lastErr });
});
