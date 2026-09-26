import Foundation

/// On-device Heartbeat Assist: ranked problem cards, then resolution floor checks.
/// Floor-check wording lives only in AssistPlaybook.json.
enum AssistPlaybook {
    struct Check: Codable, Equatable {
        enum Kind: String, Codable {
            case floor
            case auto
        }

        var id: String
        var kind: Kind
        var question: String
        var ownerRole: String?
        var tapThrough: String?
        var showWhen: String?
        /// Pack payload key. Auto checks read this key on `source` rows.
        var field: String?
        /// Same measure under another pack key. The first finite value wins.
        var aliases: [String]?
        /// Metric section that holds `field`. Omitted checks use the card's own section.
        var source: String?
        var comparator: String?
        var threshold: Double?
        var answerTrue: String?
        var answerFalse: String?

        enum CodingKeys: String, CodingKey {
            case id, kind, question, ownerRole, tapThrough, showWhen
            case field, aliases, source, comparator, threshold, answerTrue, answerFalse
        }

        init(
            id: String,
            kind: Kind = .floor,
            question: String = "",
            ownerRole: String? = nil,
            tapThrough: String? = nil,
            showWhen: String? = nil,
            field: String? = nil,
            aliases: [String]? = nil,
            source: String? = nil,
            comparator: String? = nil,
            threshold: Double? = nil,
            answerTrue: String? = nil,
            answerFalse: String? = nil
        ) {
            self.id = id
            self.kind = kind
            self.question = question
            self.ownerRole = ownerRole
            self.tapThrough = tapThrough
            self.showWhen = showWhen
            self.field = field
            self.aliases = aliases
            self.source = source
            self.comparator = comparator
            self.threshold = threshold
            self.answerTrue = answerTrue
            self.answerFalse = answerFalse
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .floor
            question = try container.decodeIfPresent(String.self, forKey: .question) ?? ""
            ownerRole = try container.decodeIfPresent(String.self, forKey: .ownerRole)
            tapThrough = try container.decodeIfPresent(String.self, forKey: .tapThrough)
            showWhen = try container.decodeIfPresent(String.self, forKey: .showWhen)
            field = try container.decodeIfPresent(String.self, forKey: .field)
            aliases = try container.decodeIfPresent([String].self, forKey: .aliases)
            source = try container.decodeIfPresent(String.self, forKey: .source)
            comparator = try container.decodeIfPresent(String.self, forKey: .comparator)
            threshold = try container.decodeIfPresent(Double.self, forKey: .threshold)
            answerTrue = try container.decodeIfPresent(String.self, forKey: .answerTrue)
            answerFalse = try container.decodeIfPresent(String.self, forKey: .answerFalse)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(kind, forKey: .kind)
            try container.encode(question, forKey: .question)
            try container.encodeIfPresent(ownerRole, forKey: .ownerRole)
            try container.encodeIfPresent(tapThrough, forKey: .tapThrough)
            try container.encodeIfPresent(showWhen, forKey: .showWhen)
            try container.encodeIfPresent(field, forKey: .field)
            try container.encodeIfPresent(aliases, forKey: .aliases)
            try container.encodeIfPresent(source, forKey: .source)
            try container.encodeIfPresent(comparator, forKey: .comparator)
            try container.encodeIfPresent(threshold, forKey: .threshold)
            try container.encodeIfPresent(answerTrue, forKey: .answerTrue)
            try container.encodeIfPresent(answerFalse, forKey: .answerFalse)
        }
    }

    struct MetricBook: Codable, Equatable {
        var checks: [Check]
    }

    struct Shared: Codable, Equatable {
        var worstChildQuestion: String
        var childOpen: String
        var childWork: String
    }

    struct File: Codable, Equatable {
        var seedNote: String?
        var shared: Shared
        var metrics: [String: MetricBook]
    }

    static func load(from data: Data) throws -> File {
        try JSONDecoder().decode(File.self, from: data)
    }

    static func bundled() -> File? {
        guard let url = Bundle.main.url(forResource: "AssistPlaybook", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? load(from: data)
    }

    static let rankedMetricIDs: [String] = MetricSection.dashboardCards
        .filter { $0 != .pickerScorecard }
        .map(\.rawValue)
}

/// On-device auto check. Reads one pack field for the scope in view.
/// Returns nil when that field is absent, so the card hides the check.
enum AssistAutoCheck {
    static func sentence(
        _ check: AssistPlaybook.Check,
        rows: [MetricSection: [MetricRow]],
        fallbackSection: MetricSection
    ) -> String? {
        guard check.kind == .auto else { return nil }
        guard let comparator = check.comparator?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              let threshold = check.threshold, threshold.isFinite,
              let holds = comparison(comparator, threshold: threshold) else { return nil }
        let section = check.source.flatMap(MetricSection.init(rawValue:)) ?? fallbackSection
        let keys = fieldKeys(check)
        guard !keys.isEmpty else { return nil }
        let samples = AssistRank.scoringRows(rows[section] ?? []).compactMap { row -> Double? in
            for key in keys {
                if let value = row.number(key), value.isFinite { return value }
            }
            return nil
        }
        guard let value = HeartbeatMath.average(samples) else { return nil }
        let template = holds(value) ? check.answerTrue : check.answerFalse
        guard let template else { return nil }
        return AssistCopy.fill(
            template,
            ["value": format(value), "threshold": format(threshold)],
            limit: AssistCopy.actionLimit
        )
    }

    private static func fieldKeys(_ check: AssistPlaybook.Check) -> [String] {
        var keys: [String] = []
        if let field = check.field?.trimmingCharacters(in: .whitespacesAndNewlines), !field.isEmpty {
            keys.append(field)
        }
        for alias in check.aliases ?? [] {
            let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !keys.contains(trimmed) { keys.append(trimmed) }
        }
        return keys
    }

    private static func comparison(_ comparator: String, threshold: Double) -> ((Double) -> Bool)? {
        switch comparator {
        case "lt", "<": return { $0 < threshold }
        case "gt", ">": return { $0 > threshold }
        case "lte", "<=", "le": return { $0 <= threshold }
        case "gte", ">=", "ge": return { $0 >= threshold }
        case "eq", "==", "=": return { $0 == threshold }
        default: return nil
        }
    }

    static func format(_ value: Double) -> String {
        let text = String(format: "%.1f", value)
        guard text.hasSuffix(".0"), let whole = text.split(separator: ".").first else { return text }
        return String(whole)
    }
}

enum AssistRank {
    struct Input: Equatable {
        var section: MetricSection
        var health: Health
        var risk: Int
        var watch: Int
        var distance: Double
        var storeCount: Int
    }

    struct Scored: Equatable {
        var section: MetricSection
        var health: Health
        var risk: Int
        var watch: Int
        var distance: Double
        var storeCount: Int
        var score: Double
    }

    static func round4(_ value: Double) -> Double {
        (value * 10_000).rounded() / 10_000
    }

    /// Gap/band for one store row. Nil when the row has no comparable value.
    /// Schedule under/over uses the spec ratio on the stored field. This base
    /// treats values at or under 0.05 as on goal (`varianceHealth`).
    static func offBand(section: MetricSection, row: MetricRow) -> Double? {
        let ratio: Double?
        switch section {
        case .pickPath, .pickPathPicker:
            guard let value = row.number("compliance_pct") else { return nil }
            ratio = max(0, HeartbeatMath.pickPathGoal - value) / 10
        case .missingItems, .preSubOOS:
            guard let value = row.number(MissingItemDept.totalKey) else { return nil }
            ratio = max(0, value - HeartbeatMath.missingItemsGoal) / 1.5
        case .prepNotReady:
            guard let value = row.number("pnr_rate_pct") else { return nil }
            ratio = max(0, value - HeartbeatMath.pnrGoal) / 0.6
        case .dynacap:
            if let value = row.number("dynacap_rate", "pieces_per_hour") {
                ratio = max(0, HeartbeatMath.dynacapGoal - value) / 5
            } else if HeartbeatMath.dynacapAligned(row) == false {
                ratio = 1
            } else {
                return nil
            }
        case .scheduleQuality:
            ratio = scheduleRatio(row)
        case .pph:
            guard let value = HeartbeatMath.pphNumber(row) else { return nil }
            ratio = max(0, HeartbeatMath.pphGoal - value) / 6
        case .labor:
            guard let value = row.number("target_vs_actual_pct") else { return nil }
            ratio = max(0, value - 0) / HeartbeatMath.laborWatch
        case .fiveStar:
            guard let value = row.number("star_rating") else { return nil }
            ratio = max(0, 4.5 - value) / 0.5
        case .lostRevenue:
            guard let value = row.number("lost_revenue_pct") else { return nil }
            ratio = max(0, value - HeartbeatMath.lostRevenueGood) / 2
        case .sales:
            if let yoy = row.number("sales_yoy_pct") {
                ratio = max(0, 0 - yoy) / 3
            } else if let plan = row.number("sales_plan_pct") {
                ratio = max(0, HeartbeatMath.salesPlanGood - plan) / 5
            } else {
                return nil
            }
        default:
            return nil
        }
        guard let ratio, ratio.isFinite else { return nil }
        return min(3, ratio)
    }

    private static func scheduleRatio(_ row: MetricRow) -> Double? {
        var terms: [Double] = []
        if let efficiency = row.number("schedule_efficiency_pct") {
            terms.append(max(0, (HeartbeatMath.scheduleGoal - efficiency) / 5))
        }
        if let staffing = row.number("staffing_efficiency_pct") {
            terms.append(max(0, (HeartbeatMath.scheduleGoal - staffing) / 5))
        }
        if let under = row.number("under_schedule_pct", "under_scheduled") {
            terms.append(max(0, (under - 0.05) / 4.95))
        }
        if let over = row.number("over_schedule_pct", "over_scheduled") {
            terms.append(max(0, (over - 0.05) / 4.95))
        }
        guard let worst = terms.max(), worst.isFinite else { return nil }
        return worst
    }

    static func distance(section: MetricSection, rows: [MetricRow]) -> Double {
        let samples = scoringRows(rows).compactMap { row -> Double? in
            let health = HeartbeatMath.health(for: section, row: row)
            guard health == .risk || health == .watch else { return nil }
            return offBand(section: section, row: row)
        }
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0, +) / Double(samples.count)
    }

    static func scoringRows(_ rows: [MetricRow]) -> [MetricRow] {
        rows.filter {
            let store = $0.storeNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !store.isEmpty else { return false }
            if HeartbeatMath.isIgnoredStore(store) { return false }
            if $0.textPayload["lost_grain"] == "market" { return false }
            return true
        }
    }

    static func score(_ input: Input) -> Scored? {
        guard input.section != .pickerScorecard else { return nil }
        guard input.health != .none, input.storeCount > 0 else { return nil }
        guard input.risk + input.watch > 0 else { return nil }
        let severity: Int
        switch input.health {
        case .risk: severity = 3
        case .watch: severity = 2
        case .good: severity = 1
        case .none: return nil
        }
        let hit = Double(input.risk) + 0.5 * Double(input.watch)
        let raw = Double(severity) * hit * (1 + input.distance)
        guard raw.isFinite else { return nil }
        return Scored(
            section: input.section,
            health: input.health,
            risk: input.risk,
            watch: input.watch,
            distance: input.distance,
            storeCount: input.storeCount,
            score: round4(raw)
        )
    }

    static func ordered(_ items: [Scored]) -> [Scored] {
        let order = Dictionary(uniqueKeysWithValues: MetricSection.dashboardCards.enumerated().map { ($0.element, $0.offset) })
        return items.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.risk != rhs.risk { return lhs.risk > rhs.risk }
            if lhs.watch != rhs.watch { return lhs.watch > rhs.watch }
            if lhs.distance != rhs.distance { return lhs.distance > rhs.distance }
            return (order[lhs.section] ?? 99) < (order[rhs.section] ?? 99)
        }
    }

    static func rank(_ inputs: [Input]) -> [Scored] {
        ordered(inputs.compactMap(score))
    }
}

enum AssistChildGrain: Equatable {
    case region, division, district, om, store
}

enum AssistScopeLevel: Equatable {
    case company, region, division, district, om, store
}

enum AssistFilterChange: Equatable {
    case none
    case clear
    case region(String)
    case division(String)
    case district(String)
    case om(String)
    case store(String)
    case commit(DashboardFilters)
}

enum AssistScope {
    static func level(_ filters: DashboardFilters) -> AssistScopeLevel {
        if !filters.store.isEmpty { return .store }
        if !filters.om.isEmpty { return .om }
        if !filters.district.isEmpty { return .district }
        if !filters.division.isEmpty { return .division }
        if !filters.region.isEmpty { return .region }
        return .company
    }

    static func label(_ filters: DashboardFilters, roster: [(number: String, name: String?)]) -> String {
        switch level(filters) {
        case .company:
            return "Total company"
        case .region:
            return DashboardFilters.display(filters.region, empty: "Total company")
        case .division:
            let shown = DashboardFilters.display(filters.division, empty: "")
            if DashboardFilters.parts(filters.division).count == 1 {
                return "\(shown) market"
            }
            return shown
        case .district:
            return DashboardFilters.display(filters.district, empty: "District", prefix: "District ")
        case .om:
            let shown = DashboardFilters.display(filters.om, empty: "")
            return shown.hasPrefix("OM ") ? shown : "OM \(shown)"
        case .store:
            let numbers = DashboardFilters.parts(filters.store).map { HeartbeatMath.canonicalStore($0) }
            if numbers.count == 1, let number = numbers.first {
                if let name = rosterName(number, roster: roster) {
                    return "Store \(number), \(name)"
                }
                return "Store \(number)"
            }
            return "Store \(DashboardFilters.display(filters.store, empty: ""))"
        }
    }

    static func scopeLine(_ filters: DashboardFilters, roster: [(number: String, name: String?)]) -> String {
        let text = label(filters, roster: roster)
        if level(filters) == .company {
            return "\(text) (all regions, divisions, districts, OMs, stores)"
        }
        return text
    }

    static func levelOwner(_ level: AssistScopeLevel) -> String {
        switch level {
        case .company: return "Region EVPs"
        case .region: return "Market directors"
        case .division: return "District managers"
        case .district: return "Operations managers"
        case .om, .store: return "Store leaders"
        }
    }

    static func childOwner(_ grain: AssistChildGrain) -> String {
        switch grain {
        case .region: return "Region EVPs"
        case .division: return "Market directors"
        case .district: return "District managers"
        case .om: return "Operations managers"
        case .store: return "Store leaders"
        }
    }

    static func naturalChild(_ level: AssistScopeLevel) -> AssistChildGrain? {
        switch level {
        case .company: return .region
        case .region: return .division
        case .division: return .district
        case .district: return .om
        case .om: return .store
        case .store: return nil
        }
    }

    static func childUnitWord(_ level: AssistScopeLevel) -> String? {
        switch naturalChild(level) {
        case .region: return "region"
        case .division: return "market"
        case .district: return "district"
        case .om: return "OM"
        case .store: return "store"
        case nil: return nil
        }
    }

    static func grainKey(_ row: MetricRow, grain: AssistChildGrain) -> String? {
        switch grain {
        case .region:
            return MarketRegion.containing(row.division)?.rawValue
        case .division:
            let name = row.division.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        case .district:
            let name = row.district.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        case .om:
            let name = row.operationsOM.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        case .store:
            let name = HeartbeatMath.canonicalStore(row.storeNumber)
            return name.isEmpty ? nil : name
        }
    }

    static func childLabel(grain: AssistChildGrain, key: String, storeName: String?) -> String {
        switch grain {
        case .region:
            return key
        case .division:
            return "\(key) market"
        case .district:
            return "District \(HeartbeatMath.displayGrainLabel(key))"
        case .om:
            return "OM \(key)"
        case .store:
            if let storeName, !storeName.isEmpty {
                return "Store \(key), \(storeName)"
            }
            return "Store \(key)"
        }
    }

    static func rosterName(_ number: String, roster: [(number: String, name: String?)]) -> String? {
        let want = HeartbeatMath.canonicalStore(number)
        guard let name = roster.first(where: { HeartbeatMath.canonicalStore($0.number) == want })?.name else {
            return nil
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func slice(_ rows: [MetricRow], filters: DashboardFilters) -> [MetricRow] {
        rows.filter { row in
            if !filters.includesDivision(row.division) { return false }
            if !filters.includesDistrict(row.district) { return false }
            if !filters.includesOM(row.operationsOM) { return false }
            if !filters.includesStore(row.storeNumber) { return false }
            return true
        }
    }
}

enum AssistIntent: Equatable {
    case fix
    case children(AssistChildGrain?)
    case metric(MetricSection)
    case shoppers
    case watch
    case healthy
    case store(String)
    case district(String)
    case division(String)
    case region(String)
    case om(String)
    case shopper(String)
    case unknown
}

struct AssistFact: Equatable, Identifiable {
    var label: String
    var value: String
    var id: String { label }
}

struct AssistAction: Equatable, Identifiable {
    var id: String
    var question: String
    var owner: String
    var buttonTitle: String
    var filters: DashboardFilters?
    var clearsFilters: Bool
    var destination: HubDestination
    var accessibilityLabel: String

    static func open(
        id: String,
        question: String,
        owner: String,
        buttonTitle: String,
        filters: DashboardFilters?,
        destination: HubDestination
    ) -> AssistAction {
        let ownerBit = owner.isEmpty ? "" : " Owner \(owner)."
        return AssistAction(
            id: id,
            question: question,
            owner: owner,
            buttonTitle: buttonTitle,
            filters: filters,
            clearsFilters: false,
            destination: destination,
            accessibilityLabel: "\(question).\(ownerBit) Opens \(destination.title)."
        )
    }
}

struct AssistHeaderLine: Equatable, Identifiable {
    var text: String
    var issueID: String
    var id: String { issueID }
}

struct AssistIssue: Equatable, Identifiable {
    var id: String
    var rank: Int
    var title: String
    var statusText: String
    var statusSymbol: String
    var statusHealth: Health
    var headline: String
    var numberLabel: String
    var numberValue: String
    var facts: [AssistFact]
    var scope: String
    var footer: String
    var footerAction: AssistAction
    var checks: [AssistAction]
    var rankedLine: String
    var accessibilityLabel: String
}

struct AssistAnswer: Equatable {
    var scopeLabel: String
    var dataWindow: String?
    var staleBanner: String?
    var headerTitle: String?
    var headerLines: [AssistHeaderLine]
    var issues: [AssistIssue]
    var rankedLines: [String]
    var emptyNote: String?
    var noticeTitle: String?
    var noticeBody: String?
    var noticeAction: AssistAction?
    var healthyFacts: [AssistFact]
    var chips: [String]

    static let empty = AssistAnswer(
        scopeLabel: "Total company",
        dataWindow: nil,
        staleBanner: nil,
        headerTitle: nil,
        headerLines: [],
        issues: [],
        rankedLines: [],
        emptyNote: nil,
        noticeTitle: nil,
        noticeBody: nil,
        noticeAction: nil,
        healthyFacts: [],
        chips: []
    )
}

struct AssistSnapshot {
    var seeded: Bool
    var filters: DashboardFilters
    var summaries: [MetricSection: SectionSummary]
    var rows: [MetricSection: [MetricRow]]
    var history: [MetricSection: [HistoryPoint]]
    var dataWindow: String?
    var rosterStores: [(number: String, name: String?)]
    var districts: [String]
    var divisions: [String]
    var operationsOMs: [String]
    var now: Date
    var warehouse: [MetricSection: [MetricRow]]
    var packUploads: [Date]

    static let needed: [MetricSection] = MetricSection.dashboardCards + [
        .pickPathPicker, .aisleMapper, .preSubOOSItem, .storeRoster,
    ]
}

extension AssistSnapshot {
    @MainActor
    static func live(_ store: HeartbeatStore, section: MetricSection?) -> AssistSnapshot {
        var summaries: [MetricSection: SectionSummary] = [:]
        var rows: [MetricSection: [MetricRow]] = [:]
        var warehouse: [MetricSection: [MetricRow]] = [:]
        var history: [MetricSection: [HistoryPoint]] = [:]
        var uploads: [Date] = []
        for item in store.summaries {
            summaries[item.section] = item
            if let uploaded = item.lastUploadedAt {
                uploads.append(uploaded)
            }
        }
        for section in AssistSnapshot.needed {
            if summaries[section] == nil {
                summaries[section] = store.summary(for: section)
            }
            rows[section] = store.displayRows(for: section)
            warehouse[section] = store.rows(for: section)
            history[section] = store.history(for: section)
            if let uploaded = store.upload(for: section)?.uploadedAt {
                uploads.append(uploaded)
            }
        }
        let window = section.flatMap { store.dataWindow(for: $0) } ?? store.sharedDataWindow()
        return AssistSnapshot(
            seeded: store.seeded,
            filters: store.filters,
            summaries: summaries,
            rows: rows,
            history: history,
            dataWindow: window,
            rosterStores: store.stores,
            districts: store.districts,
            divisions: store.divisions,
            operationsOMs: store.operationsOMs,
            now: Date(),
            warehouse: warehouse,
            packUploads: uploads
        )
    }
}

enum AssistCopy {
    static let headlineLimit = 90
    static let actionLimit = 110
    static let headerLimit = 48
    static let chipLimit = 40
    static let staleInterval: TimeInterval = 36 * 60 * 60

    static func grouped(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func stores(_ count: Int) -> String {
        count == 1 ? "1 store" : "\(grouped(count)) stores"
    }

    static func fill(_ template: String, _ values: [String: String], limit: Int) -> String? {
        guard let expression = try? NSRegularExpression(pattern: "\\{([A-Za-z0-9]+)\\}") else { return nil }
        let ns = template as NSString
        let matches = expression.matches(in: template, range: NSRange(location: 0, length: ns.length))
        var result = template
        for match in matches.reversed() {
            let key = ns.substring(with: match.range(at: 1))
            guard let value = values[key], !value.isEmpty else { return nil }
            guard let range = Range(match.range, in: result) else { return nil }
            result.replaceSubrange(range, with: value)
        }
        guard result.count <= limit else { return nil }
        return result
    }

    static func headerTitle(issueCount: Int) -> String? {
        switch issueCount {
        case 0: return nil
        case 1: return "Fix this first"
        case 2: return "Fix these 2 first"
        default: return "Fix these 3 first"
        }
    }

    static func headerLine(rank: Int, shortName: String, risk: Int, total: Int) -> String {
        let line = "\(rank). \(shortName): \(grouped(risk)) of \(grouped(total)) \(total == 1 ? "store" : "stores")"
        if line.count <= headerLimit { return line }
        return "\(rank). \(shortName): \(grouped(risk)) of \(grouped(total))"
    }

    static func storeHeaderLine(rank: Int, shortName: String, value: String, goal: String) -> String {
        let line = "\(rank). \(shortName): \(value) (goal \(goal))"
        if line.count <= headerLimit { return line }
        let shorter = "\(rank). \(shortName): \(value)"
        return shorter.count <= headerLimit ? shorter : "\(rank). \(shortName)"
    }

    static func goalShort(_ section: MetricSection) -> String {
        switch section {
        case .scheduleQuality: return "90%"
        case .missingItems, .preSubOOS: return "5%"
        case .pickPath: return "90%"
        case .fiveStar: return "4.50"
        case .prepNotReady: return "1.9%"
        case .dynacap: return "65"
        case .pph: return "80"
        case .labor: return "0%"
        case .lostRevenue: return "3%"
        case .sales: return "100%"
        default: return ""
        }
    }

    static func goalFact(_ section: MetricSection) -> String {
        switch section {
        case .scheduleQuality, .pickPath: return "90%"
        case .missingItems, .preSubOOS: return "5% or less"
        case .fiveStar: return "4.50+"
        case .prepNotReady: return "1.9% or less"
        case .dynacap: return "65"
        case .pph: return "80"
        case .labor: return "0% or less"
        case .lostRevenue: return "3% or less"
        case .sales: return "Up vs last year"
        default: return ""
        }
    }

    static func one(_ value: Double) -> String { String(format: "%.1f", value) }
    static func onePct(_ value: Double) -> String { String(format: "%.1f%%", value) }

    static func status(_ health: Health) -> (text: String, symbol: String, ink: Health) {
        switch health {
        case .risk: return ("At risk", "exclamationmark.triangle.fill", .risk)
        case .watch: return ("Watch", "eye.fill", .watch)
        case .good: return ("Stores failing", "exclamationmark.circle.fill", .watch)
        case .none: return ("No data", "questionmark.circle", .none)
        }
    }

    static func rankedLine(_ scored: AssistRank.Scored) -> String {
        let statusWord: String
        switch scored.health {
        case .risk: statusWord = "at risk"
        case .watch: statusWord = "watch"
        case .good: statusWord = "stores failing"
        case .none: statusWord = "no data"
        }
        let distance = one(scored.distance)
        return "\(scored.section.title): \(statusWord), \(grouped(scored.risk)) at-risk and \(grouped(scored.watch)) watch stores, on average \(distance) of a band past goal."
    }

    static func screenTitle(_ destination: HubDestination) -> String {
        "Open \(destination.title) ›"
    }

    static func chip(_ text: String) -> String? {
        guard !text.isEmpty, text.count <= chipLimit else { return nil }
        return text
    }
}

struct AssistChild: Equatable {
    var key: String
    var label: String
    var score: Double
    var storesAtRisk: Int
    var storeCount: Int
    var worstMetric: MetricSection?
    var worstRisk: Int
    var worstStores: Int
    var grain: AssistChildGrain
}

enum AssistComposer {
    static func chips(for snapshot: AssistSnapshot, book: AssistPlaybook.File? = nil) -> [String] {
        answer(question: "What should we fix first?", snapshot: snapshot, book: book).chips
    }

    static func answer(
        question: String,
        snapshot: AssistSnapshot,
        book: AssistPlaybook.File? = nil
    ) -> AssistAnswer {
        let playbook = book ?? AssistPlaybook.bundled()
        if !snapshot.seeded || snapshot.summaries.isEmpty {
            return noPack(snapshot)
        }
        let base = snapshot.filters
        let intent = resolve(question, snapshot: snapshot)
        let lens = narrowed(snapshot, intent: intent)
        if lens.filters.isActive && MetricSection.dashboardCards.allSatisfy({ (lens.summaries[$0]?.storeCount ?? 0) == 0 }) {
            return noScope(lens)
        }
        if lens.summaries.values.allSatisfy({ $0.health == .none }) {
            return noPack(lens)
        }
        switch intent {
        case .unknown:
            return unknown(lens, playbook: playbook, base: base)
        case .healthy:
            return healthy(lens, playbook: playbook, base: base)
        case .shoppers, .shopper:
            return shoppers(lens, intent: intent, playbook: playbook, base: base)
        case .children(let grain):
            return children(lens, grain: grain, playbook: playbook, base: base)
        case .metric(let section):
            return metrics(lens, sections: [section], watchOnly: false, showHeader: false, playbook: playbook, base: base, single: true)
        case .watch:
            return metrics(lens, sections: nil, watchOnly: true, showHeader: false, playbook: playbook, base: base, single: false)
        case .fix, .store, .district, .division, .region, .om:
            return metrics(lens, sections: nil, watchOnly: false, showHeader: true, playbook: playbook, base: base, single: false)
        }
    }

    static func resolve(_ question: String, snapshot: AssistSnapshot) -> AssistIntent {
        let normalized = normalize(question)
        guard !normalized.isEmpty else { return .unknown }
        if let store = namedStore(in: normalized, roster: snapshot.rosterStores) {
            return .store(store)
        }
        if let unit = namedUnit(in: normalized, snapshot: snapshot) {
            return unit
        }
        if let shopper = namedShopper(in: normalized, snapshot: snapshot) {
            return .shopper(shopper)
        }
        switch worstAsk(in: normalized) {
        case .unspecified:
            return .children(nil)
        case .grain(let grain):
            return .children(grain)
        case nil:
            break
        }
        if contains(normalized, ["fix", "first", "wrong", "priority", "do today", "start"]) {
            return .fix
        }
        if let section = metric(in: normalized) {
            return .metric(section)
        }
        if contains(normalized, ["shopper", "picker", "ldap", "coach"]) {
            return .shoppers
        }
        if normalized.contains("watch") {
            return .watch
        }
        if contains(normalized, ["healthy", "green", "holding", "good"]) {
            return .healthy
        }
        return .unknown
    }

    static func normalize(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func contains(_ haystack: String, _ keys: [String]) -> Bool {
        keys.contains { haystack.contains($0) }
    }

    private static func namedStore(in question: String, roster: [(number: String, name: String?)]) -> String? {
        let known = Set(roster.map { HeartbeatMath.canonicalStore($0.number) })
        let tokens = question.split(whereSeparator: { !$0.isNumber }).map(String.init)
        for token in tokens where token.count >= 3 && token.count <= 5 {
            let canonical = HeartbeatMath.canonicalStore(token)
            if known.contains(canonical) { return canonical }
        }
        return nil
    }

    private static func namedUnit(in question: String, snapshot: AssistSnapshot) -> AssistIntent? {
        let padded = " \(question.replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)) "
        func hit(_ name: String) -> Bool {
            let phrase = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard phrase.count >= 2 else { return false }
            return padded.contains(" \(phrase) ")
        }
        for name in MarketRegion.allCases.map(\.rawValue) where hit(name) {
            return .region(name)
        }
        for name in MarketRegion.allCases.map(\.rawValue) {
            let short = name.replacingOccurrences(of: " Region", with: "")
            if short.count >= 4 && hit(short) { return .region(name) }
        }
        for name in snapshot.divisions where hit(name) { return .division(name) }
        for name in snapshot.districts where hit(name) { return .district(name) }
        for name in snapshot.operationsOMs where hit(name) { return .om(name) }
        return nil
    }

    private static func namedShopper(in question: String, snapshot: AssistSnapshot) -> String? {
        let stops: Set<String> = [
            "what", "whats", "what's", "should", "which", "first", "worst", "store", "stores",
            "district", "fix", "watch", "coach", "shopper", "shoppers", "picker", "pickers",
            "about", "more", "tell", "need", "needs", "coaching", "here", "this", "today",
            "labor", "sales", "schedule", "missing", "items", "path", "prep", "ready",
        ]
        let tokens = question.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        let rows = (snapshot.rows[.pickerScorecard] ?? []) + (snapshot.rows[.pickPathPicker] ?? [])
        for token in tokens where token.count >= 4 && !stops.contains(token) {
            for row in rows {
                let name = cleanName(row)
                let id = row.shopperId?.lowercased()
                if id == token { return name ?? token }
                if let name {
                    let words = name.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
                    if words.contains(token) || name.lowercased() == token { return name }
                }
            }
        }
        return nil
    }

    private enum WorstAsk {
        case unspecified
        case grain(AssistChildGrain)
    }

    /// Nil when the question is not a worst-child ask. `.unspecified` when it is, but names no grain.
    private static func worstAsk(in question: String) -> WorstAsk? {
        let asks = contains(question, ["worst", "bottom", "lowest", "who is"])
        guard asks else { return nil }
        let padded = " \(question) "
        if padded.contains(" district") { return .grain(.district) }
        if padded.contains(" market") { return .grain(.division) }
        if padded.contains(" region") { return .grain(.region) }
        if padded.contains(" store") { return .grain(.store) }
        if padded.contains(" om") || padded.contains(" oms") { return .grain(.om) }
        return .unspecified
    }

    private static func metric(in question: String) -> MetricSection? {
        let pairs: [(MetricSection, [String])] = [
            (.prepNotReady, ["prep not ready", "pnr", "prep"]),
            (.preSubOOS, ["pre-sub", "pre sub", "oos"]),
            (.missingItems, ["missing items", "missing", "aisle tag"]),
            (.pickPath, ["pick path", "aisle map", "path"]),
            (.fiveStar, ["5 star", "five star", "flash", "presub", "ott", "oth", "coe"]),
            (.dynacap, ["dynacap", "capacity"]),
            (.scheduleQuality, ["schedule"]),
            (.pph, ["picks per hour", "pph"]),
            (.labor, ["labor", "tva"]),
            (.lostRevenue, ["lost revenue", "lost", "loss", "refund", "cancel", "kill switch"]),
            (.sales, ["sales", "yoy"]),
        ]
        for (section, keys) in pairs {
            for key in keys where containsToken(question, key) {
                return section
            }
        }
        return nil
    }

    private static func containsToken(_ question: String, _ key: String) -> Bool {
        if key.contains(" ") || key.contains("-") { return question.contains(key) }
        if key.count >= 5 { return question.contains(key) }
        let padded = " \(question.replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)) "
        return padded.contains(" \(key) ")
    }

    private static func narrowed(_ snapshot: AssistSnapshot, intent: AssistIntent) -> AssistSnapshot {
        var filters = snapshot.filters
        switch intent {
        case .store(let number):
            filters = DashboardFilters()
            filters.store = number
        case .district(let name):
            filters.district = name
            filters.om = ""
            filters.store = ""
        case .division(let name):
            filters.region = MarketRegion.containing(name)?.rawValue ?? filters.region
            filters.division = name
            filters.district = ""
            filters.om = ""
            filters.store = ""
        case .region(let name):
            filters = DashboardFilters()
            filters.region = name
        case .om(let name):
            filters.om = name
            filters.store = ""
        default:
            return snapshot
        }
        guard filters != snapshot.filters else { return snapshot }
        var next = snapshot
        next.filters = filters
        let source = snapshot.warehouse.isEmpty ? snapshot.rows : snapshot.warehouse
        var rows: [MetricSection: [MetricRow]] = [:]
        var summaries: [MetricSection: SectionSummary] = [:]
        var history: [MetricSection: [HistoryPoint]] = [:]
        for section in AssistSnapshot.needed {
            let sliced = AssistScope.slice(source[section] ?? [], filters: filters)
            rows[section] = sliced
            summaries[section] = HeartbeatMath.summarize(section, rows: sliced, upload: nil)
            history[section] = HeartbeatMath.history(section, rows: sliced)
        }
        for (section, summary) in snapshot.summaries where next.summaries[section] == nil {
            summaries[section] = summary
        }
        next.rows = rows
        next.summaries = summaries
        next.history = history
        next.warehouse = source
        return next
    }

    private static func noPack(_ snapshot: AssistSnapshot) -> AssistAnswer {
        var answer = AssistAnswer.empty
        answer.scopeLabel = AssistScope.label(snapshot.filters, roster: snapshot.rosterStores)
        answer.noticeTitle = "No Heartbeat data on this device yet."
        answer.noticeBody = "Assist answers only from the Heartbeat pack on this device. Wait for today's pack to download."
        return answer
    }

    private static func noScope(_ snapshot: AssistSnapshot) -> AssistAnswer {
        var answer = AssistAnswer.empty
        let scope = AssistScope.label(snapshot.filters, roster: snapshot.rosterStores)
        answer.scopeLabel = scope
        answer.dataWindow = snapshot.dataWindow
        answer.noticeTitle = "No Heartbeat numbers for \(scope)."
        answer.noticeBody = "The pack has no rows for this filter. Clear it or pick another area."
        answer.noticeAction = AssistAction(
            id: "clear-filters",
            question: "Clear filters",
            owner: "",
            buttonTitle: "Clear filters",
            filters: nil,
            clearsFilters: true,
            destination: .dashboard,
            accessibilityLabel: "Clear filters. Opens Dashboard."
        )
        return answer
    }

    private static func unknown(_ snapshot: AssistSnapshot, playbook: AssistPlaybook.File?, base: DashboardFilters) -> AssistAnswer {
        var answer = shell(snapshot, playbook: playbook, base: base, showHeader: false)
        answer.issues = []
        answer.headerTitle = nil
        answer.headerLines = []
        answer.rankedLines = []
        answer.noticeTitle = "I can answer from the numbers on this device. Try one of these:"
        answer.noticeBody = nil
        return answer
    }

    private static func healthy(_ snapshot: AssistSnapshot, playbook: AssistPlaybook.File?, base: DashboardFilters) -> AssistAnswer {
        let ranked = rank(snapshot)
        let withData = MetricSection.dashboardCards.filter { section in
            guard section != .pickerScorecard else { return false }
            let summary = snapshot.summaries[section]
            return (summary?.storeCount ?? 0) > 0 && summary?.health != .none
        }
        let healthyOnes = withData.filter { section in
            !ranked.contains { $0.section == section }
        }
        var answer = AssistAnswer.empty
        answer.scopeLabel = AssistScope.label(snapshot.filters, roster: snapshot.rosterStores)
        answer.dataWindow = snapshot.dataWindow
        answer.staleBanner = staleBanner(snapshot)
        answer.chips = chipList(snapshot, ranked: ranked, level: AssistScope.level(snapshot.filters))
        if ranked.isEmpty && !withData.isEmpty {
            let scope = answer.scopeLabel
            answer.noticeTitle = "Nothing needs fixing in \(scope)."
            answer.noticeBody = "All \(withData.count) scorecards with data are at goal."
            if let closest = closestToGoal(snapshot, sections: healthyOnes) {
                answer.noticeBody = (answer.noticeBody ?? "") + " Closest to its goal: \(closest)."
            }
            answer.healthyFacts = healthyOnes.compactMap { section in
                guard let summary = snapshot.summaries[section], summary.headline != nil else { return nil }
                return AssistFact(label: section.overviewLead, value: "\(summary.headlineText) (goal \(AssistCopy.goalFact(section)))")
            }
        } else {
            answer.noticeTitle = "Scorecards at goal"
            answer.noticeBody = "These scorecards are at goal in \(answer.scopeLabel)."
            answer.healthyFacts = healthyOnes.compactMap { section in
                guard let summary = snapshot.summaries[section], summary.headline != nil else { return nil }
                return AssistFact(label: section.overviewLead, value: "\(summary.headlineText) (goal \(AssistCopy.goalFact(section)))")
            }
        }
        answer.emptyNote = emptyNote(snapshot)
        return answer
    }

    private static func shoppers(
        _ snapshot: AssistSnapshot,
        intent: AssistIntent,
        playbook: AssistPlaybook.File?,
        base: DashboardFilters
    ) -> AssistAnswer {
        var answer = shell(snapshot, playbook: playbook, base: base, showHeader: false)
        let people = shopperRows(snapshot)
        let wanted: String?
        if case .shopper(let name) = intent { wanted = name } else { wanted = nil }
        let chosen = people.filter { row in
            guard let wanted else { return true }
            let name = cleanName(row)?.lowercased() ?? ""
            return name == wanted.lowercased() || (row.shopperId?.lowercased() == wanted.lowercased())
        }.prefix(5)
        if chosen.isEmpty {
            answer.noticeTitle = "No shopper in \(answer.scopeLabel) needs coaching."
            answer.noticeBody = "Picker rows in this scope are at goal, or the pack has no shopper name."
            return answer
        }
        let level = AssistScope.level(snapshot.filters)
        answer.issues = chosen.enumerated().compactMap { index, row in
            shopperIssue(row, rank: index + 1, snapshot: snapshot, playbook: playbook, base: base, level: level)
        }
        return answer
    }

    private static func children(
        _ snapshot: AssistSnapshot,
        grain: AssistChildGrain?,
        playbook: AssistPlaybook.File?,
        base: DashboardFilters
    ) -> AssistAnswer {
        var answer = shell(snapshot, playbook: playbook, base: base, showHeader: false)
        let level = AssistScope.level(snapshot.filters)
        let resolved = grain ?? AssistScope.naturalChild(level)
        guard let resolved else {
            answer.noticeTitle = "This store is the floor."
            answer.noticeBody = "Ask which shoppers need coaching, or which scorecard to fix first."
            return answer
        }
        let ranked = rankChildren(snapshot, grain: resolved).filter { $0.score > 0 || $0.storesAtRisk > 0 }
        let top = Array(ranked.prefix(3))
        guard !top.isEmpty, let playbook else {
            answer.noticeTitle = "No \(resolvedWord(resolved)) breakdown for \(answer.scopeLabel)."
            answer.noticeBody = "The pack has no \(resolvedWord(resolved)) names with stores off goal in this filter."
            return answer
        }
        let scope = AssistScope.scopeLine(snapshot.filters, roster: snapshot.rosterStores)
        answer.issues = top.enumerated().map { index, child in
            childIssue(child, rank: index + 1, snapshot: snapshot, playbook: playbook, base: base, scope: scope, first: index == 0)
        }
        answer.rankedLines = top.map { child in
            "\(child.label): score \(AssistCopy.one(child.score)), \(AssistCopy.grouped(child.storesAtRisk)) stores with an at-risk scorecard."
        }
        return answer
    }

    private static func metrics(
        _ snapshot: AssistSnapshot,
        sections: [MetricSection]?,
        watchOnly: Bool,
        showHeader: Bool,
        playbook: AssistPlaybook.File?,
        base: DashboardFilters,
        single: Bool,
        forceInclude: Bool = false
    ) -> AssistAnswer {
        var answer = shell(snapshot, playbook: playbook, base: base, showHeader: false)
        var ranked = rank(snapshot)
        if let sections {
            ranked = ranked.filter { sections.contains($0.section) }
            if single {
                for section in sections where !ranked.contains(where: { $0.section == section }) {
                    if let summary = snapshot.summaries[section], summary.storeCount > 0, summary.health != .none {
                        let distance = AssistRank.distance(section: section, rows: snapshot.rows[section] ?? [])
                        if let scored = AssistRank.score(AssistRank.Input(
                            section: section,
                            health: summary.health == .good ? .good : summary.health,
                            risk: max(summary.riskCount, summary.health == .good ? 0 : summary.riskCount),
                            watch: summary.watchCount,
                            distance: distance,
                            storeCount: summary.storeCount
                        )) {
                            ranked.append(scored)
                        } else if forceInclude || single {
                            ranked.append(AssistRank.Scored(
                                section: section,
                                health: summary.health,
                                risk: summary.riskCount,
                                watch: summary.watchCount,
                                distance: distance,
                                storeCount: summary.storeCount,
                                score: 0
                            ))
                        }
                    }
                }
            }
        }
        if watchOnly {
            ranked = ranked.filter { $0.watch > 0 }
        }
        if ranked.isEmpty && !watchOnly && !single {
            let healthyAnswer = healthy(snapshot, playbook: playbook, base: base)
            return healthyAnswer
        }
        let level = AssistScope.level(snapshot.filters)
        let children = level == .store ? [] : rankChildren(snapshot, grain: AssistScope.naturalChild(level) ?? .region)
        let worst = children.first { $0.score > 0 || $0.storesAtRisk > 0 }
        let scope = AssistScope.scopeLine(snapshot.filters, roster: snapshot.rosterStores)
        answer.issues = ranked.enumerated().map { index, scored in
            issue(
                scored,
                rank: index + 1,
                snapshot: snapshot,
                playbook: playbook,
                base: base,
                level: level,
                scope: scope,
                worst: worst,
                watchOnly: watchOnly,
                singleHealthy: single && scored.risk + scored.watch == 0
            )
        }
        if showHeader && !answer.issues.isEmpty {
            answer.headerTitle = AssistCopy.headerTitle(issueCount: answer.issues.count)
            answer.headerLines = answer.issues.prefix(3).map { item in
                AssistHeaderLine(text: headerText(for: item, snapshot: snapshot, level: level), issueID: item.id)
            }
        }
        answer.rankedLines = ranked.map(AssistCopy.rankedLine)
        answer.emptyNote = emptyNote(snapshot)
        if answer.issues.isEmpty && watchOnly {
            answer.noticeTitle = "Nothing is on watch in \(answer.scopeLabel)."
            answer.noticeBody = "No scorecard has stores close to missing the goal."
        }
        return answer
    }

    private static func shell(
        _ snapshot: AssistSnapshot,
        playbook: AssistPlaybook.File?,
        base: DashboardFilters,
        showHeader: Bool
    ) -> AssistAnswer {
        let ranked = rank(snapshot)
        var answer = AssistAnswer.empty
        answer.scopeLabel = AssistScope.label(snapshot.filters, roster: snapshot.rosterStores)
        answer.dataWindow = blank(snapshot.dataWindow)
        answer.staleBanner = staleBanner(snapshot)
        answer.chips = chipList(snapshot, ranked: ranked, level: AssistScope.level(snapshot.filters))
        _ = playbook
        _ = base
        _ = showHeader
        return answer
    }

    private static func rank(_ snapshot: AssistSnapshot) -> [AssistRank.Scored] {
        let inputs: [AssistRank.Input] = MetricSection.dashboardCards.compactMap { section in
            guard section != .pickerScorecard else { return nil }
            guard let summary = snapshot.summaries[section] else { return nil }
            let distance = AssistRank.distance(section: section, rows: snapshot.rows[section] ?? [])
            return AssistRank.Input(
                section: section,
                health: summary.health,
                risk: summary.riskCount,
                watch: summary.watchCount,
                distance: distance,
                storeCount: summary.storeCount
            )
        }
        return AssistRank.rank(inputs)
    }

    private static func headerText(for issue: AssistIssue, snapshot: AssistSnapshot, level: AssistScopeLevel) -> String {
        guard let section = MetricSection(rawValue: issue.id), let summary = snapshot.summaries[section] else {
            return issue.rank <= 3 ? "\(issue.rank). \(issue.title)" : issue.title
        }
        if level == .store {
            let value = summary.headline == nil ? issue.numberValue : summary.headlineText
            return AssistCopy.storeHeaderLine(
                rank: issue.rank,
                shortName: section.overviewLead,
                value: value,
                goal: AssistCopy.goalShort(section)
            )
        }
        return AssistCopy.headerLine(
            rank: issue.rank,
            shortName: section.overviewLead,
            risk: summary.riskCount,
            total: summary.storeCount
        )
    }

    private static func issue(
        _ scored: AssistRank.Scored,
        rank: Int,
        snapshot: AssistSnapshot,
        playbook: AssistPlaybook.File?,
        base: DashboardFilters,
        level: AssistScopeLevel,
        scope: String,
        worst: AssistChild?,
        watchOnly: Bool,
        singleHealthy: Bool
    ) -> AssistIssue {
        let section = scored.section
        let summary = snapshot.summaries[section]
        let rows = snapshot.rows[section] ?? []
        let status = AssistCopy.status(scored.health)
        let headline = headlineText(
            section: section,
            summary: summary,
            scored: scored,
            rows: rows,
            level: level,
            watchOnly: watchOnly,
            singleHealthy: singleHealthy
        )
        let number = numberPair(section: section, summary: summary, scored: scored, level: level)
        let facts = factRow(section: section, summary: summary, rows: rows, snapshot: snapshot, scored: scored)
        let stay = snapshot.filters == base ? nil : snapshot.filters
        let destination = HubDestination.from(section: section)
        let footer = footerTitle(section: section, scored: scored, level: level)
        let footerAction = AssistAction.open(
            id: "\(section.rawValue)-footer",
            question: footer,
            owner: "",
            buttonTitle: footer,
            filters: stay,
            destination: destination
        )
        let checks = resolutionChecks(
            section: section,
            summary: summary,
            rows: rows,
            snapshot: snapshot,
            playbook: playbook,
            level: level,
            worst: worst,
            stay: stay,
            destination: destination
        )
        let storesAtRisk = level == .store ? (summary?.headlineText ?? "") : "\(AssistCopy.grouped(scored.risk)) of \(AssistCopy.grouped(scored.storeCount)) stores at risk"
        return AssistIssue(
            id: section.rawValue,
            rank: rank,
            title: section.title,
            statusText: status.text,
            statusSymbol: status.symbol,
            statusHealth: status.ink,
            headline: headline,
            numberLabel: number.label,
            numberValue: number.value,
            facts: facts,
            scope: "Scope: \(scope)",
            footer: footer,
            footerAction: footerAction,
            checks: checks,
            rankedLine: AssistCopy.rankedLine(scored),
            accessibilityLabel: "Rank \(rank), \(section.title), \(status.text). \(headline). \(storesAtRisk). Scope \(scope)."
        )
    }

    private static func headlineText(
        section: MetricSection,
        summary: SectionSummary?,
        scored: AssistRank.Scored,
        rows: [MetricRow],
        level: AssistScopeLevel,
        watchOnly: Bool,
        singleHealthy: Bool
    ) -> String {
        if singleHealthy, let summary, summary.headline != nil {
            let line = "\(section.overviewLead) is at goal: \(summary.headlineText) (goal \(AssistCopy.goalFact(section)))"
            return clip(line, AssistCopy.headlineLimit)
        }
        if watchOnly || (scored.health == .watch && scored.risk == 0) {
            let line = "\(AssistCopy.stores(scored.watch)) are close to missing \(section.overviewLead)"
            return clip(line.replacingOccurrences(of: "1 store are", with: "1 store is"), AssistCopy.headlineLimit)
        }
        let risk = AssistCopy.grouped(scored.risk)
        let total = AssistCopy.grouped(scored.storeCount)
        let value = summary?.headlineText ?? ""
        let above = scored.risk == 1 ? "1 of \(total) stores" : "\(risk) of \(total) stores"
        let text: String
        if level == .store {
            text = storeHeadline(section, value: value, rows: rows, summary: summary)
        } else {
            text = aboveHeadline(section, above: above, rows: rows, summary: summary)
        }
        return clip(text, AssistCopy.headlineLimit)
    }

    private static func aboveHeadline(_ section: MetricSection, above: String, rows: [MetricRow], summary: SectionSummary?) -> String {
        switch section {
        case .scheduleQuality:
            return "Schedules don't fit the work at \(above)"
        case .missingItems:
            return "Items are missing aisle tags at \(above)"
        case .pickPath:
            return "Shoppers are off the pick path at \(above)"
        case .fiveStar:
            return "\(above) are below 4.0 stars"
        case .preSubOOS:
            return "Items are out before substitution at \(above)"
        case .prepNotReady:
            return "Prep isn't ready when shoppers pick at \(above)"
        case .dynacap:
            if summary?.headline == nil {
                return "Capacity doesn't match the recommended setting at \(above)"
            }
            return "Capacity is set below 60 pieces an hour at \(above)"
        case .pph:
            return "Shoppers pick fewer than 74 an hour at \(above)"
        case .labor:
            return "Labor is more than 3% over target at \(above)"
        case .lostRevenue:
            let money = summary?.headlineText ?? ""
            if money.isEmpty || money == "—" {
                return "\(above) are above 5% lost sales"
            }
            return "\(money) in lost sales. \(above) are above 5%."
        case .sales:
            if rows.contains(where: { $0.number("sales_yoy_pct") != nil }) {
                return "Sales are down versus last year at \(above)"
            }
            return "Sales are off the plan at \(above)"
        default:
            return "\(section.overviewLead) is off goal at \(above)"
        }
    }

    private static func storeHeadline(_ section: MetricSection, value: String, rows: [MetricRow], summary: SectionSummary?) -> String {
        let shown = value == "—" ? "" : value
        switch section {
        case .scheduleQuality:
            return shown.isEmpty ? "Your schedule efficiency is off the 90% goal" : "Your schedule efficiency is \(shown) (goal 90%)"
        case .missingItems:
            return shown.isEmpty ? "Your items are missing aisle tags (goal 5% or less)" : "\(shown) of your items have no aisle tag (goal 5% or less)"
        case .pickPath:
            return shown.isEmpty ? "Your pick path is off the 90% goal" : "Your pick path is \(shown) (goal 90%)"
        case .fiveStar:
            return shown.isEmpty ? "Your store is off a 4.50 star rating" : "Your store is at \(shown) stars (healthy is 4.50+)"
        case .preSubOOS:
            return shown.isEmpty ? "Your ordered items were out before sub (goal 5% or less)" : "\(shown) of your ordered items were out before sub (goal 5% or less)"
        case .prepNotReady:
            return shown.isEmpty ? "Your pick hours were lost to prep (goal 1.9% or less)" : "\(shown) of your pick hours were lost to prep (goal 1.9% or less)"
        case .dynacap:
            if summary?.headline == nil {
                return "Your capacity doesn't match the recommended setting"
            }
            return "Your capacity is \(shown) pieces an hour (goal 65)"
        case .pph:
            return shown.isEmpty ? "Your pure PPH is off the goal of 80" : "Your pure PPH is \(shown) (goal 80)"
        case .labor:
            return shown.isEmpty ? "Your labor is off the target (goal 0% or less)" : "Your labor is \(shown) vs target (goal 0% or less)"
        case .lostRevenue:
            let money = summary?.headlineText ?? shown
            if let pct = summary?.lostRevenuePct {
                return "Your store lost \(money), \(AssistCopy.onePct(pct)) of eComm sales (goal 3% or less)"
            }
            return money.isEmpty ? "Your store is above the 3% lost-sales goal" : "Your store lost \(money) (goal 3% or less)"
        case .sales:
            let money = summary?.headlineText ?? shown
            if let yoy = summary?.salesYoyPct ?? rows.compactMap({ $0.number("sales_yoy_pct") }).first {
                return "Your eComm sales are \(money), \(AssistCopy.one(yoy))% vs last year"
            }
            return money.isEmpty ? "Your eComm sales are off goal" : "Your eComm sales are \(money)"
        default:
            return shown.isEmpty ? "\(section.overviewLead) is off goal" : "Your \(section.overviewLead) is \(shown)"
        }
    }

    private static func numberPair(
        section: MetricSection,
        summary: SectionSummary?,
        scored: AssistRank.Scored,
        level: AssistScopeLevel
    ) -> (label: String, value: String) {
        if level == .store {
            let value = summary?.headlineText ?? "—"
            return (section.title, value == "—" ? section.overviewLead : value)
        }
        return ("Stores at risk", "\(AssistCopy.grouped(scored.risk)) of \(AssistCopy.grouped(scored.storeCount))")
    }

    private static func factRow(
        section: MetricSection,
        summary: SectionSummary?,
        rows: [MetricRow],
        snapshot: AssistSnapshot,
        scored: AssistRank.Scored
    ) -> [AssistFact] {
        guard let summary else { return [] }
        var facts: [AssistFact] = []
        if summary.headline != nil {
            let label: String
            switch section {
            case .labor: label = "Target vs Actual"
            case .lostRevenue: label = "Total lost"
            case .sales: label = "eComm sales"
            default: label = "Average"
            }
            facts.append(AssistFact(label: label, value: summary.headlineText))
        }
        let goal = AssistCopy.goalFact(section)
        if section != .sales && !goal.isEmpty {
            facts.append(AssistFact(label: "Goal", value: goal))
        }
        if let trend = trendFact(section: section, rows: rows, snapshot: snapshot) {
            facts.append(trend)
        } else if let third = thirdFact(section: section, summary: summary, rows: rows, scored: scored) {
            facts.append(third)
        }
        if section == .sales, let plan = salesPlanFact(rows) {
            facts.append(plan)
        }
        return Array(facts.prefix(3))
    }

    private static func thirdFact(
        section: MetricSection,
        summary: SectionSummary,
        rows: [MetricRow],
        scored: AssistRank.Scored
    ) -> AssistFact? {
        switch section {
        case .scheduleQuality:
            return AssistFact(
                label: "Under / over",
                value: "\(AssistCopy.grouped(summary.underScheduledCount)) / \(AssistCopy.grouped(summary.overScheduledCount))"
            )
        case .fiveStar:
            let flags = HeartbeatMath.fiveStarActionFlags(rows, includeAll: true)
            guard let weakest = flags.max(by: { $0.stores < $1.stores }), weakest.stores > 0 else {
                return AssistFact(label: "On watch", value: AssistCopy.grouped(scored.watch))
            }
            return AssistFact(label: "Weakest part", value: "\(weakest.name): \(AssistCopy.stores(weakest.stores))")
        case .lostRevenue:
            guard let pct = summary.lostRevenuePct else { return nil }
            return AssistFact(label: "Lost %", value: AssistCopy.onePct(pct))
        default:
            return AssistFact(label: "On watch", value: AssistCopy.grouped(scored.watch))
        }
    }

    private static func salesPlanFact(_ rows: [MetricRow]) -> AssistFact? {
        let plans = rows.compactMap { $0.number("sales_plan_pct") }
        guard let avg = HeartbeatMath.average(plans) else { return nil }
        return AssistFact(label: "Plan", value: AssistCopy.onePct(avg))
    }

    private static func trendFact(section: MetricSection, rows: [MetricRow], snapshot: AssistSnapshot) -> AssistFact? {
        if section == .sales {
            var current: [Double] = []
            var yoy: [Double?] = []
            for row in rows {
                guard let dollars = row.number("sales_dollars") else { continue }
                current.append(dollars)
                yoy.append(row.number("sales_yoy_pct"))
            }
            guard let pct = HeartbeatMath.salesRollupYoY(current: current, yoyPct: yoy) else {
                return nil
            }
            let direction = pct >= 0 ? "Up" : "Down"
            return AssistFact(label: "Trend", value: "\(direction) \(AssistCopy.one(abs(pct)))% vs last year")
        }
        let points = snapshot.history[section] ?? []
        guard points.count >= 2 else { return nil }
        let previous = points[points.count - 2]
        let latest = points[points.count - 1]
        let delta = latest.value - previous.value
        let direction = delta >= 0 ? "Up" : "Down"
        return AssistFact(label: "Trend", value: "\(direction) \(AssistCopy.one(abs(delta))) since \(shortDate(previous.date))")
    }

    private static func resolutionChecks(
        section: MetricSection,
        summary: SectionSummary?,
        rows: [MetricRow],
        snapshot: AssistSnapshot,
        playbook: AssistPlaybook.File?,
        level: AssistScopeLevel,
        worst: AssistChild?,
        stay: DashboardFilters?,
        destination: HubDestination
    ) -> [AssistAction] {
        guard let playbook, let book = playbook.metrics[section.rawValue] else { return [] }
        let facts = checkFacts(section: section, summary: summary, rows: rows, snapshot: snapshot, level: level)
        let cap = 3
        var actions: [AssistAction] = []
        for check in book.checks {
            guard actions.count < cap else { break }
            guard flagMatches(check.showWhen, facts.flags) else { continue }
            guard let action = makeCheck(
                check,
                values: facts.values,
                level: level,
                stay: stay,
                fallback: destination,
                bucketCapacity: facts.flags.contains("bucketCapacity"),
                section: section,
                packRows: snapshot.rows
            ) else { continue }
            actions.append(action)
        }
        if level != .store, actions.count < 4, let worst, let summary {
            let counts = childMetricCounts(section: section, child: worst, snapshot: snapshot) ?? (summary.riskCount, summary.storeCount)
            var values = facts.values
            values["child"] = worst.label
            values["childRisk"] = AssistCopy.grouped(counts.0)
            values["childStores"] = AssistCopy.grouped(counts.1)
            if let question = AssistCopy.fill(playbook.shared.worstChildQuestion, values, limit: AssistCopy.actionLimit) {
                var filters = stay ?? snapshot.filters
                filters = applying(childChange(worst), on: filters)
                actions.append(AssistAction.open(
                    id: "\(section.rawValue)-child",
                    question: question,
                    owner: AssistScope.childOwner(worst.grain),
                    buttonTitle: AssistCopy.screenTitle(.dashboard),
                    filters: filters,
                    destination: .dashboard
                ))
            }
        }
        return actions
    }

    private static func flagMatches(_ showWhen: String?, _ flags: Set<String>) -> Bool {
        guard let showWhen, showWhen != "card" else { return true }
        return flags.contains(showWhen)
    }

    private static func makeCheck(
        _ check: AssistPlaybook.Check,
        values: [String: String],
        level: AssistScopeLevel,
        stay: DashboardFilters?,
        fallback: HubDestination,
        bucketCapacity: Bool,
        section: MetricSection,
        packRows: [MetricSection: [MetricRow]]
    ) -> AssistAction? {
        let question: String?
        if check.kind == .auto {
            question = AssistAutoCheck.sentence(check, rows: packRows, fallbackSection: section)
        } else {
            question = AssistCopy.fill(check.question, values, limit: AssistCopy.actionLimit)
        }
        guard let question, !question.isEmpty else { return nil }
        var destination = check.tapThrough.flatMap(HubDestination.init(rawValue:)) ?? fallback
        if check.id == "bucket_dollars" && bucketCapacity {
            destination = .dynacap
        }
        let owner = ownerLine(check.ownerRole, values: values, level: level)
        return AssistAction.open(
            id: check.id,
            question: question,
            owner: owner,
            buttonTitle: AssistCopy.screenTitle(destination),
            filters: stay,
            destination: destination
        )
    }

    private static func ownerLine(_ template: String?, values: [String: String], level: AssistScopeLevel) -> String {
        if level != .store {
            return AssistScope.levelOwner(level)
        }
        guard let template else { return "Store leader" }
        if let filled = AssistCopy.fill(template, values, limit: 80) { return filled }
        let stripped = template.replacingOccurrences(of: " and {shopper}", with: "")
        if !stripped.contains("{"), !stripped.isEmpty { return stripped }
        return "Store leader"
    }

    private struct CheckFacts {
        var flags: Set<String>
        var values: [String: String]
    }

    private static func checkFacts(
        section: MetricSection,
        summary: SectionSummary?,
        rows: [MetricRow],
        snapshot: AssistSnapshot,
        level: AssistScopeLevel
    ) -> CheckFacts {
        var flags: Set<String> = ["card"]
        var values: [String: String] = [:]
        let scored = AssistRank.scoringRows(rows)
        switch section {
        case .scheduleQuality:
            if level == .store, let row = scored.first {
                if let over = row.number("over_schedule_pct", "over_scheduled"), over > 0.05 {
                    flags.insert("storeOver")
                }
                if let under = row.number("under_schedule_pct", "under_scheduled"), under > 0.05 {
                    flags.insert("storeUnder")
                }
            } else if let summary {
                if summary.overScheduledCount > 0 {
                    flags.insert("overScheduled")
                    values["over"] = AssistCopy.grouped(summary.overScheduledCount)
                }
                if summary.underScheduledCount > 0 {
                    flags.insert("underScheduled")
                    values["under"] = AssistCopy.grouped(summary.underScheduledCount)
                }
            }
        case .missingItems, .preSubOOS:
            if let dept = hottestDept(scored) {
                flags.insert("hottestDept")
                values["dept"] = dept.name
                values["deptPct"] = AssistCopy.onePct(dept.pct)
            }
            if section == .missingItems {
                let stale = staleCount(snapshot, mapper: true)
                if stale > 0 {
                    flags.insert("staleMaps")
                    values["staleMaps"] = AssistCopy.grouped(stale)
                }
            }
            if section == .preSubOOS, let item = topPreSubItem(snapshot) {
                flags.insert("topItem")
                values["bpn"] = item.bpn
                values["presub"] = AssistCopy.onePct(item.pct)
            }
        case .pickPath:
            if let shopper = lowestPathShopper(snapshot) {
                flags.insert("namedShopper")
                values["shopper"] = shopper.name
                values["store"] = shopper.store
                values["compliance"] = AssistCopy.onePct(shopper.value)
            }
            let maps = staleCount(snapshot, mapper: true)
            let sequences = staleCount(snapshot, mapper: false)
            if maps > 0 {
                flags.insert("staleMaps")
                values["staleMaps"] = AssistCopy.grouped(maps)
            }
            if sequences > 0 {
                flags.insert("staleSeq")
                values["staleSeq"] = AssistCopy.grouped(sequences)
            }
        case .fiveStar:
            let starFlags = HeartbeatMath.fiveStarActionFlags(scored, includeAll: true)
            if let weakest = starFlags.max(by: { $0.stores < $1.stores }), weakest.stores > 0,
               let flag = weakestFlag(weakest.name) {
                flags.insert(flag)
                values["part"] = weakest.name
                if let shopper = shopperMissing(part: weakest.name, snapshot: snapshot) {
                    flags.insert("namedShopper")
                    values["shopper"] = shopper.name
                    values["store"] = shopper.store
                }
            }
        case .prepNotReady:
            if needsAction(snapshot.summaries[.pph]), let text = snapshot.summaries[.pph]?.headlineText, text != "—" {
                flags.insert("pphNeedsAction")
                values["pphAvg"] = text
            }
        case .dynacap:
            if scored.contains(where: { HeartbeatMath.dynacapAligned($0) != nil }) {
                flags.insert("hasCapacityRecs")
            }
            if needsAction(snapshot.summaries[.labor]), let text = snapshot.summaries[.labor]?.headlineText, text != "—" {
                flags.insert("laborNeedsAction")
                values["laborAvg"] = text
            }
        case .pph:
            if let shopper = slowestPPHShopper(snapshot) {
                flags.insert("namedShopper")
                values["shopper"] = shopper.name
                values["store"] = shopper.store
                values["pph"] = AssistCopy.one(shopper.value)
            }
            if needsAction(snapshot.summaries[.prepNotReady]), let text = snapshot.summaries[.prepNotReady]?.headlineText, text != "—" {
                flags.insert("prepNeedsAction")
                values["pnrAvg"] = text
            }
        case .labor:
            if let schedule = snapshot.summaries[.scheduleQuality], schedule.overScheduledCount > 0, needsAction(schedule) || schedule.overScheduledCount > 0 {
                flags.insert("scheduleNeedsAction")
                values["over"] = AssistCopy.grouped(schedule.overScheduledCount)
            } else if let schedule = snapshot.summaries[.scheduleQuality], schedule.storeCount > 0, !needsAction(schedule) {
                flags.insert("scheduleHolding")
            }
            if level == .store, let row = scored.first,
               let act = row.number("act_cost_pct"), let target = row.number("cost_trgt_pct"), act > target {
                flags.insert("storeCostOver")
                values["act"] = String(format: "%.2f%%", act)
                values["trgt"] = String(format: "%.2f%%", target)
            }
        case .lostRevenue:
            if let bucket = largestLossBucket(scored) {
                flags.insert(bucket.flag)
                flags.insert("bucketDollars")
                values["bucket"] = bucket.name
                values["dollars"] = HeartbeatFormat.money(bucket.dollars)
                values["bucketOwner"] = bucket.flag == "bucketOOS" ? "Grocery lead" : "Store leader"
            }
        case .sales:
            let off = scored.filter { HeartbeatMath.health(for: .sales, row: $0).needsAction }
            if off.contains(where: { ($0.number("sales_yoy_pct") ?? 1) < 0 }) {
                flags.insert("salesDown")
            } else if off.contains(where: { $0.number("sales_plan_pct") != nil }) {
                flags.insert("salesPlan")
            }
        default:
            break
        }
        return CheckFacts(flags: flags, values: values)
    }

    private static func needsAction(_ summary: SectionSummary?) -> Bool {
        guard let summary, summary.health != .none, summary.storeCount > 0 else { return false }
        return summary.riskCount + summary.watchCount > 0 || summary.health == .risk || summary.health == .watch
    }

    private static func hottestDept(_ rows: [MetricRow]) -> (name: String, pct: Double)? {
        var best: (String, Double)?
        for dept in MissingItemDept.allCases {
            guard let avg = HeartbeatMath.average(rows.compactMap { $0.number(dept.rawValue) }), avg > 0 else { continue }
            if best == nil || avg > best!.1 { best = (dept.short, avg) }
        }
        return best
    }

    private static func staleCount(_ snapshot: AssistSnapshot, mapper: Bool) -> Int {
        let aisle = snapshot.rows[.aisleMapper] ?? []
        let path = snapshot.rows[.pickPath] ?? []
        func count(_ rows: [MetricRow]) -> Int {
            rows.filter {
                let iso = mapper ? AisleMapperMath.mapperISO($0) : AisleMapperMath.sequenceISO($0)
                return AisleMapperMath.health(iso) == .risk
            }.count
        }
        let aisleCount = count(aisle)
        if aisleCount > 0 || aisle.contains(where: {
            (mapper ? AisleMapperMath.mapperISO($0) : AisleMapperMath.sequenceISO($0)) != nil
        }) {
            return aisleCount
        }
        return count(path)
    }

    private static func topPreSubItem(_ snapshot: AssistSnapshot) -> (bpn: String, pct: Double)? {
        let items = snapshot.rows[.preSubOOSItem] ?? []
        var best: (String, Double)?
        for row in items {
            guard let pct = row.number("presub_pct") else { continue }
            let bpn = ["bpn", "bpn_desc", "item"].compactMap { row.textPayload[$0]?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
            guard let bpn else { continue }
            if best == nil || pct > best!.1 { best = (bpn, pct) }
        }
        return best
    }

    private struct NamedValue {
        var name: String
        var store: String
        var value: Double
    }

    private static func lowestPathShopper(_ snapshot: AssistSnapshot) -> NamedValue? {
        let rows = (snapshot.rows[.pickPathPicker] ?? []).filter { HeartbeatMath.isRealPicker($0) }
        var best: NamedValue?
        for row in rows {
            guard let name = cleanName(row), let value = row.number("compliance_pct") else { continue }
            guard HeartbeatMath.health(for: .pickPathPicker, row: row).needsAction else { continue }
            if best == nil || value < best!.value {
                best = NamedValue(name: name, store: HeartbeatMath.canonicalStore(row.storeNumber), value: value)
            }
        }
        return best
    }

    private static func slowestPPHShopper(_ snapshot: AssistSnapshot) -> NamedValue? {
        let rows = (snapshot.rows[.pickerScorecard] ?? []).filter {
            HeartbeatMath.isRealPicker($0) && HeartbeatMath.pickerHasVolume($0)
        }
        var best: NamedValue?
        for row in rows {
            guard let name = cleanName(row), let value = row.number("pph"), value > 0 else { continue }
            guard HeartbeatMath.health(for: .pickerScorecard, row: row).needsAction else { continue }
            if best == nil || value < best!.value {
                best = NamedValue(name: name, store: HeartbeatMath.canonicalStore(row.storeNumber), value: value)
            }
        }
        return best
    }

    private static func weakestFlag(_ name: String) -> String? {
        switch name {
        case "Pre Sub OOS%": return "weakestPresub"
        case "OTT": return "weakestOTT"
        case "OTH 5%": return "weakestOTH"
        case "COE": return "weakestCOE"
        case "Flash": return "weakestFlash"
        default: return nil
        }
    }

    private static func shopperMissing(part: String, snapshot: AssistSnapshot) -> NamedValue? {
        let rows = (snapshot.rows[.pickerScorecard] ?? []).filter { HeartbeatMath.isRealPicker($0) }
        var best: (NamedValue, Int)?
        for row in rows {
            guard let name = cleanName(row) else { continue }
            let mark = starMark(part: part, row: row)
            guard mark != .full else { continue }
            guard partValue(part, row) != nil else { continue }
            let rank = mark == .none ? 2 : 1
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            if best == nil || rank > best!.1 {
                best = (NamedValue(name: name, store: store, value: 0), rank)
            }
        }
        return best?.0
    }

    private static func partValue(_ part: String, _ row: MetricRow) -> Double? {
        switch part {
        case "Flash": return row.number("flash_pct", "flash_star")
        case "COE": return row.number("coe_pct", "coe_star")
        case "OTT": return row.number("ott_pct", "ott_star")
        case "Pre Sub OOS%": return row.number("presub_pct", "presub_star")
        case "OTH 5%": return row.number("oth5_pct", "oth5_star")
        default: return nil
        }
    }

    private static func starMark(part: String, row: MetricRow) -> HeartbeatMath.StarMark {
        switch part {
        case "Flash": return HeartbeatMath.flashStar(row)
        case "COE": return HeartbeatMath.coeStar(row)
        case "OTT": return HeartbeatMath.ottStar(row)
        case "Pre Sub OOS%": return HeartbeatMath.presubStar(row)
        case "OTH 5%": return HeartbeatMath.othStar(row)
        default: return .full
        }
    }

    private static func largestLossBucket(_ rows: [MetricRow]) -> (name: String, dollars: Double, flag: String)? {
        let specs: [(String, String, String)] = [
            ("Post Sub OOS Foregone", "post_sub_oos_foregone", "bucketOOS"),
            ("Refund $ Fulfillment", "refund_lost", "bucketRefund"),
            ("Cancelled Orders LDAP", "cancelled_lost", "bucketCancel"),
            ("Kill Switch Lost Sales", "kill_switch_lost", "bucketKill"),
            ("Reduced Capacity Missed Sales", "missed_sales", "bucketCapacity"),
        ]
        var best: (String, Double, String)?
        for spec in specs {
            var dollars = HeartbeatMath.lostRevenueTODollars(rows, key: spec.1)
            if dollars == 0, spec.1 == "missed_sales" {
                dollars = HeartbeatMath.lostRevenueTODollars(rows, key: "reduced_capacity")
            }
            guard dollars > 0 else { continue }
            if best == nil || dollars > best!.1 {
                best = (spec.0, dollars, spec.2)
            }
        }
        return best
    }

    private static func childMetricCounts(
        section: MetricSection,
        child: AssistChild,
        snapshot: AssistSnapshot
    ) -> (Int, Int)? {
        let rows = AssistRank.scoringRows(snapshot.rows[section] ?? []).filter {
            AssistScope.grainKey($0, grain: child.grain) == child.key
        }
        guard !rows.isEmpty else { return nil }
        let summary = HeartbeatMath.summarize(section, rows: rows, upload: nil)
        return (summary.riskCount, summary.storeCount)
    }

    private static func childChange(_ child: AssistChild) -> AssistFilterChange {
        switch child.grain {
        case .region: return .region(child.key)
        case .division: return .division(child.key)
        case .district: return .district(child.key)
        case .om: return .om(child.key)
        case .store: return .store(child.key)
        }
    }

    private static func applying(_ change: AssistFilterChange, on lens: DashboardFilters) -> DashboardFilters {
        switch change {
        case .none, .clear:
            return lens
        case .region(let name):
            var next = DashboardFilters()
            next.region = name
            return next
        case .division(let name):
            var next = DashboardFilters()
            next.region = MarketRegion.containing(name)?.rawValue ?? ""
            next.division = name
            return next
        case .district(let name):
            var next = lens
            next.district = name
            next.om = ""
            next.store = ""
            return next
        case .om(let name):
            var next = lens
            next.om = name
            next.store = ""
            return next
        case .store(let name):
            var next = lens
            next.store = HeartbeatMath.canonicalStore(name)
            return next
        case .commit(let filters):
            return filters
        }
    }

    static func rankChildren(_ snapshot: AssistSnapshot, grain: AssistChildGrain) -> [AssistChild] {
        let metrics = MetricSection.dashboardCards.filter { $0 != .pickerScorecard }
        var groups: [String: [MetricSection: [MetricRow]]] = [:]
        var names: [String: String] = [:]
        for section in metrics {
            for row in AssistRank.scoringRows(snapshot.rows[section] ?? []) {
                guard let key = AssistScope.grainKey(row, grain: grain) else { continue }
                if names[key] == nil, let storeName = row.storeName, !storeName.isEmpty {
                    names[key] = storeName
                }
                groups[key, default: [:]][section, default: []].append(row)
            }
        }
        var ranked: [AssistChild] = []
        for (key, bySection) in groups {
            var total = 0.0
            var riskStores = Set<String>()
            var allStores = Set<String>()
            var best: (MetricSection, Double, Int, Int)?
            for section in metrics {
                let rows = bySection[section] ?? []
                guard !rows.isEmpty else { continue }
                let summary = HeartbeatMath.summarize(section, rows: rows, upload: nil)
                for row in rows {
                    let store = HeartbeatMath.canonicalStore(row.storeNumber)
                    guard !store.isEmpty else { continue }
                    allStores.insert(store)
                    if HeartbeatMath.health(for: section, row: row) == .risk {
                        riskStores.insert(store)
                    }
                }
                let distance = AssistRank.distance(section: section, rows: rows)
                guard let scored = AssistRank.score(AssistRank.Input(
                    section: section,
                    health: summary.health,
                    risk: summary.riskCount,
                    watch: summary.watchCount,
                    distance: distance,
                    storeCount: summary.storeCount
                )) else { continue }
                total += scored.score
                if best == nil || scored.score > best!.1 {
                    best = (section, scored.score, summary.riskCount, summary.storeCount)
                }
            }
            let label = AssistScope.childLabel(
                grain: grain,
                key: key,
                storeName: names[key] ?? AssistScope.rosterName(key, roster: snapshot.rosterStores)
            )
            ranked.append(AssistChild(
                key: key,
                label: label,
                score: AssistRank.round4(total),
                storesAtRisk: riskStores.count,
                storeCount: max(allStores.count, 1),
                worstMetric: best?.0,
                worstRisk: best?.2 ?? 0,
                worstStores: best?.3 ?? 0,
                grain: grain
            ))
        }
        ranked.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.storesAtRisk != rhs.storesAtRisk { return lhs.storesAtRisk > rhs.storesAtRisk }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
        return ranked
    }

    private static func childIssue(
        _ child: AssistChild,
        rank: Int,
        snapshot: AssistSnapshot,
        playbook: AssistPlaybook.File,
        base: DashboardFilters,
        scope: String,
        first: Bool
    ) -> AssistIssue {
        let filters = applying(childChange(child), on: snapshot.filters == base ? snapshot.filters : snapshot.filters)
        let openText = AssistCopy.fill(playbook.shared.childOpen, ["child": child.label], limit: AssistCopy.actionLimit) ?? "Open \(child.label)"
        let metricName = child.worstMetric?.overviewLead ?? "the worst scorecard"
        let workText = AssistCopy.fill(
            playbook.shared.childWork,
            ["metric": metricName, "child": child.label],
            limit: AssistCopy.actionLimit
        )
        let destination = child.worstMetric.map { HubDestination.from(section: $0) } ?? .dashboard
        var checks: [AssistAction] = [
            AssistAction.open(
                id: "\(child.key)-open",
                question: openText,
                owner: AssistScope.childOwner(child.grain),
                buttonTitle: AssistCopy.screenTitle(.dashboard),
                filters: filters,
                destination: .dashboard
            ),
        ]
        if let workText, child.worstMetric != nil {
            checks.append(AssistAction.open(
                id: "\(child.key)-work",
                question: workText,
                owner: AssistScope.childOwner(child.grain),
                buttonTitle: AssistCopy.screenTitle(destination),
                filters: filters,
                destination: destination
            ))
        }
        var facts: [AssistFact] = []
        if let metric = child.worstMetric {
            facts.append(AssistFact(label: "Worst scorecard", value: metric.overviewLead))
            facts.append(AssistFact(
                label: "Its stores at risk",
                value: "\(AssistCopy.grouped(child.worstRisk)) of \(AssistCopy.grouped(child.worstStores))"
            ))
        }
        let headline = first ? "\(child.label) has the most stores in trouble" : "\(child.label) is next"
        let footer = "\(openText) ›"
        let footerAction = AssistAction.open(
            id: "\(child.key)-footer",
            question: footer,
            owner: "",
            buttonTitle: footer,
            filters: filters,
            destination: .dashboard
        )
        return AssistIssue(
            id: "child-\(child.grain)-\(child.key)",
            rank: rank,
            title: child.label,
            statusText: child.storesAtRisk > 0 ? "At risk" : "Watch",
            statusSymbol: child.storesAtRisk > 0 ? "exclamationmark.triangle.fill" : "eye.fill",
            statusHealth: child.storesAtRisk > 0 ? .risk : .watch,
            headline: clip(headline, AssistCopy.headlineLimit),
            numberLabel: "Stores with an at-risk scorecard",
            numberValue: "\(AssistCopy.grouped(child.storesAtRisk)) of \(AssistCopy.grouped(child.storeCount))",
            facts: facts,
            scope: "Scope: \(scope)",
            footer: footer,
            footerAction: footerAction,
            checks: checks,
            rankedLine: "\(child.label): \(AssistCopy.grouped(child.storesAtRisk)) stores with an at-risk scorecard.",
            accessibilityLabel: "Rank \(rank), \(child.label). \(headline). \(child.storesAtRisk) of \(child.storeCount) stores with an at-risk scorecard."
        )
    }

    private static func shopperRows(_ snapshot: AssistSnapshot) -> [MetricRow] {
        let rows = (snapshot.rows[.pickerScorecard] ?? []).filter {
            HeartbeatMath.isRealPicker($0) && HeartbeatMath.pickerHasVolume($0)
        }
        return rows.filter { row in
            HeartbeatMath.pickerMetricReadout(row).contains { $0.health.needsAction }
        }.sorted { lhs, rhs in
            let left = lhs.number("pph") ?? .greatestFiniteMagnitude
            let right = rhs.number("pph") ?? .greatestFiniteMagnitude
            return left < right
        }
    }

    private static func shopperIssue(
        _ row: MetricRow,
        rank: Int,
        snapshot: AssistSnapshot,
        playbook: AssistPlaybook.File?,
        base: DashboardFilters,
        level: AssistScopeLevel
    ) -> AssistIssue? {
        _ = base
        guard let name = cleanName(row) else { return nil }
        let failing = HeartbeatMath.pickerMetricReadout(row).filter { $0.health.needsAction }.map(\.name)
        guard !failing.isEmpty else { return nil }
        let store = HeartbeatMath.canonicalStore(row.storeNumber)
        let items = failing.prefix(3).joined(separator: ", ")
        var filters = snapshot.filters
        filters.store = store
        let stay: DashboardFilters? = filters
        var checks: [AssistAction] = []
        if let check = playbook?.metrics[MetricSection.pickerScorecard.rawValue]?.checks.first,
           let question = AssistCopy.fill(check.question, ["shopper": name, "items": items, "store": store], limit: AssistCopy.actionLimit) {
            checks.append(AssistAction.open(
                id: "shopper-\(rank)",
                question: question,
                owner: level == .store ? (check.ownerRole ?? "Store leader") : AssistScope.levelOwner(level),
                buttonTitle: AssistCopy.screenTitle(.pickerScorecard),
                filters: stay ?? filters,
                destination: .pickerScorecard
            ))
        }
        let headline = clip("\(name) at store \(store)", AssistCopy.headlineLimit)
        let footer = AssistCopy.screenTitle(.pickerScorecard)
        return AssistIssue(
            id: "shopper-\(store)-\(name)",
            rank: rank,
            title: "Picker",
            statusText: "At risk",
            statusSymbol: "person.fill",
            statusHealth: .risk,
            headline: headline,
            numberLabel: "Failing",
            numberValue: items,
            facts: [AssistFact(label: "Store", value: store)],
            scope: "Scope: \(AssistScope.scopeLine(snapshot.filters, roster: snapshot.rosterStores))",
            footer: footer,
            footerAction: AssistAction.open(
                id: "shopper-footer-\(rank)",
                question: footer,
                owner: "",
                buttonTitle: footer,
                filters: stay ?? filters,
                destination: .pickerScorecard
            ),
            checks: checks,
            rankedLine: "\(name) at store \(store): \(items).",
            accessibilityLabel: "\(name) at store \(store). \(items)."
        )
    }

    private static func chipList(_ snapshot: AssistSnapshot, ranked: [AssistRank.Scored], level: AssistScopeLevel) -> [String] {
        let storeScope = level == .store
        var chips: [String] = []
        func add(_ text: String) {
            guard chips.count < 4, let chip = AssistCopy.chip(text), !chips.contains(chip) else { return }
            chips.append(chip)
        }
        let opportunity = pickerOpportunity(snapshot)
        if ranked.isEmpty {
            if rankedWatch(snapshot) > 0 {
                add(storeScope ? "What's on watch here?" : "What's on watch?")
            }
            if let unit = AssistScope.childUnitWord(level) {
                add("Which \(unit) is worst?")
            }
            if opportunity > 0 {
                add(storeScope ? "Which shoppers need coaching here?" : "Which shoppers need coaching?")
            }
            return chips
        }
        add(storeScope ? "What should this store fix first?" : "What should we fix first?")
        if storeScope {
            if opportunity > 0 {
                add("Which shoppers need coaching here?")
            } else {
                add("What's on watch here?")
            }
        } else if let unit = AssistScope.childUnitWord(level) {
            add("Which \(unit) is worst?")
        }
        if let top = ranked.first {
            add("Tell me more about \(top.section.overviewLead)")
        }
        if storeScope {
            if chips.contains("What's on watch here?") == false {
                add("What's on watch here?")
            }
        } else if opportunity > 0 {
            add("Which shoppers need coaching?")
        } else {
            add("What's on watch?")
        }
        return chips
    }

    private static func rankedWatch(_ snapshot: AssistSnapshot) -> Int {
        MetricSection.dashboardCards.reduce(0) { partial, section in
            guard section != .pickerScorecard else { return partial }
            return partial + (snapshot.summaries[section]?.watchCount ?? 0)
        }
    }

    private static func pickerOpportunity(_ snapshot: AssistSnapshot) -> Int {
        let rows = snapshot.rows[.pickerScorecard] ?? []
        if rows.isEmpty {
            return snapshot.summaries[.pickerScorecard]?.riskCount ?? 0
        }
        return HeartbeatMath.pickerBoard(rows).opportunityCount
    }

    private static func emptyNote(_ snapshot: AssistSnapshot) -> String? {
        let missing = MetricSection.dashboardCards.filter { section in
            section != .pickerScorecard && (snapshot.summaries[section]?.storeCount ?? 0) == 0
        }.map(\.overviewLead)
        guard !missing.isEmpty else { return nil }
        return "No data here for: \(missing.joined(separator: ", "))."
    }

    private static func staleBanner(_ snapshot: AssistSnapshot) -> String? {
        guard let newest = snapshot.packUploads.max() else { return nil }
        guard snapshot.now.timeIntervalSince(newest) > AssistCopy.staleInterval else { return nil }
        let when = blank(snapshot.dataWindow) ?? shortDate(isoOrDate(newest))
        return "These numbers are from \(when). Today's pack hasn't loaded yet."
    }

    private static func closestToGoal(_ snapshot: AssistSnapshot, sections: [MetricSection]) -> String? {
        var best: (String, Double)?
        for section in sections {
            guard let summary = snapshot.summaries[section], let room = headroom(section, summary), room >= 0 else { continue }
            let text = "\(section.overviewLead) at \(summary.headlineText) (goal \(AssistCopy.goalFact(section)))"
            if best == nil || room < best!.1 { best = (text, room) }
        }
        return best?.0
    }

    private static func headroom(_ section: MetricSection, _ summary: SectionSummary) -> Double? {
        guard let avg = summary.headline else { return nil }
        switch section {
        case .pickPath: return (avg - HeartbeatMath.pickPathGoal) / 10
        case .missingItems, .preSubOOS: return (HeartbeatMath.missingItemsGoal - avg) / 1.5
        case .prepNotReady: return (HeartbeatMath.pnrGoal - avg) / 0.6
        case .dynacap: return (avg - HeartbeatMath.dynacapGoal) / 5
        case .scheduleQuality: return (avg - HeartbeatMath.scheduleGoal) / 5
        case .pph: return (avg - HeartbeatMath.pphGoal) / 6
        case .labor: return (0 - avg) / HeartbeatMath.laborWatch
        case .fiveStar: return (avg - 4.5) / 0.5
        case .lostRevenue:
            guard let pct = summary.lostRevenuePct else { return nil }
            return (HeartbeatMath.lostRevenueGood - pct) / 2
        case .sales:
            guard let yoy = summary.salesYoyPct else { return nil }
            return yoy / 3
        default:
            return nil
        }
    }

    private static func footerTitle(section: MetricSection, scored: AssistRank.Scored, level: AssistScopeLevel) -> String {
        if level == .store || scored.risk == 0 {
            return AssistCopy.screenTitle(HubDestination.from(section: section))
        }
        return "See all \(AssistCopy.stores(scored.risk)) ›"
    }

    private static func resolvedWord(_ grain: AssistChildGrain) -> String {
        switch grain {
        case .region: return "region"
        case .division: return "market"
        case .district: return "district"
        case .om: return "OM"
        case .store: return "store"
        }
    }

    private static func cleanName(_ row: MetricRow) -> String? {
        let name = row.shopperName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name.compare("Unknown shopper", options: .caseInsensitive) == .orderedSame {
            return nil
        }
        return name
    }

    private static func clip(_ text: String, _ limit: Int) -> String {
        if text.count <= limit { return text }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: limit)
        var cut = String(trimmed[..<end])
        if let space = cut.lastIndex(of: " "), cut.distance(from: cut.startIndex, to: space) > 24 {
            cut = String(cut[..<space])
        }
        return cut
    }

    private static func blank(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func shortDate(_ raw: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: String(raw.prefix(10))) else { return raw }
        return isoOrDate(date)
    }

    private static func isoOrDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
