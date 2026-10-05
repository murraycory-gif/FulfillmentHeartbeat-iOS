// Grain filters. Same membership rules as DashboardFilters / MarketRegion:
// region, division, district, OM, store. One selected value per grain.

const OFFICIAL = [
  "Shaws",
  "Mid-Atlantic",
  "Jewel Osco",
  "Southern",
  "United",
  "Southwest",
  "NorCal",
  "SoCal",
  "Mountain West",
  "Seattle",
  "Haggen",
  "Portland",
];

const REGIONS = [
  { id: "East Region", markets: ["Shaws", "Mid-Atlantic", "Jewel Osco"] },
  { id: "South Region", markets: ["Southern", "United", "Southwest"] },
  { id: "California Region", markets: ["NorCal", "SoCal"] },
  { id: "West Region", markets: ["Mountain West", "Seattle", "Haggen", "Portland"] },
];

const MARKET_TO_REGION = {
  shaws: "East Region",
  midatlantic: "East Region",
  jewelosco: "East Region",
  southern: "South Region",
  united: "South Region",
  southwest: "South Region",
  unitedtexas: "South Region",
  unitedsupermarkets: "South Region",
  norcal: "California Region",
  socal: "California Region",
  nocal: "California Region",
  northerncalifornia: "California Region",
  norcalifornia: "California Region",
  southerncalifornia: "California Region",
  socalifornia: "California Region",
  southerncal: "California Region",
  mountainwest: "West Region",
  seattle: "West Region",
  haggen: "West Region",
  portland: "West Region",
};

const OFFICIAL_BY_KEY = {
  midatlantic: "Mid-Atlantic",
  jewelosco: "Jewel Osco",
  nocal: "NorCal",
  northerncalifornia: "NorCal",
  norcalifornia: "NorCal",
  southerncalifornia: "SoCal",
  socalifornia: "SoCal",
  southerncal: "SoCal",
  mountainwest: "Mountain West",
  unitedtexas: "United",
  unitedsupermarkets: "United",
};

const REGION_TITLES = {
  east: "East Region",
  eastregion: "East Region",
  south: "South Region",
  southregion: "South Region",
  west: "West Region",
  westregion: "West Region",
  california: "California Region",
  californiaregion: "California Region",
  calif: "California Region",
  ca: "California Region",
};

const IGNORED = new Set([
  "total",
  "grandtotal",
  "all",
  "alldivisions",
  "allmarkets",
  "company",
  "na",
  "none",
  "null",
  "blank",
  "unassigned",
  "unknown",
]);

for (const name of OFFICIAL) OFFICIAL_BY_KEY[lookupKey(name)] = name;

export function lookupKey(raw) {
  return String(raw || "")
    .toLowerCase()
    .replace(/[^a-z0-9]/g, "");
}

function stripSuffix(key) {
  for (const suffix of ["division", "div", "market", "banner", "region"]) {
    if (key.endsWith(suffix) && key.length > suffix.length) return key.slice(0, -suffix.length);
  }
  return key;
}

export function canonicalDivision(raw) {
  const trimmed = String(raw || "").trim();
  if (!trimmed) return "";
  if (OFFICIAL.includes(trimmed)) return trimmed;
  let key = stripSuffix(lookupKey(trimmed));
  if (!key || IGNORED.has(key) || REGION_TITLES[key]) return "";
  if (OFFICIAL_BY_KEY[key]) return OFFICIAL_BY_KEY[key];
  if (key.startsWith("united")) return "United";
  if (key.includes("jewel")) return "Jewel Osco";
  if (key.startsWith("shaw")) return "Shaws";
  if (key.includes("mountainwest")) return "Mountain West";
  if (key.startsWith("haggen")) return "Haggen";
  if (key.startsWith("portland")) return "Portland";
  if (key.startsWith("seattle")) return "Seattle";
  if (key.startsWith("southwest")) return "Southwest";
  return "";
}

export function regionForDivision(raw) {
  const key = lookupKey(raw);
  if (REGION_TITLES[key]) return REGION_TITLES[key];
  const bare = key.endsWith("region") && key.length > 6 ? key.slice(0, -6) : key;
  if (REGION_TITLES[bare] && bare !== key) return REGION_TITLES[bare];
  if (MARKET_TO_REGION[key]) return MARKET_TO_REGION[key];
  const name = canonicalDivision(raw);
  if (name && MARKET_TO_REGION[lookupKey(name)]) return MARKET_TO_REGION[lookupKey(name)];
  return "";
}

function regionOfKey(key) {
  const bare = key.endsWith("region") && key.length > 6 ? key.slice(0, -6) : key;
  return REGION_TITLES[key] || REGION_TITLES[bare] || MARKET_TO_REGION[key] || "";
}

export function matchesDivision(lhs, rhs) {
  const aKey = lookupKey(lhs);
  const bKey = lookupKey(rhs);
  if (!aKey || !bKey) return false;
  if (aKey === bKey) return true;
  const aOfficial = OFFICIAL_BY_KEY[aKey];
  const bOfficial = OFFICIAL_BY_KEY[bKey];
  if (aOfficial && bOfficial) return aOfficial === bOfficial;
  const aRegion = regionOfKey(aKey);
  const bRegion = regionOfKey(bKey);
  if (aRegion && bRegion) return aRegion === bRegion;
  return false;
}

export function canonicalStore(raw) {
  let trimmed = String(raw || "").trim();
  if (trimmed.includes("|")) trimmed = trimmed.split("|")[0].trim();
  trimmed = trimmed.replace(/^store\s*#?\s*/i, "");
  if (/^\d+$/.test(trimmed)) return String(parseInt(trimmed, 10));
  const cleaned = trimmed.replace(/,/g, "");
  if (/^\d+(\.0+)?$/.test(cleaned)) {
    const value = Number(cleaned);
    if (value > 0 && value < 1_000_000) return String(value);
  }
  const digits = (trimmed.match(/^\d+/) || [""])[0];
  if (digits && digits.length <= 6) return String(parseInt(digits, 10));
  return trimmed;
}

function compact(raw) {
  return String(raw || "")
    .toLowerCase()
    .replace(/[^a-z0-9]/g, "");
}

export function districtKeys(raw) {
  const compactKey = compact(String(raw || "").replace(/^district\s+/i, ""));
  if (!compactKey) return new Set();
  const keys = new Set([compactKey]);
  if (/^\d+$/.test(compactKey)) {
    const value = String(parseInt(compactKey, 10));
    keys.add(value);
    keys.add(value.padStart(2, "0"));
  }
  return keys;
}

export function matchesDistrict(lhs, rhs) {
  const left = districtKeys(lhs);
  const right = districtKeys(rhs);
  if (left.size === 0 || right.size === 0) return false;
  for (const key of left) if (right.has(key)) return true;
  return false;
}

export function matchesOM(lhs, rhs) {
  const a = String(lhs || "").trim().toLowerCase().replace(/\s+/g, " ");
  const b = String(rhs || "").trim().toLowerCase().replace(/\s+/g, " ");
  return a.length > 0 && a === b;
}

// Two or more letter tokens, no digits. "Chicago 1" and "NorCal 04" are areas.
export function isPersonOm(raw) {
  const name = String(raw || "").trim().replace(/\s+/g, " ");
  if (!name || /\d/.test(name)) return false;
  const tokens = name.split(/[\s/]+/).filter((token) => /[A-Za-z]/.test(token));
  return tokens.length >= 2;
}

const omStoreCache = new WeakMap();

// Store numbers whose roster row carries this OM. Section rows are not the map.
export function storesForOm(roster, om) {
  const list = roster || [];
  let byOm = omStoreCache.get(list);
  if (!byOm) {
    byOm = new Map();
    omStoreCache.set(list, byOm);
  }
  const key = String(om || "").trim().toLowerCase().replace(/\s+/g, " ");
  if (byOm.has(key)) return byOm.get(key);
  const wanted = new Set();
  for (const row of list) {
    if (!row || !row.store || !matchesOM(row.om, om)) continue;
    wanted.add(canonicalStore(row.store));
  }
  byOm.set(key, wanted);
  return wanted;
}

export function emptyFilters() {
  return { region: "", division: "", district: "", om: "", store: "" };
}

export function filtersActive(filters) {
  return Boolean(filters.region || filters.division || filters.district || filters.om || filters.store);
}

export function includesScope(row, filters, roster) {
  const division = row.division || "";
  if (filters.division) {
    if (!matchesDivision(division, filters.division)) return false;
  } else if (filters.region) {
    if (regionForDivision(division) !== filters.region) return false;
  }
  if (filters.district && !matchesDistrict(row.district || "", filters.district)) return false;
  if (filters.om) {
    if (roster) {
      if (!storesForOm(roster, filters.om).has(canonicalStore(row.store || ""))) return false;
    } else if (!matchesOM(row.om || "", filters.om)) return false;
  }
  if (filters.store && canonicalStore(row.store || "") !== canonicalStore(filters.store)) return false;
  return true;
}

export function regions() {
  return REGIONS.map((region) => region.id);
}

export function divisionsFor(filters) {
  if (!filters.region) return OFFICIAL.slice();
  const region = REGIONS.find((item) => item.id === filters.region);
  return region ? region.markets.slice() : OFFICIAL.slice();
}

export function optionValues(roster, filters, field) {
  const narrowed = {
    region: field === "region" ? "" : filters.region,
    division: field === "division" || field === "region" ? "" : filters.division,
    district: field === "district" || field === "division" || field === "region" ? "" : filters.district,
    om: field === "om" || field === "district" || field === "division" || field === "region" ? "" : filters.om,
    store: "",
  };
  const values = new Set();
  for (const row of roster || []) {
    if (!includesScope(row, narrowed)) continue;
    const value = row[field] || "";
    if (!value) continue;
    if (field === "om" && !isPersonOm(value)) continue;
    values.add(field === "store" ? canonicalStore(value) : value);
  }
  return [...values].sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
}

export function scopeLabel(filters) {
  if (!filtersActive(filters)) return "Total Company";
  return [filters.region, filters.division, filters.district, filters.om, filters.store]
    .filter(Boolean)
    .join(" · ");
}

export function finestScope(filters) {
  if (filters.store) return `store:${canonicalStore(filters.store)}`;
  if (filters.om) return `om:${String(filters.om).trim()}`;
  if (filters.district) return `district:${String(filters.district).trim()}`;
  if (filters.division) {
    const name = canonicalDivision(filters.division);
    return name ? `division:${name}` : "";
  }
  if (filters.region) return `region:${filters.region}`;
  return "company";
}

export function countStores(roster, filters) {
  const seen = new Set();
  for (const row of roster || []) {
    if (!row.store || !includesScope(row, filters)) continue;
    seen.add(canonicalStore(row.store));
  }
  return seen.size;
}

export function regionName(raw) {
  return regionForDivision(raw) || regionForDivision(`${raw} Region`);
}

// Seat lines are region scope rows (label "East"), not store rows.
export function regionLineInScope(line, filters, roster) {
  if (!filtersActive(filters)) return true;
  const lineRegion = regionName(line && line.region);
  if (!lineRegion) return false;
  if (filters.region && lineRegion !== filters.region) return false;
  if (filters.division && regionForDivision(filters.division) !== lineRegion) return false;
  if (filters.district || filters.om || filters.store) {
    const regions = new Set();
    for (const row of roster || []) {
      if (!includesScope(row, filters)) continue;
      const region = regionForDivision(row.division);
      if (region) regions.add(region);
    }
    if (!regions.has(lineRegion)) return false;
  }
  return true;
}

const SCOPE_COUNT_SKIP = new Set(["picker_scorecard"]);

// Roster count when the cook has stores. Otherwise the largest store count
// on a visible seat line. Picker lines are shoppers, not stores.
export function scopeStoreCount(roster, filters, lines) {
  const stores = countStores(roster, filters);
  if (stores > 0) return stores;
  let max = 0;
  for (const line of lines || []) {
    if (!regionLineInScope(line, filters, roster)) continue;
    if (SCOPE_COUNT_SKIP.has(line.section)) continue;
    const count = Number(line.count);
    if (Number.isFinite(count) && count > max) max = count;
  }
  return max;
}

// Company: cooked regions and their division children.
// Region: that region and its children. Division: that child only.
// District, OM, and store stay on the store rows. No averaged grade.
export function sectionGrainRows(lines, section, filters, roster) {
  if (filters.district || filters.om || filters.store) return [];
  const visible = (lines || []).filter(
    (line) => line && line.section === section && regionLineInScope(line, filters, roster),
  );
  const rows = [];
  for (const line of visible) {
    if (!filters.division) {
      rows.push({
        grain: "region",
        label: line.region,
        value: line.value,
        count: line.count,
      });
    }
    for (const child of line.children || []) {
      if (filters.division && !matchesDivision(child.division, filters.division)) continue;
      rows.push({
        grain: "division",
        label: child.division,
        value: child.value,
        count: child.count,
        region: line.region,
      });
    }
  }
  return rows;
}
