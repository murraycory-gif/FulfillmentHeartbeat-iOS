import SwiftUI

struct OverviewSalesBlock: View {
    @EnvironmentObject private var store: HeartbeatStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var phone: Bool { HubLayout.isPhone(sizeClass) }

    var body: some View {
        let stores = store.salesStores()
        let total = SalesPack(rows: stores)
        let mid = midRows(from: stores)
        let days = SalesRollupBuilder.dayRows(
            from: stores,
            company: store.filters.isActive ? nil : store.salesCompanyFact()
        )
        VStack(alignment: .leading, spacing: 16) {
            overviewTable(title: scopeTitle, rows: [
                SalesRollupRow(label: scopeTitle, storeCount: Set(stores.map(\.storeNumber)).count, pack: total)
            ], showCount: true)
            if !mid.rows.isEmpty {
                overviewTable(title: mid.title, rows: mid.rows, showCount: mid.showCount)
            }
            if !days.isEmpty {
                overviewTable(title: "By Day", rows: days, showCount: false)
            }
        }
        .padding(.horizontal, phone ? 10 : 14)
        .padding(.top, phone ? 10 : 12)
        .padding(.bottom, phone ? 12 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.tableFill)
    }

    private var scopeTitle: String {
        let filters = store.filters
        if !filters.store.isEmpty { return "Store \(filters.store)" }
        if !filters.om.isEmpty { return filters.om }
        if !filters.district.isEmpty { return filters.district }
        if !filters.division.isEmpty { return filters.division }
        if !filters.region.isEmpty { return filters.region }
        return "Total Company"
    }

    private func midRows(from stores: [MetricRow]) -> (title: String, rows: [SalesRollupRow], showCount: Bool) {
        let filters = store.filters
        if !filters.store.isEmpty {
            return ("Stores", [], false)
        }
        if !filters.district.isEmpty || !filters.om.isEmpty {
            let rows = SalesRollupBuilder.rows(from: stores, grain: .store)
            return ("By Store", rows, false)
        }
        if !filters.division.isEmpty {
            return ("By District", SalesRollupBuilder.rows(from: stores, grain: .district), true)
        }
        if !filters.region.isEmpty {
            return ("By Market", SalesRollupBuilder.rows(from: stores, grain: .division), true)
        }
        return ("By Region", regionRows(from: stores), true)
    }

    private func regionRows(from stores: [MetricRow]) -> [SalesRollupRow] {
        MarketRegion.allCases.compactMap { region in
            let slice = stores.filter { region.contains($0.division) }
            guard !slice.isEmpty else { return nil }
            let pack = SalesPack(rows: slice)
            guard pack.sales != nil || pack.orders != nil else { return nil }
            return SalesRollupRow(label: region.rawValue, storeCount: Set(slice.map(\.storeNumber)).count, pack: pack)
        }
    }

    private func overviewTable(title: String, rows: [SalesRollupRow], showCount: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTheme.rounded(.title3, weight: .bold))
                .foregroundStyle(AppTheme.text)
            if phone {
                VStack(spacing: 8) {
                    ForEach(rows) { row in
                        OverviewSalesPhoneCard(label: row.label, count: showCount ? row.storeCount : nil, pack: row.pack)
                    }
                }
            } else {
                OverviewSalesAlignedTable(title: title, rows: rows, showCount: showCount)
            }
        }
    }
}

private enum OverviewCols {
    static let gap: CGFloat = 10
    static let label: CGFloat = 168
    static let count: CGFloat = 64
    static let sales: CGFloat = 132
    static let yoy: CGFloat = 78
    static let orders: CGFloat = 92
    static let ordersYoy: CGFloat = 78
    static let aos: CGFloat = 78
    static let aiv: CGFloat = 56
    static let ipt: CGFloat = 72
    static let items: CGFloat = 96
    static let status: CGFloat = 92
}

struct OverviewSalesAlignedTable: View {
    let title: String
    let rows: [SalesRollupRow]
    var showCount: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.hubTableWidth) private var tableWidth

    private var phone: Bool { HubLayout.isPhone(sizeClass) }
    private var valueWidth: CGFloat {
        HubLayout.evenValueWidth(available: tableWidth, phone: phone, columns: 8, showCount: showCount)
    }

    var body: some View {
        HubAdaptiveHScroll(minWidth: HubLayout.readableTableFloor(phone: phone, columns: 8, showCount: showCount)) {
            VStack(alignment: .leading, spacing: 0) {
                row(
                    label: title == "By Day" ? "Day" : "Scope",
                    stores: "Stores",
                    values: ["Sales $", "YoY %", "Orders", "Ord YoY", "AOS", "AIV", "Items/Txn", "Items"],
                    status: "Status",
                    health: nil,
                    header: true
                )
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                    row(
                        label: item.label,
                        stores: HeartbeatFormat.num(Double(item.storeCount)),
                        values: [
                            HeartbeatFormat.money(item.pack.sales),
                            HeartbeatFormat.pct(item.pack.yoy),
                            HeartbeatFormat.num(item.pack.orders, digits: 0),
                            HeartbeatFormat.pct(item.pack.ordersYoy),
                            HeartbeatFormat.money(item.pack.aos),
                            HeartbeatFormat.num(item.pack.aiv, digits: 2),
                            HeartbeatFormat.num(item.pack.ipt, digits: 1),
                            HeartbeatFormat.num(item.pack.items, digits: 0)
                        ],
                        status: nil,
                        health: item.pack.health == .none && (item.pack.sales ?? 0) > 0 ? .good : item.pack.health,
                        header: false,
                        yoyRisk: (item.pack.yoy ?? 0) < 0,
                        stripe: index.isMultiple(of: 2)
                    )
                }
            }
        }
    }

    private func row(
        label: String,
        stores: String,
        values: [String],
        status: String?,
        health: Health?,
        header: Bool,
        yoyRisk: Bool = false,
        stripe: Bool = false
    ) -> some View {
        HStack(spacing: 6) {
            Text(header ? label.uppercased() : label)
                .font(AppTheme.rounded(header ? .caption2 : .subheadline, weight: header ? .bold : .semibold))
                .foregroundStyle(header ? AppTheme.textSecondary : AppTheme.text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: HubLayout.readableLabelWidth(phone: phone), alignment: .leading)
            if showCount {
                cell(stores, header: header, secondary: true)
            }
            ForEach(Array(values.enumerated()), id: \.offset) { index, text in
                cell(
                    text,
                    header: header,
                    tone: header ? nil : tone(index: index, yoyRisk: yoyRisk, health: health)
                )
            }
            Group {
                if header {
                    Text(status ?? "STATUS")
                        .font(AppTheme.rounded(.caption2, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: true, vertical: false)
                } else if let health {
                    HealthBadge(health: health, prominent: true, compact: true)
                }
            }
            .frame(width: HubLayout.readableStatusWidth(phone: phone), alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, header ? 6 : 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(stripe ? AppTheme.blueSoft.opacity(0.35) : Color.clear)
    }

    private func cell(_ text: String, header: Bool, secondary: Bool = false, tone: Health? = nil) -> some View {
        Text(header ? text.uppercased() : text)
            .font(AppTheme.rounded(header ? .caption2 : .subheadline, weight: header ? .bold : .bold).monospacedDigit())
            .foregroundStyle(header ? AppTheme.textSecondary : ink(tone, secondary: secondary))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(minWidth: valueWidth, maxWidth: .infinity, alignment: .trailing)
    }

    private func tone(index: Int, yoyRisk: Bool, health: Health?) -> Health? {
        if index == 0 || index == 1 { return yoyRisk ? .risk : health }
        return nil
    }

    private func ink(_ health: Health?, secondary: Bool) -> Color {
        if secondary { return AppTheme.textSecondary }
        switch health {
        case .good: return AppTheme.ok
        case .watch: return AppTheme.warn
        case .risk: return AppTheme.bad
        default: return AppTheme.text
        }
    }
}

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

struct OverviewSalesPhoneCard: View {
    let label: String
    var count: Int? = nil
    let pack: SalesPack

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(AppTheme.rounded(.subheadline, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                if let count {
                    Text("\(count) stores")
                        .font(AppTheme.rounded(.caption, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                HealthBadge(health: pack.health == .none && (pack.sales ?? 0) > 0 ? .good : pack.health, prominent: true, compact: true)
            }
            HStack {
                phoneMetric("Sales $", HeartbeatFormat.money(pack.sales))
                phoneMetric("YoY", HeartbeatFormat.pct(pack.yoy))
            }
            HStack {
                phoneMetric("Orders", HeartbeatFormat.num(pack.orders, digits: 0))
                phoneMetric("Ord YoY", HeartbeatFormat.pct(pack.ordersYoy))
            }
            HStack {
                phoneMetric("AOS", HeartbeatFormat.money(pack.aos))
                phoneMetric("AIV", HeartbeatFormat.num(pack.aiv, digits: 2))
            }
            HStack {
                phoneMetric("Items/Txn", HeartbeatFormat.num(pack.ipt, digits: 1))
                phoneMetric("Items", HeartbeatFormat.num(pack.items, digits: 0))
            }
        }
        .tableRowCard(health: pack.health)
    }

    private func phoneMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(AppTheme.rounded(.caption2, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(AppTheme.rounded(.subheadline, weight: .bold))
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SalesRollupRow: Identifiable {
    var id: String { label }
    let label: String
    let storeCount: Int
    let pack: SalesPack
}

enum SalesRollupBuilder {
    static func grain(for filters: DashboardFilters) -> LaborRollupGrain? {
        RollupMarketFill.grain(for: filters)
    }

    static func source(from rows: [MetricRow], filters: DashboardFilters, roster: [String: HeartbeatMath.StoreIdentity] = [:]) -> [MetricRow] {
        let raw = rows.filter {
            $0.textPayload["sales_grain"] != "day"
                && $0.textPayload["sales_grain"] != "company"
                && !$0.storeNumber.isEmpty
                && $0.storeNumber.caseInsensitiveCompare("total") != .orderedSame
        }
        let stores = roster.isEmpty ? raw : HeartbeatMath.applyRoster(raw, roster: roster)
        if !filters.isActive {
            var seen: Set<String> = []
            return stores.filter { seen.insert(HeartbeatMath.canonicalStore($0.storeNumber)).inserted }
        }
        if !filters.store.isEmpty {
            let matched = stores.filter { filters.includesStore($0.storeNumber) }
            if !matched.isEmpty { return matched }
        }
        if !roster.isEmpty {
            let allowed = Set(roster.compactMap { number, identity -> String? in
                if !filters.includesDivision(identity.division) { return nil }
                if !filters.includesDistrict(identity.district) { return nil }
                if !filters.includesOM(identity.om) { return nil }
                if !filters.includesStore(number) { return nil }
                return HeartbeatMath.canonicalStore(number)
            })
            var seen: Set<String> = []
            var out: [MetricRow] = []
            for row in stores {
                let store = HeartbeatMath.canonicalStore(row.storeNumber)
                guard allowed.contains(store), seen.insert(store).inserted else { continue }
                out.append(row)
            }
            return out
        }
        return RollupMarketFill.scoped(stores, filters: filters)
    }

    static func rows(from stores: [MetricRow], grain: LaborRollupGrain) -> [SalesRollupRow] {
        var buckets: [String: [MetricRow]] = [:]
        for row in stores {
            let key: String
            switch grain {
            case .region:
                key = RollupMarketFill.bucketKey(row, grain: .region)
                if key == "Unassigned" { continue }
            case .division:
                key = RollupMarketFill.divisionKey(row.division)
                if key == "Unassigned" { continue }
            case .district:
                key = RollupMarketFill.districtKey(row.district)
                if key == "Unassigned" { continue }
            case .store:
                key = HeartbeatMath.canonicalStore(row.storeNumber)
            }
            guard !key.isEmpty, HeartbeatMath.salesHeadlineDollars(row) > 0 || HeartbeatMath.salesOrders(row) > 0 else { continue }
            buckets[key, default: []].append(row)
        }
        return buckets.keys.sorted().compactMap { key in
            if key == "Unassigned" { return nil }
            let packRows = buckets[key] ?? []
            let pack = SalesPack(rows: packRows)
            guard pack.sales != nil || pack.orders != nil else { return nil }
            return SalesRollupRow(label: key, storeCount: Set(packRows.map(\.storeNumber)).count, pack: pack)
        }
    }

    static func dayRows(from stores: [MetricRow], company: MetricRow? = nil) -> [SalesRollupRow] {
        let week = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        var seen = Set<String>()
        var unique: [MetricRow] = []
        for store in stores {
            let key = HeartbeatMath.canonicalStore(store.storeNumber)
            if key.isEmpty || key == "TOTAL" { continue }
            if store.textPayload["sales_grain"] == "company" { continue }
            guard seen.insert(key).inserted else { continue }
            unique.append(store)
        }
        let storeCount = unique.count
        if let company {
            let locked = week.enumerated().compactMap { index, name -> SalesRollupRow? in
                let pack = SalesPack(company, prefix: "sales_d\(index)_")
                guard (pack.sales ?? 0) > 0 || (pack.orders ?? 0) > 0 else { return nil }
                return SalesRollupRow(label: name, storeCount: storeCount, pack: pack)
            }
            if !locked.isEmpty { return locked }
        }
        var sales = Array(repeating: 0.0, count: 7)
        var orders = Array(repeating: 0.0, count: 7)
        var items = Array(repeating: 0.0, count: 7)
        var lastSales = Array(repeating: 0.0, count: 7)
        var lastOrders = Array(repeating: 0.0, count: 7)
        for store in unique {
            for index in 0..<7 {
                let prefix = "sales_d\(index)_"
                let daySales = store.number(prefix + "dollars") ?? 0
                let dayOrders = store.number(prefix + "orders") ?? 0
                sales[index] += daySales
                orders[index] += dayOrders
                items[index] += store.number(prefix + "items") ?? 0
                if let last = HeartbeatMath.salesPriorFromYoY(current: daySales, yoyPct: store.number(prefix + "yoy_pct")) {
                    lastSales[index] += last
                }
                if let last = HeartbeatMath.salesPriorFromYoY(current: dayOrders, yoyPct: store.number(prefix + "orders_yoy_pct")) {
                    lastOrders[index] += last
                }
            }
        }
        return week.enumerated().compactMap { index, name in
            let daySales = sales[index]
            if daySales <= 0, orders[index] <= 0 { return nil }
            let dayOrders = orders[index]
            let dayItems = items[index]
            let yoy: Double? = lastSales[index] > 0 ? (daySales / lastSales[index] - 1) * 100 : nil
            let ordYoy: Double? = lastOrders[index] > 0 ? (dayOrders / lastOrders[index] - 1) * 100 : nil
            return SalesRollupRow(
                label: name,
                storeCount: storeCount,
                pack: SalesPack(
                    sales: daySales,
                    yoy: yoy,
                    orders: dayOrders,
                    ordersYoy: ordYoy,
                    aos: dayOrders > 0 ? daySales / dayOrders : nil,
                    aiv: dayItems > 0 ? daySales / dayItems : nil,
                    items: dayItems,
                    ipt: dayOrders > 0 ? dayItems / dayOrders : nil,
                    hd: nil,
                    dug: nil,
                    health: HeartbeatMath.salesHealth(planPct: nil, yoy: yoy)
                )
            )
        }
    }

    static func dayPacks(from row: MetricRow) -> [(name: String, pack: SalesPack)] {
        let week = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return week.enumerated().compactMap { index, name -> (name: String, pack: SalesPack)? in
            let pack = SalesPack(row, prefix: "sales_d\(index)_")
            guard (pack.sales ?? 0) > 0 || (pack.orders ?? 0) > 0 else { return nil }
            return (name, pack)
        }
    }

    static func dashboardRows(from stores: [MetricRow], grain: DashScopeGrain) -> [SalesRollupRow] {
        switch grain {
        case .region:
            var buckets: [String: [MetricRow]] = [:]
            for store in stores {
                guard let region = MarketRegion.containing(store.division) else { continue }
                buckets[region.rawValue, default: []].append(store)
            }
            return MarketRegion.allCases.compactMap { region in
                let slice = buckets[region.rawValue] ?? []
                guard !slice.isEmpty else { return nil }
                let pack = SalesPack(rows: slice)
                guard pack.sales != nil || pack.orders != nil else { return nil }
                return SalesRollupRow(label: region.rawValue, storeCount: Set(slice.map(\.storeNumber)).count, pack: pack)
            }
        case .division:
            return rows(from: stores, grain: .division)
        case .district:
            return rows(from: stores, grain: .district)
        case .store:
            return rows(from: stores, grain: .store)
        }
    }
}

private enum SalesCols {
    static let label: CGFloat = 200
    static let count: CGFloat = 64
    static let sales: CGFloat = 128
    static let yoy: CGFloat = 80
    static let orders: CGFloat = 80
    static let ordersYoy: CGFloat = 80
    static let aos: CGFloat = 84
    static let aiv: CGFloat = 60
    static let ipt: CGFloat = 76
    static let items: CGFloat = 96
    static let status: CGFloat = 92
}

struct SalesMetricHeader: View {
    let label: String
    var showCount: Bool = false
    var active: String? = nil
    var ascending: Bool = false
    var onSelect: ((String) -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            head(label, key: "label", alignment: .leading)
                .frame(width: SalesCols.label, alignment: .leading)
            if showCount {
                head("Stores", key: "count", alignment: .trailing)
                    .frame(width: SalesCols.count, alignment: .trailing)
            }
            head("Sales $", key: "sales").frame(width: SalesCols.sales, alignment: .trailing)
            head("YoY %", key: "yoy").frame(width: SalesCols.yoy, alignment: .trailing)
            head("Orders", key: "orders").frame(width: SalesCols.orders, alignment: .trailing)
            head("Ord YoY", key: "ordersYoy").frame(width: SalesCols.ordersYoy, alignment: .trailing)
            head("AOS", key: "aos").frame(width: SalesCols.aos, alignment: .trailing)
            head("AIV", key: "aiv").frame(width: SalesCols.aiv, alignment: .trailing)
            head("Items/Txn", key: "ipt").frame(width: SalesCols.ipt, alignment: .trailing)
            head("Items", key: "items").frame(width: SalesCols.items, alignment: .trailing)
            head("Status", key: "status", alignment: .trailing)
                .frame(width: SalesCols.status, alignment: .trailing)
        }
        .font(.caption.weight(.bold))
        .tracking(0.3)
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }

    private func head(_ title: String, key: String, alignment: Alignment = .trailing) -> some View {
        let selected = active == key
        let content = HStack(spacing: 3) {
            Text(title.uppercased())
            if selected {
                Image(systemName: ascending ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.bold))
            }
        }
        .foregroundStyle(selected ? AppTheme.blue : AppTheme.text)
        .frame(maxWidth: .infinity, alignment: alignment)
        .contentShape(Rectangle())
        return Group {
            if let onSelect {
                Button { onSelect(key) } label: { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
    }
}

private struct SalesMetricLine: View {
    let label: String
    var count: Int? = nil
    let pack: SalesPack
    var showsChevron: Bool = false
    var expanded: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                if showsChevron {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 12)
                }
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(width: SalesCols.label, alignment: .leading)
            if let count {
                Text(HeartbeatFormat.num(Double(count)))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: SalesCols.count, alignment: .trailing)
            }
            cell(HeartbeatFormat.money(pack.sales), pack.health, width: SalesCols.sales)
            cell(HeartbeatFormat.pct(pack.yoy), pack.health, width: SalesCols.yoy)
            cell(HeartbeatFormat.num(pack.orders, digits: 0), .none, width: SalesCols.orders)
            cell(HeartbeatFormat.pct(pack.ordersYoy), .none, width: SalesCols.ordersYoy)
            cell(HeartbeatFormat.money(pack.aos), .none, brand: true, width: SalesCols.aos)
            cell(HeartbeatFormat.num(pack.aiv, digits: 2), .none, width: SalesCols.aiv)
            cell(HeartbeatFormat.num(pack.ipt, digits: 1), .none, width: SalesCols.ipt)
            cell(HeartbeatFormat.num(pack.items, digits: 0), .none, width: SalesCols.items)
            HealthBadge(health: pack.health == .none && (pack.sales ?? 0) > 0 ? .good : pack.health, prominent: true, compact: true)
                .frame(width: SalesCols.status, alignment: .trailing)
        }
        .tableRowCard(health: pack.health)
    }

    private func cell(_ value: String, _ health: Health, brand: Bool = false, width: CGFloat) -> some View {
        Text(value)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(brand ? AppTheme.blue : ink(health))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: width, alignment: .trailing)
    }

    private func ink(_ health: Health) -> Color {
        switch health {
        case .good: return AppTheme.ok
        case .watch: return AppTheme.warn
        case .risk: return AppTheme.bad
        case .none: return AppTheme.text
        }
    }

    private func wash(_ health: Health) -> Color {
        switch health {
        case .good: return AppTheme.okSoft
        case .watch: return AppTheme.warnSoft
        case .risk: return AppTheme.badSoft
        case .none: return Color.clear
        }
    }
}

struct SalesRollupTable: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var headerPin: LaborHeaderPin
    @State private var grain: LaborRollupGrain? = .division
    @State private var summary: [SalesRollupRow] = []
    @State private var sortKey = "yoy"
    @State private var sortAscending = false

    private var expanded: Bool { headerPin.rollupExpanded }

    var body: some View {
        Group {
            if let grain {
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        headerPin.rollupExpanded.toggle()
                    } label: {
                        HubTableHeader(
                            icon: grain.symbol,
                            title: grain.title,
                            accessory: "\(summary.count) \(grain.columnTitle.lowercased())\(summary.count == 1 ? "" : "s")  ·  tap to \(expanded ? "collapse" : "expand")",
                            expanded: expanded
                        )
                    }
                    .buttonStyle(.plain)
                    if expanded {
                        HubAdaptiveHScroll {
                            VStack(alignment: .leading, spacing: 10) {
                                SalesMetricHeader(
                                    label: grain.columnTitle,
                                    showCount: grain != .store,
                                    active: sortKey,
                                    ascending: sortAscending,
                                    onSelect: applySort
                                )
                                ForEach(summary) { row in
                                    SalesMetricLine(
                                        label: row.label,
                                        count: grain == .store ? nil : row.storeCount,
                                        pack: row.pack
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 14)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
                .hubScorecardChrome()
            }
        }
        .onAppear(perform: rebuild)
        .onChange(of: store.filterStamp) { _, _ in rebuild() }
    }

    private func applySort(_ key: String) {
        if sortKey == key { sortAscending.toggle() } else { sortKey = key; sortAscending = key == "label" }
        rebuild()
    }

    private func rebuild() {
        let next = SalesRollupBuilder.grain(for: store.filters)
        grain = next
        guard let next else { summary = []; return }
        var rows = SalesRollupBuilder.rows(from: store.rollupStores(for: .sales), grain: next)
        rows.sort { lhs, rhs in
            let result: ComparisonResult
            switch sortKey {
            case "label": result = RollupColumnSort.label(lhs.label, rhs.label)
            case "count": result = RollupColumnSort.count(lhs.storeCount, rhs.storeCount)
            case "orders": result = RollupColumnSort.number(lhs.pack.orders, rhs.pack.orders)
            case "ordersYoy": result = RollupColumnSort.number(lhs.pack.ordersYoy, rhs.pack.ordersYoy)
            case "aos": result = RollupColumnSort.number(lhs.pack.aos, rhs.pack.aos)
            case "aiv": result = RollupColumnSort.number(lhs.pack.aiv, rhs.pack.aiv)
            case "ipt": result = RollupColumnSort.number(lhs.pack.ipt, rhs.pack.ipt)
            case "items": result = RollupColumnSort.number(lhs.pack.items, rhs.pack.items)
            case "status", "yoy": result = RollupColumnSort.number(lhs.pack.yoy, rhs.pack.yoy)
            default: result = RollupColumnSort.number(lhs.pack.sales, rhs.pack.sales)
            }
            return RollupColumnSort.ordered(result, ascending: sortAscending)
        }
        summary = rows
    }
}

private struct SalesLineSnap: Identifiable {
    let id: String
    let storeNumber: String
    let label: String
    let pack: SalesPack
    let days: [(name: String, pack: SalesPack)]

    init(_ row: MetricRow, identity: HeartbeatMath.StoreIdentity? = nil) {
        storeNumber = row.storeNumber
        id = row.storeNumber
        label = HeartbeatMath.storeDisplayLabel(row, identity: identity)
        pack = SalesPack(row)
        days = SalesRollupBuilder.dayPacks(from: row)
    }
}

struct SalesTable: View {
    @EnvironmentObject private var headerPin: LaborHeaderPin
    @EnvironmentObject private var store: HeartbeatStore
    let rows: [MetricRow]
    @State private var sortKey = "yoy"
    @State private var sortAscending = true
    @State private var snaps: [SalesLineSnap] = []
    @State private var openStore: String?
    @State private var limit = 50
    @State private var orderedCount = 0

    private var expanded: Bool { headerPin.storesExpanded }

    var body: some View {
        if rows.isEmpty {
            Section {
                EmptyHint(
                    symbol: "cart.fill",
                    title: "No stores in this view",
                    detail: "Sales fill from the Heartbeat pack after ready. Pick another filter if this slice is empty."
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
        } else {
            Section {
                HubStoreCard(count: rows.count, expanded: expanded) {
                    let next = !headerPin.storesExpanded
                    headerPin.storesExpanded = next
                    headerPin.tableOpen = next
                    if !next { headerPin.pinned = false }
                    if next { rebuild() }
                } content: {
                    HubAdaptiveHScroll {
                        VStack(spacing: 0) {
                            SalesMetricHeader(
                                label: "Store",
                                showCount: false,
                                active: sortKey,
                                ascending: sortAscending,
                                onSelect: applySort
                            )
                            ForEach(Array(snaps.prefix(limit))) { snap in
                                let open = openStore == snap.storeNumber
                                Button {
                                    openStore = open ? nil : snap.storeNumber
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        SalesMetricLine(
                                            label: snap.label,
                                            pack: snap.pack,
                                            showsChevron: !snap.days.isEmpty,
                                            expanded: open
                                        )
                                        if open {
                                            ForEach(Array(snap.days.enumerated()), id: \.offset) { _, day in
                                                SalesMetricLine(label: day.name, pack: day.pack)
                                                    .padding(.leading, 18)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 5)
                            }
                            if orderedCount > snaps.prefix(limit).count {
                                Button {
                                    limit += 50
                                    rebuild()
                                } label: {
                                    Text("Show more · \(HeartbeatFormat.num(Double(min(limit, orderedCount)))) of \(HeartbeatFormat.num(Double(orderedCount)))")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.blue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
                .onAppear {
                    headerPin.tableOpen = headerPin.storesExpanded
                    headerPin.storeCount = rows.count
                    headerPin.active = sortKey
                    headerPin.ascending = sortAscending
                    headerPin.onSelect = applySort
                    rebuild()
                }
                .onChange(of: store.filterStamp) { _, _ in rebuild() }
                .onChange(of: rows.count) { _, _ in rebuild() }
            }
            .transaction { $0.animation = nil }
        }
    }

    private func applySort(_ key: String) {
        if sortKey == key { sortAscending.toggle() } else { sortKey = key; sortAscending = key == "label" || key == "yoy" }
        headerPin.active = sortKey
        headerPin.ascending = sortAscending
        rebuild()
    }

    private func rebuild() {
        var next = rows.compactMap { row -> SalesLineSnap? in
            let snap = SalesLineSnap(row, identity: store.identity(forStore: row.storeNumber))
            guard snap.pack.sales != nil || snap.pack.orders != nil else { return nil }
            return snap
        }
        next.sort { lhs, rhs in
            let result: ComparisonResult
            switch sortKey {
            case "label": result = RollupColumnSort.label(lhs.label, rhs.label)
            case "orders": result = RollupColumnSort.number(lhs.pack.orders, rhs.pack.orders)
            case "ordersYoy": result = RollupColumnSort.number(lhs.pack.ordersYoy, rhs.pack.ordersYoy)
            case "aos": result = RollupColumnSort.number(lhs.pack.aos, rhs.pack.aos)
            case "aiv": result = RollupColumnSort.number(lhs.pack.aiv, rhs.pack.aiv)
            case "ipt": result = RollupColumnSort.number(lhs.pack.ipt, rhs.pack.ipt)
            case "items": result = RollupColumnSort.number(lhs.pack.items, rhs.pack.items)
            case "status", "yoy": result = RollupColumnSort.number(lhs.pack.yoy, rhs.pack.yoy)
            default: result = RollupColumnSort.number(lhs.pack.sales, rhs.pack.sales)
            }
            return RollupColumnSort.ordered(result, ascending: sortAscending)
        }
        orderedCount = next.count
        snaps = Array(next.prefix(max(limit, 50)))
    }
}
