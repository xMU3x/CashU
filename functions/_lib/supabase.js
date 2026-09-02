// Shared helper: talks to Supabase via its REST API (PostgREST) using plain fetch.
// No SDK needed -> no bundling issues on Cloudflare Workers/Pages.

export function sb(env) {
  const url = env.SUPABASE_URL;
  // يقبل أي واحد من الاسمين: القديم (service_role) أو الجديد (secret key
  // بصيغة sb_secret_...) عشان يشتغل مهما كانت الـ env var اسمها إيه في Cloudflare.
  const key = env.SUPABASE_SERVICE_ROLE_KEY || env.SUPABASE_SECRET_KEY;
  if (!url || !key) {
    throw new Error(
      "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY/SUPABASE_SECRET_KEY environment variables"
    );
  }
  return {
    base: `${url.replace(/\/$/, "")}/rest/v1`,
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    },
  };
}

// Same service-role key, but pointed at Supabase's Auth Admin API
// (create/ban/unban users) instead of the PostgREST data API.
export function sbAuthAdmin(env) {
  const url = env.SUPABASE_URL;
  const key = env.SUPABASE_SERVICE_ROLE_KEY || env.SUPABASE_SECRET_KEY;
  if (!url || !key) {
    throw new Error(
      "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY/SUPABASE_SECRET_KEY environment variables"
    );
  }
  return {
    base: `${url.replace(/\/$/, "")}/auth/v1/admin`,
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    },
  };
}

export function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}

export function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders() },
  });
}

export function preflight() {
  return new Response(null, { status: 204, headers: corsHeaders() });
}
