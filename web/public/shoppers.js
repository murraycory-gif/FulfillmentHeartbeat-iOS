// Shopper identity and PPH order for the web lists.
// The PPH sheet is store totals. Shopper PPH, hours, and orders are the
// Picker ScoreCard rows already in the pack. Pick Path shoppers are a
// separate employee sheet and do not include hours.

export function shopperHoursText(value, format) {
  const number = Number(value);
  if (value != null && value !== "" && Number.isFinite(number) && number < 0) return "source data issue";
  return format(value);
}

export function shopperPph(row) {
  const payload = (row && row.payload) || {};
  const value = payload.pph;
  if (value == null || value === "") return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

// A shopper PPH at or below 0, or above 300, is not a usable rate.
// The goal split still counts these rows. Averages leave them out.
export function PPH_SOURCE_CHECK(value) {
  if (value == null || value === "") return false;
  const number = Number(value);
  if (!Number.isFinite(number)) return false;
  return number <= 0 || number > 300;
}

export function shopperPphLabel(value, format) {
  const shown = format(value);
  return PPH_SOURCE_CHECK(value) ? `${shown} check source` : shown;
}

export function shopperPphSummary(rows) {
  let atGoal = 0;
  let between = 0;
  let below = 0;
  let missing = 0;
  let flagged = 0;
  let sum = 0;
  let counted = 0;
  let weighted = 0;
  let weight = 0;
  for (const row of rows || []) {
    const pph = shopperPph(row);
    if (pph == null) {
      missing += 1;
      continue;
    }
    if (pph >= 80) atGoal += 1;
    else if (pph >= 74) between += 1;
    else below += 1;
    const hours = Number(((row && row.payload) || {}).pick_hours);
    if (Number.isFinite(hours) && hours > 0) {
      weighted += pph * hours;
      weight += hours;
    }
    if (PPH_SOURCE_CHECK(pph)) {
      flagged += 1;
      continue;
    }
    sum += pph;
    counted += 1;
  }
  return {
    withPph: atGoal + between + below,
    atGoal,
    between,
    below,
    missing,
    flagged,
    average: counted ? sum / counted : null,
    // Hours-weighted mean of these shopper rows. It is not a workbook Total row.
    storeAverage: weight ? weighted / weight : null,
  };
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
    const leftFlag = leftPph != null && PPH_SOURCE_CHECK(leftPph);
    const rightFlag = rightPph != null && PPH_SOURCE_CHECK(rightPph);
    if (leftFlag !== rightFlag) return leftFlag ? 1 : -1;
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
