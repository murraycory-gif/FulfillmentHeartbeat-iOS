import XCTest
@testable import FulfillmentHeartbeat

final class AssistCardsTests: XCTestCase {
    func testAssistPPHRankingBandIs65To80() throws {
        XCTAssertEqual(AssistRank.pphHealth(64.9), .risk)
        XCTAssertEqual(AssistRank.pphHealth(65), .watch)
        XCTAssertEqual(AssistRank.pphHealth(79.9), .watch)
        XCTAssertEqual(AssistRank.pphHealth(80), .good)
        XCTAssertEqual(HeartbeatMath.pphHealth(row(.pph, ["pph": 70])), .risk)
        XCTAssertEqual(AssistRank.pphHealth(70), .watch)

        let book = try loadPlaybook()
        var snapshot = fixtureSnapshot()
        snapshot.summaries[.pph] = summary(.pph, .risk, risk: 2, watch: 0, stores: 2, headline: 70)
        snapshot.rows[.pph] = [
            row(.pph, ["pph": 60], store: "304"),
            row(.pph, ["pph": 70], store: "305"),
        ]
        let answer = AssistComposer.answer(question: "pph", snapshot: snapshot, book: book)
        let issue = try XCTUnwrap(answer.issues.first { $0.id == "pph" })
        XCTAssertEqual(issue.statusText, "Watch")
        XCTAssertEqual(issue.numberValue, "1 of 2")
        XCTAssertTrue(issue.headline.contains("fewer than 65"))
        XCTAssertTrue(issue.rankedLine.contains("1 at-risk and 1 watch"))
        XCTAssertEqual(issue.facts.first { $0.label == "Goal" }?.value, "80")
    }

    func testRankingFixtureOrderIsBThenAThenCThenD() {
        let ranked = AssistRank.rank([
            input(.missingItems, .risk, risk: 10, watch: 4, distance: 0.50, stores: 20),
            input(.pickPath, .risk, risk: 8, watch: 10, distance: 1.00, stores: 20),
            input(.dynacap, .good, risk: 30, watch: 0, distance: 0.20, stores: 40),
            input(.pph, .watch, risk: 0, watch: 20, distance: 0.40, stores: 25),
            input(.pickerScorecard, .risk, risk: 24_671, watch: 0, distance: 1, stores: 2_000),
            input(.sales, .good, risk: 0, watch: 0, distance: 0, stores: 10),
        ])
        XCTAssertEqual(ranked.map(\.section), [.pickPath, .missingItems, .dynacap, .pph])
        XCTAssertEqual(ranked.map(\.score), [78, 54, 36, 28])
    }

    func testLaborTieBreakRanksAfterPickPath() {
        let ranked = AssistRank.rank([
            input(.pickPath, .risk, risk: 8, watch: 10, distance: 1, stores: 20),
            input(.labor, .risk, risk: 8, watch: 10, distance: 1, stores: 20),
            input(.missingItems, .risk, risk: 10, watch: 4, distance: 0.5, stores: 20),
        ])
        XCTAssertEqual(ranked.map(\.section), [.pickPath, .labor, .missingItems])
        XCTAssertEqual(ranked[0].score, ranked[1].score)
    }

    func testScoreTieBreaksUseRiskThenWatchThenDistanceThenCardOrder() {
        let byRisk = AssistRank.ordered([
            scored(.sales, score: 6, risk: 1, watch: 0, distance: 1),
            scored(.labor, score: 6, risk: 2, watch: 0, distance: 0),
        ])
        XCTAssertEqual(byRisk.map(\.section), [.labor, .sales])

        let byWatch = AssistRank.ordered([
            scored(.sales, score: 6, risk: 1, watch: 1, distance: 1),
            scored(.labor, score: 6, risk: 1, watch: 4, distance: 0),
        ])
        XCTAssertEqual(byWatch.map(\.section), [.labor, .sales])

        let byDistance = AssistRank.ordered([
            scored(.sales, score: 3, risk: 1, watch: 0, distance: 0),
            scored(.labor, score: 3, risk: 1, watch: 0, distance: 0.00001),
        ])
        XCTAssertEqual(byDistance.map(\.section), [.labor, .sales])

        let byOrder = AssistRank.ordered([
            scored(.labor, score: 9, risk: 2, watch: 1, distance: 0.5),
            scored(.sales, score: 9, risk: 2, watch: 1, distance: 0.5),
        ])
        XCTAssertEqual(byOrder.map(\.section), [.sales, .labor])
    }

    func testScoresRoundToFourDecimalsBeforeCompare() {
        let low = AssistRank.score(input(.sales, .risk, risk: 1, watch: 0, distance: 0.00001, stores: 1))
        let high = AssistRank.score(input(.labor, .risk, risk: 1, watch: 0, distance: 0.00004, stores: 1))
        XCTAssertEqual(low?.score, 3)
        XCTAssertEqual(high?.score, 3.0001)
        let ranked = AssistRank.rank([
            input(.sales, .risk, risk: 1, watch: 0, distance: 0.00001, stores: 1),
            input(.labor, .risk, risk: 1, watch: 0, distance: 0.00004, stores: 1),
        ])
        XCTAssertEqual(ranked.map(\.section), [.labor, .sales])
    }

    func testOffBandMatchesPublishedGaps() {
        XCTAssertEqual(AssistRank.offBand(section: .pickPath, row: row(.pickPath, ["compliance_pct": 80])), 1)
        XCTAssertEqual(AssistRank.offBand(section: .missingItems, row: row(.missingItems, ["mi_pct": 6.5])), 1)
        XCTAssertEqual(AssistRank.offBand(section: .pph, row: row(.pph, ["pph": 65])), 1)
        XCTAssertEqual(AssistRank.offBand(section: .pph, row: row(.pph, ["pph": 80])), 0)
        XCTAssertEqual(AssistRank.offBand(section: .pph, row: row(.pph, ["pph": 74])) ?? 0, 0.4, accuracy: 0.0001)
        XCTAssertEqual(AssistRank.offBand(section: .labor, row: row(.labor, ["target_vs_actual_pct": 3])), 1)
        XCTAssertEqual(AssistRank.offBand(section: .fiveStar, row: row(.fiveStar, ["star_rating": 4])), 1)
        XCTAssertEqual(AssistRank.offBand(section: .dynacap, row: row(.dynacap, ["dynacap_rate": 60])), 1)
        XCTAssertEqual(AssistRank.offBand(section: .sales, row: row(.sales, ["sales_yoy_pct": -3])), 1)
        XCTAssertEqual(AssistRank.offBand(section: .sales, row: row(.sales, ["sales_plan_pct": 95])), 1)
        let unaligned = MetricRow(
            section: .dynacap,
            division: "Shaws",
            operationsOM: "",
            storeNumber: "304",
            payload: [
                "pickup_capacity": 10,
                "delivery_capacity": 10,
                "rec_pickup": 40,
                "rec_delivery": 40,
            ]
        )
        XCTAssertEqual(HeartbeatMath.dynacapAligned(unaligned), false)
        XCTAssertEqual(AssistRank.offBand(section: .dynacap, row: unaligned), 1)
        XCTAssertNil(AssistRank.offBand(section: .pickPath, row: row(.pickPath, [:])))
    }

    func testDistanceSkipsHealthyIgnoredAndMarketRows() {
        let rows = [
            row(.pickPath, ["compliance_pct": 80], store: "304"),
            row(.pickPath, ["compliance_pct": 50], store: "210"),
            row(.pickPath, ["compliance_pct": 95], store: "305"),
        ]
        XCTAssertEqual(AssistRank.distance(section: .pickPath, rows: rows), 1)
        let market = MetricRow(
            section: .lostRevenue,
            division: "Shaws",
            operationsOM: "",
            storeNumber: "1",
            payload: ["lost_revenue_pct": 20],
            textPayload: ["lost_grain": "market"]
        )
        XCTAssertEqual(AssistRank.distance(section: .lostRevenue, rows: [market]), 0)
    }

    func testHeaderTitlesAndLengths() {
        XCTAssertNil(AssistCopy.headerTitle(issueCount: 0))
        XCTAssertEqual(AssistCopy.headerTitle(issueCount: 1), "Fix this first")
        XCTAssertEqual(AssistCopy.headerTitle(issueCount: 2), "Fix these 2 first")
        XCTAssertEqual(AssistCopy.headerTitle(issueCount: 5), "Fix these 3 first")
        for section in MetricSection.dashboardCards where section != .pickerScorecard {
            let line = AssistCopy.headerLine(rank: 1, shortName: section.overviewLead, risk: 12_345, total: 12_345)
            XCTAssertLessThanOrEqual(line.count, AssistCopy.headerLimit, line)
            XCTAssertTrue(line.contains("12,345"), line)
            let storeLine = AssistCopy.storeHeaderLine(
                rank: 1,
                shortName: section.overviewLead,
                value: "71.4%",
                goal: AssistCopy.goalShort(section)
            )
            XCTAssertLessThanOrEqual(storeLine.count, AssistCopy.headerLimit, storeLine)
        }
        XCTAssertEqual(
            AssistCopy.headerLine(rank: 1, shortName: "Schedule", risk: 1_822, total: 2_161),
            "1. Schedule: 1,822 of 2,161 stores"
        )
    }

    func testPlaybookParsesAndEveryDestinationResolves() throws {
        let book = try loadPlaybook()
        XCTAssertEqual(book.version, "2026-09-25.2")
        XCTAssertEqual(book.line, "0dcad79201cba43c75e6a70e2cfe67b6339eeaec")
        XCTAssertEqual(book.metrics.count, 27)
        let checks = book.metrics.flatMap(\.checks)
        XCTAssertEqual(checks.count, 115)
        XCTAssertEqual(checks.filter { $0.type == .floor }.count, 112)
        XCTAssertEqual(checks.filter { $0.type == .auto }.count, 3)
        let allowed = Set(HubDestination.allCases.map(\.rawValue))
        XCTAssertEqual(allowed.count, 15)
        XCTAssertEqual(HubDestination(rawValue: "scheduleCheck"), .scheduleCheck)
        XCTAssertTrue(allowed.contains("scheduleCheck"))
        XCTAssertEqual(HubDestination.scheduleCheck.title, "Upcoming Weeks Schedule Check")
        XCTAssertTrue(allowed.contains("settings"))
        XCTAssertFalse(allowed.contains("checklist"))
        XCTAssertFalse(allowed.contains("upload"))
        for metric in book.metrics {
            XCTAssertNotNil(HubDestination(rawValue: metric.section), metric.metricId)
            XCTAssertFalse(metric.checks.isEmpty, metric.metricId)
            for check in metric.checks {
                XCTAssertNotNil(
                    HubDestination(rawValue: check.destination),
                    "\(metric.metricId) #\(check.order) \(check.destination)"
                )
                XCTAssertNotEqual(check.destination, "checklist")
                XCTAssertNotEqual(check.destination, "upload")
                if check.type == .floor {
                    XCTAssertTrue(check.question?.hasSuffix("?") == true, check.question ?? metric.metricId)
                    XCTAssertFalse(check.question?.lowercased().contains("call-off") == true)
                    XCTAssertFalse(check.question?.lowercased().contains("no-show") == true)
                    XCTAssertFalse(check.question?.contains("(confirm)") == true)
                }
            }
        }
        for id in AssistPlaybook.rankedMetricIDs {
            XCTAssertNotNil(book.metric(id), id)
        }
        XCTAssertEqual(AssistRank.pphRankingBand.goal, 80)
        XCTAssertEqual(AssistRank.pphRankingBand.risk, 65)
        XCTAssertEqual(HeartbeatMath.pphGoal, 80)
        XCTAssertEqual(HeartbeatMath.pphRisk, 74)
        XCTAssertEqual(book.metric("lost_reduced_capacity")?.causesConfirm, ["dynacap"])
        XCTAssertEqual(book.metric("lost_revenue")?.causes, ["lost_reduced_capacity"])
        XCTAssertTrue(book.metric("lost_revenue")?.causesConfirm.isEmpty == true)
    }

    func testOwnerWordingLivesOnPreSubsOTTAndPPH() throws {
        let book = try loadPlaybook()
        let radios = [
            "Are shoppers using radios?",
            "Is the whole store using radios?",
            "Is store PI (perpetual inventory) accurate?",
        ]
        for id in ["pre_sub_oos", "five_star_presub"] {
            let checks = try XCTUnwrap(book.metric(id)).checks
            XCTAssertEqual(Array(checks.prefix(3).map(\.question)), radios, id)
            XCTAssertEqual(checks[2].detail, "Check PI accuracy; look for out-of-stocks showing as on-hand.")
            XCTAssertFalse(checks.contains { $0.question?.contains("(confirm)") == true }, id)
        }
        let pph = try XCTUnwrap(book.metric("pph")).checks
        XCTAssertEqual(pph[0].type, .floor)
        XCTAssertEqual(
            pph[0].question,
            "Are shoppers picking 30 items within the first 15 minutes of their run or shift start?"
        )
        XCTAssertEqual(pph[1].type, .auto)
        XCTAssertEqual(pph[1].label, "PPH under 65")
        XCTAssertEqual(pph[1].packFields, ["pph", "pure_pph"])
        XCTAssertEqual(pph[1].comparator, "<")
        XCTAssertEqual(pph[1].threshold, 65)
        XCTAssertEqual(pph[1].rollup, .avg)

        let ott = try XCTUnwrap(book.metric("five_star_ott")).checks
        XCTAssertEqual(ott.prefix(2).map(\.type), [.auto, .auto])
        XCTAssertEqual(ott[0].label, "Under-scheduled")
        XCTAssertEqual(ott[0].threshold, 5)
        XCTAssertEqual(ott[0].packFields, ["under_schedule_pct", "under_scheduled"])
        XCTAssertEqual(ott[0].supportFields, ["under_adherence_pct"])
        XCTAssertEqual(ott[0].rollup, .countFailing)
        XCTAssertEqual(ott[1].label, "PPH under 65")
        XCTAssertEqual(ott[1].threshold, 65)
        XCTAssertEqual(ott[2].type, .floor)
    }

    func testAutoCheckRendersScopeValue() throws {
        let book = try loadPlaybook()
        let pph = try XCTUnwrap(book.metric("pph")?.checks.first { $0.label == "PPH under 65" })
        XCTAssertEqual(
            AssistAutoCheck.sentence(pph, rows: [.pph: [row(.pph, ["pph": 58])]], level: .store),
            "PPH 58, under 65"
        )
        XCTAssertEqual(
            AssistAutoCheck.sentence(pph, rows: [.pph: [row(.pph, ["pph": 58.4])]], level: .store),
            "PPH 58.4, under 65"
        )
        XCTAssertEqual(
            AssistAutoCheck.sentence(pph, rows: [.pph: [row(.pph, ["pph": 72])]], level: .store),
            "PPH 72, at or above 65"
        )
        XCTAssertEqual(
            AssistAutoCheck.sentence(pph, rows: [.pph: [row(.pph, ["pph": 65])]], level: .store),
            "PPH 65, at or above 65"
        )
        XCTAssertEqual(
            AssistAutoCheck.sentence(pph, rows: [.pph: [row(.pph, ["pure_pph": 58])]], level: .store),
            "PPH 58, under 65"
        )
        let scope = AssistAutoCheck.evaluate(
            pph,
            rows: [.pph: [row(.pph, ["pph": 50], store: "304"), row(.pph, ["pph": 66], store: "305")]],
            summaries: [.pph: summary(.pph, .risk, risk: 1, watch: 0, stores: 2, headline: 58)],
            level: .company
        )
        XCTAssertEqual(scope?.failing, true)
        XCTAssertEqual(scope?.sentence, "PPH 58.0, under 65; 1 of 2 stores under 65")
        XCTAssertEqual(scope?.statusMark, "Check")

        let under = try XCTUnwrap(book.metric("five_star_ott")?.checks.first { $0.label == "Under-scheduled" })
        XCTAssertEqual(
            AssistAutoCheck.sentence(
                under,
                rows: [.scheduleQuality: [row(.scheduleQuality, ["under_schedule_pct": 7.2, "under_adherence_pct": 4.1])]],
                level: .store
            ),
            "Under-scheduled: yes (Sch vs Tgt 7.2%, over 5%, Pch vs Sch 4.1%)"
        )
        XCTAssertEqual(
            AssistAutoCheck.sentence(
                under,
                rows: [.scheduleQuality: [row(.scheduleQuality, ["under_schedule_pct": 7.2])]],
                level: .store
            ),
            "Under-scheduled: yes (Sch vs Tgt 7.2%, over 5%)"
        )
        XCTAssertEqual(
            AssistAutoCheck.sentence(
                under,
                rows: [.scheduleQuality: [row(.scheduleQuality, ["under_schedule_pct": 3])]],
                level: .store
            ),
            "Under-scheduled: no (Sch vs Tgt 3%)"
        )
        XCTAssertEqual(
            AssistAutoCheck.sentence(
                under,
                rows: [
                    .scheduleQuality: [
                        row(.scheduleQuality, ["under_schedule_pct": 7.2], store: "304"),
                        row(.scheduleQuality, ["under_schedule_pct": 1], store: "305"),
                    ],
                ],
                level: .company
            ),
            "Under-scheduled: yes, 1 of 2 stores over 5% (Sch vs Tgt)"
        )
    }

    func testAutoCheckHidesWhenFieldIsMissing() throws {
        let book = try loadPlaybook()
        let pph = try XCTUnwrap(book.metric("pph")?.checks.first { $0.label == "PPH under 65" })
        XCTAssertNil(AssistAutoCheck.sentence(pph, rows: [:], level: .store))
        XCTAssertNil(
            AssistAutoCheck.sentence(pph, rows: [.pph: [row(.pph, ["orders": 12])]], level: .store)
        )
        XCTAssertNil(
            AssistAutoCheck.sentence(pph, rows: [.pph: [row(.pph, ["pph": 58], store: "210")]], level: .store)
        )
        var unknown = pph
        unknown.comparator = "around"
        XCTAssertNil(
            AssistAutoCheck.sentence(unknown, rows: [.pph: [row(.pph, ["pph": 58])]], level: .store)
        )

        let under = try XCTUnwrap(book.metric("five_star_ott")?.checks.first { $0.label == "Under-scheduled" })
        XCTAssertNil(
            AssistAutoCheck.sentence(
                under,
                rows: [.scheduleQuality: [row(.scheduleQuality, ["schedule_efficiency_pct": 91])]],
                level: .store
            )
        )
        XCTAssertNil(
            AssistAutoCheck.sentence(
                under,
                rows: [.scheduleQuality: [row(.scheduleQuality, ["under_adherence_pct": 8])]],
                level: .store
            )
        )
    }

    func testAutoCheckReadsItsOwnSectionWhenPPHConflicts() throws {
        let book = try loadPlaybook()
        let storeCheck = try XCTUnwrap(book.metric("pph")?.checks.first { $0.label == "PPH under 65" })
        var pathCheck = storeCheck
        pathCheck.destination = "pickPath"
        var pickerCheck = storeCheck
        pickerCheck.destination = "pickerScorecard"
        let rows: [MetricSection: [MetricRow]] = [
            .pph: [row(.pph, ["pph": 58], store: "304")],
            .pickPath: [row(.pickPath, ["pph": 40], store: "304")],
            .pickerScorecard: [row(.pickerScorecard, ["pph": 90], store: "304")],
        ]
        XCTAssertEqual(
            AssistAutoCheck.sentence(storeCheck, rows: rows, level: .store),
            "PPH 58, under 65"
        )
        XCTAssertEqual(
            AssistAutoCheck.sentence(pathCheck, rows: rows, level: .store),
            "PPH 40, under 65"
        )
        XCTAssertEqual(
            AssistAutoCheck.sentence(pickerCheck, rows: rows, level: .store),
            "PPH 90, at or above 65"
        )
        XCTAssertNil(
            AssistAutoCheck.sentence(
                storeCheck,
                rows: [
                    .pph: [row(.pph, ["orders": 4], store: "304")],
                    .pickPath: [row(.pickPath, ["pph": 40], store: "304")],
                    .pickerScorecard: [row(.pickerScorecard, ["pph": 90], store: "304")],
                ],
                level: .store
            )
        )
        let scope = AssistAutoCheck.evaluate(
            storeCheck,
            rows: [
                .pph: [row(.pph, ["pph": 58], store: "304")],
                .pickPath: [row(.pickPath, ["pph": 40], store: "306")],
                .pickerScorecard: [row(.pickerScorecard, ["pph": 90], store: "305")],
            ],
            summaries: [.pph: summary(.pph, .risk, risk: 1, watch: 0, stores: 1, headline: 58)],
            level: .company
        )
        XCTAssertEqual(scope?.failing, true)
        XCTAssertEqual(scope?.sentence, "PPH 58.0, under 65; 1 of 1 stores under 65")
    }

    func testPlaybookDecodesOnce() throws {
        let cached = try XCTUnwrap(AssistPlaybook.bundled())
        let decoded = AssistPlaybook.bundledDecodeCount
        XCTAssertEqual(decoded, 1)
        let again = try XCTUnwrap(AssistPlaybook.bundled())
        XCTAssertEqual(again, cached)
        XCTAssertEqual(cached, try loadPlaybook())
        let snapshot = fixtureSnapshot()
        _ = AssistComposer.answer(question: "What should we fix first?", snapshot: snapshot)
        _ = AssistComposer.chips(for: snapshot)
        _ = AssistComposer.answer(question: "pph", snapshot: snapshot)
        XCTAssertEqual(AssistPlaybook.bundledDecodeCount, decoded)
    }

    func testSnapshotAssembleKeepsSectionRows() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let source = AssistSnapshot.Source(
            seeded: true,
            filters: DashboardFilters(),
            summaries: [.pph: summary(.pph, .risk, risk: 1, watch: 0, stores: 1, headline: 58)],
            latest: [
                .pph: [row(.pph, ["pph": 58], store: "304")],
                .pickPath: [row(.pickPath, ["pph": 40], store: "304")],
            ],
            historyPool: [],
            focus: nil,
            rosterStores: [("304", "Harbor")],
            districts: [],
            divisions: [],
            operationsOMs: [],
            packUploads: [],
            now: now
        )
        let snapshot = AssistSnapshot.assemble(source)
        XCTAssertEqual(snapshot.rows[.pph]?.first?.number("pph") ?? -1, 58)
        XCTAssertEqual(snapshot.rows[.pickPath]?.first?.number("pph") ?? -1, 40)
        XCTAssertTrue(snapshot.history.isEmpty)
        XCTAssertEqual(snapshot.now, now)
    }

    func testResolutionCardsUseOwnerChecksAndHideMissingAutoFields() throws {
        let book = try loadPlaybook()
        var presub = fixtureSnapshot()
        presub.filters.store = "304"
        presub.summaries[.preSubOOS] = summary(.preSubOOS, .risk, risk: 1, watch: 0, stores: 1, headline: 8)
        presub.rows[.preSubOOS] = [row(.preSubOOS, ["mi_pct": 8])]
        let presubIssue = try XCTUnwrap(
            AssistComposer.answer(question: "pre sub", snapshot: presub, book: book).issues.first { $0.id == "pre_sub_oos" }
        )
        XCTAssertEqual(Array(presubIssue.checks.prefix(3).map(\.question)), [
            "Are shoppers using radios?",
            "Is the whole store using radios?",
            "Is store PI (perpetual inventory) accurate?",
        ])
        XCTAssertEqual(presubIssue.checks[2].detail, "Check PI accuracy; look for out-of-stocks showing as on-hand.")
        XCTAssertFalse(presubIssue.checks.contains { $0.question.contains("(confirm)") })

        var low = fixtureSnapshot()
        low.filters.store = "304"
        low.summaries[.pph] = summary(.pph, .risk, risk: 1, watch: 0, stores: 1, headline: 58)
        low.rows[.pph] = [row(.pph, ["pph": 58])]
        let lowIssue = try XCTUnwrap(
            AssistComposer.answer(question: "pph", snapshot: low, book: book).issues.first { $0.id == "pph" }
        )
        XCTAssertEqual(
            lowIssue.checks.first?.question,
            "Are shoppers picking 30 items within the first 15 minutes of their run or shift start?"
        )
        XCTAssertTrue(lowIssue.checks.contains { $0.question == "PPH 58, under 65" && $0.statusMark == "Check" })

        var passing = low
        passing.summaries[.pph] = summary(.pph, .watch, risk: 0, watch: 1, stores: 1, headline: 72)
        passing.rows[.pph] = [row(.pph, ["pph": 72])]
        let passingIssue = try XCTUnwrap(
            AssistComposer.answer(question: "pph", snapshot: passing, book: book).issues.first { $0.id == "pph" }
        )
        XCTAssertFalse(passingIssue.checks.contains { $0.question.contains("65") })
        XCTAssertTrue(passingIssue.moreChecks.contains { $0.question == "PPH 72, at or above 65" && $0.statusMark == "OK" })

        var missing = low
        missing.rows[.pph] = [row(.pph, ["orders": 10])]
        missing.summaries[.pph] = summary(.pph, .risk, risk: 1, watch: 0, stores: 1, headline: nil)
        let missingIssue = try XCTUnwrap(
            AssistComposer.answer(question: "pph", snapshot: missing, book: book).issues.first { $0.id == "pph" }
        )
        let shown = missingIssue.checks + missingIssue.moreChecks
        XCTAssertEqual(shown.first?.question, lowIssue.checks.first?.question)
        XCTAssertFalse(shown.contains { $0.question.contains("65") || $0.question.contains("58") })

        var ott = fixtureSnapshot()
        ott.filters.store = "304"
        ott.summaries[.fiveStar] = summary(.fiveStar, .risk, risk: 1, watch: 0, stores: 1, headline: 3.2)
        ott.rows[.fiveStar] = [row(.fiveStar, ["ott_pct": 80, "star_rating": 3.2, "presub_pct": 2, "flash_pct": 90, "coe_pct": 30, "oth5_pct": 96])]
        ott.rows[.scheduleQuality] = [row(.scheduleQuality, ["under_schedule_pct": 7.2])]
        ott.rows[.pph] = [row(.pph, ["pph": 58])]
        ott.summaries[.pph] = summary(.pph, .risk, risk: 1, watch: 0, stores: 1, headline: 58)
        let ottIssue = try XCTUnwrap(
            AssistComposer.answer(question: "ott", snapshot: ott, book: book).issues.first { $0.id == "five_star" }
        )
        XCTAssertEqual(
            ottIssue.checks.first?.question,
            "Under-scheduled: yes (Sch vs Tgt 7.2%, over 5%)"
        )
        XCTAssertTrue(ottIssue.checks.contains { $0.question == "PPH 58, under 65" })
        XCTAssertTrue(ottIssue.checks.contains { $0.question.hasSuffix("?") })

        var ottMissing = ott
        ottMissing.rows[.scheduleQuality] = [row(.scheduleQuality, ["schedule_efficiency_pct": 91])]
        let ottMissingIssue = try XCTUnwrap(
            AssistComposer.answer(question: "ott", snapshot: ottMissing, book: book).issues.first { $0.id == "five_star" }
        )
        let ottShown = ottMissingIssue.checks + ottMissingIssue.moreChecks
        XCTAssertFalse(ottShown.contains { $0.question.hasPrefix("Under-scheduled") })
        XCTAssertTrue(ottShown.contains { $0.question == "PPH 58, under 65" })
    }

    func testFixtureAnswerOrderHeaderAndPickerExclusion() throws {
        let book = try loadPlaybook()
        let snapshot = fixtureSnapshot()
        let first = AssistComposer.answer(question: "What should we fix first?", snapshot: snapshot, book: book)
        let second = AssistComposer.answer(question: "What should we fix first?", snapshot: snapshot, book: book)
        XCTAssertEqual(first.issues.map(\.id), second.issues.map(\.id))
        XCTAssertEqual(first.issues.map(\.id), ["pick_path", "missing_items", "dynacap", "pph"])
        XCTAssertEqual(first.headerTitle, "Fix these 3 first")
        XCTAssertEqual(first.headerLines.map(\.text).count, 3)
        XCTAssertEqual(first.headerLines[0].text, "1. Pick Path: 8 of 20 stores")
        XCTAssertLessThanOrEqual(first.headerLines[0].text.count, 48)
        XCTAssertFalse(first.issues.contains { $0.id == "picker_scorecard" })
        XCTAssertFalse(first.rankedLines.joined(separator: "\n").contains("Picker"))
        for issue in first.issues {
            XCTAssertLessThanOrEqual(issue.headline.count, 90, issue.headline)
            XCTAssertFalse(issue.headline.contains("·"), issue.headline)
            XCTAssertFalse(issue.headline.contains("WHAT"), issue.headline)
            XCTAssertTrue(issue.scope.hasPrefix("Scope:"))
        }
        XCTAssertLessThanOrEqual(first.chips.count, 4)
        for chip in first.chips {
            XCTAssertLessThanOrEqual(chip.count, 40, chip)
        }
        XCTAssertEqual(first.chips.first, "What should we fix first?")
        let joined = first.rankedLines.joined(separator: "\n")
        XCTAssertTrue(joined.contains("8 at-risk and 10 watch"))
        XCTAssertTrue(joined.contains("1.0 of a band") || joined.contains("1.0 of a band past"))
        XCTAssertTrue(
            joined.contains("PPH Pure Picks Per Hour: watch, 0 at-risk and 20 watch stores, on average 0.4 of a band past goal.")
        )
    }

    func testLongHeadlinesStayWithinLimitAndStoreScopeDropsTheCount() throws {
        let book = try loadPlaybook()
        var snapshot = fixtureSnapshot()
        for section in MetricSection.dashboardCards where section != .pickerScorecard {
            snapshot.summaries[section] = summary(section, .risk, risk: 12_345, watch: 10, stores: 12_345, headline: 70)
            snapshot.rows[section] = [row(section, [:], store: "100")]
        }
        let answer = AssistComposer.answer(question: "What should we fix first?", snapshot: snapshot, book: book)
        for issue in answer.issues {
            XCTAssertLessThanOrEqual(issue.headline.count, 90, issue.headline)
        }
        snapshot.filters.store = "304"
        snapshot.rosterStores = [("304", "Harbor")]
        let storeAnswer = AssistComposer.answer(question: "What should this store fix first?", snapshot: snapshot, book: book)
        XCTAssertEqual(storeAnswer.scopeLabel, "Store 304, Harbor")
        XCTAssertEqual(AssistScope.label(DashboardFilters(), roster: []), "Total company")
        var bare = DashboardFilters()
        bare.store = "18"
        XCTAssertEqual(AssistScope.label(bare, roster: [("18", nil)]), "Store 18")
        for issue in storeAnswer.issues where issue.id != "picker_scorecard" {
            XCTAssertFalse(issue.headline.contains("stores"), issue.headline)
        }
    }

    func testQuestionRouting() {
        var snapshot = AssistSnapshot(
            seeded: true,
            filters: DashboardFilters(),
            summaries: [:],
            rows: [:],
            history: [:],
            dataWindow: nil,
            rosterStores: [("304", "Harbor")],
            districts: ["03"],
            divisions: ["Jewel Osco"],
            operationsOMs: ["North OM"],
            now: Date(),
            warehouse: [:],
            packUploads: []
        )
        XCTAssertEqual(AssistComposer.resolve("whats wrong in store 304", snapshot: snapshot), .store("304"))
        XCTAssertEqual(AssistComposer.resolve("store 99999", snapshot: snapshot), .unknown)
        XCTAssertEqual(AssistComposer.resolve("pnr", snapshot: snapshot), .metric(.prepNotReady))
        XCTAssertEqual(AssistComposer.resolve("Which district is worst?", snapshot: snapshot), .children(.district))
        XCTAssertEqual(AssistComposer.resolve("What should we fix first?", snapshot: snapshot), .fix)
        snapshot.rows[.pickerScorecard] = [
            MetricRow(
                section: .pickerScorecard,
                division: "Shaws",
                operationsOM: "",
                storeNumber: "304",
                payload: ["pph": 60],
                textPayload: ["shopper_name": "Maria Lopez", "shopper_id": "mlopez"]
            ),
        ]
        XCTAssertEqual(AssistComposer.resolve("Maria", snapshot: snapshot), .shopper("Maria Lopez"))
    }

    func testNoPackAndNoScopeCopy() throws {
        let book = try loadPlaybook()
        var empty = fixtureSnapshot()
        empty.seeded = false
        let noPack = AssistComposer.answer(question: "What should we fix first?", snapshot: empty, book: book)
        XCTAssertEqual(noPack.noticeTitle, "No Heartbeat data on this device yet.")
        XCTAssertTrue(noPack.chips.isEmpty)
        XCTAssertNil(noPack.noticeAction)

        var none = fixtureSnapshot()
        none.filters.district = "99"
        none.summaries = Dictionary(uniqueKeysWithValues: MetricSection.dashboardCards.map {
            ($0, summary($0, .none, risk: 0, watch: 0, stores: 0, headline: nil))
        })
        let noScope = AssistComposer.answer(question: "What should we fix first?", snapshot: none, book: book)
        XCTAssertEqual(noScope.noticeTitle, "No Heartbeat numbers for District 99.")
        XCTAssertEqual(noScope.noticeAction?.clearsFilters, true)
        XCTAssertEqual(noScope.noticeAction?.destination, .dashboard)
        XCTAssertTrue(noScope.chips.isEmpty)
    }

    func testLostSalesWhyNamesOnlyFailingOTTAndPPH() throws {
        let book = try loadPlaybook()
        XCTAssertEqual(book.metric("lost_revenue")?.ownerName, "Lost Sales")
        XCTAssertEqual(book.metric("lost_reduced_capacity")?.ownerName, "Low capacity")
        XCTAssertEqual(book.metric("five_star_ott")?.ownerName, "Poor OTT")
        XCTAssertEqual(book.metric("pph")?.ownerName, "Low PPH")
        XCTAssertEqual(book.metric("lost_reduced_capacity")?.causes, ["five_star_ott", "pph", "dynacap"])
        XCTAssertEqual(book.metric("lost_reduced_capacity")?.causesConfirm, ["dynacap"])
        XCTAssertEqual(book.metric("five_star_ott")?.causesConfirm, ["schedule_quality", "pph"])

        let both = lostSalesSnapshot(ott: 80, pph: 58, under: 7.2, missed: 1_200, capacity: 50)
        let lost = try lostIssue("lost revenue", both, book)
        XCTAssertEqual(
            lost.why,
            "Why: low capacity, from late orders (OTT 80.0%) and slow picking (PPH 58.0)."
        )
        XCTAssertEqual(lost.causeChecks.map(\.question), [
            "Under-scheduled: yes, 1 of 1 stores over 5% (Sch vs Tgt)",
            "PPH 58.0, under 65; 1 of 1 stores under 65",
        ])
        XCTAssertEqual(lost.causeChecks.map(\.destination), [.scheduleQuality, .pph])
        XCTAssertFalse(lost.causeChecks.contains { $0.destination == .dynacap })
        XCTAssertFalse(lost.why?.contains("Dynacap") == true)
        XCTAssertTrue(lost.drivenBy.isEmpty)

        let ranked = AssistComposer.answer(question: "What should we fix first?", snapshot: both, book: book)
        let rankedIDs = ranked.issues.map(\.id)
        XCTAssertEqual(rankedIDs.filter { $0 == "lost_revenue" }.count, 1)
        XCTAssertEqual(rankedIDs.filter { $0 == "pph" }.count, 1)
        XCTAssertEqual(rankedIDs.filter { $0 == "five_star" }.count, 1)
        XCTAssertEqual(rankedIDs.filter { $0 == "dynacap" }.count, 1)
        XCTAssertTrue(ranked.issues.first { $0.id == "lost_revenue" }?.drivenBy.isEmpty == true)

        let ottOnly = lostSalesSnapshot(ott: 80, pph: 80, under: 7.2, missed: 1_200)
        let ottLost = try lostIssue("lost revenue", ottOnly, book)
        XCTAssertEqual(ottLost.why, "Why: low capacity, from late orders (OTT 80.0%).")
        XCTAssertEqual(ottLost.causeChecks.map(\.question), [
            "Under-scheduled: yes, 1 of 1 stores over 5% (Sch vs Tgt)",
        ])
        XCTAssertFalse(ottLost.causeChecks.contains { $0.question.contains("PPH") })

        let pphOnly = lostSalesSnapshot(ott: 96, pph: 58, under: 0, missed: 1_200)
        let pphLost = try lostIssue("lost revenue", pphOnly, book)
        XCTAssertEqual(pphLost.why, "Why: low capacity, from slow picking (PPH 58.0).")
        XCTAssertEqual(pphLost.causeChecks.map(\.question), [
            "PPH 58.0, under 65; 1 of 1 stores under 65",
        ])
        XCTAssertFalse(pphLost.causeChecks.contains { $0.question.contains("Under-scheduled") })

        let neither = lostSalesSnapshot(ott: 96, pph: 80, under: 0, missed: 1_200)
        let neitherLost = try lostIssue("lost revenue", neither, book)
        XCTAssertEqual(neitherLost.why, "Why: low capacity ($1,200 missed sales).")
        XCTAssertTrue(neitherLost.causeChecks.isEmpty)

        let healthyCapacity = lostSalesSnapshot(ott: 80, pph: 58, under: 7.2, missed: nil, missedPct: 1, capacity: 50)
        let hidden = try lostIssue("lost revenue", healthyCapacity, book)
        XCTAssertNil(hidden.why)
        XCTAssertTrue(hidden.causeChecks.isEmpty)

        let absent = lostSalesSnapshot(ott: 80, pph: 58, under: 7.2, missed: nil, capacity: 50)
        let absentLost = try lostIssue("lost revenue", absent, book)
        XCTAssertNil(absentLost.why)

        var store = lostSalesSnapshot(ott: 88, pph: 58, under: 7.2, missed: 500)
        store.filters.store = "304"
        let storeLost = try lostIssue("lost revenue", store, book)
        XCTAssertEqual(
            storeLost.why,
            "Why: low capacity, from late orders (OTT 88.0%) and slow picking (PPH 58.0)."
        )
        XCTAssertEqual(storeLost.causeChecks.map(\.question), [
            "Under-scheduled: yes (Sch vs Tgt 7.2%, over 5%)",
            "PPH 58, under 65",
        ])
    }

    func testAssistSourcesStayOnDeviceAndShareOneColumn() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let cards = try String(contentsOf: root.appendingPathComponent("FulfillmentHeartbeat/Models/AssistCards.swift"), encoding: .utf8)
        let view = try String(contentsOf: root.appendingPathComponent("FulfillmentHeartbeat/Views/AssistView.swift"), encoding: .utf8)
        for source in [cards, view] {
            XCTAssertFalse(source.contains("URLSession"))
            XCTAssertFalse(source.contains("PulseCloud"))
            XCTAssertFalse(source.contains("horizontalSizeClass"))
            XCTAssertFalse(source.contains("HubLayout.isPhone"))
            XCTAssertFalse(source.contains("UIDevice"))
        }
        XCTAssertTrue(view.contains("maxWidth: 712"))
        XCTAssertTrue(view.contains("What to do"))
        XCTAssertTrue(view.contains("More checks"))
        XCTAssertTrue(view.contains("issue.why"))
        XCTAssertTrue(view.contains("Go here first:"))
        XCTAssertTrue(view.contains("Visit these stores first"))
        XCTAssertTrue(view.contains("Your plan"))
        XCTAssertTrue(view.contains("What broke"))
        XCTAssertTrue(cards.contains("AssistPlan.steps"))
        XCTAssertTrue(view.contains("storeStopButton"))
        XCTAssertTrue(view.contains("accessibilityElement(children: .ignore)"))
        XCTAssertTrue(cards.contains("Fix these"))
        XCTAssertTrue(cards.contains("AssistRank.offBand"))
        XCTAssertFalse(view.contains("LazyVGrid"))
    }

    func testPriorityStoreOrderOnTheFixture() throws {
        let rows = priorityRows()
        let roster = priorityRoster()
        let open = DashboardFilters()
        let path = AssistPriority.candidates(section: .pickPath, rows: rows[.pickPath] ?? [], filters: open, roster: roster)
        XCTAssertEqual(path.map(\.store), ["12", "30", "10", "40", "20", "15"])
        XCTAssertEqual(path.map(\.health), [.risk, .risk, .risk, .risk, .watch, .watch])
        XCTAssertEqual(path.map(\.gap), [3, 3, 2, 1.5, 1, 0.5])
        XCTAssertFalse(path.contains { ["210", "239", "999"].contains($0.store) })

        let missing = AssistPriority.candidates(section: .missingItems, rows: rows[.missingItems] ?? [], filters: open, roster: roster)
        XCTAssertEqual(missing.map(\.store), ["10", "15", "40"])
        XCTAssertEqual(missing.map(\.health), [.risk, .risk, .watch])
        XCTAssertFalse(missing.contains { $0.store == "239" })

        let visits = AssistPriority.visitCandidates(sections: [.pickPath, .missingItems, .scheduleQuality], rows: rows, filters: open, roster: roster)
        XCTAssertEqual(visits.map(\.store), ["10", "15", "40", "20", "12", "30"])
        XCTAssertEqual(visits.map(\.missCount), [3, 3, 2, 2, 1, 1])
        XCTAssertEqual(visits[0].metrics, [.pickPath, .missingItems, .scheduleQuality])
        XCTAssertFalse(visits.contains { ["210", "239", "999"].contains($0.store) })

        let list = AssistPriority.list(section: .pickPath, rows: rows[.pickPath] ?? [], filters: open, roster: roster)
        XCTAssertEqual(list.shown.map(\.text), [
            "Store 12 Fox, District J3: 55.0% (goal 90%)",
            "Store 30 Cedar, District B2: 60.0% (goal 90%)",
            "Store 10 Alpha, District J3: 70.0% (goal 90%)",
            "Store 40 Delta, District A9: 75.0% (goal 90%)",
            "Store 20 Bravo, District J3: 80.0% (goal 90%)",
        ])
        XCTAssertLessThanOrEqual(list.shown[0].text.count, 48)
        XCTAssertEqual(list.seeAll?.text, "See all 6")
        XCTAssertNil(list.seeAll?.action.filters)
        XCTAssertEqual(list.seeAll?.action.destination, .pickPath)
        XCTAssertEqual(list.shown[0].action.destination, .pickPath)
        XCTAssertEqual(list.shown[0].action.filters?.store, "12")
        XCTAssertTrue(list.shown[0].action.accessibilityLabel.contains(list.shown[0].text))
        XCTAssertFalse(list.shown[0].action.accessibilityLabel.contains("\n"))

        let visitStops = AssistPriority.visitStops(sections: [.pickPath, .missingItems, .scheduleQuality], rows: rows, filters: open, roster: roster)
        XCTAssertEqual(visitStops.map { $0.action.filters?.store }, ["10", "15", "40", "20", "12"])
        XCTAssertEqual(visitStops[0].text, "Store 10 Alpha: Pick Path, Missing Items, Schedule")
        XCTAssertEqual(visitStops[0].action.destination, .dashboard)
        XCTAssertTrue(visitStops[0].action.accessibilityLabel.contains(visitStops[0].text))
    }

    func testPriorityStoresFollowRegionDistrictAndOM() {
        let rows = priorityRows()
        let roster = priorityRoster()
        var east = DashboardFilters()
        east.region = "East Region"
        let eastPath = AssistPriority.candidates(section: .pickPath, rows: rows[.pickPath] ?? [], filters: east, roster: roster)
        XCTAssertEqual(eastPath.map(\.store), ["12", "10", "40", "20", "15"])
        XCTAssertFalse(eastPath.contains { $0.store == "30" })
        let eastList = AssistPriority.list(section: .pickPath, rows: rows[.pickPath] ?? [], filters: east, roster: roster)
        XCTAssertEqual(eastList.shown[0].action.filters?.region, "East Region")
        XCTAssertEqual(eastList.shown[0].action.filters?.store, "12")
        XCTAssertNil(eastList.seeAll)
        let eastVisits = AssistPriority.visitCandidates(
            sections: [.pickPath, .missingItems, .scheduleQuality],
            rows: rows,
            filters: east,
            roster: roster
        )
        XCTAssertFalse(eastVisits.contains { $0.store == "30" })
        XCTAssertEqual(eastVisits.first?.store, "10")

        var district = DashboardFilters()
        district.district = "J3"
        let districtPath = AssistPriority.candidates(section: .pickPath, rows: rows[.pickPath] ?? [], filters: district, roster: roster)
        XCTAssertEqual(districtPath.map(\.store), ["12", "10", "20", "15"])

        var om = DashboardFilters()
        om.om = "North"
        let omPath = AssistPriority.candidates(section: .pickPath, rows: rows[.pickPath] ?? [], filters: om, roster: roster)
        XCTAssertEqual(omPath.map(\.store), ["20"])
    }

    func testSingleStoreScopeHidesPriorityLists() throws {
        let book = try loadPlaybook()
        var snapshot = prioritySnapshot()
        snapshot.filters.store = "10"
        let answer = AssistComposer.answer(question: "What should we fix first?", snapshot: snapshot, book: book)
        XCTAssertEqual(answer.headerTitle, "Fix these 3 first")
        XCTAssertTrue(answer.visitStores.isEmpty)
        XCTAssertTrue(answer.headerLines.allSatisfy { $0.stores.isEmpty && $0.seeAll == nil })
        for issue in answer.issues {
            XCTAssertTrue(issue.goHere.isEmpty, issue.id)
            XCTAssertNil(issue.seeAllStores, issue.id)
        }
        XCTAssertEqual(answer.plan.map(\.whereText), [
            "Store 10 Alpha, District J3",
            "Store 10 Alpha, District J3",
            "Store 10 Alpha, District J3",
        ])
        XCTAssertEqual(answer.plan.map(\.brokeText), [
            "Pick Path 70.0% (goal 90, risk line 80)",
            "Missing Items 8.0% (goal 5, risk line 6.5)",
            "Under-scheduled Tue 0.1%, Sat 0.1% (goal 5, risk line 5)",
        ])
        XCTAssertEqual(answer.plan[0].who, [
            "Shopper ID J. Smith 61.0% path, 38 PPH",
            "Shopper ID A. Lee 70.0% path, 55 PPH",
            "Shopper ID C. Kim 88.0% path",
        ])
        XCTAssertEqual(answer.plan[1].what, ["MILK 22.0%", "BREAD 15.0%", "EGGS 9.0%"])
        XCTAssertTrue(answer.plan[0].what.isEmpty)
        XCTAssertTrue(answer.plan[2].who.isEmpty)
        XCTAssertFalse(answer.plan[2].brokeText.contains("Mon"))
        XCTAssertEqual(answer.plan[0].actions.first?.filters?.store, "10")
        XCTAssertEqual(answer.plan[0].actions.first?.destination, .pickPath)
    }

    func testFixFirstAnswerNamesThePriorityStores() throws {
        let book = try loadPlaybook()
        let snapshot = prioritySnapshot()
        let answer = AssistComposer.answer(question: "What should we fix first?", snapshot: snapshot, book: book)
        XCTAssertEqual(answer.issues.prefix(3).map(\.id), ["pick_path", "missing_items", "schedule_quality"])
        XCTAssertEqual(answer.headerTitle, "Fix these 3 first")
        let path = try XCTUnwrap(answer.issues.first { $0.id == "pick_path" })
        XCTAssertEqual(path.goHere.map(\.text).first, "Store 12 Fox, District J3: 55.0% (goal 90%)")
        XCTAssertEqual(path.goHere.count, 5)
        XCTAssertEqual(path.seeAllStores?.text, "See all 6")
        XCTAssertEqual(path.seeAllStores?.action.destination, .pickPath)
        XCTAssertEqual(answer.headerLines.first?.stores.map(\.text), path.goHere.map(\.text))
        XCTAssertEqual(answer.headerLines.first?.seeAll?.text, "See all 6")
        XCTAssertEqual(answer.visitStores.map { $0.action.filters?.store }, ["10", "15", "40", "20", "12"])
        XCTAssertEqual(answer.visitStores.first?.text, "Store 10 Alpha: Pick Path, Missing Items, Schedule")
        XCTAssertEqual(answer.visitStores.first?.action.destination, .dashboard)
        XCTAssertEqual(answer.visitStores.first?.action.filters?.store, "10")
        let names = answer.issues.prefix(3).map { MetricSection(rawValue: $0.id)?.overviewLead ?? "" }
        XCTAssertEqual(answer.visitStores.first?.text, "Store 10 Alpha: \(names.joined(separator: ", "))")
        XCTAssertEqual(answer.plan.map(\.whereText), [
            "District J3",
            "Store 40 Delta, District A9",
            "Store 30 Cedar, District B2",
            "Store 10 Alpha, District J3",
            "Store 15 Echo, District J3",
        ])
    }

    func testPlanNamesShoppersItemsAndDaysFromTheFixture() throws {
        let book = try loadPlaybook()
        let snapshot = prioritySnapshot()
        let answer = AssistComposer.answer(question: "What should we fix first?", snapshot: snapshot, book: book)
        let plan = answer.plan
        XCTAssertEqual(plan.count, 5)
        XCTAssertEqual(plan[0].brokeText, "Pick Path 55.0% (goal 90, risk line 80)")
        XCTAssertEqual(plan[1].brokeText, "Pick Path 75.0% (goal 90, risk line 80)")
        XCTAssertEqual(plan[2].brokeText, "Pick Path 60.0% (goal 90, risk line 80)")
        XCTAssertEqual(plan[3].brokeText, "Missing Items 8.0% (goal 5, risk line 6.5)")
        XCTAssertEqual(plan[4].brokeText, "Missing Items 7.0% (goal 5, risk line 6.5)")

        let j3 = Set(["10", "12", "15", "20"])
        let j3Shoppers = rankedPathShoppers(snapshot.rows[.pickPathPicker] ?? [], stores: j3)
        XCTAssertEqual(plan[0].who.map(shopperName), Array(j3Shoppers.prefix(5)))
        XCTAssertEqual(plan[0].who, [
            "Shopper ID J. Smith 61.0% path, 38 PPH",
            "Shopper ID A. Lee 70.0% path, 55 PPH",
            "Shopper ID C. Kim 88.0% path",
        ])
        XCTAssertEqual(plan[1].who, ["Shopper ID Z. Worst 40.0% path"])
        XCTAssertTrue(plan[2].who.isEmpty)
        XCTAssertTrue(plan[2].what.isEmpty)
        XCTAssertFalse(plan[2].actions[0].question.localizedCaseInsensitiveContains("hour"))
        XCTAssertEqual(plan[2].actions[0].question, "Walk Store 30 Cedar for pick path today")
        XCTAssertEqual(plan[2].actions[0].owner, "Store manager")
        XCTAssertEqual(plan[2].actions[0].filters?.store, "30")
        XCTAssertEqual(plan[2].actions[0].destination, .pickPath)

        let store10Items = rankedItems(snapshot.rows[.preSubOOSItem] ?? [], store: "10")
        XCTAssertEqual(plan[3].what.map(itemName), store10Items)
        XCTAssertEqual(plan[3].what, ["MILK 22.0%", "BREAD 15.0%", "EGGS 9.0%"])
        XCTAssertFalse(plan[3].what.contains { $0.contains("SODA") || $0.contains("OTHER") })
        XCTAssertTrue(plan[3].who.isEmpty)
        XCTAssertEqual(plan[3].actions[0].question, "Check shelf and sub rules for MILK, BREAD, and EGGS")
        XCTAssertEqual(plan[3].actions[0].owner, "Store manager")
        XCTAssertEqual(plan[3].actions[0].destination, .preSubOOS)
        XCTAssertEqual(plan[3].actions[0].filters?.store, "10")
        XCTAssertEqual(plan[4].what, ["OTHER 50.0%"])
        XCTAssertEqual(rankedItems(snapshot.rows[.preSubOOSItem] ?? [], store: "15"), ["OTHER"])

        XCTAssertEqual(plan[0].actions[0].question, "Coach shopper IDs J. Smith and A. Lee on path today")
        XCTAssertEqual(plan[0].actions[0].owner, "Store manager")
        XCTAssertEqual(plan[0].actions[0].filters?.store, "10")
        XCTAssertEqual(plan[0].actions[0].destination, .pickPath)
        XCTAssertEqual(plan[0].actions[1].owner, "District leader")
        XCTAssertEqual(plan[0].actions[1].filters?.district, "J3")
        XCTAssertEqual(plan[0].actions[1].filters?.store, "")
        XCTAssertEqual(plan[0].actions[1].destination, .pickPath)
        XCTAssertEqual(plan[1].actions[0].question, "Coach shopper ID Z. Worst on path today")
        XCTAssertEqual(plan[1].actions[0].filters?.store, "40")
        XCTAssertEqual(plan[1].actions[0].destination, .pickPath)

        let joined = plan.flatMap { [$0.whereText, $0.brokeText] + $0.who + $0.what + $0.actions.map(\.question) }.joined(separator: "\n")
        XCTAssertFalse(joined.contains("·"))
        XCTAssertFalse(joined.localizedCaseInsensitiveContains("placeholder"))
        XCTAssertFalse(joined.contains("TBD"))

        let schedule = AssistComposer.answer(question: "Tell me more about Schedule", snapshot: snapshot, book: book)
        let days = rankedDays(snapshot.rows[.labor] ?? [], store: "10")
        XCTAssertEqual(days, ["Tue", "Sat", "Mon"])
        let broke = try XCTUnwrap(schedule.plan.first?.brokeText)
        XCTAssertTrue(broke.contains("\(days[0]) 0.1%"))
        XCTAssertTrue(broke.contains("\(days[1]) 0.1%"))
        XCTAssertFalse(broke.contains(days[2]))
        XCTAssertEqual(broke, "Under-scheduled Tue 0.1%, Sat 0.1% (goal 5, risk line 5)")
        XCTAssertEqual(schedule.plan.first?.whereText, "District J3")
        XCTAssertEqual(schedule.plan.first?.actions.first?.filters?.store, "10")
        XCTAssertEqual(schedule.plan.first?.actions.first?.destination, .scheduleQuality)
        XCTAssertTrue(schedule.plan.allSatisfy { $0.brokeText.hasPrefix("Under-scheduled") })
    }

    func testPlanDistrictScopeFiltersNamedDrivers() throws {
        let book = try loadPlaybook()
        var snapshot = prioritySnapshot()
        snapshot.filters.district = "J3"
        let answer = AssistComposer.answer(question: "What should we fix first?", snapshot: snapshot, book: book)
        let named = answer.plan.flatMap(\.who).joined(separator: " ")
        XCTAssertFalse(named.contains("Z. Worst"))
        XCTAssertFalse(answer.plan.contains { $0.whereText.contains("40") || $0.whereText.contains("30") || $0.whereText.contains("Cedar") || $0.whereText.contains("Delta") })
        let j3Shoppers = rankedPathShoppers(snapshot.rows[.pickPathPicker] ?? [], stores: ["10", "12", "15", "20"])
        XCTAssertEqual(answer.plan[0].who.map(shopperName), Array(j3Shoppers.prefix(5)))
        XCTAssertEqual(answer.plan[0].whereText, "Store 10 Alpha, District J3")
        let itemStep = try XCTUnwrap(answer.plan.first { !$0.what.isEmpty })
        XCTAssertEqual(itemStep.what.map(itemName), rankedItems(snapshot.rows[.preSubOOSItem] ?? [], store: "10"))
        XCTAssertFalse(answer.plan.contains { $0.what.contains { $0.contains("OTHER") } })

        let schedule = AssistComposer.answer(question: "Tell me more about Schedule", snapshot: snapshot, book: book)
        let broke = try XCTUnwrap(schedule.plan.first?.brokeText)
        let days = rankedDays(snapshot.rows[.labor] ?? [], store: "10")
        XCTAssertEqual(schedule.plan.first?.whereText, "Store 10 Alpha, District J3")
        XCTAssertTrue(broke.contains(days[0]))
        XCTAssertTrue(broke.contains(days[1]))
        XCTAssertFalse(broke.contains(days[2]))
        XCTAssertFalse(schedule.plan.contains { $0.whereText.contains("40") || $0.whereText.contains("B2") })
    }

    func testScheduleAmountAtOrUnderOneAndAHalfStaysUnscaled() {
        var snapshot = prioritySnapshot()
        snapshot.rows[.labor] = []
        snapshot.rows[.scheduleQuality] = [
            row(
                .scheduleQuality,
                ["schedule_efficiency_pct": 95, "over_schedule_pct": 0.56],
                store: "10",
                division: "Shaws",
                district: "J3",
                name: "Alpha"
            ),
        ]
        let steps = AssistPlan.steps(snapshot: snapshot, sections: [.scheduleQuality])
        XCTAssertEqual(steps.first?.brokeText, "Over-scheduled 0.6% (goal 5, risk line 5)")
        XCTAssertFalse(steps.contains { $0.brokeText.contains("56.3") })
    }

    func testSalesRiskLineKeepsItsSign() {
        var snapshot = prioritySnapshot()
        snapshot.rows[.sales] = [
            row(.sales, ["sales_yoy_pct": -4], store: "10", division: "Shaws", district: "J3", name: "Alpha"),
        ]
        let steps = AssistPlan.steps(snapshot: snapshot, sections: [.sales])
        let broke = steps.first?.brokeText ?? ""
        XCTAssertEqual(broke, "Sales -4.0% (goal 0, risk line -3)")
        XCTAssertTrue(broke.contains("risk line -3"))
        XCTAssertFalse(broke.contains("risk line 3"))
    }

    func testDriverWithoutAReadingEmitsNoLine() {
        var snapshot = prioritySnapshot()
        let blank = row(.scheduleQuality, [:], store: "10", division: "Shaws", district: "J3", name: "Alpha")
        let underOnly = row(.scheduleQuality, ["under_schedule_pct": 12], store: "10", division: "Shaws", district: "J3", name: "Alpha")
        XCTAssertNil(AssistCopy.storeReading(section: .scheduleQuality, row: blank))
        XCTAssertNotNil(AssistCopy.storeReading(section: .scheduleQuality, row: underOnly))
        snapshot.rows[.scheduleQuality] = [blank]
        let picks = AssistPriority.candidates(
            section: .scheduleQuality,
            rows: snapshot.rows[.scheduleQuality] ?? [],
            filters: snapshot.filters,
            roster: snapshot.rosterStores
        )
        XCTAssertTrue(picks.isEmpty)
        let steps = AssistPlan.steps(snapshot: snapshot, sections: [.scheduleQuality])
        XCTAssertTrue(steps.isEmpty)
        XCTAssertFalse(steps.contains { $0.brokeText.localizedCaseInsensitiveContains("off goal") })
    }

    func testDivisionOnlyFilterAppliesToPlanDrivers() throws {
        let book = try loadPlaybook()
        var snapshot = prioritySnapshot()
        snapshot.filters.division = "Shaws"
        let answer = AssistComposer.answer(question: "What should we fix first?", snapshot: snapshot, book: book)
        let blob = answer.plan.flatMap { step in
            [step.whereText, step.brokeText] + step.who + step.what + step.actions.map(\.question)
        }.joined(separator: "\n")
        XCTAssertFalse(blob.contains("Z. Worst"))
        XCTAssertFalse(blob.contains("Store 30"))
        XCTAssertFalse(blob.contains("Store 40"))
        XCTAssertFalse(blob.contains("Cedar"))
        XCTAssertFalse(blob.contains("Delta"))
        XCTAssertTrue(blob.contains("J. Smith"))
        XCTAssertTrue(answer.plan.contains { $0.what.contains { $0.contains("MILK") } })
    }

    func testUnitedSummaryCountsComeFromTheSlice() throws {
        let book = try loadPlaybook()
        var filters = DashboardFilters()
        filters.division = "United"
        var company: [MetricSection: SectionSummary] = [:]
        for section in MetricSection.dashboardCards {
            company[section] = summary(section, .risk, risk: 1_331, watch: 574, stores: 2_162, headline: 7.6)
        }
        var latest: [MetricSection: [MetricRow]] = [:]
        for section in AssistSnapshot.answerSections {
            latest[section] = []
        }
        var missing: [MetricRow] = []
        for index in 1...69 {
            missing.append(row(.missingItems, ["mi_pct": 8], store: String(1000 + index), division: "United", district: "U4", name: "U"))
        }
        missing.append(row(.missingItems, ["mi_pct": 2], store: "1999", division: "United", district: "U4", name: "U"))
        for index in 1...20 {
            missing.append(row(.missingItems, ["mi_pct": 9], store: String(index), division: "Shaws", district: "J3", name: "S"))
        }
        latest[.missingItems] = missing
        var stars: [MetricRow] = []
        for index in 1...25 {
            stars.append(row(.fiveStar, ["star_rating": 3], store: String(1000 + index), division: "United", district: "U4"))
        }
        for index in 26...70 {
            stars.append(row(.fiveStar, ["star_rating": 4.8], store: String(1000 + index), division: "United", district: "U4"))
        }
        latest[.fiveStar] = stars
        var labor: [MetricRow] = []
        for index in 1...30 {
            labor.append(row(.labor, ["target_vs_actual_pct": 6], store: String(1000 + index), division: "United", district: "U7"))
        }
        for index in 31...62 {
            labor.append(row(.labor, ["target_vs_actual_pct": 0], store: String(1000 + index), division: "United", district: "U7"))
        }
        latest[.labor] = labor
        latest[.pickPath] = (1...40).map {
            row(.pickPath, ["compliance_pct": 50], store: String($0), division: "Shaws", district: "J3")
        }
        let snapshot = AssistSnapshot.assemble(AssistSnapshot.Source(
            seeded: true,
            filters: filters,
            summaries: company,
            latest: latest,
            historyPool: [],
            focus: nil,
            rosterStores: [],
            districts: ["U4", "U7"],
            divisions: ["United", "Shaws"],
            operationsOMs: [],
            packUploads: [],
            now: Date()
        ))
        let answer = AssistComposer.answer(question: "What should we fix first?", snapshot: snapshot, book: book)
        // Printed goal stays 5.00. A store at 4.8 is good (line 4.5); the 25 stores at 3.0 stay the risk count, and Labor still outranks 5 Star.
        XCTAssertEqual(answer.headerLines.map(\.text), [
            "1. Missing Items: 69 of 70 stores",
            "2. Labor: 30 of 62 stores",
            "3. 5 Star: 25 of 70 stores",
        ])
        let blob = answer.headerLines.map(\.text).joined(separator: " ")
        XCTAssertFalse(blob.contains("1,331"))
        XCTAssertFalse(blob.contains("2,162"))
        XCTAssertFalse(blob.contains("1,175"))
        let watch = answer.issues.first { $0.id == "missing_items" }?.facts.first { $0.label == "On watch" }?.value
        XCTAssertEqual(watch, "0")
    }

    func testScheduleLinePrintsTheRankedMeasure() {
        let rows = [
            row(
                .scheduleQuality,
                ["schedule_efficiency_pct": 98.7, "staffing_efficiency_pct": 72.2],
                store: "8",
                district: "65"
            ),
        ]
        let list = AssistPriority.list(section: .scheduleQuality, rows: rows, filters: DashboardFilters(), roster: [])
        let text = list.shown.first?.text ?? ""
        XCTAssertTrue(text.contains("Staffing 72.2%"))
        XCTAssertTrue(text.contains("goal 90%"))
        XCTAssertFalse(text.contains("98.7"))
    }

    func testDenominatorExcludesStoresWithNoData() throws {
        let book = try loadPlaybook()
        var company: [MetricSection: SectionSummary] = [:]
        for section in MetricSection.dashboardCards {
            company[section] = summary(section, .risk, risk: 1_822, watch: 0, stores: 2_161, headline: 70)
        }
        var latest: [MetricSection: [MetricRow]] = [:]
        for section in AssistSnapshot.answerSections {
            latest[section] = []
        }
        latest[.scheduleQuality] = [
            row(.scheduleQuality, ["schedule_efficiency_pct": 70], store: "1"),
            row(.scheduleQuality, ["schedule_efficiency_pct": 60], store: "2"),
            row(.scheduleQuality, ["schedule_efficiency_pct": 95], store: "3"),
            row(.scheduleQuality, [:], store: "4"),
        ]
        let snapshot = AssistSnapshot.assemble(AssistSnapshot.Source(
            seeded: true,
            filters: DashboardFilters(),
            summaries: company,
            latest: latest,
            historyPool: [],
            focus: nil,
            rosterStores: [],
            districts: [],
            divisions: [],
            operationsOMs: [],
            packUploads: [],
            now: Date()
        ))
        let answer = AssistComposer.answer(question: "What should we fix first?", snapshot: snapshot, book: book)
        XCTAssertEqual(answer.headerLines.first?.text, "1. Schedule: 2 of 3 stores")
        XCTAssertFalse(answer.headerLines.contains { $0.text.contains("2,161") || $0.text.contains("of 4") })
    }

    func testDollarMetricHasNoPercentGoal() throws {
        let book = try loadPlaybook()
        var snapshot = fixtureSnapshot()
        snapshot.filters.store = "3493"
        snapshot.rosterStores = [("3493", nil)]
        for section in MetricSection.dashboardCards {
            snapshot.summaries[section] = summary(section, .good, risk: 0, watch: 0, stores: 1, headline: nil)
        }
        snapshot.summaries[.lostRevenue] = summary(.lostRevenue, .watch, risk: 0, watch: 1, stores: 1, headline: 539)
        snapshot.rows[.lostRevenue] = [
            row(.lostRevenue, ["lost_revenue": 539, "lost_revenue_pct": 3.8], store: "3493"),
        ]
        let answer = AssistComposer.answer(question: "What should this store fix first?", snapshot: snapshot, book: book)
        let header = try XCTUnwrap(answer.headerLines.first?.text)
        XCTAssertEqual(header, "1. Loss Revenue: $539")
        XCTAssertFalse(header.contains("%"))
        XCTAssertFalse(header.contains("goal"))
        let issue = try XCTUnwrap(answer.issues.first { $0.id == "lost_revenue" })
        XCTAssertFalse(issue.facts.contains { $0.label == "Goal" })
        XCTAssertFalse(issue.headline.contains("goal 3%"))
        XCTAssertFalse(issue.numberValue.contains("%"))
    }

    /// Healthy Loss Revenue prints the sheet percent beside the percent goal.
    /// A dollar headline must not sit next to "(goal 3% or less)", with or without a stored percent.
    func testHealthyLossRevenuePrintsPercentOrDropsTheGoal() throws {
        let book = try loadPlaybook()
        let withPercent = healthyLossSnapshot(storedPercent: 2.9)
        let healthy = AssistComposer.answer(question: "What's healthy?", snapshot: withPercent, book: book)
        let fact = try XCTUnwrap(healthy.healthyFacts.first { $0.label == "Loss Revenue" })
        XCTAssertEqual(fact.value, "2.9% (goal 3% or less)")
        assertNoDollarBesidePercentGoal(fact.value)
        let closest = try XCTUnwrap(healthy.noticeBody)
        XCTAssertTrue(closest.contains("Closest to its goal: Loss Revenue at 2.9% (goal 3% or less)"))
        assertNoDollarBesidePercentGoal(closest)
        for row in healthy.healthyFacts {
            assertNoDollarBesidePercentGoal(row.value)
        }

        let single = AssistComposer.answer(question: "How is loss revenue?", snapshot: withPercent, book: book)
        let issue = try XCTUnwrap(single.issues.first { $0.id == "lost_revenue" })
        XCTAssertEqual(issue.headline, "Loss Revenue is at goal: 2.9% (goal 3% or less)")
        assertNoDollarBesidePercentGoal(issue.headline)
        XCTAssertFalse(issue.headline.contains("$"))

        let withoutPercent = healthyLossSnapshot(storedPercent: nil)
        let open = AssistComposer.answer(question: "What's healthy?", snapshot: withoutPercent, book: book)
        let dollars = try XCTUnwrap(open.healthyFacts.first { $0.label == "Loss Revenue" })
        XCTAssertEqual(dollars.value, "$539")
        XCTAssertFalse(dollars.value.contains("(goal"))
        XCTAssertFalse(dollars.value.contains("%"))
        assertNoDollarBesidePercentGoal(dollars.value)
        for row in open.healthyFacts {
            assertNoDollarBesidePercentGoal(row.value)
        }
        if let notice = open.noticeBody {
            assertNoDollarBesidePercentGoal(notice)
            XCTAssertFalse(notice.contains("$539 (goal"))
        }

        let singleDollars = AssistComposer.answer(question: "How is loss revenue?", snapshot: withoutPercent, book: book)
        let dollarIssue = try XCTUnwrap(singleDollars.issues.first { $0.id == "lost_revenue" })
        XCTAssertEqual(dollarIssue.headline, "Loss Revenue is at goal: $539")
        XCTAssertFalse(dollarIssue.headline.contains("(goal"))
        XCTAssertFalse(dollarIssue.headline.contains("%"))
        assertNoDollarBesidePercentGoal(dollarIssue.headline)
    }

    func testTellMeMoreReturnsPlanCardsForThatMetric() throws {
        let book = try loadPlaybook()
        let snapshot = prioritySnapshot()
        let answer = AssistComposer.answer(question: "Tell me more about Pick Path", snapshot: snapshot, book: book)
        XCTAssertEqual(answer.issues.map(\.id), ["pick_path"])
        XCTAssertEqual(answer.plan.map(\.whereText), [
            "District J3",
            "Store 40 Delta, District A9",
            "Store 30 Cedar, District B2",
        ])
        XCTAssertTrue(answer.plan.allSatisfy { $0.brokeText.hasPrefix("Pick Path") })
        XCTAssertTrue(answer.plan.allSatisfy { $0.what.isEmpty })
    }

    func testCoachingChipRanksShoppersWorstFirst() throws {
        let book = try loadPlaybook()
        let snapshot = prioritySnapshot()
        let answer = AssistComposer.answer(question: "Which shoppers need coaching?", snapshot: snapshot, book: book)
        let ranked = rankedPathShoppers(snapshot.rows[.pickPathPicker] ?? [], stores: nil)
        XCTAssertEqual(answer.plan.map { shopperName($0.whereText) }, ranked)
        XCTAssertEqual(answer.plan.count, 4)
        let first = answer.plan[0]
        XCTAssertTrue(first.whereText.contains("Z. Worst"))
        XCTAssertTrue(first.whereText.contains("Store 40"))
        XCTAssertTrue(first.whereText.contains("District A9"))
        XCTAssertEqual(first.brokeText, "Path 40.0% (goal 90, risk line 80)")
        XCTAssertEqual(first.actions.count, 1)
        XCTAssertEqual(first.actions[0].question, "Coach shopper ID Z. Worst on path today")
        XCTAssertEqual(first.actions[0].owner, "Store manager")
        XCTAssertEqual(first.actions[0].destination, .pickPath)
        XCTAssertEqual(first.actions[0].filters?.store, "40")
        XCTAssertFalse(answer.plan.contains { $0.whereText.contains("P. Good") || $0.whereText.contains("I. Gnored") })

        var district = snapshot
        district.filters.district = "J3"
        let scoped = AssistComposer.answer(question: "Which shoppers need coaching?", snapshot: district, book: book)
        let j3 = rankedPathShoppers(snapshot.rows[.pickPathPicker] ?? [], stores: Set(["10", "12", "15", "20"]))
        XCTAssertEqual(scoped.plan.map { shopperName($0.whereText) }, j3)
        XCTAssertEqual(scoped.plan.first?.actions.first?.filters?.store, "10")
        XCTAssertFalse(scoped.plan.contains { $0.whereText.contains("Z. Worst") })
    }

    private func assertNoDollarBesidePercentGoal(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        if text.contains("$"), text.contains("(goal"), text.contains("%") {
            XCTFail("dollar amount sits beside a percent goal: \(text)", file: file, line: line)
        }
    }

    private func healthyLossSnapshot(storedPercent: Double?) -> AssistSnapshot {
        var snapshot = fixtureSnapshot()
        for section in MetricSection.dashboardCards {
            snapshot.summaries[section] = summary(section, .good, risk: 0, watch: 0, stores: 10, headline: 95)
        }
        var loss = summary(.lostRevenue, .good, risk: 0, watch: 0, stores: 10, headline: 539)
        loss.lostRevenuePct = storedPercent
        snapshot.summaries[.lostRevenue] = loss
        var payload: [String: Double] = ["lost_revenue": 539]
        if let storedPercent {
            payload["lost_revenue_pct"] = storedPercent
        }
        snapshot.rows[.lostRevenue] = [row(.lostRevenue, payload, store: "3493")]
        return snapshot
    }

    private func lostIssue(_ question: String, _ snapshot: AssistSnapshot, _ book: AssistPlaybook.File) throws -> AssistIssue {
        let answer = AssistComposer.answer(question: question, snapshot: snapshot, book: book)
        return try XCTUnwrap(answer.issues.first { $0.id == "lost_revenue" })
    }

    private func lostSalesSnapshot(
        ott: Double?,
        pph: Double?,
        under: Double?,
        missed: Double?,
        missedPct: Double? = nil,
        capacity: Double? = nil
    ) -> AssistSnapshot {
        var snapshot = fixtureSnapshot()
        snapshot.summaries[.lostRevenue] = summary(.lostRevenue, .risk, risk: 6, watch: 1, stores: 12, headline: 8)
        snapshot.summaries[.fiveStar] = summary(.fiveStar, .risk, risk: 4, watch: 0, stores: 12, headline: 3.2)
        snapshot.summaries[.pph] = summary(.pph, .risk, risk: 5, watch: 0, stores: 12, headline: pph ?? 70)
        snapshot.summaries[.dynacap] = summary(.dynacap, .risk, risk: 3, watch: 0, stores: 12, headline: capacity ?? 60)
        var lostPayload: [String: Double] = ["lost_revenue_pct": 8]
        if let missed { lostPayload["missed_sales"] = missed }
        if let missedPct { lostPayload["missed_sales_pct"] = missedPct }
        snapshot.rows[.lostRevenue] = [row(.lostRevenue, lostPayload)]
        if let ott {
            snapshot.rows[.fiveStar] = [row(.fiveStar, ["ott_pct": ott, "star_rating": 3.2])]
        } else {
            snapshot.rows[.fiveStar] = [row(.fiveStar, ["star_rating": 3.2])]
        }
        snapshot.rows[.pph] = [row(.pph, pph.map { ["pph": $0] } ?? [:])]
        if let under {
            snapshot.rows[.scheduleQuality] = [row(.scheduleQuality, ["under_schedule_pct": under])]
        } else {
            snapshot.rows[.scheduleQuality] = [row(.scheduleQuality, ["schedule_efficiency_pct": 91])]
        }
        if let capacity {
            snapshot.rows[.dynacap] = [row(.dynacap, ["dynacap_rate": capacity])]
        }
        return snapshot
    }

    func testCompanyScopeOpenAndSendAlwaysHaveAVisibleAnswer() throws {
        let book = try loadPlaybook()
        let company = DashboardFilters()
        XCTAssertEqual(AssistScope.level(company), .company)
        XCTAssertEqual(AssistScope.label(company, roster: []), "Total company")
        XCTAssertEqual(AssistExchange.openingQuestion(filters: company), "What should we fix first?")

        let snapshot = prioritySnapshot()
        XCTAssertTrue(AssistExchange.packReady(snapshot))
        let opened = AssistExchange.visible(AssistComposer.answer(
            question: AssistExchange.openingQuestion(filters: snapshot.filters),
            snapshot: snapshot,
            book: book
        ))
        XCTAssertTrue(AssistExchange.showsBody(opened))
        XCTAssertEqual(opened.headerTitle, "Fix these 3 first")
        XCTAssertFalse(opened.issues.isEmpty)

        let sent = AssistExchange.visible(AssistComposer.answer(
            question: "when is lunch",
            snapshot: snapshot,
            book: book
        ))
        XCTAssertTrue(AssistExchange.showsBody(sent))
        XCTAssertNotNil(sent.noticeTitle)

        var unloaded = snapshot
        unloaded.seeded = false
        unloaded.summaries = [:]
        XCTAssertFalse(AssistExchange.packReady(unloaded))
        let waiting = AssistComposer.answer(
            question: "What should we fix first?",
            snapshot: unloaded,
            book: book
        )
        XCTAssertEqual(waiting.noticeTitle, "No Heartbeat data on this device yet.")
        XCTAssertTrue(AssistExchange.showsBody(waiting))

        let loading = AssistExchange.loadingAnswer(scope: "Total company")
        XCTAssertEqual(loading.noticeTitle, "Loading data")
        XCTAssertTrue(AssistExchange.showsBody(loading))
        XCTAssertTrue(AssistExchange.showsBody(AssistExchange.visible(.empty)))

        var store = DashboardFilters()
        store.store = "3493"
        XCTAssertEqual(AssistExchange.openingQuestion(filters: store), "What should this store fix first?")
    }

    /// Company facts stay on disk. Assist still plans from the dashboard cards.
    func testCompanyAssistPlansFromDashboardRollupsWhenFactsAreReleased() async throws {
        XCTAssertEqual(AssistExchange.packWaitSeconds, 5)
        var summaries: [MetricSection: SectionSummary] = [:]
        for section in MetricSection.dashboardCards {
            let atRisk = section == .lostRevenue || section == .sales
            summaries[section] = summary(
                section,
                atRisk ? .risk : .good,
                risk: atRisk ? 40 : 0,
                watch: atRisk ? 8 : 0,
                stores: 2_000,
                headline: section == .sales ? 84_800_000 : (section == .lostRevenue ? 2_400_000 : 90)
            )
        }
        let source = AssistSnapshot.Source(
            seeded: true,
            filters: DashboardFilters(),
            summaries: summaries,
            latest: [:],
            historyPool: [],
            focus: nil,
            rosterStores: [],
            districts: [],
            divisions: [],
            operationsOMs: [],
            packUploads: [],
            now: Date()
        )
        XCTAssertTrue(AssistExchange.packReady(source))
        XCTAssertTrue(source.latest.isEmpty)
        let snapshot = AssistSnapshot.assemble(source)
        XCTAssertTrue(snapshot.rows.values.allSatisfy(\.isEmpty))
        XCTAssertEqual(snapshot.summaries[.lostRevenue]?.riskCount, 40)
        XCTAssertEqual(snapshot.summaries[.sales]?.headline ?? 0, 84_800_000, accuracy: 1)
        XCTAssertEqual(snapshot.summaries[.lostRevenue]?.health, .risk)
        let answer = await AssistSnapshot.compose(
            question: "What should we fix first?",
            source: source
        )
        XCTAssertFalse(answer.plan.isEmpty)
        XCTAssertNotEqual(answer.noticeTitle, "Loading data")
        XCTAssertTrue(answer.plan.contains { $0.whereText == MetricSection.lostRevenue.title })
        XCTAssertTrue(answer.plan.contains { $0.brokeText.contains("40 at risk") })
        XCTAssertFalse(answer.plan.contains { $0.whereText.contains("Store ") })
    }

    /// Opening Assist at Total company must not decode or copy the company fact plane.
    @MainActor
    func testCompanyAssistDoesNotDecodeTheCompanyFactSet() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("company-assist-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = HeartbeatStore(rootURL: root)
        var cards: [SectionSummary] = []
        for section in MetricSection.dashboardCards {
            let atRisk = section == .lostRevenue || section == .sales
            cards.append(summary(
                section,
                atRisk ? .risk : .good,
                risk: atRisk ? 40 : 0,
                watch: atRisk ? 8 : 0,
                stores: 2_000,
                headline: section == .sales ? 84_800_000 : (section == .lostRevenue ? 2_400_000 : 90)
            ))
        }
        store.installPaintedDashboardRollups(cards)

        let fact = MetricRow(
            section: .sales,
            division: "United",
            operationsOM: "OM",
            storeNumber: "22",
            storeName: "United 22",
            payload: ["sales_dollars": 63_554.66, "sales_yoy_pct": -79.47],
            textPayload: ["sales_grain": "store", "district": "U5", "data_window": "Week 31"]
        )
        let seat = PulseSeatPack.localURL(root: root, key: .company)
        try FileManager.default.createDirectory(at: seat.deletingLastPathComponent(), withIntermediateDirectories: true)
        try PulseSQLite.write(rows: [fact], uploads: [], seeded: true, chrome: nil, to: seat)
        try PulseSQLite.write(
            rows: [fact],
            uploads: [],
            seeded: true,
            chrome: nil,
            to: root.appendingPathComponent(PulseSQLite.fileName)
        )

        let reads = PulseSQLite.companyFactReadCount
        let decoded = PulseSQLite.decodedFactRowCount
        let sectionReads = PulseSQLite.sectionFactReadCount
        let touches = HeartbeatStore.residentFactTouchCount

        let source = AssistSnapshot.source(from: store, focus: nil)
        XCTAssertEqual(AssistScope.level(source.filters), .company)
        XCTAssertTrue(AssistExchange.packReady(source))
        XCTAssertTrue(source.latest.isEmpty)
        XCTAssertTrue(source.historyPool.isEmpty)
        XCTAssertEqual(source.summaries[.lostRevenue]?.riskCount, 40)
        XCTAssertEqual(source.summaries[.sales]?.headline ?? 0, 84_800_000, accuracy: 1)

        let snapshot = AssistSnapshot.assemble(source)
        XCTAssertTrue(snapshot.rows.values.allSatisfy(\.isEmpty))
        XCTAssertTrue(snapshot.warehouse.values.allSatisfy(\.isEmpty))

        let legacy = HeartbeatAssist.answer(
            "What should we fix first?",
            dest: .dashboard,
            store: store
        )
        XCTAssertFalse(legacy.isEmpty)
        XCTAssertFalse(legacy.contains("Store "))

        XCTAssertEqual(
            PulseSQLite.companyFactReadCount,
            reads,
            "company Assist must not read the company sqlite"
        )
        XCTAssertEqual(
            PulseSQLite.decodedFactRowCount,
            decoded,
            "company Assist must not decode fact rows"
        )
        XCTAssertEqual(
            PulseSQLite.sectionFactReadCount,
            sectionReads,
            "company Assist must not stream a fact section"
        )
        XCTAssertEqual(
            HeartbeatStore.residentFactTouchCount,
            touches,
            "company Assist must not copy the resident fact plane"
        )

        let answer = await AssistSnapshot.compose(
            question: "What should we fix first?",
            source: source
        )
        XCTAssertFalse(answer.plan.isEmpty)
        XCTAssertNotEqual(answer.noticeTitle, "Loading data")
        XCTAssertTrue(answer.plan.contains { $0.whereText == MetricSection.lostRevenue.title })
        XCTAssertFalse(answer.plan.contains { $0.whereText.contains("Store ") })
    }

    private func loadPlaybook() throws -> AssistPlaybook.File {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent("FulfillmentHeartbeat/Resources/AssistPlaybook.json")
        return try AssistPlaybook.load(from: Data(contentsOf: url))
    }

    private func fixtureSnapshot() -> AssistSnapshot {
        var summaries: [MetricSection: SectionSummary] = [
            .pickPath: summary(.pickPath, .risk, risk: 8, watch: 10, stores: 20, headline: 79.9),
            .missingItems: summary(.missingItems, .risk, risk: 10, watch: 4, stores: 20, headline: 7.6),
            .dynacap: summary(.dynacap, .good, risk: 30, watch: 0, stores: 40, headline: 67.9),
            .pph: summary(.pph, .watch, risk: 0, watch: 20, stores: 25, headline: 76),
            .pickerScorecard: summary(.pickerScorecard, .risk, risk: 24_671, watch: 0, stores: 2_000, headline: 24_671),
        ]
        for section in MetricSection.dashboardCards where summaries[section] == nil {
            summaries[section] = summary(section, .good, risk: 0, watch: 0, stores: 10, headline: 95)
        }
        var rows: [MetricSection: [MetricRow]] = [
            .pickPath: [row(.pickPath, ["compliance_pct": 80])],
            .missingItems: [row(.missingItems, ["mi_pct": 5.75])],
            .dynacap: [row(.dynacap, ["dynacap_rate": 64])],
            .pph: (301...320).map { row(.pph, ["pph": 74], store: String($0)) },
        ]
        for section in MetricSection.dashboardCards where rows[section] == nil {
            rows[section] = []
        }
        return AssistSnapshot(
            seeded: true,
            filters: DashboardFilters(),
            summaries: summaries,
            rows: rows,
            history: [:],
            dataWindow: "Week of Sep 14",
            rosterStores: [("304", "Harbor")],
            districts: ["03"],
            divisions: [],
            operationsOMs: [],
            now: Date(),
            warehouse: rows,
            packUploads: []
        )
    }

    private func input(
        _ section: MetricSection,
        _ health: Health,
        risk: Int,
        watch: Int,
        distance: Double,
        stores: Int
    ) -> AssistRank.Input {
        AssistRank.Input(
            section: section,
            health: health,
            risk: risk,
            watch: watch,
            distance: distance,
            storeCount: stores
        )
    }

    private func scored(
        _ section: MetricSection,
        score: Double,
        risk: Int,
        watch: Int,
        distance: Double
    ) -> AssistRank.Scored {
        AssistRank.Scored(
            section: section,
            health: .risk,
            risk: risk,
            watch: watch,
            distance: distance,
            storeCount: 10,
            score: score
        )
    }

    private func summary(
        _ section: MetricSection,
        _ health: Health,
        risk: Int,
        watch: Int,
        stores: Int,
        headline: Double?
    ) -> SectionSummary {
        SectionSummary(
            section: section,
            storeCount: stores,
            headline: headline,
            headlineLabel: "x",
            secondary: "",
            health: health,
            watchCount: watch,
            riskCount: risk,
            lastFilename: nil,
            lastUploadedAt: nil
        )
    }

    private func row(
        _ section: MetricSection,
        _ payload: [String: Double],
        store: String = "304",
        division: String = "",
        district: String = "",
        om: String = "",
        name: String? = nil,
        lostGrain: String? = nil,
        text extra: [String: String] = [:]
    ) -> MetricRow {
        var text: [String: String] = extra
        if !district.isEmpty { text["district"] = district }
        if let lostGrain { text["lost_grain"] = lostGrain }
        return MetricRow(
            section: section,
            division: division,
            operationsOM: om,
            storeNumber: store,
            storeName: name,
            payload: payload,
            textPayload: text
        )
    }

    private func shopperName(_ line: String) -> String {
        var text = line
        if let range = text.range(of: "Shopper ID ") {
            text = String(text[range.upperBound...])
        }
        if let range = text.range(of: " at ") {
            return String(text[..<range.lowerBound])
        }
        let words = text.split(separator: " ").map(String.init)
        return words.prefix { !$0.contains(where: \.isNumber) }.joined(separator: " ")
    }

    private func itemName(_ line: String) -> String {
        line.split(separator: " ").first.map(String.init) ?? line
    }

    private func rankedPathShoppers(_ rows: [MetricRow], stores: Set<String>?) -> [String] {
        rows.filter { row in
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            if store.isEmpty || HeartbeatMath.isIgnoredStore(store) { return false }
            if row.textPayload["lost_grain"] == "market" { return false }
            if let stores, !stores.contains(store) { return false }
            guard let value = row.number("compliance_pct") else { return false }
            let health = HeartbeatMath.band(value, good: HeartbeatMath.pickPathGoal, watch: HeartbeatMath.pickPathRisk)
            return health == .risk || health == .watch
        }.sorted { lhs, rhs in
            let left = lhs.number("compliance_pct") ?? 0
            let right = rhs.number("compliance_pct") ?? 0
            if left != right { return left < right }
            let storeOrder = HeartbeatFormat.storeOrder(lhs.storeNumber, rhs.storeNumber)
            if storeOrder { return true }
            if HeartbeatFormat.storeOrder(rhs.storeNumber, lhs.storeNumber) { return false }
            return (lhs.textPayload["shopper_name"] ?? "") < (rhs.textPayload["shopper_name"] ?? "")
        }.map { $0.textPayload["shopper_name"] ?? "" }
    }

    private func rankedItems(_ rows: [MetricRow], store: String) -> [String] {
        rows.filter { HeartbeatMath.canonicalStore($0.storeNumber) == store }
            .filter { ($0.number("presub_pct") ?? 0) > HeartbeatMath.missingItemsGoal }
            .sorted { lhs, rhs in
                let left = lhs.number("presub_pct") ?? 0
                let right = rhs.number("presub_pct") ?? 0
                if left != right { return left > right }
                return (lhs.textPayload["bpn"] ?? "") < (rhs.textPayload["bpn"] ?? "")
            }
            .prefix(3)
            .map { $0.textPayload["bpn"] ?? "" }
    }

    private func rankedDays(_ rows: [MetricRow], store: String) -> [String] {
        rows.filter {
            $0.textPayload["labor_grain"] == "day" && HeartbeatMath.canonicalStore($0.storeNumber) == store
        }.sorted { lhs, rhs in
            let left = lhs.number("under_schedule_pct") ?? 0
            let right = rhs.number("under_schedule_pct") ?? 0
            if left != right { return left > right }
            return (lhs.textPayload["day"] ?? "") < (rhs.textPayload["day"] ?? "")
        }.map { $0.textPayload["day"] ?? "" }
    }

    private func priorityRoster() -> [(number: String, name: String?)] {
        [
            ("10", "Alpha"), ("12", "Fox"), ("15", "Echo"), ("20", "Bravo"),
            ("30", "Cedar"), ("40", "Delta"), ("99", "Good"),
        ]
    }

    private func priorityRows() -> [MetricSection: [MetricRow]] {
        var rows: [MetricSection: [MetricRow]] = [
            .pickPath: [
                row(.pickPath, ["compliance_pct": 70], store: "10", division: "Shaws", district: "J3", name: "Alpha"),
                row(.pickPath, ["compliance_pct": 55], store: "12", division: "Shaws", district: "J3", name: "Fox"),
                row(.pickPath, ["compliance_pct": 85], store: "15", division: "Shaws", district: "J3", name: "Echo"),
                row(.pickPath, ["compliance_pct": 80], store: "20", division: "Shaws", district: "J3", om: "North", name: "Bravo"),
                row(.pickPath, ["compliance_pct": 60], store: "30", division: "United", district: "B2", name: "Cedar"),
                row(.pickPath, ["compliance_pct": 75], store: "40", division: "Jewel Osco", district: "A9", name: "Delta"),
                row(.pickPath, ["compliance_pct": 95], store: "99", division: "Shaws", district: "J3", name: "Good"),
                row(.pickPath, ["compliance_pct": 40], store: "210", division: "Shaws", district: "J3", name: "Ignored"),
                row(.pickPath, ["compliance_pct": 10], store: "999", division: "Shaws", district: "J3", name: "Market", lostGrain: "market"),
            ],
            .missingItems: [
                row(.missingItems, ["mi_pct": 8], store: "10", division: "Shaws", district: "J3", name: "Alpha"),
                row(.missingItems, ["mi_pct": 7], store: "15", division: "Shaws", district: "J3", name: "Echo"),
                row(.missingItems, ["mi_pct": 4], store: "20", division: "Shaws", district: "J3", om: "North", name: "Bravo"),
                row(.missingItems, ["mi_pct": 4], store: "12", division: "Shaws", district: "J3", name: "Fox"),
                row(.missingItems, ["mi_pct": 4], store: "30", division: "United", district: "B2", name: "Cedar"),
                row(.missingItems, ["mi_pct": 6.5], store: "40", division: "Jewel Osco", district: "A9", name: "Delta"),
                row(.missingItems, ["mi_pct": 40], store: "239", division: "Shaws", district: "J3", name: "Ignored"),
            ],
            .scheduleQuality: [
                row(.scheduleQuality, ["schedule_efficiency_pct": 95, "under_schedule_pct": 0.14], store: "10", division: "Shaws", district: "J3", name: "Alpha"),
                row(.scheduleQuality, ["schedule_efficiency_pct": 95, "under_schedule_pct": 0.11], store: "15", division: "Shaws", district: "J3", name: "Echo"),
                row(.scheduleQuality, ["schedule_efficiency_pct": 95, "under_schedule_pct": 0.08], store: "20", division: "Shaws", district: "J3", om: "North", name: "Bravo"),
                row(.scheduleQuality, ["schedule_efficiency_pct": 95], store: "12", division: "Shaws", district: "J3", name: "Fox"),
                row(.scheduleQuality, ["schedule_efficiency_pct": 95], store: "30", division: "United", district: "B2", name: "Cedar"),
                row(.scheduleQuality, ["schedule_efficiency_pct": 95], store: "40", division: "Jewel Osco", district: "A9", name: "Delta"),
            ],
            .pickPathPicker: [
                row(.pickPathPicker, ["compliance_pct": 61, "pph": 38], store: "10", division: "Shaws", district: "J3", name: "Alpha", text: ["shopper_name": "J. Smith"]),
                row(.pickPathPicker, ["compliance_pct": 70, "pph": 55], store: "10", division: "Shaws", district: "J3", name: "Alpha", text: ["shopper_name": "A. Lee"]),
                row(.pickPathPicker, ["compliance_pct": 88], store: "10", division: "Shaws", district: "J3", name: "Alpha", text: ["shopper_name": "C. Kim"]),
                row(.pickPathPicker, ["compliance_pct": 95], store: "10", division: "Shaws", district: "J3", name: "Alpha", text: ["shopper_name": "P. Good"]),
                row(.pickPathPicker, ["compliance_pct": 40], store: "40", division: "Jewel Osco", district: "A9", name: "Delta", text: ["shopper_name": "Z. Worst"]),
                row(.pickPathPicker, ["compliance_pct": 20], store: "210", division: "Shaws", district: "J3", name: "Ignored", text: ["shopper_name": "I. Gnored"]),
            ],
            .preSubOOSItem: [
                row(.preSubOOSItem, ["presub_pct": 22], store: "10", division: "Shaws", district: "J3", name: "Alpha", text: ["bpn": "MILK"]),
                row(.preSubOOSItem, ["presub_pct": 15], store: "10", division: "Shaws", district: "J3", name: "Alpha", text: ["bpn": "BREAD"]),
                row(.preSubOOSItem, ["presub_pct": 9], store: "10", division: "Shaws", district: "J3", name: "Alpha", text: ["bpn": "EGGS"]),
                row(.preSubOOSItem, ["presub_pct": 4], store: "10", division: "Shaws", district: "J3", name: "Alpha", text: ["bpn": "SODA"]),
                row(.preSubOOSItem, ["presub_pct": 50], store: "15", division: "Shaws", district: "J3", name: "Echo", text: ["bpn": "OTHER"]),
            ],
            .labor: [
                row(.labor, ["under_schedule_pct": 0.14], store: "10", division: "Shaws", district: "J3", name: "Alpha", text: ["labor_grain": "day", "day": "Tue"]),
                row(.labor, ["under_schedule_pct": 0.11], store: "10", division: "Shaws", district: "J3", name: "Alpha", text: ["labor_grain": "day", "day": "Sat"]),
                row(.labor, ["under_schedule_pct": 0.08], store: "10", division: "Shaws", district: "J3", name: "Alpha", text: ["labor_grain": "day", "day": "Mon"]),
            ],
        ]
        for section in MetricSection.dashboardCards where rows[section] == nil {
            rows[section] = []
        }
        return rows
    }

    private func prioritySnapshot() -> AssistSnapshot {
        let rows = priorityRows()
        var summaries: [MetricSection: SectionSummary] = [
            .pickPath: summary(.pickPath, .risk, risk: 4, watch: 2, stores: 7, headline: 75),
            .missingItems: summary(.missingItems, .risk, risk: 2, watch: 1, stores: 6, headline: 6),
            .scheduleQuality: summary(.scheduleQuality, .risk, risk: 1, watch: 2, stores: 6, headline: 88),
        ]
        for section in MetricSection.dashboardCards where summaries[section] == nil {
            summaries[section] = summary(section, .good, risk: 0, watch: 0, stores: 6, headline: 95)
        }
        return AssistSnapshot(
            seeded: true,
            filters: DashboardFilters(),
            summaries: summaries,
            rows: rows,
            history: [:],
            dataWindow: "Week of Sep 14",
            rosterStores: priorityRoster(),
            districts: ["J3", "A9", "B2"],
            divisions: ["Shaws", "Jewel Osco", "United"],
            operationsOMs: ["North"],
            now: Date(),
            warehouse: rows,
            packUploads: []
        )
    }
}
