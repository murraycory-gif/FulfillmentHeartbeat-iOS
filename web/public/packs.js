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

export function packURL(path) {
  const clean = String(path || "")
    .replace(/^\/+/, "")
    .split("?")[0];
  const lower = clean.toLowerCase();
  if (!clean || clean.includes("..") || clean.includes("\\") || clean.includes("//")) return null;
  if (lower.includes(".sqlite") || lower.includes("://")) return null;
  if (clean === "home") return "/data/home.json";
  if (clean === "presub") return "/data/presub.json";
  if (clean === "schedule") return "/data/schedule.json";
  const match = clean.match(/^section\/([a-z0-9_]+)$/);
  if (!match) return null;
  return `/data/section/${match[1]}.json`;
}
