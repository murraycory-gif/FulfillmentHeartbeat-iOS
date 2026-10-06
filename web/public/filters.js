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
  denver: "West Region",
  intermountain: "West Region",
  seattle: "West Region",
  haggen: "West Region",
  portland: "West Region",
  jewel: "East Region",
};

const OFFICIAL_BY_KEY = {
  midatlantic: "Mid-Atlantic",
  jewel: "Jewel Osco",
  jewelosco: "Jewel Osco",
  denver: "Mountain West",
  intermountain: "Mountain West",
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
  if (key.includes("mountainwest") || key === "denver" || key === "intermountain") return "Mountain West";
  if (key.startsWith("haggen")) return "Haggen";
  if (key.startsWith("portland")) return "Portland";
  if (key.startsWith("seattle")) return "Seattle";
  if (key.startsWith("southwest")) return "Southwest";
  return "";
}

export function regionStoreCount(roster, regionName) {
  const wanted = String(regionName || "").replace(/\s*region$/i, "");
  if (!wanted) return 0;
  return (roster || []).filter((row) => {
    const home = String(regionForDivision(row && row.division) || "").replace(/\s*region$/i, "");
    return home === wanted;
  }).length;
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
  const addNumeric = (token) => {
    if (!/^\d+$/.test(token)) return;
    const value = String(parseInt(token, 10));
    keys.add(value);
    keys.add(value.padStart(2, "0"));
  };
  addNumeric(compactKey);
  // "62 DEN WEST & MTNS" and "J1 NORTH SHORE" share a code with the roster value "62" / "J1".
  const lead = compactKey.match(/^([a-z]*\d+)/);
  if (lead && lead[1] !== compactKey) {
    keys.add(lead[1]);
    addNumeric(lead[1]);
  }
  return keys;
}

// Schedule Quality keeps a sheet code (H1, or 88 for A9). The column uses the
// roster code plus the sheet's district name: A1 NE PHILA SUBURB, not H1….
function sheetLead(label) {
  return String(label || "").trim().split(/\s+/)[0] || "";
}

function sheetDistrictName(label) {
  const parts = String(label || "").trim().split(/\s+/);
  return parts.length > 1 ? parts.slice(1).join(" ") : "";
}

function sameRosterDistrict(roster, lead) {
  if (!roster || !lead || roster === lead) return roster === lead;
  const rosterCode = roster.toUpperCase();
  const sheetCode = lead.toUpperCase();
  const rosterAcme = rosterCode.match(/^A(\d)$/);
  const sheetAcme = sheetCode.match(/^H(\d)$/);
  if (rosterAcme && sheetAcme && rosterAcme[1] === sheetAcme[1]) return true;
  return rosterCode === "A9" && sheetCode === "88";
}

function rosterDistrictName(code) {
  const key = String(code || "").trim();
  if (!key) return "";
  return DISTRICT_NAMES[key] || DISTRICT_NAMES[key.toUpperCase()] || "";
}

// Bare sheet codes (A1, 82) use the same names as the filter chip and browse list.
export function shownDistrict(section, rowDistrict, rosterDistrict) {
  const roster = String(rosterDistrict || "").trim();
  const row = String(rowDistrict || "").trim();
  if (section !== "schedule_quality" || !roster) return row || "—";
  const lead = sheetLead(row);
  const name = sheetDistrictName(row);
  if (name && sameRosterDistrict(roster, lead)) return `${roster} ${name}`;
  if (!name && sameRosterDistrict(roster, lead)) {
    const known = rosterDistrictName(roster);
    if (known) return `${roster} ${known}`;
  }
  return roster;
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
const districtStoreCache = new WeakMap();

// Roster stores in this district. Schedule Quality rows often use a different
// code (roster A1, sheet H1) for the same store number.
export function storesForDistrict(roster, district) {
  const list = roster || [];
  let byDistrict = districtStoreCache.get(list);
  if (!byDistrict) {
    byDistrict = new Map();
    districtStoreCache.set(list, byDistrict);
  }
  const key = String(district || "").trim();
  if (byDistrict.has(key)) return byDistrict.get(key);
  const wanted = new Set();
  if (key) {
    for (const row of list) {
      if (!row || !row.store || !matchesDistrict(row.district || "", key)) continue;
      wanted.add(canonicalStore(row.store));
    }
  }
  byDistrict.set(key, wanted);
  return wanted;
}

// United U2–U7 have roster stores and no Schedule Quality facts. Say so.
// A matched district, including A1 joined onto H1 rows, stays quiet.
export function scheduleDistrictNote(section, filters, roster, matchedCount) {
  if (section !== "schedule_quality" || matchedCount > 0) return "";
  if (!filters || !filters.district) return "";
  if (storesForDistrict(roster, filters.district).size === 0) return "";
  return "No Schedule Quality data for this district.";
}

// Roster stores with no cooked rows. Prep is the same hole as Schedule Quality:
// the stores exist, the section file does not have them.
export function emptyScopeNote(section, filters, roster, matchedCount) {
  if (matchedCount > 0 || !filters || !filtersActive(filters)) return "";
  if (countStores(roster, filters) === 0) return "";
  if (section === "prep_not_ready") return "No Prep data for this scope.";
  if (section === "schedule_quality") {
    return scheduleDistrictNote(section, filters, roster, matchedCount) || "No Schedule Quality data for this scope.";
  }
  return "";
}

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

export function includesScope(row, filters, roster, section) {
  const division = row.division || "";
  if (filters.division) {
    if (!matchesDivision(division, filters.division)) return false;
  } else if (filters.region) {
    if (regionForDivision(division) !== filters.region) return false;
  }
  if (filters.district && !matchesDistrict(row.district || "", filters.district)) {
    const store = canonicalStore(row.store || "");
    const joined =
      section === "schedule_quality" &&
      store &&
      storesForDistrict(roster, filters.district).has(store);
    if (!joined) return false;
  }
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
    om: field === "om" || field === "division" || field === "region" ? "" : filters.om,
    store: "",
  };
  const values = new Set();
  for (const row of roster || []) {
    if (!includesScope(row, narrowed, roster)) continue;
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
        label: canonicalDivision(child.division) || child.division,
        value: child.value,
        count: child.count,
        region: line.region,
      });
    }
  }
  return rows;
}

// TODO: District names move into cooked rows with the PR #57 cook. Drop DISTRICT_NAMES then.
export const DISTRICT_NAMES = {
  "10": "CENTRAL CALIF.",
  "11": "SACRAMENTO",
  "12": "NO. SAC VALLEY",
  "14": "RENO / TAHOE",
  "15": "HAWAII",
  "16": "ANDRONICO'S",
  "21": "ANCHORAGE",
  "22": "DENALI",
  "23": "NORTH EVERETT",
  "24": "SOUTH EVERETT",
  "25": "BELLEVUE",
  "28": "KENT",
  "29": "TACOMA",
  "30": "OLYMPIA",
  "31": "CNTRL WASHINGTO",
  "32": "SPOKANE WEST",
  "33": "SPOKANE EAST",
  "39": "HAGGEN",
  "41": "CENTRAL COAST",
  "42": "VENTURA",
  "43": "CENTRAL CALI",
  "44": "SANFERN VALLEY",
  "46": "FOOTHILLS",
  "47": "PAVILIONS",
  "49": "LOS ANGELES",
  "50": "N ORANGE COUNTY",
  "51": "CTRL ORANGE CTY",
  "52": "S ORANGE COUNTY",
  "54": "DESERTS",
  "55": "INLAND EMPIRE",
  "58": "SW SAN DIEGO",
  "59": "SE SAN DIEGO",
  "61": "NORTH COLORADO",
  "62": "DEN WEST & MTNS",
  "63": "NORTHERN PLAINS",
  "65": "DENVER/SPRINGS",
  "66": "SOUTH CO & NM",
  "72": "WEST PORTLAND",
  "73": "VANCOUVER",
  "74": "EAST PORTLAND",
  "75": "SALEM",
  "76": "EUGENE",
  "77": "SOUTHERN OREGON",
  "78": "EASTERN OREGON",
  "82": "BALTIMORE",
  "83": "SE SUBURBAN MD",
  "84": "FAIRFAX",
  "85": "NW DC/CENTRL MD",
  "86": "WASHINGTONMETRO",
  "87": "ARLGTN/ALXNDRIA",
  "91": "STUC/COUNTRY/SC",
  "92": "S PHX/ELPASO/L",
  "93": "E TUC / S PHX",
  "94": "W AZ/RIVER/YUMA",
  "95": "E VLY/W MNT",
  "96": "N VEGAS / UTAH",
  "97": "S VEGAS/PAHRUMP",
  "01": "SANTA ROSA/N CO",
  "02": "MARIN / I-80",
  "03": "SAN FRANCISCO",
  "04": "OAKLAND",
  "06": "PENNINSULA",
  "07": "CONTRA COSTA",
  "08": "SAN JOSE",
  "09": "SANTA CRUZ",
  "A1": "NE PHILA SUBURB",
  "A2": "NY/CT",
  "A3": "MAIN LINE SUBUR",
  "A4": "DELAWARE/MARYLA",
  "A5": "CENTRAL NJ",
  "A6": "NORTHWEST NJ",
  "A7": "JERSEY SHORE",
  "A8": "NORTHEAST NJ",
  "A9": "KINGS/BALDUCCIS",
  "B1": "BOSTON/STAR MAR",
  "B2": "N CENTRAL MA",
  "B3": "NEW HAMPSHIRE",
  "B4": "MAINE",
  "B5": "VERMONT",
  "B6": "SE MA/CAPE",
  "B7": "S CENTRAL MA/RI",
  "D1": "DFW-SOUTHWEST",
  "D2": "DFW-NORTHWEST",
  "D3": "DFW-CENTRAL",
  "D4": "DFW-NORTHEAST",
  "D5": "DFW-SOUTHEAST",
  "D6": "RANDALLS",
  "D7": "LOUISIANA",
  "I1": "EASTERN TV",
  "I2": "EASTERN IDAHO",
  "I3": "WESTERN MONTANA",
  "I4": "EASTERN MONTANA",
  "I5": "WESTERN TV",
  "J1": "NORTH SHORE",
  "J2": "NORTHWEST",
  "J3": "CHICAGO",
  "J4": "OHARE",
  "J5": "WESTERN SUBURBS",
  "J6": "SE CHICAGO NW I",
  "J7": "SW SIDE",
  "J8": "SOUTHWEST QUADS",
  "J9": "FAR WEST",
  "N0": "N AZ/N PHX/GAL",
  "N1": "CTR PHX/N SCTS",
  "N2": "PHX/SCOTTSDALE"
};

export function storeLabel(store, name) {
  const id = canonicalStore(store);
  const padded = /^\d+$/.test(id) ? id.padStart(4, "0") : id;
  const title = String(name || "").trim();
  return title ? `${padded} · ${title}` : padded;
}

export function regionShort(region) {
  return String(region || "").replace(/\s*region$/i, "");
}

export function districtLabel(code, names = DISTRICT_NAMES) {
  const key = String(code || "").trim();
  const name = (names && (names[key] || names[key.toUpperCase()])) || "";
  return name ? `${key} · ${name}` : key;
}

export function scopeChips(filters) {
  const chips = [{ level: "company", label: "Company" }];
  if (!filters) return chips;
  if (filters.region) chips.push({ level: "region", label: regionShort(filters.region) });
  if (filters.division) chips.push({ level: "division", label: canonicalDivision(filters.division) || filters.division });
  if (filters.district) chips.push({ level: "district", label: String(filters.district) });
  if (filters.om) chips.push({ level: "om", label: String(filters.om) });
  if (filters.store) chips.push({ level: "store", label: storeLabel(filters.store) });
  return chips;
}

const SCOPE_LEVELS = ["region", "division", "district", "om", "store"];

export function filtersUpTo(filters, level) {
  if (!level || level === "company") return emptyFilters();
  const next = emptyFilters();
  for (const key of SCOPE_LEVELS) {
    next[key] = (filters && filters[key]) || "";
    if (key === level) break;
  }
  return next;
}

function rosterRows(roster) {
  return (roster || []).filter((row) => row && row.store);
}

export function cascadePick(roster, pick) {
  const rows = rosterRows(roster);
  const kind = pick && pick.kind;
  const value = (pick && pick.value) || "";
  const next = emptyFilters();
  if (kind === "region") {
    next.region = value;
    return next;
  }
  if (kind === "division") {
    const name = canonicalDivision(value) || value;
    next.division = name;
    next.region = regionForDivision(name) || "";
    return next;
  }
  if (kind === "district") {
    const sample = rows.find((row) => matchesDistrict(row.district || "", value));
    next.district = sample ? sample.district : value;
    if (sample) {
      next.division = canonicalDivision(sample.division) || sample.division || "";
      next.region = regionForDivision(next.division) || "";
    }
    return next;
  }
  if (kind === "om") {
    const matched = rows.filter((row) => isPersonOm(row.om) && matchesOM(row.om, value));
    next.om = matched[0] ? matched[0].om : value;
    const divisions = [...new Set(matched.map((row) => canonicalDivision(row.division) || row.division).filter(Boolean))];
    const districts = [...new Set(matched.map((row) => String(row.district || "")).filter(Boolean))];
    const homes = [...new Set(divisions.map((name) => regionForDivision(name)).filter(Boolean))];
    if (divisions.length === 1) next.division = divisions[0];
    if (homes.length === 1) next.region = homes[0];
    if (districts.length === 1) next.district = districts[0];
    return next;
  }
  if (kind === "store") {
    const id = canonicalStore(value);
    const sample = rows.find((row) => canonicalStore(row.store) === id);
    next.store = id;
    if (sample) {
      if (isPersonOm(sample.om)) next.om = sample.om;
      next.district = sample.district || "";
      next.division = canonicalDivision(sample.division) || sample.division || "";
      next.region = regionForDivision(next.division) || "";
    }
    return next;
  }
  return next;
}

function queryText(query) {
  return String(query || "").trim().toLowerCase();
}

function storeQueryHit(store, name, query) {
  const q = queryText(query);
  if (name && String(name).toLowerCase().includes(q)) return true;
  const digits = q.replace(/\D/g, "").replace(/^0+/, "");
  if (!digits || digits !== q.replace(/^0+/, "")) return false;
  const id = canonicalStore(store);
  return id === digits || id.startsWith(digits);
}

export function searchScope(roster, filters, query, names = DISTRICT_NAMES) {
  const q = queryText(query);
  if (!q) return [];
  const scope = filters || emptyFilters();
  const rows = rosterRows(roster).filter((row) => includesScope(row, { ...scope, store: "" }));
  const groups = [];
  const take = (hits) => hits.slice(0, 6);

  if (!scope.region) {
    const hits = regions()
      .filter((id) => {
        const label = regionShort(id);
        if (!`${label} ${id}`.toLowerCase().includes(q)) return false;
        return rows.some((row) => regionForDivision(row.division) === id);
      })
      .map((id) => ({ kind: "region", value: id, label: regionShort(id) }));
    if (hits.length) groups.push({ group: "Region", hits: take(hits) });
  }

  if (!scope.division) {
    const hits = divisionsFor(scope)
      .filter((name) => name.toLowerCase().includes(q) && rows.some((row) => matchesDivision(row.division, name)))
      .map((name) => ({
        kind: "division",
        value: name,
        label: name,
        detail: regionShort(regionForDivision(name) || ""),
      }));
    if (hits.length) groups.push({ group: "Division", hits: take(hits) });
  }

  if (!scope.district) {
    const seen = new Set();
    const hits = [];
    for (const row of rows) {
      const code = String(row.district || "").trim();
      if (!code || seen.has(code)) continue;
      const label = districtLabel(code, names);
      if (!`${code} ${label}`.toLowerCase().includes(q)) continue;
      seen.add(code);
      hits.push({ kind: "district", value: code, label, detail: canonicalDivision(row.division) || row.division || "" });
    }
    hits.sort((a, b) => a.label.localeCompare(b.label, undefined, { numeric: true }));
    if (hits.length) groups.push({ group: "District", hits: take(hits) });
  }

  if (!scope.om) {
    const seen = new Set();
    const hits = [];
    for (const row of rows) {
      if (!isPersonOm(row.om)) continue;
      const key = String(row.om).trim().toLowerCase();
      if (seen.has(key) || !key.includes(q)) continue;
      seen.add(key);
      hits.push({ kind: "om", value: row.om, label: row.om, detail: canonicalDivision(row.division) || "" });
    }
    hits.sort((a, b) => a.label.localeCompare(b.label));
    if (hits.length) groups.push({ group: "OM", hits: take(hits) });
  }

  const storeHits = [];
  const seenStores = new Set();
  for (const row of rows) {
    const id = canonicalStore(row.store);
    if (seenStores.has(id) || !storeQueryHit(id, row.name, q)) continue;
    seenStores.add(id);
    const digits = q.replace(/\D/g, "").replace(/^0+/, "");
    storeHits.push({
      kind: "store",
      value: id,
      label: storeLabel(id, row.name),
      detail: [canonicalDivision(row.division), row.district, isPersonOm(row.om) ? row.om : ""].filter(Boolean).join(" · "),
      exact: id === digits,
    });
  }
  storeHits.sort(
    (a, b) => Number(b.exact) - Number(a.exact) || a.label.localeCompare(b.label, undefined, { numeric: true }),
  );
  if (storeHits.length) groups.push({ group: "Store", hits: take(storeHits) });
  return groups;
}

export function browseScope(filters, kind, value) {
  const next = { ...(filters || emptyFilters()), [kind]: value };
  if (kind === "region") {
    next.division = "";
    next.district = "";
    next.om = "";
    next.store = "";
  }
  return next;
}

export function browseLevel(roster, filters, names = DISTRICT_NAMES) {
  const base = filters || emptyFilters();
  const row = (kind, value, label) => {
    const next = browseScope(base, kind, value);
    return { kind, value, label, count: countStores(roster, next) };
  };
  if (!base.region) {
    return {
      level: "region",
      title: "Region",
      rows: regions().map((id) => row("region", id, regionShort(id))),
    };
  }
  if (!base.division) {
    return {
      level: "division",
      title: "Division",
      rows: divisionsFor(base)
        .map((name) => row("division", name, name))
        .filter((item) => item.count > 0),
    };
  }
  if (!base.district) {
    return {
      level: "district",
      title: "District",
      rows: optionValues(roster, base, "district").map((code) => row("district", code, districtLabel(code, names))),
    };
  }
  if (!base.om) {
    return {
      level: "om",
      title: "OM",
      rows: optionValues(roster, base, "om").map((name) => row("om", name, name)),
    };
  }
  return {
    level: "store",
    title: "Store",
    rows: optionValues(roster, base, "store").map((id) => {
      const sample = rosterRows(roster).find((item) => canonicalStore(item.store) === id);
      return { kind: "store", value: id, label: storeLabel(id, sample && sample.name), count: 1 };
    }),
  };
}
