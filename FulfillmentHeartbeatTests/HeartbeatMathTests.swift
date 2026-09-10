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

    func testDynacapDashboardFlagsJoinStorePPH() {
        let dyn = MetricRow(
            section: .dynacap,
            division: "Jewel Osco",
            operationsOM: "A",
            storeNumber: "308",
            payload: ["dynacap_rate": 67.0, "utilization_pct": 21.36]
        )
        let pph = MetricRow(
            section: .pph,
            division: "Jewel Osco",
            operationsOM: "A",
            storeNumber: "308",
            payload: ["pph": 74.3]
        )
        let blank = HeartbeatMath.dynacapActionFlags([dyn])
        XCTAssertEqual(blank.first { $0.name == "Store PPH" }?.value, "—")
        let joined = HeartbeatMath.overlayStorePPH([dyn], from: [pph])
        XCTAssertEqual(joined.first?.number("pph"), 74.3)
        let flags = HeartbeatMath.dashboardActionFlags(
            section: .dynacap,
            rows: [dyn],
            pphRows: [pph]
        )
        XCTAssertEqual(flags.first { $0.name == "Pieces / Hr" }?.value, "67.0")
        XCTAssertEqual(flags.first { $0.name == "Store PPH" }?.value, "74.3")
        XCTAssertNotEqual(flags.first { $0.name == "Store PPH" }?.value, "—")
        XCTAssertEqual(flags.first { $0.name == "Utilization" }?.value, "21.36%")
        let grain = HeartbeatMath.dashboardGrainTable(
            section: .dynacap,
            rows: joined,
            grain: .region,
            order: ["East Region"]
        )
        XCTAssertEqual(grain.first?.values[1], "74.3")
    }

    func testPreSubTopItemCalloutStaysCompact() {
        let item = MetricRow(
            section: .preSubOOSItem,
            division: "Jewel Osco",
            operationsOM: "A",
            storeNumber: "308",
            payload: ["presub_pct": 12.4],
            textPayload: ["bpn": "970014483 - Plums Prune - Each - 100"]
        )
        let flags = HeartbeatMath.preSubActionFlags([], items: [item])
        let top = flags.first { $0.name == "#1 Pre-Sub Item" }
        XCTAssertNotNil(top)
        XCTAssertEqual(top?.value, "12.40%")
        XCTAssertFalse(top?.value.contains("970014483") == true, top?.value ?? "")
        XCTAssertTrue(top?.unit.contains("Plums") == true, top?.unit ?? "")
        XCTAssertLessThanOrEqual(top?.value.count ?? 99, 12)
        XCTAssertEqual(
            HeartbeatMath.compactCalloutLabel("970014483 - Plums Prune - Each - 100"),
            "Plums Prune - Each -…"
        )
        let fourWide = HubLayout.calloutColumns(count: 4, width: 1_000)
        XCTAssertEqual(fourWide, 4)
        let fourTight = HubLayout.calloutColumns(count: 4, width: 600)
        XCTAssertLessThanOrEqual(fourTight, 2)
        let tile = HubLayout.calloutTileMinWidth(columns: 4, width: 900, phone: false)
        XCTAssertLessThanOrEqual(tile * 4 + HubLayout.calloutGridSpacing * 3, 900)
        XCTAssertEqual(HubLayout.calloutTileHeight(phone: false), HubLayout.calloutMinHeight(phone: false))
        XCTAssertEqual(
            HubLayout.grid(4, spacing: 8, minWidth: 152).count,
            4
        )
    }

    func testPPHDashboardHasTotalCalloutAndDynacapFallsBackToBookPPH() {
        let stores = [
            MetricRow(section: .pph, division: "Jewel Osco", operationsOM: "A", storeNumber: "1", payload: ["pph": 81]),
            MetricRow(section: .pph, division: "Jewel Osco", operationsOM: "A", storeNumber: "2", payload: ["pph": 70]),
        ]
        let flags = HeartbeatMath.dashboardActionFlags(section: .pph, rows: stores)
        XCTAssertEqual(flags.first?.name, "PPH")
        XCTAssertEqual(flags.first?.value, "75.5")
        XCTAssertTrue(flags.contains { $0.name == "Healthy" })
        XCTAssertTrue(flags.contains { $0.name == "At Risk" })
        let dyn = MetricRow(
            section: .dynacap,
            division: "NorCal",
            operationsOM: "A",
            storeNumber: "9999",
            payload: ["dynacap_rate": 67.0, "utilization_pct": 21.36]
        )
        let missed = HeartbeatMath.dynacapActionFlags([dyn], bookPPH: stores)
        XCTAssertEqual(missed.first { $0.name == "Store PPH" }?.value, "75.5")
        XCTAssertNotEqual(missed.first { $0.name == "Store PPH" }?.value, "—")

        let pureOnly = [
            MetricRow(section: .pph, division: "Jewel Osco", operationsOM: "A", storeNumber: "1", payload: ["pure_pph": 82]),
            MetricRow(section: .pph, division: "Jewel Osco", operationsOM: "A", storeNumber: "2", payload: ["pure_pph": 70]),
        ]
        XCTAssertEqual(HeartbeatMath.weekPurePPH(pureOnly), 76)
        let summary = HeartbeatMath.summarize(.pph, rows: pureOnly, upload: nil)
        XCTAssertEqual(summary.headline, 76)
        XCTAssertEqual(summary.headlineText, "76.0")
        XCTAssertNotEqual(summary.headlineText, "—")

        let older = MetricRow(section: .pph, division: "Jewel Osco", operationsOM: "A", storeNumber: "1", recordedOn: "2026-09-06", payload: ["pph": 50])
        let weekTotal = MetricRow(section: .pph, division: "Jewel Osco", operationsOM: "A", storeNumber: "1", recordedOn: "2026-09-08", payload: ["pph": 88.4])
        XCTAssertEqual(HeartbeatMath.weekPurePPH([older, weekTotal]), 88.4)

        let pickers = [
            MetricRow(section: .pickerScorecard, division: "Jewel Osco", operationsOM: "A", storeNumber: "10", payload: ["pph": 90], textPayload: ["shopper_id": "A"]),
            MetricRow(section: .pickerScorecard, division: "Jewel Osco", operationsOM: "A", storeNumber: "11", payload: ["pph": 70], textPayload: ["shopper_id": "B"]),
        ]
        XCTAssertEqual(HeartbeatMath.weekPurePPH([], pickers: pickers), 80)
        let pickerFlags = HeartbeatMath.pphDashboardFlags([], pickers: pickers)
        XCTAssertEqual(pickerFlags.first?.name, "PPH")
        XCTAssertEqual(pickerFlags.first?.value, "80.0")
        XCTAssertNotEqual(pickerFlags.first?.value, "—")

        let east = [
            MetricRow(section: .pph, division: "Jewel Osco", operationsOM: "A", storeNumber: "1", payload: ["pph": 64]),
            MetricRow(section: .pph, division: "Jewel Osco", operationsOM: "A", storeNumber: "2", payload: ["pph": 72]),
        ]
        let west = [
            MetricRow(section: .pph, division: "Haggen", operationsOM: "B", storeNumber: "3427", payload: ["pph": 90]),
        ]
        XCTAssertEqual(HeartbeatMath.weekPurePPH(east + west)!, (64 + 72 + 90) / 3.0, accuracy: 0.01)
        XCTAssertEqual(HeartbeatMath.weekPurePPH(east), 68)
        XCTAssertEqual(HeartbeatMath.pphDashboardFlags(east).first?.value, "68.0")
        XCTAssertEqual(HeartbeatMath.pphDashboardFlags(west).first?.value, "90.0")

        let material = HeartbeatMath.materializePPH(
            [],
            roster: ["10": HeartbeatMath.StoreIdentity(division: "Jewel Osco", district: "J1", om: "A", name: nil)],
            pickers: pickers
        )
        XCTAssertEqual(Set(material.map(\.storeNumber)), Set(["10", "11"]))
        XCTAssertEqual(HeartbeatMath.weekPurePPH(material), 80)

        let card = PulseCaches.cardFlags(latest: [.pph: stores])
        XCTAssertEqual(card[.pph]?.first?.name, "PPH")
        XCTAssertEqual(card[.pph]?.first?.value, "75.5")
        let light = PulseQuery.paint(
            warehouse: [.pph: stores],
            roster: [:],
            filters: DashboardFilters(),
            grain: .region,
            uploads: [],
            hidePicker: true,
            light: true
        )
        XCTAssertTrue(light.flags.isEmpty)
        XCTAssertEqual(light.summaries.first { $0.section == .pph }?.headlineText, "75.5")
        XCTAssertEqual(light.summaries.first { $0.section == .pph }?.headlineLabel, "Week Pure PPH")
        let jewelOnly = PulseQuery.paint(
            warehouse: [.pph: east + west],
            roster: [
                "1": HeartbeatMath.StoreIdentity(division: "Jewel Osco", district: "J1", om: "A", name: nil),
                "2": HeartbeatMath.StoreIdentity(division: "Jewel Osco", district: "J1", om: "A", name: nil),
                "3427": HeartbeatMath.StoreIdentity(division: "Haggen", district: "39", om: "B", name: nil),
            ],
            filters: DashboardFilters(division: "Jewel Osco"),
            grain: .division,
            uploads: [],
            hidePicker: true,
            light: false
        )
        XCTAssertEqual(jewelOnly.summaries.first { $0.section == .pph }?.headlineText, "68.0")
        XCTAssertEqual(jewelOnly.flags[.pph]?.first?.value, "68.0")
        XCTAssertEqual(jewelOnly.flags[.pph]?.first?.name, "PPH")
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
    func testClearFiltersResetsChromeAndCompanyGrain() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = HeartbeatStore(rootURL: root)
        store.applyLaunchRole(.districtManager, district: "03")
        XCTAssertEqual(store.filters.district, "03")
        XCTAssertEqual(store.filters.chipTitle(for: .district), "03")
        XCTAssertEqual(store.effectiveDashboardGrain, .store)
        store.clearFilters()
        XCTAssertFalse(store.filters.isActive)
        for focus in FilterFocus.allCases {
            XCTAssertTrue(store.filters.values(for: focus).isEmpty, focus.rawValue)
            XCTAssertEqual(store.filters.chipTitle(for: focus), focus.chipTitle, focus.rawValue)
        }
        XCTAssertEqual(store.effectiveDashboardGrain, .region)
        store.applyLaunchRole(.om, om: "Pat Lee")
        XCTAssertEqual(store.effectiveDashboardGrain, .store)
        store.clearFilters()
        XCTAssertEqual(store.effectiveDashboardGrain, .region)
        XCTAssertEqual(store.filters.chipTitle(for: .om), "OM")
        XCTAssertFalse(store.filters.isActive)
        XCTAssertEqual(PulseLaunch.unfilteredDashboardGrain(), .region)
        XCTAssertTrue(PulseLaunch.shouldUseCompanyGrainWhenFiltersClear())
    }

    @MainActor
    func testApplyLaunchRoleKeepsWhoIsLookingUntilSeatPaint() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = HeartbeatStore(rootURL: root)
        XCTAssertTrue(store.needsRolePick)
        store.applyLaunchRole(.districtManager, district: "03")
        XCTAssertEqual(store.filters.district, "03")
        var revealed = !store.needsRolePick
        if !revealed {
            for _ in 0..<80 {
                try? await Task.sleep(nanoseconds: 25_000_000)
                if !store.needsRolePick {
                    revealed = true
                    break
                }
            }
        }
        XCTAssertTrue(revealed, "Who's looking should dismiss after the seat paint lands")
        XCTAssertEqual(store.filters.district, "03")
        XCTAssertEqual(store.effectiveDashboardGrain, .store)
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

    func testLostRevenueHeadlineAndExpandFollowFilterScope() {
        func store(_ number: String, division: String, lost: Double) -> MetricRow {
            MetricRow(
                section: .lostRevenue,
                division: division,
                operationsOM: "",
                storeNumber: number,
                payload: ["ecomm_sales": lost * 20, "lost_revenue": lost, "lost_revenue_pct": 5],
                textPayload: ["lost_grain": "store"]
            )
        }
        let east = store("1", division: "Jewel Osco", lost: 760_872.84)
        let south = store("2", division: "Southern", lost: 277_531.39)
        let california = store("3", division: "NorCal", lost: 521_791.45)
        let west = store("4", division: "Portland", lost: 455_728.04)
        let stores = [east, south, california, west]
        let raw = stores.compactMap { $0.number("lost_revenue") }.reduce(0, +)
        XCTAssertEqual(raw, 2_015_923.72, accuracy: 0.05)
        let market = MetricRow(
            section: .lostRevenue,
            division: "",
            operationsOM: "",
            storeNumber: "",
            storeName: "Total",
            payload: ["ecomm_sales": 49_026_551, "lost_revenue": 1_962_441.23, "lost_revenue_pct": 4.0],
            textPayload: ["lost_grain": "market"]
        )

        let company = HeartbeatMath.summarize(.lostRevenue, rows: stores + [market], upload: nil)
        XCTAssertEqual(company.headline ?? 0, 1_962_441.23, accuracy: 0.01)
        XCTAssertEqual(HeartbeatMath.totalOpportunityDollars(market), 1_962_441.23, accuracy: 0.01)

        let table = HeartbeatMath.dashboardGrainTable(
            section: .lostRevenue,
            rows: stores + [market],
            grain: .region,
            order: [],
            goalFallback: nil
        )
        XCTAssertEqual(table.map(\.label), MarketRegion.allCases.map(\.rawValue))
        let expandLost = table.compactMap { row -> Double? in
            guard let raw = row.values.first else { return nil }
            let digits = raw.filter { $0.isNumber || $0 == "." }
            return Double(digits)
        }.reduce(0, +)
        // Expand is the Excel column on those stores — not a scaled invented total.
        XCTAssertEqual(expandLost, 2_015_923.72, accuracy: 1)

        let district = HeartbeatMath.summarize(.lostRevenue, rows: [east], upload: nil)
        XCTAssertEqual(district.headline ?? 0, 760_872.84, accuracy: 0.01)
        XCTAssertNotEqual(district.headline ?? 0, 1_962_441.23, accuracy: 1)
        let districtTable = HeartbeatMath.dashboardGrainTable(
            section: .lostRevenue,
            rows: [east],
            grain: .region,
            order: [],
            goalFallback: nil
        )
        XCTAssertEqual(districtTable.first { $0.label == MarketRegion.east.rawValue }?.storeCount, 1)

        var warehouse: [MetricSection: [MetricRow]] = [.lostRevenue: stores + [market]]
        var painted: [MetricSection: [MetricRow]] = [.lostRevenue: stores]
        PulseQuery.restoreCompanyTotals(filtered: &painted, warehouse: warehouse)
        XCTAssertTrue((painted[.lostRevenue] ?? []).contains { $0.textPayload["lost_grain"] == "market" })
        XCTAssertFalse(PulseLaunch.shouldStampHubWhenExpandCacheFills())
        XCTAssertFalse(PulseLaunch.shouldMountHubUnderRoleGate())
        XCTAssertFalse(PulseLaunch.shouldUsePagingScroll())
        XCTAssertFalse(PulseLaunch.shouldRemountPageOnDestinationChange())
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
        XCTAssertEqual(summary?.storeCount, 2, "seat card storeCount is Heartbeat N, not fact coverage")
        XCTAssertEqual((caches.filteredLatest[.lostRevenue] ?? []).count, 2)
    }

    func testDistrictD3MatchesRoster03() {
        XCTAssertFalse(HeartbeatMath.districtMatchKeys("03").contains("d3"))
        XCTAssertFalse(HeartbeatMath.districtMatchKeys("D3").contains("3"))
        XCTAssertTrue(HeartbeatMath.districtMatchKeys("03").contains("03"))
        XCTAssertTrue(HeartbeatMath.districtMatchKeys("03").contains("3"))
        XCTAssertFalse(HeartbeatMath.districtMatchKeys("B3").contains("3"))
        XCTAssertFalse(HeartbeatMath.districtMatchKeys("J3").contains("3"))
        XCTAssertEqual(HeartbeatMath.canonicalDistrict("J3CHICAGO"), "J3")
        XCTAssertEqual(HeartbeatMath.canonicalDistrict("J1NORTHSHORE"), "J1")
        XCTAssertEqual(HeartbeatMath.canonicalDistrict("03"), "03")
        XCTAssertEqual(HeartbeatMath.canonicalDistrict("J3"), "J3")
        XCTAssertEqual(HeartbeatMath.shortDistrictName("J3CHICAGO"), "J3")
        XCTAssertEqual(HeartbeatMath.shortDistrictName("308 - J3 CHICAGO"), "J3")
        XCTAssertEqual(HeartbeatMath.canonicalDistrict("308 - J3 CHICAGO"), "J3")
        XCTAssertEqual(HeartbeatMath.shortDistrictName("J3 CHICAGO"), "J3")
        XCTAssertEqual(HeartbeatMath.displayGrainLabel("308 - J3 CHICAGO"), "J3")
        XCTAssertEqual(HeartbeatMath.displayGrainLabel("J3CHICAGO"), "J3")
        XCTAssertEqual(HeartbeatMath.displayGrainLabel("308 | Jewel Osco"), "308 | Jewel Osco")
        XCTAssertNil(HeartbeatMath.usableStoreName("J3 CHICAGO"))
        XCTAssertEqual(HeartbeatMath.usableStoreName("Joliet Larkin"), "Joliet Larkin")
        XCTAssertTrue(HeartbeatMath.districtMatchKeys("J3CHICAGO").contains("j3"))
        XCTAssertTrue(HeartbeatMath.districtMatchKeys("J3").contains("j3"))
        XCTAssertEqual(RollupMarketFill.districtKey("J3CHICAGO"), "J3")
        XCTAssertEqual(
            HeartbeatMath.dashboardGrainTable(
                section: .scheduleQuality,
                rows: [
                    MetricRow(
                        section: .scheduleQuality,
                        division: "Jewel Osco",
                        operationsOM: "",
                        storeNumber: "100",
                        textPayload: ["district": "J3CHICAGO"]
                    )
                ],
                grain: .district,
                order: []
            ).first?.label,
            "J3"
        )
        XCTAssertEqual(HubLayout.scopeLabelWidth(district: true, phone: false), 88)
        XCTAssertLessThan(
            HubLayout.readableTableFloor(
                phone: false,
                columns: 9,
                showCount: true,
                district: true,
                valueMin: HubLayout.dashboardValueMin(phone: false, columns: 9)
            ),
            HubLayout.readableTableFloor(phone: false, columns: 9, showCount: true)
        )
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
        var short = DashboardFilters()
        short.district = "J3"
        XCTAssertTrue(short.includesDistrict("J3CHICAGO"))
        XCTAssertTrue(short.includesDistrict("J3"))
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

    func testSalesRegionExpandHasFourRegionRows() {
        let stores = MarketRegion.allCases.enumerated().map { index, region in
            MetricRow(
                section: .sales,
                division: region.gateDivisions[0],
                storeNumber: "\(index + 1)",
                payload: ["sales_dollars": Double((index + 1) * 1_000_000), "sales_orders": 10],
                textPayload: ["sales_grain": "store"]
            )
        }
        let rows = SalesRollupBuilder.dashboardRows(from: stores, grain: .region)
        XCTAssertEqual(rows.map(\.label), MarketRegion.allCases.map(\.rawValue))
        XCTAssertTrue(rows.allSatisfy { ($0.pack.sales ?? 0) > 0 })
        XCTAssertTrue(PulseLaunch.shouldPrefetchSalesExpandWithGrainTables())
        XCTAssertFalse(PulseLaunch.shouldStampHubWhenExpandCacheFills())
        XCTAssertTrue(PulseLaunch.salesExpandIsLive(rows))
        XCTAssertTrue(PulseLaunch.dashboardExpandIsLive(section: .sales, salesRows: rows, grainRows: []))
        XCTAssertEqual(PulseLaunch.dashboardBannerCount(section: .sales, salesRows: rows, grainRows: []), 4)
        XCTAssertFalse(PulseLaunch.shouldMountHubUnderRoleGate())
        XCTAssertFalse(PulseLaunch.shouldUsePagingScroll())
        XCTAssertFalse(PulseLaunch.shouldRemountPageOnDestinationChange())
    }

    func testSalesExpandDoesNotShowPlaceholderRegionsFour() {
        XCTAssertFalse(PulseLaunch.salesExpandIsLive([]))
        XCTAssertFalse(PulseLaunch.dashboardExpandIsLive(section: .sales, salesRows: [], grainRows: []))
        XCTAssertEqual(PulseLaunch.dashboardBannerCount(section: .sales, salesRows: [], grainRows: []), 0)

        let placeholders = PulseCaches.placeholderGrainPacks(grain: .region)[.sales] ?? []
        XCTAssertEqual(placeholders.count, 4)
        XCTAssertTrue(placeholders.allSatisfy { $0.line.value == "—" && $0.line.count == 0 })
        let fromPacks = HeartbeatMath.dashboardGrainRowsFromPacks(
            placeholders,
            section: .sales,
            goalFallback: nil
        )
        XCTAssertFalse(HeartbeatMath.grainRowsAreLive(fromPacks))
        XCTAssertEqual(
            PulseLaunch.dashboardBannerCount(section: .sales, salesRows: [], grainRows: fromPacks),
            0,
            "placeholder packs must not paint Regions 4 over an empty table"
        )
        XCTAssertFalse(PulseLaunch.dashboardExpandIsLive(section: .pph, salesRows: [], grainRows: fromPacks))
        XCTAssertEqual(PulseLaunch.dashboardBannerCount(section: .pph, salesRows: [], grainRows: fromPacks), 0)
        XCTAssertFalse(PulseLaunch.shouldStampHubWhenExpandCacheFills())
    }

    func testPickerExpandIsLiveWhenPackChromeHasShoppers() {
        let chrome = PulseDashChrome(
            summaries: [
                SectionSummary(
                    section: .pickerScorecard,
                    storeCount: 40,
                    headline: 1_200,
                    headlineLabel: "Shoppers",
                    secondary: "400 opportunity · 600 doing well",
                    health: .watch,
                    watchCount: 0,
                    riskCount: 400,
                    lastFilename: nil,
                    lastUploadedAt: nil
                )
            ],
            flags: [:],
            packs: [:],
            pickerShoppers: 1_200,
            pickerOpportunity: 400,
            pickerStrong: 600
        )
        XCTAssertTrue(chrome.pickerOK)
        let rows = PulseLaunch.pickerExpandRows(from: chrome)
        XCTAssertTrue(HeartbeatMath.grainRowsAreLive(rows), "pack picker data must prefill live grain")
        XCTAssertTrue(
            PulseLaunch.dashboardExpandIsLive(section: .pickerScorecard, salesRows: [], grainRows: rows),
            "Picker chevron must not stay light-blue inert when chrome has shoppers"
        )
        XCTAssertFalse(
            PulseLaunch.dashboardExpandIsLive(section: .pickerScorecard, salesRows: [], grainRows: []),
            "empty picker grain must not open a header shell"
        )
        XCTAssertFalse(PulseLaunch.salesExpandIsLive([]))
        XCTAssertFalse(
            PulseLaunch.dashboardExpandIsLive(section: .sales, salesRows: [], grainRows: rows),
            "Sales expand stays gated on live $"
        )
        let emptyPaint: [MetricSection: [HeartbeatMath.DashboardGrainTableRow]] = [
            .lostRevenue: [],
            .sales: [],
        ]
        let merged = PulseLaunch.mergeLiveGrainTables(
            incoming: emptyPaint,
            live: [.pickerScorecard: rows]
        )
        XCTAssertTrue(
            HeartbeatMath.grainRowsAreLive(merged[.pickerScorecard] ?? []),
            "dashboard paint must not drop a live picker expand table"
        )
        XCTAssertFalse(PulseLaunch.shouldStreamPickerOnDashboard())
        XCTAssertFalse(PulseLaunch.shouldStampHubWhenExpandCacheFills())
        XCTAssertFalse(PulseLaunch.shouldMountHubUnderRoleGate())
        XCTAssertFalse(PulseLaunch.shouldUsePagingScroll())
        XCTAssertFalse(PulseLaunch.shouldRemountPageOnDestinationChange())
    }

    func testPickerExpandPrefersChromeTableAndScopesToFilter() {
        let jewel = HeartbeatMath.DashboardGrainTableRow(
            label: "Jewel Osco",
            storeCount: 80,
            values: ["80", "50", "20", "10"],
            health: .watch
        )
        let south = HeartbeatMath.DashboardGrainTableRow(
            label: "Albertsons South",
            storeCount: 40,
            values: ["40", "20", "10", "10"],
            health: .watch
        )
        let chrome = PulseDashChrome(
            summaries: [],
            flags: [:],
            packs: [:],
            tables: [MetricSection.pickerScorecard.rawValue: [jewel, south]],
            pickerShoppers: 120
        )
        let all = PulseLaunch.pickerExpandRows(from: chrome)
        XCTAssertEqual(all.map(\.label), ["Jewel Osco", "Albertsons South"])
        XCTAssertTrue(PulseLaunch.dashboardExpandIsLive(section: .pickerScorecard, salesRows: [], grainRows: all))
        var jewelFilter = DashboardFilters()
        jewelFilter.division = "Jewel Osco"
        XCTAssertTrue(PulseLaunch.grainRowsScopedToFilter([jewel, south], filters: jewelFilter).isEmpty)
        XCTAssertTrue(PulseLaunch.pickerExpandRows(from: chrome, filters: jewelFilter).isEmpty)
        var districtFilter = DashboardFilters()
        districtFilter.district = "03"
        XCTAssertTrue(PulseLaunch.pickerExpandRows(from: chrome, filters: districtFilter).isEmpty)
        var storeFilter = DashboardFilters()
        storeFilter.store = "304"
        XCTAssertTrue(PulseLaunch.grainRowsScopedToFilter([jewel, south], filters: storeFilter).isEmpty)
        XCTAssertTrue(PulseLaunch.pickerExpandRows(from: chrome, filters: storeFilter).isEmpty)
    }

    func testSeatFilterKeepsStoreCountsAcrossEverySection() {
        let districtStores = (1...20).map { String($0) }
        let otherStores = ["9001", "9002"]
        var roster: [String: HeartbeatMath.StoreIdentity] = [:]
        for store in districtStores {
            roster[store] = HeartbeatMath.StoreIdentity(
                division: "NorCal", district: "03", om: "Jino Arvin", name: store
            )
        }
        for store in otherStores {
            roster[store] = HeartbeatMath.StoreIdentity(
                division: "Jewel Osco", district: "J1", om: "Shelly Selof", name: store
            )
        }
        func row(
            _ section: MetricSection,
            _ store: String,
            payload: [String: Double],
            extra: [String: String] = [:]
        ) -> MetricRow {
            let identity = roster[store]!
            var text = extra
            if text["district"] == nil { text["district"] = identity.district }
            return MetricRow(
                section: section,
                division: identity.division,
                operationsOM: identity.om,
                storeNumber: store,
                storeName: identity.name,
                payload: payload,
                textPayload: text
            )
        }
        let allStores = districtStores + otherStores
        var warehouse: [MetricSection: [MetricRow]] = [:]
        warehouse[.sales] = allStores.map {
            row(.sales, $0, payload: ["sales_dollars": 100, "sales_orders": 4], extra: ["sales_grain": "store"])
        }
        warehouse[.lostRevenue] = allStores.map {
            row(.lostRevenue, $0, payload: ["lost_revenue": 10, "lost_revenue_pct": 2], extra: ["lost_grain": "store"])
        }
        warehouse[.labor] = allStores.map {
            row(.labor, $0, payload: ["target_vs_actual_pct": -1], extra: ["labor_grain": "store"])
        }
        warehouse[.pickPath] = (Array(districtStores.dropLast(1)) + otherStores).map {
            row(.pickPath, $0, payload: ["compliance_pct": 92])
        }
        warehouse[.scheduleQuality] = (Array(districtStores.dropLast(2)) + otherStores).map {
            row(.scheduleQuality, $0, payload: ["schedule_efficiency_pct": 91])
        }
        warehouse[.missingItems] = allStores.map {
            row(.missingItems, $0, payload: [MissingItemDept.totalKey: 4])
        }
        warehouse[.fiveStar] = allStores.map {
            row(.fiveStar, $0, payload: ["star_rating": 4.8])
        }
        warehouse[.preSubOOS] = allStores.map {
            row(.preSubOOS, $0, payload: [MissingItemDept.totalKey: 3])
        }
        warehouse[.prepNotReady] = allStores.map {
            row(.prepNotReady, $0, payload: ["pnr_rate_pct": 1.5])
        }
        warehouse[.dynacap] = allStores.map {
            row(.dynacap, $0, payload: ["dynacap_rate": 70])
        }
        warehouse[.pph] = allStores.map {
            row(.pph, $0, payload: ["pph": 82])
        }
        warehouse[.pickerScorecard] = allStores.map {
            row(
                .pickerScorecard,
                $0,
                payload: ["pph": 80, "orders": 10],
                extra: ["shopper_id": "\($0)-A", "shopper_name": "\($0)-A"]
            )
        }
        let regionChrome = MarketRegion.allCases.map {
            HeartbeatMath.DashboardGrainTableRow(
                label: $0.rawValue,
                storeCount: 400,
                values: ["400", "200", "100", "100"],
                health: .watch
            )
        }
        var district = DashboardFilters()
        district.district = "03"
        let view = PulseLaunch.seatSlice(warehouse: warehouse, roster: roster, filters: district)
        let counts = PulseLaunch.summaryStoreCounts(view.summaries)
        let expected = Set(districtStores)
        XCTAssertEqual(PulseCaches.allowedStores(roster: roster, filters: district), expected)
        for section in MetricSection.dashboardCards {
            XCTAssertEqual(counts[section], 20, "\(section.rawValue) card must keep all 20 District 03 stores")
            XCTAssertEqual(
                PulseLaunch.uniqueStores(in: view.filtered[section] ?? []),
                expected,
                "\(section.rawValue) slice dropped a District 03 store"
            )
            let table = view.tables[section] ?? []
            XCTAssertTrue(HeartbeatMath.grainRowsAreLive(table), "\(section.rawValue) expand must be live")
            XCTAssertEqual(table.count, 20, "\(section.rawValue) grain must list 20 stores, not company regions")
            XCTAssertFalse(
                table.contains { MarketRegion.allCases.map(\.rawValue).contains($0.label) },
                "\(section.rawValue) must not keep East/South/CA/West chrome"
            )
            if section == .sales {
                let salesRows = SalesRollupBuilder.dashboardRows(
                    from: view.filtered[.sales] ?? [],
                    grain: .store
                )
                XCTAssertTrue(PulseLaunch.salesExpandIsLive(salesRows))
                XCTAssertEqual(salesRows.count, 20)
            } else {
                XCTAssertTrue(
                    PulseLaunch.dashboardExpandIsLive(
                        section: section,
                        salesRows: [],
                        grainRows: table,
                        pickerFacts: section == .pickerScorecard ? 20 : 0
                    ),
                    "\(section.rawValue) chevron must open on the seat grain"
                )
            }
        }
        XCTAssertTrue(PulseLaunch.grainRowsScopedToFilter(regionChrome, filters: district).isEmpty)
        let chrome = PulseDashChrome(
            summaries: [
                SectionSummary(
                    section: .pickerScorecard,
                    storeCount: 26_349,
                    headline: 26_349,
                    headlineLabel: "Shoppers",
                    secondary: "",
                    health: .watch,
                    watchCount: 0,
                    riskCount: 4_000,
                    lastFilename: nil,
                    lastUploadedAt: nil
                )
            ],
            flags: [:],
            packs: [:],
            tables: [MetricSection.pickerScorecard.rawValue: regionChrome],
            pickerShoppers: 26_349
        )
        XCTAssertTrue(PulseLaunch.pickerExpandRows(from: chrome, filters: district).isEmpty)
        XCTAssertEqual(
            PulseLaunch.pickerExpandFactCount(
                filteredCount: 20,
                warehouseSlicedCount: 20,
                chromeCount: 26_349,
                filtersActive: true
            ),
            20
        )
        let pickerTable = PulseLaunch.pickerExpandTable(
            seatRows: view.filtered[.pickerScorecard] ?? [],
            chrome: chrome,
            filters: district,
            grain: .store
        )
        XCTAssertTrue(HeartbeatMath.grainRowsAreLive(pickerTable))
        XCTAssertEqual(pickerTable.count, 20)
        XCTAssertTrue(
            PulseLaunch.grainMatchesSeat(pickerTable, filters: district, grain: .store)
        )
        XCTAssertFalse(
            PulseLaunch.grainMatchesSeat(regionChrome, filters: district, grain: .store)
        )
        let merged = PulseLaunch.mergeLiveGrainTables(
            incoming: [.sales: view.tables[.sales] ?? []],
            live: [.sales: regionChrome, .pickPath: regionChrome, .labor: regionChrome],
            grain: .store,
            filtersActive: true
        )
        XCTAssertFalse((merged[.sales] ?? []).contains { $0.label == "East Region" })
        XCTAssertNil(merged[.pickPath])
        XCTAssertNil(merged[.labor])
        let companyPaint = PulseLaunch.mergeDashboardSummaries(
            painted: view.summaries.filter { $0.section == .pickerScorecard },
            live: [chrome.card(.pickerScorecard)!],
            filtersActive: true
        )
        XCTAssertEqual(companyPaint.first?.storeCount, 20)
        XCTAssertEqual(companyPaint.first?.headline ?? 0, 20, accuracy: 0.5)
        let keptPlaceholders = PulseLaunch.mergeDashboardPacks(
            incoming: PulseCaches.placeholderGrainPacks(grain: .store),
            live: view.grains,
            filtersActive: true
        )
        XCTAssertFalse(PulseLaunch.grainPacksArePlaceholders(keptPlaceholders))
        var storeFilter = DashboardFilters()
        storeFilter.store = districtStores[0]
        let one = PulseLaunch.seatSlice(warehouse: warehouse, roster: roster, filters: storeFilter)
        let oneCounts = PulseLaunch.summaryStoreCounts(one.summaries)
        XCTAssertEqual(PulseCaches.allowedStores(roster: roster, filters: storeFilter), [districtStores[0]])
        XCTAssertTrue(PulseLaunch.grainRowsScopedToFilter(regionChrome, filters: storeFilter).isEmpty)
        XCTAssertTrue(PulseLaunch.pickerExpandRows(from: chrome, filters: storeFilter).isEmpty)
        for section in MetricSection.dashboardCards {
            XCTAssertEqual(oneCounts[section], 1, "\(section.rawValue) store filter must keep 1 store")
            XCTAssertEqual(
                PulseLaunch.uniqueStores(in: one.filtered[section] ?? []),
                [districtStores[0]],
                "\(section.rawValue) store filter leaked another store"
            )
            let table = one.tables[section] ?? []
            XCTAssertTrue(HeartbeatMath.grainRowsAreLive(table), "\(section.rawValue) store expand must be live")
            XCTAssertEqual(table.count, 1, "\(section.rawValue) store grain must be one seat row")
        }
        let storePicker = PulseLaunch.pickerExpandTable(
            seatRows: one.filtered[.pickerScorecard] ?? [],
            chrome: chrome,
            filters: storeFilter,
            grain: .store
        )
        XCTAssertTrue(HeartbeatMath.grainRowsAreLive(storePicker))
        XCTAssertEqual(storePicker.count, 1)
        XCTAssertTrue(
            PulseLaunch.dashboardExpandIsLive(
                section: .pickerScorecard,
                salesRows: [],
                grainRows: storePicker,
                pickerFacts: 1
            ),
            "store-filter Picker expand must open with seat rows"
        )
        var region = DashboardFilters()
        region.region = MarketRegion.california.rawValue
        let california = PulseLaunch.seatSlice(warehouse: warehouse, roster: roster, filters: region)
        for section in MetricSection.dashboardCards {
            XCTAssertEqual(
                PulseLaunch.summaryStoreCounts(california.summaries)[section],
                20,
                "\(section.rawValue) California seat must keep the NorCal book"
            )
        }
        var om = DashboardFilters()
        om.om = "Jino Arvin"
        let omView = PulseLaunch.seatSlice(warehouse: warehouse, roster: roster, filters: om)
        for section in MetricSection.dashboardCards {
            XCTAssertEqual(
                PulseLaunch.summaryStoreCounts(omView.summaries)[section],
                20,
                "\(section.rawValue) OM seat must keep Jino's 20 stores"
            )
        }
        var division = DashboardFilters()
        division.division = "Jewel Osco"
        let jewel = PulseLaunch.seatSlice(warehouse: warehouse, roster: roster, filters: division)
        for section in MetricSection.dashboardCards {
            XCTAssertEqual(
                PulseLaunch.summaryStoreCounts(jewel.summaries)[section],
                2,
                "\(section.rawValue) Jewel Osco seat must keep both J1 stores"
            )
        }
        XCTAssertFalse(PulseLaunch.shouldMountHubUnderRoleGate())
        XCTAssertFalse(PulseLaunch.shouldUsePagingScroll())
        XCTAssertFalse(PulseLaunch.shouldRemountPageOnDestinationChange())
        XCTAssertFalse(PulseLaunch.shouldStampHubWhenExpandCacheFills())
        XCTAssertFalse(PulseLaunch.shouldStreamPickerOnDashboard())
        XCTAssertFalse(PulseLaunch.shouldStampHubOnWarehousePaint())
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .labor, header: "Cost Tgt", text: "12.00%", rowHealth: .risk
            ),
            .none
        )
    }

    func testUnionRegionBookIsBannedUnderSeatAndClearDropsSeatGrain() {
        var district = DashboardFilters()
        district.district = "03"
        let kept = MetricRow(
            section: .scheduleQuality,
            storeNumber: "304",
            payload: ["schedule_efficiency_pct": 90],
            textPayload: ["district": "03"]
        )
        let extra = MetricRow(
            section: .scheduleQuality,
            division: "NorCal",
            storeNumber: "9999",
            payload: ["schedule_efficiency_pct": 40],
            textPayload: ["district": "03"]
        )
        let merged = PulseCaches.unionRegionBook(
            [kept],
            from: [kept, extra],
            filters: district,
            roster: [:],
            allowed: ["304"]
        )
        XCTAssertEqual(merged.map(\.storeNumber), ["304"])
        let seat = HeartbeatMath.DashboardGrainTableRow(
            label: "304 | NorCal",
            storeCount: 1,
            values: ["90.0%"],
            health: .good
        )
        let regions = MarketRegion.allCases.map {
            HeartbeatMath.DashboardGrainTableRow(
                label: $0.rawValue,
                storeCount: 400,
                values: ["400"],
                health: .watch
            )
        }
        let afterWipe = PulseLaunch.mergeLiveGrainTables(
            incoming: [.scheduleQuality: regions],
            live: [:],
            grain: .region,
            filtersActive: false
        )
        XCTAssertEqual(afterWipe[.scheduleQuality]?.map(\.label), MarketRegion.allCases.map(\.rawValue))
        let leaked = PulseLaunch.mergeLiveGrainTables(
            incoming: [.scheduleQuality: regions],
            live: [.scheduleQuality: [seat]],
            grain: .region,
            filtersActive: false
        )
        XCTAssertTrue(
            HeartbeatMath.grainRowsAreLive(leaked[.scheduleQuality] ?? []),
            "incoming region book wins when present"
        )
        XCTAssertFalse(PulseLaunch.grainMatchesSeat([seat], filters: DashboardFilters(), grain: .region))
        XCTAssertFalse(PulseLaunch.shouldStampHubOnWarehousePaint())
        XCTAssertFalse(PulseLaunch.shouldStampHubWhenExpandCacheFills())
        XCTAssertFalse(PulseLaunch.shouldMountHubUnderRoleGate())
        XCTAssertFalse(PulseLaunch.shouldUsePagingScroll())
        XCTAssertFalse(PulseLaunch.shouldRemountPageOnDestinationChange())
        let padded = PulseQuery.padSeatStores(
            [kept],
            allowed: ["304", "667"],
            roster: [
                "304": .init(division: "NorCal", district: "03", om: "Jino", name: nil),
                "667": .init(division: "NorCal", district: "03", om: "Jino", name: nil),
            ],
            section: .scheduleQuality
        )
        XCTAssertEqual(PulseLaunch.uniqueStores(in: padded), ["304", "667"])
        XCTAssertEqual(
            PulseLaunch.pinSeatStoreCount(
                SectionSummary(
                    section: .scheduleQuality,
                    storeCount: 1,
                    headline: 90,
                    headlineLabel: "Avg",
                    secondary: "",
                    health: .good,
                    watchCount: 0,
                    riskCount: 0,
                    lastFilename: nil,
                    lastUploadedAt: nil
                ),
                seatStores: 2
            ).storeCount,
            2
        )
    }

    func testDistrict03EverySectionHubStoreCardMatchesHeartbeatN() {
        let districtStores = (1...20).map { String($0) }
        var roster: [String: HeartbeatMath.StoreIdentity] = [:]
        for store in districtStores {
            roster[store] = HeartbeatMath.StoreIdentity(
                division: "NorCal", district: "03", om: "Jino Arvin", name: store
            )
        }
        func row(_ section: MetricSection, _ store: String, payload: [String: Double]) -> MetricRow {
            MetricRow(
                section: section,
                division: "NorCal",
                operationsOM: "Jino Arvin",
                storeNumber: store,
                storeName: store,
                payload: payload,
                textPayload: ["district": "03"]
            )
        }
        var district = DashboardFilters()
        district.district = "03"
        let allowed = PulseCaches.allowedStores(roster: roster, filters: district)
        XCTAssertEqual(allowed, Set(districtStores))
        let heartbeatN = allowed?.count ?? 0
        XCTAssertEqual(heartbeatN, 20)
        for section in MetricSection.dashboardCards {
            let facts: [MetricRow]
            switch section {
            case .scheduleQuality:
                facts = Array(districtStores.dropLast(2)).map {
                    row(section, $0, payload: ["schedule_efficiency_pct": 91])
                }
            case .pickPath:
                facts = Array(districtStores.dropLast(1)).map {
                    row(section, $0, payload: ["compliance_pct": 92])
                }
            case .pickerScorecard:
                facts = districtStores.map {
                    row(section, $0, payload: ["pph": 80, "orders": 10])
                }
            default:
                facts = districtStores.map { row(section, $0, payload: ["pph": 80]) }
            }
            let padded = PulseQuery.sliceSection(
                section,
                rows: facts,
                allowed: allowed,
                filters: district,
                roster: roster
            )
            if section == .pickerScorecard {
                XCTAssertEqual(
                    PulseLaunch.hubStoreCardCount(padded),
                    heartbeatN,
                    "\(section.rawValue) picker seat must still cover Heartbeat N stores"
                )
            } else {
                XCTAssertEqual(
                    padded.count,
                    heartbeatN,
                    "\(section.rawValue) page rows must be rosterJoined Heartbeat N, not fact coverage"
                )
                XCTAssertEqual(
                    PulseLaunch.hubStoreCardCount(padded),
                    heartbeatN,
                    "\(section.rawValue) HubStoreCard N must equal Heartbeat \(heartbeatN)"
                )
            }
            XCTAssertEqual(
                PulseLaunch.pinSeatStoreCount(
                    SectionSummary(
                        section: section,
                        storeCount: facts.count,
                        headline: 1,
                        headlineLabel: "Avg",
                        secondary: "",
                        health: .good,
                        watchCount: 0,
                        riskCount: 0,
                        lastFilename: nil,
                        lastUploadedAt: nil
                    ),
                    seatStores: heartbeatN
                ).storeCount,
                heartbeatN,
                "\(section.rawValue) card storeCount must pin to Heartbeat N"
            )
        }
    }

    func testGrainAndPageOnlyFillMustNotBumpFilterStamp() {
        XCTAssertFalse(PulseLaunch.shouldStampHubOnWarehousePaint())
        XCTAssertFalse(PulseLaunch.shouldStampHubWhenExpandCacheFills())
        XCTAssertFalse(PulseLaunch.shouldStampGrainOrPageOnlyFill())
        XCTAssertFalse(PulseLaunch.shouldStampPickerOrPageOnlyInstall())
        XCTAssertFalse(PulseLaunch.shouldInvalidateHubOnBackgroundFill())
        XCTAssertTrue(PulseLaunch.shouldDeferSectionSQLUntilAfterChrome())
        XCTAssertGreaterThan(PulseLaunch.pageSectionLoadDelayNanoseconds, 0)
        XCTAssertTrue(PulseLaunch.shouldBuildExpandTableOffMain())
        XCTAssertFalse(PulseLaunch.shouldMountHubUnderRoleGate())
        XCTAssertFalse(PulseLaunch.shouldUsePagingScroll())
        XCTAssertFalse(PulseLaunch.shouldRemountPageOnDestinationChange())
        XCTAssertFalse(PulseLaunch.shouldStreamPickerOnDashboard())
        XCTAssertFalse(PulseLaunch.shouldStampUIDuringRolePick())
        XCTAssertTrue(PulseLaunch.shouldSkipWarehousePaintOnClear(restoredCompanyWide: true))
        XCTAssertFalse(PulseLaunch.shouldPaintWarehouseOnClear())
    }

    func testScrollAndNavDoNotInvalidateHubOnBackgroundFill() {
        XCTAssertFalse(PulseLaunch.shouldInvalidateHubOnBackgroundFill())
        XCTAssertFalse(PulseLaunch.shouldStampGrainOrPageOnlyFill())
        XCTAssertFalse(PulseLaunch.shouldStampPickerOrPageOnlyInstall())
        XCTAssertFalse(PulseLaunch.shouldStampHubOnWarehousePaint())
        XCTAssertFalse(PulseLaunch.shouldStampHubWhenExpandCacheFills())
        XCTAssertFalse(PulseLaunch.shouldRemountPageOnDestinationChange())
        XCTAssertFalse(PulseLaunch.shouldMountHubUnderRoleGate())
        XCTAssertFalse(PulseLaunch.shouldUsePagingScroll())
        XCTAssertFalse(PulseLaunch.shouldStampHubWhenExpandCacheFills())
        XCTAssertFalse(PulseLaunch.shouldStreamPickerOnDashboard())
        XCTAssertTrue(PulseLaunch.shouldDeferDestinationWorkOnNav())
        XCTAssertTrue(PulseLaunch.shouldPaintScorecardTablesAfterChrome())
        XCTAssertTrue(PulseLaunch.shouldDeferSectionSQLUntilAfterChrome())
        XCTAssertTrue(PulseLaunch.shouldHoldSeatPickerUntilWarehouseReady())
        XCTAssertTrue(PulseLaunch.aisleQuips.contains(PulseLaunch.seatLoadTitle) || PulseLaunch.seatLoadTitle.contains("aisle"))
        XCTAssertTrue(PulseLaunch.seatLoadDirective.localizedCaseInsensitiveContains("unlock"))
    }

    func testSeatWarehouseAlwaysClearsHydrating() async {
        XCTAssertTrue(PulseLaunch.seatWarehouseUnlocksHydrating(.completed))
        XCTAssertTrue(PulseLaunch.seatWarehouseUnlocksHydrating(.timedOut))
        XCTAssertTrue(PulseLaunch.seatWarehouseUnlocksHydrating(.failed))
        XCTAssertTrue(PulseLaunch.shouldUnlockWarehouseHydratingAfterSeat(completed: true))
        XCTAssertTrue(PulseLaunch.shouldUnlockWarehouseHydratingAfterSeat(timedOut: true))
        XCTAssertTrue(PulseLaunch.shouldUnlockWarehouseHydratingAfterSeat(failed: true))
        XCTAssertFalse(PulseLaunch.seatWarehouseShowsError(.completed))
        XCTAssertTrue(PulseLaunch.seatWarehouseShowsError(.timedOut))
        XCTAssertTrue(PulseLaunch.seatWarehouseShowsError(.failed))
        XCTAssertEqual(PulseLaunch.warehouseAfterSeatTimeoutNanoseconds(), 25_000_000_000)
        XCTAssertFalse(PulseLaunch.seatWarehouseTimeoutMessage().isEmpty)
        XCTAssertEqual(
            PulseLaunch.BootPhase.presentingSeat.fraction,
            3.0 / 7.0,
            accuracy: 0.01,
            "presentingSeat is the ~40% hang if hydrating never clears"
        )
        let timedOut = await PulseLaunch.awaitSeatWarehouse(timeoutNanoseconds: 2_000_000) {
            try? await Task.sleep(nanoseconds: 40_000_000)
        }
        XCTAssertTrue(timedOut, "timeout must win so Who's looking unlocks")
        let completed = await PulseLaunch.awaitSeatWarehouse(timeoutNanoseconds: 40_000_000) {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertFalse(completed, "finished warehouse must not report timeout")
    }

    @MainActor
    func testUnlockWarehouseAfterSeatClearsHydratingOnFailAndTimeout() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = HeartbeatStore(rootURL: root)
        store.beginSeatWarehouseHydrating()
        XCTAssertTrue(store.warehouseHydrating)
        store.unlockWarehouseAfterSeat(outcome: .timedOut)
        XCTAssertFalse(store.warehouseHydrating, "timeout must unlock seats")
        XCTAssertEqual(store.errorMessage, PulseLaunch.seatWarehouseTimeoutMessage())
        store.beginSeatWarehouseHydrating()
        store.unlockWarehouseAfterSeat(
            outcome: .failed,
            error: NSError(domain: "seat.warehouse", code: 1, userInfo: [NSLocalizedDescriptionKey: "pack missing"])
        )
        XCTAssertFalse(store.warehouseHydrating, "fail must unlock seats")
        XCTAssertEqual(store.errorMessage, "pack missing")
        store.beginSeatWarehouseHydrating()
        store.unlockWarehouseAfterSeat(outcome: .completed)
        XCTAssertFalse(store.warehouseHydrating)
    }

    func testRollupMarketFillGrainMatchesDashboardGrainUnderDistrict() {
        var district = DashboardFilters()
        district.district = "03"
        XCTAssertEqual(PulseLaunch.dashboardGrain(filters: district, sessionRole: .districtManager), .store)
        XCTAssertEqual(RollupMarketFill.grain(for: district), .store)
        var store = DashboardFilters()
        store.store = "304"
        XCTAssertEqual(RollupMarketFill.grain(for: store), .store)
        var om = DashboardFilters()
        om.om = "Jino Arvin"
        XCTAssertEqual(RollupMarketFill.grain(for: om), .store)
        var division = DashboardFilters()
        division.division = "Jewel Osco"
        XCTAssertEqual(PulseLaunch.dashboardGrain(filters: division, sessionRole: .director), .district)
        XCTAssertEqual(RollupMarketFill.grain(for: division), .district)
        var region = DashboardFilters()
        region.region = MarketRegion.california.rawValue
        XCTAssertEqual(RollupMarketFill.grain(for: region), .division)
        XCTAssertEqual(RollupMarketFill.grain(for: DashboardFilters()), .region)
    }

    func testUnfilteredMergeDropsSeatGrainAndSeatPacksRejectChrome() {
        let seat = HeartbeatMath.DashboardGrainTableRow(
            label: "304 | NorCal",
            storeCount: 1,
            values: ["90.0%"],
            health: .good
        )
        let regions = MarketRegion.allCases.map {
            HeartbeatMath.DashboardGrainTableRow(
                label: $0.rawValue,
                storeCount: 400,
                values: ["400"],
                health: .watch
            )
        }
        let restored = PulseLaunch.mergeLiveGrainTables(
            incoming: [:],
            live: [.scheduleQuality: [seat]],
            grain: .region,
            filtersActive: false
        )
        XCTAssertNil(
            restored[.scheduleQuality],
            "unfiltered region restore must not keep District store grain"
        )
        let keptRegions = PulseLaunch.mergeLiveGrainTables(
            incoming: [.scheduleQuality: regions],
            live: [.scheduleQuality: [seat]],
            grain: .region,
            filtersActive: false
        )
        XCTAssertEqual(keptRegions[.scheduleQuality]?.map(\.label), MarketRegion.allCases.map(\.rawValue))
        let chromePacks = MarketRegion.allCases.map {
            DashScopePack(line: DashScopeLine(label: $0.rawValue, value: "400", health: .watch, count: 400), flags: [], children: [])
        }
        XCTAssertTrue(
            PulseLaunch.grainRowsFromSeatPacks(chromePacks, section: .scheduleQuality, grain: .store).isEmpty,
            "DashScopeStrip must never fall back to chrome region labels"
        )
        let seatPacks = [
            DashScopePack(
                line: DashScopeLine(label: "304", value: "90.0%", health: .good, count: 1),
                flags: [],
                children: []
            )
        ]
        let fromPacks = PulseLaunch.grainRowsFromSeatPacks(seatPacks, section: .scheduleQuality, grain: .store)
        XCTAssertTrue(HeartbeatMath.grainRowsAreLive(fromPacks))
        XCTAssertEqual(fromPacks.count, 1)
        XCTAssertTrue(PulseLaunch.shouldSkipWarehousePaintOnClear(restoredCompanyWide: true))
        XCTAssertFalse(PulseLaunch.shouldPaintWarehouseOnClear())
    }

    func testPickerGrainPacksStayWhenFactsExistEvenIfHidePicker() {
        func shopper(_ id: String, region: String) -> MetricRow {
            MetricRow(
                section: .pickerScorecard,
                division: region,
                storeNumber: "12",
                payload: ["pph": 40, "orders": 20],
                textPayload: ["shopper_id": id, "shopper_name": id]
            )
        }
        let latest: [MetricSection: [MetricRow]] = [
            .pickerScorecard: [
                shopper("A", "Jewel Osco"),
                shopper("B", "NorCal"),
                shopper("C", "Southern"),
                shopper("D", "Seattle"),
            ]
        ]
        let hidden = PulseCaches.grainPacks(
            latest: latest,
            grain: .region,
            hidePicker: true,
            roster: [:]
        )
        XCTAssertFalse(
            (hidden[.pickerScorecard] ?? []).isEmpty,
            "hidePicker must not drop Picker ScoreCard packs when facts exist"
        )
        XCTAssertTrue(PulseLaunch.pickerPacksAreLive(hidden[.pickerScorecard] ?? []))
        let empty = PulseCaches.grainPacks(
            latest: [:],
            grain: .region,
            hidePicker: true,
            roster: [:]
        )
        XCTAssertTrue(
            (empty[.pickerScorecard] ?? []).isEmpty,
            "empty picker facts must not emit placeholder packs that wipe chrome"
        )
        let chrome = PulseDashChrome(
            summaries: [
                SectionSummary(
                    section: .pickerScorecard,
                    storeCount: 26_349,
                    headline: 26_349,
                    headlineLabel: "Shoppers",
                    secondary: "",
                    health: .watch,
                    watchCount: 0,
                    riskCount: 4_000,
                    lastFilename: nil,
                    lastUploadedAt: nil
                )
            ],
            flags: [:],
            packs: [:],
            pickerShoppers: 26_349
        )
        XCTAssertTrue(PulseLaunch.pickerFactsExist(chrome: chrome, latestCount: 0, sqliteCount: 26_349))
        let seeded = PulseLaunch.pickerExpandRows(from: chrome)
        XCTAssertTrue(HeartbeatMath.grainRowsAreLive(seeded))
        XCTAssertTrue(
            PulseLaunch.dashboardExpandIsLive(
                section: .pickerScorecard,
                salesRows: [],
                grainRows: seeded,
                pickerFacts: 26_349
            )
        )
        XCTAssertTrue(
            PulseLaunch.dashboardExpandIsLive(
                section: .pickerScorecard,
                salesRows: [],
                grainRows: [],
                pickerFacts: 26_349
            ),
            "expandLive must not stay false when the pack has picker rows"
        )
        let emptyPaint = SectionSummary(
            section: .pickerScorecard,
            storeCount: 0,
            headline: 0,
            headlineLabel: "Shoppers",
            secondary: "",
            health: .none,
            watchCount: 0,
            riskCount: 0
        )
        let merged = PulseLaunch.mergeDashboardSummaries(
            painted: [emptyPaint],
            live: [chrome.card(.pickerScorecard)!]
        )
        XCTAssertEqual(merged.first?.headline ?? 0, 26_349, accuracy: 0.5)
        let wipedPacks = PulseLaunch.mergeDashboardPacks(
            incoming: [:],
            live: hidden
        )
        XCTAssertTrue(PulseLaunch.pickerPacksAreLive(wipedPacks[.pickerScorecard] ?? []))
        XCTAssertFalse(PulseLaunch.shouldStreamPickerOnDashboard())
        XCTAssertFalse(PulseLaunch.shouldStampHubWhenExpandCacheFills())
        XCTAssertFalse(PulseLaunch.shouldMountHubUnderRoleGate())
        XCTAssertFalse(PulseLaunch.shouldUsePagingScroll())
        XCTAssertFalse(PulseLaunch.shouldRemountPageOnDestinationChange())
    }

    func testLaborExpandPolarityAndTargetVsActualStatus() {
        XCTAssertEqual(HeartbeatMath.dashboardTableHeaders(.labor).first, "Target Vs Actual")
        XCTAssertFalse(HeartbeatMath.dashboardTableHeaders(.labor).contains("TvA"))
        XCTAssertEqual(HeartbeatMath.laborHealth(-1.2), .good)
        XCTAssertEqual(HeartbeatMath.laborHealth(1.5), .watch)
        XCTAssertEqual(HeartbeatMath.laborHealth(4.0), .risk)
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .labor, header: "Target Vs Actual", text: "-1.20%", rowHealth: .risk
            ),
            .good
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .labor, header: "Target Vs Actual", text: "4.00%", rowHealth: .good
            ),
            .risk
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .labor, header: "Cost Tgt", text: "12.00%", rowHealth: .risk
            ),
            .none
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .labor, header: "UPLH", text: "2.00%", rowHealth: .none
            ),
            .watch
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .labor, header: "Wage", text: "-0.40%", rowHealth: .none
            ),
            .good
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .labor, header: "AIV", text: "5.10%", rowHealth: .none
            ),
            .risk
        )
        let over = MetricRow(
            section: .labor,
            storeNumber: "1",
            payload: ["target_vs_actual_pct": 5, "schedule_efficiency_pct": 99],
            textPayload: ["labor_grain": "store"]
        )
        let under = MetricRow(
            section: .labor,
            storeNumber: "2",
            payload: ["target_vs_actual_pct": -2, "schedule_efficiency_pct": 40],
            textPayload: ["labor_grain": "store"]
        )
        XCTAssertEqual(HeartbeatMath.dashboardTableValues(.labor, rows: [over]).health, .risk)
        XCTAssertEqual(HeartbeatMath.dashboardTableValues(.labor, rows: [under]).health, .good)
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .pickerScorecard, header: "Healthy", text: "10", rowHealth: .watch
            ),
            .good
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .pickerScorecard, header: "Watch", text: "4", rowHealth: .good
            ),
            .watch
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .missingItems, header: "At Risk", text: "3", rowHealth: .good
            ),
            .risk
        )
    }

    func testExpandCellHealthMatchesCalloutPolarity() {
        let lrHeaders = HeartbeatMath.dashboardTableHeaders(.lostRevenue)
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .lostRevenue, header: "Lost %", text: "6.00%", rowHealth: .good,
                values: ["$10,000.00", "6.00%", "2.49%", "$200,000.00", "$1,000.00", "$100.00", "$50.00", "$20.00", "$5.00"],
                headers: lrHeaders
            ),
            .risk
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .lostRevenue, header: "Lost %", text: "4.00%", rowHealth: .risk
            ),
            .watch
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .lostRevenue, header: "Lost %", text: "2.00%", rowHealth: .risk
            ),
            .good
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .lostRevenue, header: "Lost $", text: "$1,962,441.00", rowHealth: .none,
                values: ["$1,962,441.00", "4.26%", "2.49%", "$46,077,144.00", "$500,000.00", "$200,000.00", "$126,864.00", "$90,000.00", "$10.00"],
                headers: lrHeaders
            ),
            .watch
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .lostRevenue, header: "Goal %", text: "2.49%", rowHealth: .risk
            ),
            .none
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .lostRevenue, header: "eComm $", text: "$46,077,144.00", rowHealth: .risk
            ),
            .none
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .lostRevenue, header: "Kill", text: "$100.00", rowHealth: .good
            ),
            .risk
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .lostRevenue, header: "Refund", text: "$100.00", rowHealth: .good
            ),
            .watch
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .fiveStar, header: "Rating", text: "4.70", rowHealth: .risk
            ),
            .good
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .fiveStar, header: "Flash", text: "80.0%", rowHealth: .risk
            ),
            .good
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .fiveStar, header: "Flash", text: "50.0%", rowHealth: .good
            ),
            .risk
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .fiveStar, header: "Pre-Sub", text: "7.0%", rowHealth: .good
            ),
            .risk
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .missingItems, header: "Rate", text: "7.00%", rowHealth: .good
            ),
            .risk
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .pickPath, header: "Path %", text: "95.0%", rowHealth: .risk
            ),
            .good
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .pickPath, header: "Path %", text: "75.0%", rowHealth: .good
            ),
            .risk
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .pickPath, header: "AVG PPH", text: "70.0", rowHealth: .good
            ),
            .risk
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .prepNotReady, header: "PNR %", text: "3.0%", rowHealth: .good
            ),
            .risk
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .prepNotReady, header: "Goal", text: "1.9%", rowHealth: .risk
            ),
            .none
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .dynacap, header: "Pcs/Hr", text: "70.0", rowHealth: .risk
            ),
            .good
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .scheduleQuality, header: "Sch Eff", text: "92.0%", rowHealth: .risk
            ),
            .good
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .scheduleQuality, header: "Under", text: "8.00%", rowHealth: .good
            ),
            .risk
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .pph, header: "PPH", text: "81.0", rowHealth: .risk
            ),
            .good
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .sales, header: "YoY %", text: "-6.00%", rowHealth: .good
            ),
            .risk
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .sales, header: "YoY %", text: "1.20%", rowHealth: .risk
            ),
            .good
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .sales, header: "Sales $", text: "$49,026,551.00", rowHealth: .risk
            ),
            .none
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .sales, header: "Ord YoY", text: "-4.00%", rowHealth: .good
            ),
            .risk
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .pickerScorecard, header: "Shoppers", text: "26,349", rowHealth: .watch
            ),
            .none
        )
        XCTAssertEqual(
            HeartbeatMath.dashboardExpandCellHealth(
                section: .labor, header: "Cost Tgt", text: "12.00%", rowHealth: .risk
            ),
            .none
        )
    }

    func testShareBodyUsesReadableColumnsAndExpandCellColors() {
        let grain = HeartbeatMath.DashboardGrainTableRow(
            label: "East Region",
            storeCount: 400,
            values: ["$80,000.00", "6.00%", "2.49%", "$1,200,000.00", "$10,000.00", "$4,000.00", "$2,000.00", "$1,000.00", "$500.00"],
            health: .risk
        )
        let snap = PulseMail.Snapshot(
            filterSummary: "Company",
            grain: "region",
            summaries: [
                SectionSummary(
                    section: .lostRevenue,
                    storeCount: 400,
                    headline: 80_000,
                    headlineLabel: "Total Opportunity",
                    secondary: "",
                    health: .risk,
                    watchCount: 0,
                    riskCount: 12,
                    lostRevenuePct: 6
                )
            ],
            rows: [:],
            pickerCounts: [:],
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            grainTables: [.lostRevenue: [grain]]
        )
        let packet = PulseMail.make(snap, pages: [.dashboard])
        XCTAssertTrue(packet.html.contains("cell-risk") || packet.html.contains("#DC2626"), packet.html)
        XCTAssertTrue(packet.html.contains("cellpadding=\"12\"") || packet.html.contains("cellpadding=\"14\""), packet.html)
        XCTAssertTrue(packet.html.contains("max-width:1100px"), packet.html)
        XCTAssertTrue(packet.html.contains("width=\"108\"") || packet.html.contains("width:108px"), packet.html)
        XCTAssertTrue(packet.html.contains("border-right:1px solid"), packet.html)
        XCTAssertFalse(packet.html.contains("width:25%"), packet.html)
        XCTAssertTrue(packet.plain.contains("Lost $"), packet.plain)
        XCTAssertTrue(packet.plain.contains("East Region"), packet.plain)
        XCTAssertTrue(packet.plain.contains("  "), packet.plain)
        XCTAssertFalse(packet.plain.contains("East Region | $80,000.00 | 6.00%"), packet.plain)
        let overflow = PulseMail.overflowMailBody(packet.brief)
        XCTAssertTrue(overflow.contains("attached as HTML"))
        XCTAssertTrue(overflow.contains("padding:22px 24px") || overflow.contains("padding:24px 20px"))
        XCTAssertFalse(overflow.contains("<pre"))
    }

    func testUnfilteredLostRevenueSecondaryDollarsPreferMarketTOKeys() {
        let market = MetricRow(
            section: .lostRevenue,
            storeNumber: "",
            payload: [
                "lost_revenue": 1_962_441.23,
                "lost_revenue_pct": 4.26,
                "lost_revenue_goal": 1_147_500.91,
                "lost_revenue_goal_pct": 2.49,
                "ecomm_sales": 46_077_144.47,
                "missed_sales": 126_864.44,
                "missed_sales_goal": 31_716,
                "post_sub_oos_foregone": 500_000,
                "refund_lost": 200_000,
                "cancelled_lost": 90_000,
                "kill_switch_lost": 40_000,
                "kill_switch_lost_goal": 16_574.80,
            ],
            textPayload: ["lost_grain": "market"]
        )
        let stores = [
            MetricRow(
                section: .lostRevenue,
                storeNumber: "1",
                payload: [
                    "lost_revenue": 1_200_000,
                    "ecomm_sales": 20_000_000,
                    "missed_sales": 20_000,
                    "post_sub_oos_foregone": 10,
                    "refund_lost": 10,
                    "cancelled_lost": 10,
                    "kill_switch_lost": 10,
                ],
                textPayload: ["lost_grain": "store"]
            ),
            MetricRow(
                section: .lostRevenue,
                storeNumber: "2",
                payload: [
                    "lost_revenue": 815_924,
                    "ecomm_sales": 10_000_000,
                    "missed_sales": 11_716,
                    "post_sub_oos_foregone": 10,
                    "refund_lost": 10,
                    "cancelled_lost": 10,
                    "kill_switch_lost": 10,
                ],
                textPayload: ["lost_grain": "store"]
            ),
        ]
        let company = stores + [market]
        XCTAssertEqual(HeartbeatMath.lostRevenueTODollars(company, key: "missed_sales"), 126_864.44, accuracy: 0.01)
        XCTAssertEqual(HeartbeatMath.lostRevenueTODollars(company, key: "lost_revenue"), 1_962_441.23, accuracy: 0.01)
        XCTAssertNotEqual(HeartbeatMath.lostRevenueTODollars(company, key: "missed_sales"), 31_716, accuracy: 1)
        XCTAssertEqual(HeartbeatMath.lostRevenueTODollars(stores, key: "missed_sales"), 31_716, accuracy: 0.01)
        XCTAssertEqual(HeartbeatMath.lostRevenueTODollars(stores, key: "lost_revenue"), 2_015_924, accuracy: 0.01)

        let flags = HeartbeatMath.lostRevenueMetricFlags(company, includeAll: true)
        let missed = flags.first { $0.name.contains("Missed") }
        XCTAssertEqual(missed?.value, HeartbeatFormat.money(126_864.44))
        let seatFlags = HeartbeatMath.lostRevenueMetricFlags(stores, includeAll: true)
        let seatMissed = seatFlags.first { $0.name.contains("Missed") }
        XCTAssertEqual(seatMissed?.value, HeartbeatFormat.money(31_716))

        let values = HeartbeatMath.dashboardTableValues(.lostRevenue, rows: company).values
        XCTAssertEqual(values[0], HeartbeatFormat.money(1_962_441.23))
        XCTAssertEqual(values[6], HeartbeatFormat.money(126_864.44))
        let seatValues = HeartbeatMath.dashboardTableValues(.lostRevenue, rows: stores).values
        XCTAssertEqual(seatValues[6], HeartbeatFormat.money(31_716))
        XCTAssertEqual(HeartbeatMath.lostRevenueMarketRow(in: company)?.number("lost_revenue_goal") ?? 0, 1_147_500.91, accuracy: 0.01)
        XCTAssertNotEqual(HeartbeatMath.lostRevenueMarketRow(in: company)?.number("lost_revenue_goal") ?? 0, 16_574.80, accuracy: 1)
    }

    func testUnfilteredLostRevenueHeadlineUsesMarketTotal1962441() {
        let market = MetricRow(
            section: .lostRevenue,
            storeNumber: "",
            payload: ["lost_revenue": 1_962_441.23, "lost_revenue_pct": 4.53],
            textPayload: ["lost_grain": "market"]
        )
        let stores = [
            MetricRow(
                section: .lostRevenue,
                storeNumber: "1",
                payload: ["lost_revenue": 1_200_000],
                textPayload: ["lost_grain": "store"]
            ),
            MetricRow(
                section: .lostRevenue,
                storeNumber: "2",
                payload: ["lost_revenue": 815_924],
                textPayload: ["lost_grain": "store"]
            ),
        ]
        let company = HeartbeatMath.summarize(.lostRevenue, rows: stores + [market], upload: nil)
        XCTAssertEqual(company.headline ?? 0, 1_962_441.23, accuracy: 0.01)
        XCTAssertNotEqual(company.headline ?? 0, 2_015_924, accuracy: 1)
        XCTAssertEqual(HeartbeatMath.totalOpportunityDollars(market), 1_962_441.23, accuracy: 0.01)
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
        let grain = HeartbeatMath.dashboardGrainTableFilled(
            section: .lostRevenue,
            rows: caches.filteredLatest[.lostRevenue] ?? [],
            grain: .district,
            order: (caches.cachedGrainPacks[.lostRevenue] ?? []).map(\.line.label),
            goalFallback: HeartbeatMath.lostRevenueGoalPct(
                rows: [],
                market: (caches.latestBySection[.lostRevenue] ?? []).first { $0.textPayload["lost_grain"] == "market" }
            )
        )
        XCTAssertTrue(HeartbeatMath.grainRowsAreLive(grain), "Jewel Osco district expand must show dollars")
        XCTAssertGreaterThan(grain.filter { $0.storeCount > 0 }.count, 3)
        XCTAssertTrue(grain.contains { $0.values.contains(where: { $0.contains("%") && $0 != "—" }) })
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
        XCTAssertTrue(PulseLaunch.leaveSplashAfterChrome(paintedStoreCards: 3))
        XCTAssertFalse(PulseLaunch.leaveSplashAfterChrome(paintedStoreCards: 0))
        XCTAssertTrue(PulseLaunch.shouldPresentSeatBeforeWarehouse())
        XCTAssertTrue(PulseLaunch.shouldKeepLastSeatOnPackLoad(seatPresented: true))
        XCTAssertFalse(PulseLaunch.shouldKeepLastSeatOnPackLoad(seatPresented: false))
        XCTAssertFalse(PulseLaunch.shouldSkipRoleGateOnRelaunch(role: .districtManager, filtersActive: true))
        XCTAssertFalse(PulseLaunch.shouldSkipRoleGateOnRelaunch(role: .backstage, filtersActive: false))
        XCTAssertFalse(PulseLaunch.shouldSkipRoleGateOnRelaunch(role: .districtManager, filtersActive: false))
        XCTAssertFalse(PulseLaunch.shouldSkipRoleGateOnRelaunch(role: nil, filtersActive: true))
        var lastSeat = DashboardFilters()
        lastSeat.district = "03"
        XCTAssertEqual(
            PulseLaunch.suggestedSeatValues(role: .districtManager, pending: lastSeat),
            ["03"]
        )
        XCTAssertEqual(
            PulseLaunch.suggestedSeatValues(role: .evp, pending: lastSeat),
            []
        )
        XCTAssertTrue(PulseLaunch.suggestedSeatValues(role: .districtManager, pending: nil).isEmpty)
        XCTAssertFalse(PulseLaunch.shouldAllowShare(warehouseHydrating: true))
        XCTAssertTrue(PulseLaunch.shouldAllowShare(warehouseHydrating: false))
        let phases = PulseLaunch.BootPhase.allCases.sorted { $0.rawValue < $1.rawValue }
        XCTAssertEqual(phases.first, .openingFloor)
        XCTAssertEqual(phases.last, .ready)
        for (index, phase) in phases.enumerated() where index > 0 {
            XCTAssertGreaterThan(phase.fraction, phases[index - 1].fraction, "\(phase)")
            XCTAssertFalse(phase.label.isEmpty)
            XCTAssertNotEqual(phase.label, phases[index - 1].label)
        }
        XCTAssertEqual(PulseLaunch.BootPhase.openingFloor.label, "Opening the floor")
        XCTAssertEqual(PulseLaunch.BootPhase.paintingAisle.label, "Setting the aisle")
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
        XCTAssertTrue(
            PulseLaunch.shouldFetchRemotePack(
                remoteBytes: 2_000_000,
                localBytes: 2_000_000,
                localRowsLoaded: 400,
                remoteUpdated: "2026-09-10T19:15:00.000Z",
                knownUpdated: "2026-09-09T12:00:00.000Z"
            )
        )
        XCTAssertFalse(
            PulseLaunch.shouldFetchRemotePack(
                remoteBytes: 2_000_000,
                localBytes: 2_000_000,
                localRowsLoaded: 400,
                remoteUpdated: "2026-09-10T19:15:00.000Z",
                knownUpdated: "2026-09-10T19:15:00.000Z"
            )
        )
        XCTAssertTrue(
            PulseLaunch.shouldFetchRemotePack(
                remoteBytes: 2_000_000,
                localBytes: 2_000_000,
                localRowsLoaded: 400,
                remoteUpdated: "2026-09-10T19:15:00.000Z",
                knownUpdated: ""
            )
        )
        XCTAssertEqual(PulseCloud.objectByteCount(from: ["size": NSNumber(value: 2_100_000)]), 2_100_000)
        XCTAssertEqual(PulseCloud.objectByteCount(from: ["size": 2_100_000.0]), 2_100_000)
        XCTAssertTrue(PulseLaunch.shouldCheckCloudPackDuringSeatWait())
        XCTAssertTrue(PulseLaunch.shouldPinHubChromeAboveContent())
    }

    func testPromotedPackReloadsInSessionEvenWhenConstrained() {
        XCTAssertTrue(PulseLaunch.reloadInSessionAfterFetch(constrained: true, localRowsLoaded: 400))
        XCTAssertTrue(PulseLaunch.reloadInSessionAfterFetch(constrained: true, localRowsLoaded: 0))
        XCTAssertTrue(PulseLaunch.reloadInSessionAfterFetch(constrained: false, localRowsLoaded: 400))
    }

    func testDashboardGrainTableKeepsFullMoneyAndColumnCounts() {
        for section in MetricSection.dashboardCards {
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
        let salesRow = MetricRow(
            section: .sales,
            division: "NorCal",
            operationsOM: "A",
            storeNumber: "1490",
            payload: [
                "sales_dollars": 22_108.67,
                "sales_yoy_pct": -4.2,
                "sales_orders": 82,
            ],
            textPayload: ["district": "03", "sales_grain": "store"]
        )
        let salesValues = HeartbeatMath.dashboardTableValues(.sales, rows: [salesRow])
        XCTAssertEqual(salesValues.values.count, HeartbeatMath.dashboardTableHeaders(.sales).count)
        XCTAssertTrue(salesValues.values[0].contains("22,108.67"), salesValues.values[0])
        XCTAssertEqual(salesValues.values[1], "-4.20%")
        XCTAssertEqual(salesValues.values[2], "82")
        let salesTable = HeartbeatMath.dashboardGrainTable(
            section: .sales,
            rows: [salesRow],
            grain: .store,
            order: []
        )
        XCTAssertEqual(salesTable.first?.values.count, 3)
        XCTAssertEqual(salesTable.first?.values[1], "-4.20%")
        XCTAssertEqual(salesTable.first?.values[2], "82")
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
        let seated = PulseQuery.overlayPageOnlySummaries(
            painted: [sales, empty],
            live: [live],
            filtersActive: true
        )
        XCTAssertEqual(
            seated.first { $0.section == .pickerScorecard }?.storeCount,
            0,
            "seat paint must not restore company picker chrome"
        )
        let kept = PulseQuery.keepPageOnlyRows(
            painted: [.sales: []],
            live: [.pickerScorecard: [MetricRow(section: .pickerScorecard, division: "10", operationsOM: "A", storeNumber: "12", payload: ["pph": 40], textPayload: ["shopper_id": "A", "shopper_name": "A"])]]
        )
        XCTAssertEqual(kept[.pickerScorecard]?.count, 1)
        XCTAssertTrue(PulseLaunch.needsShopperJoin(.pph))
        XCTAssertTrue(PulseLaunch.needsShopperJoin(.pickerScorecard))
        XCTAssertFalse(PulseLaunch.needsShopperJoin(.sales))
        XCTAssertFalse(PulseLaunch.shouldStampPicker(replace: true, dest: .dashboard, count: 80, lastStampCount: 0))
        XCTAssertTrue(PulseLaunch.shouldStampPicker(replace: true, dest: .pickerScorecard, count: 80, lastStampCount: 0))
        XCTAssertFalse(PulseLaunch.shouldStampPicker(replace: false, dest: .dashboard, count: 200, lastStampCount: 80))
        XCTAssertFalse(PulseLaunch.shouldStampPicker(replace: false, dest: .pph, count: 500, lastStampCount: 80))
        XCTAssertTrue(PulseLaunch.shouldStampPicker(replace: false, dest: .pph, count: 880, lastStampCount: 80))
        XCTAssertFalse(PulseLaunch.shouldRefreshPickerChrome(replace: true, dest: .dashboard, stamp: true))
        XCTAssertTrue(PulseLaunch.shouldRefreshPickerChrome(replace: true, dest: .pickerScorecard, stamp: true))
        XCTAssertFalse(PulseLaunch.shouldRefreshPickerChrome(replace: false, dest: .dashboard, stamp: false))
        XCTAssertTrue(PulseLaunch.shouldRefreshPickerChrome(replace: false, dest: .pph, stamp: true))
        XCTAssertFalse(PulseLaunch.shouldTouchPickerUI(stamp: false, chrome: false))
        XCTAssertTrue(PulseLaunch.shouldTouchPickerUI(stamp: true, chrome: false))
        XCTAssertFalse(PulseLaunch.shouldRestartGrainPaint(alreadySettled: true, dest: .dashboard))
        XCTAssertTrue(PulseLaunch.shouldRestartGrainPaint(alreadySettled: false, dest: .dashboard))
        XCTAssertFalse(PulseLaunch.shouldRestartGrainPaint(alreadySettled: false, dest: .pph))
        XCTAssertEqual(HubLayout.calloutColumns(count: 7, width: 1100), 4)
        XCTAssertEqual(HubLayout.calloutColumns(count: 5, width: 1100), 3)
    }

    func testPostReadyWorkStaysOffSplashAndCoolsTheHub() {
        XCTAssertGreaterThan(PulseLaunch.grainPaintDelayNanoseconds, 0)
        XCTAssertGreaterThan(PulseLaunch.hubFirstInteractionNanoseconds, 0)
        XCTAssertGreaterThan(PulseLaunch.grainPaintDelayNanoseconds, PulseLaunch.hubFirstInteractionNanoseconds)
        XCTAssertGreaterThan(PulseLaunch.cloudHydrateDelayNanoseconds, PulseLaunch.grainPaintDelayNanoseconds)
        XCTAssertTrue(PulseLaunch.streamPickerAfterReady)
        XCTAssertTrue(PulseLaunch.streamPickerSnappyAfterReady)
        XCTAssertFalse(PulseLaunch.shouldStreamPickerOnDashboard())
        XCTAssertEqual(PulseLaunch.pickerWarehouseCap, 4_000)
        XCTAssertTrue(PulseLaunch.shouldDeferPickerStreamUntilHubQuiet())
        XCTAssertTrue(PulseLaunch.shouldDeferGrainTablesUntilHubQuiet())
        XCTAssertEqual(PulseLaunch.pickerUIStampStride, 800)
        XCTAssertGreaterThan(PulseLaunch.pickerChunkPauseNanoseconds, 0)
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
        XCTAssertTrue(PulseLaunch.shouldAcknowledgeFilterClearImmediately(previousActive: true, nextActive: false))
        XCTAssertFalse(PulseLaunch.shouldAcknowledgeFilterClearImmediately(previousActive: false, nextActive: false))
        XCTAssertFalse(PulseLaunch.shouldAcknowledgeFilterClearImmediately(previousActive: true, nextActive: true))
        XCTAssertTrue(PulseLaunch.shouldUseCompanyGrainWhenFiltersClear())
        XCTAssertEqual(PulseLaunch.unfilteredDashboardGrain(), .region)
        XCTAssertTrue(PulseLaunch.shouldDiscardPendingLaunchFiltersOnClear())
        XCTAssertTrue(PulseLaunch.shouldDiscardPendingLaunchFiltersOnRolePick())
        var districtSeat = DashboardFilters()
        districtSeat.district = "03"
        XCTAssertEqual(
            PulseLaunch.dashboardGrain(filters: districtSeat, sessionRole: .districtManager),
            .store
        )
        XCTAssertEqual(
            PulseLaunch.dashboardGrain(filters: DashboardFilters(), sessionRole: .districtManager),
            .region
        )
        XCTAssertEqual(
            PulseLaunch.dashboardGrain(filters: DashboardFilters(), sessionRole: .om),
            .region
        )
        let bounce = PulseLaunch.consumePendingLaunchFilters(
            pending: districtSeat,
            filtersActive: false,
            needsRolePick: false
        )
        XCTAssertEqual(bounce.apply?.district, "03")
        XCTAssertNil(bounce.remaining)
        let afterClear = PulseLaunch.consumePendingLaunchFilters(
            pending: nil,
            filtersActive: false,
            needsRolePick: false
        )
        XCTAssertNil(afterClear.apply)
        XCTAssertNil(afterClear.remaining)
        let alreadySeated = PulseLaunch.consumePendingLaunchFilters(
            pending: districtSeat,
            filtersActive: true,
            needsRolePick: false
        )
        XCTAssertNil(alreadySeated.apply)
        XCTAssertNil(alreadySeated.remaining)
        let waitingForSeat = PulseLaunch.consumePendingLaunchFilters(
            pending: districtSeat,
            filtersActive: false,
            needsRolePick: true
        )
        XCTAssertNil(waitingForSeat.apply)
        XCTAssertEqual(waitingForSeat.remaining?.district, "03")
        XCTAssertEqual(DashboardFilters().chipTitle(for: .region), "Region")
        XCTAssertEqual(DashboardFilters().chipTitle(for: .division), "Division")
        XCTAssertEqual(DashboardFilters().chipTitle(for: .district), "District")
        XCTAssertEqual(DashboardFilters().chipTitle(for: .om), "OM")
        XCTAssertEqual(DashboardFilters().chipTitle(for: .store), "Store")
        XCTAssertEqual(districtSeat.chipTitle(for: .district), "03")
        XCTAssertEqual(PulseLaunch.filterPaintDelayNanoseconds(clearingAll: true), 0)
        XCTAssertGreaterThan(PulseLaunch.filterPaintDelayNanoseconds(clearingAll: false), 0)
        XCTAssertLessThan(PulseLaunch.filterPaintDelayNanoseconds(clearingAll: false), PulseLaunch.grainPaintDelayNanoseconds)
        XCTAssertTrue(PulseLaunch.shouldRestoreUnfilteredPulseOnClear(hasCompanyWideCache: true))
        XCTAssertFalse(PulseLaunch.shouldRestoreUnfilteredPulseOnClear(hasCompanyWideCache: false))
        XCTAssertTrue(PulseLaunch.shouldAcknowledgeSidebarToggleImmediately())
        XCTAssertTrue(PulseLaunch.shouldKeepDetailWidthWhenSidebarOpens())
        XCTAssertTrue(PulseLaunch.shouldPaintDestinationChromeImmediately())
        XCTAssertTrue(PulseLaunch.shouldPaintScorecardTablesAfterChrome())
        XCTAssertTrue(PulseLaunch.shouldDeferDestinationWorkOnNav())
        XCTAssertTrue(PulseLaunch.shouldHoldSeatPickerUntilWarehouseReady())
        XCTAssertFalse(PulseLaunch.shouldMountHubUnderRoleGate())
        XCTAssertFalse(PulseLaunch.shouldUsePagingScroll())
        XCTAssertFalse(PulseLaunch.shouldRemountPageOnDestinationChange())
        XCTAssertTrue(PulseLaunch.shouldDeferStoreRowBuildUntilExpanded())
        XCTAssertTrue(PulseLaunch.shouldBuildExpandTableOffMain())
        XCTAssertFalse(PulseLaunch.shouldStampHubWhenExpandCacheFills())
        XCTAssertTrue(PulseLaunch.shouldPrefetchSalesExpandWithGrainTables())
        XCTAssertTrue(PulseLaunch.shouldRevealHubAfterSeatPaint())
        XCTAssertTrue(PulseLaunch.shouldCheckCloudPackDuringSeatWait())
        XCTAssertTrue(PulseLaunch.shouldPinHubChromeAboveContent())
        XCTAssertTrue(PulseLaunch.reloadInSessionAfterFetch(constrained: true, localRowsLoaded: 400))
        XCTAssertFalse(PulseLaunch.shouldShowHubFillBanner(needsRolePick: true, warehouseHydrating: true))
        XCTAssertTrue(PulseLaunch.shouldShowHubFillBanner(needsRolePick: false, warehouseHydrating: true))
        XCTAssertFalse(PulseLaunch.shouldShowHubFillBanner(needsRolePick: false, warehouseHydrating: false))
        XCTAssertFalse(PulseLaunch.shouldStampUIDuringRolePick())
        XCTAssertTrue(PulseLaunch.shouldLockPagerScrollDirection())
        XCTAssertFalse(PulseLaunch.seatLoadTitle.isEmpty)
        XCTAssertFalse(PulseLaunch.seatLoadDirective.isEmpty)
        XCTAssertFalse(PulseLaunch.aisleQuips.isEmpty)
        XCTAssertTrue(PulseLaunch.aisleQuips.contains(where: { $0.localizedCaseInsensitiveContains("ice cream") }))
        XCTAssertEqual(PulseLaunch.seatLoadQuip(at: 0), PulseLaunch.aisleQuips[0])
        XCTAssertEqual(PulseLaunch.seatLoadQuip(at: PulseLaunch.aisleQuips.count), PulseLaunch.aisleQuips[0])
        XCTAssertTrue(PulseLaunch.shouldHoldSeatPickerUntilWarehouseReady())
        XCTAssertFalse(PulseLaunch.shouldInvalidateHubOnBackgroundFill())
        XCTAssertFalse(PulseLaunch.shouldRemountPageOnDestinationChange())
        XCTAssertFalse(PulseLaunch.shouldMountHubUnderRoleGate())
        XCTAssertFalse(PulseLaunch.shouldUsePagingScroll())
        XCTAssertFalse(PulseLaunch.shouldStampHubWhenExpandCacheFills())
        XCTAssertFalse(PulseLaunch.shouldStreamPickerOnDashboard())
        XCTAssertFalse(PulseLaunch.shouldSkipRoleGateOnRelaunch(role: .districtManager, filtersActive: true))
        XCTAssertFalse(PulseLaunch.shouldKeepNeighborPagesHydrated())
        XCTAssertFalse(PulseLaunch.shouldLoadSection(visible: .dashboard, section: .pph))
        XCTAssertTrue(PulseLaunch.shouldLoadSection(visible: .pph, section: .pph))
        XCTAssertTrue(PulseLaunch.shouldLoadSection(visible: .pickPath, section: .pickPathPicker))
        XCTAssertFalse(PulseLaunch.shouldRefreshPickersAfterFilter(dest: .dashboard))
        XCTAssertTrue(PulseLaunch.shouldRefreshPickersAfterFilter(dest: .pph))
        XCTAssertFalse(PulseLaunch.shouldRebuildPPHIndexDuringPaint(dest: .dashboard))
        XCTAssertTrue(PulseLaunch.shouldRebuildPPHIndexDuringPaint(dest: .pickerScorecard))
        XCTAssertTrue(PulseLaunch.shouldSkipWarehousePaintOnClear(restoredCompanyWide: true))
        XCTAssertFalse(PulseLaunch.shouldSkipWarehousePaintOnClear(restoredCompanyWide: false))
        XCTAssertFalse(PulseLaunch.shouldPaintWarehouseOnClear())
        XCTAssertFalse(PulseLaunch.grainTableMatchesCurrent(labels: ["East Region", "West Region"], grain: .store))
        XCTAssertFalse(PulseLaunch.grainTableMatchesCurrent(labels: ["East Region"], grain: .district))
        XCTAssertTrue(PulseLaunch.grainTableMatchesCurrent(labels: ["East Region", "South Region"], grain: .region))
        XCTAssertFalse(PulseLaunch.grainTableMatchesCurrent(labels: ["1490 | NorCal", "304 | NorCal"], grain: .region))
        XCTAssertTrue(PulseLaunch.grainTableMatchesCurrent(labels: ["03", "304"], grain: .store))
        XCTAssertFalse(PulseLaunch.flagsMatchFilter(flagStores: [1841, 77, 243], scopedStores: 20))
        XCTAssertTrue(PulseLaunch.flagsMatchFilter(flagStores: [18, 2], scopedStores: 20))
        XCTAssertEqual(PulseLaunch.warehousePaintPriority(light: true, hubReady: true), .utility)
        XCTAssertEqual(PulseLaunch.warehousePaintPriority(light: true, hubReady: false), .userInitiated)
        XCTAssertEqual(PulseLaunch.warehousePaintPriority(light: true, hubReady: true, firstSectionWave: true), .utility)
        XCTAssertEqual(PulseLaunch.warehousePaintPriority(light: true, hubReady: false, firstSectionWave: true), .userInitiated)
        XCTAssertEqual(PulseLaunch.warehousePaintPriority(light: true, hubReady: true, filterPaint: true), .userInitiated)
        XCTAssertEqual(PulseLaunch.warehouseReadPriority(hubInteractive: true), .utility)
        XCTAssertEqual(PulseLaunch.warehouseReadPriority(hubInteractive: false), .userInitiated)
        XCTAssertTrue(PulseLaunch.shouldKeepLiveCalloutsUntilFilterPaint())
        XCTAssertFalse(PulseLaunch.shouldStampFilterBeforePaint())
        XCTAssertFalse(PulseLaunch.shouldRefreshFilterOptionsOnEveryPaint())
        XCTAssertFalse(PulseLaunch.shouldPassRawRowsToPaint(needFacts: false, warehouseHasScoredStores: true))
        XCTAssertTrue(PulseLaunch.shouldPassRawRowsToPaint(needFacts: true, warehouseHasScoredStores: true))
        XCTAssertFalse(PulseLaunch.shouldPrepareWarehouseOnFilterPaint())
        XCTAssertFalse(PulseLaunch.shouldPublishWarehouseRowsDuringHydrate())
        XCTAssertFalse(PulseLaunch.shouldAdoptFactsDuringInteractivePaint())
        XCTAssertTrue(PulseLaunch.shouldIncludeFlagsOnFilterPaint())
        XCTAssertFalse(PulseLaunch.shouldPatchPPHOnPaint(hasFilteredPPH: true))
        XCTAssertTrue(PulseLaunch.shouldPatchPPHOnPaint(hasFilteredPPH: false))
        XCTAssertTrue(PulseLaunch.shouldPaintDashboardSectionsProgressively())
        XCTAssertEqual(PulseLaunch.dashboardFirstWave.first, .storeRoster)
        XCTAssertTrue(PulseLaunch.dashboardFirstWave.contains(.sales))
        XCTAssertTrue(PulseLaunch.dashboardFirstWave.contains(.lostRevenue))
        XCTAssertFalse(PulseLaunch.dashboardFirstWave.contains(.pickerScorecard))
        XCTAssertTrue(PulseLaunch.dashboardSecondWave.contains(.labor))
        XCTAssertFalse(PulseLaunch.dashboardSecondWave.contains(.pickerScorecard))
        let liveSales = SectionSummary(
            section: .sales,
            storeCount: 20,
            headline: 100,
            headlineLabel: "eComm sales",
            secondary: "",
            health: .good,
            watchCount: 1,
            riskCount: 0
        )
        let emptyLabor = SectionSummary(
            section: .labor,
            storeCount: 0,
            headline: nil,
            headlineLabel: "Labor",
            secondary: "",
            health: .none,
            watchCount: 0,
            riskCount: 0
        )
        let liveLabor = SectionSummary(
            section: .labor,
            storeCount: 20,
            headline: 0.99,
            headlineLabel: "Labor",
            secondary: "",
            health: .watch,
            watchCount: 5,
            riskCount: 0
        )
        let merged = PulseLaunch.mergeDashboardSummaries(
            painted: [liveSales, emptyLabor],
            live: [
                SectionSummary(
                    section: .sales,
                    storeCount: 1_800,
                    headline: 1,
                    headlineLabel: "eComm sales",
                    secondary: "",
                    health: .good,
                    watchCount: 0,
                    riskCount: 0
                ),
                liveLabor,
            ]
        )
        XCTAssertEqual(merged.first { $0.section == .sales }?.storeCount, 20)
        XCTAssertEqual(merged.first { $0.section == .labor }?.storeCount, 20)
        let paintedRows: [MetricSection: [MetricRow]] = [
            .sales: [MetricRow(section: .sales, division: "NorCal", operationsOM: "A", storeNumber: "1490", payload: ["sales_dollars": 10])],
        ]
        let liveRows: [MetricSection: [MetricRow]] = [
            .sales: [MetricRow(section: .sales, division: "NorCal", operationsOM: "A", storeNumber: "1", payload: ["sales_dollars": 1])],
            .labor: [MetricRow(section: .labor, division: "NorCal", operationsOM: "A", storeNumber: "1490", payload: ["target_vs_actual_pct": 1])],
        ]
        let mergedRows = PulseQuery.mergeFilteredRows(painted: paintedRows, live: liveRows)
        XCTAssertEqual(mergedRows[.sales]?.first?.storeNumber, "1490")
        XCTAssertEqual(mergedRows[.labor]?.count, 1)
        XCTAssertTrue(PulseLaunch.shouldPresentShareSheetWithoutBuildingHTML())
        XCTAssertEqual(PulseLaunch.mailBodyMaxBytes, 400_000)
        XCTAssertTrue(PulseLaunch.shouldSetHTMLMessageBody(utf8Count: 12_000))
        XCTAssertFalse(PulseLaunch.shouldSetHTMLMessageBody(utf8Count: 50))
        XCTAssertFalse(PulseLaunch.shouldSetHTMLMessageBody(utf8Count: 400_001))
        XCTAssertTrue(PulseLaunch.shouldAttachHTMLFile(utf8Count: 400_001))
        XCTAssertFalse(PulseLaunch.shouldAttachHTMLFile(utf8Count: 12_000))
        XCTAssertEqual(PulseMail.SharePage.from(destination: .dashboard), .dashboard)
        XCTAssertEqual(PulseMail.SharePage.from(destination: .lostRevenue), .lostRevenue)
        XCTAssertEqual(PulseMail.SharePage.from(destination: .pickerScorecard), .pickerScorecard)
        XCTAssertFalse(HubLayout.rasterizeSwipe)
        XCTAssertFalse(HubLayout.hydrateNeighbors)
        XCTAssertEqual(PulseLaunch.streamPickerSnappyAfterReady, true)
        XCTAssertEqual(PulseLaunch.pickerChunkPauseNanoseconds, 120_000_000)
        XCTAssertFalse(PulseLaunch.shouldRestartGrainPaint(alreadySettled: true, dest: .dashboard))
        let goalOnly = HeartbeatMath.DashboardGrainTableRow(
            label: "J3",
            storeCount: 0,
            values: ["—", "—", "3.71%", "—", "—", "—", "—", "—", "—"],
            health: .none
        )
        XCTAssertFalse(HeartbeatMath.grainRowsAreLive([goalOnly]))
        XCTAssertLessThan(HubLayout.calloutMinHeight(phone: false), 104)
        XCTAssertGreaterThanOrEqual(HubLayout.calloutMinHeight(phone: false), 90)
        XCTAssertLessThan(HubLayout.calloutValueSize(phone: false), 26)
        XCTAssertGreaterThanOrEqual(HubLayout.calloutValueSize(phone: false), 20)
        XCTAssertGreaterThanOrEqual(HubLayout.calloutMinWidth(phone: false), 148)
        let first = MetricRow(
            section: .pickerScorecard,
            division: "10",
            operationsOM: "A",
            storeNumber: "12",
            payload: ["pph": 40],
            textPayload: ["shopper_id": "A", "shopper_name": "A"]
        )
        let second = MetricRow(
            section: .pickerScorecard,
            division: "10",
            operationsOM: "A",
            storeNumber: "13",
            payload: ["pph": 22],
            textPayload: ["shopper_id": "B", "shopper_name": "B"]
        )
        let merged = PulseLaunch.mergePickerRows(existing: [first], incoming: [second])
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(PulseLaunch.mergePickerRows(existing: [first], incoming: [first]).count, 1)
    }

    func testPPHPickerIndexIsO1AliasLookupAndEmptyMissIsZero() {
        func shopper(_ id: String, store: String, pph: Double?) -> MetricRow {
            MetricRow(
                section: .pickerScorecard,
                division: "NorCal",
                operationsOM: "A",
                storeNumber: store,
                payload: pph.map { ["pph": $0] } ?? [:],
                textPayload: ["shopper_id": id, "shopper_name": id]
            )
        }
        let indexed = PulseLaunch.pphPickerIndex([
            shopper("A", store: "0304", pph: 40),
            shopper("B", store: "304", pph: 50),
            shopper("SKIP", store: "304", pph: nil),
            shopper("C", store: "108", pph: 80),
        ])
        XCTAssertEqual(PulseLaunch.pphPickerCount(store: "304", counts: indexed.counts), 2)
        XCTAssertEqual(PulseLaunch.pphPickerCount(store: "0304", counts: indexed.counts), 2)
        XCTAssertEqual(PulseLaunch.pphPickerCount(store: "00304", counts: indexed.counts), 2)
        XCTAssertEqual(PulseLaunch.pphPickerCount(store: "108", counts: indexed.counts), 1)
        XCTAssertEqual(PulseLaunch.pphPickerCount(store: "999", counts: indexed.counts), 0)
        XCTAssertEqual(PulseLaunch.pphPickerCount(store: "304", counts: [:]), 0)
        XCTAssertEqual(indexed.rows["304"]?.count, 2)
        XCTAssertEqual(indexed.rows["0304"]?.count, 2)
        XCTAssertEqual(
            PulseLaunch.pphPickerTotal(storeNumbers: ["0304", "108", "999"], counts: indexed.counts),
            3
        )
        XCTAssertEqual(PulseLaunch.pphPickerTotal(storeNumbers: ["304", "304"], counts: [:]), 0)

        var many: [MetricRow] = []
        many.reserveCapacity(2_000)
        for store in 1...200 {
            for picker in 1...10 {
                many.append(shopper("S\(store)-P\(picker)", store: String(format: "%04d", store), pph: 40))
            }
        }
        let packed = PulseLaunch.pphPickerIndex(many)
        XCTAssertEqual(PulseLaunch.pphPickerCount(store: "1", counts: packed.counts), 10)
        XCTAssertEqual(PulseLaunch.pphPickerCount(store: "0001", counts: packed.counts), 10)
        XCTAssertEqual(PulseLaunch.pphPickerCount(store: "200", counts: packed.counts), 10)
        XCTAssertEqual(PulseLaunch.pphPickerCount(store: "201", counts: packed.counts), 0)
        let storeKeys = (1...200).map { String($0) }
        XCTAssertEqual(PulseLaunch.pphPickerTotal(storeNumbers: storeKeys, counts: packed.counts), 2_000)
        XCTAssertEqual(PulseLaunch.pphPickerTotal(storeNumbers: storeKeys, counts: [:]), 0)
    }

    func testStoreScopeAndShopperSliceStayO1() {
        let allowed: Set<String> = ["304", "108"]
        XCTAssertTrue(HeartbeatMath.storeInAllowed("0304", allowed: allowed))
        XCTAssertTrue(HeartbeatMath.storeInAllowed("00304", allowed: allowed))
        XCTAssertTrue(HeartbeatMath.storeInAllowed("304", allowed: allowed))
        XCTAssertFalse(HeartbeatMath.storeInAllowed("999", allowed: allowed))
        XCTAssertTrue(PulseLaunch.storeInScope("0304", allowed: allowed))
        XCTAssertFalse(PulseLaunch.storeInScope("999", allowed: allowed))
        XCTAssertTrue(PulseLaunch.storeInScope("304", allowed: nil))

        let keep = MetricRow(
            section: .pickerScorecard,
            division: "NorCal",
            operationsOM: "A",
            storeNumber: "0304",
            payload: ["pph": 40],
            textPayload: ["shopper_id": "A", "shopper_name": "A"]
        )
        let drop = MetricRow(
            section: .pickerScorecard,
            division: "NorCal",
            operationsOM: "A",
            storeNumber: "999",
            payload: ["pph": 40],
            textPayload: ["shopper_id": "B", "shopper_name": "B"]
        )
        let sliced = PulseQuery.sliceShoppers([keep, drop], allowed: allowed)
        XCTAssertEqual(sliced.map(\.shopperName), ["A"])
        XCTAssertEqual(
            PulseCaches.scopedRows([keep, drop], allowed: allowed, roster: [:], filters: DashboardFilters()).map(\.shopperName),
            ["A"]
        )
        let paddedAllowed: Set<String> = ["0304"]
        XCTAssertTrue(HeartbeatMath.storeInAllowed("304", allowed: paddedAllowed))
        XCTAssertTrue(
            PulseCaches.rowMatchesFilter(
                keep,
                allowed: allowed,
                roster: [:],
                filters: DashboardFilters()
            )
        )
        XCTAssertFalse(
            PulseCaches.rowMatchesFilter(
                drop,
                allowed: allowed,
                roster: ["999": .init(division: "NorCal", district: "N1", om: "A", name: nil)],
                filters: DashboardFilters()
            )
        )
        let prepared = PulseQuery.prepareWarehouse(
            warehouse: [:],
            roster: ["304": .init(division: "NorCal", district: "N1", om: "A", name: nil)],
            filters: DashboardFilters(),
            rawRows: [],
            pickers: [keep],
            bundledFacts: [],
            scopedLost: nil
        )
        XCTAssertEqual(prepared[.pph]?.first?.storeNumber, "304")
        XCTAssertEqual(HeartbeatMath.pphNumber(prepared[.pph]?.first ?? keep) ?? 0, 40, accuracy: 0.01)
    }

    func testMissingPackMessageIsActionable() {
        let message = PulseLaunch.missingPackMessage()
        XCTAssertTrue(message.contains("Try again"))
        XCTAssertFalse(message.isEmpty)
    }

    func testWhoIsLookingSeatsIncludeStoreViewAfterOM() {
        XCTAssertEqual(
            HeartbeatRole.allCases.map(\.rawValue),
            ["backstage", "evp", "director", "districtManager", "om", "store"]
        )
        XCTAssertEqual(HeartbeatRole.store.title, "Store View")
        XCTAssertEqual(HeartbeatRole.om.title, "Operations Manager")
        XCTAssertEqual(HeartbeatRole.store.dashboardGrain, .store)
        XCTAssertEqual(HeartbeatRole.store.pickNoun, "store")
        XCTAssertTrue(HeartbeatRole.evp.detail.localizedCaseInsensitiveContains("many"))
        XCTAssertTrue(HeartbeatRole.store.detail.localizedCaseInsensitiveContains("store"))
        var filters = DashboardFilters()
        filters.region = "East Region\nWest Region"
        filters.division = "Jewel Osco\nNorCal"
        filters.district = "Chicago\nDenver"
        filters.om = "Pat Lee\nSam Ray"
        filters.store = "304\n412"
        filters.sanitize()
        XCTAssertEqual(filters.regions, ["East Region", "West Region"])
        XCTAssertEqual(Set(filters.divisions), Set(["Jewel Osco", "NorCal"]))
        XCTAssertEqual(Set(filters.districts), Set(["Chicago", "Denver"]))
        XCTAssertEqual(Set(filters.oms), Set(["Pat Lee", "Sam Ray"]))
        XCTAssertEqual(filters.stores, ["304", "412"])
        XCTAssertTrue(filters.includesStore("304"))
        XCTAssertTrue(filters.includesStore("412"))
        XCTAssertFalse(filters.includesStore("999"))
        XCTAssertTrue(filters.includesDivision("Jewel Osco"))
        XCTAssertTrue(filters.includesDivision("NorCal"))
    }

    func testShareEmailMatchesOnScreenTablesAndStaysReadable() {
        let sales = MetricRow(
            section: .sales,
            division: "Jewel Osco",
            operationsOM: "A",
            storeNumber: "304",
            payload: [
                "sales_dollars": 1_234_567.89,
                "sales_yoy_pct": -2.4,
                "sales_orders": 4_200,
                "sales_orders_yoy_pct": 1.1,
                "sales_aos": 29.4,
                "sales_aiv": 4.2,
                "sales_ipt": 7.1,
                "sales_items": 29_820,
            ],
            textPayload: ["district": "Chicago"]
        )
        let lost = MetricRow(
            section: .lostRevenue,
            division: "Jewel Osco",
            operationsOM: "A",
            storeNumber: "304",
            payload: [
                "lost_revenue": 88_210.5,
                "lost_revenue_pct": 4.2,
                "ecomm_sales": 2_100_000,
                "post_sub_oos_foregone": 12_000,
                "refund_lost": 3_400,
                "missed_sales": 1_100,
                "cancelled_lost": 800,
                "kill_switch_lost": 250,
            ],
            textPayload: ["district": "Chicago"]
        )
        let missing = MetricRow(
            section: .missingItems,
            division: "Jewel Osco",
            operationsOM: "A",
            storeNumber: "304",
            payload: ["mi_pct": 6.8, "mi_grocery": 8.1, "mi_produce": 5.2],
            textPayload: ["district": "Chicago"]
        )
        let picker = MetricRow(
            section: .pickerScorecard,
            division: "Jewel Osco",
            operationsOM: "A",
            storeNumber: "304",
            payload: [
                "pph": 62,
                "pick_hours": 18.5,
                "orders": 40,
                "presub_pct": 8,
                "ott_pct": 90,
                "oth5_pct": 80,
                "coe_pct": 12,
            ],
            textPayload: ["shopper_name": "Alex", "district": "Chicago"]
        )
        let items = MetricRow(
            section: .preSubOOSItem,
            division: "Jewel Osco",
            operationsOM: "A",
            storeNumber: "304",
            payload: ["presub_pct": 12, "presub_count": 18, "presub_dollars": 96, "oos_pct": 4, "oos_dollars": 22],
            textPayload: ["bpn": "123456", "district": "Chicago"]
        )
        let snap = PulseMail.Snapshot(
            filterSummary: "Midwest · Jewel Osco",
            grain: "region",
            summaries: [
                SectionSummary(
                    section: .sales,
                    storeCount: 1,
                    headline: 1_234_567.89,
                    headlineLabel: "eComm sales",
                    secondary: "",
                    health: .watch,
                    watchCount: 1,
                    riskCount: 0
                ),
                SectionSummary(
                    section: .lostRevenue,
                    storeCount: 1,
                    headline: 88_210.5,
                    headlineLabel: "Total Opportunity",
                    secondary: "",
                    health: .watch,
                    watchCount: 1,
                    riskCount: 0
                ),
            ],
            rows: [
                .sales: [sales],
                .lostRevenue: [lost],
                .missingItems: [missing],
                .pickerScorecard: [picker],
                .preSubOOSItem: [items],
                .preSubOOS: [missing],
            ],
            pickerCounts: ["304": 3],
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let packet = PulseMail.make(
            snap,
            pages: [.dashboard, .sales, .lostRevenue, .missingItems, .preSubOOS, .pickerScorecard]
        )
        XCTAssertTrue(packet.subject.contains("Midwest · Jewel Osco"))
        XCTAssertTrue(packet.html.contains("Midwest · Jewel Osco"))
        XCTAssertTrue(packet.html.contains("Same layout and columns as the in-app page"))
        XCTAssertTrue(packet.html.contains("font-size:16px"))
        XCTAssertTrue(packet.html.contains("font-size:15px"))
        XCTAssertFalse(packet.html.contains("font-size:9px"))
        XCTAssertFalse(packet.html.contains("font-size:11px"))
        for header in HeartbeatMath.dashboardTableHeaders(.lostRevenue) {
            XCTAssertTrue(packet.html.contains(header), header)
        }
        for header in ["Sales $", "YoY %", "Orders", "Ord YoY", "AOS", "AIV", "Items/Txn", "Items"] {
            XCTAssertTrue(packet.html.contains(header), header)
        }
        XCTAssertTrue(packet.html.contains("1,234,567.89"), packet.html)
        XCTAssertTrue(packet.html.contains("301 Grocery"))
        XCTAssertTrue(packet.html.contains("329 Produce"))
        XCTAssertTrue(packet.html.contains("Cancel"))
        XCTAssertTrue(packet.html.contains("Kill"))
        for header in ["Hours", "PPH", "Orders", "Presub", "OTT", "OTH5", "COE"] {
            XCTAssertTrue(packet.html.contains(header), header)
        }
        XCTAssertTrue(packet.html.contains("Pre-Sub OOS Items"))
        XCTAssertTrue(packet.html.contains("123456"))
        XCTAssertTrue(packet.html.contains("<th"))
        XCTAssertTrue(packet.html.contains("class=\"data\""))
        XCTAssertTrue(packet.html.contains("class=\"pill\""))
        XCTAssertTrue(packet.html.contains("WATCH") || packet.html.contains("HEALTHY") || packet.html.contains("AT RISK") || packet.html.contains("NO DATA"))
        XCTAssertTrue(packet.plain.contains("Sales $"))
        XCTAssertTrue(packet.plain.contains("Lost $"))
        XCTAssertEqual(PulseMail.pageRows([sales], section: .sales).count, 1)
    }

    func testCaliforniaRegionResolvesFromTitleAndRoster() {
        XCTAssertEqual(MarketRegion.named("California"), .california)
        XCTAssertEqual(MarketRegion.named("California Region"), .california)
        XCTAssertEqual(MarketRegion.containing("California"), .california)
        XCTAssertEqual(MarketRegion.containing("NorCal"), .california)
        XCTAssertEqual(MarketRegion.containing("SoCal"), .california)
        XCTAssertEqual(RollupMarketFill.bucketKey(
            MetricRow(section: .scheduleQuality, division: "California", operationsOM: "", storeNumber: "304", payload: [:]),
            grain: .region
        ), "California Region")
        let stamped = HeartbeatMath.stampRoster(
            MetricRow(section: .missingItems, division: "California", operationsOM: "", storeNumber: "304", payload: ["mi_pct": 4]),
            roster: ["304": .init(division: "NorCal", district: "03", om: "Jino", name: nil)]
        )
        XCTAssertEqual(stamped.division, "NorCal")
        XCTAssertEqual(RollupMarketFill.missingRegions(present: ["East Region", "South Region", "West Region"]), ["California Region"])
        var california = DashboardFilters()
        california.region = "California Region"
        XCTAssertTrue(california.includesDivision("NorCal"))
        XCTAssertTrue(california.includesDivision("SoCal"))
        XCTAssertTrue(california.includesDivision("California"))
        XCTAssertTrue(california.includesDivision("California Region"))
        XCTAssertFalse(california.includesDivision("Jewel Osco"))
        XCTAssertTrue(MarketRegion.matchesDivision("California", "NorCal"))
        XCTAssertTrue(MarketRegion.matchesDivision("NorCal", "California"))
        XCTAssertFalse(MarketRegion.matchesDivision("California", "Jewel Osco"))
        XCTAssertNil(MarketRegion.containing(""))
        XCTAssertNil(MarketRegion.containing("J3"))
        XCTAssertFalse(MarketRegion.matchesDivision("", "NorCal"))
        XCTAssertFalse(MarketRegion.matchesDivision("J3CHICAGO", "NorCal"))
        XCTAssertFalse(california.includesDivision(""))
        XCTAssertFalse(california.includesDivision("J3"))
        let schedule = [
            MetricRow(section: .scheduleQuality, division: "California", operationsOM: "", storeNumber: "304", payload: ["schedule_efficiency_pct": 92], textPayload: ["district": "J3CHICAGO"]),
            MetricRow(section: .scheduleQuality, division: "Jewel Osco", operationsOM: "", storeNumber: "100", payload: ["schedule_efficiency_pct": 80]),
        ]
        let kept = HeartbeatMath.filtered(schedule, filters: california)
        XCTAssertTrue(kept.contains { $0.storeNumber == "304" })
        XCTAssertFalse(kept.contains { $0.storeNumber == "100" })
    }

    func testLostRevenueGoalPctUsesDollarsWhenPctMissing() {
        let row = MetricRow(
            section: .lostRevenue,
            division: "NorCal",
            operationsOM: "A",
            storeNumber: "304",
            payload: ["ecomm_sales": 10_000, "lost_revenue": 400, "lost_revenue_goal": 250],
            textPayload: ["lost_grain": "store"]
        )
        XCTAssertEqual(HeartbeatMath.lostRevenueGoalPct(row) ?? 0, 2.5, accuracy: 0.01)
        let withPct = MetricRow(
            section: .lostRevenue,
            division: "NorCal",
            operationsOM: "A",
            storeNumber: "304",
            payload: ["lost_revenue_goal_pct": 3.1, "ecomm_sales": 10_000, "lost_revenue_goal": 250]
        )
        XCTAssertEqual(HeartbeatMath.lostRevenueGoalPct(withPct) ?? 0, 3.1, accuracy: 0.01)
        let alias = MetricRow(
            section: .lostRevenue,
            division: "NorCal",
            operationsOM: "A",
            storeNumber: "304",
            payload: ["goal_pct": 2.8, "ecomm_sales": 10_000]
        )
        XCTAssertEqual(HeartbeatMath.lostRevenueGoalPct(alias) ?? 0, 2.8, accuracy: 0.01)
    }

    func testLostRevenueGrainInheritsFY2026GoalWhenStoresHaveNone() {
        let market = MetricRow(
            section: .lostRevenue,
            division: "",
            operationsOM: "",
            storeNumber: "",
            payload: ["lost_revenue_goal_pct": 3.71, "ecomm_sales": 46_000_000],
            textPayload: ["lost_grain": "market"]
        )
        let store = MetricRow(
            section: .lostRevenue,
            division: "NorCal",
            operationsOM: "A",
            storeNumber: "304",
            payload: ["lost_revenue": 400, "lost_revenue_pct": 4.0, "ecomm_sales": 10_000]
        )
        XCTAssertNil(HeartbeatMath.lostRevenueGoalPct(store))
        XCTAssertEqual(HeartbeatMath.lostRevenueGoalPct(market) ?? 0, 3.71, accuracy: 0.01)
        XCTAssertEqual(
            HeartbeatMath.lostRevenueInheritedGoalPct(rows: [store], fallback: HeartbeatMath.lostRevenueGoalPct(market)) ?? 0,
            3.71,
            accuracy: 0.01
        )
        XCTAssertTrue(HeartbeatMath.dashboardTableHeaders(.lostRevenue).contains("Goal %"))
        let table = HeartbeatMath.dashboardGrainTable(
            section: .lostRevenue,
            rows: [store],
            grain: .region,
            order: ["California Region"],
            goalFallback: 3.71
        )
        XCTAssertEqual(table.first?.label, "California Region")
        XCTAssertTrue(table.first?.values.contains("3.71%") == true, "\(table.first?.values ?? [])")
        XCTAssertEqual(
            HeartbeatMath.lostRevenueGoalFallback([market, store]) ?? 0,
            3.71,
            accuracy: 0.01
        )
        let dashed = HeartbeatMath.DashboardGrainTableRow(
            label: "J3",
            storeCount: 4,
            values: ["$1,200", "4.20%", "—", "$28,000", "—", "—", "—", "—", "—"],
            health: .watch
        )
        XCTAssertTrue(HeartbeatMath.grainTableNeedsGoalFill([dashed]))
        let patched = HeartbeatMath.fillingLostRevenueGoal([dashed], goal: 3.71)
        XCTAssertFalse(HeartbeatMath.grainTableNeedsGoalFill(patched))
        XCTAssertEqual(patched.first?.values[2], "3.71%")
        let fromPacks = HeartbeatMath.dashboardGrainRowsFromPacks(
            [DashScopePack(line: DashScopeLine(label: "California Region", value: "4.24%", health: .watch, count: 604), flags: [])],
            section: .lostRevenue
        )
        XCTAssertEqual(fromPacks.first?.label, "California Region")
        XCTAssertEqual(fromPacks.first?.values.first, "4.24%")
        let emptyGoal = HeartbeatMath.dashboardTableValues(.lostRevenue, rows: [], goalFallback: 3.71)
        XCTAssertTrue(emptyGoal.values.contains("3.71%"), "\(emptyGoal.values)")
        let withGoal = HeartbeatMath.dashboardGrainRowsFromPacks(
            [DashScopePack(line: DashScopeLine(label: "California Region", value: "4.24%", health: .watch, count: 604), flags: [])],
            section: .lostRevenue,
            goalFallback: 3.71
        )
        XCTAssertTrue(withGoal.first?.values.contains("3.71%") == true, "\(withGoal.first?.values ?? [])")
    }

    func testLostRevenueDistrictExpandMatchesPackLabelsAndFillsGoal() {
        let store = MetricRow(
            section: .lostRevenue,
            division: "Jewel Osco",
            operationsOM: "A",
            storeNumber: "308",
            payload: [
                "lost_revenue": 1_200,
                "lost_revenue_pct": 4.2,
                "ecomm_sales": 28_000,
                "post_sub_oos_foregone": 100,
                "refund_lost": 50,
                "missed_sales": 25,
                "cancelled_lost": 10,
                "kill_switch_lost": 5,
            ],
            textPayload: ["lost_grain": "store", "district": "J3CHICAGO"]
        )
        let table = HeartbeatMath.dashboardGrainTableFilled(
            section: .lostRevenue,
            rows: [store],
            grain: .district,
            order: ["J3CHICAGO", "308 - J3 CHICAGO"],
            goalFallback: 3.71
        )
        XCTAssertEqual(table.count, 1, "blank pack labels must not hide the live district")
        XCTAssertEqual(table.first?.label, "J3")
        XCTAssertGreaterThan(table.first?.storeCount ?? 0, 0)
        XCTAssertTrue(table.first?.values[0].contains("1,200") == true, "\(table.first?.values ?? [])")
        XCTAssertTrue(table.first?.values.contains("3.71%") == true, "\(table.first?.values ?? [])")
        XCTAssertTrue(HeartbeatMath.grainRowsAreLive(table))
        let market = MetricRow(
            section: .lostRevenue,
            division: "",
            operationsOM: "",
            storeNumber: "",
            payload: ["lost_revenue_goal_pct": 3.71, "ecomm_sales": 46_000_000],
            textPayload: ["lost_grain": "market"]
        )
        let roster: [String: HeartbeatMath.StoreIdentity] = [
            "308": .init(division: "Jewel Osco", district: "J3CHICAGO", om: "A", name: nil)
        ]
        for grain in [DashScopeGrain.region, .district, .store] {
            let painted = PulseQuery.paint(
                warehouse: [.lostRevenue: [market, store]],
                roster: roster,
                filters: DashboardFilters(),
                grain: grain,
                uploads: [],
                hidePicker: true,
                light: false
            )
            let rows = painted.tables[.lostRevenue] ?? []
            XCTAssertFalse(rows.isEmpty, "\(grain) expand empty")
            XCTAssertFalse(HeartbeatMath.grainTableNeedsGoalFill(rows), "\(grain) Goal % \(rows.map(\.values))")
            for row in rows where row.storeCount > 0 || row.values.contains(where: { $0 != "—" }) {
                XCTAssertNotEqual(row.values[2], "—", "\(grain) \(row.label) \(row.values)")
                XCTAssertTrue(row.values.contains("3.71%"), "\(grain) \(row.label) \(row.values)")
            }
        }
        let dynacap = HeartbeatMath.dashboardGrainTableFilled(
            section: .dynacap,
            rows: [
                MetricRow(
                    section: .dynacap,
                    division: "Jewel Osco",
                    operationsOM: "A",
                    storeNumber: "308",
                    payload: ["dynacap_rate": 74.1, "utilization_pct": 81],
                    textPayload: ["district": "J3CHICAGO"]
                )
            ],
            grain: .district,
            order: ["J3 CHICAGO"],
            goalFallback: nil
        )
        XCTAssertEqual(dynacap.first?.label, "J3")
        XCTAssertEqual(dynacap.first?.values.first, "74.1")
        XCTAssertTrue(PulseQuery.isStoreFact(
            MetricRow(
                section: .dynacap,
                division: "Jewel Osco",
                operationsOM: "",
                storeNumber: "",
                payload: ["dynacap_rate": 74.1],
                textPayload: ["district": "J3"]
            )
        ))
    }

    func testCompanyWideLostRevenueExpandPaintsAllFourRegionsEvenWhenPackIsEastOnly() throws {
        let east = MetricRow(
            section: .lostRevenue,
            division: "Jewel Osco",
            operationsOM: "A",
            storeNumber: "308",
            payload: [
                "lost_revenue": 247_025.38,
                "lost_revenue_pct": 8.24,
                "ecomm_sales": 2_997_175.77,
                "post_sub_oos_foregone": 87_241.71,
                "refund_lost": 3_926,
                "missed_sales": 18_627,
                "cancelled_lost": 4_640,
                "kill_switch_lost": 2_024.78,
            ],
            textPayload: ["lost_grain": "store", "district": "J3"]
        )
        let order = MarketRegion.allCases.map(\.rawValue)
        let placeholders = HeartbeatMath.dashboardGrainTable(
            section: .lostRevenue,
            rows: [east],
            grain: .region,
            order: order,
            goalFallback: 3.89
        )
        XCTAssertEqual(placeholders.map(\.label), order)
        XCTAssertEqual(placeholders.first?.label, "East Region")
        XCTAssertGreaterThan(placeholders.first?.storeCount ?? 0, 0)
        XCTAssertEqual(placeholders.filter { $0.storeCount > 0 }.count, 1)
        for row in placeholders {
            XCTAssertTrue(row.values.contains("3.89%"), "\(row.label) \(row.values)")
        }

        let tests = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let url = tests.deletingLastPathComponent().appendingPathComponent("FulfillmentHeartbeat/facts.json")
        let file = try JSONDecoder().decode(PulseFactsFile.self, from: Data(contentsOf: url))
        let facts = PulseFacts.metricRows(from: file)
        let eastPack = (1...300).map { n in
            MetricRow(
                section: .lostRevenue,
                division: "Jewel Osco",
                operationsOM: "A",
                storeNumber: String(n),
                payload: ["lost_revenue": 10, "ecomm_sales": 1_000, "lost_revenue_pct": 1],
                textPayload: ["lost_grain": "store"]
            )
        }
        XCTAssertNil(PulseQuery.fillIfThin(existing: eastPack, incoming: facts.filter { $0.section == .lostRevenue }))
        let merged = PulseQuery.fillMissingRegions(
            existing: eastPack,
            facts: facts,
            section: .lostRevenue
        )
        XCTAssertGreaterThan(merged.count, eastPack.count)
        let filled = HeartbeatMath.dashboardGrainTableFilled(
            section: .lostRevenue,
            rows: merged,
            grain: .region,
            order: order,
            goalFallback: 3.89
        )
        XCTAssertEqual(filled.map(\.label), order)
        let goalIndex = HeartbeatMath.dashboardTableHeaders(.lostRevenue).firstIndex(of: "Goal %")
        XCTAssertEqual(goalIndex, 2)
        for region in MarketRegion.allCases {
            let row = filled.first { $0.label == region.rawValue }
            XCTAssertGreaterThan(row?.storeCount ?? 0, 0, region.rawValue)
            XCTAssertNotEqual(row?.values.first, "—", region.rawValue)
            XCTAssertNotEqual(row?.values[2], "—", "\(region.rawValue) missing Goal % \(row?.values ?? [])")
        }
        XCTAssertEqual(MarketRegion.resolved(division: "Jewel Osco", district: "J3"), .east)
        XCTAssertEqual(MarketRegion.resolved(division: "NorCal", district: ""), .california)
        XCTAssertNil(MarketRegion.resolved(division: "", district: "J3"))
    }

    func testPrepEvenColumnsMatchPickPathSpread() {
        let headers = HeartbeatMath.dashboardTableHeaders(.prepNotReady)
        XCTAssertEqual(headers, ["PNR %", "Goal", "Watch"])
        let prep = HubLayout.evenValueWidth(
            available: 1_400,
            phone: false,
            columns: headers.count,
            showCount: true,
            district: false,
            valueMin: HubLayout.dashboardValueMin(phone: false, columns: headers.count)
        )
        let path = HubLayout.evenValueWidth(
            available: 1_400,
            phone: false,
            columns: 3,
            showCount: true,
            district: false,
            valueMin: HubLayout.dashboardValueMin(phone: false, columns: 3)
        )
        XCTAssertEqual(prep, path, accuracy: 0.5)
        XCTAssertGreaterThan(prep, HubLayout.readableValueMin(phone: false))
        let dumped = HubLayout.evenValueWidth(
            available: 1_400,
            phone: false,
            columns: 1,
            showCount: true,
            district: false,
            valueMin: HubLayout.dashboardValueMin(phone: false, columns: 1)
        )
        XCTAssertGreaterThan(dumped, prep + 80, "a single PNR column dumps leftover into a giant gap")
        let values = HeartbeatMath.dashboardTableValues(
            .prepNotReady,
            rows: [
                MetricRow(
                    section: .prepNotReady,
                    division: "Jewel Osco",
                    operationsOM: "A",
                    storeNumber: "308",
                    payload: ["pnr_rate_pct": 3.27]
                )
            ]
        )
        XCTAssertEqual(values.values.count, 3)
        XCTAssertEqual(values.values[0], "3.27%")
        XCTAssertEqual(values.values[1], "1.9%")
        XCTAssertEqual(values.values[2], "1.9–2.5%")
    }

    func testTableLabelWidthFitsRegionNamesAndEvenValues() {
        XCTAssertGreaterThanOrEqual(HubLayout.readableLabelWidth(phone: false), 220)
        XCTAssertGreaterThanOrEqual(HubLayout.pageLabelWidth, 156)
        let wide = HubLayout.evenValueWidth(available: 1400, phone: false, columns: 6, showCount: true)
        let narrow = HubLayout.evenValueWidth(available: 900, phone: false, columns: 6, showCount: true)
        XCTAssertGreaterThan(wide, narrow)
        XCTAssertEqual(
            HubLayout.evenValueWidth(available: 400, phone: true, columns: 8, showCount: true),
            HubLayout.readableValueMin(phone: true)
        )
    }

    func testShareEmailKeepsEveryFilteredStoreRow() {
        let rows = (1...200).map { n in
            MetricRow(
                section: .pickPath,
                division: "NorCal",
                operationsOM: "A",
                storeNumber: String(n),
                payload: ["compliance_pct": 90]
            )
        }
        let kept = PulseMail.pageRows(rows, section: .pickPath)
        XCTAssertEqual(kept.count, 200)
        XCTAssertEqual(kept.first?.storeNumber, "1")
        XCTAssertEqual(kept.last?.storeNumber, "200")
        let shoppers = (1...200).map { n in
            MetricRow(
                section: .pickerScorecard,
                division: "NorCal",
                operationsOM: "A",
                storeNumber: "304",
                payload: ["pph": 80],
                textPayload: ["shopper_name": "Shopper \(n)"]
            )
        }
        XCTAssertEqual(PulseMail.pageRows(shoppers, section: .pickerScorecard).count, 200)
    }

    func testShareEmailIncludesFullFilteredPage() {
        let rows = (1...120).map { n in
            MetricRow(
                section: .pickPath,
                division: "NorCal",
                operationsOM: "A",
                storeNumber: String(n),
                payload: ["compliance_pct": 90]
            )
        }
        let snap = PulseMail.Snapshot(
            filterSummary: "Company",
            grain: "store",
            summaries: [],
            rows: [.pickPath: rows],
            pickerCounts: [:],
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            rowTotals: [.pickPath: 120]
        )
        let packet = PulseMail.make(snap, pages: [.pickPath])
        XCTAssertTrue(packet.html.contains("120 stores"), packet.html)
        XCTAssertTrue(packet.html.contains("Pick Path"))
        XCTAssertTrue(packet.html.contains("120 |"), packet.html)
        XCTAssertFalse(packet.html.contains("80 of 120"), packet.html)
        XCTAssertFalse(packet.brief.isEmpty)
        let streamed = PulseMail.make(snap, pages: [.pickPath], persistHTML: false)
        XCTAssertTrue(streamed.html.isEmpty)
        XCTAssertFalse(streamed.brief.isEmpty)
        let item = PulseMail.shareActivityItem(streamed)
        XCTAssertFalse(item is String && (item as? String)?.contains("<html") == true)
        let fileHTML = (try? String(contentsOf: streamed.htmlFile!, encoding: .utf8)) ?? ""
        XCTAssertTrue(fileHTML.contains("120 |"), fileHTML)
        XCTAssertTrue(fileHTML.contains("120 stores"), fileHTML)
        let grains = (1...50).map { n in
            HeartbeatMath.DashboardGrainTableRow(
                label: "Store \(n)",
                storeCount: 1,
                values: ["90%"],
                health: .good
            )
        }
        let grainSnap = PulseMail.Snapshot(
            filterSummary: "California Region",
            grain: "store",
            summaries: [
                SectionSummary(
                    section: .pickPath,
                    storeCount: 50,
                    headline: 90,
                    headlineLabel: "Pick path",
                    secondary: "",
                    health: .good,
                    watchCount: 0,
                    riskCount: 0
                )
            ],
            rows: [.pickPath: Array(rows.prefix(50))],
            pickerCounts: [:],
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            grainTables: [.pickPath: grains]
        )
        let grainPacket = PulseMail.make(grainSnap, pages: [.dashboard])
        XCTAssertTrue(grainPacket.html.contains("Store 1"), grainPacket.html)
        XCTAssertTrue(grainPacket.html.contains("Store 40"), grainPacket.html)
        XCTAssertFalse(grainPacket.html.contains("Store 50"), grainPacket.html)
        XCTAssertTrue(grainPacket.html.contains("bgcolor=\"#003DA5\""), grainPacket.html)
    }

    func testUsablePackFileRejectsTinyStubs() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("hb-stub-\(UUID().uuidString).sqlite")
        FileManager.default.createFile(atPath: url.path, contents: Data(repeating: 1, count: 1_200), attributes: nil)
        XCTAssertFalse(PulseSQLite.isUsableFile(at: url))
        XCTAssertFalse(PulseSQLite.exists(at: url))
        try? FileManager.default.removeItem(at: url)
        XCTAssertFalse(PulseSQLite.exists(at: url))
    }

    func testMissingItemsDeptMatrixScrollsInsteadOfClipping() {
        let cramped = MILayout.metrics(depts: MissingItemDept.allCases.count, showCount: true, available: 900)
        XCTAssertEqual(cramped.cellW, MILayout.minCell, accuracy: 0.5)
        XCTAssertGreaterThan(cramped.tableWidth, 1600)
        XCTAssertGreaterThan(cramped.tableWidth, 900)
        let wide = MILayout.metrics(depts: MissingItemDept.allCases.count, showCount: true, available: 2_400)
        XCTAssertGreaterThanOrEqual(wide.cellW, MILayout.minCell)
        XCTAssertEqual(wide.tableWidth, 2_400, accuracy: 1)
    }

    func testShareEmailStreamsFileAndNeverVendsHTMLString() {
        var rows = (1...40).map { n in
            MetricRow(
                section: .scheduleQuality,
                division: "NorCal",
                operationsOM: "A",
                storeNumber: String(n),
                payload: ["schedule_efficiency_pct": 91],
                textPayload: ["district": "J3CHICAGO"]
            )
        }
        rows.append(
            MetricRow(
                section: .scheduleQuality,
                division: "California",
                operationsOM: "",
                storeNumber: "",
                payload: ["schedule_efficiency_pct": 88],
                textPayload: ["district": "J3CHICAGO"]
            )
        )
        let grain = HeartbeatMath.DashboardGrainTableRow(
            label: "J3CHICAGO",
            storeCount: 4,
            values: ["91%"],
            health: .good
        )
        let snap = PulseMail.Snapshot(
            filterSummary: "California Region",
            grain: "division",
            summaries: [],
            rows: [.scheduleQuality: rows],
            pickerCounts: [:],
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            grainTables: [.scheduleQuality: [grain]]
        )
        let packet = PulseMail.make(snap, pages: [.dashboard, .scheduleQuality], persistHTML: false)
        XCTAssertTrue(packet.html.isEmpty, "Share path must not keep the HTML string in memory")
        XCTAssertFalse(packet.brief.isEmpty)
        let item = PulseMail.shareActivityItem(packet)
        XCTAssertFalse(item is String && (item as? String)?.contains("<html") == true)
        if let url = item as? URL {
            XCTAssertEqual(url.pathExtension, "html")
            let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            XCTAssertTrue(body.contains("Schedule Quality") || body.contains("J3"), body)
            XCTAssertFalse(body.contains("J3CHICAGO"), body)
        } else {
            XCTAssertNotNil(packet.htmlFile)
            let body = (try? String(contentsOf: packet.htmlFile!, encoding: .utf8)) ?? ""
            XCTAssertFalse(body.isEmpty)
            XCTAssertFalse(body.contains("J3CHICAGO"), body)
        }
        let kept = PulseMail.make(snap, pages: [.scheduleQuality])
        XCTAssertTrue(kept.html.contains("<td class=\"name\">J3</td>") || kept.html.contains(">J3<") || kept.html.contains("J3"), kept.html)
        XCTAssertTrue(kept.html.contains("88.00%"), kept.html)
        XCTAssertFalse(kept.html.contains("J3CHICAGO"), kept.html)
    }

    func testCaliforniaScheduleQualityKeepsRegionBook() {
        XCTAssertTrue(PulseQuery.isStoreFact(
            MetricRow(
                section: .scheduleQuality,
                division: "California",
                operationsOM: "",
                storeNumber: "",
                payload: ["schedule_efficiency_pct": 88]
            )
        ))
        let caStore = MetricRow(
            section: .scheduleQuality,
            division: "NorCal",
            operationsOM: "A",
            storeNumber: "304",
            payload: ["schedule_efficiency_pct": 91],
            textPayload: ["district": "03"]
        )
        let caTotal = MetricRow(
            section: .scheduleQuality,
            division: "California",
            operationsOM: "",
            storeNumber: "",
            payload: ["schedule_efficiency_pct": 88],
            textPayload: ["district": "J3CHICAGO"]
        )
        let caUnmatched = MetricRow(
            section: .scheduleQuality,
            division: "SoCal",
            operationsOM: "B",
            storeNumber: "9999",
            payload: ["schedule_efficiency_pct": 85]
        )
        let jewel = MetricRow(
            section: .scheduleQuality,
            division: "Jewel Osco",
            operationsOM: "C",
            storeNumber: "100",
            payload: ["schedule_efficiency_pct": 80]
        )
        let roster: [String: HeartbeatMath.StoreIdentity] = [
            "304": .init(division: "NorCal", district: "03", om: "A", name: nil),
            "100": .init(division: "Jewel Osco", district: "J3", om: "C", name: nil),
        ]
        var california = DashboardFilters()
        california.region = "California Region"
        let allowed = PulseCaches.allowedStores(roster: roster, filters: california)
        XCTAssertEqual(allowed, ["304"])
        let sliced = PulseQuery.slice(
            [caStore, caTotal, caUnmatched, jewel],
            allowed: allowed,
            filters: california,
            roster: roster
        )
        XCTAssertTrue(sliced.contains { $0.storeNumber == "304" })
        XCTAssertTrue(sliced.contains { $0.division == "California" && $0.storeNumber.isEmpty })
        XCTAssertTrue(sliced.contains { $0.storeNumber == "9999" })
        XCTAssertFalse(sliced.contains { $0.storeNumber == "100" })
        let painted = PulseQuery.paint(
            warehouse: [.scheduleQuality: [caStore, caTotal, caUnmatched, jewel]],
            roster: roster,
            filters: california,
            grain: .division,
            uploads: [],
            hidePicker: true,
            light: false
        )
        let rows = painted.filtered[.scheduleQuality] ?? []
        XCTAssertGreaterThanOrEqual(rows.filter { $0.number("schedule_efficiency_pct") != nil }.count, 2)
        XCTAssertFalse(rows.contains { $0.storeNumber == "100" })
        XCTAssertEqual(HeartbeatMath.displayGrainLabel("J3CHICAGO"), "J3")
        XCTAssertEqual(
            DashboardFilters.display("J3CHICAGO", empty: "All districts", prefix: "District "),
            "District J3"
        )
    }

    func testCompanyWideScheduleQualityKeepsCaliforniaRegion() {
        let east = MetricRow(
            section: .scheduleQuality,
            division: "Jewel Osco",
            operationsOM: "C",
            storeNumber: "100",
            payload: ["schedule_efficiency_pct": 80, "under_schedule_pct": 2, "over_schedule_pct": 1],
            textPayload: ["district": "J3"]
        )
        let caTotal = MetricRow(
            section: .scheduleQuality,
            division: "California",
            operationsOM: "",
            storeNumber: "",
            payload: ["schedule_efficiency_pct": 88, "under_schedule_pct": 3, "over_schedule_pct": 1]
        )
        XCTAssertTrue(PulseQuery.isStoreFact(caTotal))
        let merged = PulseQuery.fillMissingRegions(
            existing: [east],
            facts: [east, caTotal],
            section: .scheduleQuality
        )
        XCTAssertTrue(merged.contains { $0.division == "California" && $0.storeNumber.isEmpty })
        let order = MarketRegion.allCases.map(\.rawValue)
        let table = HeartbeatMath.dashboardGrainTableFilled(
            section: .scheduleQuality,
            rows: merged,
            grain: .region,
            order: order
        )
        XCTAssertEqual(table.map(\.label), order)
        let california = table.first { $0.label == MarketRegion.california.rawValue }
        XCTAssertGreaterThan(california?.storeCount ?? 0, 0)
        XCTAssertNotEqual(california?.values.first, "—")
        XCTAssertTrue(california?.values.contains("88.00%") == true || california?.values.first?.contains("88") == true, "\(california?.values ?? [])")
        let prepared = PulseQuery.prepareWarehouse(
            warehouse: [.scheduleQuality: [east]],
            roster: ["100": .init(division: "Jewel Osco", district: "J3", om: "C", name: nil)],
            filters: DashboardFilters(),
            rawRows: [east, caTotal],
            pickers: [],
            bundledFacts: [caTotal],
            scopedLost: nil
        )
        let painted = PulseQuery.paint(
            warehouse: prepared,
            roster: ["100": .init(division: "Jewel Osco", district: "J3", om: "C", name: nil)],
            filters: DashboardFilters(),
            grain: .region,
            uploads: [],
            hidePicker: true,
            light: false
        )
        let labels = (painted.tables[.scheduleQuality] ?? []).map(\.label)
        XCTAssertFalse(labels.isEmpty)
        XCTAssertTrue(labels.contains(MarketRegion.california.rawValue), "\(labels)")
    }

    func testFilterCalloutPaintKeepsHeadersAndFlagsWithoutPrepare() {
        var district = DashboardFilters()
        district.district = "03"
        let jewel = MetricRow(
            section: .lostRevenue,
            division: "Jewel Osco",
            operationsOM: "A",
            storeNumber: "308",
            payload: ["lost_revenue": 100, "lost_revenue_pct": 4, "ecomm_sales": 2_000],
            textPayload: ["district": "J3"]
        )
        let chicago = MetricRow(
            section: .lostRevenue,
            division: "Jewel Osco",
            operationsOM: "A",
            storeNumber: "304",
            payload: ["lost_revenue": 40, "lost_revenue_pct": 2, "ecomm_sales": 1_000],
            textPayload: ["district": "03"]
        )
        let roster: [String: HeartbeatMath.StoreIdentity] = [
            "308": .init(division: "Jewel Osco", district: "J3", om: "A", name: nil),
            "304": .init(division: "Jewel Osco", district: "03", om: "A", name: nil),
        ]
        let painted = PulseQuery.paint(
            warehouse: [.lostRevenue: [jewel, chicago]],
            roster: roster,
            filters: district,
            grain: .store,
            uploads: [],
            hidePicker: true,
            light: true,
            includeFlags: true
        )
        let rows = painted.filtered[.lostRevenue] ?? []
        XCTAssertTrue(rows.contains { $0.storeNumber == "304" })
        XCTAssertFalse(rows.contains { $0.storeNumber == "308" })
        XCTAssertEqual(painted.summaries.first { $0.section == .lostRevenue }?.storeCount, 1)
        XCTAssertFalse(painted.flags.isEmpty)
        XCTAssertTrue(painted.tables.isEmpty)
        XCTAssertFalse(PulseLaunch.shouldPrepareWarehouseOnFilterPaint())
        XCTAssertFalse(PulseLaunch.shouldStampFilterBeforePaint())
        XCTAssertFalse(PulseLaunch.shouldStampHubOnWarehousePaint())
    }

    func testShareDashboardMatchesOnScreenCalloutsAndOpensWithoutHTML() {
        let flags = (1...5).map { n in
            HeartbeatMath.FiveStarFlag(name: "Flag \(n)", value: "\(n).0", health: .watch, stores: n)
        }
        let snap = PulseMail.Snapshot(
            filterSummary: "California Region",
            grain: "region",
            summaries: [
                SectionSummary(
                    section: .sales,
                    storeCount: 12,
                    headline: 1_000,
                    headlineLabel: "eComm sales",
                    secondary: "",
                    health: .watch,
                    watchCount: 2,
                    riskCount: 1
                )
            ],
            rows: [:],
            pickerCounts: [:],
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            flags: [.sales: flags]
        )
        XCTAssertEqual(HubLayout.calloutColumns(count: 5, width: HubLayout.SupportedCanvas.padLandscape), 3)
        let packet = PulseMail.make(snap, pages: [.dashboard])
        XCTAssertTrue(packet.html.contains("dash-card"), packet.html)
        XCTAssertTrue(packet.html.contains("Operational Heartbeat"), packet.html)
        XCTAssertTrue(packet.html.contains("width=\"33%\""), packet.html)
        XCTAssertTrue(packet.html.contains("Flag 5"), packet.html)
        XCTAssertTrue(packet.html.contains("bgcolor=\"#FFFFFF\""), packet.html)
        XCTAssertTrue(packet.html.contains("width=\"4\""), packet.html)
        XCTAssertTrue(packet.html.contains("bgcolor=\"#D97706\""), packet.html)
        XCTAssertTrue(packet.html.contains("class=\"pill\""), packet.html)
        XCTAssertTrue(packet.html.contains("background:#D97706"), packet.html)
        let bodyHTML = PulseMail.html(from: packet)
        XCTAssertFalse(bodyHTML.isEmpty)
        XCTAssertTrue(PulseLaunch.shouldSetHTMLMessageBody(utf8Count: bodyHTML.utf8.count))
        XCTAssertFalse(PulseLaunch.shouldAttachHTMLFile(utf8Count: bodyHTML.utf8.count))
        XCTAssertTrue(PulseMail.overflowMailBody("note").contains("attached as HTML"))
        let brief = PulseMail.briefPacket(snap, pages: [.dashboard])
        XCTAssertTrue(brief.html.isEmpty)
        XCTAssertNil(brief.htmlFile)
        XCTAssertFalse(brief.brief.isEmpty)
        XCTAssertTrue(PulseLaunch.shouldPresentShareSheetWithoutBuildingHTML())
        let streamed = PulseMail.make(snap, pages: [.dashboard], persistHTML: false)
        XCTAssertTrue(streamed.html.isEmpty)
        XCTAssertNotNil(streamed.htmlFile)
        let fromFile = PulseMail.html(from: streamed)
        XCTAssertTrue(fromFile.contains("dash-card"), fromFile)
        XCTAssertTrue(fromFile.contains("class=\"pill\""), fromFile)
        XCTAssertTrue(PulseLaunch.shouldSetHTMLMessageBody(utf8Count: fromFile.utf8.count))
        let item = PulseMail.shareActivityItem(streamed)
        XCTAssertFalse(item is String && (item as? String)?.contains("<html") == true)
    }

    func testShareDistrictFilterDoesNotEmitCompanyRegions() {
        let staleRegions = MarketRegion.allCases.map { region in
            HeartbeatMath.DashboardGrainTableRow(
                label: region.rawValue,
                storeCount: 400,
                values: ["$11,000,000.00", "4.0%", "4.2%", "1,000", "1.0%", "$50.00", "2.0", "10", "AT RISK"],
                health: .risk
            )
        }
        let store = MetricRow(
            section: .sales,
            division: "NorCal",
            operationsOM: "A",
            storeNumber: "304",
            payload: ["sales_dollars": 12_500, "sales_orders": 40],
            textPayload: ["district": "03", "sales_grain": "store"]
        )
        let snap = PulseMail.Snapshot(
            filterSummary: "All regions · All divisions · District 03 · All OMs · All stores",
            grain: "store",
            summaries: [
                SectionSummary(
                    section: .sales,
                    storeCount: 20,
                    headline: 466_210.21,
                    headlineLabel: "eComm sales",
                    secondary: "",
                    health: .good,
                    watchCount: 2,
                    riskCount: 0
                )
            ],
            rows: [.sales: [store]],
            pickerCounts: [:],
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            grainTables: [.sales: staleRegions],
            flags: [
                .sales: [
                    HeartbeatMath.FiveStarFlag(name: "Healthy", value: "Positive ID", health: .good, stores: 1_841),
                    HeartbeatMath.FiveStarFlag(name: "Watch", value: "Slightly under", health: .watch, stores: 77),
                    HeartbeatMath.FiveStarFlag(name: "At Risk", value: "Negative ID", health: .risk, stores: 243),
                ]
            ]
        )
        let html = PulseMail.make(snap, pages: [.dashboard]).html
        XCTAssertFalse(html.contains("East Region"), html)
        XCTAssertFalse(html.contains("South Region"), html)
        XCTAssertFalse(html.contains("California Region"), html)
        XCTAssertFalse(html.contains("West Region"), html)
        XCTAssertFalse(html.contains("Stores · 4"), html)
        XCTAssertFalse(html.contains("1,841"), html)
        XCTAssertTrue(html.contains("District 03"), html)
        XCTAssertTrue(html.contains("Stores"), html)
        XCTAssertTrue(html.contains("304") || html.contains("12,500") || html.contains("$12,500"), html)
        XCTAssertTrue(html.contains("40"), html)
    }

    func testShareStoreGrainFillsSalesYoYAndOrdersFromFilteredRows() {
        let stores = [
            MetricRow(
                section: .sales,
                division: "NorCal",
                operationsOM: "A",
                storeNumber: "1490",
                payload: ["sales_dollars": 22_108.67, "sales_yoy_pct": -4.2, "sales_orders": 82],
                textPayload: ["district": "03", "sales_grain": "store"]
            ),
            MetricRow(
                section: .sales,
                division: "NorCal",
                operationsOM: "A",
                storeNumber: "3116",
                payload: ["sales_dollars": 72_987.06, "sales_yoy_pct": -5.1, "sales_orders": 210],
                textPayload: ["district": "03", "sales_grain": "store"]
            ),
        ]
        let sparse = stores.map { row in
            HeartbeatMath.DashboardGrainTableRow(
                label: "\(row.storeNumber) | NorCal",
                storeCount: 1,
                values: [HeartbeatFormat.money(row.number("sales_dollars"))],
                health: .risk
            )
        }
        XCTAssertTrue(HeartbeatMath.grainTableNeedsColumnFill(sparse, section: .sales))
        let filled = HeartbeatMath.fillingGrainTable(
            sparse,
            section: .sales,
            metricRows: stores,
            grain: .store
        )
        XCTAssertEqual(filled.count, 2)
        XCTAssertEqual(filled[0].values.count, 3)
        XCTAssertEqual(filled[0].values[1], "-4.20%")
        XCTAssertEqual(filled[0].values[2], "82")
        XCTAssertEqual(filled[1].values[1], "-5.10%")
        XCTAssertEqual(filled[1].values[2], "210")
        let snap = PulseMail.Snapshot(
            filterSummary: "All regions · All divisions · District 03 · All OMs · All stores",
            grain: "store",
            summaries: [
                SectionSummary(
                    section: .sales,
                    storeCount: 2,
                    headline: 95_095.73,
                    headlineLabel: "eComm sales",
                    secondary: "",
                    health: .risk,
                    watchCount: 0,
                    riskCount: 2
                )
            ],
            rows: [.sales: stores],
            pickerCounts: [:],
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            grainTables: [.sales: sparse]
        )
        let html = PulseMail.make(snap, pages: [.dashboard]).html
        XCTAssertTrue(html.contains("1490"), html)
        XCTAssertTrue(html.contains("3116"), html)
        XCTAssertTrue(html.contains("YoY %"), html)
        XCTAssertTrue(html.contains("Orders"), html)
        XCTAssertTrue(html.contains("-4.20%"), html)
        XCTAssertTrue(html.contains("-5.10%"), html)
        XCTAssertTrue(html.contains(">82<") || html.contains("82"), html)
        XCTAssertTrue(html.contains("210"), html)
        let packed = HeartbeatMath.dashboardGrainRowsFromPacks(
            [DashScopePack(line: DashScopeLine(label: "1490 | NorCal", value: "$22,108.67", health: .risk, count: 1), flags: [])],
            section: .sales
        )
        XCTAssertTrue(HeartbeatMath.grainTableNeedsColumnFill(packed, section: .sales))
        let packedFilled = HeartbeatMath.fillingGrainTable(
            packed,
            section: .sales,
            metricRows: stores,
            grain: .store
        )
        XCTAssertEqual(packedFilled.first?.values[1], "-4.20%")
        XCTAssertEqual(packedFilled.first?.values[2], "82")
    }

    func testSupportedFloorIPhone13AndiPad13FlowEvenColumns() {
        let phoneP = HubLayout.SupportedCanvas.phonePortrait
        let phoneL = HubLayout.SupportedCanvas.phoneLandscape
        let padP = HubLayout.SupportedCanvas.padPortrait
        let padL = HubLayout.SupportedCanvas.padLandscape
        XCTAssertEqual(phoneP, 390)
        XCTAssertEqual(phoneL, 844)
        XCTAssertEqual(padP, 1024)
        XCTAssertEqual(padL, 1366)
        for count in [4, 5, 7] {
            XCTAssertTrue(HubLayout.calloutsFitCanvas(count: count, width: phoneP, phone: true), "phone portrait \(count)")
            XCTAssertTrue(HubLayout.calloutsFitCanvas(count: count, width: phoneL, phone: true), "phone landscape \(count)")
            XCTAssertTrue(HubLayout.calloutsFitCanvas(count: count, width: padP, phone: false), "pad portrait \(count)")
            XCTAssertTrue(HubLayout.calloutsFitCanvas(count: count, width: padL, phone: false), "pad landscape \(count)")
        }
        XCTAssertLessThanOrEqual(HubLayout.calloutColumns(count: 4, width: phoneP), 2)
        XCTAssertGreaterThanOrEqual(HubLayout.calloutColumns(count: 4, width: phoneL), 3)
        XCTAssertEqual(HubLayout.calloutColumns(count: 4, width: padL), 4)
        XCTAssertEqual(HubLayout.calloutColumns(count: 5, width: padL), 3)
        for canvas in [phoneP, phoneL] {
            XCTAssertTrue(
                HubLayout.tableFlowsOnCanvas(available: canvas, phone: true, columns: 3, showCount: true),
                "prep 3-col phone \(canvas)"
            )
            XCTAssertTrue(
                HubLayout.tableFlowsOnCanvas(
                    available: canvas,
                    phone: true,
                    columns: 4,
                    showCount: true,
                    district: true
                ),
                "district 4-col phone \(canvas)"
            )
        }
        for canvas in [padP, padL] {
            XCTAssertTrue(
                HubLayout.tableFlowsOnCanvas(available: canvas, phone: false, columns: 3, showCount: true),
                "prep 3-col pad \(canvas)"
            )
            XCTAssertTrue(
                HubLayout.tableFlowsOnCanvas(available: canvas, phone: false, columns: 6, showCount: true),
                "dashboard 6-col pad \(canvas)"
            )
        }
        let phoneEven = HubLayout.evenValueWidth(available: phoneL, phone: true, columns: 3, showCount: true)
        let padEven = HubLayout.evenValueWidth(available: padL, phone: false, columns: 3, showCount: true)
        XCTAssertGreaterThanOrEqual(phoneEven, HubLayout.readableValueMin(phone: true))
        XCTAssertGreaterThanOrEqual(padEven, HubLayout.readableValueMin(phone: false))
        XCTAssertGreaterThan(padEven, phoneEven)
        XCTAssertEqual(HeartbeatMath.displayGrainLabel("J3CHICAGO").count, 2)
    }
}

