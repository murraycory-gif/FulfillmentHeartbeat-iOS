import SwiftUI

private struct SalesPack {
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
        sales = row.number(prefix + "dollars")
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

    init(rows: [MetricRow]) {
        let sales = rows.compactMap { $0.number("sales_dollars") }.reduce(0, +)
        let orders = rows.compactMap { $0.number("sales_orders") }.reduce(0, +)
        let items = rows.compactMap { $0.number("sales_items") }.reduce(0, +)
        let hd = rows.compactMap { $0.number("sales_hd_orders") }.reduce(0, +)
        let dug = rows.compactMap { $0.number("sales_dug_orders") }.reduce(0, +)
        let yoyWeight = rows.reduce(0.0) { $0 + (($1.number("sales_yoy_pct") ?? 0) * ($1.number("sales_dollars") ?? 0)) }
        self.sales = sales
        self.orders = orders
        self.items = items
        self.hd = hd
        self.dug = dug
        self.yoy = sales > 0 ? yoyWeight / sales : HeartbeatMath.average(rows.compactMap { $0.number("sales_yoy_pct") })
        self.aos = orders > 0 ? sales / orders : HeartbeatMath.average(rows.compactMap { $0.number("sales_aos") ?? $0.number("sales_aov") })
        self.aiv = HeartbeatMath.average(rows.compactMap { $0.number("sales_aiv") })
        self.ipt = HeartbeatMath.average(rows.compactMap { $0.number("sales_ipt") })
        self.ordersYoy = HeartbeatMath.average(rows.compactMap { $0.number("sales_orders_yoy_pct") })
        self.health = HeartbeatMath.salesHealth(planPct: nil, yoy: yoy)
    }
}

private struct SalesRollupRow: Identifiable {
    var id: String { label }
    let label: String
    let storeCount: Int
    let pack: SalesPack
}

private enum SalesRollupBuilder {
    static func grain(for filters: DashboardFilters) -> LaborRollupGrain? {
        RollupMarketFill.grain(for: filters)
    }

    static func source(from rows: [MetricRow], filters: DashboardFilters) -> [MetricRow] {
        let stores = rows.filter { $0.textPayload["sales_grain"] != "day" && !HeartbeatMath.isIgnoredStore($0.storeNumber) && !$0.storeNumber.isEmpty }
        return RollupMarketFill.scoped(stores, filters: filters)
    }

    static func rows(from stores: [MetricRow], grain: LaborRollupGrain) -> [SalesRollupRow] {
        var buckets: [String: [MetricRow]] = [:]
        for row in stores {
            let key: String
            switch grain {
            case .division:
                key = RollupMarketFill.divisionKey(row.division)
                if key == "Unassigned" { continue }
            case .district:
                key = RollupMarketFill.districtKey(row.district)
                if key == "Unassigned" { continue }
            case .store:
                key = HeartbeatMath.canonicalStore(row.storeNumber)
            }
            guard !key.isEmpty, row.number("sales_dollars") != nil || row.number("sales_orders") != nil else { continue }
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
}

struct SalesMetricHeader: View {
    let label: String
    var showCount: Bool = false
    var active: String? = nil
    var ascending: Bool = false
    var onSelect: ((String) -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            head(label, key: "label", alignment: .leading)
                .frame(minWidth: 132, maxWidth: 190, alignment: .leading)
            if showCount {
                head("Stores", key: "count", alignment: .trailing)
                    .frame(width: 58, alignment: .trailing)
            }
            head("Sales $", key: "sales")
            head("YoY %", key: "yoy")
            head("Orders", key: "orders")
            head("Ord YoY", key: "ordersYoy")
            head("AOS", key: "aos")
            head("AIV", key: "aiv")
            head("Items/Txn", key: "ipt")
            head("Items", key: "items")
            head("Status", key: "status", alignment: .trailing)
                .frame(width: 88, alignment: .trailing)
        }
        .font(.caption.weight(.bold))
        .tracking(0.3)
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 6)
        .padding(.bottom, 8)
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
        .frame(maxWidth: alignment == .leading ? nil : .infinity, alignment: alignment)
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
        HStack(spacing: 6) {
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
                    .minimumScaleFactor(0.7)
            }
            .frame(minWidth: 132, maxWidth: 190, alignment: .leading)
            if let count {
                Text(HeartbeatFormat.num(Double(count)))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 58, alignment: .trailing)
            }
            cell(HeartbeatFormat.money(pack.sales), pack.health)
            cell(HeartbeatFormat.pct(pack.yoy), pack.health)
            cell(HeartbeatFormat.num(pack.orders, digits: 0), .none)
            cell(HeartbeatFormat.pct(pack.ordersYoy), .none)
            cell(HeartbeatFormat.money(pack.aos), .none, brand: true)
            cell(HeartbeatFormat.num(pack.aiv, digits: 2), .none)
            cell(HeartbeatFormat.num(pack.ipt, digits: 1), .none)
            cell(HeartbeatFormat.num(pack.items, digits: 0), .none)
            HealthBadge(health: pack.health == .none && (pack.sales ?? 0) > 0 ? .good : pack.health, prominent: true, compact: true)
                .frame(width: 88, alignment: .trailing)
        }
        .tableRowCard(health: pack.health)
    }

    private func cell(_ value: String, _ health: Health, brand: Bool = false) -> some View {
        Text(value)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(brand ? AppTheme.blue : ink(health))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(brand ? AppTheme.blueSoft : wash(health))
            )
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
                VStack(alignment: .leading, spacing: expanded ? 10 : 0) {
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
                        .padding(.top, 10)
                        .padding(.bottom, 16)
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
        var rows = SalesRollupBuilder.rows(from: SalesRollupBuilder.source(from: store.allLatest(for: .sales), filters: store.filters), grain: next)
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

    init(_ row: MetricRow) {
        storeNumber = row.storeNumber
        id = row.storeNumber
        let place = row.district.isEmpty ? row.division : row.district
        label = place.isEmpty ? row.storeNumber : "\(row.storeNumber) | \(place)"
        pack = SalesPack(row)
        let names = (row.textPayload["sales_days"] ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "Week" }
        days = names.enumerated().compactMap { index, name in
            let day = SalesPack(row, prefix: "sales_d\(index)_")
            guard day.sales != nil || day.orders != nil else { return nil }
            return (name, day)
        }
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
                    detail: "Upload the Sales ScoreCard export or pick another filter."
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
                    if expanded { rebuild() }
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
            let snap = SalesLineSnap(row)
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
