// Supabase Edge Function: ai-chat  (مساعد CashU)
// المفتاح يُقرأ من Supabase Secrets (GROQ_API_KEY) ولا يوجد في التطبيق.
// النشر:  supabase secrets set GROQ_API_KEY=gsk_...   ثم   supabase functions deploy ai-chat
// يعيد {reply, actions[]}. الدالة لا تنفّذ أي شيء: التطبيق هو اللي بينفّذ الأوامر بعد تأكيد المستخدم.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const MODEL = "llama-3.3-70b-versatile";
const MAX_MSGS = 16;
const MAX_MSG_LEN = 1500;
const MAX_CTX = 7000;
const LIMIT_PER_HOUR = 60;
const ACTIONS = new Set(["add_expense", "add_income", "add_goal", "add_to_goal", "add_loan", "open_page"]);

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

const SYSTEM = `You are CashU Assistant, a friendly personal-finance assistant inside an Arabic (Egyptian dialect) money app.
Reply in the user's language (default Egyptian Arabic), short and practical. Use ONLY the APP CONTEXT for numbers; never invent balances or transactions.
Reply ONLY with JSON: {"reply": string, "actions": [{"name": string, "args": object}]}.
Use actions only when the user clearly asks to DO something. Allowed actions (args):
- add_expense {amount:number, category: food|shop|transport|bills|health|fun|edu|home|other, note:string, account?:string (id or name)}
- add_income {amount:number, category: salary|free|gift|invest|other_i, note:string, account?:string}
- add_goal {name:string, target:number}
- add_to_goal {goal:string (goal name), amount:number}
- add_loan {dir:"owed"|"owe", person:string, amount:number, days?:number}   (owed = someone owes me, owe = I owe someone)
- open_page {page: goals|subscriptions|loans|assets}
The app asks the user to confirm every action before running it. Never propose deleting data, backups, restoring, or changing settings.
If information is missing (e.g. amount), ask a short question and return no actions.`;

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

  let payload: { messages?: unknown; context?: unknown; consent?: unknown };
  try { payload = await req.json(); } catch { return json(400, { error: "invalid_json" }); }
  if (payload.consent !== true) return json(400, { error: "consent_required" });
  if (!Array.isArray(payload.messages) || payload.messages.length === 0) return json(400, { error: "invalid_input" });
  const msgs = payload.messages.slice(-MAX_MSGS)
    .filter((m: any) => m && (m.role === "user" || m.role === "assistant") && typeof m.content === "string")
    .map((m: any) => ({ role: m.role, content: String(m.content).slice(0, MAX_MSG_LEN) }));
  if (msgs.length === 0 || msgs[msgs.length - 1].role !== "user") return json(400, { error: "invalid_input" });
  const ctx = typeof payload.context === "string" ? payload.context.slice(0, MAX_CTX) : "";

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const since = new Date(Date.now() - 3600_000).toISOString();
  const { count, error: cerr } = await admin.from("ai_rate_limit").select("id", { count: "exact", head: true })
    .eq("user_id", uid).gte("created_at", since);
  if (cerr) return json(500, { error: "rate_check_failed" });
  if ((count ?? 0) >= LIMIT_PER_HOUR) return json(429, { error: "rate_limited" });
  await admin.from("ai_rate_limit").insert({ user_id: uid });

  const key = Deno.env.get("GROQ_API_KEY");
  if (!key) return json(500, { error: "server_not_configured" });
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), 25000);
  try {
    const r = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST", signal: ctl.signal,
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: MODEL, temperature: 0.3, response_format: { type: "json_object" },
        messages: [{ role: "system", content: SYSTEM + "\n\nAPP CONTEXT:\n" + ctx }, ...msgs],
      }),
    });
    if (!r.ok) return json(502, { error: "upstream_error" });
    const data = await r.json();
    let out: any = {};
    try { out = JSON.parse(data?.choices?.[0]?.message?.content ?? "{}"); } catch { /* نص عادي */ }
    const reply = typeof out.reply === "string" ? out.reply.slice(0, 2000) : "";
    const actions = (Array.isArray(out.actions) ? out.actions : []).slice(0, 5)
      .filter((a: any) => a && typeof a.name === "string" && ACTIONS.has(a.name) && a.args && typeof a.args === "object")
      .map((a: any) => ({ name: a.name, args: a.args }));
    return json(200, { reply: reply || "تمام.", actions });
  } catch (_e) {
    return json(504, { error: "timeout_or_failure" });
  } finally { clearTimeout(t); }
});
