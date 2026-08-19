import Foundation

enum MetricSection: String, CaseIterable, Identifiable, Codable, Hashable {
    case fiveStar = "five_star"
    case pickPath = "pick_path"
    case prepNotReady = "prep_not_ready"
    case dynacap = "dynacap"
    case scheduleQuality = "schedule_quality"
    case pph = "pph"
    case pickerScorecard = "picker_scorecard"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fiveStar: return "5 Star Metrics"
        case .pickPath: return "Pick Path Compliance"
        case .prepNotReady: return "Prep Not Ready"
        case .dynacap: return "Dynacap Setting"
        case .scheduleQuality: return "Schedule Quality"
        case .pph: return "PPH Pure Picks Per Hour"
        case .pickerScorecard: return "Picker ScoreCard"
        }
    }

    var short: String {
        switch self {
        case .fiveStar: return "5 Star"
        case .pickPath: return "Pick Path"
        case .prepNotReady: return "Prep NR"
        case .dynacap: return "Dynacap"
        case .scheduleQuality: return "Schedule"
        case .pph: return "PPH"
        case .pickerScorecard: return "Pickers"
        }
    }

    var blurb: String {
        switch self {
        case .fiveStar: return "Store-level star rating from Flash, Presubs, COE, OTT, and OTH5. Upload Star Ratings by Store."
        case .pickPath: return "Share of picks that followed the system path. Upload the All Pickers WEEK_ID export."
        case .prepNotReady: return "Share of pick hours lost to prep not ready. Upload the weekly Hours % export."
        case .dynacap: return "Pieces per hour we allow down to the picker. Upload the Overall Capacity Summary."
        case .scheduleQuality: return "How tightly the labor plan matches the work. Upload Optimized Departments."
        case .pph: return "Pure picks completed per labor hour. Upload the WEEK_ID by Division export."
        case .pickerScorecard: return "Shopper-level PPH, OTT, Presubs, OTH5, and COE. Upload the weekly Picker Scorecard."
        }
    }

    var expectedMetrics: String {
        switch self {
        case .fiveStar: return "Store · Division · OM · District · Total Rating · Flash · Presubs · COE · OTT · OTH5"
        case .pickPath: return "WEEK_ID · DIVISION · DISTRICT · OM · STORE_ID · EMPLOYEE · Pick Path · Orders · Pure PPH"
        case .prepNotReady: return "DIVISION · District · OM · Store · Prep Not Ready Hours %"
        case .dynacap: return "DISTRICT · Total Pieces/Total Hrs · DPA Dynacap · Utilization %"
        case .scheduleQuality: return "Division · District · Store · Schedule Efficiency · Under % · Over %"
        case .pph: return "WEEK_ID · DIVISION · DISTRICT · OM_AREA · OM_ID · STORE · Pure PPH"
        case .pickerScorecard: return "STORE · PICKER · PPH · OTT · Presub · OTH5 · COE · Orders"
        }
    }

    var symbol: String {
        switch self {
        case .fiveStar: return "star.fill"
        case .pickPath: return "point.topleft.down.to.point.bottomright.curvepath"
        case .prepNotReady: return "shippingbox"
        case .dynacap: return "slider.horizontal.3"
        case .scheduleQuality: return "calendar.badge.clock"
        case .pph: return "speedometer"
        case .pickerScorecard: return "person.2.fill"
        }
    }

    var sourceLink: URL? {
        switch self {
        case .fiveStar:
            return URL(string: "https://app.powerbi.com/groups/me/apps/d973ff03-651f-4e52-9e7a-8e5bff14b5e6/reports/73aafb1b-7a54-4c96-af93-4736442edc42/ReportSection5f4b54422e8bd962800c?experience=power-bi")
        case .pickerScorecard:
            return URL(string: "https://app.powerbi.com/groups/me/apps/d973ff03-651f-4e52-9e7a-8e5bff14b5e6/reports/7c59791f-78af-4257-8dde-c4f16b2017f0/9c54590ee447c7f3310b?experience=power-bi")
        case .pickPath:
            return URL(string: "https://app.powerbi.com/groups/b49dfeed-3984-42bf-82ef-d591fb235e2a/reports/b6400525-ba91-4f3d-bfba-3338a0b52fa7/ReportSection73f793f7ab37dd823bd7?experience=power-bi")
        case .pph:
            return URL(string: "https://app.powerbi.com/groups/me/apps/d973ff03-651f-4e52-9e7a-8e5bff14b5e6/reports/efe509e3-0bb6-4f54-9528-feb8fa1dc5fe/ReportSectionb4ac0532033cd00ce85a?experience=power-bi")
        default:
            return nil
        }
    }

    static var dashboardCards: [MetricSection] {
        [.fiveStar, .pickPath, .prepNotReady, .dynacap, .scheduleQuality, .pph, .pickerScorecard]
    }

    static var checklistSections: [MetricSection] {
        dashboardCards
    }
}

enum Health: String, Codable {
    case good, watch, risk, none

    var label: String {
        switch self {
        case .good: return "Healthy"
        case .watch: return "Watch"
        case .risk: return "At risk"
        case .none: return "No data"
        }
    }
}

struct MetricRow: Identifiable, Codable, Hashable {
    var id: UUID
    var section: MetricSection
    var division: String
    var operationsOM: String
    var storeNumber: String
    var storeName: String?
    var recordedOn: String?
    var payload: [String: Double]
    var textPayload: [String: String]

    init(
        id: UUID = UUID(),
        section: MetricSection,
        division: String,
        operationsOM: String,
        storeNumber: String,
        storeName: String? = nil,
        recordedOn: String? = nil,
        payload: [String: Double] = [:],
        textPayload: [String: String] = [:]
    ) {
        self.id = id
        self.section = section
        self.division = division
        self.operationsOM = operationsOM
        self.storeNumber = storeNumber
        self.storeName = storeName
        self.recordedOn = recordedOn
        self.payload = payload
        self.textPayload = textPayload
    }

    func number(_ keys: String...) -> Double? {
        for key in keys {
            if let value = payload[key] { return value }
        }
        return nil
    }

    var shopperName: String {
        let keys = ["shopper_name", "shopper", "picker", "pickername", "associate", "associatename"]
        for key in keys {
            if let value = textPayload[key], !value.isEmpty { return value }
        }
        return "Unknown shopper"
    }

    var shopperId: String? {
        let keys = ["shopper_id", "picker_id", "associate_id", "win"]
        for key in keys {
            if let value = textPayload[key], !value.isEmpty { return value }
        }
        return nil
    }

    var shopperKey: String {
        if let shopperId, !shopperId.isEmpty { return shopperId.lowercased() }
        return shopperName.lowercased()
    }

    var district: String { textPayload["district"] ?? "" }

    var omArea: String { textPayload["om_area"] ?? "" }
}

struct UploadRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var section: MetricSection
    var filename: String
    var rowCount: Int
    var uploadedAt: Date

    init(
        id: UUID = UUID(),
        section: MetricSection,
        filename: String,
        rowCount: Int,
        uploadedAt: Date = Date()
    ) {
        self.id = id
        self.section = section
        self.filename = filename
        self.rowCount = rowCount
        self.uploadedAt = uploadedAt
    }
}

struct SectionSummary: Identifiable {
    var section: MetricSection
    var storeCount: Int
    var headline: Double?
    var headlineLabel: String
    var secondary: String
    var health: Health
    var watchCount: Int
    var riskCount: Int
    var lastFilename: String?
    var lastUploadedAt: Date?

    var id: MetricSection { section }

    var headlineText: String {
        guard let headline else { return "—" }
        if section == .fiveStar {
            return String(format: "%.2f", headline)
        }
        if section == .pph || section == .dynacap {
            return String(format: "%.1f", headline)
        }
        if section == .pickerScorecard {
            return String(format: "%.0f", headline)
        }
        return String(format: "%.1f%%", headline)
    }
}

enum HeartbeatMath {
    static func latestPerStore(_ rows: [MetricRow]) -> [MetricRow] {
        var map: [String: MetricRow] = [:]
        for row in rows {
            let key = row.storeNumber.isEmpty
                ? "\(row.division)|\(row.operationsOM)|\(row.storeName ?? "")"
                : row.storeNumber
            if let existing = map[key] {
                if (row.recordedOn ?? "") > (existing.recordedOn ?? "") {
                    map[key] = row
                }
            } else {
                map[key] = row
            }
        }
        return map.values.sorted { HeartbeatFormat.storeOrder($0.storeNumber, $1.storeNumber) }
    }

    static func latestPerShopper(_ rows: [MetricRow]) -> [MetricRow] {
        var map: [String: MetricRow] = [:]
        for row in rows {
            let key = "\(row.storeNumber)|\(row.shopperKey)"
            if let existing = map[key] {
                if (row.recordedOn ?? "") > (existing.recordedOn ?? "") {
                    map[key] = row
                }
            } else {
                map[key] = row
            }
        }
        return map.values.sorted {
            if $0.storeNumber == $1.storeNumber { return $0.shopperName < $1.shopperName }
            return $0.storeNumber < $1.storeNumber
        }
    }

    static func filtered(_ rows: [MetricRow], division: String, district: String, om: String, store: String) -> [MetricRow] {
        filtered(rows, division: division, district: district, om: om, store: store, relaxUnknown: false, universe: nil)
    }

    static func filtered(
        _ rows: [MetricRow],
        division: String,
        district: String,
        om: String,
        store: String,
        relaxUnknown: Bool,
        universe: [MetricRow]? = nil
    ) -> [MetricRow] {
        let pool = universe ?? rows
        let roster = storeRoster(pool)
        let divisionStores = storeSet(in: pool, roster: roster, value: division, relax: relaxUnknown) { $0.division }
        let districtStores = storeSet(in: pool, roster: roster, value: district, relax: relaxUnknown) { $0.district }
        let omStores = storeSet(in: pool, roster: roster, value: om, relax: relaxUnknown) { $0.om }
        let storeFilter = usableFilter(store, in: pool.map(\.storeNumber), relax: relaxUnknown)

        return rows.filter { row in
            if let divisionStores, !belongs(row.storeNumber, to: divisionStores, identity: resolvedIdentity(row, roster: roster).division, value: division) {
                return false
            }
            if let districtStores, !belongs(row.storeNumber, to: districtStores, identity: resolvedIdentity(row, roster: roster).district, value: district) {
                return false
            }
            if let omStores, !belongs(row.storeNumber, to: omStores, identity: resolvedIdentity(row, roster: roster).om, value: om) {
                return false
            }
            if let storeFilter, !matches(row.storeNumber, storeFilter) { return false }
            return true
        }
    }

    private static func storeSet(
        in rows: [MetricRow],
        roster: [String: StoreIdentity],
        value: String,
        relax: Bool,
        field: (StoreIdentity) -> String
    ) -> Set<String>? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let hits = Set(rows.compactMap { row -> String? in
            let identity = resolvedIdentity(row, roster: roster)
            guard matches(field(identity), trimmed), !row.storeNumber.isEmpty else { return nil }
            return row.storeNumber
        })
        if hits.isEmpty { return relax ? nil : [] }
        return hits
    }

    private static func belongs(_ storeNumber: String, to stores: Set<String>, identity: String, value: String) -> Bool {
        if !storeNumber.isEmpty { return stores.contains(storeNumber) }
        return matches(identity, value)
    }

    static func usableFilter(_ value: String, in options: [String], relax: Bool) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if options.contains(where: { matches($0, trimmed) }) { return trimmed }
        return relax ? nil : trimmed
    }

    static func matches(_ lhs: String, _ rhs: String) -> Bool {
        normalize(lhs) == normalize(rhs)
    }

    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }

    struct StoreIdentity {
        var division: String
        var district: String
        var om: String
        var name: String?
    }

    struct MarketStore: Identifiable {
        var storeNumber: String
        var division: String
        var district: String
        var om: String
        var pph: Double?
        var compliance: Double?
        var id: String { storeNumber }
    }

    static func marketBoard(_ rows: [MetricRow], division: String, district: String, om: String, store: String) -> [MarketStore] {
        let matched = filtered(rows, division: division, district: district, om: om, store: store, relaxUnknown: false, universe: rows)
        let roster = storeRoster(rows)
        var pph: [String: Double] = [:]
        for row in latestPerStore(matched.filter { $0.section == .pph }) {
            guard !row.storeNumber.isEmpty, let value = row.number("pph") else { continue }
            pph[row.storeNumber] = value
        }
        var path: [String: Double] = [:]
        for row in latestPerStore(matched.filter { $0.section == .pickPath }) {
            guard !row.storeNumber.isEmpty, let value = row.number("compliance_pct") else { continue }
            path[row.storeNumber] = value
        }
        let stores = Set(matched.map(\.storeNumber).filter { !$0.isEmpty })
        return stores.sorted(by: HeartbeatFormat.storeOrder).map { number in
            let identity = roster[number] ?? StoreIdentity(division: "", district: "", om: "", name: nil)
            return MarketStore(
                storeNumber: number,
                division: identity.division,
                district: identity.district,
                om: identity.om,
                pph: pph[number],
                compliance: path[number]
            )
        }
    }

    static func canonicalStore(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let number = Int(trimmed) { return String(number) }
        return trimmed
    }

    static func storeRoster(_ rows: [MetricRow]) -> [String: StoreIdentity] {
        var map: [String: StoreIdentity] = [:]
        for row in rows {
            guard !row.storeNumber.isEmpty else { continue }
            let number = canonicalStore(row.storeNumber)
            var current = map[number] ?? StoreIdentity(division: "", district: "", om: "", name: nil)
            if current.division.isEmpty, !row.division.isEmpty { current.division = row.division }
            if current.district.isEmpty, !row.district.isEmpty { current.district = row.district }
            if current.om.isEmpty, !row.operationsOM.isEmpty { current.om = row.operationsOM }
            if current.name == nil, let name = row.storeName, !name.isEmpty { current.name = name }
            map[number] = current
        }
        return map
    }

    static func materializeDistrictMetric(_ rows: [MetricRow], roster: [String: StoreIdentity]) -> [MetricRow] {
        let byDistrict = Dictionary(rows.filter { !$0.district.isEmpty }.map { (normalize($0.district), $0) }, uniquingKeysWith: { _, latest in latest })
        var expanded: [MetricRow] = []
        for (number, identity) in roster {
            let key = normalize(identity.district)
            guard let source = byDistrict[key] else { continue }
            var text = source.textPayload
            text["district"] = identity.district
            expanded.append(
                MetricRow(
                    section: source.section,
                    division: identity.division,
                    operationsOM: identity.om,
                    storeNumber: number,
                    storeName: identity.name,
                    recordedOn: source.recordedOn,
                    payload: source.payload,
                    textPayload: text
                )
            )
        }
        if expanded.isEmpty {
            return rows.filter { $0.number("dynacap_rate", "pieces_per_hour") != nil || $0.number("pickup_capacity") != nil }
        }
        return expanded
    }

    static func remapSchedulePayload(_ payload: [String: Double]) -> [String: Double] {
        var out = payload
        func take(matching: (String) -> Bool, as key: String) {
            if out[key] != nil { return }
            guard let found = out.first(where: { matching($0.key) }) else { return }
            var value = found.value
            if value <= 1.5 { value *= 100 }
            out[key] = value
        }
        take(matching: { $0.contains("underschedule") }, as: "under_schedule_pct")
        take(matching: { $0.contains("overschedule") }, as: "over_schedule_pct")
        take(matching: { $0.contains("scheduleeffic") }, as: "schedule_efficiency_pct")
        take(matching: { $0.contains("scheduleadherence") }, as: "schedule_adherence_pct")
        take(matching: { $0.contains("underadherence") }, as: "under_adherence_pct")
        take(matching: { $0.contains("overadherence") }, as: "over_adherence_pct")
        take(matching: { $0.contains("understaffing") }, as: "under_staffing_pct")
        take(matching: { $0.contains("overstaffing") }, as: "over_staffing_pct")
        take(matching: { $0.contains("staffingeffic") }, as: "staffing_efficiency_pct")
        return out
    }

    static func applyRoster(_ rows: [MetricRow], roster: [String: StoreIdentity]) -> [MetricRow] {
        rows.map { row in
            let number = canonicalStore(row.storeNumber)
            let known = roster[number]
            var text = row.textPayload
            if let district = known?.district, !district.isEmpty {
                text["district"] = district
            }
            return MetricRow(
                section: row.section,
                division: known?.division.isEmpty == false ? known!.division : row.division,
                operationsOM: known?.om.isEmpty == false ? known!.om : row.operationsOM,
                storeNumber: number,
                storeName: row.storeName ?? known?.name,
                recordedOn: row.recordedOn,
                payload: remapSchedulePayload(row.payload),
                textPayload: text
            )
        }
    }

    static func resolvedIdentity(_ row: MetricRow, roster: [String: StoreIdentity]) -> StoreIdentity {
        let known = roster[canonicalStore(row.storeNumber)]
        return StoreIdentity(
            division: row.division.isEmpty ? (known?.division ?? "") : row.division,
            district: row.district.isEmpty ? (known?.district ?? "") : row.district,
            om: row.operationsOM.isEmpty ? (known?.om ?? "") : row.operationsOM,
            name: row.storeName ?? known?.name
        )
    }

    static func health(for section: MetricSection, row: MetricRow) -> Health {
        switch section {
        case .fiveStar:
            return fiveStarHealth(row)
        case .pickPath:
            guard row.number("compliance_pct") != nil else { return .none }
            return band(row.number("compliance_pct"), good: pickPathGoal, watch: pickPathRisk)
        case .prepNotReady:
            return band(row.number("pnr_rate_pct"), good: pnrGoal, watch: pnrWatch, invert: true)
        case .dynacap:
            if let rate = row.number("dynacap_rate", "pieces_per_hour") {
                return band(rate, good: dynacapGoal, watch: dynacapRisk)
            }
            guard let aligned = dynacapAligned(row) else { return .none }
            return aligned ? .good : .risk
        case .scheduleQuality:
            return scheduleHealth(row)
        case .pph:
            return pphHealth(row)
        case .pickerScorecard:
            return pickerHealth(row)
        }
    }

    static func dynacapAligned(_ row: MetricRow) -> Bool? {
        guard
            let pickup = row.number("pickup_capacity"),
            let delivery = row.number("delivery_capacity"),
            let recPickup = row.number("rec_pickup"),
            let recDelivery = row.number("rec_delivery")
        else { return nil }
        return near(pickup, recPickup) && near(delivery, recDelivery)
    }

    static func summarize(_ section: MetricSection, rows: [MetricRow], upload: UploadRecord?) -> SectionSummary {
        let latest = section == .pickerScorecard ? latestPerShopper(rows) : latestPerStore(rows)
        let watch = latest.filter { health(for: section, row: $0) == .watch }.count
        let risk = latest.filter { health(for: section, row: $0) == .risk }.count

        switch section {
        case .fiveStar:
            let headline = average(latest.compactMap { $0.number("star_rating") })
            let five = latest.filter { ($0.number("star_rating") ?? 0) >= 4.95 }.count
            let pass = latest.filter { ($0.number("star_rating") ?? 0) >= fiveStarPass }.count
            let fail = latest.filter { ($0.number("star_rating") ?? .greatestFiniteMagnitude) < fiveStarPass }.count
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: headline,
                headlineLabel: "Avg star rating",
                secondary: latest.isEmpty
                    ? "No 5 Star rows in this filter"
                    : "\(five) of \(latest.count) at 5.00 · \(pass) pass · \(fail) fail",
                health: latest.isEmpty ? .none : band(headline, good: 4.5, watch: fiveStarPass),
                watchCount: watch,
                riskCount: risk,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt
            )
        case .pickPath:
            let headline = average(latest.compactMap { $0.number("compliance_pct") })
            let atGoal = latest.filter { ($0.number("compliance_pct") ?? 0) >= pickPathGoal }.count
            let atRisk = latest.filter { ($0.number("compliance_pct") ?? .greatestFiniteMagnitude) < pickPathRisk }.count
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: headline,
                headlineLabel: "Avg compliance",
                secondary: latest.isEmpty
                    ? "No Pick Path rows in this filter"
                    : "\(atGoal) of \(latest.count) at 90% · \(atRisk) below 80%",
                health: latest.isEmpty ? .none : band(headline, good: pickPathGoal, watch: pickPathRisk),
                watchCount: watch,
                riskCount: risk,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt
            )
        case .prepNotReady:
            let headline = average(latest.compactMap { $0.number("pnr_rate_pct") })
            let atGoal = latest.filter { ($0.number("pnr_rate_pct") ?? .greatestFiniteMagnitude) <= pnrGoal }.count
            let atRisk = latest.filter { ($0.number("pnr_rate_pct") ?? 0) > pnrWatch }.count
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: headline,
                headlineLabel: "Avg PNR hours",
                secondary: latest.isEmpty
                    ? "No Prep Not Ready rows in this filter"
                    : "\(atGoal) of \(latest.count) at 1.9% · \(atRisk) above 2.5%",
                health: latest.isEmpty ? .none : band(headline, good: pnrGoal, watch: pnrWatch, invert: true),
                watchCount: watch,
                riskCount: risk,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt
            )
        case .dynacap:
            let headline = average(latest.compactMap { $0.number("dynacap_rate", "pieces_per_hour") })
            let atGoal = latest.filter { ($0.number("dynacap_rate", "pieces_per_hour") ?? 0) >= dynacapGoal }.count
            let atRisk = latest.filter { ($0.number("dynacap_rate", "pieces_per_hour") ?? .greatestFiniteMagnitude) < dynacapRisk }.count
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: headline,
                headlineLabel: "Avg pieces / hour",
                secondary: latest.isEmpty
                    ? "No Dynacap rows in this filter"
                    : "\(atGoal) of \(latest.count) at 65 · \(atRisk) below 60",
                health: latest.isEmpty ? .none : band(headline, good: dynacapGoal, watch: dynacapRisk),
                watchCount: watch,
                riskCount: risk,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt
            )
        case .scheduleQuality:
            let headline = average(latest.compactMap { $0.number("schedule_efficiency_pct") })
            let atGoal = latest.filter { ($0.number("schedule_efficiency_pct") ?? 0) >= scheduleGoal }.count
            let underRisk = latest.filter { ($0.number("under_schedule_pct", "under_scheduled") ?? 0) > scheduleVarianceWatch }.count
            let overRisk = latest.filter { ($0.number("over_schedule_pct", "over_scheduled") ?? 0) > scheduleVarianceWatch }.count
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: headline,
                headlineLabel: "Avg schedule efficiency",
                secondary: latest.isEmpty
                    ? "No Schedule rows in this filter"
                    : "\(atGoal) of \(latest.count) at 90% · \(underRisk) under risk · \(overRisk) over risk",
                health: latest.isEmpty ? .none : band(headline, good: scheduleGoal, watch: scheduleWatch),
                watchCount: watch,
                riskCount: risk,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt
            )
        case .pph:
            let headline = average(latest.compactMap { $0.number("pph") })
            let atGoal = latest.filter { ($0.number("pph") ?? 0) >= pphGoal }.count
            let atRisk = latest.filter { ($0.number("pph") ?? .greatestFiniteMagnitude) < pphRisk }.count
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: headline,
                headlineLabel: "Avg pure PPH",
                secondary: latest.isEmpty
                    ? "No stores in view"
                    : "\(atGoal) of \(latest.count) at 80 · \(atRisk) below 74",
                health: band(headline, good: pphGoal, watch: pphRisk),
                watchCount: watch,
                riskCount: risk,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt
            )
        case .pickerScorecard:
            let board = pickerBoard(latest)
            return SectionSummary(
                section: section,
                storeCount: Set(latest.map(\.storeNumber)).count,
                headline: Double(board.opportunityCount),
                headlineLabel: "Opportunity pickers",
                secondary: latest.isEmpty
                    ? "No shoppers in view"
                    : "\(board.strongCount) doing well · \(board.shopperCount) shoppers",
                health: band(
                    latest.isEmpty ? nil : (1 - Double(board.opportunityCount) / Double(max(board.shopperCount, 1))) * 100,
                    good: 80,
                    watch: 65
                ),
                watchCount: 0,
                riskCount: board.opportunityCount,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt
            )
        }
    }

    static let pnrGoal = 1.9
    static let pnrWatch = 2.5
    static let pphGoal = 80.0
    static let pphRisk = 74.0
    static let pickPathGoal = 90.0
    static let pickPathRisk = 80.0
    static let dynacapGoal = 65.0
    static let dynacapRisk = 60.0
    static let scheduleGoal = 90.0
    static let scheduleWatch = 85.0
    static let scheduleVarianceWatch = 5.0
    static let fiveStarGoal = 5.0
    static let fiveStarPass = 4.0

    enum StarMark: Double {
        case none = 0
        case half = 0.5
        case full = 1

        var health: Health {
            switch self {
            case .full: return .good
            case .half: return .watch
            case .none: return .risk
            }
        }

        var label: String {
            switch self {
            case .full: return "Full"
            case .half: return "½"
            case .none: return "None"
            }
        }
    }

    static func fiveStarHealth(_ row: MetricRow) -> Health {
        band(row.number("star_rating"), good: 4.5, watch: fiveStarPass)
    }

    static func starMark(value: Double?, full: Double, half: Double, invert: Bool = false) -> StarMark {
        guard let value else { return .none }
        if invert {
            if value < full { return .full }
            if value <= half { return .half }
            return .none
        }
        if value >= full { return .full }
        if value >= half { return .half }
        return .none
    }

    static func componentStar(_ row: MetricRow, starKey: String, pctKey: String, full: Double, half: Double, invert: Bool = false) -> StarMark {
        if let star = row.number(starKey) {
            if star >= 0.75 { return .full }
            if star >= 0.25 { return .half }
            return .none
        }
        return starMark(value: row.number(pctKey), full: full, half: half, invert: invert)
    }

    static func flashStar(_ row: MetricRow) -> StarMark {
        componentStar(row, starKey: "flash_star", pctKey: "flash_pct", full: 75, half: 55)
    }

    static func presubStar(_ row: MetricRow) -> StarMark {
        componentStar(row, starKey: "presub_star", pctKey: "presub_pct", full: 5, half: 6, invert: true)
    }

    static func coeStar(_ row: MetricRow) -> StarMark {
        componentStar(row, starKey: "coe_star", pctKey: "coe_pct", full: 20, half: 0)
    }

    static func ottStar(_ row: MetricRow) -> StarMark {
        componentStar(row, starKey: "ott_star", pctKey: "ott_pct", full: 95, half: 90)
    }

    static func othStar(_ row: MetricRow) -> StarMark {
        componentStar(row, starKey: "oth5_star", pctKey: "oth5_pct", full: 92, half: 78)
    }

    static func varianceHealth(_ pct: Double?) -> Health {
        guard let pct else { return .none }
        if pct <= 0.05 { return .good }
        if pct <= scheduleVarianceWatch { return .watch }
        return .risk
    }

    static func scheduleHealth(_ row: MetricRow) -> Health {
        let under = varianceHealth(row.number("under_schedule_pct", "under_scheduled"))
        let over = varianceHealth(row.number("over_schedule_pct", "over_scheduled"))
        let efficiency = band(row.number("schedule_efficiency_pct"), good: scheduleGoal, watch: scheduleWatch)
        let ranks: [Health: Int] = [.none: 0, .good: 1, .watch: 2, .risk: 3]
        return [under, over, efficiency].max { (ranks[$0] ?? 0) < (ranks[$1] ?? 0) } ?? .watch
    }

    static func pphHealth(_ row: MetricRow) -> Health {
        band(row.number("pph"), good: pphGoal, watch: pphRisk)
    }

    static func pickerHasVolume(_ row: MetricRow) -> Bool {
        (row.number("pick_hours") ?? 0) >= 1 || (row.number("orders") ?? 0) >= 5
    }

    static func isRealPicker(_ row: MetricRow) -> Bool {
        let name = row.shopperName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return false }
        if name.localizedCaseInsensitiveContains("unknown") { return false }
        let store = row.storeNumber
        if store.localizedCaseInsensitiveContains("filter") { return false }
        if store.localizedCaseInsensitiveContains("WEEK") { return false }
        return true
    }

    static func pickerMatches(_ row: MetricRow, focus: PickerFocus) -> Bool {
        guard isRealPicker(row) else { return false }
        switch focus {
        case .all:
            return true
        case .opportunity:
            return pickerHasVolume(row) && pickerHealth(row) != .good
        case .strong:
            return pickerHasVolume(row) && pickerHealth(row) == .good
        case .ott:
            return row.number("ott_pct") != nil && ottStar(row).health != .good
        case .presub:
            return row.number("presub_pct") != nil && presubStar(row).health != .good
        case .oth:
            return row.number("oth5_pct") != nil && othStar(row).health != .good
        case .coe:
            return row.number("coe_pct") != nil && coeStar(row).health != .good
        case .pph:
            return row.number("pph") != nil && pphHealth(row) != .good
        }
    }

    static func pickerFlags(_ row: MetricRow) -> [(name: String, health: Health)] {
        var flags: [(String, Health)] = []
        if row.number("pph") != nil {
            flags.append(("PPH", pphHealth(row)))
        }
        if row.number("presub_pct") != nil {
            flags.append(("Presub", starMark(value: row.number("presub_pct"), full: 5, half: 6, invert: true).health))
        }
        if row.number("oth5_pct") != nil {
            flags.append(("OTH", othStar(row).health))
        }
        if row.number("coe_pct") != nil {
            flags.append(("COE", coeStar(row).health))
        }
        if row.number("ott_pct") != nil {
            flags.append(("OTT", ottStar(row).health))
        }
        if flags.isEmpty, row.number("compliance_pct") != nil {
            flags.append(("Path", band(row.number("compliance_pct"), good: pickPathGoal, watch: pickPathRisk)))
        }
        return flags
    }

    static func pickerOpportunityText(_ row: MetricRow) -> String {
        let weak = pickerFlags(row).filter { $0.health == .risk || $0.health == .watch }.map(\.name)
        return weak.isEmpty ? "On track" : weak.joined(separator: " · ")
    }

    static func pickerMetricReadout(_ row: MetricRow) -> [(name: String, value: String, health: Health)] {
        var items: [(String, String, Health)] = []
        if row.number("pph") != nil {
            items.append(("PPH", HeartbeatFormat.num(row.number("pph"), digits: 1), pphHealth(row)))
        }
        if row.number("presub_pct") != nil {
            items.append(("Presub", HeartbeatFormat.pct(row.number("presub_pct")), starMark(value: row.number("presub_pct"), full: 5, half: 6, invert: true).health))
        }
        if row.number("oth5_pct") != nil {
            items.append(("OTH", HeartbeatFormat.pct(row.number("oth5_pct")), othStar(row).health))
        }
        if row.number("coe_pct") != nil {
            items.append(("COE", HeartbeatFormat.pct(row.number("coe_pct")), coeStar(row).health))
        }
        if row.number("ott_pct") != nil {
            items.append(("OTT", HeartbeatFormat.pct(row.number("ott_pct")), ottStar(row).health))
        }
        return items
    }

    static func pickerComposite(_ row: MetricRow) -> Double {
        var parts: [Double] = []
        if let pph = row.number("pph") {
            parts.append(min(max(pph / pphGoal, 0), 1.15) / 1.15)
        }
        if let presub = row.number("presub_pct") {
            parts.append(min(max(1 - presub / 6, 0), 1))
        }
        if let oth = row.number("oth5_pct") {
            parts.append(min(max(oth / 92, 0), 1))
        }
        if let coe = row.number("coe_pct") {
            parts.append(min(max((coe + 20) / 40, 0), 1))
        }
        if let ott = row.number("ott_pct") {
            parts.append(min(max(ott / 95, 0), 1))
        }
        if parts.isEmpty {
            if let compliance = row.number("compliance_pct") {
                parts.append(min(compliance / 100, 1))
            }
            if let quality = row.number("quality_score") {
                parts.append(quality > 5 ? min(quality / 100, 1) : min(quality / 5, 1))
            }
        }
        guard !parts.isEmpty else { return 0 }
        return parts.reduce(0, +) / Double(parts.count)
    }

    static func pickerHealth(_ row: MetricRow) -> Health {
        let flags = pickerFlags(row)
        if flags.contains(where: { $0.health == .risk }) { return .risk }
        if flags.contains(where: { $0.health == .watch }) { return .watch }
        if flags.contains(where: { $0.health == .good }) { return .good }
        return .none
    }

    struct PickerBoard {
        var shopperCount: Int
        var opportunityCount: Int
        var strongCount: Int
        var opportunity: [MetricRow]
        var strong: [MetricRow]
    }

    struct PickerMetricBoard: Identifiable, Equatable {
        var metric: String
        var rows: [MetricRow]
        var id: String { metric }
    }

    static func pickerBoard(_ rows: [MetricRow], limit: Int = 6) -> PickerBoard {
        var opportunity: [(score: Double, row: MetricRow)] = []
        var strong: [(score: Double, row: MetricRow)] = []
        var opportunityCount = 0
        var strongCount = 0
        for row in rows {
            guard pickerHasVolume(row) else { continue }
            let health = pickerHealth(row)
            guard health != .none else { continue }
            let score = pickerComposite(row)
            if health == .good {
                strongCount += 1
                keepTop(&strong, score: score, row: row, limit: limit, lowest: false)
            } else {
                opportunityCount += 1
                keepTop(&opportunity, score: score, row: row, limit: limit, lowest: true)
            }
        }
        return PickerBoard(
            shopperCount: rows.count,
            opportunityCount: opportunityCount,
            strongCount: strongCount,
            opportunity: opportunity.map(\.row),
            strong: strong.map(\.row)
        )
    }

    private static func keepTop(_ bucket: inout [(score: Double, row: MetricRow)], score: Double, row: MetricRow, limit: Int, lowest: Bool) {
        if bucket.count < limit {
            bucket.append((score, row))
            if bucket.count == limit {
                bucket.sort { lowest ? $0.score < $1.score : $0.score > $1.score }
            }
            return
        }
        let edge = bucket[limit - 1].score
        let better = lowest ? score < edge : score > edge
        guard better else { return }
        bucket[limit - 1] = (score, row)
        bucket.sort { lowest ? $0.score < $1.score : $0.score > $1.score }
    }

    static func opportunitySortValue(section: MetricSection, row: MetricRow) -> Double {
        switch section {
        case .fiveStar:
            return -(row.number("star_rating") ?? 99)
        case .pickPath:
            return -(row.number("compliance_pct") ?? 999)
        case .prepNotReady:
            return row.number("pnr_rate_pct") ?? 0
        case .dynacap:
            return -(row.number("dynacap_rate") ?? 999)
        case .scheduleQuality:
            let under = row.number("under_schedule_pct") ?? 0
            let over = row.number("over_schedule_pct") ?? 0
            let miss = max(0, scheduleGoal - (row.number("schedule_efficiency_pct") ?? scheduleGoal))
            return max(under, over) + miss
        case .pph:
            return -(row.number("pph") ?? 999)
        case .pickerScorecard:
            return -pickerComposite(row)
        }
    }

    static func topOpportunityStores(section: MetricSection, rows: [MetricRow], limit: Int = 10) -> [MetricRow] {
        rows
            .filter {
                let health = health(for: section, row: $0)
                return health == .risk || health == .watch
            }
            .sorted { opportunitySortValue(section: section, row: $0) > opportunitySortValue(section: section, row: $1) }
            .prefix(limit)
            .map { $0 }
    }

    static func topPickersByMetric(_ rows: [MetricRow], limit: Int = 10) -> [PickerMetricBoard] {
        var pph: [(score: Double, row: MetricRow)] = []
        var presub: [(score: Double, row: MetricRow)] = []
        var oth: [(score: Double, row: MetricRow)] = []
        var coe: [(score: Double, row: MetricRow)] = []
        var ott: [(score: Double, row: MetricRow)] = []
        for row in rows {
            guard pickerHasVolume(row) else { continue }
            if let value = row.number("pph") {
                let health = pphHealth(row)
                if health == .risk || health == .watch {
                    keepTop(&pph, score: value, row: row, limit: limit, lowest: true)
                }
            }
            if let value = row.number("presub_pct") {
                let health = starMark(value: value, full: 5, half: 6, invert: true).health
                if health == .risk || health == .watch {
                    keepTop(&presub, score: value, row: row, limit: limit, lowest: false)
                }
            }
            if let value = row.number("oth5_pct") {
                let health = othStar(row).health
                if health == .risk || health == .watch {
                    keepTop(&oth, score: value, row: row, limit: limit, lowest: true)
                }
            }
            if let value = row.number("coe_pct") {
                let health = coeStar(row).health
                if health == .risk || health == .watch {
                    keepTop(&coe, score: value, row: row, limit: limit, lowest: true)
                }
            }
            if let value = row.number("ott_pct") {
                let health = ottStar(row).health
                if health == .risk || health == .watch {
                    keepTop(&ott, score: value, row: row, limit: limit, lowest: true)
                }
            }
        }
        return [
            PickerMetricBoard(metric: "PPH", rows: pph.map(\.row)),
            PickerMetricBoard(metric: "Presub", rows: presub.map(\.row)),
            PickerMetricBoard(metric: "OTH", rows: oth.map(\.row)),
            PickerMetricBoard(metric: "COE", rows: coe.map(\.row)),
            PickerMetricBoard(metric: "OTT", rows: ott.map(\.row)),
        ].filter { !$0.rows.isEmpty }
    }

    static func band(_ value: Double?, good: Double, watch: Double, invert: Bool = false) -> Health {
        guard let value else { return .watch }
        if invert {
            if value <= good { return .good }
            if value <= watch { return .watch }
            return .risk
        }
        if value >= good { return .good }
        if value >= watch { return .watch }
        return .risk
    }

    static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func near(_ actual: Double, _ rec: Double) -> Bool {
        if rec == 0 { return actual == 0 }
        return abs(actual - rec) / rec <= 0.1
    }

    static func history(_ section: MetricSection, rows: [MetricRow]) -> [HistoryPoint] {
        var buckets: [String: [Double]] = [:]
        for row in rows {
            guard let date = row.recordedOn else { continue }
            let value: Double?
            switch section {
            case .fiveStar: value = row.number("star_rating")
            case .pickPath: value = row.number("compliance_pct")
            case .prepNotReady: value = row.number("pnr_rate_pct")
            case .dynacap:
                value = row.number("dynacap_rate", "pieces_per_hour")
            case .scheduleQuality:
                value = row.number("schedule_efficiency_pct")
            case .pph:
                value = row.number("pph")
            case .pickerScorecard:
                value = pickerComposite(row)
            }
            guard let value else { continue }
            buckets[date, default: []].append(value)
        }
        return buckets.keys.sorted().compactMap { date in
            guard let values = buckets[date], !values.isEmpty else { return nil }
            return HistoryPoint(date: date, value: values.reduce(0, +) / Double(values.count))
        }
    }
}

struct HistoryPoint: Identifiable, Hashable {
    var date: String
    var value: Double
    var id: String { date }
}

enum ChecklistStatus: String, Codable, CaseIterable, Identifiable {
    case open
    case addressed
    case followUp
    case notCovered

    var id: String { rawValue }

    var label: String {
        switch self {
        case .open: return "Open"
        case .addressed: return "Addressed"
        case .followUp: return "Follow Up Needed"
        case .notCovered: return "Not Covered"
        }
    }

    var isClosed: Bool { self != .open }

    var shortLabel: String {
        switch self {
        case .open: return "Open"
        case .addressed: return "Done"
        case .followUp: return "Follow up"
        case .notCovered: return "Skip"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "fixed", "addressed": self = .addressed
        case "followUp": self = .followUp
        case "notCovered": self = .notCovered
        default: self = .open
        }
    }
}

struct ChecklistItem: Identifiable, Codable, Hashable {
    var id: String
    var status: ChecklistStatus
    var comment: String
    var updatedAt: Date?

    init(
        id: String,
        status: ChecklistStatus = .open,
        comment: String = "",
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.status = status
        self.comment = comment
        self.updatedAt = updatedAt
    }
}

struct ChecklistFile: Codable {
    var items: [String: ChecklistItem]
    var recipients: [String]
}

struct ChecklistDriverItem: Identifiable, Equatable {
    var id: String
    var title: String
    var subtitle: String
    var value: String
    var health: Health
}

struct ChecklistDriverGroup: Identifiable, Equatable {
    var title: String
    var items: [ChecklistDriverItem]
    var id: String { title }
}

struct DashboardFilters: Equatable, Codable {
    var division = ""
    var district = ""
    var om = ""
    var store = ""

    var isActive: Bool {
        !division.isEmpty || !district.isEmpty || !om.isEmpty || !store.isEmpty
    }

    var summary: String {
        [
            division.isEmpty ? "All divisions" : division,
            district.isEmpty ? "All districts" : "District \(district)",
            om.isEmpty ? "All OMs" : om,
            store.isEmpty ? "All stores" : store,
        ].joined(separator: " · ")
    }

    enum CodingKeys: String, CodingKey { case division, district, om, store }

    init() {}

    init(division: String, district: String, om: String, store: String) {
        self.division = division
        self.district = district
        self.om = om
        self.store = store
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        division = try c.decodeIfPresent(String.self, forKey: .division) ?? ""
        district = try c.decodeIfPresent(String.self, forKey: .district) ?? ""
        om = try c.decodeIfPresent(String.self, forKey: .om) ?? ""
        store = try c.decodeIfPresent(String.self, forKey: .store) ?? ""
    }
}

struct HeartbeatSnapshot: Codable {
    var rows: [MetricRow]
    var uploads: [UploadRecord]
    var seeded: Bool
    var filters: DashboardFilters
}

enum HeartbeatFormat {
    static func divisionLabel(_ value: String) -> String {
        value
    }

    static func storeOrder(_ lhs: String, _ rhs: String) -> Bool {
        if let a = Int(lhs), let b = Int(rhs) { return a < b }
        return lhs.localizedStandardCompare(rhs) == .orderedAscending
    }

    static func stars(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f", value)
    }

    static func pct(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f%%", value)
    }

    static func num(_ value: Double?, digits: Int = 0) -> String {
        guard let value else { return "—" }
        if digits == 0 {
            return NumberFormatter.localizedString(from: NSNumber(value: value.rounded()), number: .decimal)
        }
        return String(format: "%.\(digits)f", value)
    }

    static func headline(_ summary: SectionSummary) -> String {
        summary.headlineText
    }

    static func relative(_ date: Date?) -> String {
        guard let date else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func stamp(_ date: Date?) -> String {
        guard let date else { return "No data" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy · h:mm a"
        return formatter.string(from: date)
    }

    static func updated(_ date: Date?) -> String {
        guard let date else { return "No data" }
        return "Updated \(stamp(date))"
    }
}

struct StoreCellViewModel {
    var primary: String
    var extra: String

    static func make(section: MetricSection, row: MetricRow) -> StoreCellViewModel {
        switch section {
        case .fiveStar:
            let parts = [
                "Flash \(HeartbeatMath.flashStar(row).label)",
                "Presub \(HeartbeatMath.presubStar(row).label)",
                "COE \(HeartbeatMath.coeStar(row).label)",
                "OTT \(HeartbeatMath.ottStar(row).label)",
                "OTH \(HeartbeatMath.othStar(row).label)",
            ]
            return StoreCellViewModel(
                primary: HeartbeatFormat.stars(row.number("star_rating")),
                extra: parts.joined(separator: " · ")
            )
        case .pickPath:
            let compliance = row.number("compliance_pct")
            let gap = compliance.map { $0 - HeartbeatMath.pickPathGoal }
            let gapText: String
            if let gap {
                gapText = gap >= 0
                    ? "+\(HeartbeatFormat.num(gap, digits: 1)) vs 90"
                    : "\(HeartbeatFormat.num(gap, digits: 1)) vs 90"
            } else {
                gapText = "Not in Pick Path file"
            }
            let orders = row.number("orders") ?? row.number("picks_total")
            let pph = row.number("pph")
            let extra: String
            if let orders, let pph {
                extra = "\(gapText) · \(HeartbeatFormat.num(orders)) orders · PPH \(HeartbeatFormat.num(pph, digits: 1))"
            } else if let orders {
                extra = "\(gapText) · \(HeartbeatFormat.num(orders)) orders"
            } else {
                extra = gapText
            }
            return StoreCellViewModel(
                primary: HeartbeatFormat.pct(compliance),
                extra: extra
            )
        case .prepNotReady:
            let rate = row.number("pnr_rate_pct")
            let gap = rate.map { $0 - HeartbeatMath.pnrGoal }
            let gapText: String
            if let gap {
                gapText = gap <= 0
                    ? "\(HeartbeatFormat.num(abs(gap), digits: 1)) under 1.9%"
                    : "+\(HeartbeatFormat.num(gap, digits: 1)) vs 1.9%"
            } else {
                gapText = "Goal 1.9%"
            }
            return StoreCellViewModel(
                primary: HeartbeatFormat.pct(rate),
                extra: gapText
            )
        case .dynacap:
            let rate = row.number("dynacap_rate", "pieces_per_hour")
            let gap = rate.map { $0 - HeartbeatMath.dynacapGoal }
            let gapText: String
            if let gap {
                gapText = gap >= 0
                    ? "+\(HeartbeatFormat.num(gap, digits: 1)) vs 65"
                    : "\(HeartbeatFormat.num(gap, digits: 1)) vs 65"
            } else if HeartbeatMath.dynacapAligned(row) != nil {
                let aligned = HeartbeatMath.dynacapAligned(row)
                return StoreCellViewModel(
                    primary: aligned == true ? "Aligned" : "Off rec",
                    extra: "PU \(HeartbeatFormat.num(row.number("pickup_capacity"))) / \(HeartbeatFormat.num(row.number("rec_pickup")))"
                )
            } else {
                gapText = "Not in Dynacap file"
            }
            let util = row.number("utilization_pct")
            let extra = util == nil ? gapText : "\(gapText) · Util \(HeartbeatFormat.pct(util))"
            return StoreCellViewModel(
                primary: HeartbeatFormat.num(rate, digits: 1),
                extra: extra
            )
        case .scheduleQuality:
            let efficiency = row.number("schedule_efficiency_pct")
            let under = row.number("under_schedule_pct", "under_scheduled")
            let over = row.number("over_schedule_pct", "over_scheduled")
            return StoreCellViewModel(
                primary: HeartbeatFormat.pct(efficiency),
                extra: "Under \(HeartbeatFormat.pct(under)) · Over \(HeartbeatFormat.pct(over))"
            )
        case .pph:
            let pph = row.number("pph")
            let gap = pph.map { $0 - HeartbeatMath.pphGoal }
            let gapText: String
            if let gap {
                gapText = gap >= 0
                    ? "+\(HeartbeatFormat.num(gap, digits: 1)) vs 80"
                    : "\(HeartbeatFormat.num(gap, digits: 1)) vs 80"
            } else {
                gapText = "Goal 80"
            }
            return StoreCellViewModel(
                primary: HeartbeatFormat.num(pph, digits: 1),
                extra: gapText
            )
        case .pickerScorecard:
            return StoreCellViewModel(
                primary: HeartbeatFormat.num(row.number("pph"), digits: 1),
                extra: HeartbeatMath.pickerOpportunityText(row)
            )
        }
    }
}

enum PickerFocus: String, CaseIterable, Identifiable {
    case all
    case opportunity
    case strong
    case ott
    case presub
    case oth
    case coe
    case pph

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All Shoppers"
        case .opportunity: return "Opportunity"
        case .strong: return "Doing Well"
        case .ott: return "OTT"
        case .presub: return "Presub"
        case .oth: return "OTH"
        case .coe: return "COE"
        case .pph: return "PPH"
        }
    }
}

enum PickerSort: String, CaseIterable, Identifiable {
    case pph, name, store
    var id: String { rawValue }

    var title: String {
        switch self {
        case .pph: return "PPH"
        case .name: return "Picker"
        case .store: return "Store"
        }
    }
}

