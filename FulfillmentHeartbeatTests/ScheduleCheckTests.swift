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

    func testScheduleCheckPageIsItsOwnDestination() throws {
        XCTAssertEqual(BuildStamp.id, "HB-0828.492")
        XCTAssertEqual(HubDestination.scheduleCheck.title, "Upcoming Weeks Schedule Check")
        XCTAssertNil(HubDestination.scheduleCheck.section)
        XCTAssertFalse(HubDestination.metricItems.contains(.scheduleCheck))
        XCTAssertFalse(HubDestination.settingsItems.contains(.scheduleCheck))
        let pages = HubDestination.sectionItems
        let schedule = try XCTUnwrap(pages.firstIndex(of: .scheduleQuality))
        XCTAssertEqual(pages[schedule + 1], .scheduleCheck)
        XCTAssertEqual(PulseEmail.SharePage.from(destination: .scheduleCheck), .dashboard)
        XCTAssertFalse(HeartbeatAssist.pagePrompts(.scheduleCheck).isEmpty)
        XCTAssertTrue(ScheduleCheckMath.assistText(pack: nil, filters: DashboardFilters()).contains("NO DATA"))
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
