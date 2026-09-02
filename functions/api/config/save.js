import { sb, json, preflight } from "../../_lib/supabase.js";
import { requireActiveUser, AuthError } from "../../_lib/auth.js";

// body: { key: "consultants" | "departments" | ..., value: [ ...strings ] }
export async function onRequestPost({ request, env }) {
  try {
    await requireActiveUser(request, env);

    const { key, value } = await request.json();
    if (!key || value === undefined || value === null) {
      return json({ error: "Invalid config data (key, value required)" }, 400);
    }
    const { base, headers } = sb(env);
    const r = await fetch(`${base}/app_config`, {
      method: "POST",
      headers: { ...headers, Prefer: "resolution=merge-duplicates,return=minimal" },
      body: JSON.stringify([{ key, value, updated_at: new Date().toISOString() }]),
    });
    if (!r.ok) throw new Error(`Supabase upsert error ${r.status}: ${await r.text()}`);
    return json({ ok: true });
  } catch (err) {
    if (err instanceof AuthError) return json({ error: err.message }, err.status);
    console.error("save-config error:", err);
    return json({ error: err.message }, 500);
  }
}

export async function onRequestOptions() {
  return preflight();
}
