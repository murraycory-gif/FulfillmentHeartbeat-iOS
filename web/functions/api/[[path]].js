const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "private, no-store",
  "x-content-type-options": "nosniff",
};

// The bucket stays private. HEARTBEAT_PACKS is read only in _middleware.js,
// after the session check, through readPackObject. This route does not call
// bucket.get and does not publish a public bucket host.
export async function onRequest() {
  return new Response(JSON.stringify({ error: "NO DATA" }), { status: 404, headers: JSON_HEADERS });
}
