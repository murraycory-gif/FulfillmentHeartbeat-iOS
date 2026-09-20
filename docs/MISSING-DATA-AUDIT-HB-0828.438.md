# Missing-data map — APP vs PACK/COOK

**Baseline:** HB-0828.438 / 764 @ `2b6cc1d`
**439 / PR #13** merged @ `7141c25` (HB-0828.439 / 765) — M1 + M7 chrome-then-fill
**This tip:** **HB-0828.440 / 766** — M3 + M4 only (app blanks when pack **has** rows)
**QC pack gaps** below are **authoritative for the pack side**. Do not invent UI fills.

Company pack today ~26.4MB. Sales grain `company` = **$79,870,895 / +16.23%**.
Ops = OM. No TestFlight. No HUB Predictions.

---

## Report matrix (APP vs PACK)

| Surface | Symptom | Pack | Verdict | Owner |
|---|---|---|---|---|
| **M1** Sales / Prep / 5★ / Loss body | Soft FAIL blank forever on company | Pack **has** store facts | **APP BUG** | **439** (merged) `shouldInstallSliceWhenWarehouseHasRows` + `openSectionPage` |
| **M7** skipOnLight grains | Blank until expand / force-load that never fired | Pre-Sub items in pack; company thin has no picker tape | **APP BUG** when pack has rows | **439** after-chrome force-load |
| **M3** Pick Path expand Path % | Scorecard-first index + `pphPickers` merge → — | Path rows **in** seat pack | **APP BUG** | **440** this tip |
| **M4** Prep pad / Excel 0 | `rosterJoined` dual ID → —; Excel 0 stored as 0 | Excel 0 **is** in pack | **APP BUG** | **440** this tip |
| **M2** Path expand shoppers | Empty until peek store seat | Company thin drops `pick_path_picker` | **PASS** if peek hits; **MISSING PACK** if store seat unpublished | 436 KEEP + 439 companion |
| **M5** CC chrome vs facts | $79.9M without opening Sales | Company grain + dash_chrome | **PASS** | 424 / 437 KEEP |
| **M6** Filter lock | Company→Regions+Markets; Region→Markets; Division→Districts+Stores; District/OM→Stores; Store→that store | Roster 12 markets / 4 regions | **PASS** | 387 KEEP |
| **ScoreCard facts** | Chrome cites **29249** pickers; `picker_scorecard` facts = **0** | Thin company pack killed ScoreCard tape | **PACK/COOK** | Cook — do not fake shopper facts from chrome |
| **Loss Revenue** | All rows `division=Haggen`; ops/OM blank; East / South / CA dash | Pack rows are Haggen-only; other regions omitted | **PACK/COOK** | Cook — dash when grain has no rows |
| **Prep NR** | United **zero**; **863 / 2161** stores missing; Southern 5 / United Ops OM **zero** | Pack omitted those stores / OMs | **PACK/COOK** | Cook — `shouldInventPrepRateOnEmptyStore` = false |
| **5 Star** | **2224** stores missing | Pack omitted those store facts | **PACK/COOK** | Cook — empty grain stays empty |
| **Region chrome** | Holes: CA / Mountain West / United | Pack has no chrome/facts for those regions | **PACK/COOK** | Cook — no invented region heroes |
| **Dynacap Store PPH** | Store PPH **—** | Store grain missing PPH fact | **PACK/COOK** | Cook — dash, not a guessed PPH |
| **Filter row** | 1 garbage filter row | Cook published a junk option | **PACK/COOK** | Cook — do not hide by faking a clean roster |

---

## Rule

- **APP BUG** = pack **has** rows and the phone paints blank / — / wrong join forever. Fix in app.
- **PACK/COOK** = pack **omitted** the grain. UI stays empty / dash / “No … rows this week”. **Do not invent fills.**

`PulseLaunch.prepRateText(0)` = **0%** (Excel stored zero).
`PulseLaunch.prepRateText(nil)` = **—** (missing key / missing pack row).
`shouldInventPrepRateOnEmptyStore()` = **false**.

---

## 439 hunk list (merged — do not copy onto 440)

M1 + M7 live in present/paint. Soft FAIL if that merge is dirty.

| File | Hunk | Why |
|---|---|---|
| `HeartbeatStore.swift` | `openSectionPage` / `beginPageOpen` / `endPageOpen` | Chrome first, then force-load. |
| `HeartbeatStore.swift` | `ensureSectionLoaded`: `shouldInstallSliceWhenWarehouseHasRows` on deferred **and** owned early-return | M1 — slice when warehouse has rows. |
| `HeartbeatStore.swift` | `shouldPublishVisibleSectionAfterLoad` → `objectWillChange` | Stamp-hold cannot swallow fill. |
| `PulseLaunch.swift` | `shouldForceLoadPageGrainsAfterChrome` = true | M1/M7. |
| `PulseLaunch.swift` | `shouldInstallSliceWhenWarehouseHasRows` = true | M1. |
| `PulseLaunch.swift` | `requiredChromeThenFillSections` = Sales, Prep, Pick Path, 5 Star, Loss | M1 body pages. |
| `PulseLaunch.swift` | `pageOpenForceLoadSections`: `[section]` + Pre-Sub items; Pick Path + `aisleMapper` + `pickPathPicker` when `shouldForceLoadDeferredCompanionAfterChrome` | M7 companions **after** chrome. `shouldLoadPickPathPickerOnPageOpen` stays **false**. |
| `PulseLaunch.swift` | `shouldParkSectionSQLWhileSheetOpen` = **false** | Pages latch must not skip SQL forever. |
| `SectionDetailView.swift` | `.task` calls `openSectionPage` | Re-arm if chrome-first yield cancels. |
| `MainHubView.swift` / sheets | warm cap 3, `HubSheetPresenter` | Nav only — do not lift into 440. |

**Leave on 439:** Region/Division company-chrome heroes (wrong grain, not blank). Clear under Pages if `shouldPublishHeldSeatPaintAfterSheet` is false.

**Do not** add `pickPathPicker` to first paint. Peek store seat on expand stays 436/440.

---

## 440 (this tip) — app blanks when pack has data

- `pickPathPickerIndex`: scorecard is LDAP→STORE join only. Expand rows are `pick_path_picker`.
- `PathShopperTable`: no `pphPickers` merge on Pick Path (`shouldMergePPHPickersOnPickPathExpand` = false).
- `prepRows` = `snapshots` (`seatRows`). Dual ID gone.
- Excel 0 → `prepRateText(0)` = **0%**. Missing key → **—**. No invented Prep / Loss / 5★ / Dynacap / ScoreCard fills for cook holes.

Cable after 439 lands: M1/M7 pages fill **when the pack has rows**; then M3 expand Path %; M4 store 1 / Excel 0 is 0%. Pack QC holes stay cook. No TestFlight.
