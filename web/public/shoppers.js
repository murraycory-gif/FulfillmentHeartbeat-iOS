// Shopper identity and PPH order for the web lists.
// The PPH sheet is store totals. Shopper PPH, hours, and orders are the
// Picker ScoreCard rows already in the pack. Pick Path shoppers are a
// separate employee sheet and do not include hours.

export function shopperPph(row) {
  const payload = (row && row.payload) || {};
  const value = payload.pph;
  if (value == null || value === "") return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

// 80 is the goal. 74 up to the goal is watch. Below 74 is at risk.
// A blank PPH stays none so the list does not invent a color.
export function pphBar(value) {
  if (value == null || value === "" || !Number.isFinite(Number(value))) return "none";
  const number = Number(value);
  if (number >= 80) return "good";
  if (number >= 74) return "watch";
  return "risk";
}

export function shopperIdentity(row) {
  const name = String((row && row.shopper) || "").trim();
  const id = String((row && row.shopperId) || "").trim();
  if (name && id && name !== id) return `${name} · ${id}`;
  return name || id || "";
}

export function sortShoppersByPph(rows) {
  return (rows || []).slice().sort((left, right) => {
    const leftPph = shopperPph(left);
    const rightPph = shopperPph(right);
    if (leftPph == null && rightPph == null) return shopperIdentity(left).localeCompare(shopperIdentity(right));
    if (leftPph == null) return 1;
    if (rightPph == null) return -1;
    if (leftPph !== rightPph) return leftPph - rightPph;
    const store = String(left.store || "").localeCompare(String(right.store || ""), undefined, { numeric: true });
    if (store) return store;
    return shopperIdentity(left).localeCompare(shopperIdentity(right));
  });
}

export function shopperMatchesQuery(row, query) {
  const needle = String(query || "").trim().toLowerCase();
  if (!needle) return true;
  const hay = [row && row.shopper, row && row.shopperId, row && row.store, shopperIdentity(row)]
    .filter((part) => part != null && part !== "")
    .join(" ")
    .toLowerCase();
  return hay.includes(needle);
}

// Keep a metric column only when some row actually carries that field.
export function metricsInSource(rows, columns) {
  return (columns || []).filter((column) =>
    (rows || []).some((row) => {
      const payload = (row && row.payload) || {};
      return (column.keys || []).some((key) => payload[key] != null && payload[key] !== "");
    }),
  );
}
