import { sb, json, preflight } from "../../_lib/supabase.js";
import { requireAdmin, AuthError } from "../../_lib/auth.js";

// POST /api/doctors/reorder   body: { order: [id1, id2, id3, ...] }
// Admin-only: persists the new display order of doctor accounts (the array
// index becomes each doctor's sort_order).
export async function onRequestPost({ request, env }) {
  try {
    await requireAdmin(request, env);

    const { order } = await request.json();
    if (!Array.isArray(order) || !order.length) {
      return json({ error: "order (array of doctor ids) is required" }, 400);
    }

    const { base, headers } = sb(env);
    await Promise.all(
      order.map((id, idx) =>
        fetch(`${base}/profiles?id=eq.${encodeURIComponent(id)}`, {
          method: "PATCH",
          headers: { ...headers, Prefer: "return=minimal" },
          body: JSON.stringify({ sort_order: idx }),
        }).then((r) => {
          if (!r.ok) throw new Error(`Supabase reorder error ${r.status}`);
        })
      )
    );

    return json({ ok: true });
  } catch (err) {
    if (err instanceof AuthError) return json({ error: err.message }, err.status);
    console.error("reorder-doctors error:", err);
    return json({ error: err.message }, 500);
  }
}

export async function onRequestOptions() {
  return preflight();
}
