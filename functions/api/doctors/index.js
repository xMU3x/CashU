import { sb, json, preflight } from "../../_lib/supabase.js";
import { requireAdmin, AuthError } from "../../_lib/auth.js";

// GET /api/doctors -> list every doctor account (admin only)
export async function onRequestGet({ request, env }) {
  try {
    await requireAdmin(request, env);
    const { base, headers } = sb(env);
    const r = await fetch(
      `${base}/profiles?select=id,email,display_name,is_active,role,sort_order,created_at&order=sort_order.asc,created_at.asc`,
      { headers }
    );
    if (!r.ok) throw new Error(`Supabase error ${r.status}: ${await r.text()}`);
    return json(await r.json());
  } catch (err) {
    if (err instanceof AuthError) return json({ error: err.message }, err.status);
    console.error("list-doctors error:", err);
    return json({ error: err.message }, 500);
  }
}

export async function onRequestOptions() {
  return preflight();
}
