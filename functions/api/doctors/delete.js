import { sb, sbAuthAdmin, json, preflight } from "../../_lib/supabase.js";
import { requireAdmin, AuthError } from "../../_lib/auth.js";

// POST /api/doctors/delete   body: { id }
// Admin-only: permanently removes a doctor's login (Supabase Auth user).
// The matching profile row is removed automatically via the ON DELETE
// CASCADE foreign key. Cases they registered/edited are NOT touched — the
// "registered/edited by" name stays as a plain text snapshot on each case.
export async function onRequestPost({ request, env }) {
  try {
    const { user } = await requireAdmin(request, env);

    const { id } = await request.json();
    if (!id) return json({ error: "Missing id" }, 400);
    if (id === user.id) {
      return json({ error: "You can't delete your own account." }, 400);
    }

    const admin = sbAuthAdmin(env);
    const r = await fetch(`${admin.base}/users/${encodeURIComponent(id)}`, {
      method: "DELETE",
      headers: admin.headers,
    });
    if (!r.ok && r.status !== 404) {
      throw new Error(`Supabase admin error ${r.status}: ${await r.text()}`);
    }

    return json({ ok: true });
  } catch (err) {
    if (err instanceof AuthError) return json({ error: err.message }, err.status);
    console.error("delete-doctor error:", err);
    return json({ error: err.message }, 500);
  }
}

export async function onRequestOptions() {
  return preflight();
}
