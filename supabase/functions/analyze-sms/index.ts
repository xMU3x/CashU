// Supabase Edge Function: analyze-sms
// يستدعي Groq من السيرفر فقط. المفتاح يُقرأ من Supabase Secrets (GROQ_API_KEY) ولا يوجد في التطبيق.
// النشر:  supabase secrets set GROQ_API_KEY=gsk_...   ثم   supabase functions deploy analyze-sms
// الجدول المطلوب للحدّ من الطلبات: انظر supabase/ai_rate_limit.sql
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const MODEL = "llama-3.3-70b-versatile";
const MAX_BODY = 600;      // حروف
const MAX_SENDER = 40;
const LIMIT_PER_HOUR = 60; // لكل مستخدم

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

// إخفاء ثانٍ على السيرفر (دفاع إضافي): روابط + أرقام طويلة → آخر 4 فقط
function redact(s: string): string {
  return s
    .replace(/https?:\/\/\S+/g, "[link]")
    .replace(/\d[\d\- ]{7,}\d/g, (m) => {
      const d = m.replace(/\D/g, "");
      return d.length < 9 ? m : "****" + d.slice(-4);
    });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  // 1) هوية المستخدم: JWT صالح فقط (مش anon key)
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return json(401, { error: "unauthorized" });
  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const userClient = createClient(url, anon, { global: { headers: { Authorization: auth } } });
  const { data: u, error: uerr } = await userClient.auth.getUser();
  if (uerr || !u?.user) return json(401, { error: "unauthorized" });
  const uid = u.user.id;

  // 2) التحقق من المدخلات
  let payload: { sender?: unknown; body?: unknown; consent?: unknown };
  try { payload = await req.json(); } catch { return json(400, { error: "invalid_json" }); }
  if (payload.consent !== true) return json(400, { error: "consent_required" });
  if (typeof payload.body !== "string" || typeof payload.sender !== "string") return json(400, { error: "invalid_input" });
  const sender = payload.sender.trim().slice(0, MAX_SENDER);
  const body = payload.body.trim();
  if (!body || body.length > MAX_BODY) return json(400, { error: "invalid_length" });

  // 3) حد الطلبات (جدول ai_rate_limit، يكتب بـ service role)
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const since = new Date(Date.now() - 3600_000).toISOString();
  const { count, error: cerr } = await admin.from("ai_rate_limit").select("id", { count: "exact", head: true })
    .eq("user_id", uid).gte("created_at", since);
  if (cerr) return json(500, { error: "rate_check_failed" });
  if ((count ?? 0) >= LIMIT_PER_HOUR) return json(429, { error: "rate_limited" });
  await admin.from("ai_rate_limit").insert({ user_id: uid });

  // 4) استدعاء Groq
  const key = Deno.env.get("GROQ_API_KEY");
  if (!key) return json(500, { error: "server_not_configured" });
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), 8000);
  try {
    const r = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST", signal: ctl.signal,
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: MODEL, temperature: 0, response_format: { type: "json_object" },
        messages: [
          { role: "system", content:
            'You classify Egyptian bank/wallet SMS. Reply ONLY JSON: {"financial":bool,"kind":"exp"|"inc"|"","amount":number,"merchant":string,"confidence":0..1}. ' +
            "financial=false for OTPs, ads, promotions, balance-only or failed transactions. exp = money left the account, inc = money received." },
          { role: "user", content: `Sender: ${sender}\nMessage: ${redact(body)}` },
        ],
      }),
    });
    if (!r.ok) return json(502, { error: "upstream_error" });
    const data = await r.json();
    const out = JSON.parse(data?.choices?.[0]?.message?.content ?? "{}");
    // تنظيف المخرجات: لا نمرّر إلا الحقول المتوقعة
    return json(200, {
      financial: out.financial === true,
      kind: out.kind === "exp" || out.kind === "inc" ? out.kind : "",
      amount: typeof out.amount === "number" && isFinite(out.amount) ? out.amount : 0,
      merchant: typeof out.merchant === "string" ? out.merchant.slice(0, 80) : "",
      confidence: typeof out.confidence === "number" ? Math.min(1, Math.max(0, out.confidence)) : 0,
    });
  } catch (_e) {
    return json(504, { error: "timeout_or_failure" });
  } finally { clearTimeout(t); }
});
