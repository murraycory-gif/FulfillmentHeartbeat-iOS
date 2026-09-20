# Missing-data map — verify vs pack/code (M1–M7)

**Baseline:** HB-0828.438 / 764 @ `2b6cc1d`  
**439:** [PR #13](https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS/pull/13) `bc-86582dfa` — present/paint (M1/M7). Soft FAIL dirty merge.  
**440:** [PR #15](https://github.com/murraycory-gif/FulfillmentHeartbeat-iOS/pull/15) — M3/M4 only. This PR is the audit + hunk list. No app rewrite here.

Company pack ~26.4MB. Sales grain **$79,870,895 / +16.23%**. Ops = OM. No TestFlight.

| ID | Gap | 438 | Verdict | Owner |
|---|---|---|---|---|
| **M1** | Company `ensureSectionLoaded` early-return without `installSectionSlice` → Sales / Prep / 5★ / Loss empty body | Confirmed | **APP BUG** blank-forever | **439** |
| **M2** | Company thin drops `pick_path_picker`; expand must force-load / peek | Confirmed KEEP | **PASS** if peek hits; **MISSING PACK** if store seat unpublished | 436 + 439 after-chrome; peek stays |
| **M3** | Scorecard-first index + `pphPickers` merge → Path % — | Confirmed | **APP BUG** | **440** PR #15 |
| **M4** | Prep Excel 0 → dash; `rosterJoined` vs `snapshots` | Confirmed. Chrome already 0%. Pad dual ID painted — | **APP BUG** | **440** PR #15 |
| **M5** | CC summaries same turn; $79.9M without opening Sales | Confirmed | **PASS** | 424 / 437 |
| **M6** | Company→Regions+Markets; Region→Markets; Division→Districts+Stores; District/OM→Stores once; Store→only | Confirmed | **PASS** | 387 |
| **M7** | `skipOnLight` blank until expand / force-load | Confirmed | **BLANK RISK** | **439** |

## 439 hunk list (do not copy onto 440)

| File | Hunk |
|---|---|
| `HeartbeatStore.swift` | `openSectionPage` / `beginPageOpen` / `endPageOpen` |
| `HeartbeatStore.swift` | `ensureSectionLoaded`: `shouldInstallSliceWhenWarehouseHasRows` on deferred **and** owned early-return |
| `HeartbeatStore.swift` | `shouldPublishVisibleSectionAfterLoad` → `objectWillChange` |
| `PulseLaunch.swift` | `shouldForceLoadPageGrainsAfterChrome` = true |
| `PulseLaunch.swift` | `shouldInstallSliceWhenWarehouseHasRows` = true |
| `PulseLaunch.swift` | `requiredChromeThenFillSections` = Sales, Prep, Pick Path, 5 Star, Loss |
| `PulseLaunch.swift` | `pageOpenForceLoadSections`: `[section]` + Pre-Sub items; Pick Path + `aisleMapper` + `pickPathPicker` **after** chrome (`shouldLoadPickPathPickerOnPageOpen` stays false) |
| `PulseLaunch.swift` | `shouldParkSectionSQLWhileSheetOpen` = **false** |
| `SectionDetailView.swift` | `.task` → `openSectionPage` |
| `MainHubView.swift` | warm cap 3 / `HubSheetPresenter` — nav only |

Leave on 439: Region/Division company-chrome heroes; Clear under Pages if held stamp never publishes.

## 440 (PR #15)

Path expand is `pick_path_picker` only. Prep `prepRows` = `snapshots`. Excel 0 = **0%**.
