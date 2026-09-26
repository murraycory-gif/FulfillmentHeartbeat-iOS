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
        XCTAssertEqual(allowed.count, 13)
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
        XCTAssertTrue(cards.contains("Fix these"))
        XCTAssertFalse(view.contains("LazyVGrid"))
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

    private func row(_ section: MetricSection, _ payload: [String: Double], store: String = "304") -> MetricRow {
        MetricRow(
            section: section,
            division: "",
            operationsOM: "",
            storeNumber: store,
            payload: payload
        )
    }
}
