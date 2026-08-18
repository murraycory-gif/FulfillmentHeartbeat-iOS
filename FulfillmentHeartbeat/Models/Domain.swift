import Foundation

enum MetricSection: String, CaseIterable, Identifiable, Codable, Hashable {
    case fiveStar = "five_star"
    case pickPath = "pick_path"
    case prepNotReady = "prep_not_ready"
    case dynacap = "dynacap"
    case scheduleQuality = "schedule_quality"
    case pph = "pph"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fiveStar: return "5 Star Metrics"
        case .pickPath: return "Pick Path Compliance"
        case .prepNotReady: return "Prep Not Ready"
        case .dynacap: return "Dynacap Setting"
        case .scheduleQuality: return "Schedule Quality"
        case .pph: return "PPH Pure Picks Per Hour"
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
        }
    }

    var blurb: String {
        switch self {
        case .fiveStar: return "Composite star rating and the four drivers behind it."
        case .pickPath: return "Share of picks that followed the system path."
        case .prepNotReady: return "Orders not staged by the promised ready time."
        case .dynacap: return "Pickup and delivery capacity versus recommended."
        case .scheduleQuality: return "How tightly the labor plan matches the work — efficiency, over, and under."
        case .pph: return "Pure picks completed per labor hour."
        }
    }

    var expectedMetrics: String {
        switch self {
        case .fiveStar: return "Star Rating · OTP % · Fill Rate · Quality · CX"
        case .pickPath: return "Compliance % · Picks Total · Picks Compliant · Exceptions"
        case .prepNotReady: return "PNR Count · Orders Due · PNR Rate · Avg Late Min"
        case .dynacap: return "Pickup / Delivery capacity · Rec pickup / delivery"
        case .scheduleQuality: return "Schedule Efficiency · Over Scheduled · Under Scheduled"
        case .pph: return "PPH · Picks Total · Pick Hours · Goal PPH"
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
        }
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
        return map.values.sorted { $0.storeNumber < $1.storeNumber }
    }

    static func filtered(_ rows: [MetricRow], division: String, om: String, store: String) -> [MetricRow] {
        rows.filter { row in
            if !division.isEmpty, row.division != division { return false }
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
            return band(row.number("compliance_pct"), good: 95, watch: 88)
        case .prepNotReady:
            return band(row.number("pnr_rate_pct"), good: 2, watch: 5, invert: true)
        case .dynacap:
            guard let aligned = dynacapAligned(row) else { return .watch }
            return aligned ? .good : .risk
        case .scheduleQuality:
            return band(row.number("schedule_efficiency_pct"), good: 95, watch: 88)
        case .pph:
            return pphHealth(row)
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
        let latest = latestPerStore(rows)
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
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: headline,
                headlineLabel: "Avg compliance",
                secondary: risk > 0
                    ? "\(risk) store\(risk == 1 ? "" : "s") below 88%"
                    : (latest.isEmpty ? "No stores in view" : "All stores at or above 88%"),
                health: band(headline, good: 95, watch: 88),
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
            let picks = latest.reduce(0) { $0 + ($1.number("picks_total") ?? 0) }
            let atGoal = latest.filter { row in
                guard let pph = row.number("pph"), let goal = row.number("goal_pph") else { return false }
                return pph >= goal
            }.count
            let hasGoals = latest.contains { $0.number("goal_pph") != nil }
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: headline,
                headlineLabel: "Avg pure PPH",
                secondary: latest.isEmpty
                    ? "No stores in view"
                    : (hasGoals
                        ? "\(atGoal) of \(latest.count) at goal"
                        : "\(Int(picks.rounded())) picks"),
                health: band(headline, good: 65, watch: 50),
                watchCount: watch,
                riskCount: risk,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt
            )
        }
    }

    static func pphHealth(_ row: MetricRow) -> Health {
        let pph = row.number("pph")
        if let pph, let goal = row.number("goal_pph"), goal > 0 {
            return band(pph / goal * 100, good: 100, watch: 90)
        }
        return band(pph, good: 65, watch: 50)
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
    var om = ""
    var store = ""

    var isActive: Bool {
        !division.isEmpty || !om.isEmpty || !store.isEmpty
    }

    var summary: String {
        [
            division.isEmpty ? "All divisions" : "Div \(division)",
            om.isEmpty ? "All OMs" : om,
            store.isEmpty ? "All stores" : store,
        ].joined(separator: " · ")
    }
}

struct HeartbeatSnapshot: Codable {
    var rows: [MetricRow]
    var uploads: [UploadRecord]
    var seeded: Bool
    var filters: DashboardFilters
}

enum HeartbeatFormat {
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
            return StoreCellViewModel(
                primary: HeartbeatFormat.pct(row.number("compliance_pct")),
                extra: "\(HeartbeatFormat.num(row.number("picks_compliant"))) / \(HeartbeatFormat.num(row.number("picks_total"))) picks"
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
            let goal = row.number("goal_pph")
            return StoreCellViewModel(
                primary: HeartbeatFormat.num(row.number("pph"), digits: 1),
                extra: goal == nil
                    ? "\(HeartbeatFormat.num(row.number("picks_total"))) picks · \(HeartbeatFormat.num(row.number("pick_hours"), digits: 1)) hrs"
                    : "Goal \(HeartbeatFormat.num(goal, digits: 1)) · \(HeartbeatFormat.num(row.number("picks_total"))) picks"
            )
        }
    }
}

