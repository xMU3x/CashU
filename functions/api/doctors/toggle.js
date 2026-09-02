import { sb, sbAuthAdmin, json, preflight } from "../../_lib/supabase.js";
import { requireAdmin, AuthError } from "../../_lib/auth.js";

// POST /api/doctors/toggle  body: { id, isActive }
// Enables or disables a doctor's login. Disabling does NOT delete the
// account or touch any case they previously registered/edited — those
// records (and their "registered/edited by" trail) stay exactly as they are.
export async function onRequestPost({ request, env }) {
  try {
    const { user } = await requireAdmin(request, env);

    const { id, isActive } = await request.json();
    if (!id || typeof isActive !== "boolean") {
      return json({ error: "id and isActive (boolean) are required" }, 400);
    }
    if (id === user.id && !isActive) {
      return json({ error: "You can't disable your own account." }, 400);
    }

    const admin = sbAuthAdmin(env);
    // ban_duration: "none" re-enables login; a very long duration blocks it
    // (Supabase has no permanent "disabled" flag, so this is the standard trick).
    const banRes = await fetch(`${admin.base}/users/${encodeURIComponent(id)}`, {
      method: "PUT",
      headers: admin.headers,
      body: JSON.stringify({ ban_duration: isActive ? "none" : "876000h" }),
    });
    if (!banRes.ok) throw new Error(`Supabase admin error ${banRes.status}: ${await banRes.text()}`);

    const { base, headers } = sb(env);
    const updRes = await fetch(`${base}/profiles?id=eq.${encodeURIComponent(id)}`, {
      method: "PATCH",
      headers: { ...headers, Prefer: "return=minimal" },
      body: JSON.stringify({ is_active: isActive }),
    });
    if (!updRes.ok) throw new Error(`Supabase profile update error ${updRes.status}: ${await updRes.text()}`);

    return json({ ok: true });
  } catch (err) {
    if (err instanceof AuthError) return json({ error: err.message }, err.status);
    console.error("toggle-doctor error:", err);
    return json({ error: err.message }, 500);
  }
}

export async function onRequestOptions() {
  return preflight();
}
