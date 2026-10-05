import XCTest
@testable import FulfillmentHeartbeat

final class ScheduleCheckTests: XCTestCase {
    func testScheduleCheckActionGate() {
        XCTAssertFalse(ScheduleCheckMath.qualifies(sales: nil, under: 100, fourUnder: 20, over: 20))
        XCTAssertFalse(ScheduleCheckMath.qualifies(sales: 29_999.99, under: 50, fourUnder: 50, over: 50))
        XCTAssertTrue(ScheduleCheckMath.qualifies(sales: 30_000, under: 10, fourUnder: 0, over: 0))
        XCTAssertFalse(ScheduleCheckMath.qualifies(sales: 30_000, under: 9.99, fourUnder: 9, over: 14.99))
        XCTAssertFalse(ScheduleCheckMath.qualifies(sales: 30_000, under: 0, fourUnder: 9, over: 0))
        XCTAssertTrue(ScheduleCheckMath.qualifies(sales: 30_000, under: 0, fourUnder: 9.01, over: 0))
        XCTAssertTrue(ScheduleCheckMath.qualifies(sales: 30_000, under: 0, fourUnder: 0, over: 15))
        XCTAssertFalse(ScheduleCheckMath.qualifies(sales: 30_000, under: nil, fourUnder: nil, over: nil))

        let unscheduled = ScheduleStore(store: "117", sales: 40_000, under: 100, over: 0, eff: 0, fourUnder: 0)
        XCTAssertTrue(unscheduled.notScheduled)
        XCTAssertTrue(ScheduleCheckMath.qualifies(unscheduled))
        XCTAssertEqual(ScheduleCheckMath.effHealth(unscheduled.eff, notScheduled: true), .none)
        XCTAssertEqual(ScheduleCheckMath.percentHealth(unscheduled.under, notScheduled: true), .none)
        XCTAssertEqual(ScheduleCheckMath.percentHealth(100, notScheduled: false), .risk)
        XCTAssertEqual(ScheduleCheckMath.effHealth(90, notScheduled: false), .good)
        XCTAssertEqual(ScheduleCheckMath.effHealth(89.99, notScheduled: false), .risk)
        XCTAssertEqual(ScheduleCheckMath.percentHealth(0, notScheduled: false), .good)
    }

    func testScheduleCheckScopeFilter() {
        let pack = companyFixture()
        let regions = ScheduleCheckMath.rankedRegions(pack: pack, filters: DashboardFilters())
        XCTAssertEqual(regions.map(\.scope).reduce(0, +), 2163)
        XCTAssertEqual(regions.map(\.underCount).reduce(0, +), 2008)
        XCTAssertEqual(regions.map(\.overCount).reduce(0, +), 1566)
        let east = regions.first { $0.region == "East Region" }
        XCTAssertEqual(east?.scope, 612)
        XCTAssertEqual(HeartbeatFormat.pct(east?.under), "10.00%")

        var eastOnly = DashboardFilters()
        eastOnly.region = "East Region"
        XCTAssertEqual(ScheduleCheckMath.summary(pack: pack, filters: eastOnly).scope, 612)
        XCTAssertFalse(ScheduleCheckMath.summary(pack: pack, filters: eastOnly).usesMarketLook)

        var district = DashboardFilters()
        district.district = "B5"
        let one = ScheduleCheckMath.summary(pack: pack, filters: district)
        XCTAssertEqual(one.scope, 1)
        XCTAssertFalse(one.usesMarketLook)
        XCTAssertEqual(HeartbeatFormat.pct(one.under), "10.00%")
        XCTAssertNotEqual(HeartbeatFormat.pct(one.under), "41.07%")
    }

    func testScheduleCheckCompanyUsesMarketLookWhenUnfiltered() {
        let pack = companyFixture()
        let card = ScheduleCheckMath.summary(pack: pack, filters: DashboardFilters())
        XCTAssertTrue(card.usesMarketLook)
        XCTAssertEqual(HeartbeatFormat.pct(card.under), "41.07%")
        XCTAssertEqual(HeartbeatFormat.pct(card.over), "4.03%")
        XCTAssertEqual(HeartbeatFormat.pct(card.pch), "70.28%")
        XCTAssertEqual(HeartbeatFormat.pct(card.eff), "64.97%")
        XCTAssertEqual(card.underCount, 2008)
        XCTAssertEqual(card.overCount, 1566)
        XCTAssertEqual(card.scope, 2163)
        XCTAssertEqual(HeartbeatFormat.pct(card.storeUnder), "9.28%")
        XCTAssertNotEqual(HeartbeatFormat.pct(card.storeUnder), "41.07%")
        XCTAssertNotNil(ScheduleCheckMath.companyMarketNote(card, filters: DashboardFilters()))

        var shaws = DashboardFilters()
        shaws.division = "Shaws"
        let division = ScheduleCheckMath.summary(pack: pack, filters: shaws)
        XCTAssertTrue(division.usesMarketLook)
        XCTAssertEqual(HeartbeatFormat.pct(division.under), "87.99%")
        XCTAssertEqual(division.scope, 612)

        shaws.district = "B5"
        let cut = ScheduleCheckMath.summary(pack: pack, filters: shaws)
        XCTAssertFalse(cut.usesMarketLook)
        XCTAssertEqual(HeartbeatFormat.pct(cut.under), "10.00%")

        var united = DashboardFilters()
        united.division = "United"
        let blank = ScheduleCheckMath.summary(pack: unitedPack(), filters: united)
        XCTAssertTrue(blank.usesMarketLook)
        XCTAssertNil(blank.under)
        XCTAssertNil(blank.over)
    }

    func testScheduleCheckBannerMismatchIs472Against468() {
        var stores: [ScheduleStore] = []
        for index in 1...472 {
            stores.append(ScheduleStore(store: String(index), sales: 30_000, under: 10, over: 0, eff: 50, fourUnder: 0))
        }
        stores.append(ScheduleStore(store: "9000", sales: 30_000, under: 0, over: 0, eff: 95, fourUnder: 9))
        let pack = ScheduleCheckPack(
            publishedAt: "2026-09-28T12:00:00Z",
            week: 32,
            filename: "Schedule Review Week 32.xlsx",
            summaryTitle: "",
            workbookActionBanner: 468,
            markets: [],
            stores: stores
        )
        let card = ScheduleCheckMath.summary(pack: pack, filters: DashboardFilters())
        XCTAssertEqual(card.actionCount, 472)
        XCTAssertEqual(
            ScheduleCheckMath.bannerMismatch(pack: pack, summary: card, filters: DashboardFilters()),
            "Workbook banner said 468 stores. This cook qualifies 472."
        )
    }

    /// A loaded pack with 472 qualifying rows must paint the Action Needed body
    /// and the Summary market list. The old two-axis lazy scroll laid out at
    /// height 0, so the tabs showed and the area under them stayed blank.
    func testActionNeededPaintsScopeRowsWhenPackHas472() throws {
        let pack = actionPaintFixture()
        let filters = DashboardFilters()
        let card = ScheduleCheckMath.summary(pack: pack, filters: filters)
        XCTAssertEqual(card.scope, 2163)
        XCTAssertEqual(card.actionCount, 472)
        XCTAssertEqual(pack.markets.count, 13)
        XCTAssertEqual(
            pack.markets.map(\.label),
            [
                "Shaws", "SoCal", "Southwest", "Mountain West", "Jewel Osco",
                "Mid-Atlantic", "NorCal", "Seattle", "Southern", "Portland",
                "Haggen", "United", "Total",
            ]
        )
        XCTAssertEqual(
            ScheduleCheckMath.bannerMismatch(pack: pack, summary: card, filters: filters),
            "Workbook banner said 468 stores. This cook qualifies 472."
        )
        let groups = ScheduleCheckMath.actionGroups(pack: pack, filters: filters)
        XCTAssertEqual(
            groups.map(\.division),
            [
                "Shaws", "Mid-Atlantic", "Jewel Osco", "Southern", "Southwest",
                "NorCal", "SoCal", "Mountain West", "Seattle", "Portland",
            ]
        )
        XCTAssertEqual(groups.map(\.stores.count), [91, 41, 51, 25, 57, 32, 74, 56, 28, 17])
        XCTAssertEqual(groups.reduce(0) { $0 + $1.stores.count }, 472)
        let scopeLine = "\(card.actionCount) stores · sales ≥ $30,000 and (under ≥ 10% or 4-wk under > 9% or over ≥ 15%)"
        XCTAssertEqual(scopeLine, "472 stores · sales ≥ $30,000 and (under ≥ 10% or 4-wk under > 9% or over ≥ 15%)")

        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let view = try String(
            contentsOf: root.appendingPathComponent("FulfillmentHeartbeat/Views/ScheduleCheckView.swift"),
            encoding: .utf8
        )
        let action = sourceSpan(view, from: "private func actionPage", until: "private func summaryPage")
        XCTAssertFalse(
            action.contains("ScrollView([.horizontal, .vertical])"),
            "two-axis scroll around the action rows lays the list body out at height 0"
        )
        XCTAssertFalse(
            action.contains("LazyVStack"),
            "a lazy stack in the action scroll leaves the area under the tabs blank"
        )
        XCTAssertTrue(action.contains("bannerMismatch"))
        XCTAssertTrue(action.contains(#"\(summary.actionCount) stores · sales ≥ $30,000 and (under ≥ 10% or 4-wk under > 9% or over ≥ 15%)"#))
        XCTAssertTrue(action.contains("No stores qualify in this scope."))
        XCTAssertTrue(action.contains("ForEach(groups)"))
        XCTAssertTrue(action.contains("ForEach(group.stores)"))
        XCTAssertTrue(action.contains("ScrollView(.vertical)"))
        XCTAssertTrue(action.contains("frame(maxWidth: .infinity, maxHeight: .infinity"))

        let summary = sourceSpan(view, from: "private func summaryPage", until: "private func detailPage")
        XCTAssertTrue(summary.contains("Stores in scope"))
        XCTAssertTrue(summary.contains("marketBlock(pack.markets)"))
        XCTAssertTrue(summary.contains("frame(maxWidth: .infinity, maxHeight: .infinity"))
        let markets = sourceSpan(view, from: "private func marketBlock", until: "private func kpi")
        XCTAssertTrue(markets.contains("ForEach(markets)"))
        XCTAssertTrue(markets.contains("market.label"))

        let detail = sourceSpan(view, from: "private func detailPage", until: "private func marketBlock")
        XCTAssertTrue(
            detail.contains("ScrollView([.horizontal, .vertical])"),
            "header and store rows share one scroll that has a real viewport"
        )
        XCTAssertTrue(detail.contains("GeometryReader"), "the scroll needs the page size or the lazy rows lay out at height 0")
        XCTAssertTrue(detail.contains("LazyVStack"), "store rows stay lazy so 2,163 lines do not build on the tap")
        XCTAssertTrue(detail.contains("ForEach(rows)"))
        XCTAssertTrue(detail.contains("header(detailColumns, tappable: true)"))
        XCTAssertFalse(detail.contains("frame(height: rowBody"))
        XCTAssertFalse(detail.contains("minHeight: laidOut"), "a 2,163-line min height blanks the lazy stack")
    }

    func testStoreDetailRowsHaveLaidOutHeight() {
        let height = ScheduleCheckMath.detailBodyHeight(rowCount: 2163)
        XCTAssertGreaterThan(height, 0)
        XCTAssertEqual(
            height,
            ScheduleCheckMath.detailHeaderHeight + CGFloat(2163) * ScheduleCheckMath.detailRowHeight
        )
        XCTAssertEqual(ScheduleCheckMath.detailBodyHeight(rowCount: 0), ScheduleCheckMath.detailHeaderHeight)
        XCTAssertGreaterThan(ScheduleCheckMath.detailBodyHeight(rowCount: 0), 0)
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let view = try? String(
            contentsOf: root.appendingPathComponent("FulfillmentHeartbeat/Views/ScheduleCheckView.swift"),
            encoding: .utf8
        )
        let detail = view ?? ""
        XCTAssertFalse(detail.contains("ScheduleCheckMath.detailBodyHeight(rowCount: rows.count)"))
        XCTAssertFalse(detail.contains("frame(minWidth: detailWidth, minHeight: laidOut"))
        XCTAssertTrue(detail.contains("No stores in this scope."))
        XCTAssertTrue(detail.contains("header(detailColumns, tappable: true)"))
        XCTAssertTrue(detail.contains("LazyVStack"))
        XCTAssertTrue(detail.contains("ForEach(rows)"))
        guard let pageStart = detail.range(of: "private func detailPage"),
              let pageEnd = detail.range(of: "private func marketBlock") else {
            XCTFail("Store Detail page is missing")
            return
        }
        let page = String(detail[pageStart.lowerBound..<pageEnd.lowerBound])
        let header = page.range(of: "header(detailColumns, tappable: true)")
        let scroll = page.range(of: "ScrollView([.horizontal, .vertical])")
        let rows = page.range(of: "ForEach(rows)")
        XCTAssertNotNil(header)
        XCTAssertNotNil(scroll)
        XCTAssertNotNil(rows)
        if let header, let scroll, let rows {
            XCTAssertLessThan(scroll.lowerBound, header.lowerBound, "the column header sits in the same scroll as the rows")
            XCTAssertLessThan(header.lowerBound, rows.lowerBound)
        }
        XCTAssertTrue(page.contains("GeometryReader"))
        XCTAssertTrue(page.contains(".frame(width: proxy.size.width, height: proxy.size.height)"))
        XCTAssertFalse(page.contains("frame(height: rowBody"))
        XCTAssertFalse(page.contains("minHeight: laidOut"))
        XCTAssertTrue(page.contains("frame(width: detailWidth, height: ScheduleCheckMath.detailHeaderHeight"))
        XCTAssertTrue(page.contains("frame(width: detailWidth, height: ScheduleCheckMath.detailRowHeight"))
    }

    func testScheduleRowsRoundTripInsideCurrentSqlite() throws {
        let pack = ScheduleCheckPack(
            publishedAt: "2026-09-28T12:00:00Z",
            week: 32,
            filename: "Schedule Review Week 32.xlsx",
            summaryTitle: "Schedule Review Summary",
            workbookActionBanner: 468,
            markets: [ScheduleMarket(label: "Total", under: 41.07, over: 4.03, eff: 64.97)],
            stores: [
                ScheduleStore(
                    store: "117",
                    region: "East Region",
                    division: "Shaws",
                    district: "B5",
                    om: "Pat",
                    sales: 33_961.98,
                    under: 100,
                    over: 0,
                    eff: 0,
                    pch: 70.2,
                    fourUnder: 9.2,
                    fourOver: nil,
                    star: 4.2,
                    dayUnder: [1, nil, 3, nil, nil, nil, 7],
                    dayOver: [nil, 2, nil, nil, nil, nil, nil]
                )
            ]
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("schedule-pack-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        try PulseSQLite.write(rows: [], uploads: [], seeded: true, to: url)
        try PulseSQLite.writeSchedule(pack, to: url)
        let read = try XCTUnwrap(PulseSQLite.readSchedule(from: url))
        XCTAssertEqual(read, pack)
        let facts = PulseSQLite.sectionCount(from: url, section: .sales)
        XCTAssertEqual(facts, 0)
    }

    /// The page reads schedule_pack from the open sqlite. A pack without that
    /// table is the NO DATA page. Writing the table must not replace prep facts.
    func testSchedulePackInCurrentSqliteLeavesPrepFacts() throws {
        let prep = MetricRow(
            section: .prepNotReady,
            division: "United",
            operationsOM: "Pat Ruiz",
            storeNumber: "10",
            payload: ["pnr_rate_pct": 1.8036477701044753]
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("schedule-keep-prep-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        try PulseSQLite.write(rows: [prep], uploads: [], seeded: true, to: url)
        XCTAssertNil(PulseSQLite.readSchedule(from: url))
        let view = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("FulfillmentHeartbeat/Views/ScheduleCheckView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(view.contains("This pack has no Schedule Check rows."))
        XCTAssertFalse(view.contains("not on this device"))
        XCTAssertTrue(view.contains("store.scheduleCheck == nil"))
        let pack = ScheduleCheckPack(
            publishedAt: "2026-09-29T20:29:58Z",
            week: 40,
            filename: "Schedule Review Week 40.xlsx",
            summaryTitle: "Schedule Review Summary",
            workbookActionBanner: nil,
            markets: [ScheduleMarket(label: "Total", under: 41.07, over: 4.03, eff: 64.97)],
            stores: [ScheduleStore(store: "10", division: "United", sales: 30_000, under: 12, over: 1, eff: 80)]
        )
        try PulseSQLite.writeSchedule(pack, to: url)
        XCTAssertEqual(try XCTUnwrap(PulseSQLite.readSchedule(from: url)), pack)
        let kept = try PulseSQLite.read(from: url)
        let rated = try XCTUnwrap(kept.rows.first { $0.section == .prepNotReady && $0.storeNumber == "10" })
        XCTAssertEqual(rated.number("pnr_rate_pct") ?? 0, 1.8036477701044753, accuracy: 0.000_000_1)
        XCTAssertEqual(PulseSQLite.sectionCount(from: url, section: .prepNotReady), 1)
    }

    func testScheduleCheckShipsInsideSqliteNotAsASidecarPack() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let model = try String(contentsOf: root.appendingPathComponent("FulfillmentHeartbeat/Models/ScheduleCheck.swift"), encoding: .utf8)
        XCTAssertFalse(model.contains("Not part of the Heartbeat sqlite pack"))
        XCTAssertFalse(model.contains("objectName"))
        XCTAssertFalse(model.contains("os(macOS) || targetEnvironment(macCatalyst)"))
        XCTAssertTrue(model.contains("#if os(macOS)"))
        XCTAssertTrue(model.contains("homeDirectoryForCurrentUser"))
        let store = try String(contentsOf: root.appendingPathComponent("FulfillmentHeartbeat/Storage/HeartbeatStore.swift"), encoding: .utf8)
        XCTAssertFalse(store.contains("schedule-check.json"))
        XCTAssertFalse(store.contains("ScheduleCheckPack.objectName"))
        XCTAssertTrue(store.contains("PulseSQLite.readSchedule"))
    }

    func testScheduleCheckPageIsItsOwnDestination() throws {
        XCTAssertEqual(BuildStamp.id, "HB-0828.494")
        XCTAssertEqual(HubDestination.scheduleCheck.title, "Upcoming Weeks Schedule Check")
        XCTAssertNil(HubDestination.scheduleCheck.section)
        XCTAssertFalse(HubDestination.metricItems.contains(.scheduleCheck))
        XCTAssertFalse(HubDestination.settingsItems.contains(.scheduleCheck))
        let pages = HubDestination.sectionItems
        let schedule = try XCTUnwrap(pages.firstIndex(of: .scheduleQuality))
        XCTAssertEqual(pages[schedule + 1], .scheduleCheck)
        XCTAssertEqual(PulseEmail.SharePage.from(destination: .scheduleCheck), .dashboard)
        XCTAssertFalse(HeartbeatAssist.pagePrompts(.scheduleCheck).isEmpty)
        let emptyAssist = ScheduleCheckMath.assistText(pack: nil, filters: DashboardFilters())
        XCTAssertTrue(emptyAssist.contains("NO DATA"))
        XCTAssertTrue(emptyAssist.contains("This pack has no Schedule Check rows."))
        XCTAssertFalse(emptyAssist.contains("not on this device"))
    }

    private func sourceSpan(_ text: String, from start: String, until end: String) -> String {
        guard let from = text.range(of: start), let to = text.range(of: end, range: from.upperBound..<text.endIndex) else {
            XCTFail("missing \(start) … \(end)")
            return ""
        }
        return String(text[from.lowerBound..<to.lowerBound])
    }

    /// 472 qualifying stores in the ten divisions, padded to 2,163 in scope,
    /// plus 13 Market Look rows (11 divisions, United, and Total).
    private func actionPaintFixture() -> ScheduleCheckPack {
        let qualifying: [(String, String, Int)] = [
            ("East Region", "Shaws", 91),
            ("California Region", "SoCal", 74),
            ("South Region", "Southwest", 57),
            ("West Region", "Mountain West", 56),
            ("East Region", "Jewel Osco", 51),
            ("East Region", "Mid-Atlantic", 41),
            ("California Region", "NorCal", 32),
            ("West Region", "Seattle", 28),
            ("South Region", "Southern", 25),
            ("West Region", "Portland", 17),
        ]
        var stores: [ScheduleStore] = []
        var number = 0
        for (region, division, count) in qualifying {
            for _ in 0..<count {
                number += 1
                stores.append(
                    ScheduleStore(
                        store: String(number),
                        region: region,
                        division: division,
                        sales: 30_000,
                        under: 10,
                        over: 0,
                        eff: 50,
                        fourUnder: 0
                    )
                )
            }
        }
        while stores.count < 2163 {
            number += 1
            stores.append(
                ScheduleStore(
                    store: String(number),
                    region: "East Region",
                    division: "Shaws",
                    sales: 29_999,
                    under: 50,
                    over: 50,
                    eff: 50,
                    fourUnder: 20
                )
            )
        }
        let labels = [
            "Shaws", "SoCal", "Southwest", "Mountain West", "Jewel Osco",
            "Mid-Atlantic", "NorCal", "Seattle", "Southern", "Portland",
            "Haggen", "United", "Total",
        ]
        return ScheduleCheckPack(
            publishedAt: "2026-09-28T21:45:00Z",
            week: 32,
            filename: "Schedule Review Week 32 - Summary First Look.xlsx",
            summaryTitle: "Schedule Review Summary — Week 31 (WK31)",
            workbookActionBanner: 468,
            markets: labels.map { ScheduleMarket(label: $0, under: 1, over: 1, eff: 80) },
            stores: stores
        )
    }

    private func companyFixture() -> ScheduleCheckPack {
        var stores: [ScheduleStore] = []
        stores.reserveCapacity(2163)
        let slices = [
            ("East Region", "Shaws", 612),
            ("South Region", "Southern", 397),
            ("California Region", "NorCal", 600),
            ("West Region", "Seattle", 554),
        ]
        var number = 0
        for (region, division, count) in slices {
            for _ in 0..<count {
                number += 1
                stores.append(
                    ScheduleStore(
                        store: String(number),
                        region: region,
                        division: division,
                        district: number == 1 ? "B5" : "D1",
                        om: "OM",
                        sales: 40_000,
                        under: number <= 2008 ? 10 : 0,
                        over: number <= 1566 ? 1 : 0,
                        eff: 64.96863574753489,
                        pch: 70.27935894879694,
                        fourUnder: 0
                    )
                )
            }
        }
        return ScheduleCheckPack(
            publishedAt: "2026-09-28T12:00:00Z",
            week: 32,
            filename: "Schedule Review Week 32 - Summary First Look.xlsx",
            summaryTitle: "Schedule Review Summary — Week 31 (WK31)",
            workbookActionBanner: 468,
            markets: [
                ScheduleMarket(label: "Total", under: 41.065737598188234, over: 4.033726345032599, eff: 54.90053605677916),
                ScheduleMarket(label: "Shaws", under: 87.99105158110805, over: 0.6493752187443836, eff: 11.359573200147566),
            ],
            stores: stores
        )
    }

    private func unitedPack() -> ScheduleCheckPack {
        ScheduleCheckPack(
            publishedAt: "2026-09-28T12:00:00Z",
            week: 32,
            filename: "Schedule Review Week 32.xlsx",
            summaryTitle: "",
            workbookActionBanner: nil,
            markets: [ScheduleMarket(label: "United", under: nil, over: nil, eff: 100)],
            stores: [ScheduleStore(store: "1216", region: "South Region", division: "United", eff: 100)]
        )
    }
}
