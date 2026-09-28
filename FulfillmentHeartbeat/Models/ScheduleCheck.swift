import Foundation

/// Compact Upcoming Weeks Schedule Check pack. Cooked on the Mac from
/// `Schedule Review Week *.xlsx`. Not part of the Heartbeat sqlite pack.
struct ScheduleCheckPack: Codable, Equatable {
    var publishedAt: String
    var week: Int
    var filename: String
    var summaryTitle: String
    var workbookActionBanner: Int?
    var markets: [ScheduleMarket]
    var stores: [ScheduleStore]

    static let objectName = "schedule-check.json"
    static let fileName = "schedule-check.json"

    var publishedDate: Date? {
        HeartbeatFormat.parsePackTimestamp(publishedAt)
    }

    func market(labeled name: String) -> ScheduleMarket? {
        markets.first { $0.label.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    static func read(from url: URL) -> ScheduleCheckPack? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(ScheduleCheckPack.self, from: data)
    }

    /// Mac cook writes here. iPhone reads the R2 copy cached in the app container.
    static var macCookedFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Heartbeat", isDirectory: true)
            .appendingPathComponent(fileName)
    }
}

struct ScheduleMarket: Codable, Equatable, Identifiable {
    var label: String
    var under: Double?
    var over: Double?
    var eff: Double?

    var id: String { label }
}

struct ScheduleStore: Codable, Equatable, Identifiable {
    var store: String
    var region: String
    var division: String
    var district: String
    var om: String
    var sales: Double?
    var under: Double?
    var over: Double?
    var eff: Double?
    var pch: Double?
    var fourUnder: Double?
    var fourOver: Double?
    var star: Double?
    var dayUnder: [Double?]
    var dayOver: [Double?]

    var id: String { store }

    init(
        store: String,
        region: String = "",
        division: String = "",
        district: String = "",
        om: String = "",
        sales: Double? = nil,
        under: Double? = nil,
        over: Double? = nil,
        eff: Double? = nil,
        pch: Double? = nil,
        fourUnder: Double? = nil,
        fourOver: Double? = nil,
        star: Double? = nil,
        dayUnder: [Double?] = Array(repeating: nil, count: 7),
        dayOver: [Double?] = Array(repeating: nil, count: 7)
    ) {
        self.store = store
        self.region = region
        self.division = division
        self.district = district
        self.om = om
        self.sales = sales
        self.under = under
        self.over = over
        self.eff = eff
        self.pch = pch
        self.fourUnder = fourUnder
        self.fourOver = fourOver
        self.star = star
        self.dayUnder = dayUnder
        self.dayOver = dayOver
    }

    /// First-look files mark an unscheduled store as Under 100% and Eff 0%.
    var notScheduled: Bool {
        guard let under, let eff else { return false }
        return under >= 99.5 && abs(eff) < 0.05
    }

    var hitUnder: Bool { (under ?? -1) >= ScheduleCheckMath.underGate }
    var hitFourWeek: Bool { ((fourUnder ?? -1) - ScheduleCheckMath.fourUnderGate) > 0.0001 }
    var hitOver: Bool { (over ?? -1) >= ScheduleCheckMath.overGate }
}

struct ScheduleScopeSummary: Equatable {
    var under: Double?
    var over: Double?
    var pch: Double?
    var eff: Double?
    var underCount: Int
    var overCount: Int
    var scope: Int
    var usesMarketLook: Bool
    var storeUnder: Double?
    var storeOver: Double?
    var actionCount: Int
}

struct ScheduleActionGroup: Equatable, Identifiable {
    var division: String
    var region: String
    var stores: [ScheduleStore]

    var id: String { division }
}

struct ScheduleRankRow: Equatable, Identifiable {
    var region: String
    var division: String
    var under: Double?
    var over: Double?
    var pch: Double?
    var eff: Double?
    var underCount: Int
    var overCount: Int
    var scope: Int

    var id: String { division.isEmpty ? region : "\(region)|\(division)" }
}

enum ScheduleCheckMath {
    static let salesGate = 30_000.0
    static let underGate = 10.0
    static let fourUnderGate = 9.0
    static let overGate = 15.0
    static let effGoal = 90.0
    static let dayNames = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    static func qualifies(sales: Double?, under: Double?, fourUnder: Double?, over: Double?) -> Bool {
        guard let sales, sales >= salesGate else { return false }
        if let under, under >= underGate { return true }
        if let fourUnder, fourUnder - fourUnderGate > 0.0001 { return true }
        if let over, over >= overGate { return true }
        return false
    }

    static func qualifies(_ store: ScheduleStore) -> Bool {
        qualifies(sales: store.sales, under: store.under, fourUnder: store.fourUnder, over: store.over)
    }

    static func includes(_ store: ScheduleStore, filters: DashboardFilters) -> Bool {
        filters.includesDivision(store.division)
            && filters.includesDistrict(store.district)
            && filters.includesOM(store.om)
            && filters.includesStore(store.store)
    }

    static func scoped(_ pack: ScheduleCheckPack, filters: DashboardFilters) -> [ScheduleStore] {
        pack.stores.filter { includes($0, filters: filters) }
    }

    static func summary(pack: ScheduleCheckPack, filters: DashboardFilters) -> ScheduleScopeSummary {
        let rows = scoped(pack, filters: filters)
        let storeUnder = average(rows.map(\.under))
        let storeOver = average(rows.map(\.over))
        let cutInside = !filters.districts.isEmpty || !filters.oms.isEmpty || !filters.stores.isEmpty
        let oneDivision = filters.divisions.count == 1 ? filters.divisions[0] : nil
        let market: ScheduleMarket?
        if !filters.isActive {
            market = pack.market(labeled: "Total")
        } else if !cutInside, let division = oneDivision {
            market = pack.market(labeled: division)
        } else {
            market = nil
        }
        let usesMarket = market != nil
        return ScheduleScopeSummary(
            under: usesMarket ? market?.under : storeUnder,
            over: usesMarket ? market?.over : storeOver,
            pch: average(rows.map(\.pch)),
            eff: average(rows.map(\.eff)),
            underCount: rows.filter { ($0.under ?? 0) > 0 }.count,
            overCount: rows.filter { ($0.over ?? 0) > 0 }.count,
            scope: rows.count,
            usesMarketLook: market != nil,
            storeUnder: storeUnder,
            storeOver: storeOver,
            actionCount: rows.filter { qualifies($0) }.count
        )
    }

    static func companyMarketNote(_ summary: ScheduleScopeSummary, filters: DashboardFilters) -> String? {
        guard summary.usesMarketLook, !filters.isActive else { return nil }
        guard let storeUnder = summary.storeUnder, let storeOver = summary.storeOver else { return nil }
        return "Market Look Total under/over. Stores Current Week average is Under \(HeartbeatFormat.pct(storeUnder)) / Over \(HeartbeatFormat.pct(storeOver))."
    }

    static func bannerMismatch(pack: ScheduleCheckPack, summary: ScheduleScopeSummary, filters: DashboardFilters) -> String? {
        guard !filters.isActive, let banner = pack.workbookActionBanner, banner != summary.actionCount else { return nil }
        return "Workbook banner said \(banner) stores. This cook qualifies \(summary.actionCount)."
    }

    static func rankedRegions(pack: ScheduleCheckPack, filters: DashboardFilters) -> [ScheduleRankRow] {
        let rows = scoped(pack, filters: filters)
        let names = Set(rows.map(\.region).filter { !$0.isEmpty })
        return names.map { name in
            rank(region: name, division: "", rows: rows.filter { $0.region == name })
        }
        .sorted(by: rankOrder)
    }

    static func rankedDivisions(pack: ScheduleCheckPack, filters: DashboardFilters) -> [ScheduleRankRow] {
        let rows = scoped(pack, filters: filters)
        let cutInside = !filters.districts.isEmpty || !filters.oms.isEmpty || !filters.stores.isEmpty
        let names = Set(rows.map(\.division).filter { !$0.isEmpty })
        return names.map { name in
            let group = rows.filter { $0.division == name }
            let market = cutInside ? nil : pack.market(labeled: name)
            let region = group.first?.region ?? ""
            return rank(region: region, division: name, rows: group, market: market)
        }
        .sorted(by: rankOrder)
    }

    static func actionGroups(pack: ScheduleCheckPack, filters: DashboardFilters) -> [ScheduleActionGroup] {
        let rows = scoped(pack, filters: filters).filter { qualifies($0) }
        let grouped = Dictionary(grouping: rows, by: \.division)
        let order = MarketRegion.officialDivisions
        let names = grouped.keys.sorted { lhs, rhs in
            let left = order.firstIndex(of: lhs) ?? order.count
            let right = order.firstIndex(of: rhs) ?? order.count
            if left != right { return left < right }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        return names.map { name in
            let stores = (grouped[name] ?? []).sorted { lhs, rhs in
                let left = lhs.under ?? -1
                let right = rhs.under ?? -1
                if left != right { return left > right }
                return HeartbeatMath.storeOrder(lhs.store, rhs.store)
            }
            return ScheduleActionGroup(division: name, region: stores.first?.region ?? "", stores: stores)
        }
    }

    static func effHealth(_ value: Double?, notScheduled: Bool) -> Health {
        if notScheduled { return .none }
        guard let value else { return .none }
        return value >= effGoal ? .good : .risk
    }

    /// 0% is green. Any over or under above that is red. Unscheduled stays gray.
    static func percentHealth(_ value: Double?, notScheduled: Bool) -> Health {
        if notScheduled { return .none }
        guard let value else { return .none }
        return value <= 0.0001 ? .good : .risk
    }

    static func assistText(pack: ScheduleCheckPack?, filters: DashboardFilters) -> String {
        let seat = filters.isActive ? filters.summary : "Total Company"
        guard let pack else {
            return [
                "Heartbeat Assist — Upcoming Weeks Schedule Check",
                seat,
                "",
                "NO DATA",
                "The Schedule Review workbook is not on this device.",
            ].joined(separator: "\n")
        }
        let card = summary(pack: pack, filters: filters)
        var lines = [
            "Heartbeat Assist — Upcoming Weeks Schedule Check",
            "\(seat) | Week \(pack.week)",
            "",
            "Under \(HeartbeatFormat.pct(card.under)) · Over \(HeartbeatFormat.pct(card.over))",
            "Pch vs Sch \(HeartbeatFormat.pct(card.pch)) · Sch Eff \(HeartbeatFormat.pct(card.eff))",
            "\(card.underCount) under · \(card.overCount) over · \(card.scope) stores in scope",
            "\(card.actionCount) stores need action. Sales at or above $30,000, and under at least 10%, or 4-week under above 9%, or over at least 15%.",
        ]
        if let note = companyMarketNote(card, filters: filters) {
            lines.append(note)
        }
        let unscheduled = scoped(pack, filters: filters).filter(\.notScheduled).count
        if unscheduled > 0 {
            lines.append("\(unscheduled) stores are not scheduled yet (Under 100% and Eff 0%). They are not graded red.")
        }
        return lines.joined(separator: "\n")
    }

    private static func average(_ values: [Double?]) -> Double? {
        let nums = values.compactMap { $0 }
        guard !nums.isEmpty else { return nil }
        return nums.reduce(0, +) / Double(nums.count)
    }

    private static func rank(region: String, division: String, rows: [ScheduleStore], market: ScheduleMarket? = nil) -> ScheduleRankRow {
        ScheduleRankRow(
            region: region,
            division: division,
            under: market == nil ? average(rows.map(\.under)) : market?.under,
            over: market == nil ? average(rows.map(\.over)) : market?.over,
            pch: average(rows.map(\.pch)),
            eff: average(rows.map(\.eff)),
            underCount: rows.filter { ($0.under ?? 0) > 0 }.count,
            overCount: rows.filter { ($0.over ?? 0) > 0 }.count,
            scope: rows.count
        )
    }

    private static func rankOrder(_ lhs: ScheduleRankRow, _ rhs: ScheduleRankRow) -> Bool {
        switch (lhs.eff, rhs.eff) {
        case let (left?, right?) where left != right:
            return left < right
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        default:
            let left = lhs.division.isEmpty ? lhs.region : lhs.division
            let right = rhs.division.isEmpty ? rhs.region : rhs.division
            return left.localizedStandardCompare(right) == .orderedAscending
        }
    }
}
