# Test triage for Mac run of 15a7bc3

42 failures (41 unit + 1 UI) out of 233. Each row is one failing test. **A** means the app behavior is intentional and the expectation was updated. **B** means the app was wrong and the code was fixed. No assertion was deleted. Where a blanket check could only pass by inventing a number, it was restated as column-level checks that still fail if a supplied metric renders as a dash.

Counts: **19 A**, **20 B**, **3 A+B**.

This VM cannot run `xcodebuild`. The classifications below are from the Mac failure lines plus the current source.

## HeartbeatMathTests

| Test | Class | Evidence |
| --- | --- | --- |
| testArchitecture381bMacCookPublishesEverySeatSqlite | A | `identityOverrides["3603"]` is Mid-Atlantic / district A9. `storeRoster` always injects that override, so cooked districts are `03`, `A9`, `J1`. The OM and store assertions on that cook were not in the Mac fail list and were left alone. |
| testArchitecture383CompanyCommandCenterPickerChromeAndStoreTableScope | A | Same 3603 override adds one store, so sales / lost revenue / five star chrome counts are 7. Glance still pins to the `rosterStores: 6` argument the test passes in. |
| testArchitecture389OMSeatPacksGlanceBannerPickerShoppersAndNoDashboardBack | A | `includeStores: true` cooks the override store, so the OM set includes `Aimee-Cabrera-Kleissler`. |
| testArchitecture398PhonePageNavAndFilterSwapAreBothInstant | A | `shouldReloadSectionSQLOnSeatPaintStamp()` is false, so the SQL token is `load-sales-District 03` with no `-seatN`. Seat paint 1 and 2 are equal on purpose. The equality is still asserted. |
| testArchitecture401CompanyGrainExpandIsPageScopedNotAllCards | A | Same seat-paint lock. Seat paint 3 and 4 produce the same token. |
| testArchitecture404ShareMailLiveFlagsEveryPage | B | Watch / At Risk tiles put a ~400-character Mail pill between the label and the band subtitle, so `Watch…3.01% to 5%` (and the missing-items watch band) fell outside the 500-character window. The value and the band now come before the pill. The regex and the count of `1` are unchanged. |
| testArchitecture406SeatChipsFalseZeroBanAndLiveKeys | A | `HeartbeatFormat.pct(nil)` is `"—"`. The labor row without a week does not carry Sch Eff / UPLH / Wage / AIV, and the schedule row does not carry staffing. Inventing `0.00%` would be the false zero this test bans. The blanket "no dash" checks are now per column: supplied metrics must not be `"—"`, and the missing ones must be `"—"`. Header equality is unchanged. |
| testArchitecture425MacShareAttachesReportViaShareSheet | A | `shouldSetHTMLMessageBody` is true only for utf8 counts above 80 (and a sibling test locks 50 as false). The Recap fixture was under that floor, so Mail got the overflow note. The fixture is longer and still must contain `<p>Recap</p>`. |
| testArchitecture436PickPathExpandLoadsPickerAndPrepUsesStoreNotStoreHash | B | Prep `Store #` is `1` on every Excel row. Roster matching ran before prep and treated that column as the store. Metric parsers now run first, roster rejects metric headers, and prep uses the `Store` column. |
| testArchitecture456MetricPageStoreCountIsFactStores | A | `PhoneCompanyThisWeekBlock` calls `metricStoreCount(section, rows: factRows(section: section, store: store))`. The source scan was updated to that call. |
| testArchitecture457DashboardNestsThisWeekDetail | A | The block uses `PhoneThisWeekChrome.chips`, not `dashboardTableHeaders`. |
| testArchitecture459ThisWeekChromeIsMainActor | A | `PhoneThisWeekChrome` reads `cachedPhoneDashboardRows`, `factRows`, and `companyRows`. It does not call `salesStores()` / `seatRows` / `lostRevenueMarketRow()`. |
| testCaliforniaRegionResolvesFromTitleAndRoster | B | `MarketRegion.canonicalName("California")` is empty because California is a region title, not a division. `resolvedIdentity` then dropped the row out of a California Region filter. A raw division is kept when both the roster and the canonical name are empty. Roster NorCal still overwrites a sheet stamp. |
| testCaliforniaScheduleQualityKeepsRegionBook | B | An active region filter went through `padSeatStores` and dropped the empty-store California total and off-roster SoCal 9999. Region-only filters now union that book. District / store / OM seats still return the padded roster only (`testUnionRegionBookIsBannedUnderSeatAndClearDropsSeatGrain`). |
| testClearFiltersResetsChromeAndCompanyGrain | B | `clearFilters` reset the filters inside a `Task`, so the test still saw district `03`. The filter reset is synchronous. The seat swap stays in the task. |
| testCompanyWideLostRevenueRegionsAllHaveDollars | A+B | **A:** both `PulseCaches.build` and `PulseQuery.paint` report 2160 lost-revenue fact stores. `hasMetricFact` / HB-0828.456 count stores with a value, not roster gold 2161. East 612 was not in the fail list. **B:** `summarize` preferred a market total of `$3,337,325` over the store book. Power BI (`testPulseQueryFilterMatchesPowerBI`) still expects `$3,456,041` and that dollar line did not fail. A market total is used only when it is at least the store rollup. |
| testDashboardGrainTableKeepsFullMoneyAndColumnCounts | A | Phone `evenValueWidth(400, 8 columns, show count)` is 119.5. Label 156 + stores 58 + status 88 + gutters + the readable floor leave 956, and 956 / 8 = 119.5, which is above `readableValueMin` 118. `MacReadable` is off in this host (152 would have shown up if it were on). |
| testDashboardStoreLinesFillMissingRosterStores | A | `lines.first?.health` is `Health?`. A bare `.none` is `Optional.none` (nil), so the assert compared `Health.none` to nil. The missing roster line is `Health.none`. The expected value is `Optional(Health.none)`. |
| testFiveStarFileParsesAndUsesPosterBands | B | The five-star template matched the roster parser (division + district + store) and came back with empty metrics (`0.0` vs 5.0 / 91.0 / 2.3) and section `storeRoster`. Metric parsers run first, and roster returns nil when the header contains rating, flash, prep, schedule, pph, sales, and the other metric tokens. |
| testLostRevenueDistrictExpandMatchesPackLabelsAndFillsGoal | B | Order labels `J3CHICAGO` and `308 - J3 CHICAGO` both alias to district J3, so the table emitted two rows. A bucket key already painted is skipped. The live row is still labeled `J3` and still must contain `$1,200` and `3.71%`. |
| testMarketFiveStarTilesMatchCalloutMetrics | B | Callout order and names in the rest of the app are OTT, Flash, Presubs, COE, OTH 5%. `fiveStarActionFlags` had Flash, COE, OTT, "Pre Sub OOS%", OTH 5%. The spec list matches the callouts. |
| testPickerExpandIsLiveWhenPackChromeHasShoppers | B | Chrome with shoppers and no grain table builds one row labeled `Company`. `mergeLiveGrainTables` dropped it because region grain requires East/South/California/West labels. An unfiltered `Company` chrome row is kept. Store labels such as `304 \| NorCal` are still dropped at region grain. |
| testPickerScorecardFileParsesAndFlagsOpportunity | A | Template shopper AWHOR08 has refund `$12.50`. `refundHealth` is watch for amounts from 0 to 20 (`98b5ffc`). `pickerHealth` takes the worst flag, so the shopper is watch even with PPH 91.4. PPH and presub assertions were already passing. |
| testPickerVolumeRequiresMoreThanFifteenOrders | B | `pickerHasVolume` was true for any orders, picks, hours, or PPH. The test requires orders greater than 15. Opportunity matching uses that function. |
| testPrepNotReadyOutlineUsesStoreHoursFile | B | Same roster-before-prep bug as 436. Haggen prep `0.016979` must become `1.6979`, not `0.0`. |
| testPulseQueryFilterMatchesPowerBI | A | Lost-revenue store count is 2160 fact stores (see the company-wide row). The headline `$3,456,041` was not in the fail list and was not changed. |
| testRosterDistrictWinsOverSheetStampOnEverySection | B | `stampRoster` copied district only when the row district was empty, so sheet `B3` beat roster `03`. District is overwritten whenever the roster district is non-empty, same as division. |
| testSalesHeadlineUsesTotalColumnNotDaySum | A | The failing line is the company summary, not the per-store total column. The fixture's company grain row is `132,830,508`. `summarize(.sales)` uses `salesCompanyRow` when that row has dollars (`ca52b9a`: company-wide Sales uses the Excel Total row, not a store rollup). `testPulseQueryFilterMatchesPowerBI` expects sales `132,830,509` and did not fail. The store-row checks (total column `39,761,217`, not the day sum) were not in the fail list. |
| testScheduleVarianceBandsAndOutlineParse | B | Same roster steal. Schedule efficiency `0.931` and under `0.061` must scale to 93.1 and 6.1. `normHeader` keeps `%` as `pct`, and `applyMetric` still maps `scheduleeffic…`. |
| testSeatPackDistrict03EverySectionStoresEqualsHeartbeatN | B | `expandTables` only emitted sections present in `packs`. The test calls it with the default empty pack map, so every expand table was empty and `everyDashboardExpandLive` failed. Empty packs now build a table for each dashboard section that has seat rows. Company region prefill is still skipped. |
| testShareDashboardMatchesOnScreenCalloutsAndOpensWithoutHTML | A+B | **B:** `shouldRejectZeroBandFlags` treated any flag set without Healthy/Watch/At Risk names as stale, so sales flags `Flag 1`…`Flag 5` were dropped. Non-band flags are kept. All-zero band flags are still rejected. **A:** mail tiles are 2-up (`width="50%"`) since `23fb77c` (HB-0828.375) so Outlook does not crush a 4-up grid. On-screen `calloutColumns(count: 5) == 3` is unchanged. |
| testShareEmailMatchesOnScreenTablesAndStaysReadable | A+B | **B:** one stacked-table header was `font-size:11px`, which the readability ban forbids. It is 13px. **A:** the table class is `data mail-stack`, so the class check is `class="data "` rather than `class="data"`. The pill, header, and column checks stay. |
| testTableLabelWidthFitsRegionNamesAndEvenValues | A | Same 119.5 even-width result as the dashboard grain table test. |
| testWarehouseKeepsFullPackAndFillsThinPack | B | `takeIfRicher` replaced a pack whenever dollar totals differed by more than $1 in either direction, so a poorer full pack (store `"1"`) won. Incoming replaces existing only when it has more stores or more dollars. |

## WorkbookParserTests

| Test | Class | Evidence |
| --- | --- | --- |
| testClassifiesTemplateRows | B | Roster-first parsing stamped `textPayload["roster"]`, and `section(fromRows)` returns `.storeRoster` before five star, pick path, and prep. Metric parsers run first. |
| testNormHeaderStripsSymbols | B | `%` was deleted, so `OTP %` became `otp`. `%` now becomes `pct` (`otppct`) and `#` is still stripped (`Store #` → `store`). Alias `otppct` → `otp_pct` keeps the OTP metric. |
| testPickerTotalsMatchEveryShopperInSparseExport | A | `HeartbeatFormat.pct` is `%.2f%%`, so zero is `0.00%`. The `1.69%` presub check was already passing. |
| testPPHDayOutlineUsesTotalColumn | B | The outline was classified as a roster and the Total column never became `pph` (0.0 vs 131.6). `parseOutline` now runs before roster and still uses the Total column. |
| testPrepCookUsesStoreNotStoreHash | B | Same `Store #` = 1 bug. Expected stores stay `2` and `3427`. |
| testSalesParsesOutlineWeekTotals | A | `parseSales` emits a company-grain row with an empty store number for the Total row, and the sales template includes that Total plus the order-type filter. Store `1` / `606` / `3427` value checks are unchanged. |
| testTemplateCSVRoundTrip | A | Dynacap's template is district grain and has no Store column, so every store number is empty. Sales row 0 can be the Total row; the check is that some non-picker row has a store, not that row 0 does. |

## UI

| Test | Class | Evidence |
| --- | --- | --- |
| testUnitedStore22PickPathShoppers | B | The test counted `staticTexts` and found 0 while the app showed 6 shoppers. Each Pick Path shopper row (`pickerPhoneCard` and `pickerLine`) has accessibility identifier `pick-path-shopper-row`. The test queries that identifier and waits up to 120 seconds for the pack. |
