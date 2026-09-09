import Foundation
import zlib
#if !HEARTBEAT_INGEST
import Compression
#endif

struct ParsedWorkbookRow {
    var division: String
    var operationsOM: String
    var storeNumber: String
    var storeName: String?
    var recordedOn: String?
    var payload: [String: Double]
    var textPayload: [String: String]

    func asRow(section: MetricSection) -> MetricRow {
        MetricRow(
            section: section,
            division: division,
            operationsOM: operationsOM,
            storeNumber: storeNumber,
            storeName: storeName,
            recordedOn: recordedOn,
            payload: payload,
            textPayload: textPayload
        )
    }
}

enum WorkbookParser {
    enum ParseError: LocalizedError {
        case empty
        case unreadable
        case wrapped(String)
        case unsupported

        var errorDescription: String? {
            switch self {
            case .empty: return "That file had no usable store rows."
            case .unreadable: return "Could not read that workbook."
            case .wrapped(let detail): return detail
            case .unsupported: return "Use a .xlsx or .csv file."
            }
        }
    }

    static func unescapeXML(_ raw: String) -> String {
        unescape(raw)
    }

    static func parse(data: Data, filename: String) throws -> [ParsedWorkbookRow] {
        let ext = (filename as NSString).pathExtension.lowercased()
        let rows: [ParsedWorkbookRow]
        if ext == "csv" || ext == "txt" || looksLikeCSV(data) {
            rows = parseCSV(String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? "")
        } else if let payload = extractZipPayload(data) {
            rows = try parseXLSX(payload)
        } else if ext == "xlsx" || ext == "xlsm" || data.starts(with: [0x50, 0x4B]) {
            rows = try parseXLSX(data)
        } else {
            throw ParseError.unsupported
        }
        if rows.isEmpty { throw ParseError.empty }
        return rows
    }

    static func parseCSV(_ text: String) -> [ParsedWorkbookRow] {
        let matrix = CSVReader.read(text)
        return rows(from: matrix)
    }

    static func parseXLSX(_ data: Data) throws -> [ParsedWorkbookRow] {
        guard let zip = ZipArchive(data: data) else { throw ParseError.unreadable }
        let strings = zip.file(named: "xl/sharedStrings.xml").flatMap { String(data: $0, encoding: .utf8) }.map(SharedStrings.parse) ?? []
        let sheetNames = [
            "xl/worksheets/sheet1.xml",
            "xl/worksheets/sheet2.xml",
        ]
        for name in sheetNames {
            if let sheet = zip.file(named: name) {
                if isLaborWorkbook(strings) {
                    let labor = parseLaborSheet(data: sheet, strings: strings)
                    if !labor.isEmpty { return labor }
                }
                let matrix = SheetXML.parse(data: sheet, strings: strings)
                return rows(from: matrix)
            }
        }
        throw ParseError.unreadable
    }

    struct ParsedSheet {
        var section: MetricSection
        var sheetName: String
        var rows: [ParsedWorkbookRow]
    }

    static func parseMaster(
        data: Data,
        filename: String,
        onProgress: ((Int, Int, String) -> Void)? = nil,
        onLightReady: (([ParsedSheet]) -> Void)? = nil,
        onSheetReady: ((ParsedSheet) -> Void)? = nil
    ) throws -> [ParsedSheet] {
        let ext = (filename as NSString).pathExtension.lowercased()
        if ext == "csv" || ext == "txt" || looksLikeCSV(data) {
            throw ParseError.unsupported
        }
        guard ext == "xlsx" || ext == "xlsm" || data.starts(with: [0x50, 0x4B]) || extractZipPayload(data) != nil else { throw ParseError.unsupported }
        let unzipped = stripWrapper(data)
        let zip = Self.openWorkbook(unzipped) ?? Self.openWorkbook(data) ?? extractZipPayload(unzipped).flatMap(Self.openWorkbook)
        guard let zip else {
            let head = unzipped.prefix(8).map { String(format: "%02X", $0) }.joined(separator: " ")
            let eocd = ZipArchive.findEOCD(unzipped) != nil
            throw ParseError.wrapped("Work OneDrive encrypted this workbook (Intune). Heartbeat is not a managed app, so that copy is unreadable. Open it in Excel → Share → Save to iCloud Drive, then Choose the iCloud file — or tap Reload if this workbook is already linked.")
        }
        let strings = zip.file(named: "xl/sharedStrings.xml").flatMap { String(data: $0, encoding: .utf8) }.map(SharedStrings.parse) ?? []
        zip.release("xl/sharedStrings.xml")
        let sheetsToRead = sheetMap(from: zip).sorted { lhs, rhs in
            func heavy(_ name: String) -> Bool {
                switch section(fromSheetName: name) {
                case .pickerScorecard, .pickPathPicker, .labor, .preSubOOSItem: return true
                default: return false
                }
            }
            let left = heavy(lhs.name)
            let right = heavy(rhs.name)
            if left != right { return !left && right }
            return false
        }
        if sheetsToRead.isEmpty { throw ParseError.unreadable }

        let expected = MetricSection.uploadOrder.count
        onProgress?(0, expected, "Reading workbook…")
        var found: [MetricSection: ParsedSheet] = [:]
        var lightReleased = false
        for entry in sheetsToRead {
            autoreleasepool {
                let hinted = section(fromSheetName: entry.name)
                if !lightReleased, hinted == .labor || hinted == .pickerScorecard || hinted == .pickPathPicker || hinted == .preSubOOSItem {
                    lightReleased = true
                    onLightReady?(MetricSection.uploadOrder.compactMap { found[$0] })
                    onProgress?(found.count, expected, "Finishing Labor and Picker…")
                }
                var parsed: [ParsedWorkbookRow] = []
                if hinted == .labor {
                    onProgress?(found.count, expected, "Unpacking Labor…")
                    parsed = parseLaborFromZip(zip: zip, path: entry.path, strings: strings) { count, unit in
                        onProgress?(min(found.count + 1, expected), expected, "Labor  \(count) \(unit)")
                    }
                } else if hinted == .pickerScorecard || hinted == .pickPathPicker {
                    onProgress?(found.count, expected, "Reading \(entry.name)…")
                    parsed = parsePickersFromZip(
                        zip: zip,
                        path: entry.path,
                        strings: strings,
                        pathPicker: hinted == .pickPathPicker
                    ) { count in
                        onProgress?(found.count, expected, "\(entry.name)  \(count) shoppers")
                    }
                } else if hinted == .preSubOOSItem {
                    onProgress?(found.count, expected, "Reading Pre-Sub items…")
                    parsed = parsePreSubItemsFromZip(zip: zip, path: entry.path, strings: strings) { count in
                        onProgress?(found.count, expected, "Pre-Sub items  \(count)")
                    }
                } else if hinted == .sales {
                    onProgress?(found.count, expected, "Reading Sales…")
                    parsed = parseSalesFromZip(zip: zip, path: entry.path, strings: strings)
                    zip.release(entry.path)
                } else if hinted == .lostRevenue {
                    onProgress?(found.count, expected, "Reading Loss Revenue…")
                    parsed = parseLostRevenueFromZip(zip: zip, path: entry.path, strings: strings)
                    zip.release(entry.path)
                } else {
                    onProgress?(found.count, expected, "Unpacking \(entry.name)…")
                    guard let sheet = zip.file(named: entry.path) ?? zip.file(named: entry.path.replacingOccurrences(of: "xl/", with: "")),
                          !sheet.isEmpty else { return }
                    if hinted == .pickerScorecard || hinted == .pickPathPicker {
                        onProgress?(found.count, expected, "Reading \(entry.name)…")
                        parsed = hinted == .pickPathPicker
                            ? parseEmployeeStreaming(data: sheet, strings: strings)
                            : parsePickerStreaming(data: sheet, strings: strings) { count in
                                onProgress?(found.count, expected, "\(entry.name)  \(count) shoppers")
                            }
                        if !parsed.isEmpty {
                            parsed = compactShoppers(parsed)
                        }
                    }
                    if parsed.isEmpty {
                        let matrix = SheetXML.parse(data: sheet, strings: strings)
                        parsed = rows(from: matrix, prefer: hinted)
                        if parsed.isEmpty, hinted == .pickerScorecard {
                            parsed = parsePickerWide(matrix) ?? parseEmployeeWeek(matrix) ?? []
                        }
                        if parsed.isEmpty, hinted == nil {
                            parsed = parseLaborSheet(data: sheet, strings: strings)
                        }
                    }
                    zip.release(entry.path)
                }
                guard !parsed.isEmpty else { return }
                guard let section = hinted ?? classifySheet(name: entry.name, rows: parsed)
                    ?? classifySheet(name: filename, rows: parsed) else { return }
                if let existing = found[section] {
                    let named = entry.name.lowercased().contains(section.rawValue) || entry.name.lowercased().contains(section.short.lowercased())
                    if !named, existing.rows.count >= parsed.count { return }
                }
                found[section] = ParsedSheet(section: section, sheetName: entry.name, rows: parsed)
                onProgress?(found.count, expected, section.title)
                if section == .labor || section == .pickerScorecard || section == .pickPathPicker {
                    onSheetReady?(found[section]!)
                }
            }
        }
        let sheets = MetricSection.uploadOrder.compactMap { found[$0] }
        if sheets.isEmpty { throw ParseError.empty }
        return sheets
    }

    static func parseSalesOnly(data: Data) -> [ParsedWorkbookRow] {
        let unzipped = stripWrapper(data)
        let zip = Self.openWorkbook(unzipped) ?? Self.openWorkbook(data) ?? extractZipPayload(unzipped).flatMap(Self.openWorkbook)
        guard let zip else { return [] }
        let strings = zip.file(named: "xl/sharedStrings.xml").flatMap { String(data: $0, encoding: .utf8) }.map(SharedStrings.parse) ?? []
        for entry in sheetMap(from: zip) {
            if section(fromSheetName: entry.name) == .sales {
                return parseSalesFromZip(zip: zip, path: entry.path, strings: strings)
            }
        }
        return []
    }

    static func parseSalesMatrix(_ matrix: [[String]]) -> [ParsedWorkbookRow] {
        parseSales(matrix) ?? []
    }

    static func stripWrapper(_ data: Data) -> Data {
        if data.count > 128, data.starts(with: [0x50, 0x4B, 0x03, 0x04]) { return data }
        guard let eocd = ZipArchive.findEOCD(data), eocd + 22 <= data.count else {
            return extractZipPayload(data) ?? data
        }
        let storedCD = Int(u32(data, eocd + 16))
        let cdSize = Int(u32(data, eocd + 12))
        guard cdSize > 46, eocd >= cdSize else { return extractZipPayload(data) ?? data }
        let inferred = eocd - cdSize
        guard inferred >= 0, inferred + 4 <= data.count, u32(data, inferred) == 0x02014b50 else {
            return extractZipPayload(data) ?? data
        }
        let prefix = inferred - storedCD
        guard prefix > 0, prefix < eocd, prefix + 4 <= data.count else { return data }
        if data[prefix] == 0x50, data[prefix + 1] == 0x4B {
            return data.subdata(in: prefix..<data.count)
        }
        return extractZipPayload(data) ?? data
    }

    private static func openWorkbook(_ data: Data) -> ZipArchive? {
        guard let zip = ZipArchive(data: data) else { return nil }
        guard zip.file(named: "xl/workbook.xml") != nil, !zip.worksheetPaths().isEmpty else { return nil }
        return zip
    }

    static func extractZipPayload(_ data: Data) -> Data? {
        if data.count > 128, data.starts(with: [0x50, 0x4B, 0x03, 0x04]) { return data }
        let sig = Data([0x50, 0x4B, 0x03, 0x04])
        if data.count > 4100, data[0] == 0x00, data[1] == 0x4D, data[2] == 0x53, data[3] == 0x4D {
            let slice = data.subdata(in: 4099..<data.count)
            if slice.starts(with: [0x50, 0x4B]) { return slice }
            if let hit = slice.range(of: sig) {
                return Data(slice[hit.lowerBound..<slice.endIndex])
            }
        }
        for offset in [4096, 4099, 4100, 4112, 8192, 512, 1024] where offset + 4 < data.count {
            if data[offset] == 0x50, data[offset + 1] == 0x4B, data[offset + 2] == 0x03, data[offset + 3] == 0x04 {
                return data.subdata(in: offset..<data.count)
            }
        }
        if let hit = data.range(of: sig) {
            return Data(data[hit.lowerBound..<data.endIndex])
        }
        return nil
    }

    private static func looksLikeXlsx(_ data: Data) -> Bool {
        guard data.count > 128, data.starts(with: [0x50, 0x4B]) else { return false }
        guard let zip = ZipArchive(data: data) else { return false }
        return zip.file(named: "xl/workbook.xml") != nil
    }

    static func classifySheet(name: String, rows: [ParsedWorkbookRow]) -> MetricSection? {
        if rows.contains(where: { $0.textPayload["presub_item"] == "1" || !($0.textPayload["bpn"] ?? "").isEmpty }) {
            return .preSubOOSItem
        }
        if let named = section(fromSheetName: name) { return named }
        return section(fromRows: rows)
    }

    static func section(fromSheetName raw: String) -> MetricSection? {
        let name = raw.lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        if name.contains("lost") && name.contains("revenue") { return .lostRevenue }
        if name.contains("loss") && name.contains("revenue") { return .lostRevenue }
        if name == "sales" || name.hasPrefix("sales ") || name.contains("sales score") { return .sales }
        if (name.contains("pre sub") || name.contains("presub") || name.contains("pre-sub")
            || (name.contains("substitution") && name.contains("oos")))
            && (name.contains("item") || name.contains("bpn")) {
            return .preSubOOSItem
        }
        if name.contains("pre sub") || name.contains("presub") || name.contains("pre-sub")
            || (name.contains("substitution") && name.contains("oos"))
            || (name.contains("department") && name.contains("nm") && name.contains("oos")) {
            return .preSubOOS
        }
        if name.contains("aisle mapper") || (name.contains("aisle") && name.contains("sequence")) {
            return .aisleMapper
        }
        if name == "mi" || name.hasPrefix("mi ") || name.contains("missing item") { return .missingItems }
        if name.contains("aisle") && name.contains("tag") { return .missingItems }
        if name.contains("picker") && (name.contains("score") || name.contains("card") || name.contains("scor") || name.contains("shopper")) {
            return .pickerScorecard
        }
        if name.contains("pickerscore") || name.contains("picker scor") || name == "psc" {
            return .pickerScorecard
        }
        if (name.contains("pick path") || name.contains("path compliance"))
            && (name.contains("picker") || name.contains("employee") || name.contains("shopper")) {
            return .pickPathPicker
        }
        if name.contains("path picker") { return .pickPathPicker }
        if name.contains("pick path") || name.contains("path compliance") { return .pickPath }
        if name.contains("prep") { return .prepNotReady }
        if name.contains("dynacap") || name.contains("capacity") { return .dynacap }
        if name.contains("schedule") { return .scheduleQuality }
        if name.contains("5 star") || name.contains("five star") || name.contains("star rating") { return .fiveStar }
        if name.contains("pph") || name.contains("pure pick") { return .pph }
        if name.contains("labor") { return .labor }
        if name.contains("picker") || name.contains("shopper") { return .pickerScorecard }
        if name.contains("roster") || name.contains("roaster") { return .storeRoster }
        return nil
    }

    static func section(fromRows rows: [ParsedWorkbookRow]) -> MetricSection? {
        let sample = rows.prefix(12)
        var keys = Set<String>()
        var text = Set<String>()
        for row in sample {
            keys.formUnion(row.payload.keys)
            text.formUnion(row.textPayload.keys)
        }
        if keys.contains("lost_revenue") { return .lostRevenue }
        if keys.contains("sales_dollars") || keys.contains("sales_plan_pct") || keys.contains("sales_yoy_pct") { return .sales }
        if keys.contains("mi_pct") || keys.contains("mi_grocery") {
            if sample.contains(where: { $0.textPayload["presub_dept"] == "1" }) { return .preSubOOS }
            return .missingItems
        }
        if sample.contains(where: { $0.textPayload["presub_item"] == "1" }) || text.contains("bpn") {
            return .preSubOOSItem
        }
        if text.contains(AisleMapperMath.mapperKey) || text.contains(AisleMapperMath.sequenceKey) { return .aisleMapper }
        if text.contains("roster") { return .storeRoster }
        if keys.contains("target_vs_actual_pct") || keys.contains("earned_hrs") { return .labor }
        if keys.contains("pnr_rate_pct") { return .prepNotReady }
        if keys.contains("star_rating") || keys.contains("flash_pct") { return .fiveStar }
        if keys.contains("schedule_efficiency_pct") { return .scheduleQuality }
        if keys.contains("dynacap_rate") || keys.contains("dpa_dynacap") || keys.contains("eot_capacity") { return .dynacap }
        if keys.contains("compliance_pct") && (text.contains("employee") || text.contains("employee_alternate_id") || text.contains("shopper_id")) {
            return .pickPathPicker
        }
        if text.contains("shopper_id") || text.contains("shopper_name") { return .pickerScorecard }
        if keys.contains("compliance_pct") { return .pickPath }
        if keys.contains("pph") { return .pph }
        return nil
    }

    private static func sheetMap(from zip: ZipArchive) -> [(name: String, path: String)] {
        let fallback = zip.worksheetPaths()
        guard let wb = zip.file(named: "xl/workbook.xml").flatMap({ String(data: $0, encoding: .utf8) }) else {
            return fallback.enumerated().map { ("Sheet \($0.offset + 1)", $0.element) }
        }
        var ridToPath: [String: String] = [:]
        if let rels = zip.file(named: "xl/_rels/workbook.xml.rels").flatMap({ String(data: $0, encoding: .utf8) }),
           let regex = try? NSRegularExpression(pattern: #"<Relationship\b[^>]*>"#, options: []) {
            let range = NSRange(rels.startIndex..., in: rels)
            for match in regex.matches(in: rels, range: range) {
                guard let tagRange = Range(match.range, in: rels) else { continue }
                let tag = String(rels[tagRange])
                let rid = xmlAttr(tag, "Id")
                var target = xmlAttr(tag, "Target")
                guard !rid.isEmpty, !target.isEmpty else { continue }
                if target.hasPrefix("/") { target.removeFirst() }
                if !target.hasPrefix("xl/") { target = "xl/" + target }
                ridToPath[rid] = target
            }
        }
        let cleaned = stripNS(wb)
        var out: [(name: String, path: String)] = []
        if let regex = try? NSRegularExpression(pattern: #"<sheet\b[^>]*>"#, options: []) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            for match in regex.matches(in: cleaned, range: range) {
                guard let tagRange = Range(match.range, in: cleaned) else { continue }
                let tag = String(cleaned[tagRange])
                let name = xmlAttr(tag, "name")
                let rid = xmlAttr(tag, "r:id")
                guard !name.isEmpty else { continue }
                let path = ridToPath[rid] ?? "xl/worksheets/sheet\(out.count + 1).xml"
                out.append((name, path))
            }
        }
        if out.isEmpty {
            let titles = matches(in: cleaned, pattern: #"<sheet[^>]*name="([^"]+)""#)
            return Swift.zip(titles, fallback).map { ($0, $1) } + fallback.dropFirst(titles.count).map { ("Sheet", $0) }
        }
        return out
    }

    private static func xmlAttr(_ tag: String, _ name: String) -> String {
        let needle = "\(name)=\""
        guard let start = tag.range(of: needle) else { return "" }
        let rest = tag[start.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return "" }
        return String(rest[..<end])
    }

    private static func looksLikeCSV(_ data: Data) -> Bool {
        guard let sample = String(data: data.prefix(200), encoding: .utf8) else { return false }
        return sample.contains(",") && !data.starts(with: [0x50, 0x4B])
    }

    private static let divisionKeys = ["division", "div", "divn", "divnbr", "divisionnumber"]
    private static let omKeys = [
        "operationsom", "operations_om", "opsom", "om", "omid", "marketmanager", "mm",
        "operationsmanager", "opsmgr",
    ]
    private static let districtKeys = ["district", "dist", "distid", "districtnbr", "districtnumber"]
    private static let omAreaKeys = ["omarea", "om_area", "area", "market"]
    private static let storeKeys = [
        "storenumber", "storenbr", "store", "storeid", "unit", "storenbr", "location", "loc", "locationid",
    ]
    private static let nameKeys = ["storename", "unitname", "location", "storenm"]
    private static let shopperNameKeys = [
        "shopper", "shoppername", "picker", "pickername", "associate", "associatename", "teammember",
        "name", "fullname", "pickernm", "shoppernm",
    ]
    private static let shopperIdKeys = [
        "shopperid", "pickerid", "associateid", "win", "userid", "associatewin",
        "employeealternateid", "employeeid", "employee", "empid", "associate",
    ]
    private static let dateKeys = ["date", "week", "weekending", "period", "recordedon", "asof", "reportdate"]

    private static let metricAliases: [String: String] = {
        var dict: [String: String] = [:]
        dict["starrating"] = "star_rating"
        dict["stars"] = "star_rating"
        dict["fivestar"] = "star_rating"
        dict["fivestars"] = "star_rating"
        dict["rating"] = "star_rating"
        dict["totalrating"] = "star_rating"
        dict["flashavailabilitymakeitconvenient"] = "flash_pct"
        dict["flashavailability"] = "flash_pct"
        dict["flash"] = "flash_pct"
        dict["flashavailabilitystar"] = "flash_star"
        dict["ottmakeitconvenient"] = "ott_pct"
        dict["ott"] = "ott_pct"
        dict["ottstar"] = "ott_star"
        dict["presuboosgivemewhatiordered"] = "presub_pct"
        dict["presuboos"] = "presub_pct"
        dict["presub"] = "presub_pct"
        dict["presuboosstar"] = "presub_star"
        dict["coegivemewhatiordered"] = "coe_pct"
        dict["coe"] = "coe_pct"
        dict["coestar"] = "coe_star"
        dict["oth5pleasanthandoff"] = "oth5_pct"
        dict["oth5"] = "oth5_pct"
        dict["oth"] = "oth5_pct"
        dict["oth5star"] = "oth5_star"
        dict["passrate40"] = "pass"
        dict["passrate"] = "pass"
        dict["otp"] = "otp_pct"
        dict["otpct"] = "otp_pct"
        dict["ontime"] = "otp_pct"
        dict["ontimepromise"] = "otp_pct"
        dict["ontimepct"] = "otp_pct"
        dict["fill"] = "fill_rate_pct"
        dict["fillrate"] = "fill_rate_pct"
        dict["fillratepct"] = "fill_rate_pct"
        dict["quality"] = "quality_score"
        dict["qualityscore"] = "quality_score"
        dict["cx"] = "cx_score"
        dict["cxscore"] = "cx_score"
        dict["customerexperience"] = "cx_score"
        dict["compliance"] = "compliance_pct"
        dict["compliancepct"] = "compliance_pct"
        dict["pickpath"] = "compliance_pct"
        dict["pickpathcompliance"] = "compliance_pct"
        dict["pathcompliance"] = "compliance_pct"
        dict["orders"] = "orders"
        dict["ordercount"] = "orders"
        dict["order"] = "orders"
        dict["purepphexcludingreshop"] = "pph"
        dict["pphexcludingreshop"] = "pph"
        dict["pickstotal"] = "picks_total"
        dict["totalpicks"] = "picks_total"
        dict["pickscompliant"] = "picks_compliant"
        dict["compliantpicks"] = "picks_compliant"
        dict["exceptions"] = "exception_count"
        dict["exceptioncount"] = "exception_count"
        dict["pnr"] = "pnr_count"
        dict["pnrcount"] = "pnr_count"
        dict["netprepnotreadyhourspct"] = "pnr_rate_pct"
        dict["prepnotreadyhourspct"] = "pnr_rate_pct"
        dict["prepnotreadyhours"] = "pnr_rate_pct"
        dict["pnrhours"] = "pnr_rate_pct"
        dict["notready"] = "pnr_rate_pct"
        dict["netprepnotreadyhours"] = "pnr_rate_pct"
        dict["pnrrate"] = "pnr_rate_pct"
        dict["pnrratepct"] = "pnr_rate_pct"
        dict["ordersdue"] = "orders_due"
        dict["dueorders"] = "orders_due"
        dict["avglatemin"] = "avg_late_min"
        dict["avglate"] = "avg_late_min"
        dict["lateavg"] = "avg_late_min"
        dict["pickupcapacity"] = "pickup_capacity"
        dict["pickupcap"] = "pickup_capacity"
        dict["pickupslots"] = "pickup_capacity"
        dict["deliverycapacity"] = "delivery_capacity"
        dict["deliverycap"] = "delivery_capacity"
        dict["deliveryslots"] = "delivery_capacity"
        dict["recpickup"] = "rec_pickup"
        dict["recommendedpickup"] = "rec_pickup"
        dict["recdelivery"] = "rec_delivery"
        dict["recommendeddelivery"] = "rec_delivery"
        dict["pickuputil"] = "pickup_util_pct"
        dict["pickuputilization"] = "pickup_util_pct"
        dict["deliveryutil"] = "delivery_util_pct"
        dict["deliveryutilization"] = "delivery_util_pct"
        dict["totalpiecestotalhours"] = "dynacap_rate"
        dict["totalpiecestotalhrs"] = "dynacap_rate"
        dict["totalpiecestotalhr"] = "dynacap_rate"
        dict["totalpieceshrs"] = "dynacap_rate"
        dict["totalpieceshr"] = "dynacap_rate"
        dict["pieceshr"] = "dynacap_rate"
        dict["pcsperhr"] = "dynacap_rate"
        dict["totalpiecesperhour"] = "dynacap_rate"
        dict["piecesperhour"] = "dynacap_rate"
        dict["piecestotalhrs"] = "dynacap_rate"
        dict["dynacaprate"] = "dynacap_rate"
        dict["dynacapsetting"] = "dynacap_rate"
        dict["dynacap"] = "dynacap_rate"
        dict["dpadynacap"] = "dpa_dynacap"
        dict["eotcapacity"] = "eot_capacity"
        dict["usedcapacity"] = "used_capacity"
        dict["utilization"] = "utilization_pct"
        dict["utilizationpct"] = "utilization_pct"
        dict["change"] = "change_pct"
        dict["pctchange"] = "change_pct"
        dict["scheduleefficiency"] = "schedule_efficiency_pct"
        dict["scheduleeff"] = "schedule_efficiency_pct"
        dict["efficiency"] = "schedule_efficiency_pct"
        dict["schedefficiency"] = "schedule_efficiency_pct"
        dict["scheduleefficicency"] = "schedule_efficiency_pct"
        dict["scheduleefficicencypctschvstgt"] = "schedule_efficiency_pct"
        dict["scheduleefficiencypctschvstgt"] = "schedule_efficiency_pct"
        dict["underschedulepctschvstgt"] = "under_schedule_pct"
        dict["overschedulepctschvstgt"] = "over_schedule_pct"
        dict["scheduleadherencepctpchvsch"] = "schedule_adherence_pct"
        dict["underadherencepctpchvsch"] = "under_adherence_pct"
        dict["overadherencepctpchvsch"] = "over_adherence_pct"
        dict["staffingefficiencypctpchvstgt"] = "staffing_efficiency_pct"
        dict["staffingefficiencypchvstgt"] = "staffing_efficiency_pct"
        dict["staffingefficiency"] = "staffing_efficiency_pct"
        dict["staffingeff"] = "staffing_efficiency_pct"
        dict["staffingefficiencypctpunchvstarget"] = "staffing_efficiency_pct"
        dict["staffingefficiencypunchvstarget"] = "staffing_efficiency_pct"
        dict["staffingefficiencypctpchvstarget"] = "staffing_efficiency_pct"
        dict["staffingefficiencypchvstarget"] = "staffing_efficiency_pct"
        dict["understaffingpctpchvstgt"] = "under_staffing_pct"
        dict["overstaffingpctpchvstgt"] = "over_staffing_pct"
        dict["scheduleefficiencyschvstgt"] = "schedule_efficiency_pct"
        dict["scheduleefficicencyvsschvstgt"] = "schedule_efficiency_pct"
        dict["scheduleefficiencyvsschvstgt"] = "schedule_efficiency_pct"
        dict["overscheduled"] = "over_schedule_pct"
        dict["oversched"] = "over_schedule_pct"
        dict["overhours"] = "over_schedule_pct"
        dict["overschedule"] = "over_schedule_pct"
        dict["overscheduleschvstgt"] = "over_schedule_pct"
        dict["overschedulevsschvstgt"] = "over_schedule_pct"
        dict["underscheduled"] = "under_schedule_pct"
        dict["undersched"] = "under_schedule_pct"
        dict["underhours"] = "under_schedule_pct"
        dict["underschedule"] = "under_schedule_pct"
        dict["underscheduleschvstgt"] = "under_schedule_pct"
        dict["underschedulevsschvstgt"] = "under_schedule_pct"
        dict["scheduleadherencepchvsch"] = "schedule_adherence_pct"
        dict["scheduleadherence"] = "schedule_adherence_pct"
        dict["underadherencepchvsch"] = "under_adherence_pct"
        dict["overadherencepchvsch"] = "over_adherence_pct"
        dict["staffingefficiencypchvstgt"] = "staffing_efficiency_pct"
        dict["understaffingpchvstgt"] = "under_staffing_pct"
        dict["overstaffingpchvstgt"] = "over_staffing_pct"
        dict["pph"] = "pph"
        dict["purepph"] = "pph"
        dict["purepicksperhour"] = "pph"
        dict["picksperhour"] = "pph"
        dict["pickhours"] = "pick_hours"
        dict["laborhours"] = "pick_hours"
        dict["pphpicks"] = "pph_picks"
        dict["subs"] = "subs"
        dict["substitutes"] = "subs"
        dict["ttldugorders"] = "dug_orders"
        dict["dugorders"] = "dug_orders"
        dict["otheligibleorders"] = "oth_eligible_orders"
        dict["othelig"] = "oth_elig_pct"
        dict["otheligibility"] = "oth_elig_pct"
        dict["refundamt"] = "refund_amt"
        dict["refundamount"] = "refund_amt"
        dict["refund"] = "refund_amt"
        dict["oospct"] = "oos_pct"
        dict["oos"] = "oos_pct"
        dict["presuboospct"] = "presub_pct"
        dict["pickerott"] = "ott_pct"
        dict["totalorders"] = "orders"
        dict["qtyordered"] = "qty_ordered"
        dict["oossubstitutespresuboosct"] = "presub_count"
        dict["presuboosct"] = "presub_count"
        dict["oosct"] = "oos_count"
        dict["subct"] = "sub_count"
        dict["totalitemspicked"] = "items_picked"
        dict["totalhandoffs"] = "handoffs"
        dict["handoffsover5min"] = "handoffs_over_5"
        dict["handoffcompliance"] = "handoff_compliance_pct"
        dict["ofhandoffdefects"] = "handoff_defects"
        dict["handoffdefects"] = "handoff_defects"
        dict["greatperfectorderscount"] = "great_orders"
        dict["nipoorordercount"] = "poor_orders"
        dict["goalpph"] = "goal_pph"
        dict["pphgoal"] = "goal_pph"
        dict["targetpph"] = "goal_pph"
        dict["costtrgt"] = "cost_trgt_pct"
        dict["costtrgtpct"] = "cost_trgt_pct"
        dict["actcost"] = "act_cost_pct"
        dict["actcostpct"] = "act_cost_pct"
        dict["acttrgt"] = "act_cost_pct"
        dict["acttrgtpct"] = "act_cost_pct"
        dict["targetvsactual"] = "target_vs_actual_pct"
        dict["targetvsactualpct"] = "target_vs_actual_pct"
        dict["scheffi"] = "schedule_efficiency_pct"
        dict["scheffipct"] = "schedule_efficiency_pct"
        dict["acthrs"] = "act_hrs"
        dict["schhrs"] = "sch_hrs"
        dict["actcostdollar"] = "act_cost_dollar"
        dict["chargedhrs"] = "charged_hrs"
        return dict
    }()

    private static func rows(fromSheet data: Data, strings: [String]) -> [ParsedWorkbookRow] {
        rows(from: SheetXML.parse(data: data, strings: strings), prefer: nil)
    }

    private static func rows(from matrix: [[String]], prefer: MetricSection? = nil) -> [ParsedWorkbookRow] {
        let parsed: [ParsedWorkbookRow]
        if let prefer, let targeted = rows(from: matrix, section: prefer), !targeted.isEmpty {
            parsed = targeted
        } else {
            parsed = rowsUnhinted(matrix)
        }
        return stampWindow(parsed, matrix: matrix)
    }

    private static func rows(from matrix: [[String]], section: MetricSection) -> [ParsedWorkbookRow]? {
        switch section {
        case .labor: return parseLabor(matrix)
        case .lostRevenue: return parseLostRevenue(matrix)
        case .sales: return parseSales(matrix)
        case .preSubOOSItem: return parsePreSubOOSItem(matrix)
        case .preSubOOS: return parsePreSubOOS(matrix)
        case .missingItems: return parseMissingItems(matrix)
        case .aisleMapper: return parseAisleMapper(matrix)
        case .storeRoster: return parseStoreRoster(matrix)
        case .prepNotReady: return parsePrepHours(matrix) ?? parseFlat(matrix)
        case .pickerScorecard: return parsePickerWide(matrix) ?? parseEmployeeWeek(matrix)
        case .pickPathPicker: return parseEmployeeWeek(matrix) ?? parsePickerWide(matrix)
        case .pickPath: return parseStoreWeek(matrix) ?? parseOutline(matrix)
        case .fiveStar, .pph, .dynacap, .scheduleQuality:
            return parseStoreWeek(matrix) ?? parseOutline(matrix) ?? parseFlat(matrix)
        default:
            return nil
        }
    }

    private static func rowsUnhinted(_ matrix: [[String]]) -> [ParsedWorkbookRow] {
        if let labor = parseLabor(matrix), !labor.isEmpty { return labor }
        if let lost = parseLostRevenue(matrix), !lost.isEmpty { return lost }
        if let sales = parseSales(matrix), !sales.isEmpty { return sales }
        if let items = parsePreSubOOSItem(matrix), !items.isEmpty { return items }
        if let presub = parsePreSubOOS(matrix), !presub.isEmpty { return presub }
        if let missing = parseMissingItems(matrix), !missing.isEmpty { return missing }
        if let aisle = parseAisleMapper(matrix), !aisle.isEmpty { return aisle }
        if let roster = parseStoreRoster(matrix), !roster.isEmpty { return roster }
        if let prep = parsePrepHours(matrix), !prep.isEmpty { return prep }
        if let pickers = parsePickerWide(matrix), !pickers.isEmpty { return pickers }
        if let outline = parseOutline(matrix), !outline.isEmpty { return outline }
        if let stores = parseStoreWeek(matrix), !stores.isEmpty { return stores }
        if let pickers = parseEmployeeWeek(matrix), !pickers.isEmpty { return pickers }
        return parseFlat(matrix)
    }

    private static func stampWindow(_ rows: [ParsedWorkbookRow], matrix: [[String]]) -> [ParsedWorkbookRow] {
        guard let window = dataWindow(from: matrix), !rows.isEmpty else { return rows }
        return rows.map { row in
            var next = row
            if next.textPayload["data_window"] == nil {
                next.textPayload["data_window"] = window
            }
            return next
        }
    }

    static func dataWindow(from matrix: [[String]]) -> String? {
        if matrix.contains(where: isSalesHeader) {
            let week = salesWeek(from: Array(matrix.prefix(6)))
            if !week.isEmpty {
                if week.count == 6, let yr = Int(week.prefix(4)), let wk = Int(week.suffix(2)) {
                    return "Week \(wk), \(yr)"
                }
                return "Week \(week)"
            }
        }
        let blob = matrix.suffix(8).flatMap { $0 }.joined(separator: " ")
        let lower = blob.lowercased()
        guard lower.contains("applied filter") else { return nil }
        return formatAppliedWindow(blob)
    }

    static func formatAppliedWindow(_ raw: String) -> String? {
        let pattern = #"(\d{1,2}/\d{1,2}/\d{2,4})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = raw as NSString
        let matches = regex.matches(in: raw, range: NSRange(location: 0, length: ns.length))
        let stamps = matches.compactMap { match -> Date? in
            parseFilterDate(ns.substring(with: match.range(at: 1)))
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        if stamps.count >= 2 {
            var start = stamps[0]
            var end = stamps[1]
            if end < start { swap(&start, &end) }
            let exclusive = raw.lowercased().contains("before")
            if exclusive, let prior = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: end) {
                end = prior
            }
            formatter.dateFormat = "MMM d"
            let left = formatter.string(from: start)
            formatter.dateFormat = "MMM d, yyyy"
            let right = formatter.string(from: end)
            return "\(left) – \(right)"
        }
        if let only = stamps.first {
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: only)
        }
        if let week = raw.range(of: #"\b(20\d{2})(0[1-9]|[1-4]\d|5[0-3])\b"#, options: .regularExpression) {
            let token = String(raw[week])
            let year = String(token.prefix(4))
            let wk = String(Int(token.suffix(2)) ?? 0)
            return "Week \(wk) · \(year)"
        }
        return nil
    }

    private static func parseFilterDate(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in ["M/d/yyyy", "MM/dd/yyyy", "M/d/yy", "MM/dd/yy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        return nil
    }

    private static func isTotalCell(_ raw: String) -> Bool {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("total") == .orderedSame
    }

    private static func usableValue(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || isTotalCell(trimmed) { return nil }
        if trimmed.lowercased().hasPrefix("applied filters") { return nil }
        return trimmed
    }

    private static func normalizeWeekID(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = Double(trimmed), value >= 200_000, value == value.rounded() {
            return String(Int(value))
        }
        return trimmed
    }

    private static func isLaborWorkbook(_ strings: [String]) -> Bool {
        let blob = strings.prefix(40).map(normHeader).joined(separator: " ")
        return blob.contains("costtrgt") && blob.contains("targetvsactual")
    }

    private static func parseAisleMapper(_ matrix: [[String]]) -> [ParsedWorkbookRow]? {
        guard let headerIndex = matrix.firstIndex(where: isAisleMapperHeader) else { return nil }
        let headers = matrix[headerIndex].map(normHeader)
        var divIdx: Int?
        var distIdx: Int?
        var omIdx: Int?
        var storeIdx: Int?
        var mapperIdx: Int?
        var sequenceIdx: Int?
        for (index, name) in headers.enumerated() {
            if divisionKeys.contains(name) { divIdx = index }
            else if districtKeys.contains(name) || name == "district" { distIdx = index }
            else if omKeys.contains(name) || name == "om" { omIdx = index }
            else if storeKeys.contains(name) || name == "store" { storeIdx = index }
            else if name.contains("aislemapper") || (name.contains("mapper") && name.contains("date")) {
                mapperIdx = index
            } else if name.contains("aislesequence") || (name.contains("sequence") && name.contains("date")) {
                sequenceIdx = index
            }
        }
        guard let storeIdx, mapperIdx != nil || sequenceIdx != nil else { return nil }

        var out: [ParsedWorkbookRow] = []
        out.reserveCapacity(max(0, matrix.count - headerIndex))
        for line in matrix.dropFirst(headerIndex + 1) {
            func cell(_ index: Int?) -> String {
                guard let index, index < line.count else { return "" }
                return line[index]
            }
            let storeRaw = cell(storeIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            if storeRaw.isEmpty { continue }
            if storeRaw.lowercased().hasPrefix("applied") || storeRaw.lowercased().hasPrefix("no filter") { continue }
            if isTotalCell(storeRaw) { continue }
            let store = HeartbeatMath.canonicalStore(storeRaw)
            guard !store.isEmpty, !HeartbeatMath.isIgnoredStore(store) else { continue }

            let mapper = WorkbookParser.isoDate(cell(mapperIdx)) ?? ""
            let sequence = WorkbookParser.isoDate(cell(sequenceIdx)) ?? ""
            if mapper.isEmpty && sequence.isEmpty { continue }

            var text: [String: String] = [:]
            let district = cell(distIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            if !district.isEmpty { text["district"] = district }
            if !mapper.isEmpty { text[AisleMapperMath.mapperKey] = mapper }
            if !sequence.isEmpty { text[AisleMapperMath.sequenceKey] = sequence }
            out.append(
                ParsedWorkbookRow(
                    division: cell(divIdx).trimmingCharacters(in: .whitespacesAndNewlines),
                    operationsOM: cell(omIdx).trimmingCharacters(in: .whitespacesAndNewlines),
                    storeNumber: store,
                    storeName: nil,
                    recordedOn: sequence.isEmpty ? (mapper.isEmpty ? nil : mapper) : sequence,
                    payload: [:],
                    textPayload: text
                )
            )
        }
        return out.isEmpty ? nil : out
    }

    private static func isAisleMapperHeader(_ row: [String]) -> Bool {
        let blob = row.map { $0.lowercased() }.joined(separator: " ")
        if blob.contains("aisle mapper") && blob.contains("sequence") { return true }
        let names = row.map(normHeader)
        return names.contains(where: { $0.contains("aislemapper") })
            && names.contains(where: { $0.contains("aislesequence") || $0.contains("sequenceupdate") })
    }

    private static func parseStoreRoster(_ matrix: [[String]]) -> [ParsedWorkbookRow]? {
        guard let headerIndex = matrix.firstIndex(where: { row in
            let names = row.map(normHeader)
            return names.contains(where: { $0 == "division" || $0.contains("division") })
                && names.contains(where: { $0 == "district" || $0.contains("district") })
                && names.contains(where: { $0 == "store" || $0.contains("store") })
        }) else { return nil }
        let header = matrix[headerIndex].map(normHeader)
        func idx(_ keys: [String]) -> Int? {
            header.firstIndex { name in keys.contains(where: { name == $0 || name.contains($0) }) }
        }
        let divisionIdx = idx(["division"]) ?? 0
        let districtIdx = idx(["district"]) ?? 1
        let areaIdx = idx(["omarea", "om_area", "area"])
        let omIdx = idx(["omid", "om_id", "om"]) ?? 3
        let storeIdx = idx(["store", "storeid", "store_id"]) ?? 4
        var division = ""
        var district = ""
        var area = ""
        var om = ""
        var out: [ParsedWorkbookRow] = []
        out.reserveCapacity(max(matrix.count - headerIndex, 1))
        for line in matrix.dropFirst(headerIndex + 1) {
            func cell(_ index: Int?) -> String {
                guard let index, index < line.count else { return "" }
                return line[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let divRaw = cell(divisionIdx)
            let distRaw = cell(districtIdx)
            let areaRaw = cell(areaIdx)
            let omRaw = cell(omIdx)
            let storeRaw = cell(storeIdx)
            if !divRaw.isEmpty, !isTotalCell(divRaw), divRaw.uppercased() != "WEEK_ID" {
                division = divRaw
            }
            if !distRaw.isEmpty, !isTotalCell(distRaw) {
                district = distRaw
            }
            if !areaRaw.isEmpty, !isTotalCell(areaRaw) {
                area = areaRaw
            }
            if !omRaw.isEmpty, !isTotalCell(omRaw) {
                om = omRaw
            }
            if storeRaw.isEmpty || isTotalCell(storeRaw) { continue }
            let store = HeartbeatMath.canonicalStore(storeRaw)
            if store.isEmpty || HeartbeatMath.isIgnoredStore(store) { continue }
            var text: [String: String] = [
                "roster": "1",
                "district": HeartbeatMath.canonicalDistrict(district),
            ]
            if !area.isEmpty { text["om_area"] = area }
            out.append(
                ParsedWorkbookRow(
                    division: division,
                    operationsOM: om,
                    storeNumber: store,
                    storeName: nil,
                    recordedOn: nil,
                    payload: [:],
                    textPayload: text
                )
            )
        }
        return out.isEmpty ? nil : out
    }

    private static func parseLostRevenue(_ matrix: [[String]]) -> [ParsedWorkbookRow]? {
        guard let headerIndex = matrix.firstIndex(where: { row in
            let blob = row.map { $0.lowercased() }.joined(separator: " ")
            return blob.contains("total lost revenue") && blob.contains("total opportunity")
        }) else { return nil }
        let headers = matrix[headerIndex]
        let keys = headers.map(lostRevenueColumn)
        guard keys.contains("store"), keys.contains("lost_revenue") else { return nil }
        var out: [ParsedWorkbookRow] = []
        out.reserveCapacity(max(matrix.count - headerIndex, 1))
        for line in matrix.dropFirst(headerIndex + 1) {
            if line.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }
            var store = ""
            var division = ""
            var district = ""
            var payload: [String: Double] = [:]
            for (index, key) in keys.enumerated() {
                guard !key.isEmpty else { continue }
                let raw = index < line.count ? line[index] : ""
                if key == "store" {
                    store = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    continue
                }
                if key == "division" {
                    division = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    continue
                }
                if key == "district" {
                    district = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    continue
                }
                if let number = cellNumber(raw) {
                    var value = number
                    if key.hasSuffix("_pct"), value <= 2 { value *= 100 }
                    payload[key] = value
                }
            }
            if store.lowercased().hasPrefix("applied filters") { continue }
            let isTotal = isTotalCell(store)
            if store.isEmpty { continue }
            if !isTotal {
                store = HeartbeatMath.canonicalStore(store)
                if store.isEmpty || HeartbeatMath.isIgnoredStore(store) { continue }
                if payload["lost_revenue"] == nil && payload["ecomm_sales"] == nil { continue }
            }
            var text: [String: String] = ["lost_grain": isTotal ? "market" : "store"]
            if isTotal { text["parser_rev"] = "lost1" }
            let districtCanon = HeartbeatMath.canonicalDistrict(district)
            if !districtCanon.isEmpty { text["district"] = districtCanon }
            out.append(
                ParsedWorkbookRow(
                    division: MarketRegion.canonicalName(division),
                    operationsOM: "",
                    storeNumber: isTotal ? "" : store,
                    storeName: isTotal ? "Total" : nil,
                    recordedOn: nil,
                    payload: payload,
                    textPayload: text
                )
            )
        }
        return out.isEmpty ? nil : out
    }

    private static func lostRevenueColumn(_ raw: String) -> String {
        let lower = raw.lowercased()
        let hasPct = raw.contains("%") || lower.contains("percent")
        if lower.trimmingCharacters(in: .whitespacesAndNewlines) == "store" { return "store" }
        if lower == "store_id" || lower == "storeid" || lower == "store number" || lower == "store #"
            || lower == "store no" || lower.contains("store id") || lower.contains("store number")
            || lower.contains("store #") || (lower.contains("store") && !lower.contains("lost") && !lower.contains("sales")) {
            return "store"
        }
        if lower == "division" || (lower.contains("division") && !lower.contains("lost")) { return "division" }
        if lower == "district" || (lower.contains("district") && !lower.contains("lost")) { return "district" }
        if (lower.contains("ecomm") || lower.contains("e-comm") || lower.contains("ecommerce")) && lower.contains("sales") {
            return "ecomm_sales"
        }
        if lower.contains("total lost revenue") && lower.contains("fy") && hasPct { return "lost_revenue_goal_pct" }
        if lower.contains("total lost revenue") && lower.contains("fy") { return "lost_revenue_goal" }
        if lower.contains("total lost revenue") && lower.contains("total opportunity") && hasPct { return "lost_revenue_pct" }
        if lower.contains("total lost revenue") && lower.contains("total opportunity") { return "lost_revenue" }
        if lower.contains("post sub oos") && hasPct && !lower.contains("foregone") { return "post_sub_oos_pct" }
        if lower.contains("post sub oos") && lower.contains("foregone") && hasPct { return "post_sub_oos_foregone_pct" }
        if lower.contains("post sub oos") && lower.contains("foregone") { return "post_sub_oos_foregone" }
        if lower.contains("refund") && hasPct { return "refund_lost_pct" }
        if lower.contains("refund") { return "refund_lost" }
        if lower.contains("capacity utilization") { return "capacity_util_pct" }
        if lower.contains("missed sales") && hasPct { return "missed_sales_pct" }
        if lower.contains("missed sales") { return "missed_sales" }
        if lower.contains("cancelled") && hasPct { return "cancelled_lost_pct" }
        if lower.contains("cancelled") { return "cancelled_lost" }
        if lower.contains("kill switch") && hasPct { return "kill_switch_pct" }
        if lower.contains("kill switch") && lower.contains("lost order") { return "kill_switch_orders" }
        if lower.contains("kill switch") && (lower.contains("lost sales") || lower.contains("$90")) { return "kill_switch_lost" }
        if lower.contains("kill switch") { return "kill_switch_lost" }
        if lower.contains("reduced capacity") { return "reduced_capacity" }
        return ""
    }

    private static func parseLostRevenueFromZip(zip: ZipArchive, path: String, strings: [String]) -> [ParsedWorkbookRow] {
        var matrix: [[String]] = []
        matrix.reserveCapacity(2500)
        let handle: ([String]) -> Void = { row in
            if !row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { return }
            matrix.append(row)
        }
        let packed = zip.compressedPayload(named: path) ?? zip.compressedPayload(named: path.replacingOccurrences(of: "xl/", with: ""))
        if let packed, packed.method == 8, packed.bytes.count > 80 {
            SheetXML.forEachRowInflating(compressed: packed.bytes, strings: strings, keep: nil, handle: handle)
        }
        if matrix.count < 20, let data = zip.file(named: path) ?? zip.file(named: path.replacingOccurrences(of: "xl/", with: "")), !data.isEmpty {
            matrix.removeAll(keepingCapacity: true)
            SheetXML.forEachRowBytes(data: data, strings: strings, keep: nil, handle: handle)
        }
        if let rows = parseLostRevenue(matrix), rows.contains(where: { !$0.storeNumber.isEmpty }) {
            return rows
        }
        if let data = zip.file(named: path) ?? zip.file(named: path.replacingOccurrences(of: "xl/", with: "")), !data.isEmpty {
            let parsed = parseLostRevenue(SheetXML.parse(data: data, strings: strings)) ?? []
            zip.release(path)
            return parsed
        }
        return parseLostRevenue(matrix) ?? []
    }

    private static func parseSalesFromZip(zip: ZipArchive, path: String, strings: [String]) -> [ParsedWorkbookRow] {
        var matrix: [[String]] = []
        matrix.reserveCapacity(4000)
        let handle: ([String]) -> Void = { row in
            if !row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { return }
            matrix.append(row)
        }
        let packed = zip.compressedPayload(named: path) ?? zip.compressedPayload(named: path.replacingOccurrences(of: "xl/", with: ""))
        if let packed, packed.method == 8, packed.bytes.count > 80 {
            SheetXML.forEachRowInflating(compressed: packed.bytes, strings: strings, keep: nil, handle: handle)
        }
        if matrix.count < 8, let data = zip.file(named: path) ?? zip.file(named: path.replacingOccurrences(of: "xl/", with: "")), !data.isEmpty {
            matrix.removeAll(keepingCapacity: true)
            SheetXML.forEachRowBytes(data: data, strings: strings, keep: nil, handle: handle)
        }
        if let rows = parseSales(matrix), !rows.isEmpty { return rows }
        if let data = zip.file(named: path) ?? zip.file(named: path.replacingOccurrences(of: "xl/", with: "")), !data.isEmpty {
            let parsed = parseSales(SheetXML.parse(data: data, strings: strings)) ?? []
            zip.release(path)
            return parsed
        }
        return []
    }

    private static func isSalesHeader(_ row: [String]) -> Bool {
        let names = row.map { $0.lowercased() }
        let hasStore = names.contains { $0.contains("store") }
        let hasSales = names.contains { $0.contains("sales") }
        return hasStore && hasSales
    }

    private struct SalesBlock {
        var label: String
        var sales: Int?
        var yoy: Int?
        var orders: Int?
        var ordersYoy: Int?
        var aos: Int?
        var aosYoy: Int?
        var aiv: Int?
        var aivYoy: Int?
        var ipt: Int?
        var iptYoy: Int?
        var items: Int?
        var itemsYoy: Int?
        var hd: Int?
        var dug: Int?
    }

    private static func salesField(_ raw: String) -> String? {
        let lower = raw.lowercased()
        if lower.contains("hd") { return "hd" }
        if lower.contains("dug") { return "dug" }
        if lower.contains("sales") && (lower.contains("yoy") || lower.contains("%")) { return "yoy" }
        if lower.contains("sales") { return "sales" }
        if lower.contains("order") && (lower.contains("yoy") || lower.contains("%")) { return "orders_yoy" }
        if lower.contains("order") { return "orders" }
        if lower.contains("aos") && (lower.contains("yoy") || lower.contains("%")) { return "aos_yoy" }
        if lower.contains("aos") { return "aos" }
        if (lower.contains("item") && (lower.contains("txn") || lower.contains("p/txn") || lower.contains("p txn")))
            && (lower.contains("yoy") || lower.contains("%")) { return "ipt_yoy" }
        if lower.contains("item") && (lower.contains("txn") || lower.contains("p/txn") || lower.contains("p txn")) { return "ipt" }
        if lower.contains("total item") && (lower.contains("yoy") || lower.contains("%")) { return "items_yoy" }
        if lower.contains("total item") { return "items" }
        if lower.contains("aiv") && (lower.contains("yoy") || lower.contains("%")) { return "aiv_yoy" }
        if lower.contains("aiv") { return "aiv" }
        return nil
    }

    private static func salesDayName(_ raw: String) -> String {
        let lower = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower.contains("weekday") { return "" }
        if lower.contains("sun") { return "Sunday" }
        if lower.contains("mon") { return "Monday" }
        if lower.contains("tue") { return "Tuesday" }
        if lower.contains("wed") { return "Wednesday" }
        if lower.contains("thu") { return "Thursday" }
        if lower.contains("fri") { return "Friday" }
        if lower.contains("sat") { return "Saturday" }
        if lower.contains("total"), !lower.contains("item") { return "Week" }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Power BI eComm Sales export (Heartbeat Daily Report, tab Sales):
    /// a Weekday row of 1-SUNDAY..7-SATURDAY then Total, each 12 metric columns,
    /// then a Store header. Later Total copies are ignored. -1 is blank.
    /// As the week fills, Wednesday–Saturday pick up automatically.
    private static func parseSales(_ matrix: [[String]]) -> [ParsedWorkbookRow]? {
        guard let headerIdx = matrix.firstIndex(where: isSalesHeader) else { return nil }
        let headers = matrix[headerIdx]
        var divisionIdx: Int?
        var districtIdx: Int?
        var storeIdx: Int?
        for (index, raw) in headers.enumerated() {
            let lower = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if lower == "division" { divisionIdx = index }
            if lower == "district" { districtIdx = index }
            if lower == "store" || lower == "store_id" || lower == "store id" { storeIdx = index }
        }
        guard let storeIdx else { return nil }
        let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

        var weekdayLabels = Array(repeating: "", count: headers.count)
        let lookback = matrix[max(0, headerIdx - 3)..<headerIdx]
        for above in lookback.reversed() {
            if !above.contains(where: {
                let lower = $0.lowercased()
                return lower.contains("sun") || lower.contains("weekday") || lower.contains("monday")
                    || lower.contains("tue") || lower.contains("wed")
                    || lower.contains("1-sun") || lower.contains("friday") || lower.contains("saturday")
                    || lower.contains("total")
            }) {
                continue
            }
            var last = ""
            for index in 0..<headers.count {
                let raw = index < above.count ? above[index].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                if !raw.isEmpty && raw.lowercased() != "weekday" {
                    last = salesDayName(raw)
                }
                weekdayLabels[index] = last
            }
            break
        }

        func name(for start: Int) -> String {
            let above = weekdayLabels.indices.contains(start) ? salesDayName(weekdayLabels[start]) : ""
            if weekdays.contains(above) || above == "Week" { return above }
            return ""
        }

        /// Power BI Sales tab, every day (and Total) is 12 columns in this order:
        /// 0 Sales $ · 1 Sales YoY % · 2 Orders · 3 Orders YoY % ·
        /// 4 AOS · 5 AOS YoY % · 6 AIV · 7 AIV YoY ·
        /// 8 Items P/TXN · 9 Item P/TXN YoY · 10 Total Items · 11 Total Items YoY
        func powerBIBlock(start: Int, label: String) -> SalesBlock {
            var block = SalesBlock(label: label)
            func col(_ offset: Int) -> Int? {
                let index = start + offset
                return index < headers.count ? index : nil
            }
            block.sales = col(0)
            block.yoy = col(1)
            block.orders = col(2)
            block.ordersYoy = col(3)
            block.aos = col(4)
            block.aosYoy = col(5)
            block.aiv = col(6)
            block.aivYoy = col(7)
            block.ipt = col(8)
            block.iptYoy = col(9)
            block.items = col(10)
            block.itemsYoy = col(11)
            let end = min(start + 12, headers.count)
            for index in start..<end {
                guard let field = salesField(headers[index]) else { continue }
                switch field {
                case "sales": block.sales = index
                case "yoy": block.yoy = index
                case "orders": block.orders = index
                case "orders_yoy": block.ordersYoy = index
                case "aos": block.aos = index
                case "aos_yoy": block.aosYoy = index
                case "aiv": block.aiv = index
                case "aiv_yoy": block.aivYoy = index
                case "ipt": block.ipt = index
                case "ipt_yoy": block.iptYoy = index
                case "items": block.items = index
                case "items_yoy": block.itemsYoy = index
                case "hd": block.hd = index
                case "dug": block.dug = index
                default: break
                }
            }
            return block
        }

        var dayBlocks: [SalesBlock] = []
        var weekBlock = SalesBlock(label: "Week")
        var cursor = storeIdx + 1
        while cursor < headers.count {
            let label = name(for: cursor)
            let start = cursor
            cursor += 1
            while cursor < headers.count, name(for: cursor) == label {
                cursor += 1
            }
            let block = powerBIBlock(start: start, label: label)
            if weekdays.contains(label), !dayBlocks.contains(where: { $0.label == label }) {
                dayBlocks.append(block)
            } else if label == "Week", weekBlock.sales == nil {
                weekBlock = block
            }
        }
        if dayBlocks.isEmpty {
            let first = storeIdx + 1
            for (offset, day) in weekdays.enumerated() {
                let start = first + offset * 12
                guard start < headers.count else { break }
                if name(for: start) == "Week" { continue }
                dayBlocks.append(powerBIBlock(start: start, label: day))
            }
            let weekStart = first + 7 * 12
            if weekBlock.sales == nil, weekStart < headers.count {
                weekBlock = powerBIBlock(start: weekStart, label: "Week")
            }
        }
        guard weekBlock.sales != nil || !dayBlocks.isEmpty else { return nil }

        let week = salesWeek(from: Array(matrix.prefix(headerIdx)))
        var lastDivision = ""
        var lastDistrict = ""
        var out: [ParsedWorkbookRow] = []
        out.reserveCapacity(max(matrix.count - headerIdx, 1))
        for line in matrix.dropFirst(headerIdx + 1) {
            if line.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }
            let blob = line.joined(separator: " ").lowercased()
            if blob.contains("applied filter") { continue }
            func cell(_ index: Int?) -> String {
                guard let index, index < line.count else { return "" }
                return line[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let rawDivision = cell(divisionIdx)
            let rawDistrict = cell(districtIdx)
            let rawStore = cell(storeIdx)
            if !rawDivision.isEmpty { lastDivision = rawDivision }
            if !rawDistrict.isEmpty && !isTotalCell(rawDistrict) { lastDistrict = rawDistrict }
            if isTotalCell(rawDivision), !rawStore.isEmpty, !isTotalCell(rawStore) { continue }
            if isTotalCell(rawStore) || isTotalCell(rawDivision) {
                var payload: [String: Double] = [:]
                applySalesBlock(weekBlock, line: line, prefix: "sales_", payload: &payload)
                for (offset, block) in dayBlocks.enumerated() where block.sales != weekBlock.sales {
                    applySalesBlock(block, line: line, prefix: "sales_d\(offset)_", payload: &payload)
                }
                if payload["sales_dollars"] == nil {
                    let daySum = (0..<7).compactMap { payload["sales_d\($0)_dollars"] }.reduce(0, +)
                    if daySum > 0 { payload["sales_dollars"] = daySum }
                }
                if payload["sales_dollars"] != nil {
                    var text: [String: String] = ["sales_grain": "company"]
                    if !week.isEmpty { text["sales_week"] = week }
                    if !dayBlocks.isEmpty {
                        text["sales_days"] = dayBlocks.map(\.label).joined(separator: ",")
                    }
                    out.append(
                        ParsedWorkbookRow(
                            division: "",
                            operationsOM: "",
                            storeNumber: "",
                            storeName: "Total Sales $",
                            recordedOn: week.isEmpty ? nil : week,
                            payload: payload,
                            textPayload: text
                        )
                    )
                }
                continue
            }
            if rawStore.isEmpty { continue }
            let store = HeartbeatMath.canonicalStore(rawStore)
            if store.isEmpty { continue }
            var payload: [String: Double] = [:]
            applySalesBlock(weekBlock, line: line, prefix: "sales_", payload: &payload)
            for (offset, block) in dayBlocks.enumerated() where block.sales != weekBlock.sales {
                applySalesBlock(block, line: line, prefix: "sales_d\(offset)_", payload: &payload)
            }
            if payload["sales_dollars"] == nil {
                let daySum = (0..<7).compactMap { payload["sales_d\($0)_dollars"] }.reduce(0, +)
                if daySum > 0 { payload["sales_dollars"] = daySum }
            }
            if payload["sales_orders"] == nil {
                let dayOrders = (0..<7).compactMap { payload["sales_d\($0)_orders"] }.reduce(0, +)
                if dayOrders > 0 { payload["sales_orders"] = dayOrders }
            }
            if payload["sales_dollars"] == nil && payload["sales_orders"] == nil { continue }
            if payload["sales_aov"] == nil, let sales = payload["sales_dollars"], let orders = payload["sales_orders"], orders > 0 {
                payload["sales_aov"] = sales / orders
            }
            var text: [String: String] = ["sales_grain": "store"]
            if !lastDistrict.isEmpty { text["district"] = lastDistrict }
            if !week.isEmpty { text["sales_week"] = week }
            if !dayBlocks.isEmpty {
                text["sales_days"] = dayBlocks.map(\.label).joined(separator: ",")
            }
            out.append(
                ParsedWorkbookRow(
                    division: lastDivision,
                    operationsOM: "",
                    storeNumber: store,
                    storeName: nil,
                    recordedOn: week.isEmpty ? nil : week,
                    payload: payload,
                    textPayload: text
                )
            )
        }
        return out.isEmpty ? nil : out
    }

    private static func applySalesBlock(_ block: SalesBlock, line: [String], prefix: String, payload: inout [String: Double]) {
        func value(_ index: Int?, scalePct: Bool = false) -> Double? {
            guard let index, index < line.count else { return nil }
            guard var number = cellNumber(line[index]) else { return nil }
            if number == -1 { return nil }
            if scalePct, abs(number) <= 5 { number *= 100 }
            return number
        }
        if let sales = value(block.sales) { payload[prefix + "dollars"] = sales }
        if let yoy = value(block.yoy, scalePct: true) { payload[prefix + "yoy_pct"] = yoy }
        if let orders = value(block.orders) { payload[prefix + "orders"] = orders }
        if let ordersYoy = value(block.ordersYoy, scalePct: true) { payload[prefix + "orders_yoy_pct"] = ordersYoy }
        if let aos = value(block.aos) { payload[prefix + "aos"] = aos }
        if let aosYoy = value(block.aosYoy, scalePct: true) { payload[prefix + "aos_yoy_pct"] = aosYoy }
        if let aiv = value(block.aiv) { payload[prefix + "aiv"] = aiv }
        if let aivYoy = value(block.aivYoy) { payload[prefix + "aiv_yoy"] = aivYoy }
        if let ipt = value(block.ipt) { payload[prefix + "ipt"] = ipt }
        if let iptYoy = value(block.iptYoy) { payload[prefix + "ipt_yoy"] = iptYoy }
        if let items = value(block.items) { payload[prefix + "items"] = items }
        if let itemsYoy = value(block.itemsYoy, scalePct: true) { payload[prefix + "items_yoy_pct"] = itemsYoy }
        if let hd = value(block.hd) { payload[prefix + "hd_orders"] = hd }
        if let dug = value(block.dug) { payload[prefix + "dug_orders"] = dug }
        if payload[prefix + "aos"] != nil {
            payload[prefix + "aov"] = payload[prefix + "aos"]
        } else if let sales = payload[prefix + "dollars"], let orders = payload[prefix + "orders"], orders > 0 {
            payload[prefix + "aov"] = sales / orders
        }
    }

    private static func salesWeek(from rows: [[String]]) -> String {
        for row in rows {
            let joined = row.joined(separator: " ").lowercased()
            guard joined.contains("week") && !joined.contains("weekday") else { continue }
            for value in row {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.range(of: #"^20\d{4}$"#, options: .regularExpression) != nil {
                    return trimmed
                }
            }
        }
        for row in rows {
            for value in row {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.range(of: #"^20\d{4}$"#, options: .regularExpression) != nil {
                    return trimmed
                }
            }
        }
        return ""
    }

    private static func isPreSubItemHeader(_ row: [String]) -> Bool {
        let names = row.map(normHeader)
        let hasStore = names.contains { storeKeys.contains($0) || $0 == "store" || $0.hasPrefix("store") }
        let hasBPN = names.contains {
            $0.contains("bpn") || $0.contains("itemdesc") || $0 == "item" || $0.contains("upc") || $0.contains("item")
        }
        let hasPreSub = row.contains { cell in
            let lower = cell.lowercased()
            return lower.contains("pre-sub") || lower.contains("presub") || lower.contains("pre sub")
                || (lower.contains("pre") && lower.contains("substitution"))
        }
        let hasQty = names.contains { $0.contains("ordqty") || $0.contains("orderqty") || $0.contains("oos") }
        return hasStore && hasBPN && (hasPreSub || hasQty)
    }

    private static func parsePreSubOOSItem(_ matrix: [[String]]) -> [ParsedWorkbookRow]? {
        guard let headerIdx = matrix.firstIndex(where: isPreSubItemHeader) else { return nil }
        let rawHeader = matrix[headerIdx]
        func compact(_ cell: String) -> String { normHeader(cell) }
        func firstIndex(where test: (String, String) -> Bool) -> Int? {
            rawHeader.enumerated().first { test($0.element, compact($0.element)) }?.offset
        }
        let storeIdx = firstIndex { _, n in n == "storeid" || n == "storenumber" || n == "store" || n == "storenbr" }
        let divIdx = firstIndex { _, n in n == "division" }
        let distIdx = firstIndex { _, n in n == "district" }
        let bpnIdx = firstIndex { _, n in n.contains("bpn") || n == "item" || n.contains("itemdesc") }
        let ordIdx = firstIndex { _, n in n == "ordqty" || n == "orderqty" }
        let subsIdx = firstIndex { raw, n in
            let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return (n == "subs" || n == "subct") && !lower.contains("%") && !lower.contains("$")
        }
        let pctIdx = firstIndex { raw, n in
            let lower = raw.lowercased()
            return (lower.contains("pre-sub") || lower.contains("presub") || lower.contains("pre sub"))
                && (lower.contains("%") || n.hasSuffix("pct") || n.hasSuffix("percent"))
                && !lower.contains("$")
        }
        let unitsIdx = firstIndex { raw, n in
            let lower = raw.lowercased()
            return (lower.contains("pre-sub oos") || lower.contains("presub oos") || n == "presuboos")
                && !lower.contains("%") && !lower.contains("$") && !n.contains("pct") && !n.contains("dollar")
        }
        let dollarsIdx = firstIndex { raw, _ in
            let lower = raw.lowercased()
            return lower.contains("$") && (lower.contains("pre-sub") || lower.contains("presub"))
        }
        let oosPctIdx = firstIndex { raw, n in
            let lower = raw.lowercased()
            return (n == "oospct" || n == "oospercent" || (lower.contains("oos%") && !lower.contains("pre")))
                && !lower.contains("$") && !lower.contains("pre-sub") && !lower.contains("presub")
        }
        let oosIdx = firstIndex { raw, n in
            let lower = raw.lowercased()
            return (n == "oos" || n == "oosct") && !lower.contains("%") && !lower.contains("$") && !lower.contains("pre")
        }
        let oosDollarsIdx = firstIndex { raw, _ in
            let lower = raw.lowercased()
            return lower.contains("$") && lower.contains("oos") && !lower.contains("pre-sub") && !lower.contains("presub") && !lower.contains("sub")
        }
        let subsPctIdx = firstIndex { raw, n in
            let lower = raw.lowercased()
            return (n == "subspct" || n == "subpct" || lower == "subs%") && !lower.contains("$")
        }
        let subsDollarsIdx = firstIndex { raw, _ in
            let lower = raw.lowercased()
            return lower.contains("$") && (lower.contains("subs") && !lower.contains("pre"))
        }
        guard let storeIdx, let bpnIdx else { return nil }

        var out: [ParsedWorkbookRow] = []
        out.reserveCapacity(max(0, matrix.count - headerIdx))
        for line in matrix.dropFirst(headerIdx + 1) {
            func cell(_ index: Int?) -> String {
                guard let index, index < line.count else { return "" }
                return line[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let storeRaw = cell(storeIdx)
            if storeRaw.lowercased().hasPrefix("applied") { continue }
            if isTotalCell(storeRaw) { continue }
            guard looksLikeStoreNumber(storeRaw) else { continue }
            let item = cell(bpnIdx)
            if item.isEmpty { continue }
            var payload: [String: Double] = [:]
            func put(_ index: Int?, _ key: String, percent: Bool = false) {
                guard let raw = index.map({ cell($0) }), let number = cellNumber(raw) else { return }
                var value = number
                if percent, abs(value) <= 1.5 { value *= 100 }
                payload[key] = value
            }
            put(ordIdx, "ord_qty")
            put(subsIdx, "sub_count")
            put(pctIdx, "presub_pct", percent: true)
            put(unitsIdx, "presub_count")
            put(dollarsIdx, "presub_dollars")
            put(subsPctIdx, "subs_pct", percent: true)
            put(subsDollarsIdx, "subs_dollars")
            put(oosIdx, "oos_count")
            put(oosPctIdx, "oos_pct", percent: true)
            put(oosDollarsIdx, "oos_dollars")
            var text: [String: String] = [
                "presub_item": "1",
                "bpn": item,
            ]
            let district = cell(distIdx)
            if !district.isEmpty { text["district"] = HeartbeatMath.canonicalDistrict(district) }
            out.append(
                ParsedWorkbookRow(
                    division: {
                        let raw = cell(divIdx)
                        let name = MarketRegion.canonicalName(raw)
                        return name.isEmpty ? raw : name
                    }(),
                    operationsOM: "",
                    storeNumber: HeartbeatMath.canonicalStore(storeRaw),
                    storeName: nil,
                    recordedOn: nil,
                    payload: payload,
                    textPayload: text
                )
            )
        }
        return out.isEmpty ? nil : out
    }

    private static func parsePreSubItemsFromZip(
        zip: ZipArchive,
        path: String,
        strings: [String],
        onTick: ((Int) -> Void)?
    ) -> [ParsedWorkbookRow] {
        if let packed = zip.compressedPayload(named: path) ?? zip.compressedPayload(named: path.replacingOccurrences(of: "xl/", with: "")),
           packed.method == 8 {
            let rows = parsePreSubItemStreaming(compressed: packed.bytes, strings: strings, onTick: onTick)
            if !rows.isEmpty { return rows }
        }
        if let sheet = zip.file(named: path) ?? zip.file(named: path.replacingOccurrences(of: "xl/", with: "")), !sheet.isEmpty {
            if sheet.count < 3_000_000 {
                let matrix = SheetXML.parse(data: sheet, strings: strings)
                let parsed = parsePreSubOOSItem(matrix) ?? []
                zip.release(path)
                return parsed
            }
            let rows = parsePreSubItemStreaming(data: sheet, strings: strings, onTick: onTick)
            zip.release(path)
            return rows
        }
        return []
    }

    private static func parsePreSubItemStreaming(
        data: Data? = nil,
        compressed: Data? = nil,
        strings: [String],
        onTick: ((Int) -> Void)? = nil
    ) -> [ParsedWorkbookRow] {
        var storeIdx: Int?
        var divIdx: Int?
        var distIdx: Int?
        var bpnIdx: Int?
        var pctIdx: Int?
        var unitsIdx: Int?
        var dollarsIdx: Int?
        var oosPctIdx: Int?
        var oosDollarsIdx: Int?
        var ready = false
        var out: [ParsedWorkbookRow] = []
        var seen = 0
        out.reserveCapacity(8_192)
        let handle: ([String]) -> Void = { line in
            if !ready {
                guard isPreSubItemHeader(line) else { return }
                let names = line.map(normHeader)
                storeIdx = names.firstIndex { storeKeys.contains($0) || $0 == "store" || $0.hasPrefix("store") }
                divIdx = names.firstIndex { $0 == "division" }
                distIdx = names.firstIndex { $0 == "district" }
                bpnIdx = names.firstIndex { $0.contains("bpn") || $0.contains("item") || $0.contains("upc") }
                pctIdx = line.indices.first { idx in
                    let lower = line[idx].lowercased()
                    return (lower.contains("pre-sub") || lower.contains("presub") || lower.contains("pre sub")
                        || (lower.contains("pre") && lower.contains("substitution")))
                        && (lower.contains("%") || names[idx].hasSuffix("pct"))
                }
                unitsIdx = line.indices.first { idx in
                    let lower = line[idx].lowercased()
                    let n = names[idx]
                    return (lower.contains("pre-sub oos") || lower.contains("presub oos") || n == "presuboos")
                        && !lower.contains("%") && !lower.contains("$")
                }
                dollarsIdx = line.indices.first { idx in
                    let lower = line[idx].lowercased()
                    return lower.contains("$") && (lower.contains("pre-sub") || lower.contains("presub") || lower.contains("substitution"))
                }
                oosPctIdx = names.firstIndex { $0 == "oospct" || $0 == "oospercent" }
                oosDollarsIdx = line.indices.first { idx in
                    let lower = line[idx].lowercased()
                    return lower.contains("$") && lower.contains("oos") && !lower.contains("pre")
                }
                ready = storeIdx != nil && bpnIdx != nil
                return
            }
            seen += 1
            if seen % 2_000 == 0 { onTick?(out.count) }
            func cell(_ index: Int?) -> String {
                guard let index, index < line.count else { return "" }
                return line[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let storeRaw = cell(storeIdx)
            guard looksLikeStoreNumber(storeRaw), !isTotalCell(storeRaw) else { return }
            let item = cell(bpnIdx)
            guard !item.isEmpty else { return }
            var payload: [String: Double] = [:]
            func put(_ index: Int?, _ key: String, percent: Bool = false) {
                guard let raw = index.map(cell), let number = cellNumber(raw) else { return }
                payload[key] = percent && abs(number) <= 1.5 ? number * 100 : number
            }
            put(pctIdx, "presub_pct", percent: true)
            put(unitsIdx, "presub_count")
            put(dollarsIdx, "presub_dollars")
            put(oosPctIdx, "oos_pct", percent: true)
            put(oosDollarsIdx, "oos_dollars")
            var text: [String: String] = ["presub_item": "1", "bpn": item]
            let district = cell(distIdx)
            if !district.isEmpty { text["district"] = HeartbeatMath.canonicalDistrict(district) }
            let divRaw = cell(divIdx)
            let divName = MarketRegion.canonicalName(divRaw)
            out.append(
                ParsedWorkbookRow(
                    division: divName.isEmpty ? divRaw : divName,
                    operationsOM: "",
                    storeNumber: HeartbeatMath.canonicalStore(storeRaw),
                    storeName: nil,
                    recordedOn: nil,
                    payload: payload,
                    textPayload: text
                )
            )
        }
        if let compressed {
            SheetXML.forEachRowInflating(compressed: compressed, strings: strings, handle: handle)
        } else if let data {
            SheetXML.forEachRowBytes(data: data, strings: strings, handle: handle)
        }
        onTick?(out.count)
        return out
    }

    private static func isMissingItemsDeptRow(_ row: [String]) -> Bool {
        let blob = row.map { $0.lowercased() }.joined(separator: " ")
        if blob.contains("department desc") { return true }
        if isPreSubDeptRow(row) { return true }
        let hits = row.filter { MissingItemDept.match($0) != nil }.count
        return hits >= 4
    }

    private static func isPreSubDeptRow(_ row: [String]) -> Bool {
        row.contains { cell in
            let compact = cell.lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
            return compact == "departmentnm" || compact == "departmentname"
        }
    }

    private static func isPreSubHeaderRow(_ row: [String]) -> Bool {
        let blob = row.map { $0.lowercased() }.joined(separator: " ")
        return blob.contains("pre-sub") || blob.contains("presub") || blob.contains("pre sub oos") || blob.contains("pre sub")
    }

    private static func parsePreSubOOS(_ matrix: [[String]]) -> [ParsedWorkbookRow]? {
        guard let deptRowIndex = matrix.firstIndex(where: { isPreSubDeptRow($0) || isMissingItemsDeptRow($0) }) else { return nil }
        let identityRow = deptRowIndex + 1 < matrix.count ? matrix[deptRowIndex + 1] : []
        let namedPreSub = isPreSubDeptRow(matrix[deptRowIndex]) || isPreSubHeaderRow(identityRow) || isPreSubHeaderRow(matrix[deptRowIndex])
        guard namedPreSub else { return nil }

        let deptRow = matrix[deptRowIndex]
        var keyByCol: [Int: String] = [:]
        for (index, cell) in deptRow.enumerated() {
            if MissingItemDept.isTotalHeader(cell) {
                keyByCol[index] = MissingItemDept.totalKey
            } else if let dept = MissingItemDept.match(cell) {
                keyByCol[index] = dept.rawValue
            }
        }
        guard keyByCol.count >= 4 else { return nil }

        var storeIdx: Int?
        for (index, cell) in identityRow.enumerated() where keyByCol[index] == nil {
            let name = normHeader(cell)
            if storeKeys.contains(name) || name == "store" { storeIdx = index }
        }
        if storeIdx == nil {
            storeIdx = deptRow.indices.first { MissingItemDept.match(deptRow[$0]) == nil && !MissingItemDept.isTotalHeader(deptRow[$0]) }
        }
        guard let storeIdx else { return nil }

        let identityLooksLikeStore = looksLikeStoreNumber(
            storeIdx < identityRow.count ? identityRow[storeIdx] : ""
        )
        let dataStart = identityLooksLikeStore ? deptRowIndex + 1 : deptRowIndex + 2

        var out: [ParsedWorkbookRow] = []
        out.reserveCapacity(max(0, matrix.count - deptRowIndex))
        for line in matrix.dropFirst(dataStart) {
            let storeRaw = storeIdx < line.count ? line[storeIdx].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            if storeRaw.lowercased().hasPrefix("applied") { continue }
            if isTotalCell(storeRaw) { continue }
            guard looksLikeStoreNumber(storeRaw) else { continue }

            var payload: [String: Double] = [:]
            for (index, key) in keyByCol {
                let raw = index < line.count ? line[index] : ""
                guard let number = cellNumber(raw) else { continue }
                var value = number
                if abs(value) <= 1.5 { value *= 100 }
                payload[key] = value
            }
            guard payload[MissingItemDept.totalKey] != nil || payload.count >= 3 else { continue }
            out.append(
                ParsedWorkbookRow(
                    division: "",
                    operationsOM: "",
                    storeNumber: HeartbeatMath.canonicalStore(storeRaw),
                    storeName: nil,
                    recordedOn: nil,
                    payload: payload,
                    textPayload: ["presub_dept": "1"]
                )
            )
        }
        return out.isEmpty ? nil : out
    }

    private static func parseMissingItems(_ matrix: [[String]]) -> [ParsedWorkbookRow]? {
        guard let deptRowIndex = matrix.firstIndex(where: isMissingItemsDeptRow) else { return nil }
        if isPreSubDeptRow(matrix[deptRowIndex]) { return nil }
        let identityRow = deptRowIndex + 1 < matrix.count ? matrix[deptRowIndex + 1] : []
        if isPreSubHeaderRow(identityRow) || isPreSubHeaderRow(matrix[deptRowIndex]) { return nil }
        let deptRow = matrix[deptRowIndex]
        var keyByCol: [Int: String] = [:]
        for (index, cell) in deptRow.enumerated() {
            if MissingItemDept.isTotalHeader(cell) {
                keyByCol[index] = MissingItemDept.totalKey
            } else if let dept = MissingItemDept.match(cell) {
                keyByCol[index] = dept.rawValue
            }
        }
        guard keyByCol.count >= 4 else { return nil }

        var divIdx: Int?
        var distIdx: Int?
        var omIdx: Int?
        var storeIdx: Int?
        for (index, cell) in identityRow.enumerated() where keyByCol[index] == nil {
            let name = normHeader(cell)
            if name.contains("division") { divIdx = index }
            else if districtKeys.contains(name) || name == "district" { distIdx = index }
            else if omKeys.contains(name) || name == "om" { omIdx = index }
            else if storeKeys.contains(name) || name == "store" { storeIdx = index }
        }
        if storeIdx == nil {
            divIdx = 0
            distIdx = 1
            omIdx = 2
            storeIdx = 3
        }

        var carryDiv = ""
        var carryDist = ""
        var carryOM = ""
        var out: [ParsedWorkbookRow] = []
        out.reserveCapacity(max(0, matrix.count - deptRowIndex))

        for line in matrix.dropFirst(deptRowIndex + 2) {
            func cell(_ index: Int?) -> String {
                guard let index, index < line.count else { return "" }
                return line[index]
            }
            if let value = usableValue(cell(divIdx)) { carryDiv = value }
            if let value = usableValue(cell(distIdx)) { carryDist = value }
            if let value = usableValue(cell(omIdx)) { carryOM = value }

            let storeRaw = cell(storeIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            if storeRaw.lowercased().hasPrefix("applied") { continue }
            if isTotalCell(storeRaw) { continue }
            if storeRaw.isEmpty {
                if isTotalCell(cell(omIdx)) || isTotalCell(cell(distIdx)) || isTotalCell(cell(divIdx)) {
                    continue
                }
                continue
            }
            guard looksLikeStoreNumber(storeRaw) else { continue }

            var payload: [String: Double] = [:]
            for (index, key) in keyByCol {
                let raw = index < line.count ? line[index] : ""
                guard let number = cellNumber(raw) else { continue }
                var value = number
                if abs(value) <= 1.5 { value *= 100 }
                payload[key] = value
            }
            guard payload[MissingItemDept.totalKey] != nil || payload.count >= 3 else { continue }

            var text: [String: String] = [:]
            if !carryDist.isEmpty { text["district"] = carryDist }
            out.append(
                ParsedWorkbookRow(
                    division: carryDiv,
                    operationsOM: carryOM,
                    storeNumber: HeartbeatMath.canonicalStore(storeRaw),
                    storeName: nil,
                    recordedOn: nil,
                    payload: payload,
                    textPayload: text
                )
            )
        }
        return out.isEmpty ? nil : out
    }

    private static func parseLabor(_ matrix: [[String]]) -> [ParsedWorkbookRow]? {
        guard let headerIndex = matrix.firstIndex(where: { row in
            let names = row.map(normHeader)
            return names.contains("storeid") && names.contains(where: { $0.contains("targetvsactual") || $0.contains("costtrgt") })
        }) else { return nil }
        let headerRow = matrix[headerIndex]
        let names = headerRow.map(normHeader)
        if !names.contains("weekid") {
            return matrix[(headerIndex + 1)...].compactMap { laborStoreRow($0, header: headerRow, names: names) }
        }
        var acc: [String: [String: LaborWeekAcc]] = [:]
        var week = ""
        var date = ""
        var division = ""
        var district = ""
        for row in matrix[(headerIndex + 1)...] {
            guard let parsed = laborRow(
                row,
                header: headerRow,
                names: names,
                week: &week,
                date: &date,
                division: &division,
                district: &district
            ) else { continue }
            mergeLabor(&acc, parsed)
        }
        return flattenLabor(acc)
    }

    private static func parseLaborFromZip(
        zip: ZipArchive,
        path: String,
        strings: [String],
        onTick: ((Int, String) -> Void)?
    ) -> [ParsedWorkbookRow] {
        if let packed = zip.compressedPayload(named: path) ?? zip.compressedPayload(named: path.replacingOccurrences(of: "xl/", with: "")),
           packed.method == 8 {
            if packed.uncomp > 8_000_000, let range = zip.compressedRange(named: path) ?? zip.compressedRange(named: path.replacingOccurrences(of: "xl/", with: "")) {
                let fast = parseLaborLatestWeek(zipData: zip.rawBytes, offset: range.offset, size: range.size, strings: strings, onTick: onTick)
                if !fast.isEmpty { return fast }
            }
            var rows = parseLaborSheet(compressed: packed.bytes, strings: strings, onTick: onTick)
            if rows.isEmpty {
                rows = parseLaborStoreViewRaw(compressed: packed.bytes, strings: strings, onTick: onTick)
            }
            return rows
        }
        if let sheet = zip.file(named: path) ?? zip.file(named: path.replacingOccurrences(of: "xl/", with: "")), !sheet.isEmpty {
            var rows = parseLaborSheet(data: sheet, strings: strings, onTick: onTick)
            if rows.isEmpty {
                rows = parseLaborStoreViewRaw(data: sheet, strings: strings, onTick: onTick)
            }
            zip.release(path)
            return rows
        }
        return []
    }

    private static func parsePickersFromZip(
        zip: ZipArchive,
        path: String,
        strings: [String],
        pathPicker: Bool,
        onTick: ((Int) -> Void)?
    ) -> [ParsedWorkbookRow] {
        var parsed: [ParsedWorkbookRow] = []
        if !pathPicker, let sheet = zip.file(named: path) ?? zip.file(named: path.replacingOccurrences(of: "xl/", with: "")),
           !sheet.isEmpty, sheet.count < 24_000_000 {
            let matrix = SheetXML.parse(data: sheet, strings: strings)
            if let simple = parsePickerWeeklyFlat(matrix), simple.count >= 20 {
                zip.release(path)
                return compactShoppers(simple)
            }
        }
        if !pathPicker, let packed = zip.compressedPayload(named: path) ?? zip.compressedPayload(named: path.replacingOccurrences(of: "xl/", with: "")),
           packed.method == 8 {
            parsed = parsePickerCompactRaw(compressed: packed.bytes, strings: strings, onTick: onTick)
            if parsed.count < 10_000 {
                let streamed = parsePickerStreaming(compressed: packed.bytes, strings: strings, onTick: onTick)
                if streamed.count > parsed.count { parsed = streamed }
            }
        } else if pathPicker, let packed = zip.compressedPayload(named: path) ?? zip.compressedPayload(named: path.replacingOccurrences(of: "xl/", with: "")),
                  packed.method == 8 {
            parsed = parseEmployeeStreaming(compressed: packed.bytes, strings: strings)
        } else if parsed.isEmpty, let sheet = zip.file(named: path) ?? zip.file(named: path.replacingOccurrences(of: "xl/", with: "")), !sheet.isEmpty {
            parsed = pathPicker
                ? parseEmployeeStreaming(data: sheet, strings: strings)
                : parsePickerStreaming(data: sheet, strings: strings, onTick: onTick)
            zip.release(path)
        }
        if !parsed.isEmpty {
            parsed = compactShoppers(parsed)
        }
        return parsed
    }

    private static func parseLaborLatestWeek(
        compressed: Data? = nil,
        zipData: Data? = nil,
        offset: Int = 0,
        size: Int = 0,
        strings: [String],
        onTick: ((Int, String) -> Void)?
    ) -> [ParsedWorkbookRow] {
        var bestWeek = ""
        var stores: [String: (division: String, district: String, payload: [String: Double])] = [:]
        stores.reserveCapacity(2200)
        var seen = 0
        let source = zipData ?? compressed ?? Data()
        let origin = zipData == nil ? 0 : offset
        let length = zipData == nil ? source.count : size
        SheetXML.forEachRowInflating(
            compressed: source,
            offset: origin,
            count: length,
            strings: strings,
            handleRaw: { data in
                seen += 1
                let weekRaw = SheetXML.rawCell(data, letter: "A", strings: strings)
                let storeRaw = SheetXML.rawCell(data, letter: "E", strings: strings)
                guard let week = usableValue(weekRaw), week.hasPrefix("20"), week.count >= 6 else { return }
                if !bestWeek.isEmpty, week < bestWeek { return }
                guard let store = usableValue(storeRaw), looksLikeStoreNumber(store), Double(store) ?? 0 < 200_000 else { return }
                if week > bestWeek {
                    bestWeek = week
                    stores.removeAll(keepingCapacity: true)
                }
                let key = HeartbeatMath.canonicalStore(store)
                var payload: [String: Double] = [:]
                func metric(_ letter: String, _ header: String, _ name: String) {
                    let raw = SheetXML.rawCell(data, letter: letter, strings: strings)
                    guard let number = cellNumber(raw) else { return }
                    laborMetric(&payload, header: header, key: name, value: number)
                }
                metric("F", "Sch Effi%", "scheffi")
                metric("G", "Empower Hrs", "empowerhrs")
                metric("H", "Sch_Hrs", "schhrs")
                metric("I", "ActHrs", "acthrs")
                metric("J", "Earned Hrs", "earnedhrs")
                metric("M", "ActCost$", "actcost$")
                metric("N", "CostTrgt%", "costtrgt")
                metric("O", "UPLH Impact", "uplhimpact")
                metric("P", "Wage Impact", "wageimpact")
                metric("Q", "AIV Impact", "aivimpact")
                metric("R", "ActCost%", "actcost")
                metric("S", "Target vs Actual%", "targetvsactual")
                if payload["act_cost_pct"] == nil,
                   let cost = payload["cost_trgt_pct"],
                   let tva = payload["target_vs_actual_pct"] {
                    payload["act_cost_pct"] = cost + tva
                }
                stores[key] = (
                    division: SheetXML.rawCell(data, letter: "B", strings: strings),
                    district: SheetXML.rawCell(data, letter: "C", strings: strings),
                    payload: payload
                )
                if seen % 20000 == 0 {
                    onTick?(stores.count, "stores")
                }
            }
        )
        onTick?(stores.count, "stores")
        var rows = stores.map { store, value -> ParsedWorkbookRow in
            ParsedWorkbookRow(
                division: value.division,
                operationsOM: "",
                storeNumber: store,
                storeName: nil,
                recordedOn: nil,
                payload: value.payload,
                textPayload: [
                    "labor_grain": "store",
                    "week": bestWeek,
                    "district": value.district,
                    "parser_rev": "8",
                ]
            )
        }
        if !stores.isEmpty {
            var total: [String: Double] = [:]
            var counts: [String: Double] = [:]
            for value in stores.values {
                for (key, number) in value.payload {
                    total[key, default: 0] += number
                    counts[key, default: 0] += 1
                }
            }
            var payload: [String: Double] = [:]
            for (key, sum) in total {
                if key.hasSuffix("_hrs") || key.contains("dollar") {
                    payload[key] = sum
                } else if let count = counts[key], count > 0 {
                    payload[key] = sum / count
                }
            }
            rows.append(
                ParsedWorkbookRow(
                    division: "",
                    operationsOM: "",
                    storeNumber: "TOTAL",
                    storeName: nil,
                    recordedOn: nil,
                    payload: payload,
                    textPayload: [
                        "labor_grain": "market",
                        "week": bestWeek,
                        "parser_rev": "8",
                    ]
                )
            )
        }
        return rows
    }

    private static func parseLaborStoreViewRaw(
        data: Data? = nil,
        compressed: Data? = nil,
        strings: [String],
        onTick: ((Int, String) -> Void)? = nil
    ) -> [ParsedWorkbookRow] {
        var out: [ParsedWorkbookRow] = []
        out.reserveCapacity(2200)
        var seen = 0
        let handleRaw: (Data) -> Void = { blob in
            seen += 1
            let storeRaw = SheetXML.rawCell(blob, letter: "A", strings: strings)
            guard let store = usableValue(storeRaw), looksLikeStoreNumber(store) else { return }
            var payload: [String: Double] = [:]
            func metric(_ letter: String, _ header: String, _ name: String) {
                let raw = SheetXML.rawCell(blob, letter: letter, strings: strings)
                guard let number = cellNumber(raw) else { return }
                laborMetric(&payload, header: header, key: name, value: number)
            }
            metric("B", "Sch Effi%", "scheffi")
            metric("C", "Empower Hrs", "empowerhrs")
            metric("D", "Sch_Hrs", "schhrs")
            metric("E", "ActHrs", "acthrs")
            metric("F", "Earned Hrs", "earnedhrs")
            metric("K", "CostTrgt%", "costtrgt")
            metric("O", "ActCost%", "actcost")
            metric("P", "Target vs Actual%", "targetvsactual")
            metric("J", "ActCost$", "actcost$")
            guard !payload.isEmpty else { return }
            out.append(
                ParsedWorkbookRow(
                    division: "",
                    operationsOM: "",
                    storeNumber: HeartbeatMath.canonicalStore(store),
                    storeName: nil,
                    recordedOn: nil,
                    payload: payload,
                    textPayload: ["labor_grain": "store", "parser_rev": "9"]
                )
            )
            if out.count % 400 == 0 { onTick?(out.count, "stores") }
        }
        if let compressed {
            SheetXML.forEachRowInflating(compressed: compressed, strings: strings, handleRaw: handleRaw)
        } else if let data {
            SheetXML.forEachRowBytes(data: data, strings: strings, handle: { _ in })
            // byte path: inflate-style raw not available; walk cells instead
        }
        onTick?(out.count, "stores")
        return out
    }

    private static func parseLaborSheet(
        data: Data? = nil,
        compressed: Data? = nil,
        strings: [String],
        onTick: ((Int, String) -> Void)? = nil
    ) -> [ParsedWorkbookRow] {
        var header: [String] = []
        var names: [String] = []
        var week = ""
        var date = ""
        var division = ""
        var district = ""
        var acc: [String: [String: LaborWeekAcc]] = [:]
        var storeRows: [ParsedWorkbookRow] = []
        var storeView = false
        var keep: Set<Int>?
        var idxStore = -1
        var idxWeek = -1
        var idxDate = -1
        var idxDiv = -1
        var idxDist = -1
        var metricIdx: [(Int, String, String)] = []
        var seen = 0
        var layoutReady = false
        acc.reserveCapacity(2200)
        storeRows.reserveCapacity(2200)
        let handle: ([String]) -> Void = { row in
            func cell(_ index: Int) -> String {
                guard index >= 0, index < row.count else { return "" }
                return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if header.isEmpty {
                let mapped = row.map(normHeader)
                let hasStore = mapped.contains("storeid") || mapped.contains("store")
                let hasWeek = mapped.contains("weekid") || mapped.contains("ddate")
                let hasMetric = mapped.contains(where: {
                    $0.contains("costtrgt") || $0.contains("targetvsactual") || $0.contains("scheffi")
                        || $0.contains("actcost") || $0.contains("acthrs") || $0.contains("earned")
                        || $0.contains("empower") || $0 == "tva"
                })
                if hasStore && hasMetric {
                    header = row
                    names = mapped
                    let weekHeader = mapped.firstIndex(of: "weekid") ?? mapped.firstIndex(of: "ddate")
                    storeView = weekHeader == nil
                    idxStore = mapped.firstIndex(of: "storeid") ?? mapped.firstIndex(of: "store") ?? 0
                    idxDiv = mapped.firstIndex(of: "divisionnm") ?? mapped.firstIndex(of: "division") ?? -1
                    idxDist = mapped.firstIndex(of: "district") ?? -1
                    if weekHeader != nil {
                        idxWeek = mapped.firstIndex(of: "weekid") ?? -1
                        idxDate = mapped.firstIndex(of: "ddate") ?? -1
                    }
                    var cols = Set<Int>()
                    for (index, key) in mapped.enumerated() where laborKeepColumn(key) {
                        cols.insert(index)
                    }
                    cols.insert(idxStore)
                    cols.insert(idxWeek)
                    if idxDiv >= 0 { cols.insert(idxDiv) }
                    if idxDist >= 0 { cols.insert(idxDist) }
                    keep = cols
                    metricIdx = mapped.enumerated().compactMap { index, key in
                        guard laborKeepColumn(key),
                              !["storeid", "store", "weekid", "ddate", "divisionnm", "division", "district"].contains(key)
                        else { return nil }
                        return (index, row[index], key)
                    }
                }
                return
            }
            seen += 1
            if seen % 4000 == 0 {
                onTick?(max(acc.count, storeRows.count), "stores")
            }
            if !layoutReady {
                layoutReady = true
                let first = cell(0)
                if first.count >= 6, first.hasPrefix("20"), looksLikeStoreNumber(first) == false || Double(first) ?? 0 >= 200_000 {
                    storeView = false
                    idxWeek = 0
                    if idxStore < 0 || idxStore == 0 { idxStore = 4 }
                    if idxDiv < 0 { idxDiv = 1 }
                    if idxDist < 0 { idxDist = 2 }
                    for index in 1..<min(row.count, 8) where looksLikeStoreNumber(cell(index)) {
                        idxStore = index
                        break
                    }
                    keep = Set(([idxWeek, idxStore, idxDiv, idxDist] + metricIdx.map(\.0)).filter { $0 >= 0 })
                }
            }
            if storeView {
                if let parsed = laborStoreRow(row, header: header, names: names) {
                    storeRows.append(parsed)
                }
                return
            }
            if idxWeek >= 0, let value = usableValue(cell(idxWeek)) {
                week = Self.normalizeWeekID(value)
            }
            if week.lowercased().contains("applied") || isTotalCell(week) { return }
            let dateRaw = cell(idxDate)
            if isTotalCell(dateRaw) {
                date = ""
            } else if let value = excelSerialDate(dateRaw) ?? usableValue(dateRaw) {
                date = value
            }
            let divRaw = cell(idxDiv)
            if isTotalCell(divRaw) {
                division = ""
            } else if let value = usableValue(divRaw) {
                division = value
            }
            let distRaw = cell(idxDist)
            if isTotalCell(distRaw) {
                district = ""
            } else if let value = usableValue(distRaw) {
                district = value
            }
            let storeRaw = cell(idxStore)
            guard let store = usableValue(storeRaw), looksLikeStoreNumber(store), Double(store) ?? 0 < 200_000 else { return }
            if date.isEmpty { date = week }
            var payload: [String: Double] = [:]
            for (index, rawHeader, key) in metricIdx where index < row.count {
                guard let number = cellNumber(row[index]) else { continue }
                laborMetric(&payload, header: rawHeader, key: key, value: number)
            }
            mergeLabor(
                &acc,
                ParsedWorkbookRow(
                    division: division,
                    operationsOM: "",
                    storeNumber: HeartbeatMath.canonicalStore(store),
                    storeName: nil,
                    recordedOn: date,
                    payload: payload,
                    textPayload: ["labor_grain": "day", "week": week, "district": district]
                )
            )
        }
        if let compressed {
            SheetXML.forEachRowInflating(
                compressed: compressed,
                strings: strings,
                keep: { keep },
                include: { data in
                    if header.isEmpty { return true }
                    return SheetXML.columnLooksLikeStore(data, letter: SheetXML.colLetter(max(idxStore, 4)))
                },
                handle: handle
            )
        } else if let data {
            SheetXML.forEachRowBytes(data: data, strings: strings, keep: { keep }, handle: handle)
        }
        if storeView { return storeRows }
        return flattenLabor(acc)
    }

    private static func laborKeepColumn(_ key: String) -> Bool {
        key == "storeid" || key == "store" || key == "weekid" || key == "ddate"
            || key == "divisionnm" || key == "division" || key == "district"
            || key.contains("costtrgt") || key.contains("targetvsactual") || key.contains("scheffi")
            || key.contains("actcost") || key.contains("acttrgt") || key.contains("empower")
            || key.contains("acthrs") || key.contains("schhrs") || key.contains("earned")
            || key.contains("uplh") || key.contains("wage") || key.contains("aiv")
            || key.contains("charged") || key.contains("overschedule")
    }

    private static func laborStoreRow(_ row: [String], header: [String], names: [String]) -> ParsedWorkbookRow? {
        func cell(_ key: String) -> String {
            guard let index = names.firstIndex(of: key), index < row.count else { return "" }
            return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let storeRaw = cell("storeid").isEmpty ? cell("store") : cell("storeid")
        let market = isTotalCell(storeRaw)
        let store: String
        if market {
            store = "TOTAL"
        } else {
            guard let value = usableValue(storeRaw), looksLikeStoreNumber(value) else { return nil }
            store = value
        }
        var payload: [String: Double] = [:]
        for (index, rawHeader) in header.enumerated() where index < row.count {
            let key = names.indices.contains(index) ? names[index] : normHeader(rawHeader)
            if key == "storeid" { continue }
            guard let number = cellNumber(row[index]) else { continue }
            laborMetric(&payload, header: rawHeader, key: key, value: number)
        }
        guard !payload.isEmpty else { return nil }
        if payload["act_cost_pct"] == nil,
           let cost = payload["cost_trgt_pct"],
           let tva = payload["target_vs_actual_pct"] {
            payload["act_cost_pct"] = cost + tva
        }
        return ParsedWorkbookRow(
            division: "",
            operationsOM: "",
            storeNumber: store,
            storeName: nil,
            recordedOn: nil,
            payload: payload,
            textPayload: [
                "labor_grain": market ? "market" : "store",
                "parser_rev": "8",
            ]
        )
    }

    private final class LaborWeekAcc {
        var division: String
        var district: String
        var tva: Double?
        var cost: Double?
        var dollars: Double?
        var hours: Double?
        var uplh: Double?
        var wage: Double?
        var aiv: Double?
        var days: [LaborDay] = []

        init(division: String, district: String) {
            self.division = division
            self.district = district
        }
    }

    private static func mergeLabor(_ acc: inout [String: [String: LaborWeekAcc]], _ row: ParsedWorkbookRow) {
        let store = row.storeNumber
        let week = row.textPayload["week"] ?? ""
        guard !store.isEmpty, !week.isEmpty else { return }
        if acc[store] == nil { acc[store] = [:] }
        let bucket: LaborWeekAcc
        if let existing = acc[store]?[week] {
            bucket = existing
        } else {
            bucket = LaborWeekAcc(division: row.division, district: row.textPayload["district"] ?? "")
            acc[store]?[week] = bucket
        }
        if bucket.tva == nil { bucket.tva = row.payload["target_vs_actual_pct"] }
        if bucket.cost == nil { bucket.cost = row.payload["cost_trgt_pct"] }
        if bucket.dollars == nil { bucket.dollars = row.payload["act_cost_dollar"] }
        if bucket.hours == nil { bucket.hours = row.payload["act_hrs"] }
        if bucket.uplh == nil { bucket.uplh = row.payload["uplh_impact_pct"] }
        if bucket.wage == nil { bucket.wage = row.payload["wage_impact_pct"] }
        if bucket.aiv == nil { bucket.aiv = row.payload["aiv_impact_pct"] }
        if bucket.division.isEmpty { bucket.division = row.division }
        if bucket.district.isEmpty { bucket.district = row.textPayload["district"] ?? "" }
        bucket.days.append(
            LaborDay(
                date: row.recordedOn ?? "",
                scheduleEfficiencyPct: row.payload["schedule_efficiency_pct"],
                schHrs: row.payload["sch_hrs"],
                empowerHrs: row.payload["empower_hrs"],
                earnedHrs: row.payload["earned_hrs"],
                earnedHrsUtil: row.payload["earned_hrs_util"],
                actCostPct: row.payload["act_cost_pct"],
                overSchedulePct: row.payload["over_schedule_pct"],
                chargedHrs: row.payload["charged_hrs"]
            )
        )
    }

    private static func flattenLabor(_ acc: [String: [String: LaborWeekAcc]]) -> [ParsedWorkbookRow] {
        var out: [ParsedWorkbookRow] = []
        out.reserveCapacity(acc.count * 9)
        let encoder = JSONEncoder()
        for (store, weeks) in acc {
            let ordered = weeks.keys.sorted()
            var sumDollars = 0.0
            var sumHours = 0.0
            var sumSch = 0.0
            var sumEmp = 0.0
            var sumCharged = 0.0
            var sumEarned = 0.0
            var weightedTva = 0.0
            var tvaWeight = 0.0
            var weightedCost = 0.0
            var costWeight = 0.0
            var weightedUplh = 0.0
            var weightedWage = 0.0
            var weightedAiv = 0.0
            var impactWeight = 0.0
            var weightedEff = 0.0
            var effWeight = 0.0
            var division = ""
            var district = ""
            for week in ordered where week.hasPrefix("20") {
                guard let bucket = weeks[week] else { continue }
                if division.isEmpty { division = bucket.division }
                if district.isEmpty { district = bucket.district }
                let hours = bucket.hours ?? 0
                let dollars = bucket.dollars ?? 0
                let sch = bucket.days.reduce(0) { $0 + ($1.schHrs ?? 0) }
                let emp = bucket.days.reduce(0) { $0 + ($1.empowerHrs ?? 0) }
                let charged = bucket.days.reduce(0) { $0 + ($1.chargedHrs ?? 0) }
                let earned = bucket.days.reduce(0) { $0 + ($1.earnedHrs ?? 0) }
                sumHours += hours
                sumDollars += dollars
                sumSch += sch
                sumEmp += emp
                sumCharged += charged
                sumEarned += earned
                let weight = earned > 0 ? earned : (hours > 0 ? hours : 1)
                if let tva = bucket.tva {
                    weightedTva += tva * weight
                    tvaWeight += weight
                }
                if let cost = bucket.cost {
                    let costW = sch > 0 ? sch : weight
                    weightedCost += cost * costW
                    costWeight += costW
                }
                if bucket.uplh != nil || bucket.wage != nil || bucket.aiv != nil {
                    weightedUplh += (bucket.uplh ?? 0) * weight
                    weightedWage += (bucket.wage ?? 0) * weight
                    weightedAiv += (bucket.aiv ?? 0) * weight
                    impactWeight += weight
                }
                var payload: [String: Double] = [:]
                if let tva = bucket.tva { payload["target_vs_actual_pct"] = tva }
                if let cost = bucket.cost { payload["cost_trgt_pct"] = cost }
                if let costValue = bucket.dollars { payload["act_cost_dollar"] = costValue }
                if let hourValue = bucket.hours { payload["act_hrs"] = hourValue }
                if sch > 0 { payload["sch_hrs"] = sch }
                if emp > 0 { payload["empower_hrs"] = emp }
                if charged > 0 { payload["charged_hrs"] = charged }
                if earned > 0 { payload["earned_hrs"] = earned }
                if emp > 0 { payload["over_schedule_pct"] = (sch - emp) / emp * 100 }
                var weekEff = 0.0
                var weekEffW = 0.0
                var weekUtil = 0.0
                var weekUtilW = 0.0
                for day in bucket.days {
                    let weight = day.empowerHrs ?? day.schHrs ?? 1
                    if let value = day.scheduleEfficiencyPct {
                        weekEff += value * weight
                        weekEffW += weight
                    }
                    if let value = day.earnedHrsUtil {
                        weekUtil += value * weight
                        weekUtilW += weight
                    }
                }
                if weekEffW > 0 {
                    payload["schedule_efficiency_pct"] = weekEff / weekEffW
                    let storeW = emp > 0 ? emp : weekEffW
                    weightedEff += (weekEff / weekEffW) * storeW
                    effWeight += storeW
                }
                if weekUtilW > 0 { payload["earned_hrs_util"] = weekUtil / weekUtilW }
                if let uplh = bucket.uplh { payload["uplh_impact_pct"] = uplh }
                if let wage = bucket.wage { payload["wage_impact_pct"] = wage }
                if let aiv = bucket.aiv { payload["aiv_impact_pct"] = aiv }
                if let cost = bucket.cost, let tva = bucket.tva {
                    payload["act_cost_pct"] = cost + tva
                }
                let uniqueDays: [LaborDay] = {
                    var latest: [String: LaborDay] = [:]
                    for day in bucket.days where !day.date.isEmpty {
                        latest[day.date] = day
                    }
                    return latest.values.sorted { $0.date < $1.date }
                }()
                let activeDays = uniqueDays.filter { day in
                    (day.chargedHrs ?? 0) > 0
                        || (day.empowerHrs ?? 0) > 0
                        || (day.schHrs ?? 0) > 0
                        || (day.earnedHrs ?? 0) > 0
                }
                let hasActivity = charged > 0 || emp > 0 || sch > 0 || hours > 0 || dollars > 0 || !activeDays.isEmpty
                if !hasActivity { continue }
                if payload["act_cost_pct"] == nil {
                    var chargedWeight = 0.0
                    var mixed = 0.0
                    for day in activeDays {
                        let dayCharged = day.chargedHrs ?? 0
                        guard dayCharged > 0, let pct = day.actCostPct else { continue }
                        chargedWeight += dayCharged
                        mixed += pct * dayCharged
                    }
                    if chargedWeight > 0 { payload["act_cost_pct"] = mixed / chargedWeight }
                }
                let jsonData = (try? encoder.encode(activeDays)) ?? Data("[]".utf8)
                let json = String(data: jsonData, encoding: .utf8) ?? "[]"
                out.append(
                    ParsedWorkbookRow(
                        division: bucket.division,
                        operationsOM: "",
                        storeNumber: store,
                        storeName: nil,
                        recordedOn: week,
                        payload: payload,
                        textPayload: [
                            "labor_grain": "week",
                            "week": week,
                            "district": bucket.district,
                            "days_json": json,
                            "parser_rev": "9",
                        ]
                    )
                )
            }
            var storePayload: [String: Double] = [:]
            if costWeight > 0 { storePayload["cost_trgt_pct"] = weightedCost / costWeight }
            if impactWeight > 0 {
                let uplh = weightedUplh / impactWeight
                let wage = weightedWage / impactWeight
                let aiv = weightedAiv / impactWeight
                storePayload["uplh_impact_pct"] = uplh
                storePayload["wage_impact_pct"] = wage
                storePayload["aiv_impact_pct"] = aiv
                storePayload["target_vs_actual_pct"] = uplh + wage + aiv
            } else if tvaWeight > 0 {
                storePayload["target_vs_actual_pct"] = weightedTva / tvaWeight
            }
            if sumDollars > 0 { storePayload["act_cost_dollar"] = sumDollars }
            if sumHours > 0 { storePayload["act_hrs"] = sumHours }
            if sumSch > 0 { storePayload["sch_hrs"] = sumSch }
            if sumEmp > 0 { storePayload["empower_hrs"] = sumEmp }
            if sumCharged > 0 { storePayload["charged_hrs"] = sumCharged }
            if sumEarned > 0 { storePayload["earned_hrs"] = sumEarned }
            if sumEmp > 0 {
                storePayload["over_schedule_pct"] = (sumSch - sumEmp) / sumEmp * 100
            }
            if effWeight > 0 { storePayload["schedule_efficiency_pct"] = weightedEff / effWeight }
            if let cost = storePayload["cost_trgt_pct"], let tva = storePayload["target_vs_actual_pct"] {
                storePayload["act_cost_pct"] = cost + tva
            } else if sumCharged > 0 {
                var mixed = 0.0
                var weight = 0.0
                for week in ordered {
                    guard let bucket = weeks[week] else { continue }
                    for day in bucket.days {
                        let charged = day.chargedHrs ?? 0
                        guard charged > 0, let pct = day.actCostPct else { continue }
                        mixed += pct * charged
                        weight += charged
                    }
                }
                if weight > 0 { storePayload["act_cost_pct"] = mixed / weight }
            }
            let weekIds = ordered.filter { $0.hasPrefix("20") }
            let span = weekIds.isEmpty ? "" : (weekIds.first == weekIds.last ? weekIds[0] : "\(weekIds.first!)–\(weekIds.last!)")
            out.append(
                ParsedWorkbookRow(
                    division: division,
                    operationsOM: "",
                    storeNumber: store,
                    storeName: nil,
                    recordedOn: span,
                    payload: storePayload,
                    textPayload: [
                        "labor_grain": "store",
                        "week": span,
                        "district": district,
                        "parser_rev": "7",
                    ]
                )
            )
        }
        return out
    }

    private static func laborRow(
        _ row: [String],
        header: [String],
        names: [String],
        week: inout String,
        date: inout String,
        division: inout String,
        district: inout String
    ) -> ParsedWorkbookRow? {
        func cell(_ key: String) -> String {
            guard let index = names.firstIndex(of: key), index < row.count else { return "" }
            return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let value = usableValue(cell("weekid")) {
            week = Self.normalizeWeekID(value)
        }
        if week.lowercased().contains("applied") || isTotalCell(week) { return nil }
        let dateRaw = cell("ddate")
        if isTotalCell(dateRaw) {
            date = ""
        } else if let value = excelSerialDate(dateRaw) ?? usableValue(dateRaw) {
            date = value
        }
        let divRaw = cell("divisionnm").isEmpty ? cell("division") : cell("divisionnm")
        if isTotalCell(divRaw) {
            division = ""
        } else if let value = usableValue(divRaw) {
            division = value
        }
        let distRaw = cell("district")
        if isTotalCell(distRaw) {
            district = ""
        } else if let value = usableValue(distRaw) {
            district = value
        }
        let storeRaw = cell("storeid")
        guard let store = usableValue(storeRaw), looksLikeStoreNumber(store) else { return nil }
        guard !date.isEmpty else { return nil }

        var payload: [String: Double] = [:]
        for (index, rawHeader) in header.enumerated() where index < row.count {
            let key = names.indices.contains(index) ? names[index] : normHeader(rawHeader)
            if ["weekid", "ddate", "divisionnm", "division", "district", "storeid"].contains(key) { continue }
            guard let number = cellNumber(row[index]) else { continue }
            laborMetric(&payload, header: rawHeader, key: key, value: number)
        }
        return ParsedWorkbookRow(
            division: division,
            operationsOM: "",
            storeNumber: HeartbeatMath.canonicalStore(store),
            storeName: nil,
            recordedOn: date,
            payload: payload,
            textPayload: ["labor_grain": "day", "week": week, "district": district]
        )
    }

    private static func laborMetric(_ payload: inout [String: Double], header: String, key: String, value: Double) {
        var mapped = key
        var number = value
        if key.contains("targetvsactual") {
            mapped = "target_vs_actual_pct"
        } else if key.contains("costtrgt") {
            mapped = "cost_trgt_pct"
        } else if key == "actcost" || key.contains("acttrgt") {
            mapped = header.contains("$") ? "act_cost_dollar" : "act_cost_pct"
        } else if key.contains("overschedule") {
            mapped = "over_schedule_pct"
        } else if key.contains("scheffi") {
            mapped = "schedule_efficiency_pct"
        } else if key.contains("empower") {
            mapped = "empower_hrs"
        } else if key.contains("uplh") {
            mapped = "uplh_impact_pct"
        } else if key.contains("wageimpact") || key == "wageimpact" || (key.contains("wage") && key.contains("impact")) {
            mapped = "wage_impact_pct"
        } else if key.contains("aiv") {
            mapped = "aiv_impact_pct"
        } else if key == "acthrs" {
            mapped = "act_hrs"
        } else if key == "schhrs" {
            mapped = "sch_hrs"
        } else if key.contains("chargedhrs") {
            mapped = "charged_hrs"
        } else if key.contains("earnedhrs") && key.contains("util") {
            mapped = "earned_hrs_util"
        } else if key.contains("earnedhrs") {
            mapped = "earned_hrs"
        } else {
            applyMetric(&payload, header: key, value: value)
            return
        }
        if mapped == "earned_hrs_util", abs(number) < 50 {
            number *= 100
        } else if mapped.hasSuffix("_pct"), abs(number) <= 1.0 {
            number *= 100
        } else if mapped.hasSuffix("_pct"), abs(number) > 1, abs(number) <= 8 {
            number *= 100
        }
        payload[mapped] = number
    }

    private static func excelSerialDate(_ raw: String) -> String? {
        guard let serial = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              serial > 20000, serial < 80000
        else { return nil }
        let unix = (serial - 25569.0) * 86400.0
        let date = Date(timeIntervalSince1970: unix)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Weekly picker scorecard: STORE + PICKER, date blocks across the top, Total block last.
    /// DATE banner + DIVISION / District / OM / Store + Net Prep Not Ready Hours % Total.
    private static func parsePrepHours(_ matrix: [[String]]) -> [ParsedWorkbookRow]? {
        guard let headerIndex = matrix.firstIndex(where: { row in
            let names = row.map(normHeader)
            let hasStore = names.contains(where: { storeKeys.contains($0) || $0 == "store" })
            let hasPNR = names.contains(where: {
                $0.contains("prepnotready") || $0.contains("notready") || $0.contains("pnrhour")
                    || $0.contains("pnrrate") || $0 == "pnr" || $0.contains("pnr")
            })
            return hasStore && hasPNR
        }) else { return nil }

        let header = matrix[headerIndex].map(normHeader)
        let storeIdx = header.firstIndex { storeKeys.contains($0) || $0 == "store" }
        let divIdx = header.firstIndex { divisionKeys.contains($0) }
        let distIdx = header.firstIndex { districtKeys.contains($0) }
        let omIdx = header.firstIndex { omKeys.contains($0) }
        guard let storeIdx else { return nil }

        let weekRow = headerIndex > 0 ? matrix[headerIndex - 1] : []
        var totalIdx: Int?
        for (index, cell) in weekRow.enumerated() where isTotalCell(cell) {
            totalIdx = index
        }
        if totalIdx == nil {
            totalIdx = header.indices.last { index in
                header[index].contains("prepnotready") || header[index].contains("notready")
                    || header[index].contains("pnr")
            }
        }
        guard let totalIdx else { return nil }

        var recordedOn: String?
        for cell in weekRow {
            if let date = isoDate(cell) { recordedOn = date }
        }

        var carryDiv = ""
        var carryDist = ""
        var carryOM = ""
        var out: [ParsedWorkbookRow] = []
        out.reserveCapacity(max(0, matrix.count - headerIndex))

        for line in matrix.dropFirst(headerIndex + 1) {
            func cell(_ index: Int?) -> String {
                guard let index, index < line.count else { return "" }
                return line[index]
            }
            if let value = usableValue(cell(divIdx)) { carryDiv = value }
            if let value = usableValue(cell(distIdx)) { carryDist = value }
            if let value = usableValue(cell(omIdx)) { carryOM = value }

            let storeRaw = cell(storeIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            if storeRaw.isEmpty { continue }
            if isTotalCell(storeRaw) { continue }
            if storeRaw.lowercased().hasPrefix("applied") { continue }
            guard looksLikeStoreNumber(storeRaw) else { continue }
            var raw = totalIdx < line.count ? line[totalIdx] : ""
            if cellNumber(raw) == nil {
                for index in stride(from: line.count - 1, through: 0, by: -1) {
                    if index == storeIdx || index == divIdx || index == distIdx || index == omIdx { continue }
                    let candidate = index < line.count ? line[index] : ""
                    if cellNumber(candidate) != nil {
                        raw = candidate
                        break
                    }
                }
            }
            guard let value = cellNumber(raw) else { continue }

            var payload: [String: Double] = [:]
            applyMetric(&payload, header: "pnr_rate_pct", value: value)
            guard payload["pnr_rate_pct"] != nil else { continue }

            var text: [String: String] = [:]
            if !carryDist.isEmpty { text["district"] = carryDist }
            out.append(
                ParsedWorkbookRow(
                    division: carryDiv,
                    operationsOM: carryOM,
                    storeNumber: HeartbeatMath.canonicalStore(storeRaw),
                    storeName: nil,
                    recordedOn: recordedOn,
                    payload: payload,
                    textPayload: text
                )
            )
        }
        return out.isEmpty ? nil : out
    }

    /// Weekly picker scorecard: STORE + PICKER, date blocks across the top, Total block last.
    private static func pickerHeaderIndex(_ matrix: [[String]]) -> Int? {
        func flags(_ row: [String]) -> (store: Bool, picker: Bool, metric: Bool) {
            let names = row.map(normHeader)
            let store = names.contains { storeKeys.contains($0) || $0 == "store" || $0.hasPrefix("store") }
            let picker = names.contains {
                shopperNameKeys.contains($0) || shopperIdKeys.contains($0)
                    || $0.contains("picker") || $0.contains("shopper")
            }
            let metric = names.contains {
                pickerMetricKeys[$0] != nil || $0.contains("pph") || $0.contains("presub")
                    || $0.contains("oos") || $0.contains("order") || $0.contains("ott")
            }
            return (store, picker, metric)
        }
        for (index, row) in matrix.prefix(40).enumerated() {
            let here = flags(row)
            if here.store && here.picker && here.metric { return index }
            if here.store && here.picker { return index }
            if index + 1 < matrix.count {
                let next = flags(matrix[index + 1])
                if (here.store || next.store) && (here.picker || next.picker) && (here.metric || next.metric) {
                    return here.metric ? index : index + 1
                }
            }
        }
        return nil
    }

    private static func parsePickerWide(_ matrix: [[String]]) -> [ParsedWorkbookRow]? {
        guard let headerIndex = pickerHeaderIndex(matrix) else { return nil }

        let header = matrix[headerIndex].map(normHeader)
        func firstIndex(_ keys: [String]) -> Int? {
            header.firstIndex { keys.contains($0) }
        }
        guard let storeIdx = firstIndex(storeKeys) ?? firstIndex(["store"]) else { return nil }
        let empIdx = firstIndex(shopperIdKeys) ?? firstIndex(shopperNameKeys)
        guard let empIdx else { return nil }

        let weekRow = headerIndex > 0 ? matrix[headerIndex - 1] : []
        var labels: [Int: String] = [:]
        for (index, cell) in weekRow.enumerated() {
            let trimmed = cell.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            let norm = normHeader(trimmed)
            if norm == "date" || norm == "weekid" || norm == "week" { continue }
            if isTotalCell(trimmed) {
                labels[index] = "total"
            } else if let date = dateFromWeekID(trimmed) ?? isoDate(trimmed) {
                labels[index] = date
            }
        }
        var filled: [Int: String] = [:]
        var current: String?
        for index in 0..<header.count {
            if let value = labels[index] { current = value }
            if let current { filled[index] = current }
        }

        var lastMetricColumn: [String: Int] = [:]
        for (index, name) in header.enumerated() where pickerMetricKey(name) != nil {
            lastMetricColumn[name] = index
        }
        let metricColumns = lastMetricColumn.values.sorted()
        guard !metricColumns.isEmpty else { return nil }

        var carryStore = ""
        var out: [ParsedWorkbookRow] = []
        for line in matrix.dropFirst(headerIndex + 1) {
            func cell(_ index: Int) -> String {
                index < line.count ? line[index] : ""
            }
            let storeRaw = cell(storeIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            if storeRaw.lowercased().hasPrefix("applied") { continue }
            if looksLikeStoreNumber(storeRaw) { carryStore = storeRaw }
            if isTotalCell(storeRaw) { continue }

            let picker = cell(empIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            if picker.isEmpty || isTotalCell(picker) { continue }
            if carryStore.isEmpty { continue }

            var payload: [String: Double] = [:]
            for (name, index) in lastMetricColumn {
                let raw = cell(index)
                guard let value = cellNumber(raw) else { continue }
                applyPickerMetric(&payload, header: name, value: value)
            }
            guard !payload.isEmpty else { continue }
            out.append(
                ParsedWorkbookRow(
                    division: "",
                    operationsOM: "",
                    storeNumber: HeartbeatMath.canonicalStore(carryStore),
                    storeName: nil,
                    recordedOn: filled[metricColumns.first ?? 0] == "total" ? nil : filled[metricColumns.first ?? 0],
                    payload: payload,
                    textPayload: ["shopper_id": picker, "shopper_name": picker]
                )
            )
        }
        return out.isEmpty ? nil : out
    }

    /// One row per shopper. STORE · PICKER · Hours · PPH · OTT · Orders · Presub · OOS · COE · Handoffs.
    private static func parsePickerWeeklyFlat(_ matrix: [[String]]) -> [ParsedWorkbookRow]? {
        guard let headerIndex = pickerHeaderIndex(matrix) else { return nil }
        let header = matrix[headerIndex].map(normHeader)
        func idx(_ match: (String) -> Bool) -> Int? {
            header.firstIndex(where: match)
        }
        guard let storeIdx = idx({ storeKeys.contains($0) || $0 == "store" }) else { return nil }
        guard let pickerIdx = idx({
            shopperNameKeys.contains($0) || shopperIdKeys.contains($0) || $0 == "picker" || $0 == "shopper"
        }) else { return nil }
        let hoursIdx = idx { $0 == "pickhours" || $0 == "hours" }
        let pphIdx = idx { $0 == "pph" || $0.hasSuffix("pph") }
        let ottIdx = idx { $0.contains("ott") }
        let ordersIdx = idx { $0 == "totalorders" || $0 == "orders" || $0 == "ordercount" }
        let qtyIdx = idx { ($0.contains("qty") && $0.contains("order")) || $0 == "qtyordered" }
        let presubIdx = idx { $0.contains("presub") && ($0.contains("pct") || $0.hasSuffix("oos") || $0 == "presuboos") }
        let presubCtIdx = idx { $0.contains("presuboosct") || ($0.contains("substitutes") && $0.contains("oos")) }
        let oosCtIdx = idx { $0 == "oosct" || $0 == "ooscount" }
        let subIdx = idx { $0 == "subct" || $0 == "subs" || $0 == "subcount" }
        let itemsIdx = idx { $0.contains("itemspicked") || $0.contains("totalitems") }
        let oth5Idx = idx { $0.contains("oth5") || $0 == "oth" }
        let handoffsIdx = idx { $0 == "totalhandoffs" || $0 == "handoffs" }
        let over5Idx = idx { $0.contains("over5") || $0.contains("handoffsover") }
        let complyIdx = idx { $0.contains("handoffcompliance") || $0.contains("compliance") && $0.contains("handoff") }
        let defectIdx = idx { $0.contains("defect") }
        let coeIdx = idx { $0.contains("coe") }
        let perfectIdx = idx { $0.contains("perfect") || $0.contains("great") }
        let poorIdx = idx { $0.contains("poor") || $0.contains("ni") && $0.contains("order") }
        guard pphIdx != nil || hoursIdx != nil || ordersIdx != nil else { return nil }

        var out: [ParsedWorkbookRow] = []
        out.reserveCapacity(max(64, matrix.count - headerIndex))
        for line in matrix.dropFirst(headerIndex + 1) {
            func cell(_ index: Int?) -> String {
                guard let index, index < line.count else { return "" }
                return line[index]
            }
            let storeRaw = cell(storeIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            if storeRaw.isEmpty || isTotalCell(storeRaw) { continue }
            if storeRaw.lowercased().hasPrefix("applied") { continue }
            guard looksLikeStoreNumber(storeRaw) else { continue }
            let picker = cell(pickerIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            if picker.isEmpty || isTotalCell(picker) { continue }

            var payload: [String: Double] = [:]
            func put(_ index: Int?, _ key: String, percent: Bool = false) {
                guard let raw = Optional(cell(index)), let value = cellNumber(raw) else { return }
                var number = value
                if percent, number <= 1.0, number >= -1.0 { number *= 100 }
                payload[key] = number
            }
            put(hoursIdx, "pick_hours")
            put(pphIdx, "pph")
            put(ottIdx, "ott_pct", percent: true)
            put(ordersIdx, "orders")
            put(qtyIdx, "qty_ordered")
            put(presubIdx, "presub_pct", percent: true)
            put(presubCtIdx, "presub_count")
            put(oosCtIdx, "oos_count")
            put(subIdx, "subs")
            put(itemsIdx, "items_picked")
            put(oth5Idx, "oth5_pct", percent: true)
            put(handoffsIdx, "handoffs")
            put(over5Idx, "handoffs_over5")
            put(complyIdx, "handoff_compliance_pct", percent: true)
            put(defectIdx, "handoff_defects")
            put(coeIdx, "coe_pct", percent: true)
            put(perfectIdx, "perfect_orders")
            put(poorIdx, "poor_orders")
            if payload["oos_pct"] == nil, let oos = payload["oos_count"], let qty = payload["qty_ordered"], qty > 0 {
                payload["oos_pct"] = oos / qty * 100
            }
            guard payload["pph"] != nil || payload["orders"] != nil || payload["pick_hours"] != nil else { continue }
            out.append(
                ParsedWorkbookRow(
                    division: "",
                    operationsOM: "",
                    storeNumber: HeartbeatMath.canonicalStore(storeRaw),
                    storeName: nil,
                    recordedOn: nil,
                    payload: payload,
                    textPayload: ["shopper_id": picker, "shopper_name": picker, "picker_layout": "weekly"]
                )
            )
        }
        return out.isEmpty ? nil : out
    }

    private static func parsePickerFast(
        compressed: Data,
        strings: [String],
        onTick: ((Int) -> Void)?
    ) -> [ParsedWorkbookRow] {
        var last: [String: ParsedWorkbookRow] = [:]
        last.reserveCapacity(8000)
        var seen = 0
        SheetXML.forEachRowInflating(
            compressed: compressed,
            strings: strings,
            handleRaw: { data in
                seen += 1
                let storeRaw = SheetXML.rawCell(data, letter: "A", strings: strings)
                let pickerRaw = SheetXML.rawCell(data, letter: "B", strings: strings)
                guard looksLikeStoreNumber(storeRaw), Double(storeRaw) ?? 0 < 200_000 else { return }
                let picker = pickerRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !picker.isEmpty, !isTotalCell(picker), picker != storeRaw else { return }
                var payload: [String: Double] = [:]
                if let pph = cellNumber(SheetXML.rawCell(data, letter: "C", strings: strings)) { payload["pph"] = pph }
                if let presub = cellNumber(SheetXML.rawCell(data, letter: "D", strings: strings)) {
                    applyPickerMetric(&payload, header: "presub", value: presub)
                }
                if let oos = cellNumber(SheetXML.rawCell(data, letter: "E", strings: strings)) {
                    applyPickerMetric(&payload, header: "oos", value: oos)
                }
                if let hours = cellNumber(SheetXML.rawCell(data, letter: "F", strings: strings)) { payload["pick_hours"] = hours }
                if let picks = cellNumber(SheetXML.rawCell(data, letter: "G", strings: strings)) { payload["picks"] = picks }
                if let orders = cellNumber(SheetXML.rawCell(data, letter: "I", strings: strings)) { payload["orders"] = orders }
                if let dug = cellNumber(SheetXML.rawCell(data, letter: "J", strings: strings)) { payload["dug_orders"] = dug }
                if let oth5 = cellNumber(SheetXML.rawCell(data, letter: "M", strings: strings)) {
                    applyPickerMetric(&payload, header: "oth5", value: oth5)
                }
                if let ott = cellNumber(SheetXML.rawCell(data, letter: "N", strings: strings)) {
                    applyPickerMetric(&payload, header: "ott", value: ott)
                }
                if let refund = cellNumber(SheetXML.rawCell(data, letter: "O", strings: strings)) {
                    applyPickerMetric(&payload, header: "refund", value: refund)
                }
                guard !payload.isEmpty else { return }
                let store = HeartbeatMath.canonicalStore(storeRaw)
                last[store + "|" + picker] = ParsedWorkbookRow(
                    division: "",
                    operationsOM: "",
                    storeNumber: store,
                    storeName: nil,
                    recordedOn: nil,
                    payload: payload,
                    textPayload: ["shopper_id": picker, "shopper_name": picker]
                )
                if seen % 4000 == 0 { onTick?(last.count) }
            }
        )
        onTick?(last.count)
        return Array(last.values)
    }

    private static func compactShoppers(_ rows: [ParsedWorkbookRow]) -> [ParsedWorkbookRow] {
        var last: [String: ParsedWorkbookRow] = [:]
        last.reserveCapacity(min(rows.count, 12_000))
        for row in rows {
            let shopper = row.textPayload["shopper_id"] ?? row.textPayload["shopper_name"] ?? ""
            let key = row.storeNumber + "|" + shopper
            last[key] = row
        }
        return Array(last.values)
    }

    private static func parsePickerCompactRaw(
        compressed: Data,
        strings: [String],
        onTick: ((Int) -> Void)?
    ) -> [ParsedWorkbookRow] {
        var layout = 0
        var blockStarts: [Int] = [2, 15, 28, 41, 54, 67, 80, 93]
        var blockLabels: [String] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Total"]
        var out: [String: ParsedWorkbookRow] = [:]
        out.reserveCapacity(32_000)
        let fields: [(Int, String)] = [
            (0, "pph"), (1, "presub"), (2, "oos"), (3, "pickhours"),
            (4, "picks"), (5, "subs"), (6, "orders"), (7, "dug"),
            (10, "oth5"), (11, "ott"), (12, "refund"),
        ]
        func readBlock(_ map: [String: String], start: Int) -> [String: Double] {
            var block: [String: Double] = [:]
            for (offset, header) in fields {
                let raw = map[SheetXML.colLetter(start + offset)] ?? ""
                if let value = cellNumber(raw) {
                    applyPickerMetric(&block, header: header, value: value)
                }
            }
            return block
        }
        func dayValue(_ block: [String: Double], _ key: String, worked: Bool) -> String {
            guard worked, let value = block[key] else { return "N/A" }
            return String(value)
        }
        SheetXML.forEachRowInflating(compressed: compressed, strings: strings, handleRaw: { data in
            let map = SheetXML.rawMap(data, strings: strings)
            let a = map["A"] ?? ""
            let b = map["B"] ?? ""
            if layout == 0 {
                let na = normHeader(a)
                if na == "date" || na.contains("date") {
                    var labels: [String] = []
                    for start in blockStarts {
                        let raw = (map[SheetXML.colLetter(start)] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if raw.lowercased() == "total" {
                            labels.append("Total")
                        } else if let iso = excelSerialDate(raw) {
                            labels.append(iso)
                        } else if !raw.isEmpty {
                            labels.append(raw)
                        } else {
                            labels.append("")
                        }
                    }
                    if labels.contains(where: { !$0.isEmpty }) {
                        blockLabels = labels
                    }
                    return
                }
                let nb = normHeader(b)
                if na.contains("store") && (nb.contains("picker") || nb.contains("shopper")) {
                    layout = 1
                }
                return
            }
            let picker = b.trimmingCharacters(in: .whitespacesAndNewlines)
            if picker.isEmpty || isTotalCell(picker) { return }
            guard picker.rangeOfCharacter(from: .letters) != nil else { return }
            guard looksLikeStoreNumber(a) else { return }
            let storeNumber = HeartbeatMath.canonicalStore(a)
            var total: [String: Double] = [:]
            var days: [[String: String]] = []
            days.reserveCapacity(7)
            for (index, start) in blockStarts.enumerated() {
                let label = index < blockLabels.count ? blockLabels[index] : ""
                let block = readBlock(map, start: start)
                if label.lowercased() == "total" || index == blockStarts.count - 1 {
                    if label.lowercased() == "total" || total.isEmpty {
                        total = block
                    }
                    if label.lowercased() == "total" { continue }
                    if index == blockStarts.count - 1 { continue }
                }
                let worked = (block["pph"] ?? 0) > 0
                    || (block["pick_hours"] ?? 0) > 0
                    || (block["orders"] ?? 0) > 0
                var day: [String: String] = [:]
                day["date"] = label
                day["pph"] = dayValue(block, "pph", worked: worked)
                day["presub"] = dayValue(block, "presub_pct", worked: worked)
                day["oos"] = dayValue(block, "oos_pct", worked: worked)
                day["ott"] = dayValue(block, "ott_pct", worked: worked)
                day["oth5"] = dayValue(block, "oth5_pct", worked: worked)
                day["hours"] = dayValue(block, "pick_hours", worked: worked)
                day["orders"] = dayValue(block, "orders", worked: worked)
                day["refund"] = dayValue(block, "refund_amt", worked: worked)
                days.append(day)
            }
            guard let pph = total["pph"], pph > 0, pph < 200 else { return }
            let daysJSON = (try? JSONSerialization.data(withJSONObject: days)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            out[storeNumber + "|" + picker] = ParsedWorkbookRow(
                division: "",
                operationsOM: "",
                storeNumber: storeNumber,
                storeName: nil,
                recordedOn: "Total",
                payload: total,
                textPayload: [
                    "shopper_id": picker,
                    "shopper_name": picker,
                    "days_json": daysJSON,
                ]
            )
            if out.count % 2500 == 0 { onTick?(out.count) }
        }, stop: { false })
        onTick?(out.count)
        return Array(out.values)
    }

    private static func parsePickerStreaming(
        data: Data? = nil,
        compressed: Data? = nil,
        strings: [String],
        onTick: ((Int) -> Void)? = nil
    ) -> [ParsedWorkbookRow] {
        var storeIdx: Int?
        var empIdx: Int?
        var metricColumns: [String: [Int]] = [:]
        var keep: Set<Int>?
        var ready = false
        var carryStore = ""
        var out: [ParsedWorkbookRow] = []
        var seen = 0
        out.reserveCapacity(8192)
        let handle: ([String]) -> Void = { line in
            if !ready {
                let names = line.map(normHeader)
                let store = names.firstIndex { storeKeys.contains($0) || $0 == "store" || $0.hasPrefix("store") }
                let picker = names.firstIndex {
                    shopperIdKeys.contains($0) || shopperNameKeys.contains($0)
                        || $0.contains("picker") || $0.contains("shopper")
                }
                if store != nil, picker != nil {
                    storeIdx = store
                    empIdx = picker
                    for (index, name) in names.enumerated() {
                        guard pickerMetricKey(name) != nil else { continue }
                        metricColumns[name, default: []].append(index)
                    }
                    if names.first == "date" || names.first == "weekid" || (names.first ?? "").contains("date") {
                        // Date | Store | Picker — keep the detected STORE / PICKER columns.
                    }
                    if !metricColumns.isEmpty {
                        for name in metricColumns.keys {
                            if let tail = metricColumns[name]?.suffix(3) {
                                metricColumns[name] = Array(tail)
                            }
                        }
                        var cols = Set<Int>()
                        cols.insert(0)
                        if let store { cols.insert(store) }
                        if let picker { cols.insert(picker) }
                        for indexes in metricColumns.values { cols.formUnion(indexes) }
                        keep = cols
                        ready = true
                    }
                }
                return
            }
            seen += 1
            if seen % 2500 == 0 { onTick?(out.count) }
            func cell(_ index: Int) -> String { index < line.count ? line[index] : "" }
            guard let storeIdx, let empIdx else { return }
            var storeRaw = cell(storeIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            var picker = cell(empIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            // Daily Report layout: DATE | STORE | PICKER | metrics, but many rows put the
            // picker id in STORE and the first metric in PICKER.
            if !looksLikeStoreNumber(storeRaw), picker.rangeOfCharacter(from: .letters) == nil, storeRaw.rangeOfCharacter(from: .letters) != nil {
                picker = storeRaw
                storeRaw = cell(0)
            } else if !looksLikeStoreNumber(storeRaw), looksLikeStoreNumber(cell(0)), cell(storeIdx).rangeOfCharacter(from: .letters) != nil {
                storeRaw = cell(0)
                picker = cell(storeIdx)
            }
            if storeRaw.lowercased().hasPrefix("applied") { return }
            if looksLikeStoreNumber(storeRaw) { carryStore = storeRaw }
            if isTotalCell(storeRaw) || isTotalCell(picker) { return }
            if picker.isEmpty { return }
            if looksLikeStoreNumber(picker) { return }
            var payload: [String: Double] = [:]
            for (name, indexes) in metricColumns {
                var value: Double?
                for index in indexes.reversed() {
                    if let parsed = cellNumber(cell(index)) {
                        value = parsed
                        break
                    }
                }
                if value == nil, name.contains("pph") || name.contains("pure") {
                    value = cellNumber(cell(empIdx))
                }
                guard let value else { continue }
                applyPickerMetric(&payload, header: name, value: value)
            }
            if payload.isEmpty, let pph = cellNumber(cell(empIdx)) {
                applyPickerMetric(&payload, header: "pph", value: pph)
            }
            guard !payload.isEmpty else { return }
            out.append(
                ParsedWorkbookRow(
                    division: "",
                    operationsOM: "",
                    storeNumber: HeartbeatMath.canonicalStore(carryStore),
                    storeName: nil,
                    recordedOn: nil,
                    payload: payload,
                    textPayload: ["shopper_id": picker, "shopper_name": picker]
                )
            )
        }
        if let compressed {
            SheetXML.forEachRowInflating(compressed: compressed, strings: strings, keep: { keep }, handle: handle)
        } else if let data {
            SheetXML.forEachRowBytes(data: data, strings: strings, keep: { keep }, handle: handle)
        }
        return out
    }

    private static func parseEmployeeStreaming(
        data: Data? = nil,
        compressed: Data? = nil,
        strings: [String]
    ) -> [ParsedWorkbookRow] {
        var empIdx: Int?
        var storeIdx: Int?
        var metricColumns: [String: [Int]] = [:]
        var ready = false
        var out: [ParsedWorkbookRow] = []
        out.reserveCapacity(8192)
        let handle: ([String]) -> Void = { line in
            if !ready {
                let names = line.map(normHeader)
                let picker = names.firstIndex { shopperIdKeys.contains($0) || shopperNameKeys.contains($0) }
                let store = names.firstIndex { storeKeys.contains($0) || $0 == "store" }
                let hasMetric = names.contains { $0.contains("pickpath") || $0.contains("compliance") || $0.contains("purepph") || $0 == "pph" }
                if picker != nil, hasMetric {
                    empIdx = picker
                    storeIdx = store
                    for (index, name) in names.enumerated() where index != picker && !name.isEmpty {
                        metricColumns[name, default: []].append(index)
                    }
                    ready = true
                }
                return
            }
            func cell(_ index: Int) -> String { index < line.count ? line[index] : "" }
            guard let empIdx else { return }
            let picker = cell(empIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            if picker.isEmpty || isTotalCell(picker) || picker.lowercased().hasPrefix("applied") { return }
            let storeRaw = storeIdx.map { cell($0) } ?? ""
            var payload: [String: Double] = [:]
            for (name, indexes) in metricColumns {
                var value: Double?
                for index in indexes.reversed() {
                    if let parsed = cellNumber(cell(index)) {
                        value = parsed
                        break
                    }
                }
                guard let value else { continue }
                applyMetric(&payload, header: name, value: value)
            }
            guard payload["compliance_pct"] != nil || payload["pph"] != nil else { return }
            out.append(
                ParsedWorkbookRow(
                    division: "",
                    operationsOM: "",
                    storeNumber: HeartbeatMath.canonicalStore(storeRaw),
                    storeName: nil,
                    recordedOn: nil,
                    payload: payload,
                    textPayload: ["shopper_id": picker, "shopper_name": picker]
                )
            )
        }
        if let compressed {
            SheetXML.forEachRowInflating(compressed: compressed, strings: strings, keep: nil, handle: handle)
        } else if let data {
            SheetXML.forEachRowBytes(data: data, strings: strings, keep: nil, handle: handle)
        }
        return out
    }
    private static func parseStoreWeek(_ matrix: [[String]]) -> [ParsedWorkbookRow]? {
        guard let headerIndex = matrix.firstIndex(where: { row in
            let names = Set(row.map(normHeader))
            let hasStore = names.contains(where: { storeKeys.contains($0) || $0 == "store" })
            let hasArea = names.contains(where: { omAreaKeys.contains($0) })
            let hasPicker = names.contains(where: { shopperNameKeys.contains($0) || shopperIdKeys.contains($0) })
            let hasMetric = names.contains(where: {
                $0.contains("pickpath") || $0.contains("compliance") || $0.contains("purepph") || $0 == "pph" || $0 == "orders"
            })
            return (hasStore || hasArea) && !hasPicker && hasMetric
        }) else { return nil }

        let header = matrix[headerIndex].map(normHeader)
        func firstIndex(_ keys: [String]) -> Int? {
            header.firstIndex { keys.contains($0) }
        }
        let storeIdx = firstIndex(storeKeys) ?? firstIndex(["store"])
        let areaIdx = firstIndex(omAreaKeys)
        guard storeIdx != nil || areaIdx != nil else { return nil }

        var lastMetricColumn: [String: Int] = [:]
        for (index, name) in header.enumerated() {
            if index == storeIdx || index == areaIdx || name.isEmpty { continue }
            lastMetricColumn[name] = index
        }
        guard !lastMetricColumn.isEmpty else { return nil }

        var out: [ParsedWorkbookRow] = []
        for line in matrix.dropFirst(headerIndex + 1) {
            func cell(_ index: Int?) -> String {
                guard let index, index < line.count else { return "" }
                return line[index]
            }
            let storeRaw = cell(storeIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            let areaRaw = cell(areaIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            if storeRaw.lowercased().hasPrefix("applied") || areaRaw.lowercased().hasPrefix("applied") { continue }
            if isTotalCell(storeRaw) || isTotalCell(areaRaw) { continue }

            let store = looksLikeStoreNumber(storeRaw) ? HeartbeatMath.canonicalStore(storeRaw) : ""
            let area = usableValue(areaRaw) ?? ""
            if store.isEmpty && area.isEmpty { continue }

            var payload: [String: Double] = [:]
            for (name, index) in lastMetricColumn {
                let raw = index < line.count ? line[index] : ""
                guard let value = cellNumber(raw) else { continue }
                applyMetric(&payload, header: name, value: value)
            }
            guard payload["compliance_pct"] != nil || payload["pph"] != nil else { continue }

            var text: [String: String] = [:]
            if !area.isEmpty { text["om_area"] = area }
            let week = matrix.prefix(headerIndex + 1).flatMap { $0 }.compactMap(dateFromWeekID).first
            out.append(
                ParsedWorkbookRow(
                    division: "",
                    operationsOM: "",
                    storeNumber: store,
                    storeName: nil,
                    recordedOn: week,
                    payload: payload,
                    textPayload: text
                )
            )
        }
        return out.isEmpty ? nil : out
    }

    /// WEEK_ID across the top, EMPLOYEE_ALTERNATE_ID down the side, Total block last.
    private static func parseEmployeeWeek(_ matrix: [[String]]) -> [ParsedWorkbookRow]? {
        guard let headerIndex = matrix.firstIndex(where: { row in
            let names = Set(row.map(normHeader))
            let hasPicker = names.contains(where: { shopperIdKeys.contains($0) || shopperNameKeys.contains($0) })
            let hasMetric = names.contains(where: {
                $0.contains("pickpath") || $0.contains("compliance") || $0.contains("purepph") || $0 == "pph"
            })
            return hasPicker && hasMetric
        }) else { return nil }

        let header = matrix[headerIndex].map(normHeader)
        let empIdx = header.firstIndex { shopperIdKeys.contains($0) || shopperNameKeys.contains($0) }
        let storeIdx = header.firstIndex { storeKeys.contains($0) || $0 == "store" }
        guard let empIdx else { return nil }

        var lastMetricColumn: [String: Int] = [:]
        for (index, name) in header.enumerated() {
            if index == empIdx || name.isEmpty { continue }
            lastMetricColumn[name] = index
        }
        guard !lastMetricColumn.isEmpty else { return nil }

        let week = matrix.prefix(headerIndex + 1).flatMap { $0 }.compactMap(dateFromWeekID).first
        var out: [ParsedWorkbookRow] = []
        for line in matrix.dropFirst(headerIndex + 1) {
            let picker = empIdx < line.count ? line[empIdx].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            if picker.lowercased().hasPrefix("applied") { continue }
            if picker.isEmpty || isTotalCell(picker) { continue }
            let storeRaw = storeIdx.flatMap { idx -> String? in
                guard idx < line.count else { return nil }
                return line[idx]
            } ?? ""
            let store = storeRaw.trimmingCharacters(in: .whitespacesAndNewlines)

            var payload: [String: Double] = [:]
            for (name, index) in lastMetricColumn {
                let raw = index < line.count ? line[index] : ""
                guard let value = cellNumber(raw) else { continue }
                applyMetric(&payload, header: name, value: value)
            }
            guard payload["compliance_pct"] != nil || payload["pph"] != nil else { continue }
            out.append(
                ParsedWorkbookRow(
                    division: "",
                    operationsOM: "",
                    storeNumber: store,
                    storeName: nil,
                    recordedOn: week,
                    payload: payload,
                    textPayload: ["shopper_id": picker, "shopper_name": picker]
                )
            )
        }
        return out.isEmpty ? nil : out
    }

    /// Outline / pivot exports: DIVISION, DISTRICT, OM_AREA, OM_ID, STORE
    /// with WEEK_ID across the top and Pure PPH values under each week.
    private static func parseOutline(_ matrix: [[String]]) -> [ParsedWorkbookRow]? {
        guard let headerIndex = matrix.firstIndex(where: { row in
            let names = Set(row.map(normHeader))
            return names.contains("division") && names.contains(where: { storeKeys.contains($0) || $0 == "store" })
        }) else { return nil }

        let header = matrix[headerIndex].map(normHeader)
        let looksOutline = header.contains(where: { districtKeys.contains($0) || $0 == "omid" || omAreaKeys.contains($0) })
        guard looksOutline else { return nil }

        func firstIndex(_ keys: [String]) -> Int? {
            header.firstIndex { keys.contains($0) }
        }

        let divIdx = firstIndex(divisionKeys)
        let distIdx = firstIndex(districtKeys)
        let areaIdx = firstIndex(omAreaKeys)
        let omIdx = firstIndex(omKeys)
        let storeIdx = firstIndex(storeKeys) ?? firstIndex(["store"])
        let empIdx = firstIndex(shopperIdKeys)
        guard let storeIdx else { return nil }

        let weekRow = headerIndex > 0 ? matrix[headerIndex - 1] : []
        var weekByColumn: [Int: String] = [:]
        var totalColumns: [Int] = []
        for (index, cell) in weekRow.enumerated() {
            let trimmed = cell.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            if isTotalCell(trimmed) {
                totalColumns.append(index)
                continue
            }
            let norm = normHeader(trimmed)
            if norm == "weekid" || norm == "week" || norm == "date" { continue }
            if let date = dateFromWeekID(trimmed) ?? isoDate(trimmed) {
                weekByColumn[index] = date
            }
        }
        if let lastDate = weekByColumn.values.max() {
            for index in totalColumns {
                weekByColumn[index] = lastDate
            }
        } else if !totalColumns.isEmpty {
            for index in totalColumns {
                weekByColumn[index] = "week"
            }
        }

        var carryDiv = ""
        var carryDist = ""
        var carryArea = ""
        var carryOM = ""
        var storeRows: [ParsedWorkbookRow] = []
        var pickerRows: [ParsedWorkbookRow] = []

        for line in matrix.dropFirst(headerIndex + 1) {
            func cell(_ index: Int?) -> String {
                guard let index, index < line.count else { return "" }
                return line[index]
            }

            if let value = usableValue(cell(divIdx)) { carryDiv = value }
            if let value = usableValue(cell(distIdx)) { carryDist = value }
            if let value = usableValue(cell(areaIdx)) { carryArea = value }
            if let value = usableValue(cell(omIdx)) { carryOM = value }

            let storeRaw = cell(storeIdx).trimmingCharacters(in: .whitespacesAndNewlines)
            if storeRaw.lowercased().hasPrefix("applied") { continue }
            guard looksLikeStoreNumber(storeRaw) else { continue }

            let employee = usableValue(cell(empIdx))
            let isPicker = employee != nil

            var text: [String: String] = [:]
            if !carryDist.isEmpty { text["district"] = carryDist }
            if !carryArea.isEmpty { text["om_area"] = carryArea }
            if let employee { text["shopper_id"] = employee }

            let metricColumns = header.indices.filter { index in
                index != divIdx && index != distIdx && index != areaIdx && index != omIdx && index != storeIdx && index != empIdx
            }

            let emitted: [ParsedWorkbookRow]
            if !totalColumns.isEmpty {
                var payload: [String: Double] = [:]
                for index in totalColumns {
                    let raw = index < line.count ? line[index] : ""
                    guard let value = cellNumber(raw) else { continue }
                    applyMetric(&payload, header: index < header.count ? header[index] : "", value: value)
                }
                emitted = payload.isEmpty ? [] : [
                    ParsedWorkbookRow(
                        division: carryDiv,
                        operationsOM: carryOM,
                        storeNumber: HeartbeatMath.canonicalStore(storeRaw),
                        storeName: nil,
                        recordedOn: weekByColumn.values.max(),
                        payload: payload,
                        textPayload: text
                    )
                ]
            } else if !weekByColumn.isEmpty {
                emitted = unpivotWeeks(
                    line: line,
                    metricColumns: metricColumns,
                    header: header,
                    weekByColumn: weekByColumn,
                    division: carryDiv,
                    operationsOM: carryOM,
                    storeNumber: storeRaw,
                    text: text
                )
            } else {
                var payload: [String: Double] = [:]
                var extraText = text
                for index in metricColumns {
                    guard index < header.count else { continue }
                    let raw = index < line.count ? line[index] : ""
                    if let value = cellNumber(raw) {
                        applyMetric(&payload, header: header[index], value: value)
                    } else if let value = usableValue(raw) {
                        extraText[metricAliases[header[index]] ?? header[index]] = value
                    }
                }
                emitted = payload.isEmpty ? [] : [
                    ParsedWorkbookRow(
                        division: carryDiv,
                        operationsOM: carryOM,
                        storeNumber: HeartbeatMath.canonicalStore(storeRaw),
                        storeName: nil,
                        recordedOn: nil,
                        payload: payload,
                        textPayload: extraText
                    )
                ]
            }

            if isPicker {
                pickerRows.append(contentsOf: emitted)
            } else {
                storeRows.append(contentsOf: emitted)
            }
        }

        if !storeRows.isEmpty { return storeRows }
        if !pickerRows.isEmpty { return rollupPickers(pickerRows) }
        return []
    }

    private static func unpivotWeeks(
        line: [String],
        metricColumns: [Int],
        header: [String],
        weekByColumn: [Int: String],
        division: String,
        operationsOM: String,
        storeNumber: String,
        text: [String: String]
    ) -> [ParsedWorkbookRow] {
        var byDate: [String: [String: Double]] = [:]
        for index in metricColumns {
            guard let date = weekByColumn[index] else { continue }
            let raw = index < line.count ? line[index] : ""
            guard let value = cellNumber(raw) else { continue }
            applyMetric(&byDate[date, default: [:]], header: index < header.count ? header[index] : "", value: value)
        }
        return byDate.keys.sorted().compactMap { date in
            guard let payload = byDate[date], !payload.isEmpty else { return nil }
            return ParsedWorkbookRow(
                division: division,
                operationsOM: operationsOM,
                storeNumber: HeartbeatMath.canonicalStore(storeNumber),
                storeName: nil,
                recordedOn: date,
                payload: payload,
                textPayload: text
            )
        }
    }

    private static func applyMetric(_ payload: inout [String: Double], header: String, value: Double) {
        var key = metricAliases[header] ?? header
        var number = value
        if key.contains("flash") && key.contains("star") {
            key = "flash_star"
        } else if key.contains("flash") {
            key = "flash_pct"
        } else if (key.contains("presub") || key.contains("presuboos")) && key.contains("star") {
            key = "presub_star"
        } else if key.contains("presub") || key.contains("presuboos") {
            key = "presub_pct"
        } else if key == "oos" || key == "oospct" || (key.contains("oos") && !key.contains("presub")) {
            key = "oos_pct"
        } else if key.contains("coe") && key.contains("star") {
            key = "coe_star"
        } else if key == "coe" || key.contains("coegiveme") {
            key = "coe_pct"
        } else if key.contains("ott") && key.contains("star") {
            key = "ott_star"
        } else if key.contains("ott") {
            key = "ott_pct"
        } else if key.contains("othelig") && !key.contains("order") {
            key = "oth_elig_pct"
        } else if key.contains("eligible") && key.contains("order") {
            key = "oth_eligible_orders"
        } else if (key.contains("oth5") || key.hasPrefix("oth")) && key.contains("star") {
            key = "oth5_star"
        } else if key.contains("oth5") || key == "oth" {
            key = "oth5_pct"
        } else if key.contains("dug") {
            key = "dug_orders"
        } else if key.contains("refund") {
            key = "refund_amt"
        } else if key.contains("piece") && (key.contains("hr") || key.contains("hour")) {
            key = "dynacap_rate"
        } else if key.contains("purepph") || (key == "pph") {
            key = "pph"
        } else if key.contains("pphpick") {
            key = "pph_picks"
        } else if key == "subs" || key.contains("substitute") {
            key = "subs"
        } else if key.contains("totalrating") {
            key = "star_rating"
        } else if key.contains("underschedule") {
            key = "under_schedule_pct"
        } else if key.contains("overschedule") {
            key = "over_schedule_pct"
        } else if key.contains("staffingeffic") {
            key = "staffing_efficiency_pct"
        } else if key.contains("scheduleeffic") {
            key = "schedule_efficiency_pct"
        } else if key.contains("underadherence") {
            key = "under_adherence_pct"
        } else if key.contains("overadherence") {
            key = "over_adherence_pct"
        } else if key.contains("scheduleadherence") {
            key = "schedule_adherence_pct"
        } else if key.contains("understaffing") {
            key = "under_staffing_pct"
        } else if key.contains("overstaffing") {
            key = "over_staffing_pct"
        } else if key.contains("prepnotready") || key.contains("pnrrate") || (key.contains("pnr") && key.contains("hour")) {
            key = "pnr_rate_pct"
        } else if key.contains("handoffcompliance") {
            key = "handoff_compliance_pct"
        }
        if key == "compliance_pct" || key.contains("pickpath") || key == "pathcompliance" {
            key = "compliance_pct"
            if number <= 1.5 { number *= 100 }
        }
        if key == "utilization_pct" || key == "change_pct" {
            if number <= 1.5 { number *= 100 }
        }
        if key.hasSuffix("_pct"), number <= 1.0 {
            number *= 100
        }
        if (key == "act_cost_pct" || key == "cost_trgt_pct"), abs(number) > 1, abs(number) <= 5 {
            number *= 100
        }
        if key == "over_scheduled" { key = "over_schedule_pct" }
        if key == "under_scheduled" { key = "under_schedule_pct" }
        payload[key] = number
        if key == "orders" {
            payload["picks_total"] = number
            if let compliance = payload["compliance_pct"] {
                payload["picks_compliant"] = (compliance / 100) * number
            }
        }
        if key == "compliance_pct", let orders = payload["orders"] {
            payload["picks_compliant"] = (number / 100) * orders
        }
    }

    private static let pickerMetricKeys: [String: String] = [
        "purepph": "pph",
        "totalpurepph": "pph",
        "totalpph": "pph",
        "pph": "pph",
        "presuboos": "presub_pct",
        "presuboospct": "presub_pct",
        "presubstitutionoos": "presub_pct",
        "presubstitutionoospct": "presub_pct",
        "presub": "presub_pct",
        "oos": "oos_pct",
        "oospct": "oos_pct",
        "pickhours": "pick_hours",
        "hours": "pick_hours",
        "pphpicks": "pph_picks",
        "subs": "subs",
        "substitutes": "subs",
        "orders": "orders",
        "totalorders": "orders",
        "ordercount": "orders",
        "qtyordered": "qty_ordered",
        "qtyorder": "qty_ordered",
        "quantityordered": "qty_ordered",
        "ttldugorders": "dug_orders",
        "ttldugord": "dug_orders",
        "dugorders": "dug_orders",
        "otheligibleorders": "oth_eligible_orders",
        "otheligible": "oth_eligible_orders",
        "othelig": "oth_elig_pct",
        "otheligibility": "oth_elig_pct",
        "oth5": "oth5_pct",
        "oth5pct": "oth5_pct",
        "ott": "ott_pct",
        "ottpct": "ott_pct",
        "refundamt": "refund_amt",
        "refund": "refund_amt",
        "coe": "coe_pct",
        "coepct": "coe_pct",
    ]

    private static func pickerMetricKey(_ header: String) -> String? {
        let name = normHeader(header)
        if let mapped = pickerMetricKeys[name] { return mapped }
        if name.contains("purepph") || name.hasSuffix("pph") { return "pph" }
        if name.contains("presub") { return "presub_pct" }
        if name.contains("oos") { return "oos_pct" }
        if name.contains("pickhour") || name == "hours" { return "pick_hours" }
        if name.contains("othelig") { return "oth_elig_pct" }
        if name.contains("oth5") { return "oth5_pct" }
        if name.contains("ott") { return "ott_pct" }
        if name.contains("refund") { return "refund_amt" }
        if name.contains("dug") { return "dug_orders" }
        if name.contains("coe") { return "coe_pct" }
        if name.contains("sub") && !name.contains("presub") { return "subs" }
        if name.contains("qty") && name.contains("order") { return "qty_ordered" }
        if name == "totalorders" || name == "orders" || name == "ordercount" { return "orders" }
        if name.contains("order") && !name.contains("qty") && !name.contains("perfect") && !name.contains("poor") && !name.contains("great") {
            return "orders"
        }
        return nil
    }

    private static func applyPickerMetric(_ payload: inout [String: Double], header: String, value: Double) {
        guard let key = pickerMetricKey(header) else { return }
        var number = value
        if key.hasSuffix("_pct"), number <= 1.0 {
            number *= 100
        }
        payload[key] = number
    }

    private static func rollupPickers(_ rows: [ParsedWorkbookRow]) -> [ParsedWorkbookRow] {
        struct Key: Hashable { let store: String; let date: String }
        var groups: [Key: [ParsedWorkbookRow]] = [:]
        for row in rows {
            groups[Key(store: row.storeNumber, date: row.recordedOn ?? ""), default: []].append(row)
        }
        return groups.keys.sorted { $0.store == $1.store ? $0.date < $1.date : $0.store < $1.store }.compactMap { key in
            guard let bucket = groups[key], let first = bucket.first else { return nil }
            var payload: [String: Double] = [:]
            let orders = bucket.compactMap { $0.payload["orders"] }
            let compliance = bucket.compactMap { $0.payload["compliance_pct"] }
            let pph = bucket.compactMap { $0.payload["pph"] }
            if !orders.isEmpty {
                let total = orders.reduce(0, +)
                payload["orders"] = total
                payload["picks_total"] = total
                if compliance.count == orders.count, total > 0 {
                    let weighted = zip(compliance, orders).reduce(0) { $0 + $1.0 * $1.1 } / total
                    payload["compliance_pct"] = weighted
                    payload["picks_compliant"] = (weighted / 100) * total
                }
            }
            if payload["compliance_pct"] == nil, !compliance.isEmpty {
                payload["compliance_pct"] = compliance.reduce(0, +) / Double(compliance.count)
            }
            if !pph.isEmpty {
                payload["pph"] = pph.reduce(0, +) / Double(pph.count)
            }
            guard !payload.isEmpty else { return nil }
            return ParsedWorkbookRow(
                division: first.division,
                operationsOM: first.operationsOM,
                storeNumber: first.storeNumber,
                storeName: first.storeName,
                recordedOn: first.recordedOn,
                payload: payload,
                textPayload: first.textPayload.filter { $0.key != "shopper_id" }
            )
        }
    }

    static func looksLikeStoreNumber(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isTotalCell(trimmed) else { return false }
        let cleaned = trimmed.replacingOccurrences(of: ",", with: "")
        if let value = Double(cleaned), value > 0, value < 1_000_000, abs(value - value.rounded()) < 0.001 {
            if value >= 200_000, value < 210_000 { return false }
            return true
        }
        guard trimmed.range(of: #"^\d{1,6}[A-Za-z]?$"#, options: .regularExpression) != nil else { return false }
        return true
    }

    static func dateFromWeekID(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 6, trimmed.allSatisfy(\.isNumber),
              let year = Int(trimmed.prefix(4)),
              let week = Int(trimmed.suffix(2)),
              week >= 1, week <= 53
        else { return nil }
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current
        var comps = DateComponents()
        comps.weekOfYear = week
        comps.yearForWeekOfYear = year
        comps.weekday = 2
        guard let date = calendar.date(from: comps) else { return nil }
        return iso(date)
    }

    private static func parseFlat(_ matrix: [[String]]) -> [ParsedWorkbookRow] {
        guard matrix.count >= 2 else { return [] }
        let headerIndex = matrix.firstIndex { row in
            let names = Set(row.map(normHeader))
            return names.contains(where: {
                storeKeys.contains($0) || $0 == "store" || divisionKeys.contains($0) || omAreaKeys.contains($0)
            })
        } ?? 0
        let headers = matrix[headerIndex].map(normHeader)
        var out: [ParsedWorkbookRow] = []
        for line in matrix.dropFirst(headerIndex + 1) {
            if line.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }
            var division = ""
            var om = ""
            var store = ""
            var name: String?
            var recorded: String?
            var payload: [String: Double] = [:]
            var text: [String: String] = [:]

            for (index, header) in headers.enumerated() {
                guard !header.isEmpty else { continue }
                let raw = index < line.count ? line[index] : ""
                if divisionKeys.contains(header) {
                    division = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    continue
                }
                if districtKeys.contains(header) {
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { text["district"] = trimmed }
                    continue
                }
                if omAreaKeys.contains(header) {
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { text["om_area"] = trimmed }
                    continue
                }
                if omKeys.contains(header) {
                    om = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    continue
                }
                if storeKeys.contains(header) {
                    store = HeartbeatMath.canonicalStore(raw)
                    continue
                }
                if nameKeys.contains(header) {
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    name = trimmed.isEmpty ? nil : trimmed
                    continue
                }
                if shopperNameKeys.contains(header) {
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { text["shopper_name"] = trimmed }
                    continue
                }
                if shopperIdKeys.contains(header) {
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { text["shopper_id"] = trimmed }
                    continue
                }
                if dateKeys.contains(header) {
                    recorded = isoDate(raw)
                    continue
                }
                let mapped = metricAliases[header] ?? header
                if let number = cellNumber(raw) {
                    applyMetric(&payload, header: header, value: number)
                } else {
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { text[mapped] = trimmed }
                }
            }
            if isTotalCell(store) || isTotalCell(text["district"] ?? "") || isTotalCell(division) || isTotalCell(text["om_area"] ?? "") { continue }
            if store.isEmpty && name == nil && division.isEmpty {
                if payload["compliance_pct"] != nil, !(text["om_area"] ?? "").isEmpty {
                    // OM-area pick path rollup — expanded onto stores later.
                } else if payload["dynacap_rate"] != nil || payload["dpa_dynacap"] != nil || payload["eot_capacity"] != nil {
                    // Store-level Dynacap (STORE_ID) or district-level capacity summary.
                } else if (text["district"] ?? "").isEmpty {
                    continue
                } else if payload["dynacap_rate"] == nil {
                    continue
                }
            }
            out.append(ParsedWorkbookRow(
                division: division,
                operationsOM: om,
                storeNumber: store,
                storeName: name,
                recordedOn: recorded,
                payload: payload,
                textPayload: text
            ))
        }
        return out
    }

    static func normHeader(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: "[%#]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
    }

    private static func cellNumber(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let cleaned = trimmed.replacingOccurrences(of: "[%$,]", with: "", options: .regularExpression)
        if let value = Double(cleaned), value.isFinite { return value }
        return nil
    }

    static func isoDate(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.count >= 10, trimmed.prefix(10).contains("-") {
            return String(trimmed.prefix(10))
        }
        if let serial = Double(trimmed), serial > 20000, serial < 80000 {
            return excelSerialDate(serial)
        }
        let formats = ["M/d/yyyy", "MM/dd/yyyy", "M/d/yy", "yyyy-MM-dd", "MMM d, yyyy"]
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            parser.dateFormat = format
            if let date = parser.date(from: trimmed) {
                return iso(date)
            }
        }
        return trimmed
    }

    static func excelSerialDate(_ value: Double) -> String {
        // Excel epoch is 1899-12-30.
        let seconds = (value - 25569) * 86400
        return iso(Date(timeIntervalSince1970: seconds))
    }

    private static func iso(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

enum CSVReader {
    static func read(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        field.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else if c == "\"" {
                inQuotes = true
            } else if c == "," {
                row.append(field)
                field = ""
            } else if c == "\n" || c == "\r" {
                if c == "\r", i + 1 < chars.count, chars[i + 1] == "\n" { i += 1 }
                row.append(field)
                if row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    rows.append(row)
                }
                row = []
                field = ""
            } else {
                field.append(c)
            }
            i += 1
        }
        row.append(field)
        if row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            rows.append(row)
        }
        return rows
    }
}

enum SharedStrings {
    static func parse(_ xml: String) -> [String] {
        var out: [String] = []
        out.reserveCapacity(8192)
        var cursor = xml.startIndex
        while let si = xml.range(of: "<si", range: cursor..<xml.endIndex) {
            let after = si.upperBound
            guard after < xml.endIndex else { break }
            let mark = xml[after]
            if mark != " " && mark != ">" && mark != "/" {
                cursor = after
                continue
            }
            guard let openEnd = xml.range(of: ">", range: after..<xml.endIndex) else { break }
            guard let close = xml.range(of: "</si>", range: openEnd.upperBound..<xml.endIndex) else { break }
            let body = xml[openEnd.upperBound..<close.lowerBound]
            var text = ""
            var origin = body.startIndex
            while let tOpen = body.range(of: "<t", range: origin..<body.endIndex) {
                let tAfter = tOpen.upperBound
                guard tAfter < body.endIndex else { break }
                let tMark = body[tAfter]
                if tMark != " " && tMark != ">" && tMark != "/" {
                    origin = tAfter
                    continue
                }
                guard let gt = body.range(of: ">", range: tAfter..<body.endIndex) else { break }
                guard let tClose = body.range(of: "</t>", range: gt.upperBound..<body.endIndex) else { break }
                text += unescape(String(body[gt.upperBound..<tClose.lowerBound]))
                origin = tClose.upperBound
            }
            out.append(text)
            cursor = close.upperBound
        }
        return out
    }
}

enum SheetXML {
    static func parse(_ xml: String, strings: [String]) -> [[String]] {
        parse(data: Data(xml.utf8), strings: strings)
    }

    static func parse(data: Data, strings: [String]) -> [[String]] {
        walk(data: data, strings: strings)
    }

    static func rawCell(_ inner: Data, letter: String, strings: [String]) -> String {
        let needle = Array("r=\"\(letter)".utf8)
        var searchFrom = inner.startIndex
        while searchFrom < inner.endIndex {
            guard let start = inner.range(of: Data(needle), options: [], in: searchFrom..<inner.endIndex) else {
                return ""
            }
            let after = start.upperBound
            guard after < inner.endIndex else { return "" }
            let next = inner[after]
            searchFrom = after
            guard next >= 0x30, next <= 0x39 else { continue }
            let limit = inner.index(start.lowerBound, offsetBy: 200, limitedBy: inner.endIndex) ?? inner.endIndex
            let window = inner[start.lowerBound..<limit]
            let shared = window.range(of: Data("t=\"s\"".utf8)) != nil
            guard let open = window.range(of: Data("<v>".utf8)) else { return "" }
            var cursor = open.upperBound
            while cursor < window.endIndex, window[cursor] != 0x3C { cursor = window.index(after: cursor) }
            let raw = String(data: window[open.upperBound..<cursor], encoding: .ascii) ?? ""
            if shared, let index = Int(raw), strings.indices.contains(index) { return strings[index] }
            return raw
        }
        return ""
    }

    static func rawMap(_ inner: Data, strings: [String]) -> [String: String] {
        var out: [String: String] = [:]
        out.reserveCapacity(120)
        let rToken = Data("r=\"".utf8)
        let vToken = Data("<v>".utf8)
        let sToken = Data("t=\"s\"".utf8)
        var cursor = inner.startIndex
        while cursor < inner.endIndex, let found = inner.range(of: rToken, options: [], in: cursor..<inner.endIndex) {
            var letterEnd = found.upperBound
            while letterEnd < inner.endIndex {
                let byte = inner[letterEnd]
                if byte >= 65 && byte <= 90 { letterEnd = inner.index(after: letterEnd); continue }
                break
            }
            guard letterEnd < inner.endIndex, inner[letterEnd] >= 0x30, inner[letterEnd] <= 0x39 else {
                cursor = found.upperBound
                continue
            }
            let letter = String(data: inner[found.upperBound..<letterEnd], encoding: .ascii) ?? ""
            let windowEnd = inner.index(found.lowerBound, offsetBy: 400, limitedBy: inner.endIndex) ?? inner.endIndex
            let window = inner[found.lowerBound..<windowEnd]
            guard let open = window.range(of: vToken) else {
                cursor = letterEnd
                continue
            }
            var valueEnd = open.upperBound
            while valueEnd < window.endIndex, window[valueEnd] != 0x3C {
                valueEnd = window.index(after: valueEnd)
            }
            let raw = String(data: window[open.upperBound..<valueEnd], encoding: .ascii) ?? ""
            if window.range(of: sToken) != nil, let index = Int(raw), strings.indices.contains(index) {
                out[letter] = strings[index]
            } else {
                out[letter] = raw
            }
            cursor = letterEnd
        }
        return out
    }

    static func colLetter(_ index: Int) -> String {
        var value = index
        var out = ""
        repeat {
            out = String(UnicodeScalar(65 + value % 26)!) + out
            value = value / 26 - 1
        } while value >= 0
        return out
    }

    static func columnLooksLikeStore(_ inner: Data, letter: String) -> Bool {
        let needle = Data("r=\"\(letter)".utf8)
        guard let start = inner.range(of: needle) else { return false }
        let window = inner[start.lowerBound..<min(inner.endIndex, start.lowerBound + 80)]
        guard let v = window.range(of: Data("<v>".utf8)) else { return false }
        let digits = window[v.upperBound..<min(window.endIndex, v.upperBound + 8)]
        var n = 0
        var count = 0
        for byte in digits {
            if byte == 0x3C { break }
            guard byte >= 0x30, byte <= 0x39 else { return false }
            n = n * 10 + Int(byte - 0x30)
            count += 1
        }
        return count >= 3 && count <= 5 && n < 200_000
    }

    static func forEachRow(data: Data, strings: [String], keep: (() -> Set<Int>?)? = nil, handle: ([String]) -> Void) {
        forEachRowBytes(data: data, strings: strings, keep: keep, handle: handle)
    }

    static func forEachRowInflating(
        compressed: Data,
        offset: Int = 0,
        count: Int? = nil,
        strings: [String],
        keep: (() -> Set<Int>?)? = nil,
        include: ((Data) -> Bool)? = nil,
        handleRaw: ((Data) -> Void)? = nil,
        stop: (() -> Bool)? = nil,
        handle: ([String]) -> Void = { _ in }
    ) {
        var stream = z_stream()
        let span = count ?? max(0, compressed.count - offset)
        var status: Int32 = compressed.withUnsafeBytes { srcBuf in
            guard let src = srcBuf.bindMemory(to: Bytef.self).baseAddress, offset + span <= compressed.count else { return Z_ERRNO }
            stream.next_in = UnsafeMutablePointer(mutating: src + offset)
            stream.avail_in = uInt(span)
            return inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        }
        if status != Z_OK { return }
        defer { inflateEnd(&stream) }
        var pending = Data()
        pending.reserveCapacity(256_000)
        let chunkSize = 262_144
        var chunk = Data(count: chunkSize)
        let closeToken = Data("</row>".utf8)
        let openToken = Data("<row".utf8)
        while true {
            var produced = 0
            status = chunk.withUnsafeMutableBytes { dstBuf in
                guard let dst = dstBuf.bindMemory(to: Bytef.self).baseAddress else { return Z_ERRNO }
                stream.next_out = dst
                stream.avail_out = uInt(chunkSize)
                return inflate(&stream, Z_NO_FLUSH)
            }
            produced = chunkSize - Int(stream.avail_out)
            if produced > 0 {
                pending.append(chunk.prefix(produced))
            }
            while let close = pending.range(of: closeToken) {
                let end = close.upperBound
                guard let open = pending.range(of: openToken, in: 0..<end) else {
                    pending.removeSubrange(0..<end)
                    continue
                }
                let after = open.upperBound
                guard after < pending.count else { break }
                let mark = pending[after]
                if mark != 0x20 && mark != 0x3E && mark != 0x2F {
                    pending.removeSubrange(0..<after)
                    continue
                }
                guard let gt = pending.range(of: Data(">".utf8), in: after..<end) else { break }
                let inner = pending[gt.upperBound..<close.lowerBound]
                let slice = Data(inner)
                if let handleRaw {
                    handleRaw(slice)
                    pending.removeSubrange(0..<end)
                    continue
                }
                if let include, !include(slice) {
                    pending.removeSubrange(0..<end)
                    continue
                }
                if let xml = String(data: slice, encoding: .utf8) ?? String(data: slice, encoding: .isoLatin1) {
                    handle(walkCells(Substring(xml), strings: strings, keep: keep?()))
                }
                pending.removeSubrange(0..<end)
            }
            if status == Z_STREAM_END { break }
            if status != Z_OK && status != Z_BUF_ERROR { break }
            if produced == 0, stream.avail_in == 0 { break }
            if stop?() == true { break }
        }
    }
    static func forEachRowBytes(data: Data, strings: [String], keep: (() -> Set<Int>?)? = nil, handle: ([String]) -> Void) {
        let rowOpen = Data("<row".utf8)
        let rowClose = Data("</row>".utf8)
        let gt = Data(">".utf8)
        var origin = data.startIndex
        while origin < data.endIndex, let open = data.range(of: rowOpen, in: origin..<data.endIndex) {
            let after = open.upperBound
            guard after < data.endIndex else { break }
            let mark = data[after]
            if mark != 0x20 && mark != 0x3E && mark != 0x2F {
                origin = after
                continue
            }
            guard let tagClose = data.range(of: gt, in: after..<data.endIndex) else { break }
            let slash = data.index(before: tagClose.lowerBound)
            if data[slash] == 0x2F {
                handle([])
                origin = tagClose.upperBound
                continue
            }
            guard let close = data.range(of: rowClose, in: tagClose.upperBound..<data.endIndex) else { break }
            let inner = data[tagClose.upperBound..<close.lowerBound]
            if let xml = String(data: inner, encoding: .utf8) ?? String(data: Data(inner), encoding: .isoLatin1) {
                handle(walkCells(Substring(xml), strings: strings, keep: keep?()))
            }
            origin = close.upperBound
        }
    }

    /// Safe string walk. The pointer scanner crashed on Power BI sheets.
    private static func walk(data: Data, strings: [String]) -> [[String]] {
        guard var xml = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else { return [] }
        if xml.hasPrefix("\u{FEFF}") { xml.removeFirst() }
        if xml.contains("<x:") {
            xml = xml.replacingOccurrences(of: "<x:", with: "<").replacingOccurrences(of: "</x:", with: "</")
        }
        var rows: [[String]] = []
        rows.reserveCapacity(4096)
        var cursor = xml.startIndex
        while let rowStart = xml.range(of: "<row", range: cursor..<xml.endIndex) {
            let after = rowStart.upperBound
            guard after < xml.endIndex else { break }
            let mark = xml[after]
            if mark != " " && mark != ">" && mark != "/" {
                cursor = after
                continue
            }
            guard let tagClose = xml.range(of: ">", range: after..<xml.endIndex) else { break }
            if xml[xml.index(before: tagClose.lowerBound)] == "/" {
                rows.append([])
                cursor = tagClose.upperBound
                continue
            }
            guard let rowEnd = xml.range(of: "</row>", range: tagClose.upperBound..<xml.endIndex) else { break }
            rows.append(walkCells(xml[tagClose.upperBound..<rowEnd.lowerBound], strings: strings))
            cursor = rowEnd.upperBound
        }
        return rows
    }

    private static func walkCells(_ inner: Substring, strings: [String], keep: Set<Int>? = nil) -> [String] {
        var cells: [String] = []
        var origin = inner.startIndex
        while let cs = inner.range(of: "<c", range: origin..<inner.endIndex) {
            let after = cs.upperBound
            guard after < inner.endIndex else { break }
            let mark = inner[after]
            if mark != " " && mark != ">" && mark != "/" {
                origin = after
                continue
            }
            guard let tagClose = inner.range(of: ">", range: after..<inner.endIndex) else { break }
            let openTag = String(inner[cs.lowerBound...tagClose.lowerBound])
            let selfClosing = openTag.hasSuffix("/>") || inner[inner.index(before: tagClose.lowerBound)] == "/"
            let type = attrValue(openTag, "t")
            let ref = attrValue(openTag, "r")
            let column = columnIndex(ref)
            if let keep, column >= 0, !keep.contains(column) {
                if selfClosing {
                    origin = tagClose.upperBound
                } else if let close = inner.range(of: "</c>", range: tagClose.upperBound..<inner.endIndex) {
                    origin = close.upperBound
                } else {
                    break
                }
                continue
            }
            var value = ""
            if selfClosing {
                origin = tagClose.upperBound
            } else if let close = inner.range(of: "</c>", range: tagClose.upperBound..<inner.endIndex) {
                let body = inner[tagClose.upperBound..<close.lowerBound]
                if type == "inlineStr" {
                    value = innerTexts(body, tag: "t")
                } else {
                    let raw = innerTexts(body, tag: "v")
                    if type == "s", let index = Int(raw), strings.indices.contains(index) {
                        value = strings[index]
                    } else {
                        value = raw
                    }
                }
                origin = close.upperBound
            } else {
                break
            }
            if column < 0 {
                cells.append(value)
            } else if column < 256 {
                if cells.count <= column {
                    cells.append(contentsOf: repeatElement("", count: column - cells.count + 1))
                }
                cells[column] = value
            }
        }
        return cells
    }

    private static func attrValue(_ tag: String, _ name: String) -> String {
        let needle = " \(name)=\""
        guard let start = tag.range(of: needle) else { return "" }
        let rest = tag[start.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return "" }
        return String(rest[..<end])
    }

    private static func innerTexts(_ body: Substring, tag: String) -> String {
        var out = ""
        var origin = body.startIndex
        let open = "<\(tag)"
        let close = "</\(tag)>"
        while let ts = body.range(of: open, range: origin..<body.endIndex) {
            guard let gt = body.range(of: ">", range: ts.upperBound..<body.endIndex) else { break }
            guard let end = body.range(of: close, range: gt.upperBound..<body.endIndex) else { break }
            out += unescape(String(body[gt.upperBound..<end.lowerBound]))
            origin = end.upperBound
        }
        return out
    }

    private static func scan(_ base: UnsafePointer<UInt8>, count: Int, strings: [String]) -> [[String]] {
        var i = 0
        if count >= 3, base[0] == 0xEF, base[1] == 0xBB, base[2] == 0xBF { i = 3 }

        var rows: [[String]] = []
        var cells: [String] = []
        var inRow = false

        while i < count {
            if base[i] != 60 { // <
                i += 1
                continue
            }
            i += 1
            if i >= count { break }
            let closing = base[i] == 47 // /
            if closing { i += 1 }
            let name = readName(base, count, &i)
            if name.isEmpty {
                skipToTagEnd(base, count, &i)
                continue
            }

            if nameEquals(name, "row") {
                if closing {
                    if inRow {
                        rows.append(cells)
                        cells = []
                        inRow = false
                    }
                } else {
                    if inRow { rows.append(cells) }
                    cells = []
                    inRow = true
                    skipToTagEnd(base, count, &i)
                }
                continue
            }

            if inRow, !closing, nameEquals(name, "c") {
                let parsed = readCell(base, count, &i, strings: strings)
                let column = columnIndex(parsed.ref)
                if column >= 0 {
                    if cells.count <= column {
                        cells.append(contentsOf: repeatElement("", count: column - cells.count + 1))
                    }
                    cells[column] = parsed.value
                } else {
                    cells.append(parsed.value)
                }
                continue
            }

            skipToTagEnd(base, count, &i)
        }

        if inRow { rows.append(cells) }
        return rows
    }

    private static func readCell(_ base: UnsafePointer<UInt8>, _ count: Int, _ i: inout Int, strings: [String]) -> (ref: String, value: String) {
        let attrStart = i
        let selfClosing = skipToTagEnd(base, count, &i)
        let type = attribute(base, from: attrStart, to: i, name: "t")
        let ref = attribute(base, from: attrStart, to: i, name: "r")
        if selfClosing { return (ref, "") }

        let contentStart = i
        guard let closeAt = findClosingTag(base, count, from: i, name: "c") else {
            return (ref, "")
        }
        i = closeAt.end
        if type == "inlineStr" {
            return (ref, firstInnerText(base, from: contentStart, to: closeAt.start, tag: "t"))
        }
        let raw = firstInnerText(base, from: contentStart, to: closeAt.start, tag: "v")
        if type == "s", let index = Int(raw), strings.indices.contains(index) {
            return (ref, strings[index])
        }
        return (ref, raw)
    }

    private static func columnIndex(_ ref: String) -> Int {
        var n = 0
        for byte in ref.utf8 {
            if byte >= 65, byte <= 90 {
                n = n * 26 + Int(byte - 64)
            } else if byte >= 97, byte <= 122 {
                n = n * 26 + Int(byte - 96)
            } else {
                break
            }
        }
        return n - 1
    }

    @discardableResult
    private static func skipToTagEnd(_ base: UnsafePointer<UInt8>, _ count: Int, _ i: inout Int) -> Bool {
        var selfClosing = false
        while i < count {
            let ch = base[i]
            if ch == 47, i + 1 < count, base[i + 1] == 62 {
                selfClosing = true
                i += 2
                return true
            }
            if ch == 62 {
                i += 1
                return false
            }
            i += 1
        }
        return selfClosing
    }

    private static func readName(_ base: UnsafePointer<UInt8>, _ count: Int, _ i: inout Int) -> [UInt8] {
        let start = i
        while i < count, isNameChar(base[i]) { i += 1 }
        if i < count, base[i] == 58, i > start { // namespace prefix
            i += 1
            let real = i
            while i < count, isNameChar(base[i]) { i += 1 }
            return Array(UnsafeBufferPointer(start: base + real, count: i - real))
        }
        return Array(UnsafeBufferPointer(start: base + start, count: i - start))
    }

    private static func findClosingTag(_ base: UnsafePointer<UInt8>, _ count: Int, from: Int, name: String) -> (start: Int, end: Int)? {
        var j = from
        let expected = Array(name.utf8)
        while j < count {
            if base[j] == 60, j + 1 < count, base[j + 1] == 47 {
                var k = j + 2
                let tag = readName(base, count, &k)
                if nameEquals(tag, expected) {
                    while k < count, base[k] != 62 { k += 1 }
                    if k < count { k += 1 }
                    return (j, k)
                }
            }
            j += 1
        }
        return nil
    }

    private static func firstInnerText(_ base: UnsafePointer<UInt8>, from: Int, to: Int, tag: String) -> String {
        var j = from
        let expected = Array(tag.utf8)
        while j < to {
            if base[j] == 60 {
                var k = j + 1
                if k < to, base[k] == 47 {
                    j += 1
                    continue
                }
                let name = readName(base, to, &k)
                if nameEquals(name, expected) {
                    let selfClose = skipToTagEnd(base, to, &k)
                    if selfClose { return "" }
                    if let close = findClosingTag(base, to, from: k, name: tag) {
                        return decode(base, k, close.start)
                    }
                    return decode(base, k, to)
                }
            }
            j += 1
        }
        return ""
    }

    private static func attribute(_ base: UnsafePointer<UInt8>, from: Int, to: Int, name: String) -> String {
        let key = Array(name.utf8)
        var j = from
        while j + key.count + 2 < to {
            var match = true
            for (offset, byte) in key.enumerated() where base[j + offset] != byte {
                match = false
                break
            }
            if match {
                let prev = j == from ? 32 : base[j - 1]
                let next = base[j + key.count]
                if isNameChar(prev) == false, next == 61 {
                    var k = j + key.count + 1
                    if k < to, base[k] == 34 || base[k] == 39 {
                        let quote = base[k]
                        k += 1
                        let start = k
                        while k < to, base[k] != quote { k += 1 }
                        return decode(base, start, k)
                    }
                }
            }
            j += 1
        }
        return ""
    }

    private static func decode(_ base: UnsafePointer<UInt8>, _ start: Int, _ end: Int) -> String {
        guard end > start else { return "" }
        let raw = String(decoding: UnsafeBufferPointer(start: base + start, count: end - start), as: UTF8.self)
        if raw.contains("&") { return unescape(raw) }
        return raw
    }

    private static func isNameChar(_ byte: UInt8) -> Bool {
        (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122) || (byte >= 48 && byte <= 57)
    }

    private static func nameEquals(_ name: [UInt8], _ expected: String) -> Bool {
        nameEquals(name, Array(expected.utf8))
    }

    private static func nameEquals(_ name: [UInt8], _ expected: [UInt8]) -> Bool {
        guard name.count == expected.count else { return false }
        for index in name.indices {
            let a = name[index] | 0x20
            let b = expected[index] | 0x20
            if a != b { return false }
        }
        return true
    }
}

private func stripNS(_ xml: String) -> String {
    xml.replacingOccurrences(of: "<(/?)(\\w+):", with: "<$1", options: .regularExpression)
}

private func unescape(_ raw: String) -> String {
    // Build XML entity names in parts so they cannot be HTML-decoded
    // back into broken Swift string literals.
    func entity(_ name: String) -> String { "&" + name + ";" }
    func numeric(_ code: Int) -> String { "&#" + String(code) + ";" }
    return raw
        .replacingOccurrences(of: entity("quot"), with: "\"")
        .replacingOccurrences(of: entity("apos"), with: "'")
        .replacingOccurrences(of: numeric(34), with: "\"")
        .replacingOccurrences(of: numeric(39), with: "'")
        .replacingOccurrences(of: entity("lt"), with: "<")
        .replacingOccurrences(of: entity("gt"), with: ">")
        .replacingOccurrences(of: entity("amp"), with: "&")
}

private func matches(in text: String, pattern: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
    let range = NSRange(text.startIndex..., in: text)
    return regex.matches(in: text, range: range).compactMap { match in
        guard let r = Range(match.range(at: match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound ? 1 : 0), in: text) else { return nil }
        return String(text[r])
    }
}

private func firstGroup(in text: String, pattern: String) -> String? {
    matches(in: text, pattern: pattern).first
}

private func attr(_ tag: String, _ name: String) -> String? {
    firstGroup(in: tag, pattern: "\(name)=\"([^\"]+)\"")
}

final class ZipArchive {
    private struct Meta {
        var localOff: Int
        var method: UInt16
        var compSize: Int
        var uncompSize: Int
    }

    private let data: Data
    private var index: [String: Meta] = [:]
    private var cache: [String: Data] = [:]

    init?(data: Data) {
        self.data = data
        if !parseCentralDirectory(data) {
            parseLocalHeaders(data)
        }
        if index.isEmpty { return nil }
    }

    private static func keep(_ name: String) -> Bool {
        name == "xl/workbook.xml"
            || name == "xl/sharedStrings.xml"
            || name.hasPrefix("xl/worksheets/")
            || name.hasPrefix("xl/_rels/")
    }

    private func parseCentralDirectory(_ data: Data) -> Bool {
        guard let eocd = Self.findEOCD(data) else { return false }
        let storedCD = Int(u32(data, eocd + 16))
        let cdSize = Int(u32(data, eocd + 12))
        let records = Int(u16(data, eocd + 10))
        guard records > 0, cdSize > 46, eocd >= cdSize else { return false }
        let inferred = eocd - cdSize
        var cdStart = storedCD
        if inferred >= 0, inferred + 4 <= data.count, u32(data, inferred) == 0x02014b50 {
            cdStart = inferred
        } else if storedCD + 4 <= data.count, u32(data, storedCD) == 0x02014b50 {
            cdStart = storedCD
        } else {
            return false
        }
        let prefix = max(0, cdStart - storedCD)
        var off = cdStart
        let cdEnd = min(data.count, cdStart + cdSize + 4)
        var seen = 0
        while off + 46 <= cdEnd, seen < 512 {
            if u32(data, off) != 0x02014b50 { break }
            let flags = u16(data, off + 8)
            let method = u16(data, off + 10)
            var compSize = Int(u32(data, off + 20))
            var uncompSize = Int(u32(data, off + 24))
            let nameLen = Int(u16(data, off + 28))
            let extraLen = Int(u16(data, off + 30))
            let commentLen = Int(u16(data, off + 32))
            let localOff = Int(u32(data, off + 42)) + prefix
            let nameStart = off + 46
            guard nameStart + nameLen <= data.count else { break }
            let name = String(data: data.subdata(in: nameStart..<(nameStart + nameLen)), encoding: .utf8) ?? ""
            let extraStart = nameStart + nameLen
            if extraStart + extraLen <= data.count {
                Self.applyZip64Sizes(data: data, extraStart: extraStart, extraLen: extraLen, compSize: &compSize, uncompSize: &uncompSize)
            }
            if Self.keep(name) {
                index[name] = Meta(localOff: localOff, method: method, compSize: compSize, uncompSize: uncompSize)
            }
            off = extraStart + extraLen + commentLen
            seen += 1
        }
        return index["xl/workbook.xml"] != nil || !index.isEmpty
    }

    private func parseLocalHeaders(_ data: Data) {
        var offset = 0
        let count = data.count
        while offset + 4 <= count, offset < 131_072, u32(data, offset) != 0x04034b50 {
            offset += 1
        }
        while offset + 30 <= count {
            let sig = u32(data, offset)
            if sig == 0x02014b50 || sig == 0x06054b50 { break }
            guard sig == 0x04034b50 else {
                offset += 1
                continue
            }
            let flags = u16(data, offset + 6)
            let method = u16(data, offset + 8)
            var compSize = Int(u32(data, offset + 18))
            var uncompSize = Int(u32(data, offset + 22))
            let nameLen = Int(u16(data, offset + 26))
            let extraLen = Int(u16(data, offset + 28))
            let nameStart = offset + 30
            guard nameStart + nameLen <= count else {
                offset += 1
                continue
            }
            let name = String(data: data.subdata(in: nameStart..<(nameStart + nameLen)), encoding: .utf8) ?? ""
            let extraStart = nameStart + nameLen
            if extraStart + extraLen <= count {
                Self.applyZip64Sizes(data: data, extraStart: extraStart, extraLen: extraLen, compSize: &compSize, uncompSize: &uncompSize)
            }
            let dataStart = extraStart + extraLen
            if flags & 0x08 != 0, compSize == 0 {
                var scan = dataStart
                while scan + 4 <= count {
                    let next = u32(data, scan)
                    if next == 0x04034b50 || next == 0x02014b50 || next == 0x08074b50 { break }
                    scan += 1
                    if scan - dataStart > 50_000_000 { break }
                }
                offset = scan
                if offset + 4 <= count, u32(data, offset) == 0x08074b50 { offset += 16 }
                continue
            }
            if Self.keep(name) {
                index[name] = Meta(localOff: offset, method: method, compSize: compSize, uncompSize: uncompSize)
            }
            offset = dataStart + max(compSize, 0)
            if flags & 0x08 != 0 {
                if offset + 4 <= count, u32(data, offset) == 0x08074b50 { offset += 16 }
                else { offset += 12 }
            }
        }
    }

    private func extract(meta: Meta) -> Data? {
        let localOff = meta.localOff
        guard localOff + 30 <= data.count, u32(data, localOff) == 0x04034b50 else { return nil }
        let nameLen = Int(u16(data, localOff + 26))
        let extraLen = Int(u16(data, localOff + 28))
        let dataStart = localOff + 30 + nameLen + extraLen
        let size = max(meta.compSize, 0)
        guard dataStart + size <= data.count else { return nil }
        let payload = data.subdata(in: dataStart..<(dataStart + size))
        if meta.method == 0 {
            return payload
        }
        if meta.method == 8 {
            return inflate(payload, uncompressedSize: meta.uncompSize)
        }
        return nil
    }

    func file(named name: String) -> Data? {
        if let cached = cache[name] { return cached }
        guard let meta = index[name] else { return nil }
        guard let payload = extract(meta: meta) else { return nil }
        if payload.count < 1_500_000 {
            cache[name] = payload
        }
        return payload
    }

    func compressedRange(named name: String) -> (offset: Int, size: Int, uncomp: Int, method: UInt16)? {
        guard let meta = index[name] ?? index[name.replacingOccurrences(of: "xl/", with: "")] else { return nil }
        let localOff = meta.localOff
        guard localOff + 30 <= data.count, u32(data, localOff) == 0x04034b50 else { return nil }
        let nameLen = Int(u16(data, localOff + 26))
        let extraLen = Int(u16(data, localOff + 28))
        let dataStart = localOff + 30 + nameLen + extraLen
        let size = max(meta.compSize, 0)
        guard dataStart + size <= data.count else { return nil }
        return (dataStart, size, meta.uncompSize, meta.method)
    }

    var rawBytes: Data { data }

    func compressedPayload(named name: String) -> (bytes: Data, uncomp: Int, method: UInt16)? {
        guard let meta = index[name] ?? index[name.replacingOccurrences(of: "xl/", with: "")] else { return nil }
        let localOff = meta.localOff
        guard localOff + 30 <= data.count, u32(data, localOff) == 0x04034b50 else { return nil }
        let nameLen = Int(u16(data, localOff + 26))
        let extraLen = Int(u16(data, localOff + 28))
        let dataStart = localOff + 30 + nameLen + extraLen
        let size = max(meta.compSize, 0)
        guard dataStart + size <= data.count else { return nil }
        return (data.subdata(in: dataStart..<(dataStart + size)), meta.uncompSize, meta.method)
    }

    func release(_ name: String) {
        cache.removeValue(forKey: name)
    }

    func entryNames() -> [String] {
        Array(index.keys)
    }

    func worksheetPaths() -> [String] {
        index.keys
            .filter { $0.hasPrefix("xl/worksheets/") && $0.hasSuffix(".xml") }
            .sorted { sheetIndex($0) < sheetIndex($1) }
    }

    static func findEOCD(_ data: Data) -> Int? {
        guard data.count >= 22 else { return nil }
        let floor = max(0, data.count - 65_557)
        var i = data.count - 22
        while i >= floor {
            if u32(data, i) == 0x06054b50 { return i }
            i -= 1
        }
        return nil
    }

    private static func applyZip64Sizes(data: Data, extraStart: Int, extraLen: Int, compSize: inout Int, uncompSize: inout Int) {
        var cursor = extraStart
        let end = extraStart + extraLen
        while cursor + 4 <= end {
            let headerID = u16(data, cursor)
            let blockSize = Int(u16(data, cursor + 2))
            let blockStart = cursor + 4
            let blockEnd = min(end, blockStart + blockSize)
            if headerID == 1 {
                var field = blockStart
                if uncompSize == 0xFFFFFFFF, field + 8 <= blockEnd {
                    uncompSize = Int(u64(data, field)); field += 8
                }
                if compSize == 0xFFFFFFFF, field + 8 <= blockEnd {
                    compSize = Int(u64(data, field))
                }
            }
            cursor = blockEnd
        }
    }

    private func sheetIndex(_ path: String) -> Int {
        let digits = path.compactMap(\.wholeNumberValue)
        let value = digits.reduce(0) { $0 * 10 + $1 }
        return value == 0 ? 999 : value
    }
}

private func inflate(_ source: Data, uncompressedSize: Int) -> Data? {
    let hint = usableInflateHint(uncompressedSize, compressed: source.count)
    if let out = inflateWindow(source, uncompressedSize: hint, windowBits: -MAX_WBITS), !out.isEmpty {
        return out
    }
    if let out = inflateWindow(source, uncompressedSize: uncompressedSize, windowBits: MAX_WBITS), !out.isEmpty {
        return out
    }
    var wrapped = Data([0x78, 0x01])
    wrapped.append(source)
    if let out = inflateWindow(wrapped, uncompressedSize: uncompressedSize, windowBits: MAX_WBITS), !out.isEmpty {
        return out
    }
    #if !HEARTBEAT_INGEST
    let dstSize = max(uncompressedSize, source.count * 8 + 64)
    var dest = Data(count: dstSize)
    let written = dest.withUnsafeMutableBytes { destPtr -> Int in
        source.withUnsafeBytes { srcPtr in
            guard
                let destBase = destPtr.bindMemory(to: UInt8.self).baseAddress,
                let srcBase = srcPtr.bindMemory(to: UInt8.self).baseAddress
            else { return 0 }
            return compression_decode_buffer(
                destBase,
                dstSize,
                srcBase,
                source.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
    }
    if written > 0 {
        dest.count = written
        return dest
    }
    var dest2 = Data(count: dstSize)
    let written2 = dest2.withUnsafeMutableBytes { destPtr -> Int in
        wrapped.withUnsafeBytes { srcPtr in
            guard
                let destBase = destPtr.bindMemory(to: UInt8.self).baseAddress,
                let srcBase = srcPtr.bindMemory(to: UInt8.self).baseAddress
            else { return 0 }
            return compression_decode_buffer(
                destBase,
                dstSize,
                srcBase,
                wrapped.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
    }
    guard written2 > 0 else { return nil }
    dest2.count = written2
    return dest2
    #else
    return nil
    #endif
}

private func usableInflateHint(_ uncompressedSize: Int, compressed: Int) -> Int {
    if uncompressedSize > 64, uncompressedSize <= 180_000_000 {
        return uncompressedSize
    }
    return min(max(compressed * 6, 1_000_000), 16_000_000)
}

private func inflateWindow(_ source: Data, uncompressedSize: Int, windowBits: Int32) -> Data? {
    guard !source.isEmpty else { return nil }
    var size = usableInflateHint(uncompressedSize, compressed: source.count)
    for _ in 0..<8 {
        var dest = Data(count: size)
        var produced = 0
        let rc: Int32 = source.withUnsafeBytes { srcBuf in
            dest.withUnsafeMutableBytes { dstBuf in
                guard
                    let src = srcBuf.bindMemory(to: Bytef.self).baseAddress,
                    let dst = dstBuf.bindMemory(to: Bytef.self).baseAddress
                else { return Z_ERRNO }
                var stream = z_stream()
                stream.next_in = UnsafeMutablePointer(mutating: src)
                stream.avail_in = uInt(source.count)
                stream.next_out = dst
                stream.avail_out = uInt(size)
                var status = inflateInit2_(&stream, windowBits, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
                guard status == Z_OK else { return status }
                status = inflate(&stream, Z_FINISH)
                produced = Int(stream.total_out)
                inflateEnd(&stream)
                return status
            }
        }
        if rc == Z_STREAM_END || rc == Z_OK, produced > 0 {
            dest.count = produced
            return dest
        }
        if rc == Z_BUF_ERROR {
            if size >= 180_000_000 { return nil }
            size = min(max(size * 2, size + 8_000_000), 180_000_000)
            continue
        }
        return nil
    }
    return nil
}

private func u16(_ data: Data, _ offset: Int) -> UInt16 {
    UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
}

private func u32(_ data: Data, _ offset: Int) -> UInt32 {
    UInt32(data[offset])
        | (UInt32(data[offset + 1]) << 8)
        | (UInt32(data[offset + 2]) << 16)
        | (UInt32(data[offset + 3]) << 24)
}

private func u64(_ data: Data, _ offset: Int) -> UInt64 {
    UInt64(u32(data, offset)) | (UInt64(u32(data, offset + 4)) << 32)
}
