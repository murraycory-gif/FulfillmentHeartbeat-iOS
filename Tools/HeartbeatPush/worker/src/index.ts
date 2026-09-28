interface KVNamespace {
  get(key: string): Promise<string | null>;
  put(key: string, value: string): Promise<void>;
  delete(key: string): Promise<void>;
  list(options?: { prefix?: string; cursor?: string }): Promise<{
    keys: { name: string }[];
    list_complete: boolean;
    cursor?: string;
  }>;
}

export interface Env {
  TOKENS: KVNamespace;
  PUSH_LIST_SECRET?: string;
}

type Device = {
  token: string;
  env: "sandbox" | "prod";
  appVersion: string;
  updatedAt: string;
  optedOut: boolean;
};

const tokenPattern = /^[0-9a-f]{64,200}$/;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === "POST" && url.pathname === "/token") {
      return register(request, env);
    }
    if (request.method === "GET" && url.pathname === "/tokens") {
      return list(request, env);
    }
    if (request.method === "DELETE" && url.pathname === "/token") {
      return remove(request, env);
    }
    if (request.method === "GET" && url.pathname === "/sent") {
      return sentStatus(request, env);
    }
    if (request.method === "PUT" && url.pathname === "/sent") {
      return markSent(request, env);
    }
    return json({ error: "not found" }, 404);
  },
};

async function register(request: Request, env: Env): Promise<Response> {
  const raw = await request.text();
  if (raw.length > 4096) return json({ error: "body too large" }, 413);
  let body: { token?: unknown; env?: unknown; appVersion?: unknown; optedOut?: unknown };
  try {
    body = JSON.parse(raw) as typeof body;
  } catch {
    return json({ error: "json" }, 400);
  }
  const token = typeof body.token === "string" ? body.token.trim().toLowerCase() : "";
  const scope = body.env === "sandbox" || body.env === "prod" ? body.env : null;
  const appVersion = typeof body.appVersion === "string" ? body.appVersion.trim().slice(0, 80) : "";
  if (!tokenPattern.test(token) || !scope || !appVersion) {
    return json({ error: "token, env, and appVersion are required" }, 400);
  }
  const device: Device = {
    token,
    env: scope,
    appVersion,
    updatedAt: new Date().toISOString(),
    optedOut: body.optedOut === true,
  };
  await env.TOKENS.put(deviceKey(scope, token), JSON.stringify(device));
  return json({ ok: true });
}

async function list(request: Request, env: Env): Promise<Response> {
  if (!authorized(request, env)) return json({ error: "unauthorized" }, 401);
  const scope = new URL(request.url).searchParams.get("env");
  if (scope !== "sandbox" && scope !== "prod") return json({ error: "env" }, 400);
  const tokens: Device[] = [];
  let cursor: string | undefined;
  do {
    const page = await env.TOKENS.list({ prefix: `device:${scope}:`, cursor });
    for (const key of page.keys) {
      const raw = await env.TOKENS.get(key.name);
      if (!raw) continue;
      try {
        tokens.push(JSON.parse(raw) as Device);
      } catch {
        // Drop a corrupt value on the next delete; do not fail the list.
      }
    }
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);
  return json({ tokens });
}

async function remove(request: Request, env: Env): Promise<Response> {
  if (!authorized(request, env)) return json({ error: "unauthorized" }, 401);
  const url = new URL(request.url);
  const scope = url.searchParams.get("env");
  const token = (url.searchParams.get("token") ?? "").trim().toLowerCase();
  if ((scope !== "sandbox" && scope !== "prod") || !tokenPattern.test(token)) {
    return json({ error: "env and token" }, 400);
  }
  await env.TOKENS.delete(deviceKey(scope, token));
  return json({ ok: true });
}

async function sentStatus(request: Request, env: Env): Promise<Response> {
  if (!authorized(request, env)) return json({ error: "unauthorized" }, 401);
  const stamp = new URL(request.url).searchParams.get("stamp") ?? "";
  if (!stamp || stamp.length > 80) return json({ error: "stamp" }, 400);
  const hit = await env.TOKENS.get(sentKey(stamp));
  return json({ sent: hit != null });
}

async function markSent(request: Request, env: Env): Promise<Response> {
  if (!authorized(request, env)) return json({ error: "unauthorized" }, 401);
  const raw = await request.text();
  if (raw.length > 512) return json({ error: "body too large" }, 413);
  let stamp = "";
  try {
    const body = JSON.parse(raw) as { stamp?: unknown };
    stamp = typeof body.stamp === "string" ? body.stamp : "";
  } catch {
    return json({ error: "json" }, 400);
  }
  if (!stamp || stamp.length > 80) return json({ error: "stamp" }, 400);
  await env.TOKENS.put(sentKey(stamp), new Date().toISOString());
  return json({ ok: true });
}

function deviceKey(envName: string, token: string): string {
  return `device:${envName}:${token}`;
}

function sentKey(stamp: string): string {
  return `sent:${stamp}`;
}

function authorized(request: Request, env: Env): boolean {
  const secret = env.PUSH_LIST_SECRET ?? "";
  if (!secret) return false;
  const header = request.headers.get("Authorization") ?? "";
  return header === `Bearer ${secret}`;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}
