# Missing-data audit — HB-0828.438 (fine-comb)

**Stamp audited:** `HB-0828.438` / 1.0 (764) @ `2b6cc1d` (`cursor/raise-company-seat-cap-84d2`)
**Company pack (today):** ~26.4MB thin seat. Sales grain `company` = **$79,870,895 / +16.23%** (week 202629).
**Do not fight:** [PR #13](https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS/pull/13) is **HB-0828.439 / 765** (iPhone Pages present + chrome-then-force-load). This audit does **not** duplicate that nav/paint tip.
**Code change:** none. Soft FAIL blanks live on the same `ensureSectionLoaded` / `installSectionSlice` path 439 already patches.
**Ops grain:** there is no separate Ops filter. **OM** (`FilterFocus.om`, Operations manager) is the Ops seat.

Filter-table lock (code matches QA):

| Seat | Rollup tables | Store table |
|---|---|---|
| Company | Regions + Markets (`.region` + `.division`) | hidden |
| Region | Markets | hidden |
| Division | Districts | Stores |
| District | — | Stores once |
| Store | — | that store |
| OM / Ops | — | that OM’s stores |

`PulseSeatPack.Key.forSeat` is **store → OM → district → company**. Region and Division stay on the **company** sqlite and slice in RAM.

---

## Verdicts

| Tag | Meaning |
|---|---|
| **PASS** | Pack rows reach the iPhone on this page × filter. Empty UI means the pack really has no facts. |
| **BLANK RISK** | Pack can have rows and the phone still paints empty until a force-load that 438 never finishes. |
| **MISSING PACK** | App path is correct; the published seat/tape does not contain the rows. |
| **APP BUG** | Code drops or mis-paints rows that are already in today’s company (or seat) pack. |

---

## Soft FAIL (438) — blank forever after Clear already showed $79.9M

Hypothesis confirmed on this tip line.

`ensureSectionLoaded` (HeartbeatStore ~6058):

1. **Company / no filter** (`sectionPageFirstPaint` = `.companyStream`).
2. Non-`skipOnLight` sections (Sales, 5 Star, Prep, Loss, Dynacap, Pick Path grain): if `factsOwned` and `rowCount > 0`, **return without `installSectionSlice`**.
3. `skipOnLight` (Picker, `pick_path_picker`, Pre-Sub items): warehouse `count >= 2` + non-empty `filteredLatest` → return without a force-read.
4. `PulseQuery.paint(light:)` **skips** those three sections unless `includePageOnly`.
5. Company warehouse paint **does not prefill grain tables** (`shouldBuildCompanyGrainTablesOnWarehousePaint` = false).
6. Phone grains hide when the builder returns `[]` (`PhoneSectionPage.grainBlock`). Hero can still show pack chrome **$79.9M**.

So: Command Center / Clear chrome is live, open Sales / Prep / Pick Path / 5 Star / Loss / Dynacap, tables stay empty **forever** if the `.task` early-returns and never re-arms (`shouldReloadSectionSQLOnSeatPaintStamp` is false).

**439 already owns this path.** See handoff below. Do not land a second `openSectionPage` / slice-on-owned-rows tip.

---

## Dropdowns (same on every page)

| Focus | Source | Verdict |
|---|---|---|
| Region | Hardcoded `MarketRegion`: East / South / California / West | **PASS** if pack uses those four titles. Not roster-driven. |
| Division / Market | `MarketRegion.officialDivisions` (12 markets), scoped by selected region | **PASS** for the official 12. Extra pack markets would not appear (**APP BUG** only if cook adds a 13th). |
| District | Roster, scoped by selected division | **PASS** after roster wave. Empty roster = **BLANK RISK** until first-wave `storeRoster` lands. |
| OM / Ops | `publishedOMNames` — two-or-more letter tokens, **no digits** | **PASS** after recook (people). `NorCal 04` / OM_AREA leftover = **MISSING PACK** (recook + republish; tip cannot heal baked sqlite). |
| Store | Roster, scoped by division / district / OM | **PASS** when roster is present. |

Clear rewrites filter option caches (`refreshFilterOptions` after `swapToSeatPack(.company)`).

---

## Page × filter matrix

Rows = page. Columns = filter seat. Cell = primary table/hero risk when today’s **company** pack (~26.4MB, $79.9M company grain) is on disk.

`CC` = Command Center glance / hero. Section pages are `PhoneSectionPage` on iPhone.

### Command Center

| Company | Region | Division | District | Store | OM / Ops |
|---|---|---|---|---|---|
| **PASS** chrome $79.9M / +16.23% from pack `sales_grain=company` + `dash_chrome`. Glance uses cached summaries + `seatPaintStamp`. | **APP BUG** (wrong grain, not blank): Region stays on company seat (`forSeat` → company). `applyFilters` paints **company** chrome then `reuseInPlace`. Heroes can stay $79.9M while tables (if opened) slice the region. | Same as Region — company chrome on a Division chip. | **PASS** if `packs/seat/district/<id>/current.sqlite` exists. Missing object **fails** the hub (not leftover company). | **PASS** / **MISSING PACK** if that store seat is unpublished. | **PASS** / **MISSING PACK** if that OM person seat is unpublished. OM list must be people (Jino Arvin, …), never area codes. |

Clear → company: **PASS** on 418–424 (row plane + box maps + summaries same turn) **when** the company plane is still in the LRU (cap 2, company pinned). **BLANK RISK** if 439 holds `seatPaintStamp` under Pages (`shouldPublishHeldSeatPaintAfterSheet` = false) and never publishes after dismiss.

### Sales

| Company | Region | Division | District | Store | OM / Ops |
|---|---|---|---|---|---|
| Hero **PASS** from company grain. Regions + Markets **BLANK RISK / APP BUG** on 438 (owned warehouse, no slice). 437 math is correct: do not sum store rows over the company grain. | Markets from `rollupStores` (company warehouse slice). **BLANK RISK** if 438 skipped load; **APP BUG** if hero stays company $79.9M. | Districts + Stores from company slice. Same 438 blank-forever. | **PASS** from district seat store facts. | **PASS** that store. | **PASS** OM stores. |

By Day: company uses `salesCompanyFact()` day prefixes. Empty days = **MISSING PACK** (week not cooked), not an app skip.

### 5 Star

| Company | Region | Division | District | Store | OM / Ops |
|---|---|---|---|---|---|
| Regions + Markets **BLANK RISK** (438 early-return). First wave includes `.fiveStar` so warehouse usually has rows — slice is the missing step. | Markets **BLANK RISK** / wrong company hero. | Districts + Stores **BLANK RISK**. | **PASS** district stores. | **PASS**. | **PASS**. |

Not `skipOnLight`. Same owned-section early-return as Sales.

### Pick Path Compliance

| Company | Region | Division | District | Store | OM / Ops |
|---|---|---|---|---|---|
| Path grain (Regions + Markets) **BLANK RISK** (438). Shopper tape **intentionally** not on page open (`shouldLoadPickPathPickerOnPageOpen` = false). | Markets **BLANK RISK**. Expand still peeks a store seat. | Districts + Stores **BLANK RISK**. | Path stores **PASS** from district pack. Expand shoppers **PASS** if district cook kept joined `pick_path_picker`. | **PASS** if store pack has joined shoppers. | **PASS** if OM pack kept shoppers. |

Store expand (436 KEEP): `ensurePickPathShoppers` → `ensureSectionLoaded(.pickPathPicker)` → `readStores` → full-section fallback (EMPLOYEE_ALTERNATE_ID has no STORE) → **peek** `packs/seat/store/<n>/current.sqlite` without swapping the hub.

| Expand case | Verdict |
|---|---|
| District / OM / store pack has joined picker rows | **PASS** |
| Company thin (drops shopper tape) + store seat on disk | **PASS** (peek) |
| Company thin + store seat never downloaded | **MISSING PACK** — placeholder “Shoppers fill from the Heartbeat pack after ready.” |
| `readStores` empty and no full-section / peek fallback | **APP BUG** — 436 already added the fallback; do not regress |

Sequence / Mapper dates: join `aisle_mapper` at cook + `joinAisleMapperOntoPickPathIfNeeded`. `—` after recook = **MISSING PACK**.

### Prep Not Ready

| Company | Region | Division | District | Store | OM / Ops |
|---|---|---|---|---|---|
| Regions + Markets **BLANK RISK** (438). Second wave includes `.prepNotReady`. | Markets **BLANK RISK**. | Districts + Stores **BLANK RISK**. | **PASS** district stores. | Store 1 / no rows this week: **PASS** if chrome says 0% / “No Prep rows this week” (436 Store, not `Store #`). Dead `—` tile = **APP BUG**. | **PASS**. |

### Loss Revenue

| Company | Region | Division | District | Store | OM / Ops |
|---|---|---|---|---|---|
| Hero **PASS** from first-wave + chrome. Regions + Markets **BLANK RISK** (438 slice skip). `lost_grain=market` rows are not store facts (correct). | Markets **BLANK RISK** / wrong company hero. | Districts + Stores **BLANK RISK**. | **PASS**. | **PASS**. | **PASS**. |

### Dynacap (present)

| Company | Region | Division | District | Store | OM / Ops |
|---|---|---|---|---|---|
| Present on dashboard + Pages. Regions + Markets **BLANK RISK** (438). Second wave. Coverage note is honest **MISSING PACK** when Excel omits stores (district/region totals may still paint). | Markets **BLANK RISK**. | Districts + Stores **BLANK RISK**. | **PASS**. | **PASS**. | **PASS**. |

---

## What is **not** an app blank

- Company Command Center **not** prefilling all 12 grain tables (Jetsam KEEP). Lower tables are page-scoped.
- Company thin **dropping shopper tape**. Expand + store-seat peek is the path.
- Picker ScoreCard shoppers **hidden** on Company / Region (filter lock). Highlights still show.
- No TestFlight / no HUB Predictions changes.

---

## Handoff for the 439 agent ([PR #13](https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS/pull/13))

Keep the nav/sheet/warm-host work. These data-blank items belong **on that same present/paint path** — do not open a 440 duplicate.

1. **Keep** `shouldInstallSliceWhenWarehouseHasRows` + `installSectionSlice` on owned/early-return. Reverting this re-breaks Sales / Prep / Pick Path / 5 Star / Loss / Dynacap after Clear shows $79.9M.
2. **Keep** `openSectionPage` / `shouldForceLoadPageGrainsAfterChrome`. `pageOpenForceLoadSections` already loads `[section]` (and Pre-Sub items). That covers every audit page. Do **not** add `pickPathPicker` to page-open (436 KEEP).
3. After slice, iPhone grains read `seatRows` / `rollupStores` from `latestBySection`, not `cachedGrainTables`. Chrome-only reuse (`reuseInPlace`) with an empty warehouse still paints a $79.9M hero and empty Regions — force the sqlite read when `rowCount == 0` (438 `shouldEarlyReturnOwnedSection` already requires rows; do not re-early-return on empty owned).
4. **Region / Division (secondary, wrong grain):** still company `Key`. After `reuseInPlace`, rewrite **summaries** from the company warehouse slice or Command Center / Sales heroes stay company $79.9M under a Region chip. Tables can be right while chrome is wrong.
5. **`shouldPublishHeldSeatPaintAfterSheet` = false:** confirm Clear → company still rewrites heroes when Pages was open. If Clear under the sheet leaves leftover district Stores N, publish once on dismiss (not a stamp storm).
6. **`shouldDelaySectionSQL` always true on 439:** first `.task` can cancel during chrome-first yield. `setVisibleDestination` → `openSectionPage` must still run. If that is cancelled, pages stay blank and the token never re-arms (`shouldReloadSectionSQLOnSeatPaintStamp` stays false — KEEP).
7. Company Pick Path expand: peek store seat only. If peek is empty, say **missing store pack**, do not stream company shoppers onto the hub.
8. Do not touch HUB Predictions. Do not raise the 40MB company cap. Do not restore THIS SEAT.

Cable (not TestFlight): mid-Clear, open Sales / 5 Star / Pick Path / Prep / Loss / Dynacap on Company, then Region, Division, District 03, one store, one OM. Hero under 1s, then grains. Never blank when the pack has rows.

---

## Outcome

| Item | Result |
|---|---|
| 438 Soft FAIL blank-forever | **APP BUG** — company early-return skips `installSectionSlice`; deferred page-only grains never force-load. |
| Fix | **439 / PR #13** — same present/paint path. No 440 code tip. |
| Pack-only blanks | Company shopper tape; unpublished district / OM / store seats; OM_AREA baked into old sqlite (recook). |
| This PR | Audit + handoff only. BuildStamp stays **HB-0828.438**. |
