import { sb, json, preflight } from "../../_lib/supabase.js";
import { requireActiveUser, AuthError } from "../../_lib/auth.js";

// GET /api/cases/detail?id=123 -> full case payload, including attachment file data.
// Kept separate from the list endpoint so the list itself stays fast/light.
export async function onRequestGet({ request, env }) {
  try {
    await requireActiveUser(request, env);

    const url = new URL(request.url);
    const id = url.searchParams.get("id");
    if (!id) return json({ error: "Missing id" }, 400);

    const { base, headers } = sb(env);
    const r = await fetch(
      `${base}/cases?id=eq.${encodeURIComponent(id)}&select=payload`,
      { headers }
    );
    if (!r.ok) throw new Error(`Supabase error ${r.status}: ${await r.text()}`);
    const rows = await r.json();
    if (!rows.length) return json({ error: "Not found" }, 404);
    return json(rows[0].payload);
  } catch (err) {
    if (err instanceof AuthError) return json({ error: err.message }, err.status);
    console.error("get-case-detail error:", err);
    return json({ error: err.message }, 500);
  }
}

export async function onRequestOptions() {
  return preflight();
}
