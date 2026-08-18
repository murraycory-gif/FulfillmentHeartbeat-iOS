import Compression
import Foundation

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
        case unsupported

        var errorDescription: String? {
            switch self {
            case .empty: return "That file had no usable store rows."
            case .unreadable: return "Could not read that workbook."
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
        } else if ext == "xlsx" || data.starts(with: [0x50, 0x4B]) {
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
                let matrix = SheetXML.parse(data: sheet, strings: strings)
                return rows(from: matrix)
            }
        }
        throw ParseError.unreadable
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
        "storenumber", "storenbr", "store", "storeid", "unit", "storenbr",
    ]
    private static let nameKeys = ["storename", "unitname", "location", "storenm"]
    private static let shopperNameKeys = [
        "shopper", "shoppername", "picker", "pickername", "associate", "associatename", "teammember",
    ]
    private static let shopperIdKeys = [
        "shopperid", "pickerid", "associateid", "win", "userid", "associatewin",
        "employeealternateid", "employeeid", "employee", "empid", "associate",
    ]
    private static let dateKeys = ["date", "week", "weekending", "period", "recordedon", "asof", "reportdate"]

    private static let metricAliases: [String: String] = [
        "starrating": "star_rating",
        "stars": "star_rating",
        "fivestar": "star_rating",
        "fivestars": "star_rating",
        "rating": "star_rating",
        "otp": "otp_pct",
        "otpct": "otp_pct",
        "ontime": "otp_pct",
        "ontimepromise": "otp_pct",
        "ontimepct": "otp_pct",
        "fill": "fill_rate_pct",
        "fillrate": "fill_rate_pct",
        "fillratepct": "fill_rate_pct",
        "quality": "quality_score",
        "qualityscore": "quality_score",
        "cx": "cx_score",
        "cxscore": "cx_score",
        "customerexperience": "cx_score",
        "compliance": "compliance_pct",
        "compliancepct": "compliance_pct",
        "pickpath": "compliance_pct",
        "pickpathcompliance": "compliance_pct",
        "pathcompliance": "compliance_pct",
        "orders": "orders",
        "ordercount": "orders",
        "order": "orders",
        "purepphexcludingreshop": "pph",
        "pphexcludingreshop": "pph",
        "pickstotal": "picks_total",
        "totalpicks": "picks_total",
        "pickscompliant": "picks_compliant",
        "compliantpicks": "picks_compliant",
        "exceptions": "exception_count",
        "exceptioncount": "exception_count",
        "pnr": "pnr_count",
        "pnrcount": "pnr_count",
        "prepnotready": "pnr_count",
        "notready": "pnr_count",
        "ordersdue": "orders_due",
        "dueorders": "orders_due",
        "pnrrate": "pnr_rate_pct",
        "pnrratepct": "pnr_rate_pct",
        "avglatemin": "avg_late_min",
        "avglate": "avg_late_min",
        "lateavg": "avg_late_min",
        "pickupcapacity": "pickup_capacity",
        "pickupcap": "pickup_capacity",
        "pickupslots": "pickup_capacity",
        "deliverycapacity": "delivery_capacity",
        "deliverycap": "delivery_capacity",
        "deliveryslots": "delivery_capacity",
        "recpickup": "rec_pickup",
        "recommendedpickup": "rec_pickup",
        "recdelivery": "rec_delivery",
        "recommendeddelivery": "rec_delivery",
        "pickuputil": "pickup_util_pct",
        "pickuputilization": "pickup_util_pct",
        "deliveryutil": "delivery_util_pct",
        "deliveryutilization": "delivery_util_pct",
        "scheduleefficiency": "schedule_efficiency_pct",
        "scheduleeff": "schedule_efficiency_pct",
        "efficiency": "schedule_efficiency_pct",
        "schedefficiency": "schedule_efficiency_pct",
        "overscheduled": "over_scheduled",
        "oversched": "over_scheduled",
        "overhours": "over_scheduled",
        "underscheduled": "under_scheduled",
        "undersched": "under_scheduled",
        "underhours": "under_scheduled",
        "pph": "pph",
        "purepph": "pph",
        "purepicksperhour": "pph",
        "picksperhour": "pph",
        "pickhours": "pick_hours",
        "hours": "pick_hours",
        "laborhours": "pick_hours",
        "goalpph": "goal_pph",
        "pphgoal": "goal_pph",
        "targetpph": "goal_pph",
    ]

    private static func rows(from matrix: [[String]]) -> [ParsedWorkbookRow] {
        if let outline = parseOutline(matrix), !outline.isEmpty {
            return outline
        }
        return parseFlat(matrix)
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
        for (index, cell) in weekRow.enumerated() {
            let trimmed = cell.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || isTotalCell(trimmed) { continue }
            let norm = normHeader(trimmed)
            if norm == "weekid" || norm == "week" || norm == "date" { continue }
            if let date = dateFromWeekID(trimmed) ?? isoDate(trimmed) {
                weekByColumn[index] = date
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
            if !weekByColumn.isEmpty {
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
                        storeNumber: storeRaw,
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
                storeNumber: storeNumber,
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
        if key == "compliance_pct" || key.contains("compliance") {
            key = "compliance_pct"
            if number <= 1.5 { number *= 100 }
        }
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
        if trimmed.contains(".") { return false }
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
        let headers = matrix[0].map(normHeader)
        var out: [ParsedWorkbookRow] = []
        for line in matrix.dropFirst() {
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
                    store = raw.trimmingCharacters(in: .whitespacesAndNewlines)
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
                    payload[mapped] = number
                } else {
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { text[mapped] = trimmed }
                }
            }
            if store.isEmpty && name == nil && division.isEmpty { continue }
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
        if let value = Double(cleaned) { return value }
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
        let cleaned = stripNS(xml)
        var out: [String] = []
        let sis = matches(in: cleaned, pattern: "<si[\\s\\S]*?</si>")
        for si in sis {
            let texts = matches(in: si, pattern: "<t(?:\\s[^>]*)?>([\\s\\S]*?)</t>")
            if texts.isEmpty {
                out.append("")
            } else {
                out.append(texts.map(unescape).joined())
            }
        }
        return out
    }
}

enum SheetXML {
    static func parse(_ xml: String, strings: [String]) -> [[String]] {
        parse(data: Data(xml.utf8), strings: strings)
    }

    static func parse(data: Data, strings: [String]) -> [[String]] {
        data.withUnsafeBytes { raw -> [[String]] in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return [] }
            return scan(base, count: raw.count, strings: strings)
        }
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
                cells.append(readCell(base, count, &i, strings: strings))
                continue
            }

            skipToTagEnd(base, count, &i)
        }

        if inRow { rows.append(cells) }
        return rows
    }

    private static func readCell(_ base: UnsafePointer<UInt8>, _ count: Int, _ i: inout Int, strings: [String]) -> String {
        let attrStart = i
        let selfClosing = skipToTagEnd(base, count, &i)
        let type = attribute(base, from: attrStart, to: i, name: "t")
        if selfClosing { return "" }

        let contentStart = i
        guard let closeAt = findClosingTag(base, count, from: i, name: "c") else {
            return ""
        }
        i = closeAt.end
        if type == "inlineStr" {
            return firstInnerText(base, from: contentStart, to: closeAt.start, tag: "t")
        }
        let raw = firstInnerText(base, from: contentStart, to: closeAt.start, tag: "v")
        if type == "s", let index = Int(raw), strings.indices.contains(index) {
            return strings[index]
        }
        return raw
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
    private var files: [String: Data] = [:]

    init?(data: Data) {
        var offset = 0
        let bytes = [UInt8](data)
        while offset + 30 <= bytes.count {
            let sig = u32(bytes, offset)
            if sig == 0x02014b50 || sig == 0x06054b50 { break }
            guard sig == 0x04034b50 else { return nil }
            let flags = u16(bytes, offset + 6)
            let method = u16(bytes, offset + 8)
            var compSize = Int(u32(bytes, offset + 18))
            var uncompSize = Int(u32(bytes, offset + 22))
            let nameLen = Int(u16(bytes, offset + 26))
            let extraLen = Int(u16(bytes, offset + 28))
            let nameStart = offset + 30
            guard nameStart + nameLen <= bytes.count else { return nil }
            let name = String(bytes: bytes[nameStart..<(nameStart + nameLen)], encoding: .utf8) ?? ""
            var dataStart = nameStart + nameLen + extraLen
            if flags & 0x08 != 0, compSize == 0 {
                // Data descriptor — scan for next signature after payload (best effort).
                if let next = nextLocalOrCentral(bytes, from: dataStart) {
                    // descriptor is 12 or 16 bytes before next header; size unknown — skip descriptor files
                    _ = next
                }
            }
            guard dataStart + compSize <= bytes.count else { return nil }
            let payload = Data(bytes[dataStart..<(dataStart + max(compSize, 0))])
            if method == 0 {
                files[name] = payload
            } else if method == 8 {
                files[name] = inflate(payload, uncompressedSize: uncompSize)
            }
            offset = dataStart + compSize
            if flags & 0x08 != 0 {
                // skip data descriptor
                if offset + 4 <= bytes.count, u32(bytes, offset) == 0x08074b50 { offset += 16 }
                else { offset += 12 }
            }
        }
        if files.isEmpty { return nil }
    }

    func file(named name: String) -> Data? {
        files[name]
    }

    private func nextLocalOrCentral(_ bytes: [UInt8], from start: Int) -> Int? {
        var i = start
        while i + 4 <= bytes.count {
            let sig = u32(bytes, i)
            if sig == 0x04034b50 || sig == 0x02014b50 { return i }
            i += 1
        }
        return nil
    }
}

private func inflate(_ source: Data, uncompressedSize: Int) -> Data? {
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
    // Some Excel writers emit a zlib wrapper; retry with a raw header prepended no-op.
    var wrapped = Data([0x78, 0x01])
    wrapped.append(source)
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
}

private func u16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
    UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
}

private func u32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
    UInt32(bytes[offset])
        | (UInt32(bytes[offset + 1]) << 8)
        | (UInt32(bytes[offset + 2]) << 16)
        | (UInt32(bytes[offset + 3]) << 24)
}
