// Page-header clock. Device local time. Example: Mon 9/28 3:10 PM.
// A missing publish time stays "Updated —". Never substitute the current time.

const DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

export function publishClock(date) {
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) return "";
  const hour24 = date.getHours();
  const hour = hour24 % 12 || 12;
  const minute = String(date.getMinutes()).padStart(2, "0");
  const suffix = hour24 >= 12 ? "PM" : "AM";
  return `${DAYS[date.getDay()]} ${date.getMonth() + 1}/${date.getDate()} ${hour}:${minute} ${suffix}`;
}

export function parsePackTime(raw) {
  if (raw == null) return null;
  const text = String(raw).trim();
  if (!text) return null;
  const parsed = Date.parse(text);
  if (!Number.isFinite(parsed)) return null;
  return new Date(parsed);
}

export function updatedLine(raw) {
  const date = parsePackTime(raw);
  if (!date) return "Updated —";
  return `Updated ${publishClock(date)}`;
}

export function bannerText(onScreen, incoming) {
  const previous = parsePackTime(onScreen);
  const next = parsePackTime(incoming);
  if (!previous || !next || next.getTime() <= previous.getTime()) return null;
  return `New data uploaded ${publishClock(next)}`;
}

// First visit stores the time and does not raise the banner.
export function considerPublished(storage, key, incoming) {
  const previous = storage.getItem(key);
  const text = bannerText(previous, incoming);
  if (parsePackTime(incoming)) storage.setItem(key, String(incoming).trim());
  return text;
}

export function pct(value) {
  if (value == null || Number.isNaN(Number(value))) return "—";
  return `${Number(value).toFixed(2)}%`;
}

export function money(value) {
  if (value == null || value === "") return "—";
  const cleaned = typeof value === "string" ? value.replace(/[$,\s]/g, "") : value;
  const number = Number(cleaned);
  if (!Number.isFinite(number)) return "—";
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 2,
    minimumFractionDigits: 2,
  }).format(number);
}

export function num(value, digits = 0) {
  if (value == null || Number.isNaN(Number(value))) return "—";
  return new Intl.NumberFormat("en-US", {
    maximumFractionDigits: digits,
    minimumFractionDigits: digits,
  }).format(Number(value));
}

// Company-card figure. Same precision as SectionSummary.headlineText.
export function formatHeadline(section, value) {
  if (value == null || value === "" || Number.isNaN(Number(value))) return "—";
  const number = Number(value);
  if (section === "five_star") return number.toFixed(2);
  if (section === "pph" || section === "dynacap") return number.toFixed(1);
  if (section === "picker_scorecard") return num(number, 0);
  if (section === "lost_revenue" || section === "sales") return money(number);
  if (section === "labor") return pct(number);
  return `${number.toFixed(1)}%`;
}
