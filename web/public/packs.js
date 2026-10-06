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

// A pinned section 404 refetches home once. A second 404, a home 404, or a
// 404 with no pin fails without the retry loop. Other statuses keep retrying.
export function packMissPlan({ path, status, pin, repinned }) {
  if (status !== 404) return "retry";
  if (path !== "home" && pin && !repinned) return "repin";
  return "fail";
}

export function packPinQuery(home) {
  if (!home || typeof home !== "object") return "";
  const meta = home.metadata && typeof home.metadata === "object" ? home.metadata : {};
  const cookSha = String(home.cookSha || meta.cookSha || "");
  const publishedAt = String(home.publishedAt || "");
  const cookedAt = String(home.cookedAt || meta.cookedAt || "");
  if (!/^[0-9a-f]{40}$/.test(cookSha) || !publishedAt) return "";
  const params = new URLSearchParams();
  params.set("cookSha", cookSha);
  params.set("publishedAt", publishedAt);
  if (cookedAt) params.set("cookedAt", cookedAt);
  return params.toString();
}

export function packURL(path, origin, pin) {
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
  const extra = String(pin || "").replace(/^\?/, "");
  if (extra) relative += `?${extra}`;
  if (!origin) return relative;
  // location.origin has no user:pass. Strip again in case the base still has them.
  try {
    return new URL(relative, new URL(String(origin)).origin).href;
  } catch {
    return null;
  }
}
