// Share email. Same idea as PulseMail.briefPacket: subject is the filter,
// body is the pages the user picked. Mail opens with mailto. No attachment.

export function healthWord(health) {
  if (health === "good") return "Healthy";
  if (health === "watch") return "Watch";
  if (health === "risk") return "At risk";
  return "No data";
}

export function shareSubject(scope, stamp) {
  return `Fulfillment Heartbeat — ${scope || "Total Company"} — ${stamp || ""}`.trim();
}

export function sharePages(mode, currentId, picked, catalog) {
  const pages = catalog || [];
  if (mode === "all") return pages.slice();
  if (mode === "pick") {
    const wanted = new Set(picked || []);
    return pages.filter((page) => wanted.has(page.id));
  }
  return pages.filter((page) => page.id === currentId);
}

export function shareBrief({ scope, stamp, updated, pages }) {
  const lines = [
    "Fulfillment Heartbeat",
    "",
    scope || "Total Company",
    stamp || "",
    updated || "",
    `Pages: ${(pages || []).map((page) => page.title).join(", ")}`,
    "",
  ];
  for (const page of pages || []) {
    lines.push(String(page.title || "").toUpperCase());
    if (page.detail) lines.push(page.detail);
    lines.push("");
  }
  lines.push("Sent from Fulfillment Heartbeat");
  return lines.filter((line) => line != null).join("\n");
}

export function mailtoURL({ to = "", subject = "", body = "" }) {
  const address = String(to || "")
    .split(/[,\s;]+/)
    .map((part) => part.trim())
    .filter(Boolean)
    .join(",");
  return `mailto:${address}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
}
