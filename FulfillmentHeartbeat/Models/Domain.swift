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
        case .pickerScorecard: return "Picker Score Card"
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
        case .fiveStar: return "Composite star rating and the four drivers behind it."
        case .pickPath: return "Share of picks that followed the system path. Upload the All Pickers WEEK_ID export."
        case .prepNotReady: return "Orders not staged by the promised ready time."
        case .dynacap: return "Pickup and delivery capacity versus recommended."
        case .scheduleQuality: return "How tightly the labor plan matches the work — efficiency, over, and under."
        case .pph: return "Pure picks completed per labor hour. Upload the WEEK_ID by Division export."
        case .pickerScorecard: return "Shopper-level PPH, path, and quality — opportunity versus strong."
        }
    }

    var expectedMetrics: String {
        switch self {
        case .fiveStar: return "Star Rating · OTP % · Fill Rate · Quality · CX"
        case .pickPath: return "WEEK_ID · DIVISION · DISTRICT · OM · STORE_ID · EMPLOYEE · Pick Path · Orders · Pure PPH"
        case .prepNotReady: return "PNR Count · Orders Due · PNR Rate · Avg Late Min"
        case .dynacap: return "Pickup / Delivery capacity · Rec pickup / delivery"
        case .scheduleQuality: return "Schedule Efficiency · Over Scheduled · Under Scheduled"
        case .pph: return "WEEK_ID · DIVISION · DISTRICT · OM_AREA · OM_ID · STORE · Pure PPH"
        case .pickerScorecard: return "Shopper · PPH · Pick Path % · Quality · Goal PPH"
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

    static var dashboardCards: [MetricSection] {
        [.fiveStar, .pickPath, .prepNotReady, .dynacap, .scheduleQuality, .pph]
    }
}

enum Health: String, Codable {
    case good, watch, risk

    var label: String {
        switch self {
        case .good: return "Healthy"
        case .watch: return "Watch"
        case .risk: return "At risk"
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
        if section == .pph {
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
        rows.filter { row in
            if !division.isEmpty, row.division != division { return false }
            if !district.isEmpty, row.district != district { return false }
            if !om.isEmpty, row.operationsOM != om { return false }
            if !store.isEmpty, row.storeNumber != store { return false }
            return true
        }
    }

    static func health(for section: MetricSection, row: MetricRow) -> Health {
        switch section {
        case .fiveStar:
            return band(row.number("star_rating"), good: 4.5, watch: 4.0)
        case .pickPath:
            return band(row.number("compliance_pct"), good: pickPathGoal, watch: pickPathRisk)
        case .prepNotReady:
            return band(row.number("pnr_rate_pct"), good: 2, watch: 5, invert: true)
        case .dynacap:
            guard let aligned = dynacapAligned(row) else { return .watch }
            return aligned ? .good : .risk
        case .scheduleQuality:
            return band(row.number("schedule_efficiency_pct"), good: 95, watch: 88)
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
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: headline,
                headlineLabel: "Avg star rating",
                secondary: latest.isEmpty ? "No stores in view" : "\(five) of \(latest.count) at 5.00",
                health: band(headline, good: 4.5, watch: 4.0),
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
                    ? "No stores in view"
                    : "\(atGoal) of \(latest.count) at 90% · \(atRisk) below 80%",
                health: band(headline, good: pickPathGoal, watch: pickPathRisk),
                watchCount: watch,
                riskCount: risk,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt
            )
        case .prepNotReady:
            let headline = average(latest.compactMap { $0.number("pnr_rate_pct") })
            let total = latest.reduce(0) { $0 + ($1.number("pnr_count") ?? 0) }
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: headline,
                headlineLabel: "Avg PNR rate",
                secondary: latest.isEmpty ? "No stores in view" : "\(Int(total.rounded())) orders not ready",
                health: band(headline, good: 2, watch: 5, invert: true),
                watchCount: watch,
                riskCount: risk,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt
            )
        case .dynacap:
            let aligned = latest.filter { dynacapAligned($0) == true }.count
            let headline = latest.isEmpty ? nil : (Double(aligned) / Double(latest.count)) * 100
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: headline,
                headlineLabel: "Settings aligned",
                secondary: latest.isEmpty
                    ? "No stores in view"
                    : "\(aligned) of \(latest.count) within 10% of rec",
                health: band(headline, good: 85, watch: 70),
                watchCount: watch,
                riskCount: risk,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt
            )
        case .scheduleQuality:
            let headline = average(latest.compactMap { $0.number("schedule_efficiency_pct") })
            let over = latest.reduce(0) { $0 + ($1.number("over_scheduled") ?? 0) }
            let under = latest.reduce(0) { $0 + ($1.number("under_scheduled") ?? 0) }
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: headline,
                headlineLabel: "Avg schedule efficiency",
                secondary: latest.isEmpty
                    ? "No stores in view"
                    : "\(Int(over.rounded())) over · \(Int(under.rounded())) under",
                health: band(headline, good: 95, watch: 88),
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
                headline: Double(board.opportunity.count),
                headlineLabel: "Opportunity shoppers",
                secondary: latest.isEmpty
                    ? "No shoppers in view"
                    : "\(board.strong.count) doing well · \(latest.count) shoppers",
                health: band(
                    latest.isEmpty ? nil : (1 - Double(board.opportunity.count) / Double(latest.count)) * 100,
                    good: 80,
                    watch: 65
                ),
                watchCount: latest.filter { pickerHealth($0) == .watch }.count,
                riskCount: latest.filter { pickerHealth($0) == .risk }.count,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt
            )
        }
    }

    static let pphGoal = 80.0
    static let pphRisk = 74.0
    static let pickPathGoal = 90.0
    static let pickPathRisk = 80.0

    static func pphHealth(_ row: MetricRow) -> Health {
        band(row.number("pph"), good: pphGoal, watch: pphRisk)
    }

    static func pickerComposite(_ row: MetricRow) -> Double {
        var parts: [Double] = []
        if let pph = row.number("pph") {
            let goal = max(row.number("goal_pph") ?? 65, 1)
            parts.append(min(pph / goal, 1.2) / 1.2)
        }
        if let compliance = row.number("compliance_pct") {
            parts.append(min(compliance / 100, 1))
        }
        if let quality = row.number("quality_score") {
            parts.append(quality > 5 ? min(quality / 100, 1) : min(quality / 5, 1))
        }
        guard !parts.isEmpty else { return 0 }
        return parts.reduce(0, +) / Double(parts.count)
    }

    static func pickerHealth(_ row: MetricRow) -> Health {
        band(pickerComposite(row), good: 0.92, watch: 0.80)
    }

    struct PickerBoard {
        var shoppers: [MetricRow]
        var opportunity: [MetricRow]
        var strong: [MetricRow]
    }

    static func pickerBoard(_ rows: [MetricRow], limit: Int = 6) -> PickerBoard {
        let shoppers = latestPerShopper(rows)
        let ranked = shoppers.sorted { pickerComposite($0) < pickerComposite($1) }
        let opportunity = Array(ranked.filter { pickerHealth($0) != .good }.prefix(limit))
        let strong = Array(ranked.reversed().filter { pickerHealth($0) == .good }.prefix(limit))
        return PickerBoard(shoppers: shoppers, opportunity: opportunity, strong: strong)
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
                if let aligned = dynacapAligned(row) {
                    value = aligned ? 100 : 0
                } else {
                    value = nil
                }
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
}

struct StoreCellViewModel {
    var primary: String
    var extra: String

    static func make(section: MetricSection, row: MetricRow) -> StoreCellViewModel {
        switch section {
        case .fiveStar:
            return StoreCellViewModel(
                primary: HeartbeatFormat.stars(row.number("star_rating")),
                extra: "OTP \(HeartbeatFormat.pct(row.number("otp_pct"))) · Fill \(HeartbeatFormat.pct(row.number("fill_rate_pct")))"
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
                gapText = "Goal 90%"
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
            return StoreCellViewModel(
                primary: HeartbeatFormat.pct(row.number("pnr_rate_pct")),
                extra: "\(HeartbeatFormat.num(row.number("pnr_count"))) not ready · \(HeartbeatFormat.num(row.number("avg_late_min"), digits: 1)) min late"
            )
        case .dynacap:
            let aligned = HeartbeatMath.dynacapAligned(row)
            return StoreCellViewModel(
                primary: aligned == nil ? "—" : (aligned == true ? "Aligned" : "Off rec"),
                extra: "PU \(HeartbeatFormat.num(row.number("pickup_capacity"))) / \(HeartbeatFormat.num(row.number("rec_pickup"))) · DL \(HeartbeatFormat.num(row.number("delivery_capacity"))) / \(HeartbeatFormat.num(row.number("rec_delivery")))"
            )
        case .scheduleQuality:
            return StoreCellViewModel(
                primary: HeartbeatFormat.pct(row.number("schedule_efficiency_pct")),
                extra: "Over \(HeartbeatFormat.num(row.number("over_scheduled"))) · Under \(HeartbeatFormat.num(row.number("under_scheduled")))"
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
                extra: "Path \(HeartbeatFormat.pct(row.number("compliance_pct"))) · Qual \(HeartbeatFormat.pct(row.number("quality_score")))"
            )
        }
    }
}

