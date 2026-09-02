import { sb, json, preflight } from "../../_lib/supabase.js";
import { requireActiveUser, AuthError } from "../../_lib/auth.js";

export async function onRequestPost({ request, env }) {
  try {
    const { user, profile } = await requireActiveUser(request, env);

    const item = await request.json();
    if (!item || !item.id || !item.ptName) {
      return json({ error: "Invalid case data (id, ptName required)" }, 400);
    }
    const { base, headers } = sb(env);

    // Find any existing row so we keep the ORIGINAL "registered by" info,
    // and only update the "last edited by" info.
    const existingRes = await fetch(
      `${base}/cases?id=eq.${encodeURIComponent(item.id)}&select=payload,created_by,created_by_name,created_at`,
      { headers }
    );
    if (!existingRes.ok) throw new Error(`Supabase lookup error ${existingRes.status}`);
    const existingRows = await existingRes.json();
    const existing = existingRows[0] || null;

    const nowIso = new Date().toISOString();
    const createdBy = existing ? existing.created_by : user.id;
    const createdByName = existing ? existing.created_by_name : (profile.display_name || user.email);
    const createdAt = existing ? existing.created_at : nowIso;

    // Stamp the trail directly into the payload too, so the frontend can
    // show "Registered by / Edited by" without extra lookups.
    const payload = {
      ...item,
      createdByName,
      createdAt,
      updatedByName: profile.display_name || user.email,
      updatedAt: nowIso,
    };

    // Upsert: delete any previous row with the same id, then insert fresh.
    const del = await fetch(`${base}/cases?id=eq.${encodeURIComponent(item.id)}`, {
      method: "DELETE",
      headers,
    });
    if (!del.ok) throw new Error(`Supabase delete error ${del.status}`);

    const insRes = await fetch(`${base}/cases`, {
      method: "POST",
      headers: { ...headers, Prefer: "return=minimal" },
      body: JSON.stringify([
        {
          id: item.id,
          pt_name: item.ptName,
          consultant: item.consultant || null,
          status: item.dayOut ? "archived" : "active",
          payload,
          created_by: createdBy,
          created_by_name: createdByName,
          updated_by: user.id,
          updated_by_name: profile.display_name || user.email,
          created_at: createdAt,
          updated_at: nowIso,
        },
      ]),
    });
    if (!insRes.ok)
      throw new Error(`Supabase insert error ${insRes.status}: ${await insRes.text()}`);

    return json({ ok: true });
  } catch (err) {
    if (err instanceof AuthError) return json({ error: err.message }, err.status);
    console.error("save-case error:", err);
    return json({ error: err.message }, 500);
  }
}

export async function onRequestOptions() {
  return preflight();
}
