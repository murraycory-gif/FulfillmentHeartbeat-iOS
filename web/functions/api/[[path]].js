import allowlistText from "../allowlist.txt";
import { authorize, objectKeyForPath } from "../gate.js";

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "private, no-store",
  "x-content-type-options": "nosniff",
};

function json(body, status) {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

// Proxies an allowlisted R2 key after Access says yes. The bucket hostname
// is never written into the response.
export async function onRequest(context) {
  const request = context.request;
  if (request.method !== "GET" && request.method !== "HEAD") {
    return json({ error: "NO DATA" }, 405);
  }
  const url = new URL(request.url);
  const rest = url.pathname.replace(/^\/api\/?/, "");
  const key = objectKeyForPath(rest);
  if (!key) return json({ error: "NO DATA" }, 404);

  const auth = await authorize(request, context.env || {}, allowlistText);
  if (!auth.ok) return json({ error: "Unauthorized" }, 401);

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
