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

    func testMasterSheetNames() {
        XCTAssertEqual(WorkbookParser.section(fromSheetName: "Lost Revenue"), .lostRevenue)
        XCTAssertEqual(WorkbookParser.section(fromSheetName: "Loss Revenue ScoreCard"), .lostRevenue)
        XCTAssertEqual(WorkbookParser.section(fromSheetName: "5 Star"), .fiveStar)
        XCTAssertEqual(WorkbookParser.section(fromSheetName: "Pick Path Picker"), .pickPathPicker)
        XCTAssertEqual(WorkbookParser.section(fromSheetName: "Pick Path"), .pickPath)
        XCTAssertEqual(WorkbookParser.section(fromSheetName: "Prep Not Ready"), .prepNotReady)
        XCTAssertEqual(WorkbookParser.section(fromSheetName: "Dynacap"), .dynacap)
        XCTAssertEqual(WorkbookParser.section(fromSheetName: "Schedule Quality"), .scheduleQuality)
        XCTAssertEqual(WorkbookParser.section(fromSheetName: "PPH"), .pph)
        XCTAssertEqual(WorkbookParser.section(fromSheetName: "Labor"), .labor)
        XCTAssertEqual(WorkbookParser.section(fromSheetName: "Picker ScoreCard"), .pickerScorecard)
        XCTAssertEqual(WorkbookParser.section(fromSheetName: "Picker ScorCard"), .pickerScorecard)
        XCTAssertEqual(WorkbookParser.section(fromSheetName: "Path Picker"), .pickPathPicker)
        XCTAssertEqual(WorkbookParser.section(fromSheetName: "Loss Revenue"), .lostRevenue)
        XCTAssertEqual(WorkbookParser.section(fromSheetName: "MI"), .missingItems)
        XCTAssertEqual(WorkbookParser.section(fromSheetName: "Missing Items"), .missingItems)
        XCTAssertEqual(WorkbookParser.section(fromSheetName: "Aisle Mapper"), .aisleMapper)
        XCTAssertNil(WorkbookParser.section(fromSheetName: "Sheet1"))
    }

    func testDynacapDailyReportHeadersMapRateAndStore() {
        let csv = """
        STORE_ID,DPA_DYNACAP,EOT Capacity,Total Pieces/Total Hrs,% Change,Used Capacity,Utilization%
        0001,17439,17499,75.657,0.00344,3164,0.1787
        0052,25029,25081,57.472,0.00208,5556,0.2212
        """
        let rows = WorkbookParser.parseCSV(csv)
        XCTAssertEqual(WorkbookParser.classifySheet(name: "Dynacap", rows: rows), .dynacap)
        XCTAssertEqual(Set(rows.map(\.storeNumber)), Set(["1", "52"]))
        XCTAssertEqual(rows.first { $0.storeNumber == "1" }?.payload["dynacap_rate"] ?? 0, 75.657, accuracy: 0.01)
        XCTAssertEqual(rows.first { $0.storeNumber == "52" }?.payload["dynacap_rate"] ?? 0, 57.472, accuracy: 0.01)
        XCTAssertEqual(rows.first { $0.storeNumber == "1" }?.payload["dpa_dynacap"] ?? 0, 17439, accuracy: 0.5)
    }

    func testClassifiesTemplateRows() throws {
        for section in MetricSection.uploadOrder {
            let csv = SampleMarket.templateCSV(for: section)
            let rows = WorkbookParser.parseCSV(csv)
            XCTAssertFalse(rows.isEmpty, section.rawValue)
            let classified = WorkbookParser.classifySheet(name: "Sheet1", rows: rows)
            XCTAssertEqual(classified, section, section.rawValue)
        }
    }

    func testMissingItemsParsesDepartmentPercentsAndSkipsTotals() {
        let csv = SampleMarket.templateCSV(for: .missingItems)
        let rows = WorkbookParser.parseCSV(csv)
        XCTAssertEqual(WorkbookParser.classifySheet(name: "MI", rows: rows), .missingItems)
        XCTAssertEqual(Set(rows.map(\.storeNumber)), Set(["1", "606", "3427"]))
        let jewel = rows.first { $0.storeNumber == "1" }!
        XCTAssertEqual(jewel.division, "Jewel Osco")
        XCTAssertEqual(jewel.operationsOM, "Shelly Selof")
        XCTAssertEqual(jewel.textPayload["district"], "J1")
        XCTAssertEqual(jewel.payload["mi_grocery"] ?? 0, 4.0, accuracy: 0.05)
        XCTAssertEqual(jewel.payload["mi_pct"] ?? 0, 4.5, accuracy: 0.05)
        XCTAssertEqual(jewel.payload["mi_bakery_pkgd"] ?? 0, 7.5, accuracy: 0.05)
        XCTAssertEqual(HeartbeatMath.health(for: .missingItems, row: jewel), .good)
        let watch = rows.first { $0.storeNumber == "606" }!
        XCTAssertEqual(watch.payload["mi_pct"] ?? 0, 6.8, accuracy: 0.05)
        XCTAssertEqual(HeartbeatMath.health(for: .missingItems, row: watch), .risk)
        let haggen = rows.first { $0.storeNumber == "3427" }!
        XCTAssertEqual(haggen.payload["mi_pct"] ?? 0, 3.8, accuracy: 0.05)
        XCTAssertEqual(HeartbeatMath.health(for: .missingItems, row: haggen), .good)
    }

    func testAisleMapperParsesDatesAndSkipsFilterRow() {
        let csv = SampleMarket.templateCSV(for: .aisleMapper)
        let rows = WorkbookParser.parseCSV(csv)
        XCTAssertEqual(WorkbookParser.classifySheet(name: "Aisle Mapper", rows: rows), .aisleMapper)
        XCTAssertEqual(Set(rows.map(\.storeNumber)), Set(["1", "606", "3427"]))
        let fresh = rows.first { $0.storeNumber == "1" }!
        XCTAssertEqual(fresh.textPayload[AisleMapperMath.mapperKey], "2026-08-20")
        XCTAssertEqual(fresh.textPayload[AisleMapperMath.sequenceKey], "2026-08-24")
        XCTAssertEqual(AisleMapperMath.health(nil), .none)
        let stale = rows.first { $0.storeNumber == "606" }!
        XCTAssertEqual(stale.textPayload[AisleMapperMath.mapperKey], "2021-03-05")
        XCTAssertEqual(AisleMapperMath.health("2021-03-05"), .risk)
        let path = MetricRow(section: .pickPath, division: "Jewel Osco", operationsOM: "Shelly Selof", storeNumber: "1", payload: ["compliance_pct": 92])
        let merged = HeartbeatMath.applyAisleMapper([path], from: rows)
        XCTAssertEqual(merged.first?.textPayload[AisleMapperMath.mapperKey], "2026-08-20")
        XCTAssertEqual(HeartbeatFormat.shortDate("2026-08-20"), "8/20/26")
    }

    func testTemplateCSVRoundTrip() throws {
        for section in MetricSection.allCases {
            let csv = SampleMarket.templateCSV(for: section)
            let rows = try WorkbookParser.parse(data: Data(csv.utf8), filename: "\(section.rawValue).csv")
            XCTAssertFalse(rows.isEmpty, section.rawValue)
            if section != .pickPathPicker {
                XCTAssertFalse(rows[0].storeNumber.isEmpty, section.rawValue)
            }
        }
    }

    func testPPHDayOutlineUsesTotalColumn() throws {
        let csv = """
        DATE,,,,,2026-08-16,2026-08-17,2026-08-18,Total
        DIVISION,DISTRICT,OM_AREA,OM_ID,STORE,Pure PPH,Pure PPH,Pure PPH,Pure PPH
        Portland,Total,,,,82.7,81.5,80.4,81.7
        ,77,Total,,,88.3,82.9,83.8,85.3
        ,,Portland 4,Total,,88.3,82.9,83.8,85.3
        ,,,Kennda Richardson,Total,88.3,82.9,83.8,85.3
        ,,,,4262,126.4,142.4,125.5,131.60118190032
        ,,,,4316,93.2,111.8,123.9,107.310732478482
        Jewel Osco,J1,Chicago 1,Shelly Selof,1,64.9,67.0,71.3,67.3344365031863
        Total,,,,,,,,73.8
        """
        let rows = try WorkbookParser.parse(data: Data(csv.utf8), filename: "pph-day.csv")
        let store4262 = try XCTUnwrap(rows.first { $0.storeNumber == "4262" })
        XCTAssertEqual(store4262.division, "Portland")
        XCTAssertEqual(store4262.operationsOM, "Kennda Richardson")
        XCTAssertEqual(store4262.textPayload["district"], "77")
        XCTAssertEqual(store4262.payload["pph"] ?? 0, 131.60118190032, accuracy: 0.001)
        let store1 = try XCTUnwrap(rows.first { $0.storeNumber == "1" })
        XCTAssertEqual(store1.division, "Jewel Osco")
        XCTAssertEqual(store1.operationsOM, "Shelly Selof")
        XCTAssertEqual(store1.payload["pph"] ?? 0, 67.3344365031863, accuracy: 0.001)
        XCTAssertFalse(rows.contains { $0.storeNumber.lowercased() == "total" })
        XCTAssertEqual(rows.filter { $0.storeNumber == "4262" }.count, 1)
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

    func testPickerTotalsMatchEveryShopperInSparseExport() throws {
        let csv = """
        DATE,,46250,46250,46250,46250,46250,46250,46250,46250,46250,46250,46250,46250,46250,46251,46251,46251,46251,46251,46251,46251,46251,46251,46251,46251,46251,46251,Total,Total,Total,Total,Total,Total,Total,Total,Total,Total,Total,Total,Total
        STORE,PICKER,Pure_PPH,Pre_SUB_OOS_%,OOS_%,PICK_HOURS,PPH Picks,SUBS,ORDERS,Ttl DUG ORDERS,OTH  Eligible  Orders,OTH_ELIG,OTH5%,OTT %,Refund_AMT,Pure_PPH,Pre_SUB_OOS_%,OOS_%,PICK_HOURS,PPH Picks,SUBS,ORDERS,Ttl DUG ORDERS,OTH  Eligible  Orders,OTH_ELIG,OTH5%,OTT %,Refund_AMT,Pure_PPH,Pre_SUB_OOS_%,OOS_%,PICK_HOURS,PPH Picks,SUBS,ORDERS,Ttl DUG ORDERS,OTH  Eligible  Orders,OTH_ELIG,OTH5%,OTT %,Refund_AMT
        76,Total,52,,,,,,,,,,,,,52,,,,,,,,,,,,,52.174038899918223,0.10637270679111684,4.2484711940778887E-2,230.30611111111111,12016,794,453,308,284,0.96928327645051193,0.89084507042253525,0.26548672566371684,269.34
        76,AGUT473,,,,,,,,,,,,,,50.077279752704783,0.20754716981132076,3.3018867924528301E-2,4.1336111111111116,207,37,5,3,,,,0,,50.077279752704783,0.20754716981132076,3.3018867924528301E-2,4.1336111111111116,207,37,5,3,,,,0,
        12,MMCC808,,,,,,,,,,,,,,44.251236696147494,1.6260162601626018E-2,0,5.5591666666666679,246,4,2,1,2,1,0.5,1,,43.708026628346865,1.6908212560386472E-2,0,9.4719444444444463,414,7,7,5,2,1,0.5,1,
        Total,,,,,,,,,,,,,,,,,,,,,,,,,,,,73.85,0.058,0.024,126510,9343041,321222,399603,270725,253764,0.965,0.903,0.872,148211.63
        """
        let rows = try WorkbookParser.parse(data: Data(csv.utf8), filename: "PickerScoreCard Week 25.xlsx")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(Set(rows.map(\.storeNumber)), ["12", "76"])

        let mmcc = try XCTUnwrap(rows.first { $0.textPayload["shopper_id"] == "MMCC808" })
        XCTAssertEqual(mmcc.storeNumber, "12")
        XCTAssertEqual(mmcc.payload["pph"] ?? 0, 43.708026628346865, accuracy: 0.0001)
        XCTAssertEqual(mmcc.payload["presub_pct"] ?? 0, 1.6908212560386472, accuracy: 0.0001)
        XCTAssertEqual(mmcc.payload["oos_pct"] ?? 0, 0, accuracy: 0.0001)
        XCTAssertEqual(mmcc.payload["pick_hours"] ?? 0, 9.4719444444444463, accuracy: 0.0001)
        XCTAssertEqual(mmcc.payload["pph_picks"] ?? 0, 414, accuracy: 0.001)
        XCTAssertEqual(mmcc.payload["subs"] ?? 0, 7, accuracy: 0.001)
        XCTAssertEqual(mmcc.payload["orders"] ?? 0, 7, accuracy: 0.001)
        XCTAssertEqual(mmcc.payload["dug_orders"] ?? 0, 5, accuracy: 0.001)
        XCTAssertEqual(mmcc.payload["oth_eligible_orders"] ?? 0, 2, accuracy: 0.001)
        XCTAssertEqual(mmcc.payload["oth_elig_pct"] ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(mmcc.payload["oth5_pct"] ?? 0, 50, accuracy: 0.001)
        XCTAssertEqual(mmcc.payload["ott_pct"] ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(HeartbeatFormat.pct(mmcc.payload["presub_pct"]), "1.69%")
        XCTAssertEqual(HeartbeatFormat.pct(mmcc.payload["oos_pct"]), "0.0%")

        let agut = try XCTUnwrap(rows.first { $0.textPayload["shopper_id"] == "AGUT473" })
        XCTAssertEqual(agut.storeNumber, "76")
        XCTAssertEqual(agut.payload["pph"] ?? 0, 50.077279752704783, accuracy: 0.0001)
        XCTAssertEqual(agut.payload["presub_pct"] ?? 0, 20.754716981132076, accuracy: 0.0001)
        XCTAssertEqual(agut.payload["oos_pct"] ?? 0, 3.3018867924528301, accuracy: 0.0001)
        XCTAssertEqual(agut.payload["pick_hours"] ?? 0, 4.1336111111111116, accuracy: 0.0001)
        XCTAssertEqual(agut.payload["subs"] ?? 0, 37, accuracy: 0.001)
        XCTAssertEqual(HeartbeatFormat.pct(agut.payload["oos_pct"]), "3.30%")
    }

    func testSheetXMLKeepsSkippedColumnsSoTotalsStayPut() {
        let xml = """
        <worksheet><sheetData>
        <row r="21651">
        <c r="A21651"><v>10</v></c>
        <c r="B21651" t="inlineStr"><is><t>JBAGL16</t></is></c>
        <c r="AB21651" s="13"/>
        <c r="AD21651" s="10"/>
        <c r="AE21651" s="10"/>
        <c r="AG21651" s="11"/>
        <c r="AP21651"><v>81.432266571993708</v></c>
        <c r="AQ21651"><v>1.5695067264573991E-2</v></c>
        <c r="AR21651"><v>0</v></c>
        <c r="AS21651"><v>5.4769444444444444</v></c>
        <c r="AT21651"><v>446</v></c>
        <c r="AU21651"><v>7</v></c>
        <c r="AV21651"><v>8</v></c>
        <c r="AW21651"><v>7</v></c>
        <c r="AX21651"><v>3</v></c>
        <c r="AY21651"><v>1</v></c>
        <c r="AZ21651"><v>1</v></c>
        <c r="BA21651"><v>0.875</v></c>
        <c r="BB21651" s="9"/>
        </row>
        </sheetData></worksheet>
        """
        let rows = SheetXML.parse(xml, strings: [])
        XCTAssertEqual(rows.count, 1)
        XCTAssertGreaterThanOrEqual(rows[0].count, 53)
        XCTAssertEqual(rows[0][0], "10")
        XCTAssertEqual(rows[0][1], "JBAGL16")
        XCTAssertEqual(rows[0][41], "81.432266571993708")
        XCTAssertEqual(rows[0][42], "1.5695067264573991E-2")
        XCTAssertEqual(rows[0][43], "0")
        XCTAssertEqual(rows[0][44], "5.4769444444444444")
        XCTAssertEqual(rows[0][45], "446")
        XCTAssertEqual(rows[0][52], "0.875")
    }

    func testPickPathStoreWeekUsesTotalColumns() throws {
        let csv = """
        WEEK_ID,202625,202625,202625,Total,Total,Total
        STORE_ID,Pick Path Compliance,Orders,Pure PPH (excluding Reshop),Pick Path Compliance,Orders,Pure PPH (excluding Reshop)
        2939,0.91,10,70,0.965870307167236,36,95.6238222009512
        66,0.90,20,60,0.944927536231884,107,70.6372740057949
        Total,0.79,100,50,0.795631687701431,334913,75.9349899829327
        """
        let rows = try WorkbookParser.parse(data: Data(csv.utf8), filename: "pick-path.csv")
        XCTAssertEqual(rows.count, 2)
        let store = try XCTUnwrap(rows.first { $0.storeNumber == "2939" })
        XCTAssertEqual(store.payload["compliance_pct"] ?? 0, 96.5870307167236, accuracy: 0.001)
        XCTAssertEqual(store.payload["orders"] ?? 0, 36, accuracy: 0.001)
        XCTAssertEqual(store.payload["pph"] ?? 0, 95.6238222009512, accuracy: 0.001)
        XCTAssertFalse(rows.contains { $0.storeNumber.lowercased() == "total" })
    }

    func testPickPathPickerWeekUsesEmployeeTotals() throws {
        let csv = """
        WEEK_ID,202625,202625,202625,Total,Total,Total
        EMPLOYEE_ALTERNATE_ID,Pick Path Compliance,Orders,Pure PPH (excluding Reshop),Pick Path Compliance,Orders,Pure PPH (excluding Reshop)
        AABRA77,0.50,1,80,1,17,129.917857281894
        Total,0.79,100,50,0.7956,334913,75.93
        """
        let rows = try WorkbookParser.parse(data: Data(csv.utf8), filename: "pick-path-picker.csv")
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].textPayload["shopper_id"], "AABRA77")
        XCTAssertEqual(rows[0].payload["compliance_pct"] ?? 0, 100, accuracy: 0.01)
        XCTAssertEqual(rows[0].payload["orders"] ?? 0, 17, accuracy: 0.01)
        XCTAssertEqual(rows[0].payload["pph"] ?? 0, 129.917857281894, accuracy: 0.001)
    }

    func testLostRevenueKeepsDollarAndPercentColumnsAndTotalRow() throws {
        let csv = """
        Store,eComm Sales,Total Lost Revenue (Total Opportunity),Total Lost Revenue % (Total Opportunity),Total Lost Revenue (FY2026 Goal) %
        2218,2193.25,2538.573,1.15744807933432,0.546313005813291
        1,10000,450,0.045,0.028
        378,,,,,
        210,500,10,0.02,0.01
        Total,46077144.47,2087654.14383581,0.0453078021185763,0.0279096891593072
        """
        let rows = try WorkbookParser.parse(data: Data(csv.utf8), filename: "Breakdown Week 25.xlsx")
        XCTAssertEqual(Set(rows.map(\.storeNumber)), Set(["2218", "1", ""]))
        let store = try XCTUnwrap(rows.first { $0.storeNumber == "2218" })
        XCTAssertEqual(store.payload["lost_revenue"] ?? 0, 2538.573, accuracy: 0.001)
        XCTAssertEqual(store.payload["lost_revenue_pct"] ?? 0, 115.744807933432, accuracy: 0.001)
        XCTAssertEqual(store.payload["ecomm_sales"] ?? 0, 2193.25, accuracy: 0.001)
        XCTAssertEqual(store.textPayload["lost_grain"], "store")
        let company = try XCTUnwrap(rows.first { $0.storeNumber == "1" })
        XCTAssertEqual(company.payload["lost_revenue_pct"] ?? 0, 4.5, accuracy: 0.01)
        let market = try XCTUnwrap(rows.first { $0.textPayload["lost_grain"] == "market" })
        XCTAssertEqual(market.payload["lost_revenue"] ?? 0, 2087654.14383581, accuracy: 0.01)
        XCTAssertEqual(market.payload["lost_revenue_pct"] ?? 0, 4.53078021185763, accuracy: 0.0001)
        XCTAssertEqual(market.payload["ecomm_sales"] ?? 0, 46077144.47, accuracy: 0.01)
        XCTAssertFalse(rows.contains { $0.storeNumber == "378" })
    }
}

