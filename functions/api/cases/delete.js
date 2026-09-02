import { sb, json, preflight } from "../../_lib/supabase.js";
import { requireAdmin, AuthError } from "../../_lib/auth.js";

// POST /api/cases/delete   body: { id }        -> delete a single case
// POST /api/cases/delete   body: { ids: [...] } -> bulk-delete several cases
//
// Deleting cases is an Admin-only action (the delete button/bulk-delete
// option is hidden from non-admin doctors in the UI, and this endpoint
// enforces the same rule server-side so it can't be bypassed).
export async function onRequestPost({ request, env }) {
  try {
    await requireAdmin(request, env);

    const body = await request.json();
    let ids = [];
    if (Array.isArray(body?.ids)) {
      ids = body.ids.filter((v) => v !== undefined && v !== null);
    } else if (body?.id !== undefined && body?.id !== null) {
      ids = [body.id];
    }
    if (!ids.length) {
      return json({ error: "Missing id or ids" }, 400);
    }

    const { base, headers } = sb(env);
    // PostgREST supports "in.(a,b,c)" for deleting multiple rows in one call.
    const list = ids.map((id) => encodeURIComponent(id)).join(",");
    const r = await fetch(`${base}/cases?id=in.(${list})`, {
      method: "DELETE",
      headers,
    });
    if (!r.ok) throw new Error(`Supabase delete error ${r.status}: ${await r.text()}`);
    return json({ ok: true, deleted: ids.length });
  } catch (err) {
    if (err instanceof AuthError) return json({ error: err.message }, err.status);
    console.error("delete-case error:", err);
    return json({ error: err.message }, 500);
  }
}

export async function onRequestOptions() {
  return preflight();
}
