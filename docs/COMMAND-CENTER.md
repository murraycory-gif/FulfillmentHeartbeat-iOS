# Command Center (Tip 2 / Option 8b)

Stamp **HB-0828.389** / 715. Data plane stays Tip 1 seat packs (`docs/SEAT-SCOPED-PACKS.md`) plus **OM person seats**. Mac and iPad have **no Alerts rail**. Glance tiles use a tight **blue title banner**, a bigger section title, and one **centered** health-tinted SF Symbol — no spark bars. No Dashboard back chevron on scorecards.

Cold open is **company Command Center** (`swapToSeatPack(.company)`). Who's looking is not a required wall. Seat changes are dashboard filter chips only (District / OM / Store / Clear→company). OM chip swaps `packs/seat/om/<slug>/current.sqlite`. No per-page tours. Every filter swap paints or errors — never a silent no-op.

**Recook + republish required.** Existing device sqlite already baked `operations_om` from OM_AREA (`NorCal 04`…). This tip does not heal packs already on disk.

Home is a **Pulse / Power BI Mobile briefing**: packed KPI tiles, tight gutters, expand on demand. Not always-open ScoreCard tables.

| Surface | Must |
|---|---|
| Heroes | Sales / Loss / 5 Star navy tiles. Gold **Stores N** is one roster pin (`pinSeatStoreCount`) at company and district. No 2189/2160/2159 split. |
| Glance | Every other **real** `dashboardCards` tile only: **blue title banner** + bigger title + health badge on the banner + value + one **centered** SF Symbol tinted with `displayedHealth`. No spark bars / invented history. Picker headline is pack chrome / `pickerShoppers` (summary-first). Empty cards stay No data — never `.none` → Healthy. |
| Scorecard | Active-filter tables only, never duplicates. **Company:** Regions + Markets. **Region:** Markets. **Division:** Districts + Stores. **District / OM / Store:** Stores once. Picker: **one shoppers table** on Division / District / OM / Store. |
| Density | Tiles stretch to leftover height. Zero dead white. |
| Expand | Tap opens the scorecard. No store tables on home. |
| Mac | **Pinned** left Pages rail + dense center. **No right Alerts column.** |
| iPad land + port | **Full-width center by default.** Pages opens as a drawer. **No Alerts drawer / rail.** Do not pin Mac triple columns. |
| iPhone | Same glance-first density (2-col port / 3-col land). |
| Load | Heart + progress + chrome. **No grocery one-liners.** |
| Halloween | Off |

Do not merge. Do not TestFlight until Cory PASSes iPad land/port + Mac Catalyst.
