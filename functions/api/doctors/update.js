import { sb, sbAuthAdmin, json, preflight } from "../../_lib/supabase.js";
import { requireAdmin, AuthError } from "../../_lib/auth.js";

// POST /api/doctors/update
// body: { id, displayName, email, role, password? }
// Admin-only: edits an existing doctor's account details. Password is only
// changed if a non-empty value is supplied.
export async function onRequestPost({ request, env }) {
  try {
    await requireAdmin(request, env);

    const { id, displayName, email, role, password } = await request.json();
    if (!id || !displayName || !email) {
      return json({ error: "id, displayName and email are required" }, 400);
    }
    if (password && password.length < 6) {
      return json({ error: "Password must be at least 6 characters" }, 400);
    }

    const admin = sbAuthAdmin(env);

    // 1) Update the Supabase Auth account (email / display name / password).
    const authPayload = {
      email,
      user_metadata: { display_name: displayName },
    };
    if (password) authPayload.password = password;

    const updRes = await fetch(`${admin.base}/users/${encodeURIComponent(id)}`, {
      method: "PUT",
      headers: admin.headers,
      body: JSON.stringify(authPayload),
    });
    const updBody = await updRes.json().catch(() => ({}));
    if (!updRes.ok) {
      throw new Error(updBody?.msg || updBody?.error_description || `Supabase auth error ${updRes.status}`);
    }

    // 2) Update the matching profile row.
    const { base, headers } = sb(env);
    const profRes = await fetch(`${base}/profiles?id=eq.${encodeURIComponent(id)}`, {
      method: "PATCH",
      headers: { ...headers, Prefer: "return=minimal" },
      body: JSON.stringify({
        email,
        display_name: displayName,
        role: role === "admin" ? "admin" : "doctor",
      }),
    });
    if (!profRes.ok) throw new Error(`Supabase profile update error ${profRes.status}: ${await profRes.text()}`);

    return json({ ok: true });
  } catch (err) {
    if (err instanceof AuthError) return json({ error: err.message }, err.status);
    console.error("update-doctor error:", err);
    return json({ error: err.message }, 500);
  }
}

export async function onRequestOptions() {
  return preflight();
}
