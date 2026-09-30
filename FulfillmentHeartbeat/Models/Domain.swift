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
    case sales = "sales"
    case missingItems = "missing_items"
    case aisleMapper = "aisle_mapper"
    case preSubOOS = "pre_sub_oos"
    case preSubOOSItem = "pre_sub_oos_item"
    case storeRoster = "store_roster"

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
        case .sales: return "Sales"
        case .missingItems: return "Missing Items"
        case .aisleMapper: return "Aisle Mapper"
        case .preSubOOS: return "Pre-Sub OOS"
        case .preSubOOSItem: return "Pre-Sub OOS Item"
        case .storeRoster: return "Roster"
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
        case .sales: return "Sales"
        case .missingItems: return "MI"
        case .aisleMapper: return "Aisle Map"
        case .preSubOOS: return "Pre-Sub"
        case .preSubOOSItem: return "Pre-Sub Item"
        case .storeRoster: return "Roster"
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
        case .sales: return "eComm sales, orders, HD, and DUG by store. Upload the Sales ScoreCard export. Tab name in the master file is Sales."
        case .missingItems: return "Share of items without an aisle in store tag subscription data. Upload the department-wise MI export. 5% or less is healthy."
        case .aisleMapper: return "Latest aisle mapper and aisle sequence update by store. Upload the Latest Aisle Mapper and Sequence Update Date By Store export. Dates show on the Pick Path store table."
        case .preSubOOS: return "Pre-substitution OOS% by store and department. Upload Pre Substitution OOS% Division Area Store View. 5% or less is healthy."
        case .preSubOOSItem: return "Item-level Pre-Sub OOS by store. Upload Pre Substitution OOS% items by Store. Rows show on the Pre-Sub OOS ScoreCard under the store table."
        case .storeRoster: return "Company store roster. Division, district, OM, and store. Used to filter every scorecard. Master tab name: Roster."
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
        case .sales: return "Store · District · Sales $ · Sales YoY % · Orders · AOS · AIV · Items · weekday breakout"
        case .missingItems: return "Division · District · OM · Store · 301 Grocery · 303 Alcohol · 304 Pharmacy · 306 Food Service · 309 Deli · 311 GM/HBC · 314 Dairy · 315 Floral · 316 Bakery · 317 Frozen · 328 Coffee Kiosk · 329 Produce · 330 Seafood · 333 Meat · 336 Bakery Pkgd · Total"
        case .aisleMapper: return "Division · District · OM · Store · Latest Aisle Mapper Update Date · Latest Aisle Sequence Update Date"
        case .preSubOOS: return "STORE_ID · Alcohol · Bakery · Bakery Pkgd · Dairy · Deli · Floral · Food Service · Frozen · GM/HBC · Grocery · Meat · Pharmacy · Produce · Seafood · Total Pre-Sub OOS%"
        case .preSubOOSItem: return "STORE_ID · DIVISION · DISTRICT · BPN DESC · ORD_QTY · Subs · Pre-Sub OOS% · Pre-Sub OOS · $Pre-Sub OOS · OOS · OOS% · $OOS"
        case .storeRoster: return "DIVISION · DISTRICT · OM_AREA · OM_ID · STORE"
        }
    }

    var overviewLead: String {
        switch self {
        case .sales: return "Sales"
        case .lostRevenue: return "Loss Revenue"
        case .fiveStar: return "5 Star"
        case .preSubOOS: return "Pre-Sub OOS"
        case .pickPath: return "Pick Path"
        case .missingItems: return "Missing Items"
        case .prepNotReady: return "Prep Not Ready"
        case .dynacap: return "Dynacap"
        case .scheduleQuality: return "Schedule"
        case .pickerScorecard: return "Picker"
        case .pph: return "PPH"
        case .labor: return "Labor"
        default: return short
        }
    }

    var overviewTitle: String {
        switch self {
        case .sales: return "Sales Overview"
        case .lostRevenue: return "Loss Revenue"
        default: return title
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
        case .sales: return "Sales ScoreCard"
        case .missingItems: return "Missing Items ScoreCard"
        case .aisleMapper: return "Aisle Mapper"
        case .preSubOOS: return "Pre-Sub OOS ScoreCard"
        case .preSubOOSItem: return "Pre-Sub OOS Items"
        case .storeRoster: return "Roster"
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
        case .sales: return "cart.fill"
        case .missingItems: return "tag.slash.fill"
        case .aisleMapper: return "map.fill"
        case .preSubOOS: return "cart.badge.minus"
        case .preSubOOSItem: return "barcode"
        case .storeRoster: return "building.2.fill"
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
            return URL(string: "https://app.powerbi.com/groups/me/apps/d973ff03-651f-4e52-9e7a-8e5bff14b5e6/reports/5e149f25-b69e-4d6d-83c7-2bea61f951e3/ReportSectioneea6916e080ade11f562?experience=power-bi")
        case .lostRevenue:
            return URL(string: "https://app.powerbi.com/groups/me/apps/d973ff03-651f-4e52-9e7a-8e5bff14b5e6/reports/dac4848e-a28a-4e12-bfbb-b386da90f344/e57401a67b0f2379a0b3?ctid=b7f604a0-00a9-4188-9248-42f3a5aac2e9&experience=power-bi")
        case .sales:
            return URL(string: "https://app.powerbi.com/groups/me/apps/f0978345-5d6c-4de3-a8af-fee82058b466/reports/1bcd4b2b-3b1f-4070-81b4-3ba9bc3ddf62/ReportSection32d8740c6be3cdc72f2c?experience=power-bi")
        case .missingItems:
            return URL(string: "https://app.powerbi.com/groups/me/apps/d973ff03-651f-4e52-9e7a-8e5bff14b5e6/reports/47829fe7-c57f-4c65-a557-f35c99a1e851/2a870f3cf2c35df0a38b?ctid=b7f604a0-00a9-4188-9248-42f3a5aac2e9&experience=power-bi")
        case .aisleMapper:
            return URL(string: "https://app.powerbi.com/groups/me/apps/d973ff03-651f-4e52-9e7a-8e5bff14b5e6/reports/c13fc8a7-5492-4d39-bd1b-8091e2f5f99a/bc42d1e4f9041554fbad?ctid=b7f604a0-00a9-4188-9248-42f3a5aac2e9&experience=power-bi&clientSideAuth=0")
        case .preSubOOS:
            return URL(string: "https://app.powerbi.com/groups/me/apps/d973ff03-651f-4e52-9e7a-8e5bff14b5e6/reports/73aafb1b-7a54-4c96-af93-4736442edc42/ReportSection5f4b54422e8bd962800c?experience=power-bi")
        case .preSubOOSItem:
            return URL(string: "https://app.powerbi.com/groups/me/apps/d973ff03-651f-4e52-9e7a-8e5bff14b5e6/reports/5e149f25-b69e-4d6d-83c7-2bea61f951e3/ReportSection05d54238959c5bc8a4ad?experience=power-bi")
        default:
            return nil
        }
    }

    static var overviewCards: [MetricSection] {
        [.sales, .lostRevenue, .fiveStar, .preSubOOS, .pickPath, .missingItems, .prepNotReady, .dynacap, .scheduleQuality, .pickerScorecard, .pph, .labor]
    }

    static var dashboardCards: [MetricSection] {
        [.sales, .lostRevenue, .missingItems, .fiveStar, .preSubOOS, .pickPath, .prepNotReady, .dynacap, .scheduleQuality, .pickerScorecard, .pph, .labor]
    }

    static var uploadOrder: [MetricSection] {
        [.storeRoster, .sales, .lostRevenue, .missingItems, .fiveStar, .preSubOOS, .pickPath, .pickPathPicker, .aisleMapper, .prepNotReady, .dynacap, .scheduleQuality, .pph, .labor, .pickerScorecard, .preSubOOSItem]
    }

    static var checklistSections: [MetricSection] {
        dashboardCards
    }
}

/// Hub pages. Lives here so the kitchen can compile PulseLaunch without SwiftUI.
enum HubDestination: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case fiveStar
    case pickPath
    case prepNotReady
    case dynacap
    case scheduleQuality
    case scheduleCheck
    case pph
    case labor
    case pickerScorecard
    case sales
    case lostRevenue
    case missingItems
    case preSubOOS
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .fiveStar: return MetricSection.fiveStar.title
        case .pickPath: return MetricSection.pickPath.title
        case .prepNotReady: return MetricSection.prepNotReady.title
        case .dynacap: return MetricSection.dynacap.title
        case .scheduleQuality: return MetricSection.scheduleQuality.title
        case .scheduleCheck: return "Upcoming Weeks Schedule Check"
        case .pph: return MetricSection.pph.title
        case .labor: return MetricSection.labor.title
        case .pickerScorecard: return MetricSection.pickerScorecard.title
        case .sales: return MetricSection.sales.bannerTitle
        case .lostRevenue: return "Loss Revenue ScoreCard"
        case .missingItems: return MetricSection.missingItems.bannerTitle
        case .preSubOOS: return MetricSection.preSubOOS.bannerTitle
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .fiveStar: return MetricSection.fiveStar.symbol
        case .pickPath: return MetricSection.pickPath.symbol
        case .prepNotReady: return MetricSection.prepNotReady.symbol
        case .dynacap: return MetricSection.dynacap.symbol
        case .scheduleQuality: return MetricSection.scheduleQuality.symbol
        case .scheduleCheck: return "calendar.badge.exclamationmark"
        case .pph: return MetricSection.pph.symbol
        case .labor: return MetricSection.labor.symbol
        case .pickerScorecard: return MetricSection.pickerScorecard.symbol
        case .sales: return MetricSection.sales.symbol
        case .lostRevenue: return MetricSection.lostRevenue.symbol
        case .missingItems: return MetricSection.missingItems.symbol
        case .preSubOOS: return MetricSection.preSubOOS.symbol
        case .settings: return "gearshape.fill"
        }
    }

    var section: MetricSection? {
        switch self {
        case .fiveStar: return .fiveStar
        case .pickPath: return .pickPath
        case .prepNotReady: return .prepNotReady
        case .dynacap: return .dynacap
        case .scheduleQuality: return .scheduleQuality
        case .pph: return .pph
        case .labor: return .labor
        case .pickerScorecard: return .pickerScorecard
        case .sales: return .sales
        case .lostRevenue: return .lostRevenue
        case .missingItems: return .missingItems
        case .preSubOOS: return .preSubOOS
        case .dashboard, .settings, .scheduleCheck: return nil
        }
    }

    static func from(section: MetricSection) -> HubDestination {
        switch section {
        case .fiveStar: return .fiveStar
        case .pickPath, .pickPathPicker: return .pickPath
        case .prepNotReady: return .prepNotReady
        case .dynacap: return .dynacap
        case .scheduleQuality: return .scheduleQuality
        case .pph: return .pph
        case .labor: return .labor
        case .pickerScorecard: return .pickerScorecard
        case .sales: return .sales
        case .lostRevenue: return .lostRevenue
        case .missingItems: return .missingItems
        case .preSubOOS, .preSubOOSItem: return .preSubOOS
        case .aisleMapper: return .pickPath
        case .storeRoster: return .dashboard
        }
    }

    static var sectionItems: [HubDestination] { [.dashboard, .sales, .lostRevenue, .missingItems, .fiveStar, .preSubOOS, .pickPath, .prepNotReady, .dynacap, .scheduleQuality, .scheduleCheck, .pickerScorecard, .pph, .labor] }
    static var settingsItems: [HubDestination] { [.settings] }
    static var primaryTabs: [HubDestination] { [.dashboard] }
    static var metricItems: [HubDestination] { [.sales, .lostRevenue, .missingItems, .fiveStar, .preSubOOS, .pickPath, .prepNotReady, .dynacap, .scheduleQuality, .pickerScorecard, .pph, .labor] }
}

/// Sales expand math. Lives here so the kitchen can compile PulseLaunch without SwiftUI.
struct SalesPack {
    let sales: Double?
    let yoy: Double?
    let orders: Double?
    let ordersYoy: Double?
    let aos: Double?
    let aiv: Double?
    let items: Double?
    let ipt: Double?
    let hd: Double?
    let dug: Double?
    let health: Health

    init(_ row: MetricRow, prefix: String = "sales_") {
        if prefix == "sales_" {
            let week = row.number("sales_dollars")
            let days = HeartbeatMath.salesHeadlineDollars(row)
            sales = max(week ?? 0, days) == 0 ? week : max(week ?? 0, days)
        } else {
            sales = row.number(prefix + "dollars")
        }
        yoy = row.number(prefix + "yoy_pct")
        orders = row.number(prefix + "orders")
        ordersYoy = row.number(prefix + "orders_yoy_pct")
        aos = row.number(prefix + "aos") ?? row.number(prefix + "aov")
        aiv = row.number(prefix + "aiv")
        items = row.number(prefix + "items")
        ipt = row.number(prefix + "ipt")
        hd = row.number(prefix + "hd_orders")
        dug = row.number(prefix + "dug_orders")
        health = HeartbeatMath.salesHealth(planPct: nil, yoy: yoy)
    }

    /// Company math: sum $, sum orders, sum items. YoY is this-year vs last-year, not an average of store %.
    /// AOS = $/orders. AIV = $/items. Items/txn = items/orders.
    init(rows: [MetricRow]) {
        let sales = rows.reduce(0) { $0 + HeartbeatMath.salesHeadlineDollars($1) }
        let orders = rows.reduce(0) { $0 + HeartbeatMath.salesOrders($1) }
        let items = rows.reduce(0) { $0 + HeartbeatMath.salesItems($1) }
        let hd = rows.compactMap { $0.number("sales_hd_orders") }.reduce(0, +)
        let dug = rows.compactMap { $0.number("sales_dug_orders") }.reduce(0, +)
        self.sales = sales
        self.orders = orders
        self.items = items
        self.hd = hd
        self.dug = dug
        self.yoy = HeartbeatMath.salesRollupYoY(
            current: rows.map { HeartbeatMath.salesHeadlineDollars($0) },
            yoyPct: rows.map { $0.number("sales_yoy_pct") }
        )
        self.aos = orders > 0 ? sales / orders : nil
        self.aiv = items > 0 ? sales / items : nil
        self.ipt = orders > 0 ? items / orders : nil
        self.ordersYoy = HeartbeatMath.salesRollupYoY(
            current: rows.map { HeartbeatMath.salesOrders($0) },
            yoyPct: rows.map { $0.number("sales_orders_yoy_pct") }
        )
        self.health = HeartbeatMath.salesHealth(planPct: nil, yoy: yoy)
    }

    /// Company-wide Total uses the pack `sales_grain=company` row when present.
    init(company: MetricRow?, stores: [MetricRow]) {
        if let company, HeartbeatMath.salesHeadlineDollars(company) > 0 {
            self.init(company)
        } else {
            self.init(rows: stores)
        }
    }

    init(
        sales: Double?,
        yoy: Double?,
        orders: Double?,
        ordersYoy: Double?,
        aos: Double?,
        aiv: Double?,
        items: Double?,
        ipt: Double?,
        hd: Double?,
        dug: Double?,
        health: Health
    ) {
        self.sales = sales
        self.yoy = yoy
        self.orders = orders
        self.ordersYoy = ordersYoy
        self.aos = aos
        self.aiv = aiv
        self.items = items
        self.ipt = ipt
        self.hd = hd
        self.dug = dug
        self.health = health
    }
}

struct SalesRollupRow: Identifiable {
    var id: String { label }
    let label: String
    let storeCount: Int
    let pack: SalesPack
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

/// Formatted company-scope card tiles. Labels match the phone card. Values are the workbook rollup, not an empty fact walk.
struct CompanyCardTiles: Codable, Equatable {
    var labels: [String]
    var values: [String]
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
            let value = textPayload[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !value.isEmpty { return value }
        }
        if let id = shopperId?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
            return id
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

struct SectionSummary: Identifiable, Equatable, Codable {
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
    var salesYoyPct: Double? = nil

    var id: MetricSection { section }

    enum CodingKeys: String, CodingKey {
        case section, storeCount, headline, headlineLabel, secondary, health
        case watchCount, riskCount, lastFilename, lastUploadedAt
        case underScheduledCount, overScheduledCount, lostRevenuePct, salesYoyPct
    }

    init(
        section: MetricSection,
        storeCount: Int,
        headline: Double?,
        headlineLabel: String,
        secondary: String,
        health: Health,
        watchCount: Int,
        riskCount: Int,
        lastFilename: String?,
        lastUploadedAt: Date?,
        underScheduledCount: Int = 0,
        overScheduledCount: Int = 0,
        lostRevenuePct: Double? = nil,
        salesYoyPct: Double? = nil
    ) {
        self.section = section
        self.storeCount = storeCount
        self.headline = headline
        self.headlineLabel = headlineLabel
        self.secondary = secondary
        self.health = health
        self.watchCount = watchCount
        self.riskCount = riskCount
        self.lastFilename = lastFilename
        self.lastUploadedAt = lastUploadedAt
        self.underScheduledCount = underScheduledCount
        self.overScheduledCount = overScheduledCount
        self.lostRevenuePct = lostRevenuePct
        self.salesYoyPct = salesYoyPct
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        section = try container.decode(MetricSection.self, forKey: .section)
        storeCount = try container.decode(Int.self, forKey: .storeCount)
        headline = try container.decodeIfPresent(Double.self, forKey: .headline)
        headlineLabel = try container.decode(String.self, forKey: .headlineLabel)
        secondary = try container.decode(String.self, forKey: .secondary)
        health = try container.decode(Health.self, forKey: .health)
        watchCount = try container.decode(Int.self, forKey: .watchCount)
        riskCount = try container.decode(Int.self, forKey: .riskCount)
        lastFilename = try container.decodeIfPresent(String.self, forKey: .lastFilename)
        lastUploadedAt = try container.decodeIfPresent(Date.self, forKey: .lastUploadedAt)
        underScheduledCount = try container.decodeIfPresent(Int.self, forKey: .underScheduledCount) ?? 0
        overScheduledCount = try container.decodeIfPresent(Int.self, forKey: .overScheduledCount) ?? 0
        lostRevenuePct = try container.decodeIfPresent(Double.self, forKey: .lostRevenuePct)
        salesYoyPct = try container.decodeIfPresent(Double.self, forKey: .salesYoyPct)
    }

    var headlineText: String {
        if PulseLaunch.isPrepEmptyChrome(self) {
            return PulseLaunch.prepEmptyRateText
        }
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
        if section == .lostRevenue || section == .sales {
            return HeartbeatFormat.money(headline)
        }
        if section == .labor {
            return String(format: "%.2f%%", headline)
        }
        return String(format: "%.1f%%", headline)
    }
}

/// Band lines for health, `AssistRank.offBand`, and the plan breakpoint. One table.
enum AssistScoreLine {
    static let pickPathGoal = 90.0
    /// Same 5 Star goal the Scorecard prints. Pass stays 4.0; it is not goal minus 0.5.
    static let fiveStarGoal = 5.0
    static let fiveStarPass = 4.0
    /// Store row and Rating cell. 4.7 is good, 4.2 is watch, below 4.0 is risk.
    /// The printed goal stays 5.00.
    static let fiveStarStoreGood = 4.5
    static let salesWatch = -3.0
    static let laborGoal = 0.0
    static let scheduleWatch = 85.0
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
        var pin: [MetricSection] = [.sales, .lostRevenue, .fiveStar, .labor, .pickerScorecard]
        if role == .evp {
            pin.append(contentsOf: [.fiveStar, .dynacap])
        } else if role == .director {
            pin.append(contentsOf: [.fiveStar, .labor, .dynacap, .pickerScorecard])
        } else if role == .districtManager {
            pin.append(contentsOf: [.fiveStar, .labor, .dynacap])
        }
        let restRiskWatch = !storeScoped && (
            role == .evp || role == .director || role == .districtManager || role?.showsOnlyRiskAndWatch == true
        )
        return pinnedCallouts(cards, pin: pin, restRiskWatch: restRiskWatch)
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

    static func rowsFillingRoster(_ rows: [MetricRow], roster: [String: StoreIdentity]) -> [MetricRow] {
        guard !roster.isEmpty else { return rows }
        return rows.map { stampRoster($0, roster: roster) }
    }

    static func stampRoster(_ row: MetricRow, roster: [String: StoreIdentity]) -> MetricRow {
        let store = canonicalStore(row.storeNumber)
        guard !store.isEmpty else { return row }
        var identity = roster[store]
        if identity == nil {
            for alias in storeAliases(store) {
                if let hit = roster[alias] {
                    identity = hit
                    break
                }
            }
        }
        guard let identity else { return row }
        var next = row
        let rosterCanon = MarketRegion.canonicalName(identity.division)
        let sheetDivision = MarketRegion.canonicalName(row.division)
        if !rosterCanon.isEmpty {
            // Roster DIVISION wins on every section, including Loss. The Loss
            // tab's First DIVISION column is a Power BI aggregate, not the store's market.
            next.division = rosterCanon
        } else {
            next.division = sheetDivision
        }
        if !identity.district.isEmpty {
            next.textPayload["district"] = identity.district
        }
        if next.operationsOM.isEmpty, !identity.om.isEmpty { next.operationsOM = identity.om }
        if next.storeName == nil || next.storeName?.isEmpty == true { next.storeName = identity.name }
        return next
    }

    static func dashboardScopeKey(_ row: MetricRow, grain: DashScopeGrain) -> String? {
        switch grain {
        case .region:
            return MarketRegion.resolved(division: row.division, district: row.district)?.rawValue
        case .division:
            let key = RollupMarketFill.divisionKey(row.division)
            if PulseLaunch.shouldHideUnassignedMarketGrain(), RollupMarketFill.hidesUnassignedMarket(key) {
                return nil
            }
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
        let source = section == .pickerScorecard ? latestPerShopper(rows) : rows
        var buckets: [String: [MetricRow]] = [:]
        for row in source {
            if row.textPayload["lost_grain"] == "market" { continue }
            if row.textPayload["labor_grain"] == "market" { continue }
            if row.textPayload["sales_grain"] == "company" { continue }
            if isIgnoredStore(row.storeNumber), section != .sales { continue }
            guard let key = dashboardScopeKey(row, grain: grain) else { continue }
            buckets[key, default: []].append(row)
        }
        return buckets.map { key, group -> (DashScopeLine, Double) in
            let card = scopeCard(section: section, rows: group)
            let line = DashScopeLine(
                label: displayGrainLabel(key),
                value: card.value,
                health: card.health,
                count: card.count
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

    struct DashboardGrainTableRow: Identifiable, Equatable, Sendable, Codable {
        let label: String
        let storeCount: Int
        let values: [String]
        let health: Health
        var id: String { label }
    }

    /// Column titles for the Sales-style grain table on every dashboard card.
    static func dashboardTableHeaders(_ section: MetricSection) -> [String] {
        switch section {
        case .lostRevenue:
            return ["Lost $", "Lost %", "Goal %", "eComm $", "Post Sub", "Refund", "Missed", "Cancel", "Kill"]
        case .fiveStar:
            return ["Rating", "Flash", "COE", "OTT", "Pre-Sub", "OTH"]
        case .missingItems, .preSubOOS:
            return ["Rate", "Healthy", "Watch", "At Risk"]
        case .pickPath, .pickPathPicker:
            return ["Path %", "AVG PPH"]
        case .prepNotReady:
            return ["PNR %", "Goal", "Watch"]
        case .dynacap:
            return ["Pcs/Hr", "PPH", "Util %"]
        case .scheduleQuality:
            return ["Sch Eff", "Staffing", "Under", "Over"]
        case .pph:
            return ["PPH", "At Goal", "Below 74"]
        case .labor:
            return ["Target Vs Actual", "Act Cost", "Cost Tgt", "Sch Eff", "UPLH", "Wage", "AIV"]
        case .pickerScorecard:
            return ["Shoppers", "Healthy", "Watch", "At Risk"]
        case .sales:
            return ["Sales $", "YoY %", "Orders"]
        default:
            return ["Result"]
        }
    }

    static func dashboardTableValues(
        _ section: MetricSection,
        rows: [MetricRow],
        goalFallback: Double? = nil,
        pphRows: [MetricRow] = []
    ) -> (values: [String], health: Health) {
        let health = worstHealth(section, rows: rows)
        let dash = Array(repeating: "—", count: dashboardTableHeaders(section).count)
        if rows.isEmpty {
            if section == .lostRevenue, let goal = goalFallback {
                var values = dash
                if let index = dashboardTableHeaders(section).firstIndex(of: "Goal %") {
                    values[index] = HeartbeatFormat.pct(goal)
                }
                return (values, .none)
            }
            return (dash, .none)
        }
        switch section {
        case .lostRevenue:
            let market = lostRevenueMarketRow(in: rows)
            let facts = lostRevenueStoreRows(rows).filter { hasMetricFact(.lostRevenue, $0) }
            if market == nil, facts.isEmpty {
                return (dash, .none)
            }
            let pct = lostRevenueReportedPct(rows)
            let goal = lostRevenueInheritedGoalPct(rows: rows, fallback: goalFallback)
            return (
                [
                    HeartbeatFormat.money(lostRevenueReportedValue(rows, key: "lost_revenue")),
                    HeartbeatFormat.pct(pct),
                    HeartbeatFormat.pct(goal),
                    HeartbeatFormat.money(lostRevenueReportedValue(rows, key: "ecomm_sales")),
                    HeartbeatFormat.money(lostRevenueReportedValue(rows, key: "post_sub_oos_foregone")),
                    HeartbeatFormat.money(lostRevenueReportedValue(rows, key: "refund_lost")),
                    HeartbeatFormat.money(lostRevenueReportedValue(rows, key: "missed_sales")),
                    HeartbeatFormat.money(lostRevenueReportedValue(rows, key: "cancelled_lost")),
                    HeartbeatFormat.money(lostRevenueReportedValue(rows, key: "kill_switch_lost")),
                ],
                lostRevenueStatus(pct: pct, goal: goal)
            )
        case .fiveStar:
            return (
                [
                    HeartbeatFormat.stars(average(rows.compactMap { $0.number("star_rating") })),
                    HeartbeatFormat.pct(average(rows.compactMap { $0.number("flash_pct") })),
                    HeartbeatFormat.pct(average(rows.compactMap { $0.number("coe_pct") })),
                    HeartbeatFormat.pct(average(rows.compactMap { $0.number("ott_pct") })),
                    HeartbeatFormat.pct(average(rows.compactMap { $0.number("presub_pct") })),
                    HeartbeatFormat.pct(average(rows.compactMap { $0.number("oth5_pct") })),
                ],
                health
            )
        case .missingItems, .preSubOOS:
            let stores = rows.filter { !isIgnoredStore($0.storeNumber) && !$0.storeNumber.isEmpty }
            let scoped = stores.isEmpty ? rows : stores
            return (
                [
                    HeartbeatFormat.pct(average(scoped.compactMap { $0.number(MissingItemDept.totalKey) })),
                    HeartbeatFormat.num(Double(scoped.filter { missingItemsHealth($0) == .good }.count)),
                    HeartbeatFormat.num(Double(scoped.filter { missingItemsHealth($0) == .watch }.count)),
                    HeartbeatFormat.num(Double(scoped.filter { missingItemsHealth($0) == .risk }.count)),
                ],
                health
            )
        case .pickPath, .pickPathPicker:
            return (
                [
                    HeartbeatFormat.pct(average(rows.compactMap { $0.number("compliance_pct") })),
                    HeartbeatFormat.num(average(rows.compactMap(pphNumber)), digits: 1),
                ],
                health
            )
        case .prepNotReady:
            let coverage = prepCoverage(rows)
            if coverage.thin {
                return (["—", "—", "—"], .none)
            }
            return (
                [
                    HeartbeatFormat.pct(average(rows.compactMap { $0.number("pnr_rate_pct", "pnr_hours", "prep_not_ready_pct") })),
                    String(format: "%.1f%%", pnrGoal),
                    String(format: "%.1f–%.1f%%", pnrGoal, pnrWatch),
                ],
                health
            )
        case .dynacap:
            let pcs = average(rows.compactMap { $0.number("dynacap_rate", "pieces_per_hour") })
            let pph = dynacapSeatPurePPH(dynacapRows: rows, pphRows: pphRows)
            return (
                [
                    HeartbeatFormat.num(pcs, digits: 1),
                    HeartbeatFormat.num(pph, digits: 1),
                    HeartbeatFormat.pct(average(rows.compactMap { $0.number("utilization_pct", "pickup_util_pct") })),
                ],
                health
            )
        case .scheduleQuality:
            return (
                [
                    HeartbeatFormat.pct(average(rows.compactMap { $0.number("schedule_efficiency_pct") })),
                    HeartbeatFormat.pct(average(rows.compactMap { $0.number("staffing_efficiency_pct") })),
                    HeartbeatFormat.pct(average(rows.compactMap { $0.number("under_schedule_pct", "under_scheduled", "under_staffing_pct") })),
                    HeartbeatFormat.pct(average(rows.compactMap { $0.number("over_schedule_pct", "over_scheduled", "over_staffing_pct") })),
                ],
                health
            )
        case .pph:
            let pph = weekPurePPH(rows)
            let stores = latestPerStore(rows.filter { !isIgnoredStore($0.storeNumber) && !$0.storeNumber.isEmpty })
            return (
                [
                    HeartbeatFormat.num(pph, digits: 1),
                    HeartbeatFormat.num(Double(stores.filter { (pphNumber($0) ?? 0) >= pphGoal }.count)),
                    HeartbeatFormat.num(Double(stores.filter { (pphNumber($0) ?? .greatestFiniteMagnitude) < pphRisk }.count)),
                ],
                health
            )
        case .labor:
            let tva = laborRollup(rows, key: "target_vs_actual_pct")
            return (
                [
                    HeartbeatFormat.pct(tva),
                    HeartbeatFormat.pct(laborRollup(rows, key: "act_cost_pct")),
                    HeartbeatFormat.pct(laborRollup(rows, key: "cost_trgt_pct")),
                    HeartbeatFormat.pct(laborRollup(rows, key: "schedule_efficiency_pct")),
                    HeartbeatFormat.pct(laborRollup(rows, key: "uplh_impact_pct")),
                    HeartbeatFormat.pct(laborRollup(rows, key: "wage_impact_pct")),
                    HeartbeatFormat.pct(laborRollup(rows, key: "aiv_impact_pct")),
                ],
                laborHealth(tva)
            )
        case .pickerScorecard:
            let status = pickerStatusCounts(rows)
            return (
                [
                    HeartbeatFormat.num(Double(status.shoppers)),
                    HeartbeatFormat.num(Double(status.healthy)),
                    HeartbeatFormat.num(Double(status.watch)),
                    HeartbeatFormat.num(Double(status.risk)),
                ],
                health
            )
        case .sales:
            let sales = rows.reduce(0) { $0 + salesHeadlineDollars($1) }
            let orders = rows.reduce(0) { $0 + salesOrders($1) }
            let yoy = salesRollupYoY(
                current: rows.map { salesHeadlineDollars($0) },
                yoyPct: rows.map { $0.number("sales_yoy_pct") }
            )
            return (
                [
                    HeartbeatFormat.money(sales),
                    HeartbeatFormat.pct(yoy),
                    HeartbeatFormat.num(orders, digits: 0),
                ],
                salesHealth(planPct: nil, yoy: yoy)
            )
        default:
            return ([scopeHeadline(section, rows: rows)], health)
        }
    }

    /// Phone Sales card. Same eight tiles as `OverviewSalesPhoneCard`.
    static let salesPhoneTileLabels = ["Sales $", "YoY", "Orders", "Ord YoY", "AOS", "AIV", "Items/Txn", "Items"]

    static func salesPhoneTiles(_ pack: SalesPack) -> CompanyCardTiles {
        CompanyCardTiles(labels: salesPhoneTileLabels, values: salesPhoneTileValues(pack))
    }

    /// No Sales sheet and no Total row. Dashes, not a summed $0.
    static func salesPhoneTiles(company: MetricRow?, stores: [MetricRow]) -> CompanyCardTiles {
        let hasCompany = company.map { salesHeadlineDollars($0) > 0 } ?? false
        if !hasCompany && stores.isEmpty {
            return CompanyCardTiles(
                labels: salesPhoneTileLabels,
                values: Array(repeating: "—", count: salesPhoneTileLabels.count)
            )
        }
        return salesPhoneTiles(SalesPack(company: company, stores: stores))
    }

    static func salesPhoneTileValues(_ pack: SalesPack) -> [String] {
        [
            HeartbeatFormat.money(pack.sales),
            HeartbeatFormat.pct(pack.yoy),
            HeartbeatFormat.num(pack.orders, digits: 0),
            HeartbeatFormat.pct(pack.ordersYoy),
            HeartbeatFormat.money(pack.aos),
            HeartbeatFormat.num(pack.aiv, digits: 2),
            HeartbeatFormat.num(pack.ipt, digits: 1),
            HeartbeatFormat.num(pack.items, digits: 0),
        ]
    }

    /// Company Sales uses the workbook Total row. Ratios fill from dollars, orders, and items when the Total row omits them.
    static func salesPackFromWorkbookTotal(_ row: MetricRow) -> SalesPack {
        let base = SalesPack(row)
        return SalesPack(
            sales: base.sales,
            yoy: base.yoy,
            orders: base.orders,
            ordersYoy: base.ordersYoy,
            aos: base.aos ?? ratio(base.sales, base.orders),
            aiv: base.aiv ?? ratio(base.sales, base.items),
            items: base.items,
            ipt: base.ipt ?? ratio(base.items, base.orders),
            hd: base.hd,
            dug: base.dug,
            health: base.health
        )
    }

    private static func ratio(_ numerator: Double?, _ denominator: Double?) -> Double? {
        guard let numerator, let denominator, denominator > 0 else { return nil }
        return numerator / denominator
    }

    static func companyTileIsBlank(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "—" || trimmed == "-" || trimmed == "–"
    }

    static func companyTilesHaveWorkbookValue(_ tiles: CompanyCardTiles) -> Bool {
        !tiles.values.isEmpty && tiles.values.contains { !companyTileIsBlank($0) }
    }

    /// A cooked card still needs a cell when any value is blank or a column is missing.
    static func companyTilesNeedFill(_ tiles: CompanyCardTiles) -> Bool {
        if tiles.labels.isEmpty || tiles.values.count < tiles.labels.count { return true }
        return tiles.values.contains(where: companyTileIsBlank)
    }

    /// A cooked cell that already has a number stays. A blank cell takes the pack value when the pack has one.
    static func filledCompanyTiles(cooked: CompanyCardTiles?, pack: CompanyCardTiles) -> CompanyCardTiles {
        guard let cooked, !cooked.labels.isEmpty else { return pack }
        var cookedValue: [String: String] = [:]
        for (index, label) in cooked.labels.enumerated() where index < cooked.values.count {
            cookedValue[label] = cooked.values[index]
        }
        var packValue: [String: String] = [:]
        for (index, label) in pack.labels.enumerated() where index < pack.values.count {
            packValue[label] = pack.values[index]
        }
        let labels = pack.labels.count >= cooked.labels.count ? pack.labels : cooked.labels
        let values = labels.map { label -> String in
            if let kept = cookedValue[label], !companyTileIsBlank(kept) { return kept }
            if let filled = packValue[label], !companyTileIsBlank(filled) { return filled }
            return cookedValue[label] ?? packValue[label] ?? "—"
        }
        return CompanyCardTiles(labels: labels, values: values)
    }

    /// One company card, formatted the same way the phone paints it.
    /// Sales is the workbook Total row (`sales_grain=company`), never a sum of stores.
    static func companyCardTiles(
        section: MetricSection,
        rows: [MetricRow],
        pphRows: [MetricRow] = []
    ) -> CompanyCardTiles? {
        let tiles: CompanyCardTiles
        if section == .prepNotReady {
            let coverage = prepCoverage(rows)
            if coverage.thin {
                return CompanyCardTiles(
                    labels: ["Stores", "PNR %", "Goal", "Watch"],
                    values: [coverage.coverageTile, "—", "—", "—"]
                )
            }
        }
        if section == .sales {
            guard let total = salesCompanyRow(rows), salesHeadlineDollars(total) > 0 else { return nil }
            tiles = CompanyCardTiles(
                labels: salesPhoneTileLabels,
                values: salesPhoneTileValues(salesPackFromWorkbookTotal(total))
            )
        } else {
            guard !rows.isEmpty else { return nil }
            let scored = dashboardTableValues(section, rows: rows, pphRows: pphRows)
            tiles = CompanyCardTiles(
                labels: dashboardTableHeaders(section),
                values: scored.values
            )
        }
        return companyTilesHaveWorkbookValue(tiles) ? tiles : nil
    }

    /// Sales Total, Loss market, and Labor market rows. Other sections are tile strings only.
    static func companyRollupRow(section: MetricSection, rows: [MetricRow]) -> MetricRow? {
        switch section {
        case .sales:
            guard let total = salesCompanyRow(rows), salesHeadlineDollars(total) > 0 else { return nil }
            return total
        case .lostRevenue:
            return lostRevenueMarketRow(in: rows)
        case .labor:
            return rows.first { $0.textPayload["labor_grain"] == "market" }
        default:
            return nil
        }
    }

    static func companyScopeTiles(
        latest: [MetricSection: [MetricRow]],
        laborMarket: MetricRow? = nil
    ) -> [String: CompanyCardTiles] {
        let source = latestIncludingLaborMarket(latest, laborMarket: laborMarket)
        let pph = source[.pph] ?? []
        var out: [String: CompanyCardTiles] = [:]
        for section in MetricSection.dashboardCards {
            guard let tiles = companyCardTiles(section: section, rows: source[section] ?? [], pphRows: pph) else { continue }
            out[section.rawValue] = tiles
        }
        return out
    }

    /// The Labor market row is the same row RESULT uses. Store rows stay in `latest`; this only adds that one seat total.
    static func latestIncludingLaborMarket(
        _ latest: [MetricSection: [MetricRow]],
        laborMarket: MetricRow?
    ) -> [MetricSection: [MetricRow]] {
        guard let laborMarket, laborMarket.section == .labor, laborMarket.textPayload["labor_grain"] == "market" else {
            return latest
        }
        var source = latest
        var labor = source[.labor] ?? []
        if !labor.contains(where: { $0.textPayload["labor_grain"] == "market" }) {
            labor.append(laborMarket)
        }
        source[.labor] = labor
        return source
    }

    static func companyScopeRollups(
        latest: [MetricSection: [MetricRow]],
        laborMarket: MetricRow? = nil
    ) -> [String: MetricRow] {
        let source = latestIncludingLaborMarket(latest, laborMarket: laborMarket)
        var out: [String: MetricRow] = [:]
        for section in [MetricSection.sales, .lostRevenue, .labor] {
            guard let row = companyRollupRow(section: section, rows: source[section] ?? []) else { continue }
            out[section.rawValue] = row
        }
        return out
    }

    /// Pack chrome may still say "J3CHICAGO" / "308 - J3 CHICAGO" while buckets are keyed "J3".
    static func grainAliasKeys(_ raw: String, grain: DashScopeGrain) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var keys: [String] = [trimmed]
        let display = displayGrainLabel(trimmed)
        if display != trimmed { keys.append(display) }
        switch grain {
        case .district:
            let district = RollupMarketFill.districtKey(trimmed)
            if district != "Unassigned" { keys.append(district) }
        case .division:
            let division = RollupMarketFill.divisionKey(trimmed)
            if division != "Unassigned" { keys.append(division) }
        case .region:
            if let region = MarketRegion.named(trimmed) ?? MarketRegion.containing(trimmed) {
                keys.append(region.rawValue)
            }
        case .store:
            let number = canonicalStore(trimmed)
            if !number.isEmpty { keys.append(number) }
        }
        let compact = compactKey(display == trimmed ? trimmed : display)
        if !compact.isEmpty { keys.append(compact) }
        var seen: Set<String> = []
        return keys.filter { seen.insert($0).inserted }
    }

    /// A roster count with dash values is not a live breakdown. The first column
    /// is the section metric. A lone Goal % behind dashes is not live either.
    static func grainRowHasSectionValue(_ row: DashboardGrainTableRow) -> Bool {
        guard let first = row.values.first else { return false }
        let text = first.trimmingCharacters(in: .whitespacesAndNewlines)
        return !text.isEmpty && text != "—" && text != "-" && text != "–"
    }

    static func grainRowsAreLive(_ rows: [DashboardGrainTableRow]) -> Bool {
        rows.contains(where: grainRowHasSectionValue)
    }

    /// Rows whose labels already match this grain and that carry a section value.
    /// A mixed region-and-division book keeps only the matching labels.
    static func fittingGrainRows(
        _ rows: [DashboardGrainTableRow],
        grain: DashScopeGrain
    ) -> [DashboardGrainTableRow] {
        guard grain == .region || grain == .division else { return [] }
        let live = rows.filter { !RollupMarketFill.hidesUnassignedMarket($0.label) }
        let fitting = live.filter { grainLabelsMatch([$0.label], grain: grain) }
        guard fitting.contains(where: grainRowHasSectionValue) else { return [] }
        return fitting
    }

    /// Old packs store one grain in chrome (regions, with division children on the packs).
    /// Section pages use that when the company seat has not decoded store facts.
    static func chromeSectionRows(
        section: MetricSection,
        grain: DashScopeGrain,
        tables: [DashboardGrainTableRow],
        packs: [DashScopePack]
    ) -> [DashboardGrainTableRow] {
        let live = tables.filter { !RollupMarketFill.hidesUnassignedMarket($0.label) }
        let fitting = fittingGrainRows(live, grain: grain)
        if grainRowsAreLive(fitting) { return fitting }
        if grain == .division {
            let rows = rowsFromScopeLines(packs.flatMap(\.children), section: section)
            if grainRowsAreLive(rows) { return rows }
        }
        if grain == .region {
            let fromPacks = dashboardGrainRowsFromPacks(packs, section: section)
            if grainRowsAreLive(fromPacks) { return fromPacks }
        }
        // The chrome rows already have this section's numbers. A label that is
        // not the grain title must not drop the table. Store seats stay out.
        if (grain == .region || grain == .division), grainLabelsMatch(live, grain: grain) {
            return live
        }
        return []
    }

    static func grainLabelsMatch(_ labels: [String], grain: DashScopeGrain) -> Bool {
        let names = labels.map { displayGrainLabel($0) }.filter { !$0.isEmpty }
        guard !names.isEmpty else { return false }
        // "California" and "California Region" are the same grain. A market name is not.
        func isRegion(_ name: String) -> Bool { MarketRegion.named(name) != nil }
        switch grain {
        case .region:
            return names.contains(where: isRegion)
        case .division:
            return names.allSatisfy { !isRegion($0) }
        default:
            return true
        }
    }

    /// Chrome that already has this section's numbers stays. A label that is
    /// not the exact grain title does not drop those rows. A store seat
    /// (`304` or `304 | NorCal`) is not a company region or division table.
    /// "East Region" with a dash is not a match: the first value has to be a
    /// real section number before the row can replace chrome.
    static func grainLabelsMatch(_ rows: [DashboardGrainTableRow], grain: DashScopeGrain) -> Bool {
        let valued = rows.filter(grainRowHasSectionValue)
        guard !valued.isEmpty else { return false }
        if valued.contains(where: isStoreSeatLabel) { return false }
        if grain == .region || grain == .division { return true }
        return grainLabelsMatch(rows.map(\.label), grain: grain)
    }

    private static func isStoreSeatLabel(_ row: DashboardGrainTableRow) -> Bool {
        if row.label.contains("|") { return true }
        let compact = compactKey(displayGrainLabel(row.label))
        return !compact.isEmpty && compact.allSatisfy(\.isNumber)
    }

    /// Division children on an old pack are one headline, not a full tile row.
    static func rowsFromScopeLines(
        _ lines: [DashScopeLine],
        section: MetricSection
    ) -> [DashboardGrainTableRow] {
        let width = dashboardTableHeaders(section).count
        return lines.compactMap { line in
            guard !line.label.isEmpty, !RollupMarketFill.hidesUnassignedMarket(line.label) else { return nil }
            let live = line.count > 0 || (!line.value.isEmpty && line.value != "—")
            guard live else { return nil }
            var values = Array(repeating: "—", count: max(width, 1))
            values[0] = line.value.isEmpty ? "—" : line.value
            return DashboardGrainTableRow(
                label: displayGrainLabel(line.label),
                storeCount: line.count,
                values: values,
                health: line.health
            )
        }
    }

    /// Company card columns from a cooked summary when `companyTiles` was never written.
    static func legacyCompanyTiles(
        summary: SectionSummary,
        pickerShoppers: Int = 0,
        pickerOpportunity: Int = 0,
        pickerStrong: Int = 0
    ) -> CompanyCardTiles? {
        switch summary.section {
        case .missingItems, .preSubOOS:
            guard summary.storeCount > 0 || summary.headline != nil else { return nil }
            let healthy = namedHealthyCount(summary.secondary)
                ?? max(0, summary.storeCount - summary.watchCount - summary.riskCount)
            return CompanyCardTiles(
                labels: dashboardTableHeaders(summary.section),
                values: [
                    HeartbeatFormat.pct(summary.headline),
                    HeartbeatFormat.num(Double(healthy)),
                    HeartbeatFormat.num(Double(summary.watchCount)),
                    HeartbeatFormat.num(Double(summary.riskCount)),
                ]
            )
        case .pickerScorecard:
            let shoppers = max(Int(summary.headline ?? 0), pickerShoppers)
            guard shoppers > 0 else { return nil }
            let risk = max(summary.riskCount, pickerOpportunity)
            let healthy = pickerStrong
            let known = risk > 0 || healthy > 0
            let watch = known ? max(0, shoppers - healthy - risk) : 0
            return CompanyCardTiles(
                labels: dashboardTableHeaders(.pickerScorecard),
                values: [
                    HeartbeatFormat.num(Double(shoppers)),
                    known ? HeartbeatFormat.num(Double(healthy)) : "—",
                    known ? HeartbeatFormat.num(Double(watch)) : "—",
                    known ? HeartbeatFormat.num(Double(risk)) : "—",
                ]
            )
        case .prepNotReady:
            guard summary.health != .none, summary.headline != nil, !isPrepThinNote(summary.secondary) else { return nil }
            return CompanyCardTiles(
                labels: dashboardTableHeaders(.prepNotReady),
                values: [HeartbeatFormat.pct(summary.headline), "—", "—"]
            )
        default:
            return nil
        }
    }

    /// The tile title stays Goal %. The sheet already stores the FY loss rate.
    static func phoneTileLabel(_ label: String, value: String) -> String {
        _ = value
        return label
    }

    static let lostRevenueNotInUploadNote = "not in this upload"

    static func lossGrainHealth(_ row: DashboardGrainTableRow) -> Health {
        if row.storeCount == 0 { return .none }
        let headers = dashboardTableHeaders(.lostRevenue)
        let pct = headers.firstIndex(of: "Lost %").flatMap { index in
            index < row.values.count ? parsedTileNumber(row.values[index]) : nil
        }
        let goal = headers.firstIndex(of: "Goal %").flatMap { index in
            index < row.values.count ? parsedTileNumber(row.values[index]) : nil
        }
        if pct != nil {
            return lostRevenueStatus(pct: pct, goal: goal)
        }
        if row.health != .none { return row.health }
        return .none
    }

    /// "961 healthy · 537 watch · …" is the scored band. Roster-pinned storeCount is not.
    static func namedHealthyCount(_ secondary: String) -> Int? {
        let trimmed = secondary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = trimmed.range(
            of: #"^(\d{1,3}(?:,\d{3})*|\d+)\s+healthy\b"#,
            options: .regularExpression
        ) else { return nil }
        let token = trimmed[range].split(separator: " ").first.map(String.init) ?? ""
        return Int(token.replacingOccurrences(of: ",", with: ""))
    }

    /// Region picker cards count shoppers. The company card keeps its store count.
    static func pickerGrainSubtitle(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return "\(groupedCount(count)) \(count == 1 ? "shopper" : "shoppers")"
    }

    /// Expand has dollars/other columns but Goal % is still a dash.
    static func grainTableNeedsGoalFill(_ rows: [DashboardGrainTableRow]) -> Bool {
        guard let index = dashboardTableHeaders(.lostRevenue).firstIndex(of: "Goal %") else { return false }
        return rows.contains { row in
            guard index < row.values.count else { return true }
            let goal = row.values[index]
            let hasBook = row.storeCount > 0 || row.values.contains { $0 != "—" && !$0.isEmpty && $0 != goal }
            return hasBook && (goal == "—" || goal.isEmpty)
        }
    }

    static func fillingLostRevenueGoal(_ rows: [DashboardGrainTableRow], goal: Double) -> [DashboardGrainTableRow] {
        guard let index = dashboardTableHeaders(.lostRevenue).firstIndex(of: "Goal %") else { return rows }
        let text = HeartbeatFormat.pct(goal)
        return rows.map { row in
            guard index < row.values.count else { return row }
            let current = row.values[index]
            guard row.storeCount > 0 else { return row }
            guard current == "—" || current.isEmpty else { return row }
            var values = row.values
            values[index] = text
            return DashboardGrainTableRow(
                label: row.label,
                storeCount: row.storeCount,
                values: values,
                health: row.health
            )
        }
    }

    /// Share / pack chrome often keeps the first metric and drops YoY, Orders, PPH, …
    static func grainTableNeedsColumnFill(_ rows: [DashboardGrainTableRow], section: MetricSection) -> Bool {
        let count = dashboardTableHeaders(section).count
        guard count > 1 else { return false }
        return rows.contains { row in
            row.values.count < count
                || row.values.dropFirst().allSatisfy { $0 == "—" || $0.isEmpty }
        }
    }

    /// Keep grain labels (1490 | NorCal) and fill missing metric cells from the same filtered rows expand uses.
    static func fillingGrainTable(
        _ rows: [DashboardGrainTableRow],
        section: MetricSection,
        metricRows: [MetricRow],
        grain: DashScopeGrain,
        goalFallback: Double? = nil,
        fillDashesOnly: Bool = false
    ) -> [DashboardGrainTableRow] {
        let headers = dashboardTableHeaders(section)
        guard !rows.isEmpty, headers.count > 1, !metricRows.isEmpty else {
            return paddedGrainTable(rows, headerCount: headers.count)
        }
        let rebuilt = dashboardGrainTableFilled(
            section: section,
            rows: metricRows,
            grain: grain,
            order: rows.map(\.label),
            goalFallback: goalFallback
        )
        var aliasToRow: [String: DashboardGrainTableRow] = [:]
        aliasToRow.reserveCapacity(rebuilt.count * 3)
        for row in rebuilt {
            for alias in grainAliasKeys(row.label, grain: grain) where aliasToRow[alias] == nil {
                aliasToRow[alias] = row
            }
        }
        func match(_ label: String) -> DashboardGrainTableRow? {
            for alias in grainAliasKeys(label, grain: grain) {
                if let hit = aliasToRow[alias] { return hit }
            }
            return nil
        }
        return rows.map { row in
            let incoming = match(row.label)
            if section == .lostRevenue, (incoming?.storeCount ?? 0) == 0 {
                return DashboardGrainTableRow(
                    label: row.label,
                    storeCount: 0,
                    values: Array(repeating: "—", count: headers.count),
                    health: .none
                )
            }
            return DashboardGrainTableRow(
                label: row.label,
                storeCount: max(row.storeCount, incoming?.storeCount ?? 0),
                values: mergedGrainValues(
                    current: row.values,
                    incoming: incoming?.values ?? [],
                    headerCount: headers.count,
                    fillDashesOnly: fillDashesOnly
                ),
                health: row.health == .none ? (incoming?.health ?? row.health) : row.health
            )
        }
    }

    static func paddedGrainTable(
        _ rows: [DashboardGrainTableRow],
        headerCount: Int
    ) -> [DashboardGrainTableRow] {
        guard headerCount > 0 else { return rows }
        return rows.map { row in
            guard row.values.count != headerCount else { return row }
            return DashboardGrainTableRow(
                label: row.label,
                storeCount: row.storeCount,
                values: mergedGrainValues(current: row.values, incoming: [], headerCount: headerCount),
                health: row.health
            )
        }
    }

    static func mergedGrainValues(
        current: [String],
        incoming: [String],
        headerCount: Int,
        fillDashesOnly: Bool = false
    ) -> [String] {
        var out: [String] = []
        out.reserveCapacity(headerCount)
        for index in 0..<headerCount {
            let have = index < current.count ? current[index] : ""
            let next = index < incoming.count ? incoming[index] : ""
            let haveValue = have != "—" && !have.isEmpty
            if fillDashesOnly, haveValue {
                out.append(have)
                continue
            }
            if next != "—" && !next.isEmpty {
                out.append(next)
            } else if have != "—" && !have.isEmpty {
                out.append(have)
            } else if !next.isEmpty {
                out.append(next)
            } else if !have.isEmpty {
                out.append(have)
            } else {
                out.append("—")
            }
        }
        return out
    }

    static func dashboardGrainTable(
        section: MetricSection,
        rows: [MetricRow],
        grain: DashScopeGrain,
        order: [String],
        goalFallback: Double? = nil
    ) -> [DashboardGrainTableRow] {
        let source = section == .pickerScorecard ? latestPerShopper(rows) : rows
        var buckets: [String: [MetricRow]] = [:]
        for row in source {
            if row.textPayload["lost_grain"] == "market" { continue }
            if row.textPayload["labor_grain"] == "market" { continue }
            if row.textPayload["sales_grain"] == "company" { continue }
            guard let key = dashboardScopeKey(row, grain: grain) else { continue }
            buckets[key, default: []].append(row)
        }
        var aliasToKey: [String: String] = [:]
        aliasToKey.reserveCapacity(buckets.count * 3)
        for key in buckets.keys {
            for alias in grainAliasKeys(key, grain: grain) where aliasToKey[alias] == nil {
                aliasToKey[alias] = key
            }
        }
        func group(for label: String) -> (key: String?, rows: [MetricRow]) {
            for alias in grainAliasKeys(label, grain: grain) {
                if let key = aliasToKey[alias], let rows = buckets[key] {
                    return (key, rows)
                }
                if let rows = buckets[alias] {
                    return (alias, rows)
                }
            }
            return (nil, [])
        }
        func makeRow(label: String, group: [MetricRow]) -> DashboardGrainTableRow {
            let scoped = lossGrainRows(group, section: section, universe: rows)
            let built = dashboardTableValues(section, rows: scoped, goalFallback: goalFallback)
            let counted = scoped.filter {
                $0.textPayload["lost_grain"] != "market" && !canonicalStore($0.storeNumber).isEmpty
            }
            return DashboardGrainTableRow(
                label: displayGrainLabel(label),
                storeCount: section == .lostRevenue ? counted.count : group.count,
                values: built.values,
                health: built.health
            )
        }
        let labels: [String]
        if !order.isEmpty {
            labels = order
        } else if grain == .region {
            labels = MarketRegion.allCases.map(\.rawValue)
        } else {
            labels = buckets.keys.sorted()
        }
        var used: Set<String> = []
        var table: [DashboardGrainTableRow] = []
        table.reserveCapacity(max(labels.count, buckets.count))
        for label in labels {
            let hit = group(for: label)
            if let key = hit.key {
                if used.contains(key) { continue }
                used.insert(key)
            }
            // Keep official region slots so "Regions 4" always paints East/South/California/West.
            // District order aliases (J3CHICAGO and "308 - J3 CHICAGO") collapse to one J3 row.
            if hit.rows.isEmpty, !buckets.isEmpty, grain != .region, grain != .store,
               !(section == .lostRevenue && grain == .division) { continue }
            table.append(makeRow(label: label, group: hit.rows))
        }
        if !order.isEmpty {
            for key in buckets.keys.sorted() where !used.contains(key) {
                let group = buckets[key] ?? []
                guard !group.isEmpty else { continue }
                table.append(makeRow(label: key, group: group))
            }
        }
        return table
    }

    /// Prefer live warehouse buckets. If pack order keys missed, rebuild without order.
    static func dashboardGrainTableFilled(
        section: MetricSection,
        rows: [MetricRow],
        grain: DashScopeGrain,
        order: [String],
        goalFallback: Double? = nil
    ) -> [DashboardGrainTableRow] {
        let table = dashboardGrainTable(
            section: section,
            rows: rows,
            grain: grain,
            order: order,
            goalFallback: goalFallback
        )
        if grain == .region || grain == .division {
            let cleaned = table.filter { !RollupMarketFill.hidesUnassignedMarket($0.label) }
            if grain == .region { return cleaned }
            if grainRowsAreLive(cleaned) { return cleaned }
            return cleaned
        }
        if grainRowsAreLive(table) { return table }
        guard !order.isEmpty else { return table }
        let fallback = dashboardGrainTable(
            section: section,
            rows: rows,
            grain: grain,
            order: [],
            goalFallback: goalFallback
        )
        return grainRowsAreLive(fallback) ? fallback : table
    }

    /// Banner packs already have the headline. Use them when the warehouse slice is not ready.
    static func dashboardGrainRowsFromPacks(
        _ packs: [DashScopePack],
        section: MetricSection,
        goalFallback: Double? = nil
    ) -> [DashboardGrainTableRow] {
        let headers = dashboardTableHeaders(section)
        return packs.compactMap { pack -> DashboardGrainTableRow? in
            let line = pack.line
            guard !line.label.isEmpty, line.label != "Unassigned" else { return nil }
            let live = line.count > 0 || (!line.value.isEmpty && line.value != "—")
            guard live || !pack.flags.isEmpty || goalFallback != nil else { return nil }
            var values: [String] = []
            values.reserveCapacity(max(headers.count, 1))
            for (index, header) in headers.enumerated() {
                if header == "Goal %", let goal = goalFallback {
                    values.append(HeartbeatFormat.pct(goal))
                } else if let flag = pack.flags.first(where: { flagName($0.name, matches: header) }) {
                    if !flag.value.isEmpty {
                        values.append(flag.value)
                    } else if section == .pickerScorecard
                        || header == "Healthy" || header == "Watch" || header == "At Risk" {
                        values.append(HeartbeatFormat.num(Double(flag.stores)))
                    } else {
                        values.append("—")
                    }
                } else if index == 0 {
                    values.append(line.value.isEmpty ? "—" : line.value)
                } else {
                    values.append("—")
                }
            }
            if values.isEmpty { values = [line.value.isEmpty ? "—" : line.value] }
            return DashboardGrainTableRow(
                label: displayGrainLabel(line.label),
                storeCount: line.count,
                values: values,
                health: line.health
            )
        }
    }

    private static func flagName(_ name: String, matches header: String) -> Bool {
        let a = compactKey(name)
        let b = compactKey(header)
        return !a.isEmpty && !b.isEmpty && (a == b || a.contains(b) || b.contains(a))
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
            let card = scopeCard(section: section, rows: group)
            let line = DashScopeLine(
                label: label,
                value: card.value,
                health: card.health,
                count: card.count
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

    /// One grain card. Thin Prep stays ungraded: the value is the coverage note.
    static func scopeCard(section: MetricSection, rows: [MetricRow]) -> (value: String, health: Health, count: Int) {
        if section == .prepNotReady {
            let coverage = prepCoverage(rows)
            if coverage.thin {
                return (coverage.note, .none, coverage.inScope)
            }
        }
        return (scopeHeadline(section, rows: rows), worstHealth(section, rows: rows), rows.count)
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
        case .sales:
            return HeartbeatFormat.money(rows.compactMap { $0.number("sales_dollars") }.reduce(0, +))
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
            return HeartbeatFormat.num(weekPurePPH(rows), digits: 1)
        case .labor:
            return HeartbeatFormat.pct(average(rows.compactMap { $0.number("target_vs_actual_pct") }))
        case .pickerScorecard:
            return "\(rows.filter { isRealPicker($0) }.count) shoppers"
        case .aisleMapper:
            return "\(rows.count) stores"
        case .preSubOOSItem:
            return "\(rows.count) items"
        case .storeRoster:
            return "\(rows.count) stores"
        }
    }

    static func dashboardActionFlags(
        section: MetricSection,
        rows: [MetricRow],
        pickers: [MetricRow] = [],
        pathPickers: [MetricRow] = [],
        items: [MetricRow] = [],
        pphRows: [MetricRow] = [],
        includeAll: Bool = false
    ) -> [FiveStarFlag] {
        if section == .sales { return salesActionFlags(rows) }
        if section == .fiveStar { return fiveStarActionFlags(rows, includeAll: true) }
        if section == .lostRevenue { return lostRevenueMetricFlags(rows, includeAll: true) }
        if section == .labor { return laborActionFlags(rows) }
        if section == .scheduleQuality { return scheduleActionFlags(rows, includeAll: true) }
        if section == .pickPath { return pickPathMetricFlags(rows) }
        if section == .dynacap {
            return dynacapActionFlags(
                overlayStorePPH(rows, from: pphRows, pickers: pickers),
                bookPPH: pphRows.isEmpty ? pickers : pphRows
            )
        }
        if section == .pph {
            return pphDashboardFlags(rows, pickers: pickers)
        }
        if section == .preSubOOS { return preSubActionFlags(rows, items: items) }
        if section == .pickerScorecard {
            let status = pickerStatusCounts(rows)
            return bandFlags(healthy: status.healthy, watch: status.watch, risk: status.risk, unit: "shoppers")
        }
        let stores = rows.filter { !isIgnoredStore($0.storeNumber) && !$0.storeNumber.isEmpty }
        let healthy = stores.filter { health(for: section, row: $0) == .good }.count
        let watch = stores.filter { health(for: section, row: $0) == .watch }.count
        let risk = stores.filter { health(for: section, row: $0) == .risk }.count
        return bandFlags(healthy: healthy, watch: watch, risk: risk, unit: "stores")
    }

    static func bandFlags(healthy: Int, watch: Int, risk: Int, unit: String = "stores") -> [FiveStarFlag] {
        [
            FiveStarFlag(name: "Healthy", value: "", health: .good, stores: healthy, unit: unit),
            FiveStarFlag(name: "Watch", value: "", health: watch == 0 ? .good : .watch, stores: watch, unit: unit),
            FiveStarFlag(name: "At Risk", value: "", health: risk == 0 ? .good : .risk, stores: risk, unit: unit),
        ]
    }

    static func latestPerStore(_ rows: [MetricRow]) -> [MetricRow] {
        var map: [String: MetricRow] = [:]
        for row in rows {
            let number = canonicalStore(row.storeNumber)
            // Loss keeps ignored-store dollars in the workbook sum. Other sections hide 210 / 239.
            if isIgnoredStore(number), row.section != .sales, row.section != .lostRevenue { continue }
            if row.textPayload["sales_grain"] == "day" { continue }
            if row.textPayload["sales_grain"] == "company" {
                if let existing = map["__sales_company__"] {
                    if (row.recordedOn ?? "") >= (existing.recordedOn ?? "") {
                        map["__sales_company__"] = row
                    }
                } else {
                    map["__sales_company__"] = row
                }
                continue
            }
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
        return Array(map.values)
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
            divisionValues = selectedRegions.flatMap { name -> [String] in
                let region = MarketRegion(rawValue: name) ?? MarketRegion.named(name)
                return region?.divisions ?? []
            }
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
            let value = field(identity)
            let matched = trimmed.contains { want in
                HeartbeatMath.districtMatchKey(value) == HeartbeatMath.districtMatchKey(want)
                    && !HeartbeatMath.districtMatchKey(want).isEmpty
                    || MarketRegion.matchesDivision(value, want)
                    || HeartbeatMath.matches(value, want)
            }
            guard matched else { return nil }
            let store = canonicalStore(row.storeNumber)
            return store.isEmpty ? nil : store
        })
        if hits.isEmpty { return relax ? nil : [] }
        return hits
    }

    private static func belongs(_ storeNumber: String, to stores: Set<String>, identity: String, value: String) -> Bool {
        belongs(storeNumber, to: stores, identity: identity, values: [value])
    }

    private static func belongs(_ storeNumber: String, to stores: Set<String>, identity: String, values: [String]) -> Bool {
        if !storeNumber.isEmpty {
            let store = canonicalStore(storeNumber)
            if stores.contains(store) { return true }
            return storeInAllowed(store, allowed: stores)
        }
        return values.contains { MarketRegion.matchesDivision(identity, $0) }
    }

    static func usableFilter(_ value: String, in options: [String], relax: Bool) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if options.contains(where: { matches($0, trimmed) }) { return trimmed }
        return relax ? nil : trimmed
    }

    static func matches(_ lhs: String, _ rhs: String) -> Bool {
        if districtMatchKey(lhs) == districtMatchKey(rhs), !districtMatchKey(lhs).isEmpty {
            return true
        }
        return normalize(lhs) == normalize(rhs)
    }

    static func districtMatchKey(_ raw: String) -> String {
        let canon = canonicalDistrict(raw)
        let compact = compactKey(canon)
        guard !compact.isEmpty else { return "" }
        if compact.allSatisfy(\.isNumber), let value = Int(compact) {
            return String(value)
        }
        return compact
    }

    /// Numbered codes (03, 3) match each other. Letter codes (D3, B3) match
    /// only themselves. Do not map 03→D3 or B3→3 — the roster has both.
    static func districtMatchKeys(_ raw: String) -> Set<String> {
        let canon = canonicalDistrict(raw)
        let compact = compactKey(canon)
        guard !compact.isEmpty else { return [] }
        var keys: Set<String> = [compact]
        let rawCompact = compactKey(raw)
        if !rawCompact.isEmpty { keys.insert(rawCompact) }
        let short = compactKey(shortDistrictName(raw.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)))
        if !short.isEmpty { keys.insert(short) }
        if compact.allSatisfy(\.isNumber), let value = Int(compact) {
            keys.insert(String(value))
            keys.insert(String(format: "%02d", value))
        }
        return keys
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
            value = value.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression).uppercased()
            return shortDistrictName(value)
        }
        return value
    }

    /// Filter-true short name: J3CHICAGO → J3, J1NORTHSHORE → J1, "308 - J3 CHICAGO" → J3.
    /// Leaves 03 / D3 / J3 alone.
    static func shortDistrictName(_ raw: String) -> String {
        let canon = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !canon.isEmpty else { return "" }
        if let match = canon.range(of: #"^[A-Z]{1,3}\d{1,2}"#, options: .regularExpression) {
            let prefix = String(canon[match])
            let rest = canon[match.upperBound...]
            if rest.contains(where: \.isLetter) { return prefix }
            return canon.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        }
        if let match = canon.range(of: #"[A-Z]{1,3}\d{1,2}(?=[\s\-]*[A-Z])"#, options: .regularExpression) {
            return String(canon[match])
        }
        return canon
    }

    /// Grain / filter label: J3CHICAGO and "308 - J3 CHICAGO" → J3. Leaves stores and markets alone.
    static func displayGrainLabel(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let short = shortDistrictName(trimmed)
        guard short.range(of: #"^[A-Z]{1,3}\d{1,2}$"#, options: .regularExpression) != nil else {
            return trimmed
        }
        let compact = compactKey(trimmed)
        let shortCompact = compactKey(short)
        if compact == shortCompact { return short }
        if compact.hasPrefix(shortCompact), compact.dropFirst(shortCompact.count).contains(where: \.isLetter) {
            return short
        }
        if compact.contains(shortCompact),
           trimmed.contains(where: { $0 == "-" || $0 == "·" || $0.isWhitespace }) {
            let rest = compact.replacingOccurrences(of: shortCompact, with: "")
            if rest.contains(where: \.isLetter) { return short }
        }
        return trimmed
    }

    /// Dashboard KPI chips must stay inside the card. Strip leading SKU codes and cap length.
    static func compactCalloutLabel(_ raw: String, limit: Int = 22) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = text.range(of: #"^\d{5,}\s*[-\u2013:]\s*"#, options: .regularExpression) {
            text.removeSubrange(range)
        }
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard text.count > limit else { return text }
        return String(text.prefix(limit - 1)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    /// Roster names that are really district titles should not appear on store chips.
    static func usableStoreName(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if displayGrainLabel(trimmed) != trimmed { return nil }
        return trimmed
    }

    static func storeDisplayLabel(
        _ row: MetricRow,
        identity: StoreIdentity? = nil
    ) -> String {
        storeDisplayLabel(
            storeNumber: row.storeNumber,
            district: row.district,
            division: row.division,
            identity: identity
        )
    }

    static func storeDisplayLabel(
        storeNumber: String,
        district: String,
        division: String,
        identity: StoreIdentity? = nil
    ) -> String {
        let number = canonicalStore(storeNumber)
        var dist = canonicalDistrict(district)
        if dist.isEmpty { dist = canonicalDistrict(identity?.district ?? "") }
        var market = MarketRegion.canonicalName(division)
        if market.isEmpty {
            market = division.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if market.isEmpty {
            let raw = identity?.division ?? ""
            market = MarketRegion.canonicalName(raw)
            if market.isEmpty { market = raw.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        var parts: [String] = []
        if !number.isEmpty { parts.append(number) }
        if !dist.isEmpty { parts.append(dist) }
        if !market.isEmpty, market.caseInsensitiveCompare(dist) != .orderedSame {
            parts.append(market)
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " | ")
    }

    static func canonicalOM(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.replacingOccurrences(of: "(?i)^(om|operations manager)\\s*[:\\-–]\\s*", with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return value
    }

    static func shopperInitials(_ raw: String) -> String {
        let tokens = raw.split { $0.isWhitespace || $0 == "/" }.filter { $0.contains(where: \.isLetter) }
        let letters = tokens.prefix(2).compactMap(\.first).map { String($0).uppercased() }
        if !letters.isEmpty { return letters.joined() }
        let fallback = raw.filter(\.isLetter).prefix(2).uppercased()
        return fallback.isEmpty ? "?" : String(fallback)
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
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("|") {
            trimmed = trimmed.split(separator: "|").first.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? trimmed
        }
        trimmed = trimmed.replacingOccurrences(of: "(?i)^store\\s*#?\\s*", with: "", options: .regularExpression)
        if let number = Int(trimmed) { return String(number) }
        let cleaned = trimmed.replacingOccurrences(of: ",", with: "")
        if let value = Double(cleaned), value > 0, value < 1_000_000, value == value.rounded() {
            return String(Int(value))
        }
        let leading = trimmed.prefix(while: { $0.isNumber || $0 == " " })
        let digits = String(leading).filter(\.isNumber)
        if let number = Int(digits), number > 0, digits.count <= 6 {
            return String(number)
        }
        return trimmed
    }

    static func storeAliases(_ raw: String) -> Set<String> {
        let number = canonicalStore(raw)
        guard !number.isEmpty else { return [] }
        var out: Set<String> = [number]
        if let value = Int(number) {
            out.insert(String(value))
            out.insert(String(format: "%04d", value))
            out.insert(String(format: "%05d", value))
        }
        return out
    }

    static func sameStore(_ lhs: String, _ rhs: String) -> Bool {
        !storeAliases(lhs).isDisjoint(with: storeAliases(rhs))
    }

    /// O(1). Canonical + zero-padded aliases. Does not allocate a Set or scan `allowed`.
    static func storeInAllowed(_ raw: String, allowed: Set<String>) -> Bool {
        let store = canonicalStore(raw)
        if store.isEmpty { return false }
        if allowed.contains(store) || allowed.contains(raw) { return true }
        if let value = Int(store) {
            if allowed.contains(String(format: "%04d", value)) { return true }
            if allowed.contains(String(format: "%05d", value)) { return true }
        }
        return false
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
                let fromRoster = row.section == .storeRoster || row.textPayload["roster"] == "1"
                if !name.isEmpty, current.division.isEmpty || fromRoster {
                    current.division = name
                }
            }
            if !row.district.isEmpty {
                let district = canonicalDistrict(row.district)
                let fromRoster = row.section == .storeRoster || row.textPayload["roster"] == "1"
                if !district.isEmpty, current.district.isEmpty || fromRoster {
                    current.district = district
                }
            }
            if !row.operationsOM.isEmpty {
                let om = canonicalOM(row.operationsOM)
                let fromRoster = row.section == .storeRoster || row.textPayload["roster"] == "1"
                if !om.isEmpty, current.om.isEmpty || fromRoster {
                    current.om = om
                }
            }
            if current.name == nil, let name = row.storeName, !name.isEmpty { current.name = name }
            map[number] = current
        }
        fillDivisionsFromDistrict(in: &map)
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

    static func fillDivisionsFromDistrict(in map: inout [String: StoreIdentity]) {
        var byDistrict: [String: String] = [:]
        for identity in map.values {
            let district = normalize(canonicalDistrict(identity.district))
            let division = MarketRegion.canonicalName(identity.division)
            if !district.isEmpty, !division.isEmpty {
                byDistrict[district] = division
            }
        }
        guard !byDistrict.isEmpty else { return }
        for (number, identity) in map where identity.division.isEmpty {
            let district = normalize(canonicalDistrict(identity.district))
            guard let division = byDistrict[district] else { continue }
            var next = identity
            next.division = division
            map[number] = next
        }
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

    static func pphNumber(_ row: MetricRow) -> Double? {
        row.number("pph") ?? row.number("pure_pph")
    }

    /// One store that actually scores this metric. Soft FAIL roster gold (2161)
    /// and Soft FAIL counting ignored / TOTAL / empty-fact rows. Hero, This Week,
    /// and Regions cards on a metric page must share this filter.
    static func hasMetricFact(_ section: MetricSection, _ row: MetricRow) -> Bool {
        switch section {
        case .pph:
            return pphNumber(row) != nil
        case .prepNotReady:
            return row.number("pnr_rate_pct", "pnr_hours", "prep_not_ready_pct") != nil
        case .fiveStar:
            return row.number("star_rating") != nil
        case .pickPath, .pickPathPicker:
            return row.number("compliance_pct") != nil
        case .dynacap:
            return row.number("dynacap_rate", "pieces_per_hour") != nil
        case .scheduleQuality:
            return row.number("schedule_efficiency_pct") != nil
        case .labor:
            return row.textPayload["labor_grain"] != "market"
                && row.number("target_vs_actual_pct") != nil
        case .lostRevenue:
            return row.textPayload["lost_grain"] != "market"
                && (row.number("lost_revenue") != nil
                    || row.number("lost_revenue_pct") != nil
                    || row.number("ecomm_sales") != nil)
        case .sales:
            return row.textPayload["sales_grain"] != "company"
                && row.textPayload["sales_grain"] != "day"
                && (salesHeadlineDollars(row) > 0 || salesOrders(row) > 0)
        case .missingItems, .preSubOOS:
            return row.number(MissingItemDept.totalKey) != nil
        case .pickerScorecard, .aisleMapper, .storeRoster, .preSubOOSItem:
            return !canonicalStore(row.storeNumber).isEmpty
        }
    }

    /// latestPerStore / latestPerShopper, drop ignored + TOTAL, keep scored facts.
    static func metricFactRows(_ section: MetricSection, rows: [MetricRow]) -> [MetricRow] {
        let scoped = rows.filter { row in
            let store = canonicalStore(row.storeNumber)
            if store.isEmpty { return false }
            if store.caseInsensitiveCompare("TOTAL") == .orderedSame { return false }
            if isIgnoredStore(store) { return false }
            if row.textPayload["sales_grain"] == "company" || row.textPayload["sales_grain"] == "day" {
                return false
            }
            if row.textPayload["lost_grain"] == "market" { return false }
            if row.textPayload["labor_grain"] == "market" { return false }
            return true
        }
        let collapsed = section == .pickerScorecard
            ? latestPerShopper(scoped)
            : latestPerStore(scoped)
        return collapsed.filter { hasMetricFact(section, $0) }
    }

    static func metricStoreCount(_ section: MetricSection, rows: [MetricRow]) -> Int {
        Set(
            metricFactRows(section, rows: rows)
                .map { canonicalStore($0.storeNumber) }
                .filter { !$0.isEmpty }
        ).count
    }

    /// Dynacap PPH chip is the PPH-book week Pure PPH for this seat.
    /// Soft FAIL substituting `dynacap_rate` / pieces per hour.
    static func dynacapSeatPurePPH(dynacapRows: [MetricRow], pphRows: [MetricRow]) -> Double? {
        if PulseLaunch.shouldFillDynacapPPHFromPPHSeat(), let pph = weekPurePPH(pphRows) {
            return pph
        }
        return weekPurePPH(dynacapRows)
    }

    /// Week Pure PPH (Total) for the stores in `rows`. Multiple DATE rows collapse
    /// with `latestPerStore` (same as the PPH sheet's Total column). Empty store
    /// rows are grain totals. Shopper rows only fill when the PPH book is empty.
    /// 456: WATCH vs AT RISK pills stay on existing pphGoal / pphRisk bands.
    static func weekPurePPH(_ rows: [MetricRow], pickers: [MetricRow] = []) -> Double? {
        let stores = latestPerStore(rows.filter { !isIgnoredStore($0.storeNumber) && !$0.storeNumber.isEmpty })
        if let avg = average(stores.compactMap(pphNumber)) { return avg }
        let grainTotals = rows.filter { canonicalStore($0.storeNumber).isEmpty }
        if let avg = average(grainTotals.compactMap(pphNumber)) { return avg }
        let lookup = storePPHLookup(pickers)
        if lookup.isEmpty { return nil }
        return average(Array(lookup.values))
    }

    /// One week Pure PPH (Total) row per store. Picker Total Pure PPH fills only
    /// when the PPH sheet did not score those stores.
    static func materializePPH(
        _ rows: [MetricRow],
        roster: [String: StoreIdentity],
        pickers: [MetricRow] = []
    ) -> [MetricRow] {
        let perStore = applyRoster(
            latestPerStore(rows.filter { !canonicalStore($0.storeNumber).isEmpty }),
            roster: roster
        ).filter { pphNumber($0) != nil }
        if !perStore.isEmpty { return perStore }
        let map = storePPHLookup(pickers)
        guard !map.isEmpty else { return [] }
        return map.keys.sorted().compactMap { store in
            guard let pph = map[store] else { return nil }
            let identity = roster[store]
            var text: [String: String] = [:]
            if let district = identity?.district, !district.isEmpty {
                text["district"] = district
            }
            return MetricRow(
                section: .pph,
                division: identity?.division ?? "",
                operationsOM: identity?.om ?? "",
                storeNumber: store,
                storeName: identity?.name,
                payload: ["pph": pph],
                textPayload: text
            )
        }
    }

    /// Dynacap sheets carry pieces/hr + utilization. Store PPH lives on the PPH (or picker) scorecard.
    static func storePPHLookup(_ rows: [MetricRow]) -> [String: Double] {
        var out: [String: Double] = [:]
        out.reserveCapacity(min(rows.count, 2_200))
        for row in latestPerStore(rows) {
            let store = canonicalStore(row.storeNumber)
            guard !store.isEmpty, let pph = pphNumber(row) else { continue }
            out[store] = pph
        }
        return out
    }

    static func overlayStorePPH(
        _ rows: [MetricRow],
        from pphRows: [MetricRow],
        pickers: [MetricRow] = []
    ) -> [MetricRow] {
        var map = storePPHLookup(pphRows)
        if map.count < 8 {
            for (store, pph) in storePPHLookup(pickers) where map[store] == nil {
                map[store] = pph
            }
        }
        guard !map.isEmpty else { return rows }
        var aliased: [String: Double] = map
        for (store, pph) in map {
            for alias in storeAliases(store) { aliased[alias] = aliased[alias] ?? pph }
        }
        return rows.map { row in
            if pphNumber(row) != nil { return row }
            let store = canonicalStore(row.storeNumber)
            var pph = aliased[store]
            if pph == nil {
                pph = storeAliases(store).compactMap { aliased[$0] }.first
            }
            guard let pph else { return row }
            var next = row
            next.payload["pph"] = pph
            return next
        }
    }

    static func overlayDynacapPPH(_ latest: [MetricSection: [MetricRow]]) -> [MetricSection: [MetricRow]] {
        guard let dyn = latest[.dynacap], !dyn.isEmpty else { return latest }
        let next = overlayStorePPH(dyn, from: latest[.pph] ?? [], pickers: latest[.pickerScorecard] ?? [])
        var out = latest
        out[.dynacap] = next
        return out
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
            var next = stampRoster(row, roster: roster)
            next.payload = remapSchedulePayload(next.payload)
            return next
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
            let extra = (mapDate, seqDate)
            byStore[key] = extra
            for alias in storeAliases(key) {
                if byStore[alias] == nil { byStore[alias] = extra }
            }
        }
        guard !byStore.isEmpty else { return rows }
        return rows.map { row in
            let store = canonicalStore(row.storeNumber)
            guard let extra = byStore[store] ?? storeAliases(store).compactMap({ byStore[$0] }).first else {
                return row
            }
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
        let rosterCanon = MarketRegion.canonicalName(known?.division ?? "")
        let incomingCanon = MarketRegion.canonicalName(row.division)
        let division: String
        if !rosterCanon.isEmpty {
            division = rosterCanon
        } else if !incomingCanon.isEmpty {
            division = incomingCanon
        } else {
            division = row.division
        }
        return StoreIdentity(
            division: division,
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
            guard row.number("pnr_rate_pct", "pnr_hours", "prep_not_ready_pct") != nil else { return .none }
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
        case .sales:
            return salesHealth(row)
        case .missingItems:
            return missingItemsHealth(row)
        case .preSubOOS:
            return missingItemsHealth(row)
        case .aisleMapper:
            return AisleMapperMath.health(AisleMapperMath.mapperISO(row))
        case .preSubOOSItem:
            return missingItemsHealth(pct: row.number("presub_pct"))
        case .storeRoster:
            return .none
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

    /// Stores on the Prep tab in this scope, and how many of them have a Prep Not Ready Hours % value.
    struct PrepCoverage: Equatable {
        var reported: Int
        var inScope: Int

        /// Some stores reported a number and more than half are still blank.
        /// A numeric 0 counts as reported. Zero reported stores is the no-rows
        /// card ("No Prep rows this week"), not this gate.
        var thin: Bool { reported > 0 && inScope > 0 && reported * 2 < inScope }

        var note: String {
            HeartbeatMath.prepThinNote(reported: reported, inScope: inScope)
        }

        var coverageTile: String {
            "\(HeartbeatMath.groupedCount(reported)) of \(HeartbeatMath.groupedCount(inScope))"
        }
    }

    static func groupedCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func prepThinNote(reported: Int, inScope: Int) -> String {
        "Only \(groupedCount(reported)) of \(groupedCount(inScope)) stores reported Prep Not Ready this upload."
    }

    static func isPrepThinNote(_ text: String) -> Bool {
        text.hasPrefix("Only ") && text.hasSuffix("stores reported Prep Not Ready this upload.")
    }

    /// "36 of 1,297" from the thin-coverage note. Nil when the card is graded.
    static func prepCoverageTile(fromNote text: String) -> String? {
        guard isPrepThinNote(text) else { return nil }
        let rest = text.dropFirst("Only ".count)
        guard let end = rest.range(of: " stores reported Prep Not Ready this upload.") else { return nil }
        let tile = String(rest[..<end.lowerBound])
        return tile.isEmpty ? nil : tile
    }

    /// Distinct stores on the rows passed in. A store counts as reported when any of its rows has a rate.
    /// Ignored stores stay out, matching the other scorecards.
    static func prepCoverage(_ rows: [MetricRow]) -> PrepCoverage {
        var reportedByStore: [String: Bool] = [:]
        for row in rows {
            let store = canonicalStore(row.storeNumber)
            if store.isEmpty || store.caseInsensitiveCompare("TOTAL") == .orderedSame { continue }
            if isIgnoredStore(store) { continue }
            // Numeric 0 is a reported rate. Only a missing key is blank.
            let hasRate = row.number("pnr_rate_pct", "pnr_hours", "prep_not_ready_pct") != nil
            reportedByStore[store] = (reportedByStore[store] ?? false) || hasRate
        }
        let reported = reportedByStore.values.filter { $0 }.count
        return PrepCoverage(reported: reported, inScope: reportedByStore.count)
    }

    /// Company Prep tile. Every uploaded prep fact already has a rate, so the
    /// tile is that rollup. Roster stores with no fact stay blank. They do not
    /// turn the tile into a dash or a No data badge.
    static func companyPrepKeepsFactRollup(_ facts: PrepCoverage?) -> Bool {
        guard let facts, facts.reported > 0 else { return false }
        return !facts.thin
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
            let scored = latest.filter { $0.number("star_rating") != nil }
            let headline = average(scored.compactMap { $0.number("star_rating") })
            let five = scored.filter { ($0.number("star_rating") ?? 0) >= 4.95 }.count
            let pass = scored.filter { ($0.number("star_rating") ?? 0) >= fiveStarPass }.count
            let fail = scored.filter { ($0.number("star_rating") ?? .greatestFiniteMagnitude) < fiveStarPass }.count
            return SectionSummary(
                section: section,
                storeCount: scored.count,
                headline: headline,
                headlineLabel: "Avg star rating",
                secondary: scored.isEmpty
                    ? "No 5 Star rows in this filter"
                    : "\(five) of \(scored.count) at 5.00 · \(pass) pass · \(fail) fail",
                health: scored.isEmpty ? .none : band(headline, good: AssistScoreLine.fiveStarGoal, watch: AssistScoreLine.fiveStarPass),
                watchCount: scored.filter { fiveStarHealth($0) == .watch }.count,
                riskCount: scored.filter { fiveStarHealth($0) == .risk }.count,
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
            let coverage = prepCoverage(rows)
            if coverage.thin {
                return SectionSummary(
                    section: section,
                    storeCount: coverage.inScope,
                    headline: nil,
                    headlineLabel: "Avg PNR hours",
                    secondary: coverage.note,
                    health: .none,
                    watchCount: 0,
                    riskCount: 0,
                    lastFilename: upload?.filename,
                    lastUploadedAt: upload?.uploadedAt
                )
            }
            let rates = latest.compactMap { $0.number("pnr_rate_pct") }
            if rates.isEmpty, !PulseLaunch.shouldInventPrepRateOnEmptyStore() {
                return SectionSummary(
                    section: section,
                    storeCount: 0,
                    headline: 0,
                    headlineLabel: "Avg PNR hours",
                    secondary: PulseLaunch.prepEmptyStoreDetail,
                    health: .none,
                    watchCount: 0,
                    riskCount: 0,
                    lastFilename: upload?.filename,
                    lastUploadedAt: upload?.uploadedAt
                )
            }
            let headline = average(rates)
            let atGoal = latest.filter { ($0.number("pnr_rate_pct") ?? .greatestFiniteMagnitude) <= pnrGoal }.count
            let atRisk = latest.filter { ($0.number("pnr_rate_pct") ?? 0) > pnrWatch }.count
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: headline,
                headlineLabel: "Avg PNR hours",
                secondary: latest.isEmpty
                    ? PulseLaunch.prepEmptyStoreDetail
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
                if risk > 0 || underRisk > 0 || overRisk > 0 { return .risk }
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
            let scored = latest.filter { pphNumber($0) != nil }
            let headline = weekPurePPH(latest)
            let atGoal = scored.filter { (pphNumber($0) ?? 0) >= pphGoal }.count
            let atRisk = scored.filter { (pphNumber($0) ?? .greatestFiniteMagnitude) < pphRisk }.count
            return SectionSummary(
                section: section,
                storeCount: scored.count,
                headline: headline,
                headlineLabel: "Week Pure PPH",
                secondary: scored.isEmpty
                    ? "No stores in view"
                    : "\(atGoal) of \(scored.count) at 80 · \(atRisk) below 74",
                health: headline == nil ? .none : band(headline, good: pphGoal, watch: pphRisk),
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
                headline: Double(board.shopperCount),
                headlineLabel: "Shoppers",
                secondary: latest.isEmpty
                    ? "No shoppers in view"
                    : "\(board.opportunityCount) opportunity · \(board.strongCount) doing well",
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
            let stores = latest.filter {
                $0.textPayload["lost_grain"] != "market"
                    && !isIgnoredStore($0.storeNumber)
                    && !$0.storeNumber.isEmpty
                    && $0.number("lost_revenue") != nil
            }
            // Roster ignores stay out of the store count (`latest`). Their dollars
            // stay in the workbook sum when the seat has no market Total row.
            // Store 239 is about $218 and is the gap versus the Power BI store sum.
            let dollarRows = rows.filter {
                $0.textPayload["lost_grain"] != "market"
                    && !$0.storeNumber.isEmpty
                    && $0.number("lost_revenue") != nil
            }
            let market = latest.first { $0.textPayload["lost_grain"] == "market" && $0.storeNumber.isEmpty }
            // Excel "Total Lost Revenue (Total Opportunity)":
            // unfiltered → Total / grand-total row; filtered → that column on stores in seat.
            let marketDollars = totalOpportunityDollars(market)
            let storeTotals = lostRevenueTotals(dollarRows)
            let dollars: Double?
            let pct: Double?
            // Power BI Total Opportunity (HB-0828.369–372): the unfiltered company
            // headline is the market total row whenever that row has dollars.
            if marketDollars > 0 {
                dollars = marketDollars
                pct = market?.number("lost_revenue_pct")
            } else if !dollarRows.isEmpty {
                dollars = storeTotals.dollars
                pct = storeTotals.pct
            } else {
                dollars = nil
                pct = nil
            }
            let scored = stores
            let goal = lostRevenueGoalPct(rows: rows, market: market)
            let scope = lostRevenueScopeNote(rows)
            return SectionSummary(
                section: section,
                storeCount: stores.count,
                headline: dollars,
                headlineLabel: "Total lost revenue",
                secondary: scope
                    ?? (scored.isEmpty
                        ? "No Lost Revenue rows in this filter"
                        : "Total Lost Revenue % (Total Opportunity)"),
                health: pct == nil && scored.isEmpty ? .none : lostRevenueStatus(pct: pct, goal: goal),
                watchCount: scored.filter { lostRevenueHealth($0) == .watch }.count,
                riskCount: scored.filter { lostRevenueHealth($0) == .risk }.count,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt,
                lostRevenuePct: pct
            )
        case .sales:
            let stores = Dictionary(
                grouping: latest.filter {
                    $0.textPayload["sales_grain"] != "company"
                        && $0.textPayload["sales_grain"] != "day"
                        && !$0.storeNumber.isEmpty
                },
                by: { canonicalStore($0.storeNumber) }
            ).compactMap { $0.value.first }
            let storeSum = stores.reduce(0) { $0 + salesHeadlineDollars($1) }
            let company = salesCompanyRow(latest)
            let companyDollars = company.map { salesHeadlineDollars($0) } ?? 0
            let dollars = companyDollars > 0 ? companyDollars : storeSum
            let yoy = companyDollars > 0
                ? company?.number("sales_yoy_pct")
                : salesRollupYoY(
                    current: stores.map { salesHeadlineDollars($0) },
                    yoyPct: stores.map { $0.number("sales_yoy_pct") }
                )
            let plan = stores.compactMap { $0.number("sales_plan") }.reduce(0, +)
            let planPct: Double? = {
                if let direct = average(stores.compactMap { $0.number("sales_plan_pct") }) { return direct }
                return plan > 0 ? dollars / plan * 100 : nil
            }()
            let orders = stores.reduce(0) { $0 + salesOrders($1) }
            let up = stores.filter { salesHealth($0) == .good }.count
            let flat = stores.filter { salesHealth($0) == .watch }.count
            let down = stores.filter { salesHealth($0) == .risk }.count
            let healthValue = salesHealth(planPct: planPct, yoy: yoy)
            return SectionSummary(
                section: section,
                storeCount: stores.count,
                headline: stores.isEmpty && dollars == 0 ? nil : dollars,
                headlineLabel: "eComm sales",
                secondary: stores.isEmpty
                    ? "No Sales rows in this filter"
                    : "\(up) up · \(flat) flat · \(down) down",
                health: healthValue,
                watchCount: flat,
                riskCount: down,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt,
                salesYoyPct: yoy
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
        case .preSubOOSItem:
            let units = latest.compactMap { $0.number("presub_count") }.reduce(0, +)
            return SectionSummary(
                section: section,
                storeCount: Set(latest.map(\.storeNumber)).count,
                headline: average(latest.compactMap { $0.number("presub_pct") }),
                headlineLabel: "Item Pre-Sub OOS",
                secondary: latest.isEmpty
                    ? "No Pre-Sub item rows in this filter"
                    : "\(latest.count) items · \(HeartbeatFormat.num(units, digits: 0)) units",
                health: latest.isEmpty ? .none : band(average(latest.compactMap { $0.number("presub_pct") }), good: missingItemsGoal, watch: missingItemsWatch, invert: true),
                watchCount: latest.filter { missingItemsHealth(pct: $0.number("presub_pct")) == .watch }.count,
                riskCount: latest.filter { missingItemsHealth(pct: $0.number("presub_pct")) == .risk }.count,
                lastFilename: upload?.filename,
                lastUploadedAt: upload?.uploadedAt
            )
        case .storeRoster:
            return SectionSummary(
                section: section,
                storeCount: latest.count,
                headline: Double(latest.count),
                headlineLabel: "Stores",
                secondary: latest.isEmpty ? "No Roster rows" : "\(latest.count) stores · filters use this list",
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
    static let laborGoal = AssistScoreLine.laborGoal
    static let lostRevenueGood = 3.0
    static let lostRevenueWatch = 5.0
    static let salesPlanGood = 100.0
    static let salesPlanWatch = 95.0
    static let salesYoyWatch = AssistScoreLine.salesWatch
    static let missingItemsGoal = 5.0
    static let missingItemsWatch = 6.50
    static let pickPathGoal = AssistScoreLine.pickPathGoal
    static let pickPathRisk = 80.0
    static let dynacapGoal = 65.0
    static let dynacapRisk = 60.0
    static let scheduleGoal = 90.0
    static let scheduleWatch = AssistScoreLine.scheduleWatch
    static let scheduleVarianceWatch = 5.0
    static let fiveStarGoal = AssistScoreLine.fiveStarGoal
    static let fiveStarPass = AssistScoreLine.fiveStarPass

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
        band(row.number("star_rating"), good: AssistScoreLine.fiveStarStoreGood, watch: AssistScoreLine.fiveStarPass)
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

    struct FiveStarFlag: Identifiable, Equatable, Sendable, Codable {
        var id: String { name }
        let name: String
        let value: String
        let health: Health
        let stores: Int
        var unit: String = "stores"

        enum CodingKeys: String, CodingKey {
            case name, value, health, stores, unit
        }

        init(name: String, value: String, health: Health, stores: Int, unit: String = "stores") {
            self.name = name
            self.value = value
            self.health = health
            self.stores = stores
            self.unit = unit
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            value = try container.decode(String.self, forKey: .value)
            health = try container.decode(Health.self, forKey: .health)
            stores = try container.decode(Int.self, forKey: .stores)
            unit = try container.decodeIfPresent(String.self, forKey: .unit) ?? "stores"
        }
    }

    static func fiveStarActionFlags(_ rows: [MetricRow], includeAll: Bool = false) -> [FiveStarFlag] {
        let specs: [(name: String, key: String, mark: (MetricRow) -> StarMark)] = [
            ("Flash", "flash_pct", flashStar),
            ("COE", "coe_pct", coeStar),
            ("OTT", "ott_pct", ottStar),
            ("Pre Sub OOS%", "presub_pct", presubStar),
            ("OTH 5%", "oth5_pct", othStar),
        ]
        var flags: [FiveStarFlag] = []
        flags.reserveCapacity(specs.count)
        for spec in specs {
            var values: [Double] = []
            var risk = 0
            values.reserveCapacity(rows.count)
            for row in rows {
                guard let value = row.number(spec.key) else { continue }
                values.append(value)
                if spec.mark(row).health == .risk { risk += 1 }
            }
            guard !values.isEmpty, let avg = average(values) else { continue }
            let probe = MetricRow(
                section: .fiveStar,
                division: "",
                operationsOM: "",
                storeNumber: "AVG",
                payload: [spec.key: avg]
            )
            let health = spec.mark(probe).health
            if !includeAll, health == .good, risk == 0 { continue }
            flags.append(
                FiveStarFlag(
                    name: spec.name,
                    value: HeartbeatFormat.pct(avg),
                    health: health,
                    stores: risk
                )
            )
        }
        return flags
    }

    static func lostRevenueMetricFlags(_ rows: [MetricRow], includeAll: Bool = true) -> [FiveStarFlag] {
        let stores = lostRevenueStoreRows(rows)
        let specs: [(name: String, dollar: String, pct: String)] = [
            ("Total Lost Revenue", "lost_revenue", "lost_revenue_pct"),
            ("Post Sub OOS Foregone", "post_sub_oos_foregone", "post_sub_oos_foregone_pct"),
            ("Refund $ Fulfillment", "refund_lost", "refund_lost_pct"),
            ("Reduced Capacity Missed Sales", "missed_sales", "missed_sales_pct"),
            ("Cancelled Orders LDAP", "cancelled_lost", "cancelled_lost_pct"),
            ("Kill Switch Lost Sales", "kill_switch_lost", "kill_switch_pct"),
        ]
        var flags: [FiveStarFlag] = []
        flags.reserveCapacity(specs.count)
        for spec in specs {
            var dollars = lostRevenueTODollars(rows, key: spec.dollar)
            var sales = lostRevenueTODollars(rows, key: "ecomm_sales")
            var risk = 0
            var seen = dollars != 0 || lostRevenueMarketRow(in: rows)?.number(spec.dollar) != nil
            if !seen {
                for row in stores {
                    if let value = row.number(spec.dollar) {
                        dollars += value
                        seen = true
                        sales += row.number("ecomm_sales") ?? 0
                    } else if spec.dollar == "missed_sales", let cap = row.number("reduced_capacity") {
                        dollars += cap
                        seen = true
                        sales += row.number("ecomm_sales") ?? 0
                    }
                }
            }
            for row in stores {
                let pct = row.number(spec.pct)
                if lostRevenueHealth(pct: pct) == .risk {
                    risk += 1
                }
            }
            guard seen || includeAll else { continue }
            if !seen, !includeAll { continue }
            let pct = lostRevenueMarketRow(in: rows)?.number(spec.pct)
                ?? (sales > 0 ? dollars / sales : stores.compactMap { $0.number(spec.pct) }.first)
            let health: Health
            switch spec.dollar {
            case "refund_lost", "cancelled_lost":
                health = lostSalesDollarHealth(dollars: dollars, pct: pct, anyDollarIsRisk: false)
            case "kill_switch_lost":
                health = lostSalesDollarHealth(dollars: dollars, pct: pct, anyDollarIsRisk: true)
            default:
                let banded = lostRevenueHealth(pct: pct)
                health = banded == .none ? (dollars > 0 ? .watch : .good) : banded
            }
            if !includeAll, dollars == 0, health == .good { continue }
            flags.append(
                FiveStarFlag(
                    name: spec.name,
                    value: HeartbeatFormat.money(dollars),
                    health: health,
                    stores: risk
                )
            )
        }
        return flags
    }

    static func lostRevenueActionFlags(_ rows: [MetricRow]) -> [FiveStarFlag] {
        lostRevenueMetricFlags(rows, includeAll: true)
    }

    static func salesActionFlags(_ rows: [MetricRow]) -> [FiveStarFlag] {
        let stores = rows.filter { $0.textPayload["sales_grain"] != "company" && !$0.storeNumber.isEmpty }
        let healthy = stores.filter { salesHealth($0) == .good }.count
        let watch = stores.filter { salesHealth($0) == .watch }.count
        let risk = stores.filter { salesHealth($0) == .risk }.count
        return [
            FiveStarFlag(name: "Healthy", value: "Positive ID", health: .good, stores: healthy),
            FiveStarFlag(name: "Watch", value: "Slightly under", health: watch == 0 ? .good : .watch, stores: watch),
            FiveStarFlag(name: "At Risk", value: "Negative ID", health: risk == 0 ? .good : .risk, stores: risk),
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
        let stores = rows.filter { !isIgnoredStore($0.storeNumber) && !$0.storeNumber.isEmpty }
        let scoped = stores.isEmpty ? rows : stores
        func avg(_ keys: String...) -> Double? {
            average(scoped.compactMap { row in
                keys.lazy.compactMap { row.number($0) }.first
            })
        }
        func risk(_ health: (MetricRow) -> Health) -> Int {
            scoped.filter { health($0) == .risk }.count
        }
        let efficiency = avg("schedule_efficiency_pct")
        let staffing = avg("staffing_efficiency_pct")
        let under = avg("under_schedule_pct", "under_scheduled", "under_staffing_pct")
        let over = avg("over_schedule_pct", "over_scheduled", "over_staffing_pct")
        let flags = [
            FiveStarFlag(
                name: "Sch Effi %",
                value: HeartbeatFormat.pct(efficiency),
                health: band(efficiency, good: scheduleGoal, watch: scheduleWatch),
                stores: risk { band($0.number("schedule_efficiency_pct"), good: scheduleGoal, watch: scheduleWatch) }
            ),
            FiveStarFlag(
                name: "Staffing % Pch VS TGT",
                value: HeartbeatFormat.pct(staffing),
                health: band(staffing, good: scheduleGoal, watch: scheduleWatch),
                stores: risk { band($0.number("staffing_efficiency_pct"), good: scheduleGoal, watch: scheduleWatch) }
            ),
            FiveStarFlag(
                name: "Under",
                value: HeartbeatFormat.pct(under),
                health: varianceHealth(under),
                stores: risk { varianceHealth($0.number("under_schedule_pct", "under_scheduled", "under_staffing_pct")) }
            ),
            FiveStarFlag(
                name: "Over",
                value: HeartbeatFormat.pct(over),
                health: varianceHealth(over),
                stores: risk { varianceHealth($0.number("over_schedule_pct", "over_scheduled", "over_staffing_pct")) }
            ),
        ]
        if includeAll { return flags }
        return flags.filter { $0.health.needsAction || $0.stores > 0 }
    }

    static func laborActionFlags(_ rows: [MetricRow]) -> [FiveStarFlag] {
        let stores = rows.filter { $0.textPayload["labor_grain"] != "market" && !isIgnoredStore($0.storeNumber) }
        let tva = laborRollup(rows, key: "target_vs_actual_pct")
        let act = laborRollup(rows, key: "act_cost_pct")
        let cost = laborRollup(rows, key: "cost_trgt_pct")
        let efficiency = laborRollup(rows, key: "schedule_efficiency_pct")
        let uplh = laborRollup(rows, key: "uplh_impact_pct")
        let wage = laborRollup(rows, key: "wage_impact_pct")
        let aiv = laborRollup(rows, key: "aiv_impact_pct")
        let actHealth: Health = {
            guard let act, let cost else { return laborHealth(act) }
            return act <= cost ? .good : .risk
        }()
        return [
            FiveStarFlag(
                name: "Target Vs Actual",
                value: HeartbeatFormat.pct(tva),
                health: laborHealth(tva),
                stores: stores.filter { laborHealth($0.number("target_vs_actual_pct")) == .risk }.count
            ),
            FiveStarFlag(
                name: "Act Cost %",
                value: HeartbeatFormat.pct(act),
                health: actHealth == .none ? .watch : actHealth,
                stores: stores.filter {
                    guard let rowAct = $0.number("act_cost_pct"), let rowCost = $0.number("cost_trgt_pct") else { return false }
                    return rowAct > rowCost
                }.count
            ),
            FiveStarFlag(
                name: "Cost Target %",
                value: HeartbeatFormat.pct(cost),
                health: cost == nil ? .none : .good,
                stores: 0
            ),
            FiveStarFlag(
                name: "Schedule Efficiency %",
                value: HeartbeatFormat.pct(efficiency),
                health: band(efficiency, good: scheduleGoal, watch: scheduleWatch),
                stores: stores.filter {
                    band($0.number("schedule_efficiency_pct"), good: scheduleGoal, watch: scheduleWatch) == .risk
                }.count
            ),
            FiveStarFlag(
                name: "UPLH",
                value: HeartbeatFormat.pct(uplh),
                health: laborHealth(uplh),
                stores: stores.filter { laborHealth($0.number("uplh_impact_pct")) == .risk }.count
            ),
            FiveStarFlag(
                name: "WAGE",
                value: HeartbeatFormat.pct(wage),
                health: laborHealth(wage),
                stores: stores.filter { laborHealth($0.number("wage_impact_pct")) == .risk }.count
            ),
            FiveStarFlag(
                name: "AIV",
                value: HeartbeatFormat.pct(aiv),
                health: laborHealth(aiv),
                stores: stores.filter { laborHealth($0.number("aiv_impact_pct")) == .risk }.count
            ),
        ]
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

    static func pphDashboardFlags(_ rows: [MetricRow], pickers: [MetricRow] = []) -> [FiveStarFlag] {
        let stores = latestPerStore(rows.filter { !isIgnoredStore($0.storeNumber) && !$0.storeNumber.isEmpty })
        let scored = stores.filter { pphNumber($0) != nil }
        let pph = weekPurePPH(rows, pickers: pickers)
        let sourceCount = scored.isEmpty ? storePPHLookup(pickers).count : scored.count
        let healthy = scored.filter { health(for: .pph, row: $0) == .good }.count
        let watch = scored.filter { health(for: .pph, row: $0) == .watch }.count
        let risk = scored.filter { health(for: .pph, row: $0) == .risk }.count
        var flags: [FiveStarFlag] = [
            FiveStarFlag(
                name: "PPH",
                value: HeartbeatFormat.num(pph, digits: 1),
                health: band(pph, good: pphGoal, watch: pphRisk),
                stores: sourceCount,
                unit: "stores"
            )
        ]
        flags += bandFlags(healthy: healthy, watch: watch, risk: risk)
        return flags
    }

    static func dynacapActionFlags(_ rows: [MetricRow], bookPPH: [MetricRow] = []) -> [FiveStarFlag] {
        let stores = rows.filter { !isIgnoredStore($0.storeNumber) && !$0.storeNumber.isEmpty }
        let scoped = stores.isEmpty ? rows : stores
        let pieces = average(scoped.compactMap { $0.number("dynacap_rate", "pieces_per_hour") })
        var pph = weekPurePPH(scoped)
        var pphStores = latestPerStore(scoped.filter { pphNumber($0) != nil })
        if pph == nil || pphStores.isEmpty {
            pph = weekPurePPH(bookPPH)
            pphStores = latestPerStore(bookPPH.filter {
                !isIgnoredStore($0.storeNumber) && pphNumber($0) != nil
            })
        }
        let util = average(scoped.compactMap { $0.number("utilization_pct", "pickup_util_pct") })
        return [
            FiveStarFlag(
                name: "Pieces / Hr",
                value: HeartbeatFormat.num(pieces, digits: 1),
                health: band(pieces, good: dynacapGoal, watch: dynacapRisk),
                stores: scoped.filter { band($0.number("dynacap_rate", "pieces_per_hour"), good: dynacapGoal, watch: dynacapRisk) == .risk }.count
            ),
            FiveStarFlag(
                name: "Store PPH",
                value: HeartbeatFormat.num(pph, digits: 1),
                health: band(pph, good: pphGoal, watch: pphRisk),
                stores: pphStores.filter { band(pphNumber($0), good: pphGoal, watch: pphRisk) == .risk }.count
            ),
            FiveStarFlag(
                name: "Utilization",
                value: HeartbeatFormat.pct(util),
                health: band(util, good: dynacapGoal, watch: dynacapRisk),
                stores: scoped.filter { band($0.number("utilization_pct", "pickup_util_pct"), good: dynacapGoal, watch: dynacapRisk) == .risk }.count
            ),
        ]
    }

    static func preSubActionFlags(_ rows: [MetricRow], items: [MetricRow] = []) -> [FiveStarFlag] {
        let stores = rows.filter { !isIgnoredStore($0.storeNumber) && !$0.storeNumber.isEmpty }
        let scoped = stores.isEmpty ? rows : stores
        let above = scoped.filter { missingItemsHealth($0) == .risk }.count
        let goal = scoped.filter { missingItemsHealth($0) == .good }.count
        let close = scoped.filter { missingItemsHealth($0) == .watch }.count
        var flags: [FiveStarFlag] = [
            FiveStarFlag(name: "Above 5%", value: "", health: above == 0 ? .good : .risk, stores: above),
            FiveStarFlag(name: "At Goal", value: "≤ 5%", health: .good, stores: goal),
            FiveStarFlag(name: "Close to Goal", value: "5–6.5%", health: close == 0 ? .good : .watch, stores: close),
        ]
        let ranked = items.max { lhs, rhs in
            (lhs.number("presub_pct") ?? 0) < (rhs.number("presub_pct") ?? 0)
        }
        if let ranked {
            flags.append(
                FiveStarFlag(
                    name: "#1 Pre-Sub Item",
                    value: HeartbeatFormat.pct(ranked.number("presub_pct")),
                    health: missingItemsHealth(pct: ranked.number("presub_pct")),
                    stores: 1,
                    unit: {
                        let label = compactCalloutLabel(
                            ranked.textPayload["bpn"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        )
                        return label.isEmpty ? "item" : label
                    }()
                )
            )
        }
        return flags
    }

    static func pickPathMetricFlags(_ rows: [MetricRow]) -> [FiveStarFlag] {
        let stores = rows.filter { !isIgnoredStore($0.storeNumber) && !$0.storeNumber.isEmpty }
        let scoped = stores.isEmpty ? rows : stores
        let path = average(scoped.compactMap { $0.number("compliance_pct") })
        let pph = average(scoped.compactMap(pphNumber))
        return [
            FiveStarFlag(
                name: "Pick Path",
                value: HeartbeatFormat.pct(path),
                health: band(path, good: pickPathGoal, watch: pickPathRisk),
                stores: scoped.filter { band($0.number("compliance_pct"), good: pickPathGoal, watch: pickPathRisk) == .risk }.count
            ),
            FiveStarFlag(
                name: "AVG PPH",
                value: HeartbeatFormat.num(pph),
                health: band(pph, good: pphGoal, watch: pphRisk),
                stores: scoped.filter { band($0.number("pph"), good: pphGoal, watch: pphRisk) == .risk }.count
            ),
        ]
    }

    static func pickPathActionFlags(stores: [MetricRow], shoppers: [MetricRow]) -> [FiveStarFlag] {
        pickPathMetricFlags(stores.isEmpty ? shoppers : stores)
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
        band(pphNumber(row), good: pphGoal, watch: pphRisk)
    }

    static func laborRollup(_ rows: [MetricRow], key: String) -> Double? {
        if let market = rows.first(where: { $0.textPayload["labor_grain"] == "market" }),
           let value = market.number(key) {
            return value
        }
        let stores = rows.filter {
            $0.textPayload["labor_grain"] != "market" && !isIgnoredStore($0.storeNumber)
        }
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

    static func parsePctToken(_ text: String) -> Double? {
        let trimmed = text
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "—" { return nil }
        return Double(trimmed)
    }

    /// Header key that keeps $ / % so "Lost $" and "Lost %" stay distinct.
    static func expandHeaderKey(_ header: String) -> String {
        normalize(header)
            .replacingOccurrences(of: "$", with: "usd")
            .replacingOccurrences(of: "%", with: "pct")
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    /// Expand cell ink. Same Healthy / Watch / At Risk polarity as that section’s card callouts.
    /// Labor: +red / −green on TVA / UPLH / Wage / AIV. Cost Target stays black.
    static func dashboardExpandCellHealth(
        section: MetricSection,
        header: String,
        text: String,
        rowHealth: Health,
        values: [String] = [],
        headers: [String] = []
    ) -> Health {
        _ = rowHealth
        let key = expandHeaderKey(header)
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text == "—" {
            return .none
        }
        if section == .prepNotReady, key == "watch" || key == "goal" || key.contains("pnrgoal") {
            return .none
        }
        if key == "healthy" || key == "atgoal" { return .good }
        if key == "watch" { return .watch }
        if key.contains("atrisk") || key == "below74" || key == "risk" { return .risk }

        let number = parsePctToken(text)
        var siblings: [String: Double] = [:]
        if !headers.isEmpty, headers.count == values.count {
            for (title, cell) in zip(headers, values) {
                if let parsed = parsePctToken(cell) {
                    siblings[expandHeaderKey(title)] = parsed
                }
            }
        }

        switch section {
        case .labor:
            if key.contains("costtgt") || key.contains("costtarget") || key.contains("costtrgt") {
                return .none
            }
            if key.contains("targetvsactual") || key.contains("tgtvsact") || key == "tva"
                || key == "uplh" || key.contains("uplh")
                || key == "wage" || key.contains("wage")
                || key == "aiv" || key.contains("aiv") {
                return laborHealth(number)
            }
            if key.contains("scheff") || key.contains("actcost") {
                return .none
            }
            return .none
        case .lostRevenue:
            return lostRevenueExpandCellHealth(key: key, number: number, siblings: siblings)
        case .fiveStar:
            return fiveStarExpandCellHealth(key: key, number: number)
        case .missingItems, .preSubOOS, .preSubOOSItem:
            if key == "rate" || key == "total" || key.contains("presub") || key.contains("oos") {
                return missingItemsHealth(pct: number)
            }
            return .none
        case .pickPath, .pickPathPicker:
            if key.contains("path") || key.contains("compliance") {
                return band(number, good: pickPathGoal, watch: pickPathRisk)
            }
            if key.contains("pph") {
                return band(number, good: pphGoal, watch: pphRisk)
            }
            return .none
        case .prepNotReady:
            if key.contains("pnr") {
                return band(number, good: pnrGoal, watch: pnrWatch, invert: true)
            }
            return .none
        case .dynacap:
            if key.contains("pcs") || key.contains("pieces") || key.contains("dynacap") {
                return band(number, good: dynacapGoal, watch: dynacapRisk)
            }
            if key.contains("pph") {
                return band(number, good: pphGoal, watch: pphRisk)
            }
            if key.contains("util") {
                return band(number, good: dynacapGoal, watch: dynacapRisk)
            }
            return .none
        case .scheduleQuality:
            if key.contains("under") || key.contains("over") {
                return varianceHealth(number)
            }
            if key.contains("scheff") || key.contains("efficiency") || key.contains("staffing") {
                return band(number, good: scheduleGoal, watch: scheduleWatch)
            }
            return .none
        case .pph:
            if key.contains("pph") || key.contains("pure") {
                return band(number, good: pphGoal, watch: pphRisk)
            }
            return .none
        case .sales:
            if key.contains("yoy") {
                return salesHealth(planPct: nil, yoy: number)
            }
            return .none
        case .pickerScorecard:
            return .none
        default:
            return .none
        }
    }

    private static func lostRevenueExpandCellHealth(
        key: String,
        number: Double?,
        siblings: [String: Double]
    ) -> Health {
        if key.contains("goal") || key.contains("ecomm") || key.contains("salesusd") {
            return .none
        }
        let dollars: Double
        let pct: Double?
        if key.contains("pct") || key.hasSuffix("pct") || key == "lostpct" {
            dollars = siblings["lostusd"] ?? siblings["lost"] ?? 0
            pct = number
        } else {
            dollars = number ?? 0
            pct = siblings["lostpct"]
                ?? lostRevenueImpliedPct(dollars: dollars, sales: siblings["ecommusd"] ?? siblings["ecomm"])
        }
        if key.contains("refund") || key.contains("cancel") {
            return lostSalesDollarHealth(dollars: dollars, pct: pct, anyDollarIsRisk: false)
        }
        if key.contains("kill") {
            return lostSalesDollarHealth(dollars: dollars, pct: pct, anyDollarIsRisk: true)
        }
        let banded = lostRevenueHealth(pct: pct)
        if key.contains("post") || key.contains("missed") {
            let implied = pct ?? lostRevenueImpliedPct(
                dollars: dollars,
                sales: siblings["ecommusd"] ?? siblings["ecomm"]
            )
            let fromPct = lostRevenueHealth(pct: implied)
            return fromPct == .none ? (dollars > 0 ? .watch : .good) : fromPct
        }
        return banded == .none ? (dollars > 0 ? .watch : .good) : banded
    }

    private static func lostRevenueImpliedPct(dollars: Double, sales: Double?) -> Double? {
        guard let sales, sales > 0 else { return nil }
        return dollars / sales
    }

    private static func fiveStarExpandCellHealth(key: String, number: Double?) -> Health {
        if key.contains("rating") || key.contains("star") {
            return band(number, good: AssistScoreLine.fiveStarStoreGood, watch: AssistScoreLine.fiveStarPass)
        }
        if key.contains("flash") {
            return starMark(value: number, full: 75, half: 55).health
        }
        if key.contains("coe") {
            return starMark(value: number, full: 20, half: 0).health
        }
        if key.contains("ott") {
            return starMark(value: number, full: 95, half: 90).health
        }
        if key.contains("presub") {
            return starMark(value: number, full: 5, half: 6, invert: true).health
        }
        if key.contains("oth") {
            return starMark(value: number, full: 92, half: 78).health
        }
        return .none
    }

    static func lostRevenueHealth(_ row: MetricRow) -> Health {
        lostRevenueHealth(pct: row.number("lost_revenue_pct"))
    }

    /// FY goal % from the pack, or goal $ / eComm sales when the sheet only shipped dollars.
    static func lostRevenueGoalPct(_ row: MetricRow) -> Double? {
        if let pct = row.number(
            "lost_revenue_goal_pct",
            "goal_pct",
            "fy2026_goal_pct",
            "fy_goal_pct",
            "lost_revenue_fy_goal_pct"
        ) {
            return pct
        }
        let dollars = row.number(
            "lost_revenue_goal",
            "goal",
            "fy2026_goal",
            "fy_goal",
            "lost_revenue_fy_goal"
        )
        let sales = row.number("ecomm_sales", "sales_dollars")
        guard let dollars, let sales, sales > 0 else { return nil }
        return dollars / sales
    }

    static func lostRevenueGoalPct(rows: [MetricRow], market: MetricRow? = nil) -> Double? {
        if let market, let pct = lostRevenueGoalPct(market) { return pct }
        return lostRevenueInheritedGoalPct(rows: rows)
    }

    /// Goal % is goal $ / eComm. The sheet already stores that ratio. Do not scale it.
    static func lostRevenueInheritedGoalPct(rows: [MetricRow], fallback: Double? = nil) -> Double? {
        if let market = lostRevenueMarketRow(in: rows), let pct = lostRevenueGoalPct(market) {
            return pct
        }
        let dollars = rows.compactMap { $0.number("lost_revenue_goal") }.reduce(0, +)
        let sales = rows.compactMap { $0.number("ecomm_sales") }.reduce(0, +)
        if sales > 0, dollars > 0 { return dollars / sales }
        if let avg = average(rows.compactMap { lostRevenueGoalPct($0) }) { return avg }
        return fallback
    }

    /// Market / FY row in the book, else inherited store goals. Used when grain buckets skip `lost_grain=market`.
    static func lostRevenueGoalFallback(_ rows: [MetricRow]) -> Double? {
        if let market = rows.first(where: { $0.textPayload["lost_grain"] == "market" }),
           let pct = lostRevenueGoalPct(market) {
            return pct
        }
        if let total = rows.first(where: {
            canonicalStore($0.storeNumber).isEmpty && lostRevenueGoalPct($0) != nil
        }), let pct = lostRevenueGoalPct(total) {
            return pct
        }
        return lostRevenueInheritedGoalPct(rows: rows.filter { $0.textPayload["lost_grain"] != "market" })
    }

    /// Excel **Total Lost Revenue (Total Opportunity)** — pack key `lost_revenue`.
    static func totalOpportunityDollars(_ row: MetricRow?) -> Double {
        row?.number("lost_revenue") ?? 0
    }

    /// Excel Total row (column A = Total). Lost % is already lost $ / eComm, not a fraction to scale.
    static func lostRevenueRowIsCompanyTotal(_ row: MetricRow) -> Bool {
        guard row.textPayload["lost_grain"] == "market",
              canonicalStore(row.storeNumber).isEmpty,
              let lost = row.number("lost_revenue"), lost > 0
        else { return false }
        return true
    }

    /// Lost % already equals lost $ / eComm. A ×100 copy (1.80 vs 0.018) does not match.
    static func lostRevenueSheetRatioMatches(_ row: MetricRow) -> Bool {
        guard let lost = row.number("lost_revenue"),
              let sales = row.number("ecomm_sales"), sales > 0,
              let pct = row.number("lost_revenue_pct")
        else { return false }
        return abs(lost / sales - pct) <= 0.05
    }

    /// Prefer the Total whose Lost % matches lost $ / eComm with no extra ×100.
    static func lostRevenueMarketRow(in rows: [MetricRow]) -> MetricRow? {
        let totals = rows.filter { lostRevenueRowIsCompanyTotal($0) }
        let matched = totals.filter { lostRevenueSheetRatioMatches($0) }
        let pool = matched.isEmpty ? totals : matched
        return pool.max { ($0.number("lost_revenue") ?? 0) < ($1.number("lost_revenue") ?? 0) }
    }

    /// First-column and later cells. A dash stays nil so a chrome row can keep it.
    static func grainNumber(_ row: DashboardGrainTableRow, _ index: Int) -> Double? {
        guard index < row.values.count else { return nil }
        return parsedTileNumber(row.values[index])
    }

    /// Shopper counts already on the row stay. Healthy / Watch / At Risk fill
    /// only where the current cell is a dash.
    static func pickerRowsKeepingShoppers(
        _ current: [DashboardGrainTableRow],
        filling incoming: [DashboardGrainTableRow]
    ) -> [DashboardGrainTableRow] {
        let headers = dashboardTableHeaders(.pickerScorecard)
        guard !current.isEmpty else { return incoming }
        var byAlias: [String: DashboardGrainTableRow] = [:]
        byAlias.reserveCapacity(incoming.count * 3)
        for row in incoming {
            for alias in grainAliasKeys(row.label, grain: .region) where byAlias[alias] == nil {
                byAlias[alias] = row
            }
        }
        return current.map { row in
            var match: DashboardGrainTableRow?
            for alias in grainAliasKeys(row.label, grain: .region) {
                if let hit = byAlias[alias] {
                    match = hit
                    break
                }
            }
            let values = mergedGrainValues(
                current: row.values,
                incoming: match?.values ?? [],
                headerCount: headers.count,
                fillDashesOnly: true
            )
            let count = row.storeCount > 0 ? row.storeCount : (match?.storeCount ?? 0)
            let health = row.health == .none ? (match?.health ?? row.health) : row.health
            return DashboardGrainTableRow(
                label: row.label,
                storeCount: count,
                values: values,
                health: health
            )
        }
    }

    static func parsedTileNumber(_ value: String) -> Double? {
        let cleaned = value
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned != "—", cleaned != "-", cleaned != "–" else { return nil }
        return Double(cleaned)
    }

    static func tileNumber(_ tiles: CompanyCardTiles, label: String) -> Double? {
        guard let index = tiles.labels.firstIndex(of: label), index < tiles.values.count else { return nil }
        return parsedTileNumber(tiles.values[index])
    }

    /// Cooked Loss tiles. A Total matches lost $ / eComm with no extra ×100.
    /// Older packs that stored lost $ / eComm × 100 still match that form.
    static func lossTilesMatchCompanyTotal(_ tiles: CompanyCardTiles) -> Bool {
        guard let lost = tileNumber(tiles, label: "Lost $"), lost > 0 else { return true }
        guard let sales = tileNumber(tiles, label: "eComm $"), sales > 0,
              let pct = tileNumber(tiles, label: "Lost %") else { return true }
        let ratio = lost / sales
        if abs(ratio - pct) <= 0.05 { return true }
        if abs(ratio * 100 - pct) <= 0.15 { return true }
        return false
    }

    static func lostRevenueStoreRows(_ rows: [MetricRow]) -> [MetricRow] {
        rows.filter {
            $0.textPayload["lost_grain"] != "market"
                && !isIgnoredStore($0.storeNumber)
                && !$0.storeNumber.isEmpty
        }
    }

    static let lostRevenueMissingStoreNote = "Store not in this week's Loss report"

    /// Store filter whose seat has no Loss Revenue workbook row. A roster placeholder is not a row.
    static func lostRevenueMissingStoreNoteApplies(filters: DashboardFilters, rows: [MetricRow]) -> Bool {
        guard !DashboardFilters.parts(filters.store).isEmpty else { return false }
        let stores = lostRevenueStoreRows(rows)
        if stores.isEmpty { return true }
        return stores.allSatisfy { !hasMetricFact(.lostRevenue, $0) }
    }

    /// Market Total key when that row is in the book. Otherwise the sum of store keys that exist.
    /// Missing keys stay nil so the tile is an em dash. An explicit 0 stays 0.
    /// Store dollars for a company tile when the Total row is missing.
    /// Ignored stores stay out of the store count. Their dollars stay in this sum (store 239).
    static func lostRevenueDollarRows(_ rows: [MetricRow]) -> [MetricRow] {
        rows.filter {
            $0.textPayload["lost_grain"] != "market"
                && !$0.storeNumber.isEmpty
                && hasMetricFact(.lostRevenue, $0)
        }
    }

    static func lostRevenueReportedValue(_ rows: [MetricRow], key: String) -> Double? {
        if let market = lostRevenueMarketRow(in: rows), let value = market.number(key) {
            return value
        }
        let values = lostRevenueDollarRows(rows).compactMap { $0.number(key) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    static func lostRevenueReportedPct(_ rows: [MetricRow]) -> Double? {
        if let market = lostRevenueMarketRow(in: rows) {
            if let direct = market.number("lost_revenue_pct") { return direct }
            if let sales = market.number("ecomm_sales"), sales > 0, let lost = market.number("lost_revenue") {
                return lostRevenueDisplayPct(dollars: lost, sales: sales, stored: [])
            }
            return nil
        }
        let facts = lostRevenueDollarRows(rows)
        let sales = facts.compactMap { $0.number("ecomm_sales") }.reduce(0, +)
        let dollars = facts.compactMap { $0.number("lost_revenue") }.reduce(0, +)
        let stored = facts.compactMap { $0.number("lost_revenue_pct") }
        if sales > 0, dollars > 0 {
            return lostRevenueDisplayPct(dollars: dollars, sales: sales, stored: stored)
        }
        return average(stored)
    }

    /// Unfiltered: Excel Total / market-row TO key. Filtered seat: SUM of that TO key.
    /// One path — market row present means company book; callers must not attach it on a seat.
    static func lostRevenueTODollars(_ rows: [MetricRow], key: String) -> Double {
        if let market = lostRevenueMarketRow(in: rows), let value = market.number(key) {
            return value
        }
        return lostRevenueStoreRows(rows).compactMap { $0.number(key) }.reduce(0, +)
    }

    /// Lost % stays in the sheet's percent units. 4.5 means 4.5%.
    /// A dollar ratio that is about 100× smaller than the stored percent is that same number as a fraction.
    /// A ratio that already matches the stored percent (4.84 vs 4.84) is left alone.
    /// Dollars and sales with no stored percent are a fraction of sales. 484 / 10,000 is 4.84%, not 0.05%.
    static func lostRevenueDisplayPct(dollars: Double, sales: Double, stored: [Double]) -> Double? {
        let sample = average(stored.filter(\.isFinite))
        guard sales > 0, dollars.isFinite else { return sample }
        let ratio = dollars / sales
        let scaled = ratio * 100
        guard let sample else { return scaled }
        if abs(scaled - sample) < abs(ratio - sample) {
            return scaled
        }
        return ratio
    }

    static func lostRevenueTotals(_ stores: [MetricRow]) -> (dollars: Double, sales: Double, pct: Double?) {
        var dollars = 0.0
        var sales = 0.0
        var stored: [Double] = []
        for row in stores {
            guard let lost = row.number("lost_revenue") else { continue }
            dollars += lost
            if let pct = row.number("lost_revenue_pct") { stored.append(pct) }
            if let ecomm = row.number("ecomm_sales"), ecomm >= 20 {
                sales += ecomm
            }
        }
        let pct = lostRevenueDisplayPct(dollars: dollars, sales: sales, stored: stored)
        return (dollars, sales, pct)
    }

    static func lostRevenueHealth(pct: Double?) -> Health {
        band(pct, good: lostRevenueGood, watch: lostRevenueWatch, invert: true)
    }

    /// Above the sheet Goal % is at risk. A missing goal keeps the 3% / 5% bands.
    static func lostRevenueStatus(pct: Double?, goal: Double?) -> Health {
        guard let pct else { return .none }
        if let goal {
            return pct > goal ? .risk : .good
        }
        return lostRevenueHealth(pct: pct)
    }

    /// "203 of 2,177 stores reported · 9/27". The day comes from the sheet footer when the cook stamped it.
    /// The Loss tab's division column is not a scope.
    static func lostRevenueScopeNote(_ rows: [MetricRow], rosterStores: Int = 0) -> String? {
        let stores = rows.filter {
            $0.textPayload["lost_grain"] != "market"
                && !canonicalStore($0.storeNumber).isEmpty
                && !isIgnoredStore($0.storeNumber)
                && $0.number("lost_revenue") != nil
        }
        let ids = Set(stores.map { canonicalStore($0.storeNumber) })
        guard !ids.isEmpty else { return nil }
        var days: [String] = []
        var seenDay: Set<String> = []
        for row in rows {
            let day = (row.textPayload["loss_day"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !day.isEmpty, seenDay.insert(day).inserted else { continue }
            days.append(day)
        }
        days.sort()
        let reported = groupedCount(ids.count)
        let body: String
        if rosterStores > 0 {
            body = "\(reported) of \(groupedCount(rosterStores)) stores reported"
        } else {
            body = "\(reported) \(ids.count == 1 ? "store" : "stores") reported"
        }
        if days.count == 1 {
            return "\(body) · \(days[0])"
        }
        return body
    }

    static func isLossScopeNote(_ text: String) -> Bool {
        text.contains("store reported") || text.contains("stores reported")
    }

    /// A region or division that holds every Loss store uses the Excel Total, not the store-row sum.
    static func lossGrainRows(_ group: [MetricRow], section: MetricSection, universe: [MetricRow]) -> [MetricRow] {
        guard section == .lostRevenue else { return group }
        guard let market = universe.first(where: { lostRevenueRowIsCompanyTotal($0) }) else { return group }
        func ids(_ list: [MetricRow]) -> Set<String> {
            Set(list.compactMap { row -> String? in
                if row.textPayload["lost_grain"] == "market" { return nil }
                let store = canonicalStore(row.storeNumber)
                guard !store.isEmpty, !isIgnoredStore(store), row.number("lost_revenue") != nil else { return nil }
                return store
            })
        }
        let all = ids(universe)
        let have = ids(group)
        guard !all.isEmpty, have == all else { return group }
        return group + [market]
    }

    /// Refund / cancel / kill-switch dollars are lost sales. $0 is healthy; any loss is at least watch.
    static func lostSalesDollarHealth(dollars: Double, pct: Double?, anyDollarIsRisk: Bool) -> Health {
        if dollars <= 0 { return .good }
        if anyDollarIsRisk { return .risk }
        let fromPct = lostRevenueHealth(pct: pct)
        if fromPct == .risk { return .risk }
        return .watch
    }

    static func salesHeadlineDollars(_ row: MetricRow) -> Double {
        if let week = row.number("sales_dollars"), week > 0 { return week }
        return (0..<7).compactMap { row.number("sales_d\($0)_dollars") }.reduce(0, +)
    }

    /// Official Excel Total row. Company-wide Sales must use this, not a store rollup.
    static func salesCompanyRow(_ rows: [MetricRow]) -> MetricRow? {
        if let hit = rows.first(where: { $0.textPayload["sales_grain"] == "company" }) {
            return hit
        }
        return rows.first {
            canonicalStore($0.storeNumber).isEmpty
                && $0.storeNumber.caseInsensitiveCompare("total") != .orderedSame
                && $0.textPayload["sales_grain"] != "day"
                && salesHeadlineDollars($0) >= 5_000_000
        }
    }

    static func salesOrders(_ row: MetricRow) -> Double {
        if let week = row.number("sales_orders"), week > 0 { return week }
        return (0..<7).compactMap { row.number("sales_d\($0)_orders") }.reduce(0, +)
    }

    static func salesItems(_ row: MetricRow) -> Double {
        let week = row.number("sales_items") ?? 0
        let days = (0..<7).compactMap { row.number("sales_d\($0)_items") }.reduce(0, +)
        return max(week, days)
    }

    static func salesPriorFromYoY(current: Double, yoyPct: Double?) -> Double? {
        guard current.isFinite, current > 0, let yoyPct, yoyPct.isFinite else { return nil }
        // Blank, Infinity, and a rate at or below -100% have no prior-year dollars.
        guard yoyPct > -100, abs(yoyPct) < 1_000 else { return nil }
        let factor = 1 + yoyPct / 100
        guard factor.isFinite, factor > 0 else { return nil }
        let prior = current / factor
        guard prior.isFinite, prior > 0 else { return nil }
        return prior
    }

    static func salesRollupYoY(current: [Double], yoyPct: [Double?]) -> Double? {
        var thisYear = 0.0
        var lastYear = 0.0
        for (value, pct) in zip(current, yoyPct) {
            guard let last = salesPriorFromYoY(current: value, yoyPct: pct) else { continue }
            thisYear += value
            lastYear += last
        }
        guard lastYear > 0, thisYear > 0 else { return nil }
        return (thisYear / lastYear - 1) * 100
    }

    static let salesWeekdayShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    static let salesPartialWeekNote = "Partial week — YOY compares these days only"

    static func salesRowHasDay(_ row: MetricRow, index: Int) -> Bool {
        guard (0..<7).contains(index) else { return false }
        let prefix = "sales_d\(index)_"
        let dollars = row.payload[prefix + "dollars"]
        let orders = row.payload[prefix + "orders"]
        let items = row.payload[prefix + "items"]
        if dollars == nil, orders == nil, items == nil { return false }
        return (dollars ?? 0) > 0 || (orders ?? 0) > 0 || (items ?? 0) > 0
    }

    static func salesPopulatedDayIndexes(_ rows: [MetricRow]) -> [Int] {
        (0..<7).filter { index in rows.contains { salesRowHasDay($0, index: index) } }
    }

    static func salesShowsPartialWeekNote(dayCount: Int) -> Bool {
        dayCount > 0 && dayCount < 7
    }

    /// `202631` → fiscal 2026 week 31. Week 1 is the Sunday after the last Saturday in February.
    static func salesFiscalWeekSunday(year: Int, week: Int) -> Date? {
        guard (1...53).contains(week) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        guard let march1 = calendar.date(from: DateComponents(year: year, month: 3, day: 1)),
              let februaryLast = calendar.date(byAdding: .day, value: -1, to: march1)
        else { return nil }
        let weekday = calendar.component(.weekday, from: februaryLast)
        let backToSaturday = (weekday - 7 + 7) % 7
        guard let saturday = calendar.date(byAdding: .day, value: -backToSaturday, to: februaryLast),
              let start = calendar.date(byAdding: .day, value: 1, to: saturday)
        else { return nil }
        return calendar.date(byAdding: .day, value: (week - 1) * 7, to: start)
    }

    /// Days that actually have dollars, orders, or items. Example: `Week 31 · Sun 9/27 only (1 of 7 days)`.
    static func salesCoverageLabel(rows: [MetricRow], weekKey: String) -> String? {
        let days = salesPopulatedDayIndexes(rows)
        guard !days.isEmpty else { return nil }
        let parts = salesWeekParts(weekKey)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let sunday = parts.flatMap { salesFiscalWeekSunday(year: $0.year, week: $0.week) }
        let dated = days.map { index -> String in
            let name = salesWeekdayShort[index]
            guard let sunday,
                  let day = calendar.date(byAdding: .day, value: index, to: sunday)
            else { return name }
            let month = calendar.component(.month, from: day)
            let date = calendar.component(.day, from: day)
            return "\(name) \(month)/\(date)"
        }
        let list: String
        if dated.count == 1 {
            list = "\(dated[0]) only"
        } else if dated.count == 7, let first = dated.first, let last = dated.last {
            list = "\(first)–\(last)"
        } else {
            list = dated.joined(separator: ", ")
        }
        let count = "(\(dated.count) of 7 days)"
        if let parts {
            return "Week \(parts.week) · \(list) \(count)"
        }
        return "\(list) \(count)"
    }

    static func salesWeekParts(_ raw: String) -> (year: Int, week: Int)? {
        let digits = raw.filter(\.isNumber)
        guard digits.count == 6,
              let year = Int(digits.prefix(4)),
              let week = Int(digits.suffix(2)),
              (1...53).contains(week)
        else { return nil }
        return (year, week)
    }

    static func salesHealth(_ row: MetricRow) -> Health {
        salesHealth(planPct: row.number("sales_plan_pct"), yoy: row.number("sales_yoy_pct"))
    }

    static func salesHealth(planPct: Double?, yoy: Double?) -> Health {
        if let yoy {
            if yoy > 0 { return .good }
            if yoy >= AssistScoreLine.salesWatch { return .watch }
            return .risk
        }
        if let planPct {
            return band(planPct, good: salesPlanGood, watch: salesPlanWatch)
        }
        return .none
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
        if (row.number("orders") ?? 0) > 0 { return true }
        if (row.number("picks") ?? 0) > 0 { return true }
        if (row.number("pick_hours") ?? 0) > 0 { return true }
        return row.number("pph") != nil
    }

    static func refundHealth(_ row: MetricRow) -> Health {
        guard let amount = row.number("refund_amt") else { return .none }
        if amount <= 0 { return .good }
        if amount <= 20 { return .watch }
        return .risk
    }

    static func isRealPicker(_ row: MetricRow) -> Bool {
        let store = row.storeNumber
        if store.localizedCaseInsensitiveContains("filter") { return false }
        if store.localizedCaseInsensitiveContains("WEEK") { return false }
        if let id = row.shopperId, !id.isEmpty { return true }
        let name = row.shopperName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return pickerHasVolume(row) }
        if name.localizedCaseInsensitiveContains("unknown") { return pickerHasVolume(row) }
        return true
    }

    static func pickerMatches(_ row: MetricRow, focus: PickerFocus) -> Bool {
        guard isRealPicker(row) else { return false }
        switch focus {
        case .all:
            return true
        case .healthy:
            return pickerHasVolume(row) && pickerHealth(row) == .good
        case .watchList:
            return pickerHasVolume(row) && pickerHealth(row) == .watch
        case .riskList:
            return pickerHasVolume(row) && pickerHealth(row) == .risk
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

    /// Card tiles and expand Healthy / Watch / At Risk must use this count.
    /// Raw `pickerHealth` leaves volume shoppers at `.none` — tiles already
    /// promote those to Watch and fall back to the opportunity board.
    static func pickerStatusTone(_ row: MetricRow) -> Health {
        var health = pickerHealth(row)
        if health == .none, pickerHasVolume(row) { health = .watch }
        return health
    }

    static func pickerStatusCounts(_ rows: [MetricRow]) -> (shoppers: Int, healthy: Int, watch: Int, risk: Int) {
        let shoppers = rows.filter { isRealPicker($0) || pickerHasVolume($0) }
        let pool = shoppers.isEmpty ? rows : shoppers
        var healthy = pool.filter { pickerStatusTone($0) == .good }.count
        var watch = pool.filter { pickerStatusTone($0) == .watch }.count
        var risk = pool.filter { pickerStatusTone($0) == .risk }.count
        if healthy + watch + risk == 0, !pool.isEmpty {
            let board = pickerBoard(pool)
            healthy = board.strongCount
            risk = board.opportunityCount
            watch = max(0, pool.count - healthy - risk)
        }
        return (pool.count, healthy, watch, risk)
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
            guard pickerHasVolume(row), let pph = row.number("pph"), pph > 0, pph < 200 else { continue }
            var health = pickerHealth(row)
            if health == .none { health = .watch }
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
        case .sales:
            return row.number("sales_dollars") ?? 0
        case .missingItems, .preSubOOS, .preSubOOSItem:
            return row.number(section == .preSubOOSItem ? "presub_pct" : MissingItemDept.totalKey) ?? 0
        case .aisleMapper:
            return AisleMapperMath.ageDays(AisleMapperMath.mapperISO(row)) ?? 0
        case .storeRoster:
            return 0
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
        guard let value else { return .none }
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
            case .sales:
                value = row.number("sales_dollars")
            case .missingItems, .preSubOOS:
                value = row.number(MissingItemDept.totalKey)
            case .aisleMapper:
                value = AisleMapperMath.ageDays(AisleMapperMath.mapperISO(row))
            case .preSubOOSItem:
                value = row.number("presub_pct")
            case .storeRoster:
                value = nil
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
    case store

    var id: String { rawValue }

    var title: String {
        switch self {
        case .backstage: return "Backstage Support"
        case .evp: return "EVP Region"
        case .director: return "Director / Market VP / Sr Director Sales"
        case .districtManager: return "District Manager"
        case .om: return "Operations Manager"
        case .store: return "Store View"
        }
    }

    var detail: String {
        switch self {
        case .backstage:
            return "Total company view · every region, market, and store"
        case .evp:
            return "One or many regions · markets under each callout"
        case .director:
            return "One or many markets · districts under each callout"
        case .districtManager:
            return "One or many districts · stores under each callout"
        case .om:
            return "One or many OMs · assigned stores under each callout"
        case .store:
            return "One or many stores · that store book of business"
        }
    }

    var symbol: String {
        switch self {
        case .backstage: return "building.2.fill"
        case .evp: return "map.fill"
        case .director: return "chart.bar.doc.horizontal.fill"
        case .districtManager: return "square.grid.2x2.fill"
        case .om: return "person.crop.rectangle.stack.fill"
        case .store: return "storefront.fill"
        }
    }

    var pickNoun: String {
        switch self {
        case .evp: return "region"
        case .director: return "market"
        case .districtManager: return "district"
        case .om: return "OM"
        case .store: return "store"
        case .backstage: return ""
        }
    }

    var searchPrompt: String {
        switch self {
        case .evp: return "Search regions"
        case .director: return "Search markets"
        case .districtManager: return "Search districts"
        case .om: return "Search operations managers"
        case .store: return "Search stores"
        case .backstage: return ""
        }
    }

    var showsOnlyRiskAndWatch: Bool { self != .backstage }

    var dashboardGrain: DashScopeGrain {
        switch self {
        case .backstage: return .region
        case .evp: return .division
        case .director: return .district
        case .districtManager, .om, .store: return .store
        }
    }
}

enum DashScopeGrain: String, Sendable, Equatable, Hashable {
    case region
    case division
    case district
    case store

    var title: String {
        switch self {
        case .region: return "Regions"
        case .division: return "Markets"
        case .district: return "Districts"
        case .store: return "Stores"
        }
    }

    var unit: String {
        switch self {
        case .region: return "regions"
        case .division: return "markets"
        case .district: return "districts"
        case .store: return "stores"
        }
    }

    var symbol: String {
        switch self {
        case .region: return "globe.americas.fill"
        case .division: return "map.fill"
        case .district: return "square.grid.2x2.fill"
        case .store: return "storefront.fill"
        }
    }
}

struct DashScopeLine: Identifiable, Equatable, Sendable, Codable {
    var label: String
    var value: String
    var health: Health
    var count: Int
    var id: String { label }
}

struct DashScopePack: Identifiable, Equatable, Sendable, Codable {
    var line: DashScopeLine
    var flags: [HeartbeatMath.FiveStarFlag]
    var children: [DashScopeLine] = []
    var id: String { line.label }

    enum CodingKeys: String, CodingKey {
        case line, flags, children
    }

    init(line: DashScopeLine, flags: [HeartbeatMath.FiveStarFlag], children: [DashScopeLine] = []) {
        self.line = line
        self.flags = flags
        self.children = children
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        line = try container.decode(DashScopeLine.self, forKey: .line)
        flags = try container.decodeIfPresent([HeartbeatMath.FiveStarFlag].self, forKey: .flags) ?? []
        children = try container.decodeIfPresent([DashScopeLine].self, forKey: .children) ?? []
    }
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
        if selectedRegions.isEmpty { return true }
        return selectedRegions.contains { name in
            guard let region = MarketRegion(rawValue: name) ?? MarketRegion.named(name) else { return false }
            if region.contains(value) { return true }
            return MarketRegion.containing(value) == region
        }
    }

    func includesDistrict(_ value: String) -> Bool {
        let selected = Self.parts(district)
        if selected.isEmpty { return true }
        let wanted = Set(selected.flatMap { HeartbeatMath.districtMatchKeys($0) })
        if wanted.isEmpty { return false }
        let have = HeartbeatMath.districtMatchKeys(value)
        if have.isEmpty { return false }
        return !wanted.isDisjoint(with: have)
    }

    func includesOM(_ value: String) -> Bool {
        let selected = Self.parts(om)
        if selected.isEmpty { return true }
        return selected.contains { HeartbeatMath.matches(value, $0) }
    }

    func includesStore(_ value: String) -> Bool {
        let selected = Self.parts(store).map { HeartbeatMath.canonicalStore($0) }.filter { !$0.isEmpty }
        if selected.isEmpty { return true }
        return selected.contains(HeartbeatMath.canonicalStore(value))
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
        let values = parts(raw).map { HeartbeatMath.displayGrainLabel($0) }.filter { !$0.isEmpty }
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
        Self.region(forMarketOrTitle: division) == self
    }

    /// Region title only ("California", "California Region"). Markets use `containing`.
    /// Map lookup — never `containing` / `matchesDivision` / regex.
    static func named(_ raw: String) -> MarketRegion? {
        let key = lookupKey(raw)
        guard !key.isEmpty else { return nil }
        if let hit = regionTitleKeys[key] { return hit }
        if key.hasSuffix("region"), key.count > 6 {
            return regionTitleKeys[String(key.dropLast(6))]
        }
        return nil
    }

    /// Region title or a market inside it (NorCal / SoCal). Map only — never
    /// `contains` → `matchesDivision` (that stack-overflowed and Jetsamed).
    static func containing(_ division: String) -> MarketRegion? {
        region(forMarketOrTitle: division)
    }

    /// Map a store to East/South/California/West. Never `containing` (or district codes).
    /// `containing("J3")` is nil on purpose.
    static func resolved(division: String, district: String) -> MarketRegion? {
        if let named = named(division) { return named }
        let key = lookupKey(division)
        if let region = marketToRegion[key] { return region }
        let market = canonicalName(division)
        if !market.isEmpty, let region = marketToRegion[lookupKey(market)] { return region }
        if let named = named(district) { return named }
        return nil
    }

    static func matchesDivision(_ lhs: String, _ rhs: String) -> Bool {
        let aKey = lookupKey(lhs)
        let bKey = lookupKey(rhs)
        if aKey.isEmpty || bKey.isEmpty { return false }
        if aKey == bKey { return true }
        if let a = compactToOfficial[aKey], let b = compactToOfficial[bKey] {
            return a == b
        }
        let aRegion = regionTitleKeys[stripRegionSuffix(aKey)] ?? marketToRegion[aKey]
        let bRegion = regionTitleKeys[stripRegionSuffix(bKey)] ?? marketToRegion[bKey]
        if let aRegion, let bRegion { return aRegion == bRegion }
        return false
    }

    /// Title or market → region. District codes (`J3`) are not in the maps → nil.
    private static func region(forMarketOrTitle raw: String) -> MarketRegion? {
        if let named = named(raw) { return named }
        let key = lookupKey(raw)
        if key.isEmpty || ignoredDivisionKeys.contains(key) { return nil }
        return marketToRegion[key]
    }

    static let ignoredDivisionKeys: Set<String> = [
        "total", "grandtotal", "all", "alldivisions", "allmarkets", "company",
        "na", "none", "null", "blank", "unassigned", "unknown",
    ]

    /// Blank / filter leftovers / Unassigned tokens. Never a real Excel market.
    static func isIgnoredDivisionToken(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        let compact = HeartbeatMath.compactKey(trimmed)
        if ignoredDivisionKeys.contains(compact) { return true }
        if compact.contains("unassigned") { return true }
        return false
    }

    static let regionKeys: Set<String> = [
        "east", "west", "south", "california",
        "eastregion", "westregion", "southregion", "californiaregion",
    ]

    private static let officialExactNames = Set(officialDivisions)
    private static let canonicalNameLock = NSLock()
    private static var canonicalNameCache: [String: String] = [:]

    /// ASCII letters/digits only. No regex. Shared by name / region maps.
    private static func lookupKey(_ raw: String) -> String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(raw.utf8.count)
        for byte in raw.utf8 {
            if byte >= 65 && byte <= 90 {
                bytes.append(byte + 32)
            } else if (byte >= 97 && byte <= 122) || (byte >= 48 && byte <= 57) {
                bytes.append(byte)
            }
        }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }

    private static func stripRegionSuffix(_ key: String) -> String {
        if key.hasSuffix("region"), key.count > 6 { return String(key.dropLast(6)) }
        return key
    }

    /// Region titles only. Markets are in `marketToRegion`.
    private static let regionTitleKeys: [String: MarketRegion] = [
        "east": .east, "eastregion": .east,
        "south": .south, "southregion": .south,
        "west": .west, "westregion": .west,
        "california": .california, "californiaregion": .california,
        "calif": .california, "ca": .california,
    ]

    private static let marketToRegion: [String: MarketRegion] = [
        "shaws": .east, "midatlantic": .east, "jewelosco": .east,
        "southern": .south, "united": .south, "southwest": .south,
        "unitedtexas": .south, "unitedsupermarkets": .south,
        "norcal": .california, "socal": .california, "nocal": .california,
        "northerncalifornia": .california, "southerncalifornia": .california,
        "southerncal": .california,
        "mountainwest": .west, "seattle": .west, "haggen": .west, "portland": .west,
    ]

    private static let compactToOfficial: [String: String] = {
        var map: [String: String] = [:]
        for name in officialDivisions {
            map[lookupKey(name)] = name
        }
        map["midatlantic"] = "Mid-Atlantic"
        map["jewelosco"] = "Jewel Osco"
        map["nocal"] = "NorCal"
        map["northerncalifornia"] = "NorCal"
        map["southerncalifornia"] = "SoCal"
        map["southerncal"] = "SoCal"
        map["mountainwest"] = "Mountain West"
        map["unitedtexas"] = "United"
        map["unitedsupermarkets"] = "United"
        return map
    }()

    /// Cached map lookup. `computeCanonicalName` must not call `named` /
    /// `containing` / `matchesDivision` / `canonicalName` (recursion / Jetsam).
    static func canonicalName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if officialExactNames.contains(trimmed) { return trimmed }
        canonicalNameLock.lock()
        let hit = canonicalNameCache[trimmed]
        canonicalNameLock.unlock()
        if let hit { return hit }
        let value = computeCanonicalName(trimmed)
        canonicalNameLock.lock()
        if canonicalNameCache.count > 4_096 {
            canonicalNameCache.removeAll(keepingCapacity: true)
        }
        canonicalNameCache[trimmed] = value
        canonicalNameLock.unlock()
        return value
    }

    private static func computeCanonicalName(_ trimmed: String) -> String {
        var key = lookupKey(trimmed)
        for suffix in ["division", "div", "market", "banner", "region"] where key.hasSuffix(suffix) && key.count > suffix.count {
            key.removeLast(suffix.count)
        }
        if ignoredDivisionKeys.contains(key) || regionKeys.contains(key) { return "" }
        if let official = compactToOfficial[key] { return official }
        if key.hasPrefix("united") { return "United" }
        if key.contains("jewel") { return "Jewel Osco" }
        if key.hasPrefix("shaw") { return "Shaws" }
        if key.contains("mountainwest") { return "Mountain West" }
        if key.hasPrefix("haggen") { return "Haggen" }
        if key.hasPrefix("portland") { return "Portland" }
        if key.hasPrefix("seattle") { return "Seattle" }
        if key.hasPrefix("southwest") { return "Southwest" }
        return compactToOfficial[key] ?? ""
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

    /// Pill copy. Empty focus always shows Region / Division / District / OM / Store.
    func chipTitle(for focus: FilterFocus) -> String {
        let selected = values(for: focus)
        if selected.isEmpty { return focus.chipTitle }
        if selected.count == 1 { return HeartbeatMath.displayGrainLabel(selected[0]) }
        return "\(HeartbeatMath.displayGrainLabel(selected[0])) +\(selected.count - 1)"
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
        if focus == .division {
            if current.contains(where: matches) {
                current.removeAll(where: matches)
                division = current.joined(separator: "\n")
            } else {
                division = incoming
                district = ""
                om = ""
                store = ""
            }
            return
        }
        if current.contains(where: matches) {
            current.removeAll(where: matches)
        } else {
            current.append(incoming)
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

/// One scope's Picker ScoreCard. Shoppers are distinct PICKER ids.
/// Stores are distinct stores. Healthy + Watch + At Risk equals Shoppers.
struct PickerScopeRollup: Codable, Equatable, Sendable {
    var shoppers: Int
    var stores: Int
    var healthy: Int
    var watch: Int
    var risk: Int

    var cardHealth: Health {
        if risk > 0 { return .risk }
        if watch > 0 { return .watch }
        if healthy > 0 { return .good }
        return .none
    }

    var tileValues: [String] {
        [
            HeartbeatFormat.num(Double(shoppers)),
            HeartbeatFormat.num(Double(healthy)),
            HeartbeatFormat.num(Double(watch)),
            HeartbeatFormat.num(Double(risk)),
        ]
    }
}

/// Cook-time picker counts for every grain. The phone reads this map.
/// It does not decode the Picker ScorCard tab to paint region cards.
enum PickerScopeRollups {
    static func distinctPickerCount(_ rows: [MetricRow]) -> Int {
        var ids = Set<String>()
        ids.reserveCapacity(rows.count)
        for row in rows {
            guard let id = pickerID(row) else { continue }
            ids.insert(id)
        }
        return ids.count
    }

    static func catalog(
        rows: [MetricRow],
        roster: [String: HeartbeatMath.StoreIdentity],
        includeCompany: Bool
    ) -> [String: PickerScopeRollup] {
        let bag = ScopeBag()
        for row in rows {
            guard row.section == .pickerScorecard, let id = pickerID(row) else { continue }
            var stamped = HeartbeatMath.stampRoster(row, roster: roster)
            let store = HeartbeatMath.canonicalStore(stamped.storeNumber)
            if let identity = rosterIdentity(store, roster: roster) {
                if !identity.om.isEmpty { stamped.operationsOM = identity.om }
                if !identity.district.isEmpty { stamped.textPayload["district"] = identity.district }
            }
            var tone = HeartbeatMath.pickerStatusTone(stamped)
            if tone == .none { tone = .watch }
            if includeCompany {
                bag.add(PreSubTopItems.companyScope, id: id, store: store, tone: tone)
            }
            if let region = MarketRegion.resolved(division: stamped.division, district: stamped.district) {
                bag.add(PreSubTopItems.regionScope(region.rawValue), id: id, store: store, tone: tone)
            }
            let division = RollupMarketFill.divisionKey(stamped.division)
            if !division.isEmpty {
                bag.add(PreSubTopItems.divisionScope(division), id: id, store: store, tone: tone)
            }
            let district = RollupMarketFill.districtKey(stamped.district)
            if !district.isEmpty {
                bag.add(PreSubTopItems.districtScope(district), id: id, store: store, tone: tone)
            }
            let om = HeartbeatMath.canonicalOM(stamped.operationsOM)
            if !om.isEmpty {
                bag.add(PreSubTopItems.omScope(om), id: id, store: store, tone: tone)
            }
            bag.add(PreSubTopItems.storeScope(store), id: id, store: store, tone: tone)
        }
        return bag.finish()
    }

    static func apply(
        onto chrome: inout PulseDashChrome,
        rows: [MetricRow],
        roster: [String: HeartbeatMath.StoreIdentity],
        includeCompany: Bool
    ) {
        let rollups = catalog(rows: rows, roster: roster, includeCompany: includeCompany)
        guard !rollups.isEmpty else { return }
        chrome.pickerRollups = rollups
        guard includeCompany, let company = rollups[PreSubTopItems.companyScope] else { return }
        chrome.pickerShoppers = company.shoppers
        chrome.pickerStrong = company.healthy
        chrome.pickerOpportunity = company.risk
        chrome.companyTiles[MetricSection.pickerScorecard.rawValue] = CompanyCardTiles(
            labels: HeartbeatMath.dashboardTableHeaders(.pickerScorecard),
            values: company.tileValues
        )
        let secondary = "\(company.risk) opportunity · \(company.healthy) doing well"
        if let index = chrome.summaries.firstIndex(where: { $0.section == .pickerScorecard }) {
            chrome.summaries[index].headline = Double(company.shoppers)
            chrome.summaries[index].headlineLabel = "Shoppers"
            chrome.summaries[index].watchCount = company.watch
            chrome.summaries[index].riskCount = company.risk
            chrome.summaries[index].secondary = secondary
            if chrome.summaries[index].health == .none {
                chrome.summaries[index].health = company.cardHealth
            }
        }
    }

    /// Region / division / district / store cards for the active filter.
    static func grainRows(
        rollups: [String: PickerScopeRollup],
        grain: DashScopeGrain,
        filters: DashboardFilters,
        roster: [String: HeartbeatMath.StoreIdentity]
    ) -> [HeartbeatMath.DashboardGrainTableRow] {
        guard !rollups.isEmpty else { return [] }
        let labels = grainLabels(rollups: rollups, grain: grain, filters: filters, roster: roster)
        return labels.compactMap { label in
            let key = PreSubTopItems.grainScope(grain, label: label)
            guard let roll = rollups[key], roll.shoppers > 0 else { return nil }
            return HeartbeatMath.DashboardGrainTableRow(
                label: label,
                storeCount: roll.stores,
                values: roll.tileValues,
                health: roll.cardHealth
            )
        }
    }

    private static func pickerID(_ row: MetricRow) -> String? {
        guard HeartbeatMath.isRealPicker(row) || HeartbeatMath.pickerHasVolume(row) else { return nil }
        let store = HeartbeatMath.canonicalStore(row.storeNumber)
        if store.isEmpty || HeartbeatMath.isIgnoredStore(store) { return nil }
        if store.caseInsensitiveCompare("TOTAL") == .orderedSame { return nil }
        let id = HeartbeatMath.canonicalShopper(row.shopperKey)
        return id.isEmpty ? nil : id
    }

    private static func rosterIdentity(
        _ store: String,
        roster: [String: HeartbeatMath.StoreIdentity]
    ) -> HeartbeatMath.StoreIdentity? {
        if let hit = roster[store] { return hit }
        for alias in HeartbeatMath.storeAliases(store) {
            if let hit = roster[alias] { return hit }
        }
        return nil
    }

    private static func grainLabels(
        rollups: [String: PickerScopeRollup],
        grain: DashScopeGrain,
        filters: DashboardFilters,
        roster: [String: HeartbeatMath.StoreIdentity]
    ) -> [String] {
        switch grain {
        case .region:
            return MarketRegion.allCases.map(\.rawValue).filter { label in
                rollups[PreSubTopItems.regionScope(label)] != nil && regionMatches(label, filters: filters)
            }
        case .division:
            return prefixed(rollups, "division:")
                .filter { filters.includesDivision($0) }
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        case .district:
            let present = prefixed(rollups, "district:")
            let allowed = allowedKeys(filters: filters, roster: roster) { identity, _ in
                RollupMarketFill.districtKey(identity.district)
            }
            let labels = allowed.isEmpty && !filters.isActive ? present : present.filter { allowed.contains($0) }
            return labels.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        case .store:
            let present = prefixed(rollups, "store:")
            let allowed = allowedKeys(filters: filters, roster: roster) { _, store in store }
            let labels = allowed.isEmpty && !filters.isActive ? present : present.filter { allowed.contains($0) }
            return labels.sorted { HeartbeatFormat.storeOrder($0, $1) }
        }
    }

    private static func prefixed(_ rollups: [String: PickerScopeRollup], _ prefix: String) -> [String] {
        rollups.keys.compactMap { key in
            guard key.hasPrefix(prefix) else { return nil }
            let label = String(key.dropFirst(prefix.count))
            return label.isEmpty ? nil : label
        }
    }

    private static func regionMatches(_ label: String, filters: DashboardFilters) -> Bool {
        if filters.region.isEmpty { return true }
        let labelRegion = MarketRegion.named(label) ?? MarketRegion(rawValue: label)
        return filters.regions.contains { raw in
            let selected = MarketRegion.named(raw) ?? MarketRegion(rawValue: raw)
            if let labelRegion, let selected { return labelRegion == selected }
            return raw == label
        }
    }

    private static func allowedKeys(
        filters: DashboardFilters,
        roster: [String: HeartbeatMath.StoreIdentity],
        key: (HeartbeatMath.StoreIdentity, String) -> String
    ) -> Set<String> {
        var out = Set<String>()
        for (store, identity) in roster {
            let number = HeartbeatMath.canonicalStore(store)
            guard !number.isEmpty else { continue }
            guard filters.includesStore(number),
                  filters.includesDivision(identity.division),
                  filters.includesDistrict(identity.district),
                  filters.includesOM(identity.om)
            else { continue }
            let label = key(identity, number)
            if !label.isEmpty { out.insert(label) }
        }
        return out
    }

    private final class Bucket {
        var tones: [String: Health] = [:]
        var stores = Set<String>()

        func add(id: String, store: String, tone: Health) {
            if !store.isEmpty { stores.insert(store) }
            if let have = tones[id] {
                if tone.dashboardRank < have.dashboardRank { tones[id] = tone }
            } else {
                tones[id] = tone
            }
        }

        func finish() -> PickerScopeRollup {
            var healthy = 0
            var watch = 0
            var risk = 0
            for tone in tones.values {
                switch tone {
                case .good: healthy += 1
                case .risk: risk += 1
                case .watch, .none: watch += 1
                }
            }
            return PickerScopeRollup(
                shoppers: tones.count,
                stores: stores.count,
                healthy: healthy,
                watch: watch,
                risk: risk
            )
        }
    }

    private final class ScopeBag {
        var scopes: [String: Bucket] = [:]

        func add(_ scope: String, id: String, store: String, tone: Health) {
            guard !scope.isEmpty else { return }
            if scopes[scope] == nil { scopes[scope] = Bucket() }
            scopes[scope]?.add(id: id, store: store, tone: tone)
        }

        func finish() -> [String: PickerScopeRollup] {
            var out: [String: PickerScopeRollup] = [:]
            out.reserveCapacity(scopes.count)
            for (scope, bucket) in scopes {
                let roll = bucket.finish()
                if roll.shoppers > 0 { out[scope] = roll }
            }
            return out
        }
    }
}

/// Cook-time top 10 Pre-Sub OOS items for one scope. The phone reads one key
/// at a time from `presub_top`. It never sums the 16.8k item rows.
enum PreSubTopItems {
    static let missingTabNote = "Item detail not in this upload"
    static let heading = "Top 10 Pre-Sub OOS items"
    static let limit = 10
    static let companyScope = "company"

    struct Item: Codable, Equatable, Sendable {
        var name: String
        var code: String
        var percent: Double?
        var count: Double
    }

    struct Catalog: Equatable {
        var tabPresent: Bool
        var lists: [String: [Item]]
    }

    /// What the card shows. `missingNote` is set only when the item tab was not cooked.
    struct Card: Equatable {
        var missingNote: String?
        var items: [Item]
    }

    static func regionScope(_ label: String) -> String { "region:\(label)" }
    static func divisionScope(_ label: String) -> String { "division:\(label)" }
    static func districtScope(_ label: String) -> String { "district:\(label)" }
    static func omScope(_ label: String) -> String { "om:\(label)" }
    static func storeScope(_ number: String) -> String {
        "store:\(HeartbeatMath.canonicalStore(number))"
    }

    /// Finest active filter. Company when nothing is selected. Empty when several
    /// values share a grain — there is no single cooked key for that combination.
    static func seatScope(_ filters: DashboardFilters) -> String {
        if filters.stores.count == 1 { return storeScope(filters.stores[0]) }
        if filters.oms.count == 1 { return omScope(HeartbeatMath.canonicalOM(filters.oms[0])) }
        if filters.districts.count == 1 {
            return districtScope(RollupMarketFill.districtKey(filters.districts[0]))
        }
        if filters.divisions.count == 1 {
            return divisionScope(RollupMarketFill.divisionKey(filters.divisions[0]))
        }
        if filters.regions.count == 1 {
            let raw = filters.regions[0]
            return regionScope(MarketRegion(rawValue: raw)?.rawValue ?? raw)
        }
        if !filters.isActive { return companyScope }
        return ""
    }

    static func grainScope(_ grain: DashScopeGrain, label: String) -> String {
        switch grain {
        case .region: return regionScope(label)
        case .division: return divisionScope(label)
        case .district: return districtScope(label)
        case .store: return storeScope(label)
        }
    }

    /// Leading BPN number comes off the name. The code stays available to show small.
    static func displayParts(_ raw: String) -> (name: String, code: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [#"^(\d{4,})\s*[-–:]\s*"#, #"^(\d{4,})\s+"#]
        for pattern in patterns {
            guard let match = trimmed.range(of: pattern, options: .regularExpression) else { continue }
            let code = String(trimmed[match]).filter(\.isNumber)
            let name = String(trimmed[match.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty, !code.isEmpty { return (name, code) }
        }
        return (trimmed, "")
    }

    static func countText(_ count: Double) -> String {
        if abs(count.rounded() - count) < 0.05 {
            return HeartbeatFormat.num(count, digits: 0)
        }
        return HeartbeatFormat.num(count, digits: 1)
    }

    /// Group by BPN DESC. count = sum(Pre-Sub OOS). % = sum(count) / sum(ORD_QTY).
    /// Never the average of the row percents. Rank by count, then by %.
    /// Region and OM come from the store directory, not the item row.
    static func catalog(
        items: [MetricRow],
        roster: [String: HeartbeatMath.StoreIdentity],
        includeCompany: Bool
    ) -> Catalog {
        guard !items.isEmpty else { return Catalog(tabPresent: false, lists: [:]) }
        let scopes = ScopeBag()
        for row in items {
            let bpn = (row.textPayload["bpn"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !bpn.isEmpty else { continue }
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            guard !store.isEmpty, !HeartbeatMath.isIgnoredStore(store) else { continue }
            let known = roster[store]
            let division = RollupMarketFill.divisionKey(
                (known?.division.isEmpty == false ? known?.division : nil) ?? row.division
            )
            let districtRaw: String = {
                if let district = known?.district, !district.isEmpty { return district }
                return row.textPayload["district"] ?? ""
            }()
            let district = RollupMarketFill.districtKey(districtRaw)
            let om = HeartbeatMath.canonicalOM(
                (known?.om.isEmpty == false ? known?.om : nil) ?? row.operationsOM
            )
            let region = MarketRegion.resolved(division: division, district: district)?.rawValue ?? ""
            let count = row.payload["presub_count"] ?? 0
            let orders = row.payload["ord_qty"] ?? 0
            if includeCompany { scopes.add(companyScope, bpn, count: count, orders: orders) }
            if !region.isEmpty { scopes.add(regionScope(region), bpn, count: count, orders: orders) }
            if !division.isEmpty { scopes.add(divisionScope(division), bpn, count: count, orders: orders) }
            if !district.isEmpty { scopes.add(districtScope(district), bpn, count: count, orders: orders) }
            if !om.isEmpty { scopes.add(omScope(om), bpn, count: count, orders: orders) }
            scopes.add(storeScope(store), bpn, count: count, orders: orders)
        }
        return Catalog(tabPresent: true, lists: scopes.finish())
    }

    private final class Acc {
        var count: Double = 0
        var orders: Double = 0
    }

    private final class ItemMap {
        var items: [String: Acc] = [:]
    }

    private final class ScopeBag {
        var scopes: [String: ItemMap] = [:]

        func add(_ scope: String, _ bpn: String, count: Double, orders: Double) {
            if scopes[scope] == nil { scopes[scope] = ItemMap() }
            guard let map = scopes[scope] else { return }
            let acc = map.items[bpn] ?? Acc()
            acc.count += count
            acc.orders += orders
            map.items[bpn] = acc
        }

        func finish() -> [String: [Item]] {
            var out: [String: [Item]] = [:]
            out.reserveCapacity(scopes.count)
            for (scope, map) in scopes {
                let ranked = map.items.map { bpn, acc -> Item in
                    let parts = displayParts(bpn)
                    let percent: Double? = acc.orders > 0 ? (acc.count / acc.orders) * 100 : nil
                    return Item(
                        name: parts.name.isEmpty ? bpn : parts.name,
                        code: parts.code,
                        percent: percent,
                        count: acc.count
                    )
                }
                .sorted { lhs, rhs in
                    if lhs.count != rhs.count { return lhs.count > rhs.count }
                    let left = lhs.percent ?? -1
                    let right = rhs.percent ?? -1
                    if left != right { return left > right }
                    let name = lhs.name.localizedStandardCompare(rhs.name)
                    if name != .orderedSame { return name == .orderedAscending }
                    return lhs.code.localizedStandardCompare(rhs.code) == .orderedAscending
                }
                out[scope] = Array(ranked.prefix(limit))
            }
            return out
        }
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

    /// Page header clock. Device local time. Example: `Mon 9/28 3:10 PM`.
    static func publishClock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "EEE M/d h:mm a"
        return formatter.string(from: date)
    }

    static func parsePackTimestamp(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parser = ISO8601DateFormatter()
        if let date = parser.date(from: trimmed) { return date }
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return parser.date(from: trimmed)
    }
}

extension HeartbeatMath {
    /// Cook time on chrome, then the pack file's written time, then a summary upload.
    /// Nil when none of those exist. Does not substitute `Date()`.
    static func packPublishDate(chrome: PulseDashChrome?, writtenAt: Date?) -> Date? {
        if let published = chrome?.publishedAt { return published }
        if let writtenAt { return writtenAt }
        return chrome?.summaries.compactMap(\.lastUploadedAt).max()
    }
}

/// In-app "new data" banner. The clock is `HeartbeatFormat.publishClock`, the same
/// string the Updated header line uses.
enum NewDataAlert {
    static let dismissAfterSeconds: TimeInterval = 5

    /// Nil unless a published pack is strictly newer than the one already on screen.
    /// A first launch with no on-screen time does not count as new data.
    /// The in-app banner toggle turns the line off without touching the pack.
    static func bannerText(onScreen: Date?, incoming: Date?, bannerEnabled: Bool = true) -> String? {
        guard bannerEnabled else { return nil }
        guard let incoming, let onScreen, incoming > onScreen else { return nil }
        return "New data uploaded \(HeartbeatFormat.publishClock(incoming))"
    }
}

/// Settings toggles. UserDefaults only — no pack, chrome, or row reads.
enum NewDataPreferences {
    static let pushAlertsKey = "hb.newDataAlerts"
    static let bannerKey = "hb.inAppNewDataBanner"

    /// Missing key stays on. An explicit OFF is the only opt-out.
    static func pushAlertsEnabled(in defaults: UserDefaults) -> Bool {
        if defaults.object(forKey: pushAlertsKey) != nil {
            return defaults.bool(forKey: pushAlertsKey)
        }
        return true
    }

    static func setPushAlertsEnabled(_ on: Bool, in defaults: UserDefaults) {
        defaults.set(on, forKey: pushAlertsKey)
    }

    static func pushPreferenceChosen(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: pushAlertsKey) != nil
    }

    /// Missing key stays on.
    static func bannerEnabled(in defaults: UserDefaults) -> Bool {
        if defaults.object(forKey: bannerKey) != nil {
            return defaults.bool(forKey: bannerKey)
        }
        return true
    }

    static func setBannerEnabled(_ on: Bool, in defaults: UserDefaults) {
        defaults.set(on, forKey: bannerKey)
    }
}

/// Lock-screen alert permission. Asked once, and only after a pack is on screen.
enum NewDataPushPrompt {
    static let answeredKey = "hb.pushPromptAnswered"

    /// iOS permission dialog. Once, after a pack is on screen, and only while push is still on.
    static func shouldRequestSystemPermission(
        dataOnScreen: Bool,
        alreadyAsked: Bool,
        pushEnabled: Bool
    ) -> Bool {
        dataOnScreen && !alreadyAsked && pushEnabled
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
        case .sales:
            return StoreCellViewModel(
                primary: HeartbeatFormat.money(row.number("sales_dollars")),
                extra: "YoY \(HeartbeatFormat.pct(row.number("sales_yoy_pct"))) · \(HeartbeatFormat.num(row.number("sales_orders"), digits: 0)) orders"
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
        case .preSubOOSItem:
            return StoreCellViewModel(
                primary: HeartbeatFormat.pct(row.number("presub_pct")),
                extra: row.textPayload["bpn"] ?? row.textPayload["item"] ?? ""
            )
        case .storeRoster:
            return StoreCellViewModel(
                primary: row.district.isEmpty ? "—" : row.district,
                extra: row.operationsOM
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
    case healthy
    case watchList
    case riskList
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
        case .healthy: return "Healthy"
        case .watchList: return "Watch"
        case .riskList: return "At Risk"
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

