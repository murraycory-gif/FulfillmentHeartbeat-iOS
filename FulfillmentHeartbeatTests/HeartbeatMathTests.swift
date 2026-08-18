import XCTest
@testable import FulfillmentHeartbeat

final class HeartbeatMathTests: XCTestCase {
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
        let risk = MetricRow(section: .prepNotReady, division: "10", operationsOM: "A", storeNumber: "2", payload: ["pnr_rate_pct": 8.0])
        XCTAssertEqual(HeartbeatMath.health(for: .prepNotReady, row: good), .good)
        XCTAssertEqual(HeartbeatMath.health(for: .prepNotReady, row: risk), .risk)
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
    }

    func testLatestPerStoreKeepsNewestDate() {
        let older = MetricRow(section: .fiveStar, division: "10", operationsOM: "A", storeNumber: "1487", recordedOn: "2026-08-03", payload: ["star_rating": 4.1])
        let newer = MetricRow(section: .fiveStar, division: "10", operationsOM: "A", storeNumber: "1487", recordedOn: "2026-08-17", payload: ["star_rating": 4.8])
        let latest = HeartbeatMath.latestPerStore([older, newer])
        XCTAssertEqual(latest.count, 1)
        XCTAssertEqual(latest.first?.number("star_rating"), 4.8)
    }

    func testFiltersDivisionOMStore() {
        let rows = [
            MetricRow(section: .fiveStar, division: "Jewel Osco", operationsOM: "A. Brooks", storeNumber: "1487", textPayload: ["district": "J1"]),
            MetricRow(section: .fiveStar, division: "Jewel Osco", operationsOM: "J. Patel", storeNumber: "1088", textPayload: ["district": "J3"]),
        ]
        XCTAssertEqual(HeartbeatMath.filtered(rows, division: "", district: "J1", om: "", store: "").count, 1)
        XCTAssertEqual(HeartbeatMath.filtered(rows, division: "", district: "", om: "J. Patel", store: "").first?.storeNumber, "1088")
        XCTAssertEqual(HeartbeatMath.filtered(rows, division: "", district: "", om: "", store: "1487").count, 1)
    }

    func testSummarizeFiveStar() {
        let rows = [
            MetricRow(section: .fiveStar, division: "10", operationsOM: "A", storeNumber: "1", payload: ["star_rating": 5.0]),
            MetricRow(section: .fiveStar, division: "10", operationsOM: "A", storeNumber: "2", payload: ["star_rating": 4.0]),
        ]
        let summary = HeartbeatMath.summarize(.fiveStar, rows: rows, upload: nil)
        XCTAssertEqual(summary.storeCount, 2)
        XCTAssertEqual(summary.headline, 4.5)
        XCTAssertEqual(summary.health, .good)
        XCTAssertTrue(summary.secondary.contains("1 of 2"))
    }

    func testSampleMarketHasFiveSections() {
        let rows = SampleMarket.rows()
        XCTAssertEqual(Set(rows.map(\.section)).count, 7)
        XCTAssertEqual(rows.filter { $0.section == .fiveStar }.count, SampleMarket.stores.count * SampleMarket.dates.count)
        XCTAssertEqual(rows.filter { $0.section == .scheduleQuality }.count, SampleMarket.stores.count * SampleMarket.dates.count)
        XCTAssertEqual(rows.filter { $0.section == .pph }.count, SampleMarket.stores.count * SampleMarket.dates.count)
    }

    func testPPHUsesGoalWhenPresent() {
        let good = MetricRow(section: .pph, division: "Jewel Osco", operationsOM: "A", storeNumber: "1", payload: ["pph": 82])
        let watch = MetricRow(section: .pph, division: "Jewel Osco", operationsOM: "A", storeNumber: "2", payload: ["pph": 76])
        let risk = MetricRow(section: .pph, division: "Jewel Osco", operationsOM: "A", storeNumber: "3", payload: ["pph": 70])
        XCTAssertEqual(HeartbeatMath.health(for: .pph, row: good), .good)
        XCTAssertEqual(HeartbeatMath.health(for: .pph, row: watch), .watch)
        XCTAssertEqual(HeartbeatMath.health(for: .pph, row: risk), .risk)
    }

    func testScheduleQualityBand() {
        let good = MetricRow(section: .scheduleQuality, division: "10", operationsOM: "A", storeNumber: "1", payload: ["schedule_efficiency_pct": 96.2])
        let risk = MetricRow(section: .scheduleQuality, division: "10", operationsOM: "A", storeNumber: "2", payload: ["schedule_efficiency_pct": 81.0])
        XCTAssertEqual(HeartbeatMath.health(for: .scheduleQuality, row: good), .good)
        XCTAssertEqual(HeartbeatMath.health(for: .scheduleQuality, row: risk), .risk)
    }

    func testPPHOutlineSkipsTotalsAndUnpivotsWeeks() {
        let csv = SampleMarket.templateCSV(for: .pph)
        let rows = WorkbookParser.parseCSV(csv)
        XCTAssertEqual(Set(rows.map(\.storeNumber)), Set(["1", "606", "3427"]))
        XCTAssertFalse(rows.contains { $0.storeNumber.lowercased() == "total" })
        XCTAssertEqual(rows.filter { $0.storeNumber == "3427" }.count, 8)
        let haggen = rows.first { $0.storeNumber == "3427" }
        XCTAssertEqual(haggen?.division, "Haggen")
        XCTAssertEqual(haggen?.textPayload["district"], "39")
        XCTAssertEqual(haggen?.operationsOM, "Luke Lomas")
        XCTAssertEqual(haggen?.payload["pph"], 87.9)
        XCTAssertEqual(WorkbookParser.dateFromWeekID("202618"), "2026-04-27")
    }

    func testEmptyCellsDoNotShiftStoreAndOM() {
        let xml = """
        <worksheet><sheetData>
        <row>
          <c t="inlineStr"><is><t>WEEK_ID</t></is></c><c /><c /><c /><c />
          <c><v>202618</v></c><c><v>202619</v></c>
        </row>
        <row>
          <c t="inlineStr"><is><t>DIVISION</t></is></c>
          <c t="inlineStr"><is><t>DISTRICT</t></is></c>
          <c t="inlineStr"><is><t>OM_AREA</t></is></c>
          <c t="inlineStr"><is><t>OM_ID</t></is></c>
          <c t="inlineStr"><is><t>STORE</t></is></c>
          <c t="inlineStr"><is><t>Pure PPH</t></is></c>
          <c t="inlineStr"><is><t>Pure PPH</t></is></c>
        </row>
        <row>
          <c t="inlineStr"><is><t>United</t></is></c>
          <c t="inlineStr"><is><t>U6</t></is></c>
          <c />
          <c t="inlineStr"><is><t>Jackie McGuffin</t></is></c>
          <c><v>554</v></c>
          <c><v>102.775856959399</v></c>
          <c><v>111.162974956078</v></c>
        </row>
        </sheetData></worksheet>
        """
        let matrix = SheetXML.parse(xml, strings: [])
        XCTAssertEqual(matrix.last, ["United", "U6", "", "Jackie McGuffin", "554", "102.775856959399", "111.162974956078"])
        let rows = WorkbookParser.parseCSV("""
        WEEK_ID,,,,,202618,202619
        DIVISION,DISTRICT,OM_AREA,OM_ID,STORE,Pure PPH,Pure PPH
        United,U6,,Jackie McGuffin,554,102.775856959399,111.162974956078
        """)
        XCTAssertEqual(Set(rows.map(\.storeNumber)), Set(["554"]))
        XCTAssertEqual(rows.first?.operationsOM, "Jackie McGuffin")
        XCTAssertEqual(rows.first?.payload["pph"], 102.775856959399)
        XCTAssertFalse(WorkbookParser.looksLikeStoreNumber("102.775856959399"))
    }

    func testDistrictFilterScopesOMAndStore() {
        let rows = SampleMarket.rows()
        let j1 = HeartbeatMath.filtered(rows, division: "Jewel Osco", district: "J1", om: "", store: "")
        XCTAssertFalse(j1.isEmpty)
        XCTAssertTrue(j1.allSatisfy { $0.district == "J1" })
        let none = HeartbeatMath.filtered(rows, division: "Jewel Osco", district: "39", om: "", store: "")
        XCTAssertTrue(none.isEmpty)
    }
}
