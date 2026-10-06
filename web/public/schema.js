// Bump this when home.json gains a key the page reads.
// An older pack still loads, and the page warns.
export const SCHEMA_VERSION = 1;

export function schemaWarning(home) {
  const version = home && home.metadata ? home.metadata.schemaVersion : undefined;
  if (typeof version === "number" && version >= SCHEMA_VERSION) return "";
  const shown = typeof version === "number" ? String(version) : "missing";
  return `This pack is schema ${shown}. This page expects schema ${SCHEMA_VERSION}.`;
}
