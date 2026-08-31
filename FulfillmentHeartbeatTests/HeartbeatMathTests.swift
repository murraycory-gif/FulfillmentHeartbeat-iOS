import XCTest
@testable import FulfillmentHeartbeat

final class HeartbeatMathTests: XCTestCase {
    func testDashboardCalloutsSortRiskThenWatchThenHealthy() {
        func card(_ section: MetricSection, _ health: Health, risk: Int = 0, watch: Int = 0) -> SectionSummary {
            SectionSummary(
                section: section,
                storeCount: 4,
                headline: 1,
                headlineLabel: "x",
                secondary: "",
                health: health,
                watchCount: watch,
                riskCount: risk
            )
        }
        let mixed = [
            card(.fiveStar, .good, watch: 1),
            card(.missingItems, .risk, risk: 3, watch: 1),
            card(.pph, .watch, watch: 2),
            card(.lostRevenue, .risk, risk: 8),
            card(.labor, .none),
            card(.pickPath, .watch, watch: 5),
        ]
        let ordered = HeartbeatMath.dashboardCallouts(mixed)
        XCTAssertEqual(
            ordered.map(\.section),
            [.lostRevenue, .missingItems, .pickPath, .pph, .fiveStar, .labor]
        )
        let filteredHealthy = HeartbeatMath.dashboardCallouts([
            card(.lostRevenue, .good),
            card(.missingItems, .watch, watch: 1),
            card(.pph, .risk, risk: 2),
        ])
        XCTAssertEqual(filteredHealthy.map(\.section), [.pph, .missingItems, .lostRevenue])
    }

    func testDashboardCalloutsPinsFiveStarOnlyWhenAtRisk() {
        func card(_ section: MetricSection, _ health: Health, risk: Int = 0, watch: Int = 0) -> SectionSummary {
            SectionSummary(
                section: section,
                storeCount: 4,
                headline: 1,
                headlineLabel: "x",
                secondary: "",
                health: health,
                watchCount: watch,
                riskCount: risk
            )
        }
        let atRisk = HeartbeatMath.dashboardCallouts([
            card(.lostRevenue, .risk, risk: 12),
            card(.missingItems, .risk, risk: 4),
            card(.fiveStar, .risk, risk: 1),
            card(.pph, .watch, watch: 2),
        ])
        XCTAssertEqual(atRisk.map(\.section), [.fiveStar, .lostRevenue, .missingItems, .pph])

        let watchOnly = HeartbeatMath.dashboardCallouts([
            card(.lostRevenue, .risk, risk: 8),
            card(.fiveStar, .watch, watch: 3),
            card(.pph, .good),
        ])
        XCTAssertEqual(watchOnly.map(\.section), [.lostRevenue, .fiveStar, .pph])
    }

    func testEvpDashboardPutsLostRevenueThenFiveStar() {
        func card(_ section: MetricSection, _ health: Health, risk: Int = 0, watch: Int = 0) -> SectionSummary {
            SectionSummary(
                section: section,
                storeCount: 4,
                headline: 1,
                headlineLabel: "x",
                secondary: "",
                health: health,
                watchCount: watch,
                riskCount: risk
            )
        }
        let ordered = HeartbeatMath.dashboardCallouts([
            card(.fiveStar, .risk, risk: 9),
            card(.missingItems, .risk, risk: 3),
            card(.lostRevenue, .good),
            card(.pickerScorecard, .risk, risk: 4),
            card(.pph, .watch, watch: 2),
            card(.labor, .good),
        ], role: .evp)
        XCTAssertEqual(ordered.map(\.section), [.lostRevenue, .fiveStar, .missingItems, .pph])
    }

    func testDashboardScopeLinesGroupByMarketThenRisk() {
        let rows = [
            MetricRow(section: .missingItems, division: "Jewel Osco", operationsOM: "A", storeNumber: "1", payload: ["mi_pct": 8.2]),
            MetricRow(section: .missingItems, division: "Jewel Osco", operationsOM: "A", storeNumber: "2", payload: ["mi_pct": 4.0]),
            MetricRow(section: .missingItems, division: "Shaws", operationsOM: "B", storeNumber: "3", payload: ["mi_pct": 5.2]),
        ]
        let lines = HeartbeatMath.dashboardScopeLines(section: .missingItems, rows: rows, grain: .division)
        XCTAssertEqual(lines.map(\.label), ["Jewel Osco", "Shaws"])
        XCTAssertEqual(lines[0].health, .risk)
        XCTAssertEqual(lines[1].health, .watch)
        XCTAssertEqual(lines[0].count, 2)
    }

    func testFiveStarStoreLinesRankWorstPresubFirst() {
        let rows = [
            MetricRow(section: .fiveStar, division: "Jewel Osco", operationsOM: "A", storeNumber: "10", payload: ["star_rating": 4.8, "presub_pct": 2.1]),
            MetricRow(section: .fiveStar, division: "Jewel Osco", operationsOM: "A", storeNumber: "20", payload: ["star_rating": 4.1, "presub_pct": 8.4]),
            MetricRow(section: .fiveStar, division: "Jewel Osco", operationsOM: "A", storeNumber: "30", payload: ["star_rating": 4.4, "presub_pct": 5.0]),
        ]
        let lines = HeartbeatMath.dashboardScopeLines(section: .fiveStar, rows: rows, grain: .store)
        XCTAssertEqual(lines.map { String($0.label.prefix(2)) }, ["20", "30", "10"])
    }

    func testFiveStarMarketLinesRankWorstPresubFirst() {
        let rows = [
            MetricRow(section: .fiveStar, division: "Shaws", operationsOM: "A", storeNumber: "1", payload: ["star_rating": 3.5, "presub_pct": 3.0]),
            MetricRow(section: .fiveStar, division: "Jewel Osco", operationsOM: "B", storeNumber: "2", payload: ["star_rating": 4.8, "presub_pct": 9.2]),
            MetricRow(section: .fiveStar, division: "Mid-Atlantic", operationsOM: "C", storeNumber: "3", payload: ["star_rating": 4.0, "presub_pct": 6.1]),
        ]
        let lines = HeartbeatMath.dashboardScopeLines(section: .fiveStar, rows: rows, grain: .division)
        XCTAssertEqual(lines.map(\.label), ["Jewel Osco", "Mid-Atlantic", "Shaws"])
    }

    func testMarketFiveStarTilesMatchCalloutMetrics() {
        let jewel = MetricRow(
            section: .fiveStar,
            division: "Jewel Osco",
            operationsOM: "A",
            storeNumber: "1",
            payload: [
                "star_rating": 4.1,
                "ott_pct": 81,
                "flash_pct": 80,
                "presub_pct": 4,
                "coe_pct": 22,
                "oth5_pct": 93,
            ]
        )
        let flags = HeartbeatMath.dashboardActionFlags(section: .fiveStar, rows: [jewel], includeAll: true)
        XCTAssertEqual(flags.map(\.name), ["OTT", "Flash", "Presubs", "COE", "OTH 5%"])
        XCTAssertEqual(flags.first { $0.name == "OTT" }?.value, HeartbeatFormat.pct(81))
    }

    func testFiveStarBand() {
        let good = MetricRow(section: .fiveStar, division: "10", operationsOM: "A", storeNumber: "1", payload: ["star_rating": 4.7])
        let watch = MetricRow(section: .fiveStar, division: "10", operationsOM: "A", storeNumber: "2", payload: ["star_rating": 4.2])
        let risk = MetricRow(section: .fiveStar, division: "10", operationsOM: "A", storeNumber: "3", payload: ["star_rating": 3.6])
        XCTAssertEqual(HeartbeatMath.health(for: .fiveStar, row: good), .good)
        XCTAssertEqual(HeartbeatMath.health(for: .fiveStar, row: watch), .watch)
        XCTAssertEqual(HeartbeatMath.health(for: .fiveStar, row: risk), .risk)
    }

    func testPrepNotReadyInverts() {
        let good = MetricRow(section: .prepNotReady, division: "10", operationsOM: "A", storeNumber: "1", payload: ["pnr_rate_pct": 1.2])
        let watch = MetricRow(section: .prepNotReady, division: "10", operationsOM: "A", storeNumber: "3", payload: ["pnr_rate_pct": 2.2])
        let risk = MetricRow(section: .prepNotReady, division: "10", operationsOM: "A", storeNumber: "2", payload: ["pnr_rate_pct": 8.0])
        XCTAssertEqual(HeartbeatMath.health(for: .prepNotReady, row: good), .good)
        XCTAssertEqual(HeartbeatMath.health(for: .prepNotReady, row: watch), .watch)
        XCTAssertEqual(HeartbeatMath.health(for: .prepNotReady, row: risk), .risk)
    }

    func testPrepNotReadyOutlineUsesStoreHoursFile() {
        let parsed = WorkbookParser.parseCSV(SampleMarket.templateCSV(for: .prepNotReady))
        let rows = parsed.map { $0.asRow(section: .prepNotReady) }
        XCTAssertEqual(Set(rows.map(\.storeNumber)), Set(["3427", "1", "2219", "1432"]))
        let haggen = rows.first { $0.storeNumber == "3427" }!
        XCTAssertEqual(haggen.division, "Haggen")
        XCTAssertEqual(haggen.operationsOM, "Luke Lomas")
        XCTAssertEqual(haggen.payload["pnr_rate_pct"] ?? 0, 1.6979, accuracy: 0.02)
        XCTAssertEqual(HeartbeatMath.health(for: .prepNotReady, row: haggen), .good)
        let hotspot = rows.first { $0.storeNumber == "2219" }!
        XCTAssertEqual(hotspot.payload["pnr_rate_pct"] ?? 0, 7.455, accuracy: 0.05)
        XCTAssertEqual(HeartbeatMath.health(for: .prepNotReady, row: hotspot), .risk)
    }

    func testMissingItemsInvertsAtFiveAndSixFifty() {
        func row(_ pct: Double) -> MetricRow {
            MetricRow(section: .missingItems, division: "Jewel Osco", operationsOM: "A", storeNumber: "1", payload: ["mi_pct": pct])
        }
        XCTAssertEqual(HeartbeatMath.missingItemsHealth(row(5.0)), .good)
        XCTAssertEqual(HeartbeatMath.missingItemsHealth(row(5.01)), .watch)
        XCTAssertEqual(HeartbeatMath.missingItemsHealth(row(6.50)), .watch)
        XCTAssertEqual(HeartbeatMath.missingItemsHealth(row(6.51)), .risk)
        XCTAssertEqual(HeartbeatMath.health(for: .missingItems, row: row(4.9)), .good)
        let flags = HeartbeatMath.missingItemsActionFlags([row(4.0), row(5.5), row(8.0)])
        XCTAssertEqual(flags.map(\.name), ["Healthy", "Watch", "At Risk"])
        XCTAssertEqual(flags.map(\.stores), [1, 1, 1])
        XCTAssertEqual(MissingItemDept.match("301 GROCERY"), .grocery)
        XCTAssertEqual(MissingItemDept.match("336 BAKERY PKGD OUTSIDE"), .bakeryPkgd)
        XCTAssertEqual(MissingItemDept.match("317 FROZEN GROCERY"), .frozen)
        XCTAssertNil(MissingItemDept.match("Total"))
    }

    func testDynacapAlignedWithinTenPercent() {
        let aligned = MetricRow(
            section: .dynacap,
            division: "10",
            operationsOM: "A",
            storeNumber: "1",
            payload: ["pickup_capacity": 36, "delivery_capacity": 20, "rec_pickup": 36, "rec_delivery": 20]
        )
        let off = MetricRow(
            section: .dynacap,
            division: "10",
            operationsOM: "A",
            storeNumber: "2",
            payload: ["pickup_capacity": 48, "delivery_capacity": 20, "rec_pickup": 36, "rec_delivery": 20]
        )
        XCTAssertEqual(HeartbeatMath.dynacapAligned(aligned), true)
        XCTAssertEqual(HeartbeatMath.dynacapAligned(off), false)
        XCTAssertEqual(HeartbeatMath.health(for: .dynacap, row: aligned), .good)
        XCTAssertEqual(HeartbeatMath.health(for: .dynacap, row: off), .risk)
        let rateGood = MetricRow(section: .dynacap, division: "Jewel Osco", operationsOM: "Shelly Selof", storeNumber: "1", payload: ["dynacap_rate": 74], textPayload: ["district": "J1"])
        let rateWatch = MetricRow(section: .dynacap, division: "Jewel Osco", operationsOM: "Shelly Selof", storeNumber: "2", payload: ["dynacap_rate": 62], textPayload: ["district": "J1"])
        let rateRisk = MetricRow(section: .dynacap, division: "Jewel Osco", operationsOM: "Shelly Selof", storeNumber: "3", payload: ["dynacap_rate": 54], textPayload: ["district": "J1"])
        XCTAssertEqual(HeartbeatMath.health(for: .dynacap, row: rateGood), .good)
        XCTAssertEqual(HeartbeatMath.health(for: .dynacap, row: rateWatch), .watch)
        XCTAssertEqual(HeartbeatMath.health(for: .dynacap, row: rateRisk), .risk)
    }

    func testDynacapDistrictFileParsesAndJoinsStores() {
        let csv = SampleMarket.templateCSV(for: .dynacap)
        let parsed = WorkbookParser.parseCSV(csv)
        XCTAssertEqual(Set(parsed.map(\.district)), Set(["J1", "J2", "39"]))
        XCTAssertEqual(parsed.first { $0.district == "J1" }?.payload["dynacap_rate"] ?? 0, 74.07, accuracy: 0.02)
        let roster = [
            "1": HeartbeatMath.StoreIdentity(division: "Jewel Osco", district: "J1", om: "Shelly Selof", name: nil),
            "3427": HeartbeatMath.StoreIdentity(division: "Haggen", district: "39", om: "Luke Lomas", name: nil),
        ]
        let rows = parsed.map { $0.asRow(section: .dynacap) }
        let expanded = HeartbeatMath.materializeDistrictMetric(rows, roster: roster)
        XCTAssertEqual(Set(expanded.map(\.storeNumber)), Set(["1", "3427"]))
        XCTAssertEqual(expanded.first { $0.storeNumber == "1" }?.division, "Jewel Osco")
    }

    func testLatestPerStoreKeepsNewestDate() {
        let older = MetricRow(section: .fiveStar, division: "10", operationsOM: "A", storeNumber: "1487", recordedOn: "2026-08-03", payload: ["star_rating": 4.1])
        let newer = MetricRow(section: .fiveStar, division: "10", operationsOM: "A", storeNumber: "1487", recordedOn: "2026-08-17", payload: ["star_rating": 4.8])
        let latest = HeartbeatMath.latestPerStore([older, newer])
        XCTAssertEqual(latest.count, 1)
        XCTAssertEqual(latest.first?.number("star_rating"), 4.8)
    }

    func testScheduleVarianceBandsAndOutlineParse() {
        let good = MetricRow(section: .scheduleQuality, division: "Jewel Osco", operationsOM: "Shelly Selof", storeNumber: "1", payload: ["schedule_efficiency_pct": 93, "under_schedule_pct": 0, "over_schedule_pct": 0])
        let underWatch = MetricRow(section: .scheduleQuality, division: "Jewel Osco", operationsOM: "Shelly Selof", storeNumber: "2", payload: ["schedule_efficiency_pct": 92, "under_schedule_pct": 3, "over_schedule_pct": 0])
        let underRisk = MetricRow(section: .scheduleQuality, division: "Jewel Osco", operationsOM: "Shelly Selof", storeNumber: "3", payload: ["schedule_efficiency_pct": 94, "under_schedule_pct": 6.2, "over_schedule_pct": 0])
        let overRisk = MetricRow(section: .scheduleQuality, division: "Jewel Osco", operationsOM: "Shelly Selof", storeNumber: "4", payload: ["schedule_efficiency_pct": 91, "under_schedule_pct": 0, "over_schedule_pct": 8])
        XCTAssertEqual(HeartbeatMath.scheduleHealth(good), .good)
        XCTAssertEqual(HeartbeatMath.scheduleHealth(underWatch), .watch)
        XCTAssertEqual(HeartbeatMath.scheduleHealth(underRisk), .risk)
        XCTAssertEqual(HeartbeatMath.scheduleHealth(overRisk), .risk)

        let parsed = WorkbookParser.parseCSV(SampleMarket.templateCSV(for: .scheduleQuality))
        XCTAssertEqual(Set(parsed.map(\.storeNumber)), Set(["1", "606", "3427"]))
        XCTAssertEqual(parsed.first { $0.storeNumber == "1" }?.payload["schedule_efficiency_pct"] ?? 0, 93.1, accuracy: 0.05)
        XCTAssertEqual(parsed.first { $0.storeNumber == "606" }?.payload["under_schedule_pct"] ?? 0, 6.1, accuracy: 0.05)

        let remapped = HeartbeatMath.remapSchedulePayload([
            "scheduleefficicencyschvstgt": 0.931,
            "underscheduleschvstgt": 0.061,
            "overscheduleschvstgt": 0.014,
        ])
        XCTAssertEqual(remapped["schedule_efficiency_pct"] ?? 0, 93.1, accuracy: 0.05)
        XCTAssertEqual(remapped["under_schedule_pct"] ?? 0, 6.1, accuracy: 0.05)
        XCTAssertEqual(remapped["over_schedule_pct"] ?? 0, 1.4, accuracy: 0.05)

        let staffing = HeartbeatMath.remapSchedulePayload([
            "staffingefficiencypctpchvstgt": 0.887,
        ])
        XCTAssertEqual(staffing["staffing_efficiency_pct"] ?? 0, 88.7, accuracy: 0.05)
    }

    func testFiveStarFileParsesAndUsesPosterBands() {
        let parsed = WorkbookParser.parseCSV(SampleMarket.templateCSV(for: .fiveStar))
        XCTAssertEqual(Set(parsed.map(\.storeNumber)), Set(["1", "606"]))
        let five = parsed.first { $0.storeNumber == "1" }!.asRow(section: .fiveStar)
        let fail = parsed.first { $0.storeNumber == "606" }!.asRow(section: .fiveStar)
        XCTAssertEqual(five.payload["star_rating"] ?? 0, 5, accuracy: 0.01)
        XCTAssertEqual(five.payload["flash_pct"] ?? 0, 91, accuracy: 0.5)
        XCTAssertEqual(five.payload["presub_pct"] ?? 0, 2.3, accuracy: 0.1)
        XCTAssertEqual(HeartbeatMath.health(for: .fiveStar, row: five), .good)
        XCTAssertEqual(HeartbeatMath.health(for: .fiveStar, row: fail), .risk)
        XCTAssertEqual(HeartbeatMath.flashStar(five), .full)
        XCTAssertEqual(HeartbeatMath.flashStar(fail), .none)
        XCTAssertEqual(HeartbeatMath.presubStar(five), .full)
        XCTAssertEqual(HeartbeatMath.presubStar(fail), .none)
        XCTAssertEqual(HeartbeatMath.ottStar(fail), .half)
    }

    func testPickerScorecardFileParsesAndFlagsOpportunity() {
        let parsed = WorkbookParser.parseCSV(SampleMarket.templateCSV(for: .pickerScorecard))
        let rows = parsed.map { $0.asRow(section: .pickerScorecard) }
        XCTAssertEqual(Set(rows.map(\.shopperName)), Set(["AWHOR08", "JCOLE02"]))
        let strong = rows.first { $0.storeNumber == "1" }!
        let weak = rows.first { $0.storeNumber == "606" }!
        XCTAssertEqual(strong.payload["pph"] ?? 0, 91.4, accuracy: 0.05)
        XCTAssertEqual(strong.payload["presub_pct"] ?? 0, 2.3, accuracy: 0.1)
        XCTAssertEqual(weak.payload["ott_pct"] ?? 0, 0, accuracy: 0.01)
        XCTAssertEqual(HeartbeatMath.pickerHealth(strong), .good)
        XCTAssertEqual(HeartbeatMath.pickerHealth(weak), .risk)
        XCTAssertTrue(HeartbeatMath.pickerOpportunityText(weak).contains("PPH"))
        let boards = HeartbeatMath.topPickersByMetric(rows, limit: 10)
        XCTAssertTrue(boards.contains { $0.metric == "PPH" && $0.rows.contains(where: { $0.storeNumber == "606" }) })
    }

    func testShopperAliasesJoinPathAndScorecardIDs() {
        XCTAssertEqual(HeartbeatMath.canonicalShopper("LMEN-219"), "lmen219")
        XCTAssertEqual(HeartbeatMath.canonicalShopper("LMEN 219"), "lmen219")
        XCTAssertEqual(HeartbeatMath.canonicalShopper("EFINI00"), "efini00")
        let scorecard = MetricRow(
            section: .pickerScorecard,
            division: "10",
            operationsOM: "A",
            storeNumber: "322",
            payload: ["pph": 45.4, "presub_pct": 2.78],
            textPayload: ["shopper_id": "LMEN-219", "shopper_name": "LMEN-219"]
        )
        let path = MetricRow(
            section: .pickPathPicker,
            division: "",
            operationsOM: "",
            storeNumber: "",
            payload: ["compliance_pct": 61.0, "pph": 45.4],
            textPayload: ["shopper_id": "LMEN219", "shopper_name": "LMEN219"]
        )
        let aliases = Set(HeartbeatMath.shopperAliases(scorecard))
        XCTAssertFalse(aliases.isDisjoint(with: HeartbeatMath.shopperAliases(path)))
        let merged = HeartbeatMath.latestPerShopper([path, scorecard])
        XCTAssertEqual(merged.count, 2)
    }

    @MainActor
    func testChecklistReadyAfterEveryKPIHasStatus() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = HeartbeatStore(rootURL: root)
        XCTAssertFalse(store.canSendChecklist)
        store.addChecklistRecipient("not-an-email")
        XCTAssertFalse(store.canSendChecklist)
        store.addChecklistRecipient("leader@example.com, om@example.com")
        XCTAssertEqual(store.checklistRecipients, ["leader@example.com", "om@example.com"])
        XCTAssertTrue(store.canSendChecklist)
        XCTAssertTrue(store.checklistEmailText().contains("eCommerce Fulfillment Checklist"))
        XCTAssertTrue(store.checklistEmailHTML().contains("viewport"))
        XCTAssertTrue(store.checklistEmailSubject().contains("Fulfillment Checklist"))
    }

    func testPickerVolumeRequiresMoreThanFifteenOrders() {
        let low = MetricRow(section: .pickerScorecard, division: "10", operationsOM: "A", storeNumber: "12", payload: ["orders": 15, "pph": 40], textPayload: ["shopper_id": "LOW15", "shopper_name": "LOW15"])
        let high = MetricRow(section: .pickerScorecard, division: "10", operationsOM: "A", storeNumber: "12", payload: ["orders": 16, "pph": 40], textPayload: ["shopper_id": "HIGH16", "shopper_name": "HIGH16"])
        XCTAssertFalse(HeartbeatMath.pickerHasVolume(low))
        XCTAssertTrue(HeartbeatMath.pickerHasVolume(high))
        XCTAssertFalse(HeartbeatMath.pickerMatches(low, focus: .opportunity))
        XCTAssertTrue(HeartbeatMath.pickerMatches(high, focus: .opportunity))
    }

    func testRefundBands() {
        func row(_ amount: Double) -> MetricRow {
            MetricRow(section: .pickerScorecard, division: "10", operationsOM: "A", storeNumber: "12", payload: ["refund_amt": amount], textPayload: ["shopper_id": "R", "shopper_name": "REFUND"])
        }
        XCTAssertEqual(HeartbeatMath.refundHealth(row(0)), .good)
        XCTAssertEqual(HeartbeatMath.refundHealth(row(1)), .watch)
        XCTAssertEqual(HeartbeatMath.refundHealth(row(20)), .watch)
        XCTAssertEqual(HeartbeatMath.refundHealth(row(20.01)), .risk)
        XCTAssertTrue(HeartbeatMath.pickerMatches(row(25), focus: .refund))
        XCTAssertFalse(HeartbeatMath.pickerMatches(row(0), focus: .refund))
    }

    func testLostRevenueSummarizeUsesMarketTotalThenFilterSum() {
        let market = MetricRow(
            section: .lostRevenue,
            division: "",
            operationsOM: "",
            storeNumber: "",
            storeName: "Total",
            payload: [
                "ecomm_sales": 46_077_144.47,
                "lost_revenue": 2_087_654.14,
                "lost_revenue_pct": 4.53,
            ],
            textPayload: ["lost_grain": "market"]
        )
        let jewel = MetricRow(
            section: .lostRevenue,
            division: "Jewel Osco",
            operationsOM: "Shelly Selof",
            storeNumber: "1",
            payload: [
                "ecomm_sales": 10_000,
                "lost_revenue": 450,
                "lost_revenue_pct": 4.5,
            ],
            textPayload: ["lost_grain": "store"]
        )
        let portland = MetricRow(
            section: .lostRevenue,
            division: "Portland",
            operationsOM: "Kennda Richardson",
            storeNumber: "4262",
            payload: [
                "ecomm_sales": 20_000,
                "lost_revenue": 1_600,
                "lost_revenue_pct": 8.0,
            ],
            textPayload: ["lost_grain": "store"]
        )
        let all = HeartbeatMath.summarize(.lostRevenue, rows: [jewel, portland, market], upload: nil)
        XCTAssertEqual(all.headline ?? 0, 2_087_654.14, accuracy: 0.01)
        XCTAssertEqual(all.lostRevenuePct ?? 0, 4.53, accuracy: 0.01)
        XCTAssertEqual(all.storeCount, 2)
        XCTAssertEqual(all.health, .watch)
        XCTAssertEqual(HeartbeatFormat.money(all.headline), "$2,087,654.14")
        XCTAssertEqual(HeartbeatFormat.pct(all.lostRevenuePct), "4.53%")

        let filtered = HeartbeatMath.summarize(.lostRevenue, rows: [jewel], upload: nil)
        XCTAssertEqual(filtered.headline ?? 0, 450, accuracy: 0.01)
        XCTAssertEqual(filtered.lostRevenuePct ?? 0, 4.5, accuracy: 0.05)
        XCTAssertEqual(filtered.storeCount, 1)
        XCTAssertEqual(HeartbeatMath.lostRevenueHealth(portland), .risk)
        XCTAssertEqual(HeartbeatMath.lostRevenueHealth(jewel), .watch)
        XCTAssertEqual(HeartbeatFormat.moneyShort(13_522_827.21), "$13.52M")
        XCTAssertEqual(HeartbeatFormat.moneyShort(1_100), "$1,100")
    }

    func testCanonicalDivisionMapsUnitedAndCompanyMarketsIncludeUnited() {
        XCTAssertEqual(MarketRegion.canonicalName("United"), "United")
        XCTAssertEqual(MarketRegion.canonicalName("United Texas"), "United")
        XCTAssertEqual(MarketRegion.canonicalName("united supermarkets"), "United")
        XCTAssertEqual(MarketRegion.canonicalName("Mid Atlantic"), "Mid-Atlantic")
        XCTAssertEqual(MarketRegion.canonicalName("Jewel Osco"), "Jewel Osco")
        XCTAssertEqual(MarketRegion.canonicalName("Jewel-Osco"), "Jewel Osco")
        XCTAssertEqual(MarketRegion.canonicalName("Mountain West Division"), "Mountain West")
        XCTAssertEqual(MarketRegion.canonicalName("MountainWest"), "Mountain West")
        XCTAssertEqual(MarketRegion.canonicalName("West Region"), "")
        XCTAssertEqual(MarketRegion.canonicalName("Nor Cal"), "NorCal")
        XCTAssertEqual(MarketRegion.canonicalName("SoCal Division"), "SoCal")
        XCTAssertEqual(MarketRegion.divisionChoices(regions: []).count, 12)
        XCTAssertEqual(MarketRegion.divisionChoices(regions: ["West Region"]), ["Mountain West", "Seattle", "Portland", "Haggen"])
        XCTAssertEqual(MarketRegion.east.gateDivisions, ["Shaws", "Jewel Osco", "Mid-Atlantic"])
        XCTAssertEqual(MarketRegion.south.gateDivisions, ["Southern", "United", "Southwest"])
        XCTAssertEqual(MarketRegion.california.gateDivisions, ["NorCal", "SoCal"])
        XCTAssertEqual(
            MarketRegion.uniqueNames(["Mountain West", "Mountain West Division", "mountain west", "West Region", "Total"]),
            ["Mountain West"]
        )
        XCTAssertTrue(MarketRegion.south.contains("United Texas"))
        let all = MarketRegion.companyDivisions(for: DashboardFilters())
        XCTAssertEqual(all.count, 12)
        XCTAssertTrue(all.contains("United"))
        XCTAssertFalse(all.contains("Mid Atlantic"))
        let south = MarketRegion.companyDivisions(for: DashboardFilters(region: "South Region", division: "", district: "", om: "", store: ""))
        XCTAssertEqual(south, ["Southern", "United", "Southwest"])
    }
}

