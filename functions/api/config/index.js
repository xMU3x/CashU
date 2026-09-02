import { sb, json, preflight } from "../../_lib/supabase.js";
import { requireActiveUser, AuthError } from "../../_lib/auth.js";

const DEFAULTS = {
  seniors: [
    "Dr. Ahmed Hassan","Dr. Mohamed Ali","Dr. Sara Youssef","Dr. Khaled Mostafa"
  ],
  consultants: [
    "Dr. Ahmed Hassan","Dr. Mohamed Ali","Dr. Sara Youssef","Dr. Khaled Mostafa",
    "Dr. Omar Fathy","Dr. Nour ElDin","Dr. Amr Sami","Dr. Laila Adel"
  ],
  departments: ["Surgery A","Surgery B","ICU 6th Floor"],
  password: "1234",
  showInstallOption: true,
};

// Requires a logged-in, active doctor account (this list is only used
// inside the app once someone is signed in).
export async function onRequestGet({ request, env }) {
  try {
    const { profile } = await requireActiveUser(request, env);
    const { base, headers } = sb(env);
    const r = await fetch(`${base}/app_config?select=key,value`, { headers });
    if (!r.ok) throw new Error(`Supabase error ${r.status}: ${await r.text()}`);
    const rows = await r.json();
    const out = { ...DEFAULTS };
    for (const row of rows) out[row.key] = row.value;
    out.isAdmin = profile.role === "admin";
    return json(out);
  } catch (err) {
    if (err instanceof AuthError) return json({ error: err.message }, err.status);
    console.error("get-config error:", err);
    return json({ error: err.message }, 500);
  }
}

export async function onRequestOptions() {
  return preflight();
}
