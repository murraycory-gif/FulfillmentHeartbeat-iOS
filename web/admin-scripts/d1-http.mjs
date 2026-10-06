// D1 over the Cloudflare HTTP API. The site does not serve this file.
// Routine account commands use this instead of `wrangler d1`.

export const PREVIEW_DATABASE_NAME = "hb-auth-preview";
export const PREVIEW_DATABASE_ID = "291dfe6d-fcc1-4b15-90c7-768db26d1f8e";
export const PRODUCTION_DATABASE_NAME = "fulfillment-heartbeat-auth";
export const PRODUCTION_DATABASE_ID = "646c017a-802f-4395-b635-d4b5bd66c1cb";

const NAMED = {
  [PREVIEW_DATABASE_NAME]: PREVIEW_DATABASE_ID,
  [PRODUCTION_DATABASE_NAME]: PRODUCTION_DATABASE_ID,
};

export function databaseId(database) {
  const value = String(database || "").trim();
  if (NAMED[value]) return NAMED[value];
  if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) return value.toLowerCase();
  return "";
}

export function productionBlocked(database, allowProd = process.env.HB_ALLOW_PROD === "1") {
  if (allowProd) return false;
  const value = String(database || "").trim();
  const id = databaseId(value);
  return value === PRODUCTION_DATABASE_NAME || value === "hb-users" || id === PRODUCTION_DATABASE_ID;
}

export function sqlStatements(text) {
  return String(text)
    .split(";")
    .map((part) => part.replace(/--[^\n]*/g, "").trim())
    .filter(Boolean);
}

export function ignorableMigrationError(error) {
  return /duplicate column name|already exists/i.test(String(error && error.message));
}

export async function d1Query(database, sql, params = []) {
  const id = databaseId(database);
  const accountId = String(process.env.CLOUDFLARE_ACCOUNT_ID || "").trim();
  const token = String(process.env.CLOUDFLARE_API_TOKEN || "").trim();
  if (!id) throw new Error("Pass hb-auth-preview or a D1 database id.");
  if (!accountId || !token) {
    throw new Error("Set CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN. This command uses the D1 HTTP API.");
  }
  const response = await fetch(`https://api.cloudflare.com/client/v4/accounts/${accountId}/d1/database/${id}/query`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ sql, params }),
  });
  const body = await response.json().catch(() => null);
  if (!response.ok || !body || body.success === false) {
    const message = body && body.errors && body.errors[0] && body.errors[0].message;
    throw new Error(message || "D1 query failed");
  }
  return (Array.isArray(body.result) ? body.result[0] : body.result) || { results: [] };
}

export async function applyMigration(database, sqlText) {
  for (const statement of sqlStatements(sqlText)) {
    try {
      await d1Query(database, statement);
    } catch (error) {
      if (!ignorableMigrationError(error)) throw error;
    }
  }
}
