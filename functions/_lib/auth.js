// Shared helper: verifies the Supabase Auth access token sent by the browser
// (Authorization: Bearer <token>) and checks the doctor's profile is active.
//
// Every protected endpoint should call requireActiveUser(request, env) first.
// It returns { user, profile } on success, or throws an AuthError that the
// caller turns into a 401/403 JSON response.

export class AuthError extends Error {
  constructor(message, status) {
    super(message);
    this.status = status || 401;
  }
}

// Verifies the bearer token against Supabase Auth and returns the user object
// ({ id, email, ... }), or null if there's no/invalid token.
async function getUserFromToken(request, env) {
  const authHeader = request.headers.get("Authorization") || "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) return null;

  const url = env.SUPABASE_URL;
  const anonKey = env.SUPABASE_ANON_KEY;
  if (!url || !anonKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_ANON_KEY environment variables");
  }

  const r = await fetch(`${url.replace(/\/$/, "")}/auth/v1/user`, {
    headers: { apikey: anonKey, Authorization: `Bearer ${token}` },
  });
  if (!r.ok) return null;
  return r.json();
}

// Looks up the doctor's profile row (display name / active flag / role)
// using the service-role key (server-side only, bypasses RLS).
async function getProfile(userId, env) {
  const { sb } = await import("./supabase.js");
  const { base, headers } = sb(env);
  const r = await fetch(
    `${base}/profiles?id=eq.${encodeURIComponent(userId)}&select=id,email,display_name,is_active,role`,
    { headers }
  );
  if (!r.ok) throw new Error(`Supabase error ${r.status}: ${await r.text()}`);
  const rows = await r.json();
  return rows[0] || null;
}

// Main guard: requires a valid, active doctor account. Throws AuthError otherwise.
export async function requireActiveUser(request, env) {
  const user = await getUserFromToken(request, env);
  if (!user || !user.id) throw new AuthError("Please sign in to continue.", 401);

  const profile = await getProfile(user.id, env);
  if (!profile) throw new AuthError("No profile found for this account.", 403);
  if (!profile.is_active) throw new AuthError("This account has been disabled.", 403);

  return { user, profile };
}

// Stricter guard for the doctor-management endpoints: requires role = 'admin'.
export async function requireAdmin(request, env) {
  const { user, profile } = await requireActiveUser(request, env);
  if (profile.role !== "admin") throw new AuthError("Admins only.", 403);
  return { user, profile };
}
