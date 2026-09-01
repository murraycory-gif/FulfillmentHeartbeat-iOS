import Foundation

enum MetricSection: String, CaseIterable, Identifiable, Codable, Hashable {
    case fiveStar = "five_star"
    case pickPath = "pick_path"
    case pickPathPicker = "pick_path_picker"
    case prepNotReady = "prep_not_ready"
    case dynacap = "dynacap"
    case scheduleQuality = "schedule_quality"
    case pph = "pph"
    case labor = "labor"
    case pickerScorecard = "picker_scorecard"
    case lostRevenue = "lost_revenue"
    case missingItems = "missing_items"
    case aisleMapper = "aisle_mapper"
    case preSubOOS = "pre_sub_oos"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fiveStar: return "5 Star Metrics"
        case .pickPath: return "Pick Path Compliance"
        case .pickPathPicker: return "Pick Path Compliance Picker"
        case .prepNotReady: return "Prep Not Ready"
        case .dynacap: return "Dynacap Setting"
        case .scheduleQuality: return "Schedule Quality"
        case .pph: return "PPH Pure Picks Per Hour"
        case .labor: return "Labor"
        case .pickerScorecard: return "Picker ScoreCard"
        case .lostRevenue: return "Loss Revenue"
        case .missingItems: return "Missing Items"
        case .aisleMapper: return "Aisle Mapper"
        case .preSubOOS: return "Pre-Sub OOS"
        }
    }

    var short: String {
        switch self {
        case .fiveStar: return "5 Star"
        case .pickPath: return "Pick Path Compliance"
        case .pickPathPicker: return "Path Picker"
        case .prepNotReady: return "Prep NR"
        case .dynacap: return "Dynacap"
        case .scheduleQuality: return "Schedule"
        case .pph: return "PPH"
        case .labor: return "Labor"
        case .pickerScorecard: return "Pickers"
        case .lostRevenue: return "Lost Rev"
        case .missingItems: return "MI"
        case .aisleMapper: return "Aisle Map"
        case .preSubOOS: return "Pre-Sub"
        }
    }

    var blurb: String {
        switch self {
        case .fiveStar: return "Store-level star rating from Flash, Presubs, COE, OTT, and OTH5. Upload Star Ratings by Store."
        case .pickPath: return "Store-level path compliance. Upload the STORE_ID WEEK_ID export."
        case .pickPathPicker: return "Picker-level path compliance. Upload the EMPLOYEE_ALTERNATE_ID WEEK_ID export. Pickers show under each store on Pick Path."
        case .prepNotReady: return "Share of pick hours lost to prep not ready. Upload the DATE / STORE Total export."
        case .dynacap: return "Pieces per hour we allow down to the picker. Upload the Overall Capacity Summary."
        case .scheduleQuality: return "How tightly the labor plan matches the work. Upload Optimized Departments Week Store."
        case .pph: return "Pure picks completed per labor hour. Upload the DATE / STORE Total export."
        case .labor: return "Upload LABOR Store View Thru Week.xlsx for store totals. Optional: Total company day file for week and day drill-in. Each upload replaces the last Labor load."
        case .pickerScorecard: return "Shopper-level totals for PPH, Presubs, OOS, pick hours, subs, orders, DUG, OTH eligibility, OTH5, OTT, and refunds."
        case .lostRevenue: return "Total lost revenue opportunity by store. Upload Breakdown Week.xlsx from the Lost Revenue report."
        case .missingItems: return "Share of items without an aisle in store tag subscription data. Upload the department-wise MI export. 5% or less is healthy."
        case .aisleMapper: return "Latest aisle mapper and aisle sequence update by store. Upload the Latest Aisle Mapper and Sequence Update Date By Store export. Dates show on the Pick Path store table."
        case .preSubOOS: return "Pre-substitution OOS% by store and department. Upload Pre Substitution OOS% Division Area Store View. 5% or less is healthy."
        }
    }

    var expectedMetrics: String {
        switch self {
        case .fiveStar: return "Store · Division · OM · District · Total Rating · Flash · Presubs · COE · OTT · OTH5"
        case .pickPath: return "WEEK_ID · STORE_ID · Pick Path Compliance · Orders · Pure PPH (Total columns)"
        case .pickPathPicker: return "WEEK_ID · EMPLOYEE_ALTERNATE_ID · Pick Path Compliance · Orders · Pure PPH (Total columns)"
        case .prepNotReady: return "DATE · DIVISION · District · OM · Store · Net Prep Not Ready Hours % (Total)"
        case .dynacap: return "DISTRICT · Total Pieces/Total Hrs · DPA Dynacap · Utilization %"
        case .scheduleQuality: return "Division · District · Store · Schedule Efficiency · Under % · Over %"
        case .pph: return "DATE · DIVISION · DISTRICT · OM_AREA · OM_ID · STORE · Pure PPH (Total)"
        case .labor: return "STORE_ID · Sch Effi% · Empower Hrs · Sch_Hrs · ActHrs · Earned Hrs · CostTrgt% · ActCost% · Target vs Actual% · Charged Hrs  (or the day file with WEEK_ID · D_DATE)"
        case .pickerScorecard: return "STORE · PICKER · Total Pure PPH · Presub · OOS · Hours · Subs · Orders · DUG · OTH Elig · OTH5 · OTT · Refund"
        case .lostRevenue: return "Store · eComm Sales · Total Lost Revenue (Total Opportunity) · Total Lost Revenue % (Total Opportunity)"
        case .missingItems: return "Division · District · OM · Store · 301 Grocery · 303 Alcohol · 304 Pharmacy · 306 Food Service · 309 Deli · 311 GM/HBC · 314 Dairy · 315 Floral · 316 Bakery · 317 Frozen · 328 Coffee Kiosk · 329 Produce · 330 Seafood · 333 Meat · 336 Bakery Pkgd · Total"
        case .aisleMapper: return "Division · District · OM · Store · Latest Aisle Mapper Update Date · Latest Aisle Sequence Update Date"
        case .preSubOOS: return "STORE_ID · Alcohol · Bakery · Bakery Pkgd · Dairy · Deli · Floral · Food Service · Frozen · GM/HBC · Grocery · Meat · Pharmacy · Produce · Seafood · Total Pre-Sub OOS%"
        }
    }

    var bannerTitle: String {
        switch self {
        case .fiveStar: return "5 Star ScoreCard"
        case .pickPath, .pickPathPicker: return "Pick Path Compliance ScoreCard"
        case .prepNotReady: return "Prep Not Ready ScoreCard"
        case .dynacap: return "Dynacap Settings ScoreCard"
        case .scheduleQuality: return "Schedule Quality ScoreCard"
        case .pph: return "PPH Pure Picks Per Hour"
        case .labor: return "Labor ScoreCard"
        case .pickerScorecard: return "Picker ScoreCard"
        case .lostRevenue: return "Loss Revenue ScoreCard"
        case .missingItems: return "Missing Items ScoreCard"
        case .aisleMapper: return "Aisle Mapper"
        case .preSubOOS: return "Pre-Sub OOS ScoreCard"
        }
    }

    var symbol: String {
        switch self {
        case .fiveStar: return "star.fill"
        case .pickPath: return "point.topleft.down.to.point.bottomright.curvepath"
        case .pickPathPicker: return "person.crop.circle.badge.checkmark"
        case .prepNotReady: return "shippingbox"
        case .dynacap: return "slider.horizontal.3"
        case .scheduleQuality: return "calendar.badge.clock"
        case .pph: return "speedometer"
        case .labor: return "dollarsign.circle.fill"
        case .pickerScorecard: return "person.2.fill"
        case .lostRevenue: return "chart.line.downtrend.xyaxis"
        case .missingItems: return "tag.slash.fill"
        case .aisleMapper: return "map.fill"
        case .preSubOOS: return "cart.badge.minus"
        }
    }

    var sourceLink: URL? {
        switch self {
        case .fiveStar:
            return URL(string: "https://app.powerbi.com/groups/me/apps/d973ff03-651f-4e52-9e7a-8e5bff14b5e6/reports/73aafb1b-7a54-4c96-af93-4736442edc42/ReportSection5f4b54422e8bd962800c?experience=power-bi")
        case .pickerScorecard:
            return URL(string: "https://app.powerbi.com/groups/b49dfeed-3984-42bf-82ef-d591fb235e2a/reports/06359e3e-e6c3-40e3-9576-de9f22b6aff1/ReportSectioncbfdeb0d3f0df83d6a16?experience=power-bi")
        case .pickPath, .pickPathPicker:
            return URL(string: "https://app.powerbi.com/groups/b49dfeed-3984-42bf-82ef-d591fb235e2a/reports/b6400525-ba91-4f3d-bfba-3338a0b52fa7/ReportSection73f793f7ab37dd823bd7?experience=power-bi")
        case .pph:
            return URL(string: "https://app.powerbi.com/groups/me/apps/d973ff03-651f-4e52-9e7a-8e5bff14b5e6/reports/efe509e3-0bb6-4f54-9528-feb8fa1dc5fe/ReportSectionb4ac0532033cd00ce85a?experience=power-bi")
        case .prepNotReady:
            return URL(string: "https://app.powerbi.com/groups/me/apps/d973ff03-651f-4e52-9e7a-8e5bff14b5e6/reports/cffa468f-571d-438d-8174-7b6c155d542c/52d096ca430790708916?experience=power-bi")
        case .labor:
            return URL(string: "https://app.powerbi.com/groups/b49dfeed-3984-42bf-82ef-d591fb235e2a/reports/b4af7dad-92e1-4e78-a222-39b97c245e44/ReportSectionceac564838e55ea8368a?experience=power-bi")
        case .dynacap:
            return URL(string: "https://app.powerbi.com/groups/me/apps/d973ff03-651f-4e52-9e7a-8e5bff14b5e6/reports/c7805592-9273-416c-a02f-edc74e0a75d0/ReportSection7246ca8b726f69d2ad9d?experience=power-bi&clientSideAuth=0")
        case .lostRevenue:
            return URL(string: "https://app.powerbi.com/groups/me/apps/d973ff03-651f-4e52-9e7a-8e5bff14b5e6/reports/dac4848e-a28a-4e12-bfbb-b386da90f344/e57401a67b0f2379a0b3?ctid=b7f604a0-00a9-4188-9248-42f3a5aac2e9&experience=power-bi")
        case .missingItems:
            return URL(string: "https://app.powerbi.com/groups/me/apps/d973ff03-651f-4e52-9e7a-8e5bff14b5e6/reports/47829fe7-c57f-4c65-a557-f35c99a1e851/2a870f3cf2c35df0a38b?ctid=b7f604a0-00a9-4188-9248-42f3a5aac2e9&experience=power-bi")
        case .aisleMapper:
            return URL(string: "https://app.powerbi.com/groups/me/apps/d973ff03-651f-4e52-9e7a-8e5bff14b5e6/reports/c13fc8a7-5492-4d39-bd1b-8091e2f5f99a/bc42d1e4f9041554fbad?ctid=b7f604a0-00a9-4188-9248-42f3a5aac2e9&experience=power-bi&clientSideAuth=0")
        case .preSubOOS:
            return URL(string: "https://app.powerbi.com/groups/me/apps/d973ff03-651f-4e52-9e7a-8e5bff14b5e6/reports/73aafb1b-7a54-4c96-af93-4736442edc42/ReportSection5f4b54422e8bd962800c?experience=power-bi")
        default:
            return nil
        }
    }

    static var dashboardCards: [MetricSection] {
        [.lostRevenue, .missingItems, .fiveStar, .preSubOOS, .pickPath, .prepNotReady, .dynacap, .scheduleQuality, .pickerScorecard, .pph, .labor]
    }

    static var uploadOrder: [MetricSection] {
        [.lostRevenue, .missingItems, .fiveStar, .preSubOOS, .pickPath, .pickPathPicker, .aisleMapper, .prepNotReady, .dynacap, .scheduleQuality, .pph, .labor, .pickerScorecard]
    }

    static var checklistSections: [MetricSection] {
        dashboardCards
    }
}

enum MissingItemDept: String, CaseIterable, Identifiable, Hashable {
    case grocery = "mi_grocery"
    case alcohol = "mi_alcohol"
    case pharmacy = "mi_pharmacy"
    case foodService = "mi_food_service"
    case deli = "mi_deli"
    case gmHbc = "mi_gm_hbc"
    case dairy = "mi_dairy"
    case floral = "mi_floral"
    case bakery = "mi_bakery"
    case frozen = "mi_frozen"
    case coffee = "mi_coffee"
    case produce = "mi_produce"
    case seafood = "mi_seafood"
    case meat = "mi_meat"
    case bakeryPkgd = "mi_bakery_pkgd"

    var id: String { rawValue }

    static let totalKey = "mi_pct"

    var code: String {
        switch self {
        case .grocery: return "301"
        case .alcohol: return "303"
        case .pharmacy: return "304"
        case .foodService: return "306"
        case .deli: return "309"
        case .gmHbc: return "311"
        case .dairy: return "314"
        case .floral: return "315"
        case .bakery: return "316"
        case .frozen: return "317"
        case .coffee: return "328"
        case .produce: return "329"
        case .seafood: return "330"
        case .meat: return "333"
        case .bakeryPkgd: return "336"
        }
    }

    var short: String {
        switch self {
        case .grocery: return "Grocery"
        case .alcohol: return "Alcohol"
        case .pharmacy: return "Pharmacy"
        case .foodService: return "Food Svc"
        case .deli: return "Deli"
        case .gmHbc: return "GM/HBC"
        case .dairy: return "Dairy"
        case .floral: return "Floral"
        case .bakery: return "Bakery"
        case .frozen: return "Frozen"
        case .coffee: return "Coffee"
        case .produce: return "Produce"
        case .seafood: return "Seafood"
        case .meat: return "Meat"
        case .bakeryPkgd: return "Bakery Pkgd"
        }
    }

    var title: String { "\(code) \(short)" }

    var chip: String { short }

    static func match(_ raw: String) -> MissingItemDept? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let compact = trimmed.lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
        if compact.isEmpty || compact == "departmentdesc" { return nil }
        if compact.hasPrefix("336") || compact.contains("bakerypkgd") || compact.contains("pkgdoutside") || compact.contains("pkgd") {
            return .bakeryPkgd
        }
        if compact.hasPrefix("317") || compact.contains("frozen") { return .frozen }
        if compact.hasPrefix("301") || compact == "grocery" || (compact.contains("grocery") && !compact.contains("frozen")) {
            return .grocery
        }
        if compact.hasPrefix("303") || compact.contains("alcohol") { return .alcohol }
        if compact.hasPrefix("304") || compact.contains("pharmacy") { return .pharmacy }
        if compact.hasPrefix("306") || compact.contains("foodservice") { return .foodService }
        if compact.hasPrefix("309") || compact.contains("delicatessen") || compact.contains("deli") { return .deli }
        if compact.hasPrefix("311") || compact.contains("gmhbc") || compact.contains("hbc") { return .gmHbc }
        if compact.hasPrefix("314") || compact.contains("dairy") { return .dairy }
        if compact.hasPrefix("315") || compact.contains("floral") { return .floral }
        if compact.hasPrefix("316") || compact.contains("bakery") { return .bakery }
        if compact.hasPrefix("328") || compact.contains("coffee") { return .coffee }
        if compact.hasPrefix("329") || compact.contains("produce") { return .produce }
        if compact.hasPrefix("330") || compact.contains("seafood") { return .seafood }
        if compact.hasPrefix("333") || compact == "meat" || compact.hasSuffix("meat") { return .meat }
        return nil
    }

    static func isTotalHeader(_ raw: String) -> Bool {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("total") == .orderedSame
    }

    static func visible(from selected: Set<MissingItemDept>) -> [MissingItemDept] {
        if selected.isEmpty { return Array(allCases) }
        return allCases.filter { selected.contains($0) }
    }
}

enum AisleMapperMath {
    static let mapperKey = "aisle_mapper_date"
    static let sequenceKey = "aisle_sequence_date"
    static let freshDays = 30.0
    static let watchDays = 90.0

    static func iso(_ row: MetricRow, key: String) -> String? {
        let raw = row.textPayload[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? nil : raw
    }

    static func mapperISO(_ row: MetricRow) -> String? { iso(row, key: mapperKey) }
    static func sequenceISO(_ row: MetricRow) -> String? { iso(row, key: sequenceKey) }

    static func health(_ iso: String?) -> Health {
        guard let days = ageDays(iso) else { return .none }
        if days <= freshDays { return .good }
        if days <= watchDays { return .watch }
        return .risk
    }

    static func oldest(_ values: [String?]) -> String? {
        let clean = values.compactMap { $0 }.filter { !$0.isEmpty }
        return clean.min()
    }

    static func ageDays(_ iso: String?, now: Date = Date()) -> Double? {
        guard let iso, iso.count >= 10 else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: String(iso.prefix(10))) else { return nil }
        return now.timeIntervalSince(date) / 86_400
    }
}

enum Health: String, Codable, Equatable, Sendable {
    case good, watch, risk, none

    var label: String {
        switch self {
        case .good: return "Healthy"
        case .watch: return "Watch"
        case .risk: return "At risk"
        case .none: return "No data"
        }
    }

    var needsAction: Bool { self == .risk || self == .watch }

    /// Dashboard callouts: At Risk, then Watch, then Healthy, then no data.
    var dashboardRank: Int {
        switch self {
        case .risk: return 0
        case .watch: return 1
        case .good: return 2
        case .none: return 3
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
    var validation: String?

    init(
        id: UUID = UUID(),
        section: MetricSection,
        filename: String,
        rowCount: Int,
        uploadedAt: Date = Date(),
        validation: String? = nil
    ) {
        self.id = id
        self.section = section
        self.filename = filename
        self.rowCount = rowCount
        self.uploadedAt = uploadedAt
        self.validation = validation
    }
}

struct SectionSummary: Identifiable, Equatable {
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
    var underScheduledCount: Int = 0
    var overScheduledCount: Int = 0
    var lostRevenuePct: Double? = nil

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
            return HeartbeatFormat.num(headline)
        }
        if section == .lostRevenue {
            return HeartbeatFormat.money(headline)
        }
        if section == .labor {
            return String(format: "%.2f%%", headline)
        }
        return String(format: "%.1f%%", headline)
    }
}

enum HeartbeatMath {
    static func dashboardCallouts(_ summaries: [SectionSummary]) -> [SectionSummary] {
        let order = Dictionary(uniqueKeysWithValues: MetricSection.dashboardCards.enumerated().map { ($0.element, $0.offset) })
        return summaries.sorted { lhs, rhs in
            let lhsFiveRisk = lhs.section == .fiveStar && lhs.health == .risk
            let rhsFiveRisk = rhs.section == .fiveStar && rhs.health == .risk
            if lhsFiveRisk != rhsFiveRisk { return lhsFiveRisk }
            if lhs.health.dashboardRank != rhs.health.dashboardRank {
                return lhs.health.dashboardRank < rhs.health.dashboardRank
            }
            if lhs.riskCount != rhs.riskCount { return lhs.riskCount > rhs.riskCount }
            if lhs.watchCount != rhs.watchCount { return lhs.watchCount > rhs.watchCount }
            return (order[lhs.section] ?? 99) < (order[rhs.section] ?? 99)
        }
    }

    static func dashboardCallouts(_ summaries: [SectionSummary], role: HeartbeatRole?, storeScoped: Bool = false) -> [SectionSummary] {
        var cards = dashboardCallouts(summaries)
        if role == .evp {
            cards.removeAll { $0.section == .pickerScorecard }
            return pinnedCallouts(cards, pin: [.lostRevenue, .fiveStar, .dynacap], restRiskWatch: !storeScoped)
        }
        if role == .director {
            return pinnedCallouts(cards, pin: [.lostRevenue, .fiveStar, .labor, .dynacap, .pickerScorecard], restRiskWatch: !storeScoped)
        }
        if role == .districtManager {
            return pinnedCallouts(cards, pin: [.lostRevenue, .fiveStar, .labor, .dynacap], restRiskWatch: !storeScoped)
        }
        if storeScoped { return cards }
        guard role?.showsOnlyRiskAndWatch == true else { return cards }
        let focused = cards.filter { $0.health == .risk || $0.health == .watch }
        return focused.isEmpty ? cards : focused
    }

    private static func pinnedCallouts(
        _ cards: [SectionSummary],
        pin: [MetricSection],
        restRiskWatch: Bool
    ) -> [SectionSummary] {
        var rest = cards
        var out: [SectionSummary] = []
        for section in pin {
            if let card = rest.first(where: { $0.section == section }) {
                out.append(card)
                rest.removeAll { $0.section == section }
            }
        }
        if restRiskWatch {
            let focused = rest.filter { $0.health == .risk || $0.health == .watch }
            out.append(contentsOf: focused.isEmpty ? rest : focused)
        } else {
            out.append(contentsOf: rest)
        }
        return out
    }

    static func dashboardScopeKey(_ row: MetricRow, grain: DashScopeGrain) -> String? {
        switch grain {
        case .division:
            let key = RollupMarketFill.divisionKey(row.division)
            return key.isEmpty ? nil : key
        case .district:
            let key = RollupMarketFill.districtKey(row.district)
            return key.isEmpty ? nil : key
        case .store:
            let number = canonicalStore(row.storeNumber)
            guard !number.isEmpty else { return nil }
            let market = RollupMarketFill.divisionKey(row.division)
            return market.isEmpty || market == "Unassigned" ? number : "\(number)  |  \(market)"
        }
    }

    static func dashboardScopeLines(section: MetricSection, rows: [MetricRow], grain: DashScopeGrain) -> [DashScopeLine] {
        let source: [MetricRow]
        if section == .pickerScorecard {
            source = latestPerShopper(rows)
        } else {
            source = latestPerStore(rows)
        }
        var buckets: [String: [MetricRow]] = [:]
        for row in source {
            guard let key = dashboardScopeKey(row, grain: grain) else { continue }
            buckets[key, default: []].append(row)
        }
        return buckets.map { key, group -> (DashScopeLine, Double) in
            let worst = worstHealth(section, rows: group)
            let line = DashScopeLine(
                label: key,
                value: scopeHeadline(section, rows: group),
                health: worst,
                count: group.count
            )
            let rank: Double
            if section == .fiveStar {
                rank = fiveStarPresubScore(group)
            } else {
                rank = 0
            }
            return (line, rank)
        }
        .sorted { lhs, rhs in
            if section == .fiveStar {
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.label.localizedStandardCompare(rhs.0.label) == .orderedAscending
            }
            if lhs.0.health.dashboardRank != rhs.0.health.dashboardRank {
                return lhs.0.health.dashboardRank < rhs.0.health.dashboardRank
            }
            return lhs.0.label.localizedStandardCompare(rhs.0.label) == .orderedAscending
        }
        .map(\.0)
    }

    static func dashboardStoreLines(
        section: MetricSection,
        rows: [MetricRow],
        stores: [(number: String, name: String?)],
        roster: [String: StoreIdentity]
    ) -> [DashScopeLine] {
        let source: [MetricRow]
        if section == .pickerScorecard {
            source = latestPerShopper(rows)
        } else {
            source = latestPerStore(rows)
        }
        var byStore: [String: [MetricRow]] = [:]
        for row in source {
            let number = canonicalStore(row.storeNumber)
            guard !number.isEmpty else { continue }
            byStore[number, default: []].append(row)
        }
        return stores.compactMap { item -> (DashScopeLine, Double)? in
            let number = canonicalStore(item.number)
            guard !number.isEmpty else { return nil }
            let group = byStore[number] ?? []
            let market = RollupMarketFill.divisionKey(roster[number]?.division ?? group.first?.division ?? "")
            let label = market.isEmpty || market == "Unassigned" ? number : "\(number)  |  \(market)"
            if group.isEmpty {
                return (DashScopeLine(label: label, value: "—", health: .none, count: 0), section == .fiveStar ? -1 : 0)
            }
            let worst = worstHealth(section, rows: group)
            let line = DashScopeLine(
                label: label,
                value: scopeHeadline(section, rows: group),
                health: worst,
                count: group.count
            )
            let rank = section == .fiveStar ? fiveStarPresubScore(group) : 0
            return (line, rank)
        }
        .sorted { lhs, rhs in
            if section == .fiveStar {
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.label.localizedStandardCompare(rhs.0.label) == .orderedAscending
            }
            if lhs.0.health.dashboardRank != rhs.0.health.dashboardRank {
                return lhs.0.health.dashboardRank < rhs.0.health.dashboardRank
            }
            return lhs.0.label.localizedStandardCompare(rhs.0.label) == .orderedAscending
        }
        .map(\.0)
    }

    static func fiveStarPresubScore(_ rows: [MetricRow]) -> Double {
        average(rows.compactMap { $0.number("presub_pct") }) ?? -1
    }

    static func worstHealth(_ section: MetricSection, rows: [MetricRow]) -> Health {
        rows.reduce(Health.none) { current, row in
            let next = health(for: section, row: row)
            return next.dashboardRank < current.dashboardRank ? next : current
        }
    }

    static func scopeHeadline(_ section: MetricSection, rows: [MetricRow]) -> String {
        switch section {
        case .lostRevenue:
            return HeartbeatFormat.money(rows.compactMap { $0.number("lost_revenue") }.reduce(0, +))
        case .missingItems:
            return HeartbeatFormat.pct(average(rows.compactMap { $0.number(MissingItemDept.totalKey) }))
        case .preSubOOS:
            return HeartbeatFormat.pct(average(rows.compactMap { $0.number(MissingItemDept.totalKey) }))
        case .fiveStar:
            return HeartbeatFormat.stars(average(rows.compactMap { $0.number("star_rating") }))
        case .pickPath, .pickPathPicker:
            return HeartbeatFormat.pct(average(rows.compactMap { $0.number("compliance_pct") }))
        case .prepNotReady:
            return HeartbeatFormat.pct(average(rows.compactMap { $0.number("pnr_rate_pct") }))
        case .dynacap:
            return HeartbeatFormat.num(average(rows.compactMap { $0.number("dynacap_rate", "pieces_per_hour") }), digits: 1)
        case .scheduleQuality:
            return HeartbeatFormat.pct(average(rows.compactMap { $0.number("schedule_efficiency_pct") }))
        case .pph:
            return HeartbeatFormat.num(average(rows.compactMap { $0.number("pph") ?? $0.number("pure_pph") }), digits: 1)
        case .labor:
            return HeartbeatFormat.pct(average(rows.compactMap { $0.number("target_vs_actual_pct") }))
        case .pickerScorecard:
            return "\(rows.filter { isRealPicker($0) }.count) shoppers"
        case .aisleMapper:
            return "\(rows.count) stores"
        }
    }

    static func dashboardActionFlags(
        section: MetricSection,
        rows: [MetricRow],
        pickers: [MetricRow] = [],
        pathPickers: [MetricRow] = [],
        includeAll: Bool = false
    ) -> [FiveStarFlag] {
        switch section {
        case .fiveStar:
            return fiveStarActionFlags(rows, includeAll: includeAll)
        case .lostRevenue:
            return lostRevenueActionFlags(rows)
        case .missingItems:
            return missingItemsActionFlags(rows)
        case .preSubOOS:
            return missingItemsActionFlags(rows)
        case .scheduleQuality:
            return scheduleActionFlags(rows, includeAll: includeAll)
        case .labor:
            return laborActionFlags(rows)
        case .pph:
            return pphActionFlags(stores: rows, shoppers: pickers)
        case .dynacap:
            return dynacapActionFlags(rows)
        case .pickPath, .pickPathPicker:
            return pickPathActionFlags(stores: rows, shoppers: pathPickers)
        case .pickerScorecard:
            return pickerActionFlags(rows)
        case .prepNotReady:
            let stores = rows.filter { !isIgnoredStore($0.storeNumber) && !$0.storeNumber.isEmpty }
            let healthy = stores.filter { health(for: .prepNotReady, row: $0) == .good }.count
            let watch = stores.filter { health(for: .prepNotReady, row: $0) == .watch }.count
            let risk = stores.filter { health(for: .prepNotReady, row: $0) == .risk }.count
            return [
                FiveStarFlag(name: "Healthy", value: "", health: .good, stores: healthy),
                FiveStarFlag(name: "Watch", value: "", health: watch == 0 ? .good : .watch, stores: watch),
                FiveStarFlag(name: "At Risk", value: "", health: risk == 0 ? .good : .risk, stores: risk),
            ]
        case .aisleMapper:
            return []
        }
    }

    static func latestPerStore(_ rows: [MetricRow]) -> [MetricRow] {
        var map: [String: MetricRow] = [:]
        for row in rows {
            let number = canonicalStore(row.storeNumber)
            if isIgnoredStore(number) { continue }
            let key = number.isEmpty
                ? "\(row.division)|\(row.operationsOM)|\(row.storeName ?? "")"
                : number
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
            let key = "\(row.storeNumber)|\(canonicalShopper(row.shopperKey))"
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

    static func canonicalShopper(_ raw: String) -> String {
        raw.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    static func shopperAliases(_ row: MetricRow) -> [String] {
        var seen = Set<String>()
        var keys: [String] = []
        for raw in [row.shopperKey, row.shopperId ?? "", row.shopperName] {
            let key = canonicalShopper(raw)
            if !key.isEmpty, seen.insert(key).inserted {
                keys.append(key)
            }
        }
        return keys
    }

    static func filtered(_ rows: [MetricRow], division: String, district: String, om: String, store: String) -> [MetricRow] {
        filtered(rows, division: division, district: district, om: om, store: store, relaxUnknown: false, universe: nil, region: "")
    }

    static func filtered(
        _ rows: [MetricRow],
        filters: DashboardFilters,
        relaxUnknown: Bool = false,
        universe: [MetricRow]? = nil
    ) -> [MetricRow] {
        filtered(
            rows,
            division: filters.division,
            district: filters.district,
            om: filters.om,
            store: filters.store,
            relaxUnknown: relaxUnknown,
            universe: universe,
            region: filters.region
        )
    }

    static func filtered(
        _ rows: [MetricRow],
        division: String,
        district: String,
        om: String,
        store: String,
        relaxUnknown: Bool,
        universe: [MetricRow]? = nil,
        region: String = ""
    ) -> [MetricRow] {
        let pool = universe ?? rows
        let roster = storeRoster(pool)
        let selectedDivisions = DashboardFilters.parts(division)
        let selectedRegions = DashboardFilters.parts(region)
        let divisionValues: [String]
        if !selectedDivisions.isEmpty {
            divisionValues = selectedDivisions
        } else {
            divisionValues = selectedRegions.flatMap { MarketRegion(rawValue: $0)?.divisions ?? [] }
        }
        let districtValues = DashboardFilters.parts(district)
        let omValues = DashboardFilters.parts(om)
        let storeValues = DashboardFilters.parts(store)
        let divisionStores = storeSet(in: pool, roster: roster, values: divisionValues, relax: relaxUnknown) { $0.division }
        let districtStores = storeSet(in: pool, roster: roster, values: districtValues, relax: relaxUnknown) { $0.district }
        let omStores = storeSet(in: pool, roster: roster, values: omValues, relax: relaxUnknown) { $0.om }

        return rows.filter { row in
            let identity = resolvedIdentity(row, roster: roster)
            if let divisionStores, !belongs(row.storeNumber, to: divisionStores, identity: identity.division, values: divisionValues) {
                return false
            }
            if let districtStores, !belongs(row.storeNumber, to: districtStores, identity: identity.district, values: districtValues) {
                return false
            }
            if let omStores, !belongs(row.storeNumber, to: omStores, identity: identity.om, values: omValues) {
                return false
            }
            if storeValues.isEmpty { return true }
            return storeValues.contains { matches(row.storeNumber, $0) } || relaxUnknown
        }
    }

    private static func storeSet(
        in rows: [MetricRow],
        roster: [String: StoreIdentity],
        value: String,
        relax: Bool,
        field: (StoreIdentity) -> String
    ) -> Set<String>? {
        storeSet(in: rows, roster: roster, values: value.isEmpty ? [] : [value], relax: relax, field: field)
    }

    private static func storeSet(
        in rows: [MetricRow],
        roster: [String: StoreIdentity],
        values: [String],
        relax: Bool,
        field: (StoreIdentity) -> String
    ) -> Set<String>? {
        let trimmed = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if trimmed.isEmpty { return nil }
        let hits = Set(rows.compactMap { row -> String? in
            let identity = resolvedIdentity(row, roster: roster)
            guard trimmed.contains(where: { MarketRegion.matchesDivision(field(identity), $0) }), !row.storeNumber.isEmpty else { return nil }
            return row.storeNumber
        })
        if hits.isEmpty { return relax ? nil : [] }
        return hits
    }

    private static func belongs(_ storeNumber: String, to stores: Set<String>, identity: String, value: String) -> Bool {
        belongs(storeNumber, to: stores, identity: identity, values: [value])
    }

    private static func belongs(_ storeNumber: String, to stores: Set<String>, identity: String, values: [String]) -> Bool {
        if !storeNumber.isEmpty { return stores.contains(storeNumber) }
        return values.contains { MarketRegion.matchesDivision(identity, $0) }
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

    static func compactKey(_ raw: String) -> String {
        normalize(raw).replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    static func canonicalDistrict(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.replacingOccurrences(of: "(?i)^district\\s+", with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !value.isEmpty else { return "" }
        if value.rangeOfCharacter(from: .decimalDigits) != nil {
            return value.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression).uppercased()
        }
        return value
    }

    static func canonicalOM(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.replacingOccurrences(of: "(?i)^(om|operations manager)\\s*[:\\-–]\\s*", with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return value
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

    static func marketBoard(_ rows: [MetricRow], filters: DashboardFilters) -> [MarketStore] {
        marketBoard(rows, division: filters.division, district: filters.district, om: filters.om, store: filters.store, region: filters.region)
    }

    static func marketBoard(_ rows: [MetricRow], division: String, district: String, om: String, store: String, region: String = "") -> [MarketStore] {
        let matched = filtered(rows, division: division, district: district, om: om, store: store, relaxUnknown: false, universe: rows, region: region)
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

    static let ignoredStores: Set<String> = ["210", "239"]

    static let identityOverrides: [String: StoreIdentity] = [
        "3603": StoreIdentity(division: "Mid-Atlantic", district: "A9", om: "Aimee Cabrera-Kleissler", name: nil)
    ]

    static func isIgnoredStore(_ raw: String) -> Bool {
        ignoredStores.contains(canonicalStore(raw))
    }

    static func storeRoster(_ rows: [MetricRow]) -> [String: StoreIdentity] {
        var map: [String: StoreIdentity] = [:]
        for row in rows {
            guard !row.storeNumber.isEmpty else { continue }
            let number = canonicalStore(row.storeNumber)
            if ignoredStores.contains(number) { continue }
            var current = map[number] ?? StoreIdentity(division: "", district: "", om: "", name: nil)
            if !row.division.isEmpty {
                let name = MarketRegion.canonicalName(row.division)
                if !name.isEmpty { current.division = name }
            }
            if !row.district.isEmpty {
                let district = canonicalDistrict(row.district)
                if !district.isEmpty { current.district = district }
            }
            if !row.operationsOM.isEmpty {
                let om = canonicalOM(row.operationsOM)
                if !om.isEmpty { current.om = om }
            }
            if current.name == nil, let name = row.storeName, !name.isEmpty { current.name = name }
            map[number] = current
        }
        for (number, override) in identityOverrides {
            var current = map[number] ?? override
            if !override.division.isEmpty { current.division = override.division }
            if !override.district.isEmpty { current.district = override.district }
            if !override.om.isEmpty { current.om = override.om }
            if let name = override.name, current.name == nil { current.name = name }
            map[number] = current
        }
        for number in ignoredStores {
            map.removeValue(forKey: number)
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
            return applyRoster(
                rows.filter { $0.number("dynacap_rate", "pieces_per_hour") != nil || $0.number("pickup_capacity") != nil },
                roster: roster
            )
        }
        return applyRoster(expanded, roster: roster)
    }

    static func materializeDynacap(_ rows: [MetricRow], roster: [String: StoreIdentity]) -> [MetricRow] {
        func hasRate(_ row: MetricRow) -> Bool {
            row.number("dynacap_rate", "pieces_per_hour") != nil
        }
        let perStore = applyRoster(latestPerStore(rows.filter { !$0.storeNumber.isEmpty }), roster: roster)
            .filter(hasRate)
        if !perStore.isEmpty { return perStore }
        return materializeDistrictMetric(rows, roster: roster).filter(hasRate)
    }

    static func materializePickPath(_ rows: [MetricRow], roster: [String: StoreIdentity]) -> [MetricRow] {
        let perStore = applyRoster(latestPerStore(rows.filter { !$0.storeNumber.isEmpty }), roster: roster)
        if !perStore.isEmpty { return perStore }

        let byArea = Dictionary(
            rows.compactMap { row -> (String, MetricRow)? in
                let area = normalize(row.textPayload["om_area"] ?? "")
                guard !area.isEmpty else { return nil }
                return (area, row)
            },
            uniquingKeysWith: { _, latest in latest }
        )
        guard !byArea.isEmpty else { return applyRoster(latestPerStore(rows), roster: roster) }

        var expanded: [MetricRow] = []
        for (number, identity) in roster {
            let keys = [
                normalize("\(identity.division) \(identity.district)"),
                normalize(identity.district),
                normalize(identity.om),
                normalize("\(identity.division) \(identity.om)"),
            ].filter { !$0.isEmpty }
            guard let source = keys.compactMap({ byArea[$0] }).first else { continue }
            var text = source.textPayload
            text["district"] = identity.district
            text["om_area"] = source.textPayload["om_area"] ?? ""
            expanded.append(
                MetricRow(
                    section: .pickPath,
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
        return expanded.isEmpty ? rows : expanded
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
                division: {
                    if let known = known?.division, !known.isEmpty { return MarketRegion.canonicalName(known) }
                    return MarketRegion.canonicalName(row.division)
                }(),
                operationsOM: known?.om.isEmpty == false ? known!.om : row.operationsOM,
                storeNumber: number,
                storeName: row.storeName ?? known?.name,
                recordedOn: row.recordedOn,
                payload: remapSchedulePayload(row.payload),
                textPayload: text
            )
        }
    }

    static func applyAisleMapper(_ rows: [MetricRow], from mapper: [MetricRow]) -> [MetricRow] {
        guard !mapper.isEmpty else { return rows }
        var byStore: [String: (mapper: String, sequence: String)] = [:]
        for row in mapper {
            let key = canonicalStore(row.storeNumber)
            guard !key.isEmpty, !isIgnoredStore(key) else { continue }
            let mapDate = AisleMapperMath.mapperISO(row) ?? ""
            let seqDate = AisleMapperMath.sequenceISO(row) ?? ""
            if mapDate.isEmpty && seqDate.isEmpty { continue }
            byStore[key] = (mapDate, seqDate)
        }
        guard !byStore.isEmpty else { return rows }
        return rows.map { row in
            guard let extra = byStore[canonicalStore(row.storeNumber)] else { return row }
            var text = row.textPayload
            if !extra.mapper.isEmpty { text[AisleMapperMath.mapperKey] = extra.mapper }
            if !extra.sequence.isEmpty { text[AisleMapperMath.sequenceKey] = extra.sequence }
            var next = row
            next.textPayload = text
            return next
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
        case .pickPath, .pickPathPicker:
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
        case .labor:
            return laborHealth(row)
        case .pickerScorecard:
            return pickerHealth(row)
        case .lostRevenue:
            return lostRevenueHealth(row)
        case .missingItems:
            return missingItemsHealth(row)
        case .preSubOOS:
            return missingItemsHealth(row)
        case .aisleMapper:
            return AisleMapperMath.health(AisleMapperMath.mapperISO(row))
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
        let latest: [MetricRow]
        if section == .pickerScorecard {
            latest = latestPerShopper(rows)
        } else if section == .lostRevenue {
            latest = rows.filter { !isIgnoredStore($0.storeNumber) }
        } else {
            latest = latestPerStore(rows)
        }
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
        case .pickPath, .pickPathPicker:
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
            let calloutHealth: Health = {
                if underRisk > 0 || overRisk > 0 { return .risk }
                if watch > 0 { return .watch }
                return latest.isEmpty ? .none : .good
            }()
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: headline,
                headlineLabel: "Avg schedule efficiency",
                secondary: latest.isEmpty
                    ? "No Schedule rows in this filter"
                    : "\(atGoal) of \(latest.count) at 90% · \(underRisk) under · \(overRisk) over",
                health: calloutHealth,
                watchCount: watch,
                riskCount: risk,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt,
                underScheduledCount: underRisk,
                overScheduledCount: overRisk
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
        case .labor:
            let latest = rows.filter { $0.textPayload["labor_grain"] != "market" }
            let headline: Double? = laborRollup(rows, key: "target_vs_actual_pct")
            let healthy = latest.filter { ($0.number("target_vs_actual_pct") ?? 1) <= 0 }.count
            let watchCount = latest.filter {
                let value = $0.number("target_vs_actual_pct") ?? 0
                return value > 0 && value <= laborWatch
            }.count
            let riskCount = latest.filter { ($0.number("target_vs_actual_pct") ?? 0) > laborWatch }.count
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: headline,
                headlineLabel: "Target vs Actual",
                secondary: latest.isEmpty
                    ? "No Labor rows in this filter"
                    : "\(healthy) healthy · \(watchCount) watch · \(riskCount) over 3%",
                health: latest.isEmpty ? .none : laborHealth(headline),
                watchCount: watchCount,
                riskCount: riskCount,
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
        case .lostRevenue:
            let stores = latest.filter { $0.textPayload["lost_grain"] != "market" && !isIgnoredStore($0.storeNumber) }
            let market = latest.first { $0.textPayload["lost_grain"] == "market" }
            let dollars: Double?
            let pct: Double?
            if let market {
                dollars = market.number("lost_revenue")
                pct = market.number("lost_revenue_pct")
            } else {
                let sumDollars = stores.compactMap { $0.number("lost_revenue") }.reduce(0, +)
                let sumSales = stores.compactMap { $0.number("ecomm_sales") }.reduce(0, +)
                dollars = stores.isEmpty ? nil : sumDollars
                pct = sumSales > 0 ? sumDollars / sumSales * 100 : nil
            }
            let scored = stores.isEmpty ? (market.map { [$0] } ?? []) : stores
            return SectionSummary(
                section: section,
                storeCount: stores.count,
                headline: dollars,
                headlineLabel: "Total lost revenue",
                secondary: scored.isEmpty
                    ? "No Lost Revenue rows in this filter"
                    : "Total Lost Revenue % (Total Opportunity)",
                health: scored.isEmpty ? .none : lostRevenueHealth(pct: pct),
                watchCount: scored.filter { lostRevenueHealth($0) == .watch }.count,
                riskCount: scored.filter { lostRevenueHealth($0) == .risk }.count,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt,
                lostRevenuePct: pct
            )
        case .missingItems:
            let headline = average(latest.compactMap { $0.number(MissingItemDept.totalKey) })
            let healthy = latest.filter { missingItemsHealth($0) == .good }.count
            let watchCount = latest.filter { missingItemsHealth($0) == .watch }.count
            let riskCount = latest.filter { missingItemsHealth($0) == .risk }.count
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: headline,
                headlineLabel: "Avg missing items",
                secondary: latest.isEmpty
                    ? "No Missing Items rows in this filter"
                    : "\(healthy) healthy · \(watchCount) watch · \(riskCount) over 6.50%",
                health: latest.isEmpty ? .none : band(headline, good: missingItemsGoal, watch: missingItemsWatch, invert: true),
                watchCount: watchCount,
                riskCount: riskCount,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt
            )
        case .preSubOOS:
            let headline = average(latest.compactMap { $0.number(MissingItemDept.totalKey) })
            let healthy = latest.filter { missingItemsHealth($0) == .good }.count
            let watchCount = latest.filter { missingItemsHealth($0) == .watch }.count
            let riskCount = latest.filter { missingItemsHealth($0) == .risk }.count
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: headline,
                headlineLabel: "Avg Pre-Sub OOS",
                secondary: latest.isEmpty
                    ? "No Pre-Sub OOS rows in this filter"
                    : "\(healthy) healthy · \(watchCount) watch · \(riskCount) over 6.50%",
                health: latest.isEmpty ? .none : band(headline, good: missingItemsGoal, watch: missingItemsWatch, invert: true),
                watchCount: watchCount,
                riskCount: riskCount,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt
            )
        case .aisleMapper:
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: nil,
                headlineLabel: "Aisle mapper",
                secondary: latest.isEmpty
                    ? "No Aisle Mapper rows in this filter"
                    : "\(latest.count) stores · dates show on Pick Path",
                health: .none,
                watchCount: 0,
                riskCount: 0,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt
            )
        }
    }

    static let pnrGoal = 1.9
    static let pnrWatch = 2.5
    static let pphGoal = 80.0
    static let pphRisk = 74.0
    static let laborWatch = 3.0
    static let lostRevenueGood = 3.0
    static let lostRevenueWatch = 5.0
    static let missingItemsGoal = 5.0
    static let missingItemsWatch = 6.50
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

    struct FiveStarFlag: Identifiable, Equatable, Sendable {
        var id: String { name }
        let name: String
        let value: String
        let health: Health
        let stores: Int
        var unit: String = "stores"
    }

    static func fiveStarActionFlags(_ rows: [MetricRow], includeAll: Bool = false) -> [FiveStarFlag] {
        let specs: [(name: String, key: String, mark: (MetricRow) -> StarMark)] = [
            ("OTT", "ott_pct", ottStar),
            ("Flash", "flash_pct", flashStar),
            ("Presubs", "presub_pct", presubStar),
            ("COE", "coe_pct", coeStar),
            ("OTH 5%", "oth5_pct", othStar),
        ]
        var flags: [FiveStarFlag] = []
        flags.reserveCapacity(specs.count)
        for spec in specs {
            var worst = Health.none
            var action = 0
            var values: [Double] = []
            values.reserveCapacity(rows.count)
            for row in rows {
                guard let value = row.number(spec.key) else { continue }
                values.append(value)
                let health = spec.mark(row).health
                if health.needsAction {
                    action += 1
                    if health == .risk { worst = .risk }
                    else if worst != .risk { worst = .watch }
                }
            }
            guard !values.isEmpty else { continue }
            if !includeAll {
                guard action > 0, worst.needsAction else { continue }
            }
            flags.append(
                FiveStarFlag(
                    name: spec.name,
                    value: HeartbeatFormat.pct(average(values)),
                    health: worst == .none ? .good : worst,
                    stores: action
                )
            )
        }
        return flags
    }

    static func lostRevenueActionFlags(_ rows: [MetricRow]) -> [FiveStarFlag] {
        let stores = rows.filter {
            $0.textPayload["lost_grain"] != "market"
                && !isIgnoredStore($0.storeNumber)
                && !$0.storeNumber.isEmpty
        }
        let healthy = stores.filter { lostRevenueHealth($0) == .good }.count
        let watch = stores.filter { lostRevenueHealth($0) == .watch }.count
        let risk = stores.filter { lostRevenueHealth($0) == .risk }.count
        return [
            FiveStarFlag(name: "Healthy", value: "", health: .good, stores: healthy),
            FiveStarFlag(name: "Watch", value: "", health: watch == 0 ? .good : .watch, stores: watch),
            FiveStarFlag(name: "At Risk", value: "", health: risk == 0 ? .good : .risk, stores: risk),
        ]
    }

    static func missingItemsActionFlags(_ rows: [MetricRow]) -> [FiveStarFlag] {
        let stores = rows.filter { !isIgnoredStore($0.storeNumber) && !$0.storeNumber.isEmpty }
        let healthy = stores.filter { missingItemsHealth($0) == .good }.count
        let watch = stores.filter { missingItemsHealth($0) == .watch }.count
        let risk = stores.filter { missingItemsHealth($0) == .risk }.count
        return [
            FiveStarFlag(name: "Healthy", value: "", health: .good, stores: healthy),
            FiveStarFlag(name: "Watch", value: "", health: watch == 0 ? .good : .watch, stores: watch),
            FiveStarFlag(name: "At Risk", value: "", health: risk == 0 ? .good : .risk, stores: risk),
        ]
    }

    static func scheduleActionFlags(_ rows: [MetricRow], includeAll: Bool = false) -> [FiveStarFlag] {
        let specs: [(name: String, keys: [String])] = [
            ("Under Scheduled", ["under_schedule_pct", "under_scheduled"]),
            ("Over Scheduled", ["over_schedule_pct", "over_scheduled"]),
        ]
        var flags: [FiveStarFlag] = []
        flags.reserveCapacity(specs.count)
        for spec in specs {
            var worst = Health.none
            var action = 0
            var values: [Double] = []
            values.reserveCapacity(rows.count)
            for row in rows {
                let value: Double?
                if spec.keys.count == 2 {
                    value = row.number(spec.keys[0], spec.keys[1])
                } else {
                    value = row.number(spec.keys[0])
                }
                guard let value else { continue }
                values.append(value)
                let health = varianceHealth(value)
                if health.needsAction {
                    action += 1
                    if health == .risk { worst = .risk }
                    else if worst != .risk { worst = .watch }
                }
            }
            guard !values.isEmpty else { continue }
            if !includeAll {
                guard action > 0, worst.needsAction else { continue }
            }
            flags.append(
                FiveStarFlag(
                    name: spec.name,
                    value: HeartbeatFormat.pct(average(values)),
                    health: worst == .none ? .good : worst,
                    stores: action
                )
            )
        }
        return flags
    }

    static func laborActionFlags(_ rows: [MetricRow]) -> [FiveStarFlag] {
        let stores = rows.filter { $0.textPayload["labor_grain"] != "market" && !isIgnoredStore($0.storeNumber) }
        let cost = laborRollup(rows, key: "cost_trgt_pct")
        let act = laborRollup(rows, key: "act_cost_pct")
        let uplh = laborRollup(rows, key: "uplh_impact_pct")
        let wage = laborRollup(rows, key: "wage_impact_pct")
        let aiv = laborRollup(rows, key: "aiv_impact_pct")
        var flags: [FiveStarFlag] = []
        flags.append(
            FiveStarFlag(
                name: "Cost Trgt%",
                value: HeartbeatFormat.pct(cost),
                health: .none,
                stores: 0
            )
        )
        let actHealth: Health = {
            guard let act, let cost else { return .none }
            return act <= cost ? .good : .risk
        }()
        flags.append(
            FiveStarFlag(
                name: "Act Cost%",
                value: HeartbeatFormat.pct(act),
                health: actHealth,
                stores: 0
            )
        )
        let over3 = stores.filter { ($0.number("target_vs_actual_pct") ?? 0) > laborWatch }.count
        let band = stores.filter {
            let value = $0.number("target_vs_actual_pct") ?? 0
            return value > 0 && value <= laborWatch
        }.count
        flags.append(
            FiveStarFlag(
                name: "Over 3%",
                value: "",
                health: over3 == 0 ? .good : .risk,
                stores: over3
            )
        )
        flags.append(
            FiveStarFlag(
                name: "0.01%–3%",
                value: "",
                health: band == 0 ? .good : .watch,
                stores: band
            )
        )
        for spec in [("UPLH", uplh), ("Wage", wage), ("AIV", aiv)] {
            flags.append(
                FiveStarFlag(
                    name: spec.0,
                    value: HeartbeatFormat.pct(spec.1),
                    health: laborHealth(spec.1),
                    stores: 0
                )
            )
        }
        return flags
    }

    static func pphActionFlags(stores: [MetricRow], shoppers: [MetricRow]) -> [FiveStarFlag] {
        let pickerRows = shoppers.filter { isRealPicker($0) && $0.number("pph") != nil }
        let usingShoppers = !pickerRows.isEmpty
        let rows = usingShoppers ? pickerRows : stores.filter { !isIgnoredStore($0.storeNumber) && $0.number("pph") != nil }
        let atGoal = rows.filter { ($0.number("pph") ?? 0) >= pphGoal }.count
        let below74 = rows.filter { ($0.number("pph") ?? .greatestFiniteMagnitude) < pphRisk }.count
        let unit = usingShoppers ? "shoppers" : "stores"
        return [
            FiveStarFlag(
                name: "At Goal",
                value: "",
                health: .good,
                stores: atGoal,
                unit: unit
            ),
            FiveStarFlag(
                name: "Below 74",
                value: "",
                health: below74 == 0 ? .good : .risk,
                stores: below74,
                unit: unit
            ),
        ]
    }

    static func dynacapActionFlags(_ rows: [MetricRow]) -> [FiveStarFlag] {
        let stores = rows.filter {
            !isIgnoredStore($0.storeNumber) && $0.number("dynacap_rate", "pieces_per_hour") != nil
        }
        let atGoal = stores.filter { ($0.number("dynacap_rate", "pieces_per_hour") ?? 0) >= dynacapGoal }.count
        let below60 = stores.filter { ($0.number("dynacap_rate", "pieces_per_hour") ?? .greatestFiniteMagnitude) < dynacapRisk }.count
        return [
            FiveStarFlag(
                name: "At Goal",
                value: "",
                health: .good,
                stores: atGoal
            ),
            FiveStarFlag(
                name: "Below 60",
                value: "",
                health: below60 == 0 ? .good : .risk,
                stores: below60
            ),
        ]
    }

    static func pickPathActionFlags(stores: [MetricRow], shoppers: [MetricRow]) -> [FiveStarFlag] {
        let pickerRows = shoppers.filter { $0.number("compliance_pct") != nil }
        let usingShoppers = !pickerRows.isEmpty
        let rows = usingShoppers ? pickerRows : stores.filter { !isIgnoredStore($0.storeNumber) && $0.number("compliance_pct") != nil }
        let atGoal = rows.filter { ($0.number("compliance_pct") ?? 0) >= pickPathGoal }.count
        let below80 = rows.filter { ($0.number("compliance_pct") ?? .greatestFiniteMagnitude) < pickPathRisk }.count
        let unit = usingShoppers ? "shoppers" : "stores"
        return [
            FiveStarFlag(
                name: "At Goal",
                value: "",
                health: .good,
                stores: atGoal,
                unit: unit
            ),
            FiveStarFlag(
                name: "Below 80%",
                value: "",
                health: below80 == 0 ? .good : .risk,
                stores: below80,
                unit: unit
            ),
        ]
    }

    static func pickerActionFlags(_ rows: [MetricRow]) -> [FiveStarFlag] {
        var opportunity = 0
        var strong = 0
        var pph = 0
        var presub = 0
        var oos = 0
        var ott = 0
        var oth = 0
        var refund = 0
        var pphHealth: Health = .none
        var presubHealth: Health = .none
        var oosHealth: Health = .none
        var ottHealth: Health = .none
        var othHealth: Health = .none
        var refundHealth: Health = .none
        func bump(_ current: inout Health, _ next: Health) {
            if next == .risk { current = .risk }
            else if next == .watch, current != .risk { current = .watch }
        }
        for row in rows {
            guard isRealPicker(row) else { continue }
            let volume = pickerHasVolume(row)
            let overall = pickerHealth(row)
            if volume && overall == .good {
                strong += 1
            } else if volume && overall.needsAction {
                opportunity += 1
            }
            if row.number("pph") != nil {
                let health = Self.pphHealth(row)
                if health.needsAction {
                    pph += 1
                    bump(&pphHealth, health)
                }
            }
            if row.number("presub_pct") != nil {
                let health = presubStar(row).health
                if health.needsAction {
                    presub += 1
                    bump(&presubHealth, health)
                }
            }
            if row.number("oos_pct") != nil {
                let health = oosStar(row).health
                if health.needsAction {
                    oos += 1
                    bump(&oosHealth, health)
                }
            }
            if row.number("ott_pct") != nil {
                let health = ottStar(row).health
                if health.needsAction {
                    ott += 1
                    bump(&ottHealth, health)
                }
            }
            if row.number("oth5_pct") != nil {
                let health = othStar(row).health
                if health.needsAction {
                    oth += 1
                    bump(&othHealth, health)
                }
            }
            if row.number("refund_amt") != nil {
                let health = Self.refundHealth(row)
                if health.needsAction {
                    refund += 1
                    bump(&refundHealth, health)
                }
            }
        }
        func shoppers(_ name: String, _ count: Int, _ health: Health) -> FiveStarFlag {
            FiveStarFlag(
                name: name,
                value: "",
                health: count == 0 ? .good : health,
                stores: count,
                unit: "shoppers"
            )
        }
        return [
            shoppers("Opportunity", opportunity, .risk),
            shoppers("Doing Well", strong, .good),
            shoppers("PPH", pph, pphHealth),
            shoppers("Presub", presub, presubHealth),
            shoppers("OOS", oos, oosHealth),
            shoppers("OTT", ott, ottHealth),
            shoppers("OTH", oth, othHealth),
            shoppers("Refund", refund, refundHealth),
        ]
    }

    static func oosStar(_ row: MetricRow) -> StarMark {
        componentStar(row, starKey: "oos_star", pctKey: "oos_pct", full: 3, half: 5, invert: true)
    }

    static func othEligStar(_ row: MetricRow) -> StarMark {
        componentStar(row, starKey: "oth_elig_star", pctKey: "oth_elig_pct", full: 95, half: 90)
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
        let staffing = band(row.number("staffing_efficiency_pct"), good: scheduleGoal, watch: scheduleWatch)
        let ranks: [Health: Int] = [.none: 0, .good: 1, .watch: 2, .risk: 3]
        return [under, over, efficiency, staffing].max { (ranks[$0] ?? 0) < (ranks[$1] ?? 0) } ?? .watch
    }

    static func pphHealth(_ row: MetricRow) -> Health {
        band(row.number("pph"), good: pphGoal, watch: pphRisk)
    }

    static func laborRollup(_ rows: [MetricRow], key: String) -> Double? {
        if let market = rows.first(where: { $0.textPayload["labor_grain"] == "market" }) {
            return market.number(key)
        }
        let stores = rows.filter { $0.textPayload["labor_grain"] != "market" }
        if stores.count == 1 { return stores[0].number(key) }
        if key == "schedule_efficiency_pct" {
            return laborWeighted(stores, key: key, weightKey: "empower_hrs")
        }
        var num = 0.0
        var den = 0.0
        for row in stores {
            guard let value = row.number(key) else { continue }
            let weight = laborBase(row)
            num += value * weight
            den += weight
        }
        return den > 0 ? num / den : nil
    }

    private static func laborBase(_ row: MetricRow) -> Double {
        if let dollars = row.number("act_cost_dollar"),
           let act = row.number("act_cost_pct"),
           abs(act) > 0.0001 {
            return dollars / (act / 100)
        }
        return row.number("earned_hrs") ?? row.number("charged_hrs") ?? 1
    }

    private static func laborWeighted(_ rows: [MetricRow], key: String, weightKey: String) -> Double? {
        var num = 0.0
        var den = 0.0
        for row in rows {
            guard let value = row.number(key) else { continue }
            let weight = row.number(weightKey) ?? 0
            guard weight > 0 else { continue }
            num += value * weight
            den += weight
        }
        return den > 0 ? num / den : nil
    }

    static func laborHealth(_ row: MetricRow) -> Health {
        laborHealth(row.number("target_vs_actual_pct"))
    }

    static func laborHealth(_ value: Double?) -> Health {
        guard let value else { return .none }
        if value <= 0 { return .good }
        if value <= laborWatch { return .watch }
        return .risk
    }

    static func lostRevenueHealth(_ row: MetricRow) -> Health {
        lostRevenueHealth(pct: row.number("lost_revenue_pct"))
    }

    static func lostRevenueHealth(pct: Double?) -> Health {
        band(pct, good: lostRevenueGood, watch: lostRevenueWatch, invert: true)
    }

    static func missingItemsRate(_ row: MetricRow, depts: [MissingItemDept] = []) -> Double? {
        if depts.isEmpty || depts.count == MissingItemDept.allCases.count {
            return row.number(MissingItemDept.totalKey)
        }
        return average(depts.compactMap { row.number($0.rawValue) })
    }

    static func missingItemsHealth(_ row: MetricRow, depts: [MissingItemDept] = []) -> Health {
        missingItemsHealth(pct: missingItemsRate(row, depts: depts))
    }

    static func missingItemsHealth(pct: Double?) -> Health {
        band(pct, good: missingItemsGoal, watch: missingItemsWatch, invert: true)
    }

    static func pickerHasVolume(_ row: MetricRow) -> Bool {
        (row.number("orders") ?? 0) > 15
    }

    static func refundHealth(_ row: MetricRow) -> Health {
        guard let amount = row.number("refund_amt") else { return .none }
        if amount <= 0 { return .good }
        if amount <= 20 { return .watch }
        return .risk
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
        case .oos:
            return row.number("oos_pct") != nil && oosStar(row).health != .good
        case .refund:
            return row.number("refund_amt") != nil && refundHealth(row) != .good && refundHealth(row) != .none
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
        if row.number("oos_pct") != nil {
            flags.append(("OOS", oosStar(row).health))
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
        if row.number("oth_elig_pct") != nil {
            flags.append(("OTH Elig", othEligStar(row).health))
        }
        if row.number("refund_amt") != nil {
            flags.append(("Refund", refundHealth(row)))
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
        if row.number("oos_pct") != nil {
            items.append(("OOS", HeartbeatFormat.pct(row.number("oos_pct")), oosStar(row).health))
        }
        if row.number("oth5_pct") != nil {
            items.append(("OTH5", HeartbeatFormat.pct(row.number("oth5_pct")), othStar(row).health))
        }
        if row.number("ott_pct") != nil {
            items.append(("OTT", HeartbeatFormat.pct(row.number("ott_pct")), ottStar(row).health))
        }
        if row.number("coe_pct") != nil {
            items.append(("COE", HeartbeatFormat.pct(row.number("coe_pct")), coeStar(row).health))
        }
        if row.number("oth_elig_pct") != nil {
            items.append(("OTH Elig", HeartbeatFormat.pct(row.number("oth_elig_pct")), othEligStar(row).health))
        }
        if row.number("pick_hours") != nil {
            items.append(("Hours", HeartbeatFormat.num(row.number("pick_hours"), digits: 1), .none))
        }
        if row.number("subs") != nil {
            items.append(("Subs", HeartbeatFormat.num(row.number("subs")), .none))
        }
        if row.number("orders") != nil {
            items.append(("Orders", HeartbeatFormat.num(row.number("orders")), .none))
        }
        if row.number("dug_orders") != nil {
            items.append(("DUG", HeartbeatFormat.num(row.number("dug_orders")), .none))
        }
        if row.number("refund_amt") != nil {
            items.append(("Refund", HeartbeatFormat.money(row.number("refund_amt")), refundHealth(row)))
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
            if health == .good {
                let score = (row.number("orders") ?? 0) * pickerComposite(row)
                strongCount += 1
                keepTop(&strong, score: score, row: row, limit: limit, lowest: false)
            } else {
                let gap = max(0, 1 - pickerComposite(row))
                let refundBump = (row.number("refund_amt") ?? 0) > 20 ? 0.25 : 0
                let score = (row.number("orders") ?? 0) * (gap + refundBump)
                opportunityCount += 1
                keepTop(&opportunity, score: score, row: row, limit: limit, lowest: false)
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
        case .pickPath, .pickPathPicker:
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
        case .labor:
            return row.number("target_vs_actual_pct") ?? 0
        case .pickerScorecard:
            return -pickerComposite(row)
        case .lostRevenue:
            return row.number("lost_revenue") ?? 0
        case .missingItems, .preSubOOS:
            return row.number(MissingItemDept.totalKey) ?? 0
        case .aisleMapper:
            return AisleMapperMath.ageDays(AisleMapperMath.mapperISO(row)) ?? 0
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
            case .pickPath, .pickPathPicker: value = row.number("compliance_pct")
            case .prepNotReady: value = row.number("pnr_rate_pct")
            case .dynacap:
                value = row.number("dynacap_rate", "pieces_per_hour")
            case .scheduleQuality:
                value = row.number("schedule_efficiency_pct")
            case .pph:
                value = row.number("pph")
            case .labor:
                value = row.number("target_vs_actual_pct")
            case .pickerScorecard:
                value = pickerComposite(row)
            case .lostRevenue:
                value = row.number("lost_revenue")
            case .missingItems, .preSubOOS:
                value = row.number(MissingItemDept.totalKey)
            case .aisleMapper:
                value = AisleMapperMath.ageDays(AisleMapperMath.mapperISO(row))
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

struct ChecklistFinding: Identifiable, Equatable {
    var name: String
    var value: String
    var need: String
    var health: Health
    var fact: String
    var shoppers: String
    var action: String
    var id: String { name }
}

struct ChecklistShopper: Identifiable, Equatable {
    var id: String
    var name: String
    var issues: [String]
    var action: String
    var health: Health
}

struct ChecklistDriverItem: Identifiable, Equatable {
    var id: String
    var title: String
    var subtitle: String
    var value: String
    var health: Health
    var broken: String = ""
    var shoppers: String = ""
    var action: String = ""
    var findings: [ChecklistFinding] = []
    var people: [ChecklistShopper] = []

    func shopperItem(_ person: ChecklistShopper) -> ChecklistDriverItem {
        ChecklistDriverItem(
            id: "\(id)|ldap|\(person.id)",
            title: person.name,
            subtitle: title,
            value: person.issues.joined(separator: " · "),
            health: person.health,
            action: person.action
        )
    }

    func findingItem(_ finding: ChecklistFinding) -> ChecklistDriverItem {
        ChecklistDriverItem(
            id: "\(id)|finding|\(finding.id)",
            title: finding.name,
            subtitle: title,
            value: finding.value,
            health: finding.health,
            action: finding.action
        )
    }
}

struct ChecklistDriverGroup: Identifiable, Equatable {
    var title: String
    var items: [ChecklistDriverItem]
    var id: String { title }
}

enum HeartbeatRole: String, CaseIterable, Identifiable, Sendable {
    case backstage
    case evp
    case director
    case districtManager
    case om

    var id: String { rawValue }

    var title: String {
        switch self {
        case .backstage: return "Backstage Support"
        case .evp: return "EVP Region"
        case .director: return "Director / Market VP / Sr Director Sales"
        case .districtManager: return "District Manager"
        case .om: return "Operations Manager"
        }
    }

    var detail: String {
        switch self {
        case .backstage:
            return "Total company view · every region, market, and store"
        case .evp:
            return "East, South, California, or West · markets under each callout"
        case .director:
            return "One market · districts under each callout"
        case .districtManager:
            return "Your district · stores under each callout"
        case .om:
            return "Your OM book · assigned stores under each callout"
        }
    }

    var symbol: String {
        switch self {
        case .backstage: return "building.2.fill"
        case .evp: return "map.fill"
        case .director: return "chart.bar.doc.horizontal.fill"
        case .districtManager: return "square.grid.2x2.fill"
        case .om: return "person.crop.rectangle.stack.fill"
        }
    }

    var showsOnlyRiskAndWatch: Bool { self != .backstage }

    var dashboardGrain: DashScopeGrain? {
        switch self {
        case .backstage: return nil
        case .evp: return .division
        case .director: return .district
        case .districtManager, .om: return .store
        }
    }
}

enum DashScopeGrain: String, Sendable, Equatable {
    case division
    case district
    case store

    var title: String {
        switch self {
        case .division: return "Markets"
        case .district: return "Districts"
        case .store: return "Stores"
        }
    }

    var unit: String {
        switch self {
        case .division: return "markets"
        case .district: return "districts"
        case .store: return "stores"
        }
    }

    var symbol: String {
        switch self {
        case .division: return "map.fill"
        case .district: return "square.grid.2x2.fill"
        case .store: return "storefront.fill"
        }
    }
}

struct DashScopeLine: Identifiable, Equatable, Sendable {
    var label: String
    var value: String
    var health: Health
    var count: Int
    var id: String { label }
}

struct DashScopePack: Identifiable, Equatable, Sendable {
    var line: DashScopeLine
    var flags: [HeartbeatMath.FiveStarFlag]
    var id: String { line.label }
}

struct DashboardFilters: Equatable, Codable {
    var region = ""
    var division = ""
    var district = ""
    var om = ""
    var store = ""

    var isActive: Bool {
        !region.isEmpty || !division.isEmpty || !district.isEmpty || !om.isEmpty || !store.isEmpty
    }

    var summary: String {
        summaryParts.map(\.text).joined(separator: " · ")
    }

    var summaryParts: [(text: String, active: Bool)] {
        [
            (Self.display(region, empty: "All regions"), !region.isEmpty),
            (Self.display(division, empty: "All divisions"), !division.isEmpty),
            (Self.display(district, empty: "All districts", prefix: "District "), !district.isEmpty),
            (Self.display(om, empty: "All OMs"), !om.isEmpty),
            (Self.display(store, empty: "All stores"), !store.isEmpty),
        ]
    }

    func includesDivision(_ value: String) -> Bool {
        let selected = Self.parts(division)
        if !selected.isEmpty {
            return selected.contains { MarketRegion.matchesDivision(value, $0) }
        }
        let selectedRegions = Self.parts(region)
        if !selectedRegions.isEmpty {
            return selectedRegions.contains { MarketRegion(rawValue: $0)?.contains(value) == true }
        }
        return true
    }

    func includesDistrict(_ value: String) -> Bool {
        let selected = Self.parts(district)
        if selected.isEmpty { return true }
        return selected.contains { HeartbeatMath.matches(value, $0) }
    }

    func includesOM(_ value: String) -> Bool {
        let selected = Self.parts(om)
        if selected.isEmpty { return true }
        return selected.contains { HeartbeatMath.matches(value, $0) }
    }

    func includesStore(_ value: String) -> Bool {
        let selected = Self.parts(store)
        if selected.isEmpty { return true }
        return selected.contains {
            HeartbeatMath.matches(value, $0) || HeartbeatMath.matches(HeartbeatMath.canonicalStore(value), HeartbeatMath.canonicalStore($0))
        }
    }

    var regionDivisions: [String] {
        Self.parts(region).flatMap { MarketRegion(rawValue: $0)?.divisions ?? [] }
    }

    var regions: [String] { Self.parts(region) }
    var divisions: [String] { Self.parts(division) }
    var districts: [String] { Self.parts(district) }
    var oms: [String] { Self.parts(om) }
    var stores: [String] { Self.parts(store) }

    static func parts(_ raw: String) -> [String] {
        raw.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    static func display(_ raw: String, empty: String, prefix: String = "") -> String {
        let values = parts(raw)
        if values.isEmpty { return empty }
        if values.count == 1 { return prefix + values[0] }
        if values.count == 2 { return prefix + values[0] + ", " + values[1] }
        return prefix + values[0] + " + \(values.count - 1) more"
    }

    enum CodingKeys: String, CodingKey { case region, division, district, om, store }

    init() {}

    init(region: String = "", division: String, district: String, om: String, store: String) {
        self.region = region
        self.division = division
        self.district = district
        self.om = om
        self.store = store
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        region = try c.decodeIfPresent(String.self, forKey: .region) ?? ""
        division = try c.decodeIfPresent(String.self, forKey: .division) ?? ""
        district = try c.decodeIfPresent(String.self, forKey: .district) ?? ""
        om = try c.decodeIfPresent(String.self, forKey: .om) ?? ""
        store = try c.decodeIfPresent(String.self, forKey: .store) ?? ""
        sanitize()
    }

    mutating func sanitize() {
        division = MarketRegion.uniqueNames(divisions).joined(separator: "\n")
        district = Self.uniqueNormalized(districts.map(HeartbeatMath.canonicalDistrict))
        om = Self.uniqueNormalized(oms.map(HeartbeatMath.canonicalOM))
        store = Self.uniqueNormalized(stores.map(HeartbeatMath.canonicalStore))
    }

    private static func uniqueNormalized(_ values: [String]) -> String {
        var seen = Set<String>()
        var out: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(HeartbeatMath.normalize(trimmed)).inserted {
                out.append(trimmed)
            }
        }
        return out.joined(separator: "\n")
    }
}

enum MarketRegion: String, CaseIterable, Identifiable, Sendable {
    case east = "East Region"
    case south = "South Region"
    case california = "California Region"
    case west = "West Region"

    var id: String { rawValue }

    var divisions: [String] {
        switch self {
        case .east: return ["Shaws", "Mid-Atlantic", "Mid Atlantic", "Jewel Osco"]
        case .south: return ["Southern", "United", "Southwest"]
        case .california: return ["NorCal", "SoCal"]
        case .west: return ["Mountain West", "Seattle", "Haggen", "Portland"]
        }
    }

    static let officialDivisions = [
        "Shaws", "Mid-Atlantic", "Jewel Osco",
        "Southern", "United", "Southwest",
        "NorCal", "SoCal",
        "Mountain West", "Seattle", "Haggen", "Portland",
    ]

    var displayDivisions: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for name in gateDivisions + divisions {
            let canonical = Self.canonicalName(name)
            guard !canonical.isEmpty else { continue }
            if seen.insert(HeartbeatMath.compactKey(canonical)).inserted {
                out.append(canonical)
            }
        }
        return out
    }

    var gateDivisions: [String] {
        switch self {
        case .east: return ["Shaws", "Jewel Osco", "Mid-Atlantic"]
        case .south: return ["Southern", "United", "Southwest"]
        case .california: return ["NorCal", "SoCal"]
        case .west: return ["Mountain West", "Seattle", "Portland", "Haggen"]
        }
    }

    func contains(_ division: String) -> Bool {
        divisions.contains { Self.matchesDivision(division, $0) }
            || divisions.contains { Self.matchesDivision(Self.canonicalName(division), $0) }
    }

    static func containing(_ division: String) -> MarketRegion? {
        allCases.first { $0.contains(division) }
    }

    static func matchesDivision(_ lhs: String, _ rhs: String) -> Bool {
        let a = canonicalName(lhs)
        let b = canonicalName(rhs)
        if !a.isEmpty, !b.isEmpty { return HeartbeatMath.compactKey(a) == HeartbeatMath.compactKey(b) }
        return HeartbeatMath.compactKey(lhs) == HeartbeatMath.compactKey(rhs) && !HeartbeatMath.compactKey(lhs).isEmpty
    }

    static let ignoredDivisionKeys: Set<String> = [
        "total", "grandtotal", "all", "alldivisions", "allmarkets", "company",
        "na", "none", "null", "blank", "unassigned", "unknown",
    ]

    static let regionKeys: Set<String> = [
        "east", "west", "south", "california",
        "eastregion", "westregion", "southregion", "californiaregion",
    ]

    static func canonicalName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        var compact = HeartbeatMath.normalize(
            trimmed.replacingOccurrences(of: "[-'’./]", with: " ", options: .regularExpression)
        )
        compact = compact.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        for suffix in [" division", " div", " market", " banner", " region"] {
            if compact.hasSuffix(suffix) {
                compact = String(compact.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        var key = HeartbeatMath.compactKey(compact)
        for suffix in ["division", "div", "market", "banner", "region"] where key.hasSuffix(suffix) && key.count > suffix.count {
            key.removeLast(suffix.count)
        }
        if ignoredDivisionKeys.contains(key) || regionKeys.contains(key) { return "" }
        if key == "midatlantic" || compact.hasPrefix("mid atlantic") { return "Mid-Atlantic" }
        if key.hasPrefix("united") { return "United" }
        if key.contains("jewel") { return "Jewel Osco" }
        if key == "shaws" || key.hasPrefix("shaw") { return "Shaws" }
        if key == "norcal" || key == "nocal" || key == "northerncalifornia" { return "NorCal" }
        if key == "socal" || key == "southerncalifornia" || key == "southerncal" { return "SoCal" }
        if key.contains("mountainwest") { return "Mountain West" }
        if key == "haggen" || key.hasPrefix("haggen") { return "Haggen" }
        if key == "portland" || key.hasPrefix("portland") { return "Portland" }
        if key == "seattle" || key.hasPrefix("seattle") { return "Seattle" }
        if key == "southwest" || key.hasPrefix("southwest") { return "Southwest" }
        if key == "southern" { return "Southern" }
        for official in officialDivisions {
            if key == HeartbeatMath.compactKey(official) { return official }
        }
        return ""
    }

    static func uniqueNames(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in values {
            let name = canonicalName(raw)
            guard !name.isEmpty else { continue }
            if seen.insert(HeartbeatMath.compactKey(name)).inserted {
                out.append(name)
            }
        }
        return out
    }

    static func divisionChoices(regions: [String]) -> [String] {
        if regions.isEmpty { return officialDivisions }
        var seen = Set<String>()
        var out: [String] = []
        for region in regions.compactMap({ MarketRegion(rawValue: $0) }) {
            for name in region.displayDivisions {
                if seen.insert(HeartbeatMath.compactKey(name)).inserted {
                    out.append(name)
                }
            }
        }
        return out
    }

    static func companyDivisions(for filters: DashboardFilters) -> [String] {
        let selectedDivisions = DashboardFilters.parts(filters.division)
        if !selectedDivisions.isEmpty {
            return uniqueNames(selectedDivisions)
        }
        let selectedRegions = DashboardFilters.parts(filters.region)
        if !selectedRegions.isEmpty {
            var seen: Set<String> = []
            var out: [String] = []
            for region in selectedRegions.compactMap({ MarketRegion(rawValue: $0) }) {
                for name in region.displayDivisions {
                    if seen.insert(HeartbeatMath.normalize(name)).inserted {
                        out.append(name)
                    }
                }
            }
            return out
        }
        return allCases.flatMap(\.displayDivisions)
    }
}

enum FilterFocus: String, CaseIterable, Identifiable, Sendable {
    case region
    case division
    case district
    case om
    case store

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .region: return "globe.americas.fill"
        case .division: return "building.2.fill"
        case .district: return "square.grid.2x2.fill"
        case .om: return "person.2.fill"
        case .store: return "storefront.fill"
        }
    }

    var title: String {
        switch self {
        case .region: return "Region"
        case .division: return "Division"
        case .district: return "District"
        case .om: return "Operations manager"
        case .store: return "Store #"
        }
    }

    var chipTitle: String {
        switch self {
        case .region: return "Region"
        case .division: return "Division"
        case .district: return "District"
        case .om: return "OM"
        case .store: return "Store"
        }
    }

    var prompt: String {
        switch self {
        case .region: return "Type a region"
        case .division: return "Type a division"
        case .district: return "Type a district"
        case .om: return "Type an OM name"
        case .store: return "Type a store number"
        }
    }

    var allLabel: String {
        switch self {
        case .region: return "All regions"
        case .division: return "All divisions"
        case .district: return "All districts"
        case .om: return "All operations managers"
        case .store: return "All stores"
        }
    }
}

extension DashboardFilters {
    func values(for focus: FilterFocus) -> [String] {
        switch focus {
        case .region: return Self.parts(region)
        case .division: return Self.parts(division)
        case .district: return Self.parts(district)
        case .om: return Self.parts(om)
        case .store: return Self.parts(store)
        }
    }

    mutating func toggle(_ value: String, in focus: FilterFocus) {
        if value.isEmpty {
            switch focus {
            case .region: region = ""
            case .division: division = ""
            case .district: district = ""
            case .om: om = ""
            case .store: store = ""
            }
            return
        }
        var current = values(for: focus)
        let incoming = focus == .division ? MarketRegion.canonicalName(value) : value
        let matches: (String) -> Bool = { item in
            if focus == .division {
                return MarketRegion.matchesDivision(item, incoming)
                    || HeartbeatMath.matches(MarketRegion.canonicalName(item), incoming)
            }
            return HeartbeatMath.matches(item, incoming)
        }
        if current.contains(where: matches) {
            current.removeAll(where: matches)
        } else {
            current.append(incoming)
            if focus == .division {
                current = MarketRegion.uniqueNames(current)
            }
        }
        let joined = current.joined(separator: "\n")
        switch focus {
        case .region:
            region = joined
            let allowed = regionDivisions
            if !division.isEmpty {
                division = Self.parts(division).filter { name in
                    allowed.contains { MarketRegion.matchesDivision(name, $0) }
                }.joined(separator: "\n")
            }
        case .division: division = joined
        case .district: district = joined
        case .om: om = joined
        case .store: store = joined
        }
    }
}

struct HeartbeatSnapshot: Codable {
    var rows: [MetricRow]
    var uploads: [UploadRecord]
    var seeded: Bool
    var filters: DashboardFilters

    enum CodingKeys: String, CodingKey { case rows, uploads, seeded, filters }

    init(rows: [MetricRow], uploads: [UploadRecord], seeded: Bool, filters: DashboardFilters) {
        self.rows = rows
        self.uploads = uploads
        self.seeded = seeded
        self.filters = filters
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rows = try c.decodeIfPresent([MetricRow].self, forKey: .rows) ?? []
        uploads = try c.decodeIfPresent([UploadRecord].self, forKey: .uploads) ?? []
        seeded = try c.decodeIfPresent(Bool.self, forKey: .seeded) ?? !rows.isEmpty
        filters = try c.decodeIfPresent(DashboardFilters.self, forKey: .filters) ?? DashboardFilters()
    }
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
        return String(format: "%.2f%%", value)
    }

    static func num(_ value: Double?, digits: Int = 0) -> String {
        guard let value else { return "—" }
        if digits == 0 {
            return NumberFormatter.localizedString(from: NSNumber(value: value.rounded()), number: .decimal)
        }
        return String(format: "%.\(digits)f", value)
    }

    static func money(_ value: Double?) -> String {
        guard let value else { return "—" }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        if abs(value - value.rounded()) < 0.005 {
            formatter.maximumFractionDigits = 0
            formatter.minimumFractionDigits = 0
            return "$" + (formatter.string(from: NSNumber(value: value.rounded())) ?? "0")
        }
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return "$" + (formatter.string(from: NSNumber(value: value)) ?? "0")
    }

    static func shortDate(_ iso: String?) -> String {
        guard let iso, iso.count >= 10 else { return "—" }
        let parts = iso.prefix(10).split(separator: "-")
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
            return String(iso.prefix(10))
        }
        return "\(month)/\(day)/\(String(format: "%02d", year % 100))"
    }

    static func moneyShort(_ value: Double?) -> String {
        guard let value else { return "—" }
        if abs(value) >= 1_000_000 {
            return String(format: "$%.2fM", value / 1_000_000)
        }
        return money(value.rounded())
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
        case .pickPath, .pickPathPicker:
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
        case .labor:
            return StoreCellViewModel(
                primary: HeartbeatFormat.pct(row.number("target_vs_actual_pct")),
                extra: "Cost \(HeartbeatFormat.pct(row.number("cost_trgt_pct"))) · Act \(HeartbeatFormat.pct(row.number("act_cost_pct")))"
            )
        case .pickerScorecard:
            return StoreCellViewModel(
                primary: HeartbeatFormat.num(row.number("pph"), digits: 1),
                extra: HeartbeatMath.pickerOpportunityText(row)
            )
        case .lostRevenue:
            return StoreCellViewModel(
                primary: HeartbeatFormat.money(row.number("lost_revenue")),
                extra: "\(HeartbeatFormat.pct(row.number("lost_revenue_pct"))) of \(HeartbeatFormat.money(row.number("ecomm_sales"))) sales"
            )
        case .missingItems, .preSubOOS:
            let rate = row.number(MissingItemDept.totalKey)
            let gap = rate.map { $0 - HeartbeatMath.missingItemsGoal }
            let gapText: String
            if let gap {
                gapText = gap <= 0
                    ? "\(HeartbeatFormat.num(abs(gap), digits: 1)) under 5%"
                    : "+\(HeartbeatFormat.num(gap, digits: 1)) vs 5%"
            } else {
                gapText = "Goal 5%"
            }
            return StoreCellViewModel(
                primary: HeartbeatFormat.pct(rate),
                extra: gapText
            )
        case .aisleMapper:
            return StoreCellViewModel(
                primary: HeartbeatFormat.shortDate(AisleMapperMath.mapperISO(row)),
                extra: "Seq \(HeartbeatFormat.shortDate(AisleMapperMath.sequenceISO(row)))"
            )
        }
    }
}

enum LaborFocus: String, CaseIterable, Identifiable {
    case all
    case healthy
    case watch
    case risk

    var id: String { rawValue }
}

enum LostRevenueFocus: String, CaseIterable, Identifiable {
    case all
    case healthy
    case watch
    case risk

    var id: String { rawValue }
}

enum MissingItemsFocus: String, CaseIterable, Identifiable {
    case all
    case healthy
    case watch
    case risk

    var id: String { rawValue }
}

struct LaborDay: Codable, Identifiable, Hashable {
    var date: String
    var scheduleEfficiencyPct: Double?
    var schHrs: Double?
    var empowerHrs: Double?
    var earnedHrs: Double?
    var earnedHrsUtil: Double?
    var actCostPct: Double?
    var overSchedulePct: Double?
    var chargedHrs: Double?

    var id: String { date }
}

enum FiveStarFocus: String, CaseIterable, Identifiable {
    case all
    case atFive
    case pass
    case fail
    case flash
    case presub
    case coe
    case ott
    case oth

    var id: String { rawValue }
}

enum PrepFocus: String, CaseIterable, Identifiable {
    case all
    case atGoal
    case above25

    var id: String { rawValue }
}

enum ScheduleFocus: String, CaseIterable, Identifiable {
    case all
    case atGoal
    case underRisk
    case overRisk

    var id: String { rawValue }
}

enum PPHFocus: String, CaseIterable, Identifiable {
    case all
    case atGoal
    case below74

    var id: String { rawValue }
}

enum DynacapFocus: String, CaseIterable, Identifiable {
    case all
    case atGoal
    case below60

    var id: String { rawValue }
}

enum PickPathFocus: String, CaseIterable, Identifiable {
    case all
    case atGoal
    case below80

    var id: String { rawValue }
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
    case oos
    case refund

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
        case .oos: return "OOS"
        case .refund: return "Refund"
        }
    }
}

enum PickerSort: String, CaseIterable, Identifiable {
    case pph, presub, oos, ott, oth5, refund, name, store, status
    var id: String { rawValue }

    var title: String {
        switch self {
        case .pph: return "PPH"
        case .presub: return "Presub"
        case .oos: return "OOS"
        case .ott: return "OTT"
        case .oth5: return "OTH5"
        case .refund: return "Refund"
        case .name: return "Picker"
        case .store: return "Store"
        case .status: return "Status"
        }
    }

    var defaultAscending: Bool {
        switch self {
        case .name, .store, .pph, .ott, .oth5, .status: return true
        case .presub, .oos, .refund: return false
        }
    }
}

