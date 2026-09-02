import SwiftUI

private struct SalesRollupRow: Identifiable {
    var id: String { label }
    let label: String
    let storeCount: Int
    let sales: Double?
    let orders: Double?
    let hd: Double?
    let dug: Double?
    let aov: Double?
    let health: Health
}

private enum SalesRollupBuilder {
    static func grain(for filters: DashboardFilters) -> LaborRollupGrain? {
        RollupMarketFill.grain(for: filters)
    }

    static func source(from rows: [MetricRow], filters: DashboardFilters) -> [MetricRow] {
        let stores = rows.filter { !HeartbeatMath.isIgnoredStore($0.storeNumber) && !$0.storeNumber.isEmpty }
        return RollupMarketFill.scoped(stores, filters: filters)
    }

    static func rows(from stores: [MetricRow], grain: LaborRollupGrain) -> [SalesRollupRow] {
        var buckets: [String: [MetricRow]] = [:]
        for row in stores {
            let key: String
            switch grain {
            case .division:
                key = RollupMarketFill.divisionKey(row.division)
            case .district:
                key = RollupMarketFill.districtKey(row.district)
            case .store:
                key = HeartbeatMath.canonicalStore(row.storeNumber)
            }
            guard !key.isEmpty else { continue }
            buckets[key, default: []].append(row)
        }
        return buckets.keys.sorted().compactMap { key in
            let pack = buckets[key] ?? []
            guard !pack.isEmpty else { return nil }
            let sales = pack.compactMap { $0.number("sales_dollars") }.reduce(0, +)
            let orders = pack.compactMap { $0.number("sales_orders") }.reduce(0, +)
            let hd = pack.compactMap { $0.number("sales_hd_orders") }.reduce(0, +)
            let dug = pack.compactMap { $0.number("sales_dug_orders") }.reduce(0, +)
            return SalesRollupRow(
                label: key,
                storeCount: Set(pack.map(\.storeNumber)).count,
                sales: sales,
                orders: orders,
                hd: hd,
                dug: dug,
                aov: orders > 0 ? sales / orders : nil,
                health: sales > 0 ? .good : .none
            )
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
            head("Orders", key: "orders")
            head("HD", key: "hd")
            head("DUG", key: "dug")
            head("AOV", key: "aov")
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
    let sales: Double?
    let orders: Double?
    let hd: Double?
    let dug: Double?
    let aov: Double?

    var body: some View {
        let health: Health = (sales ?? 0) > 0 ? .good : .none
        HStack(spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: 132, maxWidth: 190, alignment: .leading)
            if let count {
                Text(HeartbeatFormat.num(Double(count)))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 58, alignment: .trailing)
            }
            cell(HeartbeatFormat.money(sales), health)
            cell(HeartbeatFormat.num(orders, digits: 0), .none)
            cell(HeartbeatFormat.num(hd, digits: 0), .none)
            cell(HeartbeatFormat.num(dug, digits: 0), .none)
            cell(HeartbeatFormat.money(aov), .none, brand: true)
            HealthBadge(health: health, prominent: true, compact: true)
                .frame(width: 88, alignment: .trailing)
        }
        .tableRowCard(health: health)
    }

    private func cell(_ value: String, _ health: Health, brand: Bool = false) -> some View {
        Text(value)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(brand ? AppTheme.blue : AppTheme.text)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(brand ? AppTheme.blueSoft : Color.clear)
            )
    }
}

struct SalesRollupTable: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var headerPin: LaborHeaderPin
    @State private var grain: LaborRollupGrain? = .division
    @State private var summary: [SalesRollupRow] = []
    @State private var sortKey = "sales"
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
                                        sales: row.sales,
                                        orders: row.orders,
                                        hd: row.hd,
                                        dug: row.dug,
                                        aov: row.aov
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
        let source = SalesRollupBuilder.source(from: store.allLatest(for: .sales), filters: store.filters)
        var rows = SalesRollupBuilder.rows(from: source, grain: next)
        rows.sort { lhs, rhs in
            let result: ComparisonResult
            switch sortKey {
            case "label": result = RollupColumnSort.label(lhs.label, rhs.label)
            case "count": result = RollupColumnSort.count(lhs.storeCount, rhs.storeCount)
            case "orders": result = RollupColumnSort.number(lhs.orders, rhs.orders)
            case "hd": result = RollupColumnSort.number(lhs.hd, rhs.hd)
            case "dug": result = RollupColumnSort.number(lhs.dug, rhs.dug)
            case "aov": result = RollupColumnSort.number(lhs.aov, rhs.aov)
            case "status": result = RollupColumnSort.health(lhs.health, rhs.health)
            default: result = RollupColumnSort.number(lhs.sales, rhs.sales)
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
    let sales: Double?
    let orders: Double?
    let hd: Double?
    let dug: Double?
    let aov: Double?

    init(_ row: MetricRow) {
        storeNumber = row.storeNumber
        id = row.storeNumber
        let name = row.storeName.map { "\(row.storeNumber) | \($0)" } ?? row.storeNumber
        label = row.division.isEmpty ? name : "\(name) | \(row.division)"
        sales = row.number("sales_dollars")
        orders = row.number("sales_orders")
        hd = row.number("sales_hd_orders")
        dug = row.number("sales_dug_orders")
        aov = row.number("sales_aov")
    }
}

struct SalesTable: View {
    @EnvironmentObject private var headerPin: LaborHeaderPin
    @EnvironmentObject private var store: HeartbeatStore
    let rows: [MetricRow]
    @State private var sortKey = "sales"
    @State private var sortAscending = false
    @State private var snaps: [SalesLineSnap] = []
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
                    VStack(spacing: 0) {
                        SalesMetricHeader(
                            label: "Store",
                            showCount: false,
                            active: sortKey,
                            ascending: sortAscending,
                            onSelect: applySort
                        )
                        ForEach(Array(snaps.prefix(limit))) { snap in
                            SalesMetricLine(
                                label: snap.label,
                                sales: snap.sales,
                                orders: snap.orders,
                                hd: snap.hd,
                                dug: snap.dug,
                                aov: snap.aov
                            )
                            .padding(.vertical, 5)
                        }
                        if orderedCount > snaps.count {
                            Button {
                                limit += 50
                                rebuild()
                            } label: {
                                Text("Show more · \(HeartbeatFormat.num(Double(snaps.count))) of \(HeartbeatFormat.num(Double(orderedCount)))")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
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
        if sortKey == key { sortAscending.toggle() } else { sortKey = key; sortAscending = key == "label" }
        headerPin.active = sortKey
        headerPin.ascending = sortAscending
        rebuild()
    }

    private func rebuild() {
        var next = rows.map(SalesLineSnap.init)
        next.sort { lhs, rhs in
            let result: ComparisonResult
            switch sortKey {
            case "label": result = RollupColumnSort.label(lhs.label, rhs.label)
            case "orders": result = RollupColumnSort.number(lhs.orders, rhs.orders)
            case "hd": result = RollupColumnSort.number(lhs.hd, rhs.hd)
            case "dug": result = RollupColumnSort.number(lhs.dug, rhs.dug)
            case "aov": result = RollupColumnSort.number(lhs.aov, rhs.aov)
            default: result = RollupColumnSort.number(lhs.sales, rhs.sales)
            }
            return RollupColumnSort.ordered(result, ascending: sortAscending)
        }
        orderedCount = next.count
        snaps = Array(next.prefix(max(limit, 50)))
    }
}
