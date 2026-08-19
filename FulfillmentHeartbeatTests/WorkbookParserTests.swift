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

    func testUnescapesXMLEntities() {
        func entity(_ name: String) -> String { "&" + name + ";" }
        func numeric(_ code: Int) -> String { "&#" + String(code) + ";" }
        XCTAssertEqual(WorkbookParser.unescapeXML("A " + entity("amp") + " B"), "A & B")
        XCTAssertEqual(WorkbookParser.unescapeXML(entity("lt") + "store" + entity("gt")), "<store>")
        XCTAssertEqual(WorkbookParser.unescapeXML(entity("quot") + "Chicago" + entity("quot")), "\"Chicago\"")
        XCTAssertEqual(WorkbookParser.unescapeXML("O" + entity("apos") + "Hare"), "O'Hare")
        XCTAssertEqual(WorkbookParser.unescapeXML(numeric(34) + "quoted" + numeric(34)), "\"quoted\"")
        XCTAssertEqual(WorkbookParser.unescapeXML(numeric(39) + "ok" + numeric(39)), "'ok'")
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

    func testPickerScorecardUsesTotalColumnsAndSkipsStoreTotals() throws {
        let csv = """
        DATE,,2026-08-16,,,,,,,Total
        STORE,PICKER,Pure_PPH,Pre_SUB_OOS_%,OOS_%,PICK_HOURS,SUBS,ORDERS,Refund_AMT,Pure_PPH,Pre_SUB_OOS_%,OOS_%,PICK_HOURS,SUBS,ORDERS,Ttl DUG ORDERS,OTH_ELIG,OTH5%,OTT %,Refund_AMT
        76,Total,40,0.2,0.05,10,20,8,5,52.17,0.106,0.042,230.3,794,453,308,0.969,0.891,0.265,269.34
        ,AGUT473,50,0.21,0.03,4,37,5,0,50.08,0.208,0.033,4.13,37,5,3,0.9,0.5,0,12.17
        ,AJUST39,62,0.19,0.04,6,60,3,16,62.38,0.193,0.045,6.32,60,3,2,1,1,0,15.98
        Total,,74,0.05,0.02,100,100,80,10,73.85,0.058,0.024,126510,321222,399603,270725,0.965,0.903,0.872,148211.63
        """
        let rows = try WorkbookParser.parse(data: Data(csv.utf8), filename: "PickerScoreCard Week 25.xlsx")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(Set(rows.map(\.storeNumber)), ["76"])
        XCTAssertEqual(Set(rows.map { $0.textPayload["shopper_id"] ?? "" }), ["AGUT473", "AJUST39"])
        let first = rows.first { $0.textPayload["shopper_id"] == "AGUT473" }
        XCTAssertEqual(first?.payload["pph"] ?? 0, 50.08, accuracy: 0.01)
        XCTAssertEqual(first?.payload["presub_pct"] ?? 0, 20.8, accuracy: 0.2)
        XCTAssertEqual(first?.payload["oos_pct"] ?? 0, 3.3, accuracy: 0.2)
        XCTAssertEqual(first?.payload["pick_hours"] ?? 0, 4.13, accuracy: 0.01)
        XCTAssertEqual(first?.payload["dug_orders"] ?? 0, 3, accuracy: 0.01)
        XCTAssertEqual(first?.payload["refund_amt"] ?? 0, 12.17, accuracy: 0.01)
        XCTAssertEqual(first?.payload["oth_elig_pct"] ?? 0, 90, accuracy: 0.5)
    }

    func testSheetXMLKeepsSparseColumns() {
        let xml = """
        <worksheet><sheetData>
        <row r="1">
        <c r="A1" t="inlineStr"><is><t>STORE</t></is></c>
        <c r="B1" t="inlineStr"><is><t>PICKER</t></is></c>
        <c r="AP1"><v>0.016908</v></c>
        <c r="AQ1"><v>0</v></c>
        </row>
        </sheetData></worksheet>
        """
        let rows = SheetXML.parse(xml, strings: [])
        XCTAssertEqual(rows.count, 1)
        XCTAssertGreaterThanOrEqual(rows[0].count, 43)
        XCTAssertEqual(rows[0][0], "STORE")
        XCTAssertEqual(rows[0][1], "PICKER")
        XCTAssertEqual(rows[0][41], "0.016908")
        XCTAssertEqual(rows[0][42], "0")
    }

    func testPickerPercentsKeepSmallValues() throws {
        let csv = """
        DATE,,Total
        STORE,PICKER,Pure_PPH,Pre_SUB_OOS_%,OOS_%,PICK_HOURS,ORDERS,OTH5%,OTT %
        12,MMCC808,43.708,0.016908,0,9.47,7,0.5,1
        12,SAMPLE14,80.0,1.4,0.0,8.0,10,90,95
        """
        let rows = try WorkbookParser.parse(data: Data(csv.utf8), filename: "PickerScoreCard.xlsx")
        let mmcc = rows.first { $0.textPayload["shopper_id"] == "MMCC808" }
        XCTAssertEqual(mmcc?.payload["presub_pct"] ?? 0, 1.6908, accuracy: 0.001)
        XCTAssertEqual(mmcc?.payload["oos_pct"] ?? 0, 0, accuracy: 0.001)
        XCTAssertEqual(mmcc?.payload["oth5_pct"] ?? 0, 50, accuracy: 0.01)
        XCTAssertEqual(mmcc?.payload["ott_pct"] ?? 0, 100, accuracy: 0.01)
        let sample = rows.first { $0.textPayload["shopper_id"] == "SAMPLE14" }
        XCTAssertEqual(sample?.payload["presub_pct"] ?? 0, 1.4, accuracy: 0.001)
        XCTAssertEqual(sample?.payload["oos_pct"] ?? 0, 0, accuracy: 0.001)
    }
}
