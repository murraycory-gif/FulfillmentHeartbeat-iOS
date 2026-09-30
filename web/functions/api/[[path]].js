import { objectKeyForPath } from "../gate.js";

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "private, no-store",
  "x-content-type-options": "nosniff",
};

function json(body, status) {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

// Cooked pack JSON only. objectKeyForPath already refuses sqlite and a public bucket host.
// The Pages hostname is not behind Access, so a missing email PIN must not
// hide these keys. The browser reads /data/*.json first; this route is the
// same pack when the files are in the bucket.
export async function onRequest(context) {
  const request = context.request;
  if (request.method !== "GET" && request.method !== "HEAD") {
    return json({ error: "NO DATA" }, 405);
  }
  const url = new URL(request.url);
  const rest = url.pathname.replace(/^\/api\/?/, "");
  const key = objectKeyForPath(rest);
  if (!key) return json({ error: "NO DATA" }, 404);

  const bucket = context.env && context.env.HEARTBEAT_PACKS;
  if (!bucket || typeof bucket.get !== "function") return json({ error: "NO DATA" }, 404);

  const object = await bucket.get(key);
  if (!object) return json({ error: "NO DATA" }, 404);

  const headers = {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "private, no-store",
    "x-content-type-options": "nosniff",
  };
  if (request.method === "HEAD") return new Response(null, { status: 200, headers });
  return new Response(object.body, { status: 200, headers });
}
