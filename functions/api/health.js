export async function onRequestGet() {
  return new Response(JSON.stringify({ ok: true, service: "surgery-cases" }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}
