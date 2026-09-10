import XCTest
@testable import FulfillmentHeartbeat

final class HeartbeatMathTests: XCTestCase {
    func testAssistPromptsRouteOnEveryScorecard() {
        let pairs: [(HubDestination, HeartbeatAssist.Intent)] = [
            (.dashboard, .overview),
            (.lostRevenue, .districts),
            (.missingItems, .districts),
            (.fiveStar, .fiveStar),
            (.pickPath, .districts),
            (.prepNotReady, .districts),
            (.dynacap, .stores),
            (.scheduleQuality, .districts),
            (.pph, .districts),
            (.labor, .districts),
            (.pickerScorecard, .shoppers),
        ]
        for (dest, _) in pairs {
            let prompts = HeartbeatAssist.pagePrompts(dest)
            XCTAssertFalse(prompts.isEmpty, "\(dest) should have prompts")
            for prompt in prompts {
                let intent = HeartbeatAssist.intent(for: prompt, dest: dest)
                XCTAssertNotEqual(intent, .upload, "\(dest) prompt should not route to upload: \(prompt)")
            }
        }
        XCTAssertEqual(HeartbeatAssist.intent(for: "What's the biggest dollar bucket?", dest: .lostRevenue), .buckets)
        XCTAssertEqual(HeartbeatAssist.intent(for: "Which 5 Star KPIs are broken?", dest: .fiveStar), .fiveStar)
        XCTAssertEqual(HeartbeatAssist.intent(for: "Which departments are the hottest?", dest: .missingItems), .missing)
        XCTAssertEqual(HeartbeatAssist.intent(for: "Which stores have stale aisle maps?", dest: .pickPath), .path)
        XCTAssertEqual(HeartbeatAssist.intent(for: "What should grocery own today?", dest: .prepNotReady), .prep)
        XCTAssertEqual(HeartbeatAssist.intent(for: "Is Dynacap hiding a labor problem?", dest: .dynacap), .dynacap)
        XCTAssertEqual(HeartbeatAssist.intent(for: "Is this a map problem or no-shows?", dest: .scheduleQuality), .schedule)
        XCTAssertEqual(HeartbeatAssist.intent(for: "How do we get to 80 PPH?", dest: .pph), .pph)
        XCTAssertEqual(HeartbeatAssist.intent(for: "Is this call-offs or a bad map?", dest: .labor), .labor)
        XCTAssertEqual(HeartbeatAssist.intent(for: "Who should we coach today?", dest: .pickerScorecard), .shoppers)
        XCTAssertFalse(HubDestination.sectionItems.contains { $0.rawValue == "checklist" })
        XCTAssertFalse(HubDestination.allCases.contains { $0.rawValue == "checklist" })
        XCTAssertFalse(HubDestination.metricItems.contains { $0.rawValue == "checklist" })
        XCTAssertFalse(HubDestination.settingsItems.contains { $0.rawValue == "checklist" })
        XCTAssertFalse(HubDestination.allCases.contains { $0.rawValue == "upload" })
        XCTAssertTrue(HubDestination.settingsItems.isEmpty)
        XCTAssertTrue(HubNavSelection.lightsIcon(selected: true))
        XCTAssertFalse(HubNavSelection.lightsIcon(selected: false))
    }

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
        XCTAssertEqual(ordered.map(\.section), [.lostRevenue, .fiveStar, .labor, .pickerScorecard, .missingItems, .pph])
    }

    func testDistrictDashboardPutsLostFiveStarThenLabor() {
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
            card(.lostRevenue, .watch, watch: 1),
            card(.labor, .good),
            card(.pph, .watch, watch: 2),
            card(.pickPath, .good),
        ], role: .districtManager)
        XCTAssertEqual(ordered.map(\.section), [.lostRevenue, .fiveStar, .labor, .missingItems, .pph])
    }

    func testDirectorDashboardKeepsPickerScorecard() {
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
            card(.lostRevenue, .watch, watch: 1),
            card(.fiveStar, .risk, risk: 2),
            card(.labor, .good),
            card(.pickerScorecard, .good),
            card(.pph, .watch, watch: 2),
        ], role: .director)
        XCTAssertEqual(ordered.prefix(4).map(\.section), [.lostRevenue, .fiveStar, .labor, .pickerScorecard])
    }

    func testPickerScopeLinesGroupByDistrict() {
        let rows = [
            MetricRow(section: .pickerScorecard, division: "Jewel Osco", operationsOM: "A", storeNumber: "1", payload: ["pph": 42], textPayload: ["shopper_name": "A", "district": "J2"]),
            MetricRow(section: .pickerScorecard, division: "Jewel Osco", operationsOM: "A", storeNumber: "2", payload: ["pph": 31], textPayload: ["shopper_name": "B", "district": "J3"]),
            MetricRow(section: .pickerScorecard, division: "Jewel Osco", operationsOM: "B", storeNumber: "3", payload: ["pph": 55], textPayload: ["shopper_name": "C", "district": "J2"]),
        ]
        let lines = HeartbeatMath.dashboardScopeLines(section: .pickerScorecard, rows: rows, grain: .district)
        XCTAssertEqual(Set(lines.map(\.label)), ["J2", "J3"])
        XCTAssertEqual(lines.first { $0.label == "J2" }?.count, 2)
    }

    func testDashboardStoreLinesFillMissingRosterStores() {
        let rows = [
            MetricRow(section: .prepNotReady, division: "Jewel Osco", operationsOM: "A", storeNumber: "3466", payload: ["pnr_rate_pct": 3.1]),
            MetricRow(section: .prepNotReady, division: "Jewel Osco", operationsOM: "A", storeNumber: "3503", payload: ["pnr_rate_pct": 1.2]),
        ]
        let roster: [String: HeartbeatMath.StoreIdentity] = [
            "3466": .init(division: "Jewel Osco", district: "J2", om: "A", name: nil),
            "3503": .init(division: "Jewel Osco", district: "J2", om: "A", name: nil),
            "3478": .init(division: "Jewel Osco", district: "J2", om: "A", name: nil),
        ]
        let stores = [("3466", nil as String?), ("3503", nil), ("3478", nil)]
        let lines = HeartbeatMath.dashboardStoreLines(
            section: .prepNotReady,
            rows: rows,
            stores: stores,
            roster: roster
        )
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(Set(lines.map { String($0.label.prefix(4)) }), ["3466", "3503", "3478"])
        XCTAssertEqual(lines.first { $0.label.hasPrefix("3478") }?.health, .none)
        XCTAssertEqual(lines.first { $0.label.hasPrefix("3478") }?.value, "—")
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

    func testPickPathPickerStaysWhenDivisionFilterIsOn() {
        let scorecard = MetricRow(
            section: .pickerScorecard,
            division: "Jewel Osco",
            operationsOM: "Shelly Selof",
            storeNumber: "3503",
            payload: ["pph": 101.6, "presub_pct": 6.78, "oos_pct": 1.48],
            textPayload: ["shopper_id": "AALL215", "shopper_name": "AALL215", "district": "J2"]
        )
        let path = MetricRow(
            section: .pickPathPicker,
            division: "",
            operationsOM: "",
            storeNumber: "",
            payload: ["compliance_pct": 66.19, "pph": 101.6, "orders": 200],
            textPayload: ["shopper_id": "AALL215", "shopper_name": "AALL215"]
        )
        let other = MetricRow(
            section: .pickerScorecard,
            division: "SoCal",
            operationsOM: "A",
            storeNumber: "108",
            payload: ["pph": 80],
            textPayload: ["shopper_id": "ZZZ1", "shopper_name": "ZZZ1"]
        )
        var filters = DashboardFilters()
        filters.division = "Jewel Osco"
        let caches = PulseCaches.build(rows: [scorecard, path, other], filters: filters)
        XCTAssertEqual(caches.filteredLatest[.pickPathPicker]?.count, 1)
        XCTAssertEqual(caches.pickPathByShopper["aall215"]?.number("compliance_pct") ?? 0, 66.19, accuracy: 0.01)
        XCTAssertEqual(caches.pickPathPickersByStore["3503"]?.first?.number("compliance_pct") ?? 0, 66.19, accuracy: 0.01)
        XCTAssertEqual(caches.pphPickersByStore["3503"]?.first?.shopperName, "AALL215")
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

    func testLostRevenueDistrictFilterJoinsStoresWithoutDistrictColumn() {
        let roster: [String: HeartbeatMath.StoreIdentity] = [
            "667": .init(division: "Jewel Osco", district: "03", om: "Pat", name: nil),
            "3031": .init(division: "Jewel Osco", district: "03", om: "Pat", name: nil),
            "2218": .init(division: "Mid-Atlantic", district: "A9", om: "Aimee", name: nil),
        ]
        let district03 = MetricRow(
            section: .lostRevenue,
            division: "",
            operationsOM: "",
            storeNumber: "667",
            payload: ["ecomm_sales": 10_000, "lost_revenue": 400, "lost_revenue_pct": 4],
            textPayload: ["lost_grain": "store"]
        )
        let other = MetricRow(
            section: .lostRevenue,
            division: "",
            operationsOM: "",
            storeNumber: "2218",
            payload: ["ecomm_sales": 8_000, "lost_revenue": 900, "lost_revenue_pct": 11],
            textPayload: ["lost_grain": "store"]
        )
        let market = MetricRow(
            section: .lostRevenue,
            division: "",
            operationsOM: "",
            storeNumber: "",
            storeName: "Total",
            payload: ["ecomm_sales": 46_000_000, "lost_revenue": 96_564, "lost_revenue_pct": 2.81],
            textPayload: ["lost_grain": "market"]
        )
        var filters = DashboardFilters()
        filters.district = "03"
        let allowed = PulseCaches.allowedStores(roster: roster, filters: filters) ?? []
        XCTAssertEqual(allowed, ["667", "3031"])
        let scoped = PulseCaches.rowsMatchingStores(
            [district03, other, market],
            stores: allowed,
            skipMarket: true
        )
        XCTAssertEqual(Set(scoped.map(\.storeNumber)), ["667"])
        let summary = HeartbeatMath.summarize(.lostRevenue, rows: scoped, upload: nil)
        XCTAssertEqual(summary.headline ?? 0, 400, accuracy: 0.01)
        XCTAssertNotEqual(summary.health, .none)
        XCTAssertEqual(summary.storeCount, 1)
    }

    func testPulseCachesBuildJoinsLostRevenueWhenOnlyFiveStarHasDistrict() {
        func five(_ store: String, district: String, division: String) -> MetricRow {
            MetricRow(
                section: .fiveStar,
                division: division,
                operationsOM: "Pat",
                storeNumber: store,
                payload: ["five_star": 4.6],
                textPayload: ["district": district]
            )
        }
        func lost(_ store: String, dollars: Double) -> MetricRow {
            MetricRow(
                section: .lostRevenue,
                division: "",
                operationsOM: "",
                storeNumber: store,
                payload: ["ecomm_sales": dollars * 20, "lost_revenue": dollars, "lost_revenue_pct": 5],
                textPayload: ["lost_grain": "store"]
            )
        }
        let rows = [
            five("667", district: "03", division: "Jewel Osco"),
            five("1507", district: "03", division: "Jewel Osco"),
            five("2218", district: "A9", division: "Mid-Atlantic"),
            lost("667", dollars: 1_832),
            lost("1507", dollars: 7_777),
            lost("2218", dollars: 900),
            MetricRow(
                section: .lostRevenue,
                division: "",
                operationsOM: "",
                storeNumber: "",
                storeName: "Total",
                payload: ["ecomm_sales": 46_000_000, "lost_revenue": 96_564, "lost_revenue_pct": 2.81],
                textPayload: ["lost_grain": "market"]
            ),
        ]
        var filters = DashboardFilters()
        filters.district = "03"
        let caches = PulseCaches.build(rows: rows, filters: filters, uploads: [], heavy: false, grain: .store)
        let summary = caches.cachedSummaries.first { $0.section == .lostRevenue }
        XCTAssertEqual(summary?.storeCount, 2)
        XCTAssertEqual(summary?.headline ?? 0, 9_609, accuracy: 0.01)
        XCTAssertNotEqual(summary?.health, .none)
        let scoped = Set((caches.filteredLatest[.lostRevenue] ?? []).map(\.storeNumber))
        XCTAssertEqual(scoped, ["667", "1507"])
    }

    func testOfficialRosterDrivesDistrict03Filter() {
        let rosterCSV = """
        DIVISION,DISTRICT,OM_AREA,OM_ID,STORE
        NorCal,03,NorCal 04,Jino Arvin,304
        NorCal,03,NorCal 04,Jino Arvin,667
        Jewel Osco,J1,Chicago 1,Shelly Selof,1
        """
        let parsed = WorkbookParser.parseCSV(rosterCSV)
        XCTAssertEqual(parsed.count, 3)
        let rosterRows = parsed.map { $0.asRow(section: .storeRoster) }
        let lost = MetricRow(
            section: .lostRevenue,
            division: "",
            operationsOM: "",
            storeNumber: "304",
            payload: ["ecomm_sales": 50_254, "lost_revenue": 2_510, "lost_revenue_pct": 4.99],
            textPayload: ["lost_grain": "store"]
        )
        var filters = DashboardFilters()
        filters.district = "03"
        let caches = PulseCaches.build(
            rows: rosterRows + [lost],
            filters: filters,
            uploads: [],
            heavy: false,
            grain: .store
        )
        let allowed = PulseCaches.allowedStores(roster: caches.roster, filters: filters) ?? []
        XCTAssertEqual(allowed, ["304", "667"])
        let summary = caches.cachedSummaries.first { $0.section == .lostRevenue }
        XCTAssertEqual(summary?.headline ?? 0, 2_510, accuracy: 0.01)
        XCTAssertEqual(summary?.storeCount, 1)
    }

    func testDistrictD3MatchesRoster03() {
        XCTAssertFalse(HeartbeatMath.districtMatchKeys("03").contains("d3"))
        XCTAssertFalse(HeartbeatMath.districtMatchKeys("D3").contains("3"))
        XCTAssertTrue(HeartbeatMath.districtMatchKeys("03").contains("03"))
        XCTAssertTrue(HeartbeatMath.districtMatchKeys("03").contains("3"))
        XCTAssertFalse(HeartbeatMath.districtMatchKeys("B3").contains("3"))
        XCTAssertFalse(HeartbeatMath.districtMatchKeys("J3").contains("3"))
        var filters = DashboardFilters()
        filters.district = "D3"
        XCTAssertTrue(filters.includesDistrict("D3"))
        XCTAssertFalse(filters.includesDistrict("03"))
        XCTAssertFalse(filters.includesDistrict("B3"))
        XCTAssertFalse(filters.includesDistrict("I3"))
        filters.district = "03"
        XCTAssertTrue(filters.includesDistrict("03"))
        XCTAssertTrue(filters.includesDistrict("3"))
        XCTAssertFalse(filters.includesDistrict("D3"))
        XCTAssertFalse(filters.includesDistrict("B3"))
        XCTAssertFalse(filters.includesDistrict("J3"))
        let rosterRows = [
            MetricRow(
                section: .storeRoster,
                division: "NorCal",
                operationsOM: "Jino Arvin",
                storeNumber: "304",
                textPayload: ["roster": "1", "district": "03"]
            )
        ]
        let lost = MetricRow(
            section: .lostRevenue,
            storeNumber: "304",
            payload: ["lost_revenue": 2_510, "ecomm_sales": 50_254],
            textPayload: ["lost_grain": "store"]
        )
        let caches = PulseCaches.build(
            rows: rosterRows + [lost],
            filters: filters,
            uploads: [],
            heavy: false,
            grain: .store
        )
        let allowed = PulseCaches.allowedStores(roster: caches.roster, filters: filters) ?? []
        XCTAssertTrue(allowed.contains("304"))
        let summary = caches.cachedSummaries.first { $0.section == .lostRevenue }
        XCTAssertEqual(summary?.headline ?? 0, 2_510, accuracy: 0.01)
        XCTAssertEqual(summary?.storeCount, 1)
    }

    func testPublishedFactsKeepsDistrict03SeparateFromD3() throws {
        let tests = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let url = tests.deletingLastPathComponent().appendingPathComponent("FulfillmentHeartbeat/facts.json")
        let file = try JSONDecoder().decode(PulseFactsFile.self, from: Data(contentsOf: url))
        let rows = PulseFacts.metricRows(from: file)
        XCTAssertGreaterThan(rows.count, 1000)

        func summary(for district: String) -> SectionSummary {
            var filters = DashboardFilters()
            filters.district = district
            let caches = PulseCaches.build(rows: rows, filters: filters, uploads: [], heavy: false, grain: .store)
            return caches.cachedSummaries.first { $0.section == .lostRevenue }!
        }

        let d03 = summary(for: "03")
        let dD3 = summary(for: "D3")
        let dB3 = summary(for: "B3")
        XCTAssertEqual(d03.storeCount, 20)
        XCTAssertEqual(d03.headline ?? 0, 36_193, accuracy: 1)
        XCTAssertEqual(dD3.storeCount, 17)
        XCTAssertEqual(dD3.headline ?? 0, 21_547, accuracy: 1)
        XCTAssertEqual(dB3.storeCount, 23)
        XCTAssertGreaterThan(dB3.headline ?? 0, 50_000)
        XCTAssertNotEqual(d03.headline, dD3.headline)
        XCTAssertLessThan(d03.lostRevenuePct ?? 99, 20)
        XCTAssertLessThan(dD3.lostRevenuePct ?? 99, 20)

        func caches(for district: String) -> PulseCaches {
            var filters = DashboardFilters()
            filters.district = district
            return PulseCaches.build(rows: rows, filters: filters, uploads: [], heavy: false, grain: .store)
        }
        let c03 = caches(for: "03")
        XCTAssertEqual(c03.cachedStores.count, 20)
        let sales = c03.cachedSummaries.first { $0.section == .sales }
        XCTAssertEqual(sales?.storeCount, 20)
        XCTAssertEqual(sales?.headline ?? 0, 2_312_699, accuracy: 5)
        let five = c03.cachedSummaries.first { $0.section == .fiveStar }
        XCTAssertEqual(five?.storeCount, 20)
        XCTAssertEqual(five?.headline ?? 0, 4.525, accuracy: 0.02)
        let labor = PulseCaches.rowsMatchingStores(
            rows.filter { $0.section == .lostRevenue },
            stores: Set(c03.cachedStores.map(\.number)),
            skipMarket: true
        )
        XCTAssertEqual(labor.count, 20)
    }

    func testRosterDistrictWinsOverSheetStampOnEverySection() {
        let roster = MetricRow(
            section: .storeRoster,
            division: "Jewel Osco",
            operationsOM: "Pat",
            storeNumber: "667",
            textPayload: ["roster": "1", "district": "03"]
        )
        func sheet(_ section: MetricSection, extra: [String: String] = [:]) -> MetricRow {
            var text = extra
            text["district"] = "B3"
            return MetricRow(
                section: section,
                division: "Shaws",
                operationsOM: "Wrong",
                storeNumber: "667",
                payload: ["lost_revenue": 100, "ecomm_sales": 5_000, "sales_dollars": 9_000, "star_rating": 4.2],
                textPayload: text
            )
        }
        let rows = [
            roster,
            sheet(.lostRevenue, extra: ["lost_grain": "store"]),
            sheet(.sales, extra: ["sales_grain": "store"]),
            sheet(.fiveStar)
        ]
        var filters = DashboardFilters()
        filters.district = "03"
        let caches = PulseCaches.build(rows: rows, filters: filters, uploads: [], heavy: false, grain: .store)
        XCTAssertEqual(PulseCaches.allowedStores(roster: caches.roster, filters: filters), ["667"])
        for section in [MetricSection.lostRevenue, .sales, .fiveStar] {
            let row = caches.filteredLatest[section]?.first
            XCTAssertEqual(HeartbeatMath.canonicalDistrict(row?.district ?? ""), "03", "\(section)")
            XCTAssertEqual(MarketRegion.canonicalName(row?.division ?? ""), "Jewel Osco", "\(section)")
        }
        filters.district = "B3"
        let other = PulseCaches.build(rows: rows, filters: filters, uploads: [], heavy: false, grain: .store)
        XCTAssertTrue((PulseCaches.allowedStores(roster: other.roster, filters: filters) ?? []).isEmpty)
    }

    func testSalesHeadlineUsesTotalColumnNotDaySum() {
        var row = MetricRow(
            section: .sales,
            division: "Jewel Osco",
            operationsOM: "",
            storeNumber: "1",
            payload: [
                "sales_dollars": 39_761_217,
                "sales_d0_dollars": 13_466_026,
                "sales_d1_dollars": 15_180_411,
                "sales_d2_dollars": 11_114_780
            ],
            textPayload: ["sales_grain": "store"]
        )
        XCTAssertEqual(HeartbeatMath.salesHeadlineDollars(row), 39_761_217, accuracy: 0.5)

        row.payload["sales_dollars"] = 0
        XCTAssertEqual(
            HeartbeatMath.salesHeadlineDollars(row),
            13_466_026 + 15_180_411 + 11_114_780,
            accuracy: 0.5
        )

        let summary = HeartbeatMath.summarize(.sales, rows: [
            MetricRow(
                section: .sales,
                division: "",
                operationsOM: "",
                storeNumber: "",
                payload: ["sales_dollars": 132_830_508],
                textPayload: ["sales_grain": "company"]
            ),
            MetricRow(
                section: .sales,
                division: "Jewel Osco",
                operationsOM: "",
                storeNumber: "1",
                payload: ["sales_dollars": 13_466_026],
                textPayload: ["sales_grain": "store"]
            ),
            MetricRow(
                section: .sales,
                division: "Shaws",
                operationsOM: "",
                storeNumber: "2",
                payload: ["sales_dollars": 15_180_411],
                textPayload: ["sales_grain": "store"]
            ),
            MetricRow(
                section: .sales,
                division: "United",
                operationsOM: "",
                storeNumber: "3",
                payload: ["sales_dollars": 11_114_780],
                textPayload: ["sales_grain": "store"]
            )
        ], upload: nil)
        XCTAssertEqual(summary.headline ?? 0, 39_761_217, accuracy: 0.5)
        XCTAssertEqual(summary.storeCount, 3)
    }

    func testFactsSnapshotCannotReplaceLiveSales() {
        let live = MetricRow(
            section: .sales,
            division: "Jewel Osco",
            operationsOM: "",
            storeNumber: "1",
            payload: ["sales_dollars": 39_761_217],
            textPayload: ["sales_grain": "store", "sales_week": "202637"]
        )
        let stale = MetricRow(
            section: .sales,
            division: "Jewel Osco",
            operationsOM: "",
            storeNumber: "1",
            payload: ["sales_dollars": 132_830_508],
            textPayload: ["sales_grain": "store", "sales_week": "202636"]
        )
        let roster = MetricRow(
            section: .storeRoster,
            division: "Jewel Osco",
            operationsOM: "Pat",
            storeNumber: "1",
            textPayload: ["roster": "1", "district": "03"]
        )
        XCTAssertEqual(PulseDataPolicy.identityOnly([stale, roster]).map(\.section), [.storeRoster])
        let afterFacts = PulseDataPolicy.applyIdentity(existing: [live], identity: [stale, roster])
        XCTAssertEqual(afterFacts.filter { $0.section == .sales }.count, 1)
        XCTAssertEqual(afterFacts.first { $0.section == .sales }?.payload["sales_dollars"], 39_761_217)

        let merged = PulseDataPolicy.replaceLiveSections(existing: [stale], live: [live])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].payload["sales_dollars"], 39_761_217)
        XCTAssertEqual(PulseDataPolicy.weekKey(from: merged), "202637")
    }

    func testSalesDayRowsKeepTuesday() {
        let row = MetricRow(
            section: .sales,
            division: "Jewel Osco",
            operationsOM: "",
            storeNumber: "1",
            payload: [
                "sales_dollars": 39_761_217,
                "sales_d0_dollars": 13_466_026,
                "sales_d1_dollars": 15_180_411,
                "sales_d2_dollars": 11_114_780,
                "sales_d0_orders": 1,
                "sales_d1_orders": 1,
                "sales_d2_orders": 1
            ],
            textPayload: ["sales_grain": "store", "sales_days": "Sunday,Monday,Tuesday"]
        )
        let days = SalesRollupBuilder.dayRows(from: [row])
        XCTAssertEqual(days.map(\.label), ["Sunday", "Monday", "Tuesday"])
        XCTAssertEqual(days[0].pack.sales ?? 0, 13_466_026, accuracy: 0.5)
        XCTAssertEqual(days[1].pack.sales ?? 0, 15_180_411, accuracy: 0.5)
        XCTAssertEqual(days[2].pack.sales ?? 0, 11_114_780, accuracy: 0.5)
    }

    func testPowerBISalesTabSundayMondayTuesdayAndTotal() {
        let metric = ["Sales $", "Sales YoY %", "Orders", "Orders YoY %", "AOS", "AOS YoY %", "AIV", "AIV YoY", "Items P/TXN", "Item P/TXN YoY", "Total Items", "Total Items YoY"]
        let weekday = ["Weekday"]
            + Array(repeating: "1-SUNDAY", count: 12)
            + Array(repeating: "2-MONDAY", count: 12)
            + Array(repeating: "3-TUESDAY", count: 12)
            + Array(repeating: "4-WEDNESDAY", count: 12)
            + Array(repeating: "Total", count: 12)
            + Array(repeating: "Total", count: 12)
        let header = ["Store"] + metric + metric + metric + metric + metric + metric
        let store = ["1"]
            + ["5448.03", "-0.24104175", "54", "-0.16923077", "100.88944", "-0.08643914", "4.3376035", "0.05460828", "23.259259", "-2.5253561", "1256", "-0.25059666"]
            + ["6257.51", "0.53707898", "60", "0.36363636", "104.29183", "0.12719125", "4.4191455", "-0.01071306", "23.6", "2.7136364", "1416", "0.54080522"]
            + ["5974.18", "0.69159720", "66", "0.83333333", "90.517879", "-0.07731062", "4.3511872", "-0.20581927", "20.803030", "-0.72474747", "1373", "0.77161290"]
            + ["-1", "-1", "-1", "-1", "-1", "-1", "-1", "-1", "-1", "-1", "-1", "-1"]
            + ["17679.72", "0.19610961", "180", "0.24137931", "98.220667", "-0.03646726", "4.3707590", "-0.01530039", "22.472222", "-0.76915709", "4045", "0.20029674"]
            + ["17679.72", "0.19610961", "180", "0.24137931", "98.220667", "-0.03646726", "4.3707590", "-0.01530039", "22.472222", "-0.76915709", "4045", "0.20029674"]
        let total = ["Total"]
            + ["13375189.33", "-0.05902716", "139882", "-0.02728676", "95.617659", "-0.03263078", "4.3906372", "0.01539590", "21.777627", "-0.81380883", "3046298", "-0.06232670"]
            + ["15072088.06", "0.55034734", "158968", "0.48245410", "94.812088", "0.04579788", "4.4044869", "-0.02245046", "21.526251", "1.0470697", "3421985", "0.55824974"]
            + ["11022667.84", "0.39938636", "122951", "0.33574152", "89.650900", "0.04764757", "4.4439755", "-0.02395726", "20.173581", "1.0207572", "2480362", "0.40693039"]
            + ["-1", "-1", "-1", "-1", "-1", "-1", "-1", "-1", "-1", "-1", "-1", "-1"]
            + ["39469945.23", "0.24069580", "421801", "0.22943227", "93.574802", "0.00916157", "4.4107175", "-0.00294585", "21.215324", "0.20663259", "8948645", "0.24152445"]
            + ["39469945.23", "0.24069580", "421801", "0.22943227", "93.574802", "0.00916157", "4.4107175", "-0.00294585", "21.215324", "0.20663259", "8948645", "0.24152445"]
        let parsed = WorkbookParser.parseSalesMatrix([
            ["Week", "202637"],
            weekday,
            header,
            store,
            total
        ])
        let row = parsed.first { $0.storeNumber == "1" }
        XCTAssertNotNil(row)
        XCTAssertEqual(row?.payload["sales_dollars"] ?? 0, 17679.72, accuracy: 0.02)
        XCTAssertEqual(row?.payload["sales_orders"] ?? 0, 180, accuracy: 0.01)
        XCTAssertEqual(row?.payload["sales_aos"] ?? 0, 98.2207, accuracy: 0.02)
        XCTAssertEqual(row?.payload["sales_aiv"] ?? 0, 4.3708, accuracy: 0.02)
        XCTAssertEqual(row?.payload["sales_ipt"] ?? 0, 22.4722, accuracy: 0.02)
        XCTAssertEqual(row?.payload["sales_items"] ?? 0, 4045, accuracy: 0.5)
        XCTAssertEqual(row?.payload["sales_yoy_pct"] ?? 0, 19.61096, accuracy: 0.05)

        XCTAssertEqual(row?.payload["sales_d0_dollars"] ?? 0, 5448.03, accuracy: 0.02)
        XCTAssertEqual(row?.payload["sales_d0_yoy_pct"] ?? 0, -24.104, accuracy: 0.05)
        XCTAssertEqual(row?.payload["sales_d0_orders"] ?? 0, 54, accuracy: 0.01)
        XCTAssertEqual(row?.payload["sales_d0_orders_yoy_pct"] ?? 0, -16.923, accuracy: 0.05)
        XCTAssertEqual(row?.payload["sales_d0_aos"] ?? 0, 100.889, accuracy: 0.02)
        XCTAssertEqual(row?.payload["sales_d0_aiv"] ?? 0, 4.338, accuracy: 0.02)
        XCTAssertEqual(row?.payload["sales_d0_ipt"] ?? 0, 23.259, accuracy: 0.02)
        XCTAssertEqual(row?.payload["sales_d0_items"] ?? 0, 1256, accuracy: 0.5)

        XCTAssertEqual(row?.payload["sales_d1_dollars"] ?? 0, 6257.51, accuracy: 0.02)
        XCTAssertEqual(row?.payload["sales_d1_orders"] ?? 0, 60, accuracy: 0.01)
        XCTAssertEqual(row?.payload["sales_d1_items"] ?? 0, 1416, accuracy: 0.5)

        XCTAssertEqual(row?.payload["sales_d2_dollars"] ?? 0, 5974.18, accuracy: 0.02)
        XCTAssertEqual(row?.payload["sales_d2_yoy_pct"] ?? 0, 69.16, accuracy: 0.05)
        XCTAssertEqual(row?.payload["sales_d2_orders"] ?? 0, 66, accuracy: 0.01)
        XCTAssertEqual(row?.payload["sales_d2_orders_yoy_pct"] ?? 0, 83.333, accuracy: 0.05)
        XCTAssertEqual(row?.payload["sales_d2_aos"] ?? 0, 90.518, accuracy: 0.02)
        XCTAssertEqual(row?.payload["sales_d2_aiv"] ?? 0, 4.351, accuracy: 0.02)
        XCTAssertEqual(row?.payload["sales_d2_ipt"] ?? 0, 20.803, accuracy: 0.02)
        XCTAssertEqual(row?.payload["sales_d2_items"] ?? 0, 1373, accuracy: 0.5)
        XCTAssertNil(row?.payload["sales_d3_dollars"])
        XCTAssertTrue((row?.textPayload["sales_days"] ?? "").contains("Tuesday"))

        let company = parsed.first { $0.textPayload["sales_grain"] == "company" }
        XCTAssertEqual(company?.payload["sales_dollars"] ?? 0, 39_469_945, accuracy: 1)
        XCTAssertEqual(company?.payload["sales_orders"] ?? 0, 421_801, accuracy: 0.5)
        XCTAssertEqual(company?.payload["sales_items"] ?? 0, 8_948_645, accuracy: 0.5)
        XCTAssertEqual(company?.payload["sales_d2_dollars"] ?? 0, 11_022_667.84, accuracy: 1)

        let days = SalesRollupBuilder.dayRows(from: parsed.map { $0.asRow(section: .sales) }.filter { !$0.storeNumber.isEmpty })
        XCTAssertEqual(days.map(\.label), ["Sunday", "Monday", "Tuesday"])
        XCTAssertEqual(days[2].pack.orders ?? 0, 66, accuracy: 0.01)
        XCTAssertEqual(days[2].pack.items ?? 0, 1373, accuracy: 0.5)
        XCTAssertEqual(days[2].pack.aos ?? 0, 90.518, accuracy: 0.05)
        XCTAssertEqual(days[2].pack.aiv ?? 0, 4.351, accuracy: 0.05)
        XCTAssertEqual(days[2].pack.ipt ?? 0, 20.803, accuracy: 0.05)

        let companyRow = parsed.first { $0.textPayload["sales_grain"] == "company" }.map { $0.asRow(section: .sales) }
        XCTAssertNotNil(companyRow)
        let locked = SalesRollupBuilder.dayRows(
            from: parsed.map { $0.asRow(section: .sales) }.filter { !$0.storeNumber.isEmpty && $0.storeNumber != "Total" },
            company: companyRow
        )
        XCTAssertEqual(locked[0].pack.sales ?? 0, 13_375_189.33, accuracy: 0.5)
        XCTAssertEqual(locked[0].pack.yoy ?? 0, -5.90, accuracy: 0.05)
        XCTAssertEqual(locked[0].pack.orders ?? 0, 139_882, accuracy: 0.5)
        XCTAssertEqual(locked[0].pack.ordersYoy ?? 0, -2.73, accuracy: 0.05)
        XCTAssertEqual(locked[0].pack.aos ?? 0, 95.62, accuracy: 0.05)
        XCTAssertEqual(locked[0].pack.aiv ?? 0, 4.39, accuracy: 0.02)
        XCTAssertEqual(locked[0].pack.ipt ?? 0, 21.78, accuracy: 0.05)
        XCTAssertEqual(locked[0].pack.items ?? 0, 3_046_298, accuracy: 0.5)
        XCTAssertEqual(locked[1].pack.yoy ?? 0, 55.03, accuracy: 0.08)
        XCTAssertEqual(locked[1].pack.ordersYoy ?? 0, 48.25, accuracy: 0.08)
    }

    func testFilterJoinMatchesPaddedStoreNumbers() {
        let roster: [String: HeartbeatMath.StoreIdentity] = [
            "667": .init(division: "Jewel Osco", district: "D3", om: "Pat", name: nil),
            "304": .init(division: "NorCal", district: "03", om: "Jino", name: nil)
        ]
        var filters = DashboardFilters()
        filters.district = "D3"
        let allowed = PulseCaches.allowedStores(roster: roster, filters: filters) ?? []
        XCTAssertEqual(allowed, ["667"])
        let padded = MetricRow(
            section: .lostRevenue,
            storeNumber: "0667",
            payload: ["lost_revenue": 1_832, "ecomm_sales": 40_000],
            textPayload: ["lost_grain": "store"]
        )
        let other = MetricRow(
            section: .lostRevenue,
            storeNumber: "0304",
            payload: ["lost_revenue": 2_510, "ecomm_sales": 50_000],
            textPayload: ["lost_grain": "store"]
        )
        let scoped = PulseCaches.rowsMatchingStores(
            [padded, other],
            stores: allowed,
            skipMarket: true
        )
        XCTAssertEqual(scoped.map(\.storeNumber), ["0667"])
        let summary = HeartbeatMath.summarize(.lostRevenue, rows: scoped, upload: nil)
        XCTAssertEqual(summary.headline ?? 0, 1_832, accuracy: 0.01)
        XCTAssertEqual(summary.storeCount, 1)
    }

    func testFactsFillMissingLostRevenueForDistrict03() throws {
        let tests = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let url = tests.deletingLastPathComponent().appendingPathComponent("FulfillmentHeartbeat/facts.json")
        let file = try JSONDecoder().decode(PulseFactsFile.self, from: Data(contentsOf: url))
        let facts = PulseFacts.metricRows(from: file)
        let shawsOnly = facts.filter {
            $0.section == .lostRevenue && $0.division == "Shaws"
        }
        XCTAssertGreaterThan(shawsOnly.count, 50)
        XCTAssertFalse(shawsOnly.contains { HeartbeatMath.canonicalStore($0.storeNumber) == "304" })
        let filled = PulseDataPolicy.fillMissing(existing: shawsOnly, facts: facts)
        let lost = filled.filter { $0.section == .lostRevenue }
        XCTAssertGreaterThan(lost.count, 1_500)
        var filters = DashboardFilters()
        filters.district = "03"
        let caches = PulseCaches.build(rows: facts.filter { $0.section == .storeRoster } + lost, filters: filters, uploads: [], heavy: false, grain: .store)
        let summary = caches.cachedSummaries.first { $0.section == .lostRevenue }
        XCTAssertEqual(summary?.storeCount, 20)
        XCTAssertEqual(summary?.headline ?? 0, 36_193, accuracy: 1)
        let store304 = (caches.filteredLatest[.lostRevenue] ?? []).first {
            HeartbeatMath.canonicalStore($0.storeNumber) == "304"
        }
        XCTAssertEqual(store304?.number("lost_revenue") ?? 0, 2_510, accuracy: 0.5)
    }

    func testBundledFactsJoinJewelOscoLostRevenue() throws {
        let tests = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let url = tests.deletingLastPathComponent().appendingPathComponent("FulfillmentHeartbeat/facts.json")
        let file = try JSONDecoder().decode(PulseFactsFile.self, from: Data(contentsOf: url))
        let rows = PulseFacts.metricRows(from: file)
        var filters = DashboardFilters()
        filters.division = "Jewel Osco"
        let caches = PulseCaches.build(rows: rows, filters: filters, uploads: [], heavy: false, grain: .district)
        let summary = caches.cachedSummaries.first { $0.section == .lostRevenue }
        XCTAssertEqual(summary?.storeCount, 179)
        XCTAssertEqual(summary?.headline ?? 0, 451_085, accuracy: 5)
        XCTAssertNotEqual(summary?.health, .none)
    }

    func testCompanyWideLostRevenueRegionsAllHaveDollars() throws {
        let tests = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let url = tests.deletingLastPathComponent().appendingPathComponent("FulfillmentHeartbeat/facts.json")
        let file = try JSONDecoder().decode(PulseFactsFile.self, from: Data(contentsOf: url))
        let rows = PulseFacts.metricRows(from: file)
        let caches = PulseCaches.build(rows: rows, filters: DashboardFilters(), uploads: [], heavy: false, grain: .region)
        let summary = caches.cachedSummaries.first { $0.section == .lostRevenue }
        XCTAssertEqual(summary?.storeCount, 2161)
        XCTAssertEqual(summary?.headline ?? 0, 3_456_041, accuracy: 50)
        let packs = caches.cachedGrainPacks[.lostRevenue] ?? []
        XCTAssertEqual(packs.count, 4)
        for pack in packs {
            XCTAssertGreaterThan(pack.line.count, 0, pack.line.label)
            XCTAssertFalse(pack.line.value == "—" || pack.line.value == "$0", pack.line.label)
        }
        let east = packs.first { $0.line.label == "East Region" }
        XCTAssertEqual(east?.line.count, 612)
    }

    func testFactsSalesAndFiveStarCompanyWide() throws {
        let tests = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let url = tests.deletingLastPathComponent().appendingPathComponent("FulfillmentHeartbeat/facts.json")
        let file = try JSONDecoder().decode(PulseFactsFile.self, from: Data(contentsOf: url))
        let rows = PulseFacts.metricRows(from: file)
        let caches = PulseCaches.build(rows: rows, filters: DashboardFilters(), uploads: [], heavy: false, grain: .region)
        let sales = caches.cachedSummaries.first { $0.section == .sales }
        XCTAssertEqual(sales?.headline ?? 0, 132_830_509, accuracy: 50)
        let stars = caches.cachedSummaries.first { $0.section == .fiveStar }
        XCTAssertGreaterThan(stars?.storeCount ?? 0, 2_000)
        for section in [MetricSection.sales, .fiveStar, .lostRevenue] {
            let packs = caches.cachedGrainPacks[section] ?? []
            XCTAssertEqual(packs.count, 4, section.rawValue)
            for pack in packs {
                XCTAssertGreaterThan(pack.line.count, 0, "\(section.rawValue) \(pack.line.label)")
            }
        }
    }

    func testPulseQueryFilterMatchesPowerBI() throws {
        let tests = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let url = tests.deletingLastPathComponent().appendingPathComponent("FulfillmentHeartbeat/facts.json")
        let file = try JSONDecoder().decode(PulseFactsFile.self, from: Data(contentsOf: url))
        let rows = PulseFacts.metricRows(from: file)
        var warehouse: [MetricSection: [MetricRow]] = [:]
        var roster: [String: HeartbeatMath.StoreIdentity] = [:]
        for row in rows where row.section == .storeRoster || row.textPayload["roster"] == "1" {
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            guard !store.isEmpty else { continue }
            roster[store] = HeartbeatMath.StoreIdentity(
                division: row.division, district: row.district, om: row.operationsOM, name: row.storeName
            )
        }
        for section in [MetricSection.lostRevenue, .sales, .fiveStar] {
            let facts = rows.filter { PulseQuery.isStoreFact($0) && $0.section == section }
            warehouse[section] = HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(facts), roster: roster)
        }

        let company = PulseQuery.paint(
            warehouse: warehouse, roster: roster, filters: DashboardFilters(),
            grain: .region, uploads: [], hidePicker: true, light: false
        )
        let sales = company.summaries.first { $0.section == .sales }
        XCTAssertEqual(sales?.headline ?? 0, 132_830_509, accuracy: 50)
        let lost = company.summaries.first { $0.section == .lostRevenue }
        XCTAssertEqual(lost?.storeCount, 2161)
        XCTAssertEqual(lost?.headline ?? 0, 3_456_041, accuracy: 50)
        XCTAssertEqual((company.grains[.lostRevenue] ?? []).count, 4)

        var district = DashboardFilters()
        district.district = "03"
        let d3 = PulseQuery.paint(
            warehouse: warehouse, roster: roster, filters: district,
            grain: .store, uploads: [], hidePicker: true, light: false
        )
        let d3Lost = d3.summaries.first { $0.section == .lostRevenue }
        XCTAssertEqual(d3Lost?.storeCount, 20)
        XCTAssertEqual(d3Lost?.headline ?? 0, 36_193, accuracy: 1)
        XCTAssertNotNil((d3.filtered[.lostRevenue] ?? []).first {
            HeartbeatMath.canonicalStore($0.storeNumber) == "304"
        })

        var jewel = DashboardFilters()
        jewel.division = "Jewel Osco"
        let jo = PulseQuery.paint(
            warehouse: warehouse, roster: roster, filters: jewel,
            grain: .district, uploads: [], hidePicker: true, light: false
        )
        let joLost = jo.summaries.first { $0.section == .lostRevenue }
        XCTAssertEqual(joLost?.storeCount, 179)
        XCTAssertEqual(joLost?.headline ?? 0, 451_085, accuracy: 5)

        let light = PulseQuery.paint(
            warehouse: warehouse, roster: roster, filters: district,
            grain: .store, uploads: [], hidePicker: true, light: true
        )
        let lightLost = light.summaries.first { $0.section == .lostRevenue }
        XCTAssertEqual(lightLost?.storeCount, 20)
        XCTAssertEqual(lightLost?.headline ?? 0, 36_193, accuracy: 1)

        let allowed = PulseCaches.allowedStores(roster: roster, filters: district)
        let page = PulseQuery.slice(warehouse[.lostRevenue] ?? [], allowed: allowed)
        XCTAssertEqual(page.count, 20)
        XCTAssertEqual(page.reduce(0) { $0 + ($1.number("lost_revenue") ?? 0) }, 36_193, accuracy: 1)
        let unfilteredFallback = PulseQuery.slice(warehouse[.lostRevenue] ?? [], allowed: nil)
        XCTAssertGreaterThan(unfilteredFallback.count, 2_000)
    }

    func testPickerSliceKeepsEveryShopperInTheFilter() {
        func shopper(_ store: String, _ name: String, pph: Double) -> MetricRow {
            MetricRow(
                section: .pickerScorecard,
                storeNumber: store,
                payload: ["pph": pph],
                textPayload: ["shopper_id": name, "shopper_name": name]
            )
        }
        let rows = [
            shopper("304", "Ann", pph: 60),
            shopper("304", "Ben", pph: 82),
            shopper("667", "Cara", pph: 70),
        ]
        let allowed: Set<String> = ["304"]
        let shoppers = PulseQuery.sliceShoppers(rows, allowed: allowed)
        XCTAssertEqual(shoppers.map { $0.textPayload["shopper_name"] ?? "" }.sorted(), ["Ann", "Ben"])
        let collapsed = PulseQuery.slice(rows, allowed: allowed)
        XCTAssertEqual(collapsed.count, 1)
        XCTAssertEqual(PulseQuery.sliceSection(.pickerScorecard, rows: rows, allowed: allowed).count, 2)
        XCTAssertEqual(PulseQuery.sliceSection(.lostRevenue, rows: rows, allowed: allowed).count, 1)

        let unnamed = [
            MetricRow(section: .pickerScorecard, division: "", operationsOM: "", storeNumber: "304", payload: [:], textPayload: [:]),
            MetricRow(section: .pickerScorecard, division: "", operationsOM: "", storeNumber: "304", payload: [:], textPayload: ["shopper_name": ""]),
        ]
        XCTAssertEqual(PulseQuery.sliceShoppers(unnamed, allowed: allowed).count, 2)

        var warehouse: [MetricSection: [MetricRow]] = [.pickerScorecard: rows]
        let light = PulseQuery.paint(
            warehouse: warehouse,
            roster: [:],
            filters: DashboardFilters(),
            grain: .region,
            uploads: [],
            hidePicker: true,
            light: true
        )
        XCTAssertNil(light.filtered[.pickerScorecard])
        let pageOpen = PulseQuery.paint(
            warehouse: warehouse,
            roster: [:],
            filters: DashboardFilters(),
            grain: .region,
            uploads: [],
            hidePicker: true,
            light: true,
            includePageOnly: true
        )
        XCTAssertEqual(pageOpen.filtered[.pickerScorecard]?.count, 3)
        warehouse[.pickerScorecard] = [rows[0]]
        let splash = PulseQuery.paint(
            warehouse: warehouse,
            roster: [:],
            filters: DashboardFilters(),
            grain: .region,
            uploads: [],
            hidePicker: true,
            light: true
        )
        XCTAssertNil(splash.filtered[.pickerScorecard])
    }

    func testWarehouseKeepsFullPackAndFillsThinPack() {
        func lost(_ store: String, dollars: Double) -> MetricRow {
            MetricRow(
                section: .lostRevenue,
                storeNumber: store,
                payload: ["lost_revenue": dollars],
                textPayload: ["lost_grain": "store"]
            )
        }
        let thin = (1...40).map { lost(String($0), dollars: 10) }
        let full = (1...220).map { lost(String($0), dollars: 20) }
        let newer = (1...220).map { lost(String($0), dollars: 40) }
        XCTAssertNotNil(PulseQuery.fillIfThin(existing: thin, incoming: full))
        XCTAssertNil(PulseQuery.fillIfThin(existing: full, incoming: thin))
        XCTAssertNil(PulseQuery.fillIfThin(existing: full, incoming: newer))
        XCTAssertNotNil(PulseQuery.takeIfRicher(existing: thin, incoming: full))
        XCTAssertNotNil(PulseQuery.takeIfRicher(existing: full, incoming: newer))
        XCTAssertNil(PulseQuery.takeIfRicher(existing: newer, incoming: full))
        XCTAssertNil(PulseQuery.takeIfRicher(existing: full, incoming: thin))
    }

    func testLaunchLeavesSplashOnPackOrPaintedFacts() {
        XCTAssertTrue(PulseLaunch.leaveSplash(localPackBytes: 80_000, loadedRows: 12))
        XCTAssertFalse(PulseLaunch.leaveSplash(localPackBytes: 80_000, loadedRows: 0))
        XCTAssertFalse(PulseLaunch.leaveSplash(localPackBytes: 1_200, loadedRows: 40))
        XCTAssertTrue(PulseLaunch.leaveSplash(localPackBytes: 0, loadedRows: 0, paintedStoreCards: 3))
        XCTAssertFalse(PulseLaunch.leaveSplash(localPackBytes: 0, loadedRows: 0, paintedStoreCards: 0))
    }

    func testLaunchDoesNotRefetchTheSameLocalPack() {
        XCTAssertFalse(
            PulseLaunch.shouldFetchRemotePack(remoteBytes: 2_000_000, localBytes: 2_000_000, localRowsLoaded: 400)
        )
        XCTAssertTrue(
            PulseLaunch.shouldFetchRemotePack(remoteBytes: 2_100_000, localBytes: 2_000_000, localRowsLoaded: 400)
        )
        XCTAssertTrue(
            PulseLaunch.shouldFetchRemotePack(remoteBytes: 2_000_000, localBytes: 0, localRowsLoaded: 0)
        )
        XCTAssertTrue(
            PulseLaunch.shouldFetchRemotePack(remoteBytes: 2_000_000, localBytes: 2_000_000, localRowsLoaded: 0)
        )
        XCTAssertFalse(
            PulseLaunch.shouldFetchRemotePack(remoteBytes: 12_000, localBytes: 0, localRowsLoaded: 0)
        )
    }

    func testConstrainedRefreshDoesNotReloadPackInSession() {
        XCTAssertFalse(PulseLaunch.reloadInSessionAfterFetch(constrained: true, localRowsLoaded: 400))
        XCTAssertTrue(PulseLaunch.reloadInSessionAfterFetch(constrained: true, localRowsLoaded: 0))
        XCTAssertTrue(PulseLaunch.reloadInSessionAfterFetch(constrained: false, localRowsLoaded: 400))
    }

    func testDashboardGrainTableKeepsFullMoneyAndColumnCounts() {
        for section in MetricSection.dashboardCards where section != .sales {
            let headers = HeartbeatMath.dashboardTableHeaders(section)
            XCTAssertFalse(headers.isEmpty, "\(section) needs Sales-style columns")
        }
        let rows = [
            MetricRow(
                section: .lostRevenue,
                division: "Jewel Osco",
                operationsOM: "A",
                storeNumber: "304",
                payload: [
                    "lost_revenue": 1_234_567.89,
                    "ecomm_sales": 10_000_000,
                    "post_sub_oos_foregone": 100,
                    "refund_lost": 50,
                    "missed_sales": 25,
                    "cancelled_lost": 10,
                    "kill_switch_lost": 5,
                ],
                textPayload: ["lost_grain": "store"]
            )
        ]
        let table = HeartbeatMath.dashboardGrainTable(
            section: .lostRevenue,
            rows: rows,
            grain: .store,
            order: []
        )
        XCTAssertEqual(table.count, 1)
        XCTAssertEqual(table[0].values.count, HeartbeatMath.dashboardTableHeaders(.lostRevenue).count)
        XCTAssertTrue(table[0].values[0].contains("1,234,567.89"), table[0].values[0])
        XCTAssertFalse(table[0].values[0].contains("M"))
        XCTAssertGreaterThan(HubLayout.readableTableFloor(phone: true, columns: 8, showCount: true), 700)
        XCTAssertGreaterThan(
            HubLayout.readableTableFloor(phone: false, columns: 8, showCount: true),
            HubLayout.readableTableFloor(phone: true, columns: 8, showCount: true)
        )
        XCTAssertEqual(HubLayout.tableSpan(available: 1400, floor: 900), 1400)
        XCTAssertEqual(HubLayout.tableSpan(available: 700, floor: 900), 900)
        XCTAssertGreaterThan(
            HubLayout.evenValueWidth(available: 1400, phone: false, columns: 8, showCount: true),
            HubLayout.readableValueMin(phone: false)
        )
        XCTAssertEqual(
            HubLayout.evenValueWidth(available: 400, phone: true, columns: 8, showCount: true),
            HubLayout.readableValueMin(phone: true)
        )
    }

    func testLostSalesDollarBucketsAreNeverHealthyWhenDollarsRemain() {
        XCTAssertEqual(HeartbeatMath.lostSalesDollarHealth(dollars: 0, pct: 0, anyDollarIsRisk: false), .good)
        XCTAssertEqual(HeartbeatMath.lostSalesDollarHealth(dollars: 25, pct: 1.0, anyDollarIsRisk: false), .watch)
        XCTAssertEqual(HeartbeatMath.lostSalesDollarHealth(dollars: 25, pct: 6.0, anyDollarIsRisk: false), .risk)
        XCTAssertEqual(HeartbeatMath.lostSalesDollarHealth(dollars: 10, pct: 0.2, anyDollarIsRisk: true), .risk)
        let rows = [
            MetricRow(
                section: .lostRevenue,
                division: "Jewel Osco",
                operationsOM: "A",
                storeNumber: "1",
                payload: [
                    "ecomm_sales": 100_000,
                    "refund_lost": 40,
                    "refund_lost_pct": 0.04,
                    "cancelled_lost": 80,
                    "cancelled_lost_pct": 0.08,
                    "kill_switch_lost": 90,
                    "kill_switch_pct": 0.09,
                    "lost_revenue": 200,
                    "lost_revenue_pct": 0.2,
                ],
                textPayload: ["lost_grain": "store"]
            )
        ]
        let flags = HeartbeatMath.lostRevenueMetricFlags(rows, includeAll: true)
        let refund = flags.first { $0.name.contains("Refund") }
        let cancel = flags.first { $0.name.contains("Cancelled") }
        let kill = flags.first { $0.name.contains("Kill") }
        XCTAssertEqual(refund?.health, .watch)
        XCTAssertEqual(cancel?.health, .watch)
        XCTAssertEqual(kill?.health, .risk)
    }

    func testPageOnlyPaintKeepsLivePickerSummary() {
        let empty = SectionSummary(
            section: .pickerScorecard,
            storeCount: 0,
            headline: 0,
            headlineLabel: "Shoppers",
            secondary: "No shoppers in view",
            health: .none,
            watchCount: 0,
            riskCount: 0
        )
        let live = SectionSummary(
            section: .pickerScorecard,
            storeCount: 12,
            headline: 80,
            headlineLabel: "Shoppers",
            secondary: "4 opportunity · 3 doing well",
            health: .watch,
            watchCount: 2,
            riskCount: 4
        )
        let sales = SectionSummary(
            section: .sales,
            storeCount: 10,
            headline: 1,
            headlineLabel: "Sales",
            secondary: "",
            health: .good,
            watchCount: 0,
            riskCount: 0
        )
        let merged = PulseQuery.overlayPageOnlySummaries(painted: [sales, empty], live: [live])
        XCTAssertEqual(merged.first { $0.section == .pickerScorecard }?.storeCount, 12)
        XCTAssertEqual(merged.first { $0.section == .sales }?.storeCount, 10)
        let kept = PulseQuery.keepPageOnlyRows(
            painted: [.sales: []],
            live: [.pickerScorecard: [MetricRow(section: .pickerScorecard, division: "10", operationsOM: "A", storeNumber: "12", payload: ["pph": 40], textPayload: ["shopper_id": "A", "shopper_name": "A"])]]
        )
        XCTAssertEqual(kept[.pickerScorecard]?.count, 1)
        XCTAssertTrue(PulseLaunch.needsShopperJoin(.pph))
        XCTAssertTrue(PulseLaunch.needsShopperJoin(.pickerScorecard))
        XCTAssertFalse(PulseLaunch.needsShopperJoin(.sales))
        XCTAssertTrue(PulseLaunch.shouldStampPicker(replace: true, dest: .dashboard, count: 80, lastStampCount: 0))
        XCTAssertFalse(PulseLaunch.shouldStampPicker(replace: false, dest: .dashboard, count: 200, lastStampCount: 80))
        XCTAssertTrue(PulseLaunch.shouldStampPicker(replace: false, dest: .pph, count: 500, lastStampCount: 80))
        XCTAssertEqual(HubLayout.calloutColumns(count: 7, width: 1100), 4)
        XCTAssertEqual(HubLayout.calloutColumns(count: 5, width: 1100), 3)
    }

    func testPostReadyWorkStaysOffSplashAndCoolsTheHub() {
        XCTAssertGreaterThan(PulseLaunch.grainPaintDelayNanoseconds, 0)
        XCTAssertGreaterThan(PulseLaunch.cloudHydrateDelayNanoseconds, PulseLaunch.grainPaintDelayNanoseconds)
        XCTAssertTrue(PulseLaunch.streamPickerAfterReady)
        XCTAssertFalse(PulseLaunch.loadPageOnlyOnReady)
        XCTAssertGreaterThan(PulseLaunch.pickerFirstPaintCount, 0)
        XCTAssertTrue(PulseLaunch.shouldPaintGrains(dashboardVisible: true, ready: true, rolePicked: true))
        XCTAssertFalse(PulseLaunch.shouldPaintGrains(dashboardVisible: false, ready: true, rolePicked: true))
        XCTAssertTrue(PulseLaunch.acceptPaint(generation: 3, current: 3, cancelled: false))
        XCTAssertFalse(PulseLaunch.acceptPaint(generation: 3, current: 4, cancelled: false))
        XCTAssertFalse(PulseLaunch.acceptPaint(generation: 3, current: 3, cancelled: true))
        XCTAssertFalse(PulseLaunch.shouldPullCloudOnForeground(secondsSinceReady: 12))
        XCTAssertTrue(PulseLaunch.shouldPullCloudOnForeground(secondsSinceReady: 90))
        XCTAssertFalse(PulseLaunch.shouldLoadPublishedFacts(lostStores: 400, salesStores: 400))
        XCTAssertTrue(PulseLaunch.shouldLoadPublishedFacts(lostStores: 40, salesStores: 40))
        XCTAssertFalse(PulseLaunch.shouldLoadPublishedFacts(lostStores: 40, salesStores: 400))
    }

    func testMissingPackMessageIsActionable() {
        let message = PulseLaunch.missingPackMessage()
        XCTAssertTrue(message.contains("Try again"))
        XCTAssertFalse(message.isEmpty)
    }

    func testUsablePackFileRejectsTinyStubs() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("hb-stub-\(UUID().uuidString).sqlite")
        FileManager.default.createFile(atPath: url.path, contents: Data(repeating: 1, count: 1_200), attributes: nil)
        XCTAssertFalse(PulseSQLite.isUsableFile(at: url))
        XCTAssertFalse(PulseSQLite.exists(at: url))
        try? FileManager.default.removeItem(at: url)
        XCTAssertFalse(PulseSQLite.exists(at: url))
    }
}

