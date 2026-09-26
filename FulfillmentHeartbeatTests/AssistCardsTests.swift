import XCTest
@testable import FulfillmentHeartbeat

final class AssistCardsTests: XCTestCase {
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
        XCTAssertEqual(AssistRank.offBand(section: .pph, row: row(.pph, ["pph": 74])), 1)
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

    func testPlaybookParsesAndEveryRankedMetricHasAFloorCheck() throws {
        let book = try loadPlaybook()
        XCTAssertFalse(book.shared.worstChildQuestion.isEmpty)
        let comparators = ["lt", "gt", "lte", "gte", "eq", "<", ">", "<=", ">="]
        for id in AssistPlaybook.rankedMetricIDs {
            let checks = book.metrics[id]?.checks ?? []
            XCTAssertFalse(checks.isEmpty, id)
            for check in checks {
                switch check.kind {
                case .floor:
                    XCTAssertTrue(check.question.hasSuffix("?"), check.question)
                    XCTAssertLessThanOrEqual(check.question.count, AssistCopy.actionLimit, check.question)
                    let first = check.question.split(separator: " ").first.map(String.init)?.lowercased()
                    XCTAssertTrue(
                        ["is", "are", "do", "does", "has", "have", "can"].contains(first ?? ""),
                        check.question
                    )
                    XCTAssertFalse(check.question.lowercased().contains("call-off"), check.question)
                    XCTAssertFalse(check.question.lowercased().contains("no-show"), check.question)
                case .auto:
                    XCTAssertFalse(check.field?.isEmpty ?? true, check.id)
                    XCTAssertTrue(comparators.contains(check.comparator ?? ""), check.id)
                    XCTAssertNotNil(check.threshold, check.id)
                    XCTAssertFalse(check.answerTrue?.isEmpty ?? true, check.id)
                    XCTAssertFalse(check.answerFalse?.isEmpty ?? true, check.id)
                }
            }
        }
        XCTAssertNotNil(book.metrics["picker_scorecard"])
    }

    func testOwnerSeedsFloorAndAutoChecks() throws {
        let book = try loadPlaybook()
        let presub = try XCTUnwrap(book.metrics["pre_sub_oos"]).checks
        XCTAssertEqual(presub.prefix(3).map(\.kind), [.floor, .floor, .floor])
        XCTAssertEqual(Array(presub.prefix(3).map(\.question)), [
            "Are shoppers using radios?",
            "Is the whole store using radios?",
            "Is store PI (perpetual inventory) accurate?",
        ])

        let pph = try XCTUnwrap(book.metrics["pph"]).checks
        XCTAssertEqual(pph[0].kind, .floor)
        XCTAssertEqual(
            pph[0].question,
            "Are shoppers picking 30 items within the first 15 minutes of their run/shift start?"
        )
        XCTAssertEqual(pph[1].kind, .auto)
        XCTAssertEqual(pph[1].field, "pph")
        XCTAssertEqual(pph[1].comparator, "lt")
        XCTAssertEqual(pph[1].threshold, 65)
        XCTAssertEqual(HeartbeatMath.pphGoal, 80, "The owner floor stays in the playbook.")

        let stars = try XCTUnwrap(book.metrics["five_star"]).checks
        let under = try XCTUnwrap(stars.first { $0.id == "ott_under_scheduled" })
        XCTAssertEqual(under.kind, .auto)
        XCTAssertEqual(under.showWhen, "weakestOTT")
        XCTAssertEqual(under.field, "under_schedule_pct")
        XCTAssertEqual(under.aliases, ["under_scheduled"])
        XCTAssertEqual(under.source, "schedule_quality")
        XCTAssertEqual(under.comparator, "gt")
        XCTAssertEqual(under.threshold ?? 0, 0.05, accuracy: 0.0001)
        XCTAssertEqual(under.answerTrue, "Under-scheduled: yes")
        let ottPPH = try XCTUnwrap(stars.first { $0.id == "ott_pph_under_65" })
        XCTAssertEqual(ottPPH.kind, .auto)
        XCTAssertEqual(ottPPH.field, "pph")
        XCTAssertEqual(ottPPH.source, "pph")
        XCTAssertEqual(ottPPH.comparator, "lt")
        XCTAssertEqual(ottPPH.threshold, 65)
        XCTAssertEqual(ottPPH.showWhen, "weakestOTT")
        let ottIndex = try XCTUnwrap(stars.firstIndex { $0.id == "ott_under_scheduled" })
        let toteIndex = try XCTUnwrap(stars.firstIndex { $0.id == "weak_ott" })
        XCTAssertLessThan(ottIndex, toteIndex)
    }

    func testAutoCheckRendersScopeValue() {
        let pph = pphAutoCheck()
        XCTAssertEqual(
            AssistAutoCheck.sentence(pph, rows: [.pph: [row(.pph, ["pph": 58])]], fallbackSection: .pph),
            "PPH 58 - under 65"
        )
        XCTAssertEqual(
            AssistAutoCheck.sentence(pph, rows: [.pph: [row(.pph, ["pph": 58.4])]], fallbackSection: .pph),
            "PPH 58.4 - under 65"
        )
        XCTAssertEqual(
            AssistAutoCheck.sentence(pph, rows: [.pph: [row(.pph, ["pph": 72])]], fallbackSection: .pph),
            "PPH 72 - at or above 65"
        )
        XCTAssertEqual(
            AssistAutoCheck.sentence(pph, rows: [.pph: [row(.pph, ["pph": 65])]], fallbackSection: .pph),
            "PPH 65 - at or above 65"
        )
        XCTAssertEqual(
            AssistAutoCheck.sentence(
                pph,
                rows: [.pph: [row(.pph, ["pph": 50], store: "304"), row(.pph, ["pph": 66], store: "305")]],
                fallbackSection: .pph
            ),
            "PPH 58 - under 65"
        )
        XCTAssertEqual(
            AssistAutoCheck.sentence(pph, rows: [.pph: [row(.pph, ["pure_pph": 58])]], fallbackSection: .pph),
            "PPH 58 - under 65"
        )

        let under = underScheduledCheck()
        XCTAssertEqual(
            AssistAutoCheck.sentence(
                under,
                rows: [.scheduleQuality: [row(.scheduleQuality, ["under_schedule_pct": 6.2])]],
                fallbackSection: .fiveStar
            ),
            "Under-scheduled: yes"
        )
        XCTAssertEqual(
            AssistAutoCheck.sentence(
                under,
                rows: [.scheduleQuality: [row(.scheduleQuality, ["under_schedule_pct": 3])]],
                fallbackSection: .fiveStar
            ),
            "Under-scheduled: yes"
        )
        XCTAssertEqual(
            AssistAutoCheck.sentence(
                under,
                rows: [.scheduleQuality: [row(.scheduleQuality, ["under_scheduled": 0])]],
                fallbackSection: .fiveStar
            ),
            "Under-scheduled: no"
        )
        XCTAssertEqual(
            AssistAutoCheck.sentence(
                under,
                rows: [.scheduleQuality: [row(.scheduleQuality, ["under_schedule_pct": 0.04])]],
                fallbackSection: .fiveStar
            ),
            "Under-scheduled: no"
        )
    }

    func testAutoCheckHidesWhenFieldIsMissing() {
        let pph = pphAutoCheck()
        XCTAssertNil(AssistAutoCheck.sentence(pph, rows: [:], fallbackSection: .pph))
        XCTAssertNil(
            AssistAutoCheck.sentence(
                pph,
                rows: [.pph: [row(.pph, ["orders": 12])]],
                fallbackSection: .pph
            )
        )
        XCTAssertNil(
            AssistAutoCheck.sentence(
                pph,
                rows: [.pph: [row(.pph, ["pph": 58], store: "210")]],
                fallbackSection: .pph
            )
        )
        XCTAssertNil(
            AssistAutoCheck.sentence(
                pph,
                rows: [.fiveStar: [row(.fiveStar, ["pph": 58])]],
                fallbackSection: .fiveStar
            )
        )
        var unknown = pph
        unknown.comparator = "around"
        XCTAssertNil(
            AssistAutoCheck.sentence(
                unknown,
                rows: [.pph: [row(.pph, ["pph": 58])]],
                fallbackSection: .pph
            )
        )

        let under = underScheduledCheck()
        XCTAssertNil(
            AssistAutoCheck.sentence(
                under,
                rows: [.scheduleQuality: [row(.scheduleQuality, ["schedule_efficiency_pct": 91])]],
                fallbackSection: .fiveStar
            )
        )
        XCTAssertNil(
            AssistAutoCheck.sentence(
                under,
                rows: [.scheduleQuality: [row(.scheduleQuality, ["under_adherence_pct": 8])]],
                fallbackSection: .fiveStar
            )
        )
    }

    func testResolutionCardsUseOwnerChecksAndHideMissingAutoFields() throws {
        let book = try loadPlaybook()
        var presub = fixtureSnapshot()
        presub.summaries[.preSubOOS] = summary(.preSubOOS, .risk, risk: 4, watch: 1, stores: 10, headline: 8)
        presub.rows[.preSubOOS] = [row(.preSubOOS, ["mi_pct": 8])]
        let presubAnswer = AssistComposer.answer(question: "pre sub", snapshot: presub, book: book)
        let presubQuestions = presubAnswer.issues.first { $0.id == "pre_sub_oos" }?.checks.map(\.question) ?? []
        XCTAssertEqual(Array(presubQuestions.prefix(3)), [
            "Are shoppers using radios?",
            "Is the whole store using radios?",
            "Is store PI (perpetual inventory) accurate?",
        ])

        var low = fixtureSnapshot()
        low.summaries[.pph] = summary(.pph, .risk, risk: 2, watch: 0, stores: 2, headline: 58)
        low.rows[.pph] = [
            row(.pph, ["pph": 50], store: "304"),
            row(.pph, ["pph": 66], store: "305"),
        ]
        let lowAnswer = AssistComposer.answer(question: "pph", snapshot: low, book: book)
        let lowQuestions = lowAnswer.issues.first { $0.id == "pph" }?.checks.map(\.question) ?? []
        XCTAssertEqual(
            lowQuestions.first,
            "Are shoppers picking 30 items within the first 15 minutes of their run/shift start?"
        )
        XCTAssertTrue(lowQuestions.contains("PPH 58 - under 65"))

        var missing = low
        missing.rows[.pph] = [row(.pph, ["orders": 10], store: "304")]
        let missingAnswer = AssistComposer.answer(question: "pph", snapshot: missing, book: book)
        let missingQuestions = missingAnswer.issues.first { $0.id == "pph" }?.checks.map(\.question) ?? []
        XCTAssertEqual(missingQuestions.first, lowQuestions.first)
        XCTAssertFalse(missingQuestions.contains { $0.contains("65") })
        XCTAssertFalse(missingQuestions.contains { $0.contains("58") })

        var ott = fixtureSnapshot()
        ott.summaries[.fiveStar] = summary(.fiveStar, .risk, risk: 3, watch: 0, stores: 3, headline: 3.2)
        ott.rows[.fiveStar] = [row(.fiveStar, ["ott_pct": 80, "star_rating": 3.2])]
        ott.rows[.scheduleQuality] = [row(.scheduleQuality, ["under_schedule_pct": 6.2])]
        ott.rows[.pph] = [row(.pph, ["pph": 58])]
        let ottAnswer = AssistComposer.answer(question: "ott", snapshot: ott, book: book)
        let ottQuestions = ottAnswer.issues.first { $0.id == "five_star" }?.checks.map(\.question) ?? []
        XCTAssertEqual(ottQuestions.first, "Under-scheduled: yes")
        XCTAssertTrue(ottQuestions.contains("PPH 58 - under 65"))

        var ottMissing = ott
        ottMissing.rows[.scheduleQuality] = [row(.scheduleQuality, ["schedule_efficiency_pct": 91])]
        let ottMissingAnswer = AssistComposer.answer(question: "ott", snapshot: ottMissing, book: book)
        let ottMissingQuestions = ottMissingAnswer.issues.first { $0.id == "five_star" }?.checks.map(\.question) ?? []
        XCTAssertFalse(ottMissingQuestions.contains { $0.hasPrefix("Under-scheduled") })
        XCTAssertTrue(ottMissingQuestions.contains("PPH 58 - under 65"))
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

    func testLostSalesShowsOTTAndPPHCausesOnlyWhenTheyFail() throws {
        let book = try loadPlaybook()
        XCTAssertEqual(book.metrics["lost_revenue"]?.causes, ["dynacap"])
        XCTAssertEqual(book.metrics["dynacap"]?.causes, ["five_star", "pph"])
        XCTAssertEqual(book.metrics["dynacap"]?.causeLabel, "Low capacity")
        XCTAssertEqual(book.metrics["five_star"]?.causeLabel, "Poor OTT")
        XCTAssertEqual(book.metrics["pph"]?.causeLabel, "Low PPH")
        let ottCheck = try XCTUnwrap(book.metrics["five_star"]?.checks.first { $0.id == "ott_vs_target" })
        XCTAssertEqual(ottCheck.threshold, 95)
        XCTAssertEqual(HeartbeatMath.pphGoal, 80)

        let failing = lostSalesSnapshot(ott: 80, pph: 58, under: 6.2, capacity: 50)
        let lost = try lostIssue("lost revenue", failing, book)
        XCTAssertEqual(
            lost.why,
            "Low capacity, 50 pieces an hour. Poor OTT, Under-scheduled, and Low PPH"
        )
        XCTAssertEqual(lost.causeChecks.map(\.question), [
            "Capacity 50 - under 65",
            "OTT 80 - under 95",
            "Under-scheduled: yes",
            "PPH 58 - under 65",
        ])
        XCTAssertEqual(lost.causeChecks.map(\.destination), [.dynacap, .fiveStar, .scheduleQuality, .pph])
        XCTAssertTrue(lost.drivenBy.isEmpty)

        let ranked = AssistComposer.answer(question: "What should we fix first?", snapshot: failing, book: book)
        let rankedIDs = ranked.issues.map(\.id)
        XCTAssertEqual(rankedIDs.filter { $0 == "lost_revenue" }.count, 1)
        XCTAssertEqual(rankedIDs.filter { $0 == "pph" }.count, 1)
        XCTAssertEqual(rankedIDs.filter { $0 == "five_star" }.count, 1)
        XCTAssertEqual(rankedIDs.filter { $0 == "dynacap" }.count, 1)
        let linked = try XCTUnwrap(ranked.issues.first { $0.id == "lost_revenue" })
        XCTAssertEqual(linked.drivenBy.map(\.text), [
            "Driven by Dynacap",
            "Driven by 5 Star",
            "Driven by PPH",
        ])
        XCTAssertEqual(linked.drivenBy.map(\.issueID), ["dynacap", "five_star", "pph"])
        XCTAssertTrue(linked.causeChecks.contains { $0.question == "PPH 58 - under 65" })
        XCTAssertTrue(linked.causeChecks.contains { $0.question == "OTT 80 - under 95" })

        let healthy = lostSalesSnapshot(ott: 96, pph: 72, under: 0, capacity: 70)
        let healthyLost = try lostIssue("lost revenue", healthy, book)
        XCTAssertNil(healthyLost.why)
        XCTAssertTrue(healthyLost.causeChecks.isEmpty)
        let healthyRanked = AssistComposer.answer(question: "What should we fix first?", snapshot: healthy, book: book)
        XCTAssertTrue(healthyRanked.issues.contains { $0.id == "lost_revenue" })
        XCTAssertTrue(healthyRanked.issues.contains { $0.id == "pph" })
        let healthyLink = try XCTUnwrap(healthyRanked.issues.first { $0.id == "lost_revenue" })
        XCTAssertTrue(healthyLink.drivenBy.isEmpty)
        XCTAssertFalse(healthyLink.causeChecks.contains { $0.question.contains("OTT") || $0.question.contains("PPH") })

        let pphOnly = lostSalesSnapshot(ott: 96, pph: 58, under: 0, capacity: 70)
        let pphLost = try lostIssue("lost revenue", pphOnly, book)
        XCTAssertEqual(pphLost.why, "Low PPH")
        XCTAssertEqual(pphLost.causeChecks.map(\.question), ["PPH 58 - under 65"])
        XCTAssertFalse(pphLost.causeChecks.contains { $0.question.contains("OTT") })

        let missingCapacity = lostSalesSnapshot(ott: 80, pph: 58, under: 0, capacity: nil, pickupOnly: 40)
        let missing = try lostIssue("lost revenue", missingCapacity, book)
        XCTAssertEqual(missing.why, "Low capacity. Poor OTT and Low PPH")
        XCTAssertFalse(missing.why?.contains("pieces") ?? true)
        XCTAssertFalse(missing.why?.contains("40") ?? true)
        XCTAssertEqual(missing.causeChecks.map(\.question), [
            "OTT 80 - under 95",
            "PPH 58 - under 65",
        ])
        XCTAssertFalse(missing.causeChecks.contains { $0.question.hasPrefix("Capacity") })
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
        XCTAssertTrue(view.contains("Resolution"))
        XCTAssertTrue(view.contains("Why"))
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
        capacity: Double?,
        pickupOnly: Double? = nil
    ) -> AssistSnapshot {
        var snapshot = fixtureSnapshot()
        snapshot.summaries[.lostRevenue] = summary(.lostRevenue, .risk, risk: 6, watch: 1, stores: 12, headline: 8)
        snapshot.summaries[.fiveStar] = summary(.fiveStar, .risk, risk: 4, watch: 0, stores: 12, headline: 3.2)
        snapshot.summaries[.pph] = summary(.pph, .risk, risk: 5, watch: 0, stores: 12, headline: pph ?? 70)
        snapshot.summaries[.dynacap] = summary(.dynacap, .risk, risk: 3, watch: 0, stores: 12, headline: capacity ?? 60)
        snapshot.rows[.lostRevenue] = [row(.lostRevenue, ["lost_revenue_pct": 8])]
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
        } else if let pickupOnly {
            snapshot.rows[.dynacap] = [row(.dynacap, ["pickup_capacity": pickupOnly])]
        } else {
            snapshot.rows[.dynacap] = [row(.dynacap, [:])]
        }
        return snapshot
    }

    private func pphAutoCheck() -> AssistPlaybook.Check {
        AssistPlaybook.Check(
            id: "pph_under_65",
            kind: .auto,
            field: "pph",
            aliases: ["pure_pph"],
            source: "pph",
            comparator: "lt",
            threshold: 65,
            answerTrue: "PPH {value} - under {threshold}",
            answerFalse: "PPH {value} - at or above {threshold}"
        )
    }

    private func underScheduledCheck() -> AssistPlaybook.Check {
        AssistPlaybook.Check(
            id: "ott_under_scheduled",
            kind: .auto,
            field: "under_schedule_pct",
            aliases: ["under_scheduled"],
            source: "schedule_quality",
            comparator: "gt",
            threshold: 0.05,
            answerTrue: "Under-scheduled: yes",
            answerFalse: "Under-scheduled: no"
        )
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
            .pph: [row(.pph, ["pph": 77.6])],
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
