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

function blockLines(block) {
  const lines = [String(block.title || "").toUpperCase()];
  const status = [block.status, block.count].filter(Boolean).join(" · ");
  if (status) lines.push(status);
  if (block.figure) lines.push(String(block.figure));
  if (block.note) lines.push(String(block.note));
  for (const metric of block.metrics || []) {
    lines.push(`${metric.label}    ${metric.value}`);
  }
  return lines;
}

export function shareBrief({ scope, stamp, updated, pages }) {
  const lines = [
    "FULFILLMENT HEARTBEAT",
    "",
    scope || "Total Company",
    stamp || "",
    updated || "",
    "",
    "PAGES",
    (pages || []).map((page) => page.title).filter(Boolean).join(", "),
    "",
  ];
  for (const page of pages || []) {
    lines.push("------------------------------");
    lines.push(String(page.title || "").toUpperCase());
    lines.push("------------------------------");
    lines.push("");
    if (page.blocks && page.blocks.length) {
      for (const block of page.blocks) {
        lines.push(...blockLines(block));
        lines.push("");
      }
    } else if (page.detail) {
      lines.push(page.detail);
      lines.push("");
    }
  }
  lines.push("Sent from Fulfillment Heartbeat");
  return lines.join("\n");
}

function escHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function blockHtml(block) {
  const status = [block.status, block.count].filter(Boolean).join(" · ");
  const metrics = (block.metrics || [])
    .map(
      (metric) =>
        `<tr><td style="padding:6px 0;color:#5C677A;font-size:14px">${escHtml(metric.label)}</td><td style="padding:6px 0;text-align:right;font-weight:700;font-size:16px;color:#141A29">${escHtml(metric.value)}</td></tr>`,
    )
    .join("");
  return `<table width="100%" cellpadding="0" cellspacing="0" style="width:100%;background:#FFFFFF;border:1px solid #E4E9F4;border-radius:12px;margin:0 0 12px"><tr><td style="padding:14px 16px"><div style="font-size:16px;line-height:22px;font-weight:700;color:#141A29">${escHtml(String(block.title || "").toUpperCase())}</div>${status ? `<div style="margin-top:4px;color:#5C677A;font-size:14px;line-height:20px">${escHtml(status)}</div>` : ""}${block.figure ? `<div style="margin-top:8px;font-size:28px;line-height:32px;font-weight:700;color:#003DA5">${escHtml(block.figure)}</div>` : ""}${block.note ? `<div style="margin-top:8px;color:#3D4658;font-size:14px;line-height:20px">${escHtml(block.note)}</div>` : ""}${metrics ? `<table width="100%" cellpadding="0" cellspacing="0" style="width:100%;margin-top:10px;border-top:1px solid #E4E9F4">${metrics}</table>` : ""}</td></tr></table>`;
}

export function shareHtml({ scope, stamp, updated, pages }) {
  const sections = (pages || [])
    .map((page) => {
      const blocks = page.blocks && page.blocks.length ? page.blocks : [{ title: page.title, note: page.detail || "" }];
      return `<h2 style="margin:20px 0 8px;font-size:13px;line-height:18px;letter-spacing:.06em;color:#003DA5">${escHtml(String(page.title || "").toUpperCase())}</h2>${blocks.map(blockHtml).join("")}`;
    })
    .join("");
  return `<!DOCTYPE html><html><head><meta charset="utf-8"></head><body style="margin:0;padding:24px 16px;background:#F5F7FC;color:#141A29;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif"><div style="max-width:640px;margin:0 auto"><div style="font-size:26px;line-height:32px;font-weight:700;color:#003DA5">Fulfillment Heartbeat</div><p style="margin:10px 0 0;font-size:16px;line-height:24px;color:#3D4658">${escHtml(scope || "Total Company")}</p><p style="margin:4px 0 0;font-size:14px;line-height:20px;color:#5C677A">${escHtml(stamp || "")}<br>${escHtml(updated || "")}</p>${sections}<p style="margin:18px 0 0;color:#5C677A;font-size:14px">Sent from Fulfillment Heartbeat</p></div></body></html>`;
}

export function shareEml({ to = "", subject = "", plain = "", html = "" }) {
  const boundary = "hb-share-brief";
  return [
    `To: ${to || ""}`,
    `Subject: ${subject || ""}`,
    "X-Unsent: 1",
    "MIME-Version: 1.0",
    `Content-Type: multipart/alternative; boundary="${boundary}"`,
    "",
    `--${boundary}`,
    "Content-Type: text/plain; charset=utf-8",
    "Content-Transfer-Encoding: 8bit",
    "",
    plain,
    "",
    `--${boundary}`,
    "Content-Type: text/html; charset=utf-8",
    "Content-Transfer-Encoding: 8bit",
    "",
    html,
    "",
    `--${boundary}--`,
    "",
  ].join("\r\n");
}

export function mailtoURL({ to = "", subject = "", body = "" }) {
  const address = String(to || "")
    .split(/[,\s;]+/)
    .map((part) => part.trim())
    .filter(Boolean)
    .join(",");
  return `mailto:${address}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
}
