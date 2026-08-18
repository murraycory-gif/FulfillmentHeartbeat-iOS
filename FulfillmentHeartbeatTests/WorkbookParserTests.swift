import XCTest
@testable import FulfillmentHeartbeat

final class WorkbookParserTests: XCTestCase {
    func testParsesFlexibleCSVHeaders() throws {
        let csv = """
        Div,Ops OM,Store #,Store Name,Week Ending,Star Rating,OTP %,Fill Rate
        10,A. Brooks,9999,Test Supercenter,2026-08-17,4.75,96.2,97.1
        """
        let rows = try WorkbookParser.parse(data: Data(csv.utf8), filename: "five-star.csv")
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].division, "10")
        XCTAssertEqual(rows[0].operationsOM, "A. Brooks")
        XCTAssertEqual(rows[0].storeNumber, "9999")
        XCTAssertEqual(rows[0].storeName, "Test Supercenter")
        XCTAssertEqual(rows[0].recordedOn, "2026-08-17")
        XCTAssertEqual(rows[0].payload["star_rating"], 4.75)
        XCTAssertEqual(rows[0].payload["otp_pct"], 96.2)
    }

    func testSkipsBlankRows() throws {
        let csv = """
        Division,Operations OM,Store Number,Star Rating
        10,A. Brooks,1487,4.5

        10,A. Brooks,1597,4.8
        """
        let rows = try WorkbookParser.parse(data: Data(csv.utf8), filename: "stars.csv")
        XCTAssertEqual(rows.count, 2)
    }

    func testQuotedCommas() {
        let csv = """
        Division,Store Name,Store Number
        10,"Chicago, Pulaski",1487
        """
        let rows = WorkbookParser.parseCSV(csv)
        XCTAssertEqual(rows.first?.storeName, "Chicago, Pulaski")
    }

    func testEmptyWorkbookThrows() {
        XCTAssertThrowsError(try WorkbookParser.parse(data: Data("Division,Store\n".utf8), filename: "empty.csv"))
    }

    func testExcelSerialDate() {
        XCTAssertEqual(WorkbookParser.excelSerialDate(45921), "2025-09-21")
    }

    func testNormHeaderStripsSymbols() {
        XCTAssertEqual(WorkbookParser.normHeader("OTP %"), "otppct")
        XCTAssertEqual(WorkbookParser.normHeader("Store #"), "store")
    }

    func testTemplateCSVRoundTrip() throws {
        for section in MetricSection.allCases {
            let csv = SampleMarket.templateCSV(for: section)
            let rows = try WorkbookParser.parse(data: Data(csv.utf8), filename: "\(section.rawValue).csv")
            XCTAssertFalse(rows.isEmpty, section.rawValue)
            XCTAssertFalse(rows[0].storeNumber.isEmpty, section.rawValue)
        }
    }
}
