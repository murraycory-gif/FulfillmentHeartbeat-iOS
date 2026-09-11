# Seat-scoped packs — architecture contract (Tip 1)

Stamp **HB-0828.381** / 706 (.381b). Path A locked. File audit uses this document.

Heartbeat is a field iPad app. Production analytics mobile apps (Power BI Mobile, Tableau Mobile, Salesforce Field / Briefcase, retail territory packs) do **not** download the full market and re-slice it in the client on every filter. They:

1. **Scope at the pack / query** — Import / briefcase / extract is already the user’s book. Power BI Mobile caches the *filtered* report it last opened (250 MB cap); DirectQuery is not an offline plane. Tableau Mobile stores a seat-sized Interactive Preview; filter changes that need more data go back to the server. Salesforce Briefcase syncs the records for *this* user, not the org.
2. **Summary first** — tiles and KPIs are pre-aggregated (Power BI Import aggregations, Looker PDTs, Tableau viz cache). Detail rows load when the user expands or opens a visual.
3. **Swap, don’t remount** — Looker Embed `updateFilters` + `dashboard:run` keeps the shell. Power BI “Apply all slicers” batches queries into one visual refresh. The page host stays up.
4. **Virtualize long lists** (Tip 2+) — UITableView / LazyVStack. Out of Tip 1.

`.380` failed the field day because the **data plane** was still “load company `current.sqlite` → `applySeatSliceNow` on `latestBySection` → grain gates leave every section empty except Sales (special-case prefetch).” That is the opposite of the apps above.

## Contract (Tip 1)

| Rule | Must |
|---|---|
| Cook | `cookPublished(includeStores: true)` → `packs/manifest.json` + every company / district / **OM person** / store sqlite. `publishCloudPack` uploads that seat plane. Company thin **drops shopper tape** but still publishes picker `summary_cards` + `pickerShoppers` (summary-first). |
| Grains this tip | `district`, `om`, `store`, `company` (market thin summary) |
| Pre-roll in each seat sqlite | Card headlines, expand grain, Healthy/Watch/At Risk flags, seat store roster. Shoppers = **that seat’s stores only**. |
| Device | Who’s looking → download **that** seat pack → hub paints from **that** sqlite. Missing object **fails** the hub. |
| BAN | Market `current.sqlite` as primary under a seat |
| BAN | `applySeatSlice` of the full market as the data plane |
| Clear / new seat | **`swapToSeatPack`** — Clear/Company uses the same path as District (`packs/seat/company/all/current.sqlite`). No dual-wave market restore. No seat+company merge |
| Halloween | **Removed** from load |
| District 03 | Every `MetricSection` Stores N = Heartbeat seat N |
| Out of Tip 1 | Full UITableView virtualize, comedy polish |

## Object layout

```
heartbeat-packs/
  current.sqlite                          # market file for Who’s looking roster only
  packs/manifest.json
  packs/seat/company/all/current.sqlite   # thin: store facts + chrome, no shopper tape
  packs/seat/district/03/current.sqlite
  packs/seat/om/Jino-Arvin/current.sqlite  # one pack per OM_ID person
  packs/seat/store/12/current.sqlite
```

Device cache mirrors the same relative paths under Application Support.

Mac cook (`publishCloudPack` / HeartbeatIngest) always runs `cookPublished(includeStores: true)` and uploads `packs/manifest.json` plus **every** company / district / OM person / store sqlite. A missing seat object on the field iPad **fails the hub**. `materializeSeatFromCompany` is Mac / DEBUG kitchen only.

`WorkbookParser.parseStoreRoster` binds **OM_ID** with exact / longest-key match. Normalized `omarea` must not steal key `om`. `operations_om` is the person (Tonya Lane, Jino Arvin, …). Area codes stay in `text["om_area"]`. Existing packs baked before this bind are wrong — **recook + republish**.

`Key.forSeat` is store → **OM** (`filters.oms.first`) → district → company. OM filter chips read `publishedOMNames` (two-or-more letter tokens, no digits). `NorCal 04` is not an OM seat.

## Device state machine

```
boot        → swapToSeatPack(.company) → Command Center (no Who’s looking wall)
filter chip → swapToSeatPack(district|om|store|company) → paint or error
Clear       → swapToSeatPack(.company)
missing     → FAIL hub (no silent no-op, no market slice)
```

`HeartbeatStore.sqliteURL` is the **active** pack. Cloud fetch of `current.sqlite` always lands on the company file, never on a seat file.

## Why Sales was live and everyone else was grey (`.380` autopsy)

`paintFromWarehouse(light: true)` does not write grain tables. `shouldPrefillExpandTables(filtersActive:)` is false under a seat. `shouldScheduleLiveGrainPaint(filtersActive:)` is false under a seat. Light paint then **only** `prefetchExpand(.sales)`. Loss / 5 Star / Labor / Dynacap / PPH / Missing / Schedule / Pick Path footers stay grey empty “Stores”.

Tip 1 does not flip those gates. The seat sqlite **already contains** live grain tables for every dashboard card. The hub installs that chrome.

## Tip 1 addendum (indexed seat file)

Cook writes a fully indexed seat sqlite, `VACUUM`s it, then the device **atomically swaps** that file onto `activePackURL`. No gzip download path — compress is VACUUM; swap is `replaceItemAt`.

| Plane | Objects |
|---|---|
| **summary_*** | `summary_cards` (one row per dashboard section: store_count, headline, json) + `dash_chrome` |
| **detail_*** | `facts` keyed `store_number`; view `detail_facts` exposes `store_id` |
| **needs-attention** | `facts.needs_attention` + **partial** index `facts_attention ON facts(section, store_number) WHERE needs_attention = 1` |
| Other indexes | `facts_section_store`, `facts_store`, `facts_section_div` |

- District pack **target ≪ 5–10 MB** (`districtTargetBytes` = 10 MB is the warn line, not a goal).
- Device `packs/seat/**` hard ceiling **~250 MB**; `evictSeatCache` drops oldest unused seat files (keeps the active key + company thin).
- Continue still installs grain tables for **every** dashboard section so Loss / 5 Star / Labor / etc. get the same live Stores N footer as Sales. `.380` only prefetched Sales.
- Halloween stays **off**. Clear / new seat still **swaps** the file. District 03 Stores N = Heartbeat seat N on every section.

## Later tips

- Tip 2: Region / Division published grains; UITableView / LazyVStack store lists. OM person seats pulled forward into `.389`.
- Tip 3: Comedy polish
