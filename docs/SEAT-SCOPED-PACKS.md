# Seat-scoped packs — architecture contract (Tip 1)

Stamp **HB-0828.381**. Path A locked. File audit uses this document.

Heartbeat is a field iPad app. Production analytics mobile apps (Power BI Mobile, Tableau Mobile, Salesforce Field / Briefcase, retail territory packs) do **not** download the full market and re-slice it in the client on every filter. They:

1. **Scope at the pack / query** — Import / briefcase / extract is already the user’s book. Power BI Mobile caches the *filtered* report it last opened (250 MB cap); DirectQuery is not an offline plane. Tableau Mobile stores a seat-sized Interactive Preview; filter changes that need more data go back to the server. Salesforce Briefcase syncs the records for *this* user, not the org.
2. **Summary first** — tiles and KPIs are pre-aggregated (Power BI Import aggregations, Looker PDTs, Tableau viz cache). Detail rows load when the user expands or opens a visual.
3. **Swap, don’t remount** — Looker Embed `updateFilters` + `dashboard:run` keeps the shell. Power BI “Apply all slicers” batches queries into one visual refresh. The page host stays up.
4. **Virtualize long lists** (Tip 2+) — UITableView / LazyVStack. Out of Tip 1.

`.380` failed the field day because the **data plane** was still “load company `current.sqlite` → `applySeatSliceNow` on `latestBySection` → grain gates leave every section empty except Sales (special-case prefetch).” That is the opposite of the apps above.

## Contract (Tip 1)

| Rule | Must |
|---|---|
| Cook | `packs/manifest.json` + `packs/seat/{grain}/{id}/current.sqlite` |
| Grains this tip | `district`, `store`, `company` (market thin summary) |
| Pre-roll in each seat sqlite | Card headlines, expand grain, Healthy/Watch/At Risk flags, seat store roster. Shoppers = **that seat’s stores only**. |
| Device | Who’s looking → download **that** seat pack → hub paints from **that** sqlite |
| BAN | Market `current.sqlite` as primary under a seat |
| BAN | `applySeatSlice` of the full market as the data plane |
| Clear / new seat | **Swap** the active sqlite. No seat+company merge |
| Halloween | **Removed** from load |
| District 03 | Every `MetricSection` Stores N = Heartbeat seat N |
| Out of Tip 1 | Full UITableView virtualize, comedy polish |

## Object layout

```
heartbeat-packs/
  current.sqlite                          # market file for Who’s looking roster + Clear
  packs/manifest.json
  packs/seat/company/all/current.sqlite   # thin: store facts + chrome, no shopper tape
  packs/seat/district/03/current.sqlite
  packs/seat/store/12/current.sqlite
```

Device cache mirrors the same relative paths under Application Support.

Nightly cook writes district + store + company thin. The 15-minute cook always refreshes company + **all districts** (field day). Stores can wait for the nightly pass; a missing store pack is **materialized** on device with `readStores` into a seat sqlite (still a pack swap — not an in-memory market slice).

## Device state machine

```
boot        → company sqlite (roster / Who’s looking only)
Continue    → resolve SeatPack.Key → download or materialize → activePackURL = seat file
hub paint   → chrome + facts from active seat sqlite only
Clear       → activePackURL = company sqlite, wipe seat caches, no merge
new seat    → wipe → swap file → paint
```

`HeartbeatStore.sqliteURL` is the **active** pack. Cloud fetch of `current.sqlite` always lands on the company file, never on a seat file.

## Why Sales was live and everyone else was grey (`.380` autopsy)

`paintFromWarehouse(light: true)` does not write grain tables. `shouldPrefillExpandTables(filtersActive:)` is false under a seat. `shouldScheduleLiveGrainPaint(filtersActive:)` is false under a seat. Light paint then **only** `prefetchExpand(.sales)`. Loss / 5 Star / Labor / Dynacap / PPH / Missing / Schedule / Pick Path footers stay grey empty “Stores”.

Tip 1 does not flip those gates. The seat sqlite **already contains** live grain tables for every dashboard card. The hub installs that chrome.

## Tip 1 addendum (indexed seat file)

- `facts` is the **detail_*** plane, keyed `store_number` (indexes: `facts_section_store`, `facts_store`).
- `summary_cards` + `dash_chrome` are the **summary_*** plane (card headlines, expand grain, flags).
- Cook `VACUUM`s the seat sqlite. District target ≤ 10 MB; warn above that.
- Device download is staging → **atomic replace**. Cache ceiling **250 MB**; oldest unused seat files evict.
- Continue still installs grain tables for **every** dashboard section so Loss / 5 Star / Labor / etc. get the same live Stores N footer as Sales. `.380` only prefetched Sales.

## Later tips

- Tip 2: Region / OM / Division published grains; UITableView / LazyVStack store lists
- Tip 3: Comedy polish; drop materialize fallback once nightly store coverage is complete
