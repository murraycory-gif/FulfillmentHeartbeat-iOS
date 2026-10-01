import Foundation

/// Schedule Check math for the Week 31 review.
/// Percents are the pack scale (0–100). Missing fields stay nil — never filled from another report.
enum ScheduleCheckDay: Int, CaseIterable, Identifiable {
    case sun = 0, mon, tue, wed, thu, fri, sat

    var id: Int { rawValue }

    var token: String {
        switch self {
        case .sun: return "sun"
        case .mon: return "mon"
        case .tue: return "tue"
        case .wed: return "wed"
        case .thu: return "thu"
        case .fri: return "fri"
        case .sat: return "sat"
        }
    }

    var short: String {
        switch self {
        case .sun: return "Su"
        case .mon: return "Mo"
        case .tue: return "Tu"
        case .wed: return "We"
        case .thu: return "Th"
        case .fri: return "Fr"
        case .sat: return "Sa"
        }
    }

    var underKey: String { "sched_\(token)_under" }
    var overKey: String { "sched_\(token)_over" }
}

struct ScheduleCheckStore: Equatable, Identifiable {
    var region: String
    var division: String
    var district: String
    var om: String
    var store: String
    var avgSales: Double?
    var underPct: Double?
    var overPct: Double?
    var fourWeekUnder: Double?
    var fourWeekOver: Double?
    var efficiency: Double?
    var pchVsSch: Double?
    var star5: Double?
    var dayUnder: [Double?]
    var dayOver: [Double?]

    var id: String { store }

    init(
        region: String = "",
        division: String = "",
        district: String = "",
        om: String = "",
        store: String,
        avgSales: Double? = nil,
        underPct: Double? = nil,
        overPct: Double? = nil,
        fourWeekUnder: Double? = nil,
        fourWeekOver: Double? = nil,
        efficiency: Double? = nil,
        pchVsSch: Double? = nil,
        star5: Double? = nil,
        dayUnder: [Double?]? = nil,
        dayOver: [Double?]? = nil
    ) {
        self.region = region
        self.division = division
        self.district = district
        self.om = om
        self.store = store
        self.avgSales = avgSales
        self.underPct = underPct
        self.overPct = overPct
        self.fourWeekUnder = fourWeekUnder
        self.fourWeekOver = fourWeekOver
        self.efficiency = efficiency
        self.pchVsSch = pchVsSch
        self.star5 = star5
        self.dayUnder = Self.fit(dayUnder)
        self.dayOver = Self.fit(dayOver)
    }

    var hasPackMetric: Bool {
        avgSales != nil || underPct != nil || overPct != nil || fourWeekUnder != nil || fourWeekOver != nil
            || efficiency != nil || pchVsSch != nil || star5 != nil
            || dayUnder.contains(where: { $0 != nil }) || dayOver.contains(where: { $0 != nil })
    }

    private static func fit(_ values: [Double?]?) -> [Double?] {
        var next = values ?? []
        if next.count > 7 { next = Array(next.prefix(7)) }
        while next.count < 7 { next.append(nil) }
        return next
    }
}

struct ScheduleCheckRollup: Equatable, Identifiable {
    var label: String
    var under: Double?
    var over: Double?
    var pch: Double?
    var efficiency: Double?
    var underStores: Int
    var overStores: Int
    var scope: Int

    var id: String { label }
}

enum ScheduleCheckMath {
    static let salesGate = 30_000.0
    static let underGate = 10.0
    static let fourWeekUnderGate = 9.0
    static let overGate = 15.0

    /// Average sales ≥ $30K AND (under ≥ 10% OR 4-week under > 9% OR over ≥ 15%).
    /// A missing sales figure fails the gate. A missing schedule leg does not invent a hit.
    static func isAction(_ store: ScheduleCheckStore) -> Bool {
        guard let sales = store.avgSales, sales >= salesGate else { return false }
        let underHit = (store.underPct ?? -.infinity) >= underGate
        let fourHit = (store.fourWeekUnder ?? -.infinity) > fourWeekUnderGate
        let overHit = (store.overPct ?? -.infinity) >= overGate
        return underHit || fourHit || overHit
    }

    /// Over schedule and day over: 0% green, anything above 0% red.
    static func overHeat(_ value: Double?) -> Health {
        guard let value else { return .none }
        return value > 0 ? .risk : .good
    }

    static func underHeat(_ value: Double?) -> Health {
        guard let value else { return .none }
        if value >= underGate { return .risk }
        if value > 0 { return .watch }
        return .good
    }

    static func fourWeekUnderHeat(_ value: Double?) -> Health {
        guard let value else { return .none }
        if value > fourWeekUnderGate { return .risk }
        if value > 0 { return .watch }
        return .good
    }

    static func scopedStores(
        from rows: [MetricRow],
        identity: (String) -> HeartbeatMath.StoreIdentity = { _ in
            HeartbeatMath.StoreIdentity(division: "", district: "", om: "", name: nil)
        }
    ) -> [ScheduleCheckStore] {
        var seen = Set<String>()
        var out: [ScheduleCheckStore] = []
        out.reserveCapacity(rows.count)
        for row in rows {
            let number = HeartbeatMath.canonicalStore(row.storeNumber)
            guard !number.isEmpty, Int(number) != nil, seen.insert(number).inserted else { continue }
            if HeartbeatMath.isIgnoredStore(number) { continue }
            let built = make(row, number: number, identity: identity(number))
            guard built.hasPackMetric else { continue }
            out.append(built)
        }
        return out
    }

    static func company(_ stores: [ScheduleCheckStore]) -> ScheduleCheckRollup {
        rollup("Total Company", stores)
    }

    static func regions(_ stores: [ScheduleCheckStore]) -> [ScheduleCheckRollup] {
        let order = MarketRegion.allCases.map(\.rawValue) + ["Unassigned"]
        return grouped(stores, key: \.region, order: order)
    }

    static func divisions(_ stores: [ScheduleCheckStore]) -> [ScheduleCheckRollup] {
        grouped(stores, key: { $0.division.isEmpty ? "Unassigned" : $0.division })
            .sorted { lhs, rhs in
                let left = lhs.under ?? -1
                let right = rhs.under ?? -1
                if left == right { return lhs.label.localizedStandardCompare(rhs.label) == .orderedAscending }
                return left > right
            }
    }

    static func missingSections(_ stores: [ScheduleCheckStore]) -> [String] {
        let checks: [(String, (ScheduleCheckStore) -> Bool)] = [
            ("Stores Current Week — Under, Over, and Schedule Efficiency", { $0.underPct != nil || $0.overPct != nil || $0.efficiency != nil }),
            ("Sales AVG Last 4 Wks — Average Sales Volume", { $0.avgSales != nil }),
            ("Last 4 Week Quality — 4 Wk Avg Under and Over", { $0.fourWeekUnder != nil || $0.fourWeekOver != nil }),
            ("Last 4 Week Quality col J — Pch Vs Sch", { $0.pchVsSch != nil }),
            ("Sunday–Saturday — day Under % and Over %", { $0.dayUnder.contains { $0 != nil } || $0.dayOver.contains { $0 != nil } }),
            ("5 Star Last 5 Weeks — Last 5 Wk Star Rating", { $0.star5 != nil }),
        ]
        return checks.compactMap { title, present in
            stores.contains(where: present) ? nil : title
        }
    }

    private static func make(_ row: MetricRow, number: String, identity: HeartbeatMath.StoreIdentity) -> ScheduleCheckStore {
        let divisionSource = row.division.isEmpty ? identity.division : row.division
        let division = MarketRegion.canonicalName(divisionSource)
        let district = row.district.isEmpty ? identity.district : row.district
        let om = row.operationsOM.isEmpty ? identity.om : row.operationsOM
        let region = MarketRegion.containing(division)?.rawValue ?? "Unassigned"
        return ScheduleCheckStore(
            region: region,
            division: division.isEmpty ? (divisionSource.isEmpty ? "Unassigned" : divisionSource) : division,
            district: district,
            om: om,
            store: number,
            avgSales: row.number("sched_avg_sales"),
            underPct: row.number("sched_under", "under_schedule_pct", "under_scheduled"),
            overPct: row.number("sched_over", "over_schedule_pct", "over_scheduled"),
            fourWeekUnder: row.number("sched_4wk_under"),
            fourWeekOver: row.number("sched_4wk_over"),
            efficiency: row.number("sched_eff", "schedule_efficiency_pct"),
            pchVsSch: row.number("sched_pch_vs_sch", "staffing_efficiency_pct"),
            star5: row.number("sched_star_5wk"),
            dayUnder: ScheduleCheckDay.allCases.map { row.number($0.underKey) },
            dayOver: ScheduleCheckDay.allCases.map { row.number($0.overKey) }
        )
    }

    private static func rollup(_ label: String, _ stores: [ScheduleCheckStore]) -> ScheduleCheckRollup {
        ScheduleCheckRollup(
            label: label,
            under: average(stores.compactMap(\.underPct)),
            over: average(stores.compactMap(\.overPct)),
            pch: average(stores.compactMap(\.pchVsSch)),
            efficiency: average(stores.compactMap(\.efficiency)),
            underStores: stores.filter { ($0.underPct ?? 0) > 0 }.count,
            overStores: stores.filter { ($0.overPct ?? 0) > 0 }.count,
            scope: stores.count
        )
    }

    private static func grouped(
        _ stores: [ScheduleCheckStore],
        key: (ScheduleCheckStore) -> String,
        order: [String]? = nil
    ) -> [ScheduleCheckRollup] {
        var buckets: [String: [ScheduleCheckStore]] = [:]
        for store in stores {
            let name = key(store)
            guard !name.isEmpty else { continue }
            buckets[name, default: []].append(store)
        }
        let labels: [String]
        if let order {
            let extra = buckets.keys.filter { !order.contains($0) }.sorted()
            labels = order.filter { buckets[$0] != nil } + extra
        } else {
            labels = buckets.keys.sorted()
        }
        return labels.map { rollup($0, buckets[$0] ?? []) }
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
