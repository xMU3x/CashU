import { sb, json, preflight } from "../../_lib/supabase.js";
import { requireActiveUser, AuthError } from "../../_lib/auth.js";

// GET /api/cases            -> active cases only
// GET /api/cases?all=1      -> everything
// GET /api/cases?archived=1 -> archived cases only
// Requires a valid, active doctor session.
export async function onRequestGet({ request, env }) {
  try {
    await requireActiveUser(request, env);

    const { base, headers } = sb(env);
    const url = new URL(request.url);
    let filter = "status=eq.active";
    if (url.searchParams.get("all")) filter = "";
    else if (url.searchParams.get("archived")) filter = "status=eq.archived";

    const qs = filter ? `${filter}&` : "";
    const r = await fetch(
      `${base}/cases?${qs}select=payload&order=created_at.desc`,
      { headers }
    );
    if (!r.ok) throw new Error(`Supabase error ${r.status}: ${await r.text()}`);
    const rows = await r.json();
    // Lighten the payload for the list view: drop attachment file data
    // (dataUrl) and keep only lightweight metadata (name/type/size), so the
    // list loads quickly even when cases have photos/files attached.
    const lightened = rows.map((row) => {
      const payload = row.payload || {};
      if (!Array.isArray(payload.attachments) || payload.attachments.length === 0) {
        return payload;
      }
      return {
        ...payload,
        attachments: payload.attachments.map((a) => ({
          name: a.name,
          type: a.type,
          size: a.size,
        })),
      };
    });
    return json(lightened);
  } catch (err) {
    if (err instanceof AuthError) return json({ error: err.message }, err.status);
    console.error("get-cases error:", err);
    return json({ error: err.message }, 500);
  }
}

export async function onRequestOptions() {
  return preflight();
}
