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
            MetricRow(section: .fiveStar, division: "10", operationsOM: "A. Brooks", storeNumber: "1487"),
            MetricRow(section: .fiveStar, division: "14", operationsOM: "J. Patel", storeNumber: "1088"),
        ]
        XCTAssertEqual(HeartbeatMath.filtered(rows, division: "10", om: "", store: "").count, 1)
        XCTAssertEqual(HeartbeatMath.filtered(rows, division: "", om: "J. Patel", store: "").first?.storeNumber, "1088")
        XCTAssertEqual(HeartbeatMath.filtered(rows, division: "", om: "", store: "1487").count, 1)
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
        let good = MetricRow(section: .pph, division: "10", operationsOM: "A", storeNumber: "1", payload: ["pph": 70, "goal_pph": 65])
        let risk = MetricRow(section: .pph, division: "10", operationsOM: "A", storeNumber: "2", payload: ["pph": 40, "goal_pph": 65])
        XCTAssertEqual(HeartbeatMath.health(for: .pph, row: good), .good)
        XCTAssertEqual(HeartbeatMath.health(for: .pph, row: risk), .risk)
    }

    func testScheduleQualityBand() {
        let good = MetricRow(section: .scheduleQuality, division: "10", operationsOM: "A", storeNumber: "1", payload: ["schedule_efficiency_pct": 96.2])
        let risk = MetricRow(section: .scheduleQuality, division: "10", operationsOM: "A", storeNumber: "2", payload: ["schedule_efficiency_pct": 81.0])
        XCTAssertEqual(HeartbeatMath.health(for: .scheduleQuality, row: good), .good)
        XCTAssertEqual(HeartbeatMath.health(for: .scheduleQuality, row: risk), .risk)
    }
}
