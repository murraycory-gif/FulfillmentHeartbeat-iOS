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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fiveStar: return "5 Star Metrics"
        case .pickPath: return "Pick Path Compliance Store"
        case .pickPathPicker: return "Pick Path Compliance Picker"
        case .prepNotReady: return "Prep Not Ready"
        case .dynacap: return "Dynacap Setting"
        case .scheduleQuality: return "Schedule Quality"
        case .pph: return "PPH Pure Picks Per Hour"
        case .labor: return "Labor"
        case .pickerScorecard: return "Picker ScoreCard"
        case .lostRevenue: return "Loss Revenue"
        }
    }

    var short: String {
        switch self {
        case .fiveStar: return "5 Star"
        case .pickPath: return "Path Store"
        case .pickPathPicker: return "Path Picker"
        case .prepNotReady: return "Prep NR"
        case .dynacap: return "Dynacap"
        case .scheduleQuality: return "Schedule"
        case .pph: return "PPH"
        case .labor: return "Labor"
        case .pickerScorecard: return "Pickers"
        case .lostRevenue: return "Lost Rev"
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
        default:
            return nil
        }
    }

    static var dashboardCards: [MetricSection] {
        [.lostRevenue, .fiveStar, .pickPath, .prepNotReady, .dynacap, .scheduleQuality, .pickerScorecard, .pph, .labor]
    }

    static var uploadOrder: [MetricSection] {
        [.lostRevenue, .fiveStar, .pickPath, .pickPathPicker, .prepNotReady, .dynacap, .scheduleQuality, .pph, .labor, .pickerScorecard]
    }

    static var checklistSections: [MetricSection] {
        dashboardCards
    }
}

enum Health: String, Codable, Equatable {
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
    static func latestPerStore(_ rows: [MetricRow]) -> [MetricRow] {
        var map: [String: MetricRow] = [:]
        for row in rows {
            if isIgnoredStore(row.storeNumber) { continue }
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
            if current.division.isEmpty, !row.division.isEmpty {
                current.division = MarketRegion.canonicalName(row.division)
            }
            if current.district.isEmpty, !row.district.isEmpty { current.district = row.district }
            if current.om.isEmpty, !row.operationsOM.isEmpty { current.om = row.operationsOM }
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
        }
    }

    static let pnrGoal = 1.9
    static let pnrWatch = 2.5
    static let pphGoal = 80.0
    static let pphRisk = 74.0
    static let laborWatch = 3.0
    static let lostRevenueGood = 3.0
    static let lostRevenueWatch = 5.0
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
        let ranks: [Health: Int] = [.none: 0, .good: 1, .watch: 2, .risk: 3]
        return [under, over, efficiency].max { (ranks[$0] ?? 0) < (ranks[$1] ?? 0) } ?? .watch
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

    static func makeChecklistItem(
        section: MetricSection,
        row: MetricRow,
        division: String,
        pickers: [MetricRow],
        pathPickers: [MetricRow]
    ) -> ChecklistDriverItem {
        let cell = StoreCellViewModel.make(section: section, row: row)
        let store = canonicalStore(row.storeNumber)
        let storePickers = pickers.filter { canonicalStore($0.storeNumber) == store && isRealPicker($0) }
        let storePath = pathPickers.filter { canonicalStore($0.storeNumber) == store && isRealPicker($0) }
        let note = diagnose(section: section, row: row, pickers: storePickers, pathPickers: storePath)
        return ChecklistDriverItem(
            id: "store-\(store)",
            title: "Store \(row.storeNumber)",
            subtitle: division.isEmpty ? "Store" : division,
            value: cell.primary,
            health: health(for: section, row: row),
            broken: note.broken,
            shoppers: note.shoppers,
            action: note.action
        )
    }

    private struct ChecklistNote {
        var broken: String
        var shoppers: String
        var action: String
    }

    private static func diagnose(
        section: MetricSection,
        row: MetricRow,
        pickers: [MetricRow],
        pathPickers: [MetricRow]
    ) -> ChecklistNote {
        let hits = brokenKPIs(section: section, row: row)
        let broken = hits.isEmpty
            ? "Score is off goal — open the scorecard for the full mix."
            : hits.map { "\($0.name) \($0.value)  (need \($0.need))" }.joined(separator: "  ·  ")
        let names = coachNames(hits: hits, pickers: pickers, pathPickers: pathPickers)
        let shoppers = names.isEmpty
            ? (pickers.isEmpty && pathPickers.isEmpty
               ? "No shopper names in the picker file for this store."
               : "No one shopper is the outlier — this is a store process miss.")
            : names.joined(separator: "  ·  ")
        return ChecklistNote(broken: broken, shoppers: shoppers, action: actionLine(section: section, hits: hits, names: names, row: row))
    }

    private struct KPIHit {
        var name: String
        var value: String
        var need: String
        var health: Health
        var coach: String
    }

    private static func brokenKPIs(section: MetricSection, row: MetricRow) -> [KPIHit] {
        var hits: [KPIHit] = []
        func add(_ name: String, _ value: String, _ need: String, _ health: Health, _ coach: String) {
            if health == .risk || health == .watch {
                hits.append(KPIHit(name: name, value: value, need: need, health: health, coach: coach))
            }
        }
        switch section {
        case .fiveStar:
            if row.number("flash_pct") != nil || row.number("flash_star") != nil {
                add("Flash", HeartbeatFormat.pct(row.number("flash_pct")), "≥ 75%", flashStar(row).health, "flash")
            }
            if row.number("presub_pct") != nil || row.number("presub_star") != nil {
                add("Presub", HeartbeatFormat.pct(row.number("presub_pct")), "< 5%", presubStar(row).health, "presub")
            }
            if row.number("ott_pct") != nil || row.number("ott_star") != nil {
                add("OTT", HeartbeatFormat.pct(row.number("ott_pct")), "≥ 95%", ottStar(row).health, "ott")
            }
            if row.number("oth5_pct") != nil || row.number("oth5_star") != nil {
                add("OTH5", HeartbeatFormat.pct(row.number("oth5_pct")), "≥ 92%", othStar(row).health, "oth")
            }
            if row.number("oos_pct") != nil || row.number("oos_star") != nil {
                add("OOS", HeartbeatFormat.pct(row.number("oos_pct")), "< 3%", oosStar(row).health, "oos")
            }
            if row.number("oth_elig_pct") != nil {
                add("OTH Elig", HeartbeatFormat.pct(row.number("oth_elig_pct")), "≥ 95%", othEligStar(row).health, "ott")
            }
            if hits.isEmpty {
                add("Star rating", HeartbeatFormat.stars(row.number("star_rating")), "≥ 4.50", fiveStarHealth(row), "presub")
            }
        case .pickPath, .pickPathPicker:
            add("Path compliance", HeartbeatFormat.pct(row.number("compliance_pct")), "≥ 90%", band(row.number("compliance_pct"), good: pickPathGoal, watch: pickPathRisk), "path")
        case .prepNotReady:
            add("Prep not ready", HeartbeatFormat.pct(row.number("pnr_rate_pct")), "< 2.5%", health(for: .prepNotReady, row: row), "")
        case .dynacap:
            add("Dynacap rate", HeartbeatFormat.num(row.number("dynacap_rate", "pieces_per_hour"), digits: 1), "≥ 70", health(for: .dynacap, row: row), "")
        case .scheduleQuality:
            add("Under-scheduled", HeartbeatFormat.pct(row.number("under_schedule_pct", "under_scheduled")), "≤ 5%", varianceHealth(row.number("under_schedule_pct", "under_scheduled")), "")
            add("Over-scheduled", HeartbeatFormat.pct(row.number("over_schedule_pct", "over_scheduled")), "≤ 5%", varianceHealth(row.number("over_schedule_pct", "over_scheduled")), "")
            add("Efficiency", HeartbeatFormat.pct(row.number("schedule_efficiency_pct")), "≥ \(Int(scheduleGoal))%", band(row.number("schedule_efficiency_pct"), good: scheduleGoal, watch: scheduleWatch), "")
        case .pph:
            add("PPH", HeartbeatFormat.num(row.number("pph"), digits: 1), "≥ \(Int(pphGoal))", pphHealth(row), "pph")
        case .labor:
            add("Schedule efficiency", HeartbeatFormat.pct(row.number("schedule_efficiency_pct")), "≥ \(Int(scheduleGoal))%", health(for: .labor, row: row), "")
        case .lostRevenue:
            add("Lost revenue", HeartbeatFormat.money(row.number("lost_revenue")), "under 5% of eComm", health(for: .lostRevenue, row: row), "presub")
            if let pct = row.number("lost_revenue_pct") {
                add("Lost %", HeartbeatFormat.pct(pct), "< 5%", health(for: .lostRevenue, row: row), "oos")
            }
        case .pickerScorecard:
            for flag in pickerFlags(row) where flag.health == .risk || flag.health == .watch {
                hits.append(KPIHit(name: flag.name, value: "", need: "on goal", health: flag.health, coach: flag.name.lowercased()))
            }
        }
        return hits
    }

    private static func coachNames(hits: [KPIHit], pickers: [MetricRow], pathPickers: [MetricRow]) -> [String] {
        let keys = Set(hits.map(\.coach).filter { !$0.isEmpty })
        var lines: [String] = []
        var seen = Set<String>()
        func addPicker(_ row: MetricRow, tags: [String]) {
            let name = row.shopperName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { return }
            let tag = tags.prefix(3).joined(separator: " · ")
            lines.append(tag.isEmpty ? name : "\(name)  \(tag)")
        }
        if keys.contains("path") {
            for row in pathPickers.sorted(by: { ($0.number("compliance_pct") ?? 101) < ($1.number("compliance_pct") ?? 101) }).prefix(3) {
                let health = band(row.number("compliance_pct"), good: pickPathGoal, watch: pickPathRisk)
                if health == .risk || health == .watch {
                    addPicker(row, tags: ["Path \(HeartbeatFormat.pct(row.number("compliance_pct")))"])
                }
            }
        }
        let ranked = pickers.sorted { lhs, rhs in
            let a = pickerFlags(lhs).filter { $0.health == .risk }.count
            let b = pickerFlags(rhs).filter { $0.health == .risk }.count
            if a != b { return a > b }
            return (lhs.number("orders") ?? 0) > (rhs.number("orders") ?? 0)
        }
        for row in ranked {
            var tags: [String] = []
            if keys.contains("presub"), presubStar(row).health != .good {
                tags.append("Presub \(HeartbeatFormat.pct(row.number("presub_pct")))")
            }
            if keys.contains("ott"), ottStar(row).health != .good {
                tags.append("OTT \(HeartbeatFormat.pct(row.number("ott_pct")))")
            }
            if keys.contains("oth"), othStar(row).health != .good {
                tags.append("OTH5 \(HeartbeatFormat.pct(row.number("oth5_pct")))")
            }
            if keys.contains("oos"), oosStar(row).health != .good {
                tags.append("OOS \(HeartbeatFormat.pct(row.number("oos_pct")))")
            }
            if keys.contains("pph"), pphHealth(row) != .good {
                tags.append("PPH \(HeartbeatFormat.num(row.number("pph"), digits: 1))")
            }
            if keys.contains("flash"), pickerHealth(row) != .good {
                tags.append(pickerOpportunityText(row))
            }
            if !tags.isEmpty {
                addPicker(row, tags: tags)
            }
            if lines.count == 3 { break }
        }
        return lines
    }

    private static func actionLine(section: MetricSection, hits: [KPIHit], names: [String], row: MetricRow) -> String {
        let people = names.map { $0.components(separatedBy: "  ").first ?? $0 }.prefix(3)
        let who = people.joined(separator: ", ")
        let keys = Set(hits.map(\.coach))
        var parts: [String] = []
        if keys.contains("flash") {
            parts.append("Reset Flash at the huddle until Flash is 75%+.")
        }
        if keys.contains("presub") {
            parts.append(who.isEmpty
                ? "Only offer a true like-for-like substitution, then confirm."
                : "Coach \(who) on like-for-like substitutions until Presub is under 5%.")
        }
        if keys.contains("ott") || keys.contains("oth") {
            parts.append(who.isEmpty
                ? "Protect the pickup window. Walk OTT and OTH5 on the floor this week."
                : "Walk \(who) on on-time picks and keep eligible orders in the hour.")
        }
        if keys.contains("oos") {
            parts.append("Own out-of-stocks in the daily huddle until OOS is under 3%.")
        }
        if keys.contains("path") {
            parts.append(who.isEmpty
                ? "Retrain every shopper under 80% on the path map this week."
                : "Retrain \(who) on the pick path this week, on the floor.")
        }
        if keys.contains("pph") {
            parts.append(who.isEmpty
                ? "Fix path and staging. Pull non-pick work off pickers during the wave."
                : "Pair \(who) with a strong picker for two shifts, then re-measure PPH.")
        }
        if section == .prepNotReady {
            parts.append("Align bakery, deli, and meat to the pick wave. Escalate if PNR stays over 2.5%.")
        }
        if section == .dynacap {
            parts.append("Set pickup and delivery to the recommended values — no local overrides.")
        }
        if section == .scheduleQuality {
            parts.append("Rebuild the week wherever under or over is above 5%. Match coverage to the demand curve.")
        }
        if section == .labor {
            parts.append("Get Target vs Actual under 3%. Use earned hours as the daily target.")
        }
        if section == .lostRevenue {
            parts.append("Pull the top lost-item categories and own them in the huddle until lost revenue is under 5%.")
        }
        if parts.isEmpty {
            parts.append("Open the scorecard, fix the off-goal mix, and close this item when the store is back to green.")
        }
        return parts.prefix(2).joined(separator: " ")
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
    var broken: String = ""
    var shoppers: String = ""
    var action: String = ""
}

struct ChecklistDriverGroup: Identifiable, Equatable {
    var title: String
    var items: [ChecklistDriverItem]
    var id: String { title }
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

    var displayDivisions: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for name in divisions {
            let canonical = Self.canonicalName(name)
            if seen.insert(HeartbeatMath.normalize(canonical)).inserted {
                out.append(canonical)
            }
        }
        return out
    }

    func contains(_ division: String) -> Bool {
        divisions.contains { Self.matchesDivision(division, $0) }
            || divisions.contains { Self.matchesDivision(Self.canonicalName(division), $0) }
    }

    static func containing(_ division: String) -> MarketRegion? {
        allCases.first { $0.contains(division) }
    }

    static func matchesDivision(_ lhs: String, _ rhs: String) -> Bool {
        HeartbeatMath.matches(lhs, rhs)
            || HeartbeatMath.matches(
                lhs.replacingOccurrences(of: "-", with: " "),
                rhs.replacingOccurrences(of: "-", with: " ")
            )
    }

    static func canonicalName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let spaced = HeartbeatMath.normalize(trimmed.replacingOccurrences(of: "-", with: " "))
        if spaced == "mid atlantic" { return "Mid-Atlantic" }
        if spaced == "united" || spaced.hasPrefix("united ") { return "United" }
        return trimmed
    }

    static func companyDivisions(for filters: DashboardFilters) -> [String] {
        let selectedDivisions = DashboardFilters.parts(filters.division)
        if !selectedDivisions.isEmpty {
            return selectedDivisions.map { canonicalName($0) }
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

enum FilterFocus: String, Sendable {
    case region
    case division
    case district
    case om
    case store

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
        if current.contains(where: { HeartbeatMath.matches($0, value) }) {
            current.removeAll { HeartbeatMath.matches($0, value) }
        } else {
            current.append(value)
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

