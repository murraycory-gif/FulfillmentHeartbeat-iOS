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
}
