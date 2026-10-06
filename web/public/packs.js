// Same-origin cooked JSON. The browser never calls the Access gate for a pack,
// and never opens sqlite or a public bucket host.

export const FIGURE_SECTIONS = new Set([
  "lost_revenue",
  "five_star",
  "pick_path",
  "dynacap",
  "schedule_quality",
  "picker_scorecard",
  "labor",
]);

export function packURL(path, origin) {
  const clean = String(path || "")
    .replace(/^\/+/, "")
    .split("?")[0];
  const lower = clean.toLowerCase();
  if (!clean || clean.includes("..") || clean.includes("\\") || clean.includes("//")) return null;
  if (lower.includes(".sqlite") || lower.includes("://")) return null;
  let relative = null;
  if (clean === "home") relative = "/data/home.json";
  else if (clean === "presub") relative = "/data/presub.json";
  else if (clean === "schedule") relative = "/data/schedule.json";
  else {
    const match = clean.match(/^section\/([a-z0-9_]+)$/);
    if (match) relative = `/data/section/${match[1]}.json`;
  }
  if (!relative) return null;
  if (!origin) return relative;
  // location.origin has no user:pass. Strip again in case the base still has them.
  try {
    return new URL(relative, new URL(String(origin)).origin).href;
  } catch {
    return null;
  }
}
