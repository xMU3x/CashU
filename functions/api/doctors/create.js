import { sb, sbAuthAdmin, json, preflight } from "../../_lib/supabase.js";
import { requireAdmin, AuthError } from "../../_lib/auth.js";

// POST /api/doctors/create  body: { email, password, displayName, role }
// Creates a real Supabase Auth account for a doctor, then a matching
// profile row. Only an existing admin can do this (from Settings).
export async function onRequestPost({ request, env }) {
  try {
    const { base, headers } = sb(env);

    // Bootstrap: if there are no doctor accounts at all yet, allow creating
    // the very first one (forced to admin) without requiring a login —
    // otherwise nobody could ever create the first account. This path is
    // automatically closed as soon as one profile exists.
    const countRes = await fetch(`${base}/profiles?select=id&limit=1`, { headers });
    if (!countRes.ok) throw new Error(`Supabase error ${countRes.status}: ${await countRes.text()}`);
    const existingProfiles = await countRes.json();
    const isBootstrap = existingProfiles.length === 0;

    if (!isBootstrap) {
      await requireAdmin(request, env);
    }

    const { email, password, displayName, role } = await request.json();
    if (!email || !password || !displayName) {
      return json({ error: "Email, password and display name are required" }, 400);
    }
    if (password.length < 6) {
      return json({ error: "Password must be at least 6 characters" }, 400);
    }

    const admin = sbAuthAdmin(env);

    // 1) Create the actual login account in Supabase Auth.
    const createRes = await fetch(`${admin.base}/users`, {
      method: "POST",
      headers: admin.headers,
      body: JSON.stringify({
        email,
        password,
        email_confirm: true,
        user_metadata: { display_name: displayName },
      }),
    });
    const created = await createRes.json();
    if (!createRes.ok) {
      throw new Error(created?.msg || created?.error_description || `Supabase auth error ${createRes.status}`);
    }

    // 2) Create the matching profile row (display name / role / active).
    const profRes = await fetch(`${base}/profiles`, {
      method: "POST",
      headers: { ...headers, Prefer: "return=minimal" },
      body: JSON.stringify([
        {
          id: created.id,
          email,
          display_name: displayName,
          role: isBootstrap ? "admin" : (role === "admin" ? "admin" : "doctor"),
          is_active: true,
        },
      ]),
    });
    if (!profRes.ok) throw new Error(`Supabase profile insert error ${profRes.status}: ${await profRes.text()}`);

    return json({ ok: true, id: created.id });
  } catch (err) {
    if (err instanceof AuthError) return json({ error: err.message }, err.status);
    console.error("create-doctor error:", err);
    return json({ error: err.message }, 500);
  }
}

export async function onRequestOptions() {
  return preflight();
}
