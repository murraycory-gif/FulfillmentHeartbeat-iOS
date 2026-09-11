import SwiftUI

enum MissingItemsMath {
    static let goalText = "5%"
    static let watchText = "5.01–6.50%"

    static func health(_ value: Double?) -> Health {
        HeartbeatMath.missingItemsHealth(pct: value)
    }
}

enum MILayout {
    static let gutter: CGFloat = HubLayout.tableGutter
    static var storeW: CGFloat { HubLayout.pageLabelWidth }
    static let countW: CGFloat = 52
    static let statusW: CGFloat = HubLayout.readableStatusWidth(phone: HubLayout.isPhoneDevice)
    /// Wide enough for "330" + "Seafood" and a percent. Never squeeze into the card.
    static var minCell: CGFloat { HubLayout.isPhoneDevice ? 100 : 112 }

    struct Metrics {
        let cellW: CGFloat
        let tableWidth: CGFloat
    }

    static func metrics(
        depts: Int,
        showCount: Bool,
        available: CGFloat,
        storeW: CGFloat = Self.storeW
    ) -> Metrics {
        let columns = CGFloat(max(depts, 0) + 1)
        let slots = 2 + (showCount ? 1 : 0) + Int(columns)
        let gutters = gutter * CGFloat(max(slots - 1, 0))
        let fixed = storeW + (showCount ? countW : 0) + statusW + gutters
        let floor = fixed + minCell * columns
        let span = HubLayout.tableSpan(available: available, floor: floor)
        let leftover = max(span - fixed, 0)
        let cellW = max(minCell, leftover / max(columns, 1))
        return Metrics(cellW: cellW, tableWidth: fixed + cellW * columns)
    }
}

struct MissingItemsCategoryFilter: View {
    @Binding var selected: Set<MissingItemDept>
    var width: CGFloat = 980
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var allOn: Bool { selected.isEmpty }
    private var compact: Bool { sizeClass != .regular }
    private var columns: Int {
        if compact { return 2 }
        return Int(ceil(Double(MissingItemDept.allCases.count + 1) / 2.0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Categories")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Text(allOn ? "All departments" : "\(selected.count) selected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer(minLength: 8)
                Button("Clear") {
                    var txn = Transaction()
                    txn.animation = nil
                    withTransaction(txn) { selected = [] }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.blue)
                .buttonStyle(.plain)
                .frame(minWidth: HubLayout.phoneHitTarget, minHeight: HubLayout.phoneHitTarget)
                .contentShape(Rectangle())
                .opacity(allOn ? 0 : 1)
                .disabled(allOn)
                .accessibilityHidden(allOn)
            }
            Text(allOn ? "Tap a department to focus the table. Tap more to add." : "Tap again to remove. Clear to show every department.")
                .font(.caption)
                .foregroundStyle(AppTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: compact ? 8 : 6), count: columns),
                alignment: .leading,
                spacing: compact ? 8 : 6
            ) {
                filterChip(title: "All", subtitle: "Every dept", on: allOn) {
                    apply([])
                }
                ForEach(MissingItemDept.allCases) { dept in
                    filterChip(title: dept.short, subtitle: dept.code, on: selected.contains(dept)) {
                        toggle(dept)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func apply(_ next: Set<MissingItemDept>) {
        var txn = Transaction()
        txn.animation = nil
        withTransaction(txn) { selected = next }
    }

    private func toggle(_ dept: MissingItemDept) {
        var next = selected
        if next.isEmpty {
            apply([dept])
            return
        }
        if next.contains(dept) {
            next.remove(dept)
        } else {
            next.insert(dept)
        }
        if next.isEmpty || next.count == MissingItemDept.allCases.count {
            apply([])
            return
        }
        apply(next)
    }

    private func filterChip(title: String, subtitle: String, on: Bool, action: @escaping () -> Void) -> some View {
        let label = Group {
            if compact {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(on ? .white : AppTheme.text)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(on ? Color.white.opacity(0.86) : AppTheme.textSecondary)
                        .lineLimit(1)
                }
            } else {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(on ? .white : AppTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(on ? Color.white.opacity(0.86) : AppTheme.textSecondary)
                        .lineLimit(1)
                }
            }
        }

        return label
            .frame(maxWidth: .infinity, minHeight: compact ? 48 : 36, alignment: .leading)
            .padding(.horizontal, compact ? 12 : 10)
            .padding(.vertical, compact ? 8 : 6)
            .background(
                RoundedRectangle(cornerRadius: compact ? 12 : 10, style: .continuous)
                    .fill(on ? AppTheme.blue : AppTheme.blueSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 12 : 10, style: .continuous)
                    .stroke(on ? AppTheme.blue : AppTheme.cardBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title) \(subtitle)")
            .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}

struct MissingItemsTable: View {
    @EnvironmentObject private var headerPin: LaborHeaderPin
    @EnvironmentObject private var store: HeartbeatStore
    let rows: [MetricRow]
    let depts: [MissingItemDept]
    var pageWidth: CGFloat = 1000
    var section: MetricSection = .missingItems

    private enum Column: Equatable {
        case store, total, status
        case dept(MissingItemDept)

        var key: String {
            switch self {
            case .store: return "label"
            case .total: return MissingItemDept.totalKey
            case .status: return "status"
            case .dept(let dept): return dept.rawValue
            }
        }
    }

    @State private var sort = Column.total
    @State private var ascending = false
    @State private var snaps: [MissingItemsLineSnap] = []
    @State private var openStore: String?
    @State private var limit = 80
    @State private var orderedCount = 0

    private var expanded: Bool { headerPin.storesExpanded }

    var body: some View {
        if rows.isEmpty {
            Section {
                EmptyHint(
                    symbol: section.symbol,
                    title: "No stores in this view",
                    detail: section == .preSubOOS
                        ? "Tap Avg Pre-Sub OOS to see every store, or pick another callout."
                        : "Tap Avg missing items to see every store, or pick another callout."
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
                    if next { rebuildOrder(sort: sort, ascending: ascending) }
                } content: {
                    let metrics = MILayout.metrics(
                        depts: depts.count,
                        showCount: false,
                        available: max(pageWidth - 48, 320)
                    )
                    HubAdaptiveHScroll(
                        minWidth: metrics.tableWidth,
                        minHeight: CGFloat(max(snaps.count, 1)) * 52 + 64
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            MissingItemsMetricHeader(
                                label: "Store",
                                showCount: false,
                                depts: depts,
                                cellW: metrics.cellW,
                                active: sort.key,
                                ascending: ascending,
                                onSelect: applyHeaderSort
                            )
                            .frame(width: metrics.tableWidth, alignment: .leading)
                            ForEach(snaps) { snap in
                                MissingItemsStoreRow(
                                    snap: snap,
                                    depts: depts,
                                    cellW: metrics.cellW,
                                    expanded: openStore == snap.storeNumber,
                                    onToggle: {
                                        openStore = openStore == snap.storeNumber ? nil : snap.storeNumber
                                    }
                                )
                                .equatable()
                                .frame(width: metrics.tableWidth, alignment: .leading)
                            }
                            if snaps.count < orderedCount {
                                Button {
                                    limit += 150
                                    rebuildOrder(sort: sort, ascending: ascending)
                                } label: {
                                    Text("Show more · \(HeartbeatFormat.num(Double(snaps.count))) of \(HeartbeatFormat.num(Double(orderedCount)))")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.blue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                .frame(width: metrics.tableWidth)
                            }
                        }
                        .frame(minWidth: metrics.tableWidth, alignment: .leading)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
                .onAppear {
                    headerPin.tableOpen = headerPin.storesExpanded
                    headerPin.storeCount = rows.count
                    headerPin.active = sort.key
                    headerPin.ascending = ascending
                    headerPin.onSelect = applyHeaderSort
                    rebuildOrder(sort: sort, ascending: ascending)
                }
                .onChange(of: store.filterStamp) { _, _ in
                    limit = 80
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
                .onChange(of: rows.count) { _, _ in
                    limit = 80
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
                .onChange(of: rows.first?.storeNumber) { _, _ in
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
                .onChange(of: depts.map(\.rawValue).joined()) { _, _ in
                    rebuildOrder(sort: sort, ascending: ascending)
                }
            }
            .transaction { $0.animation = nil }
        }
    }

    private func applyHeaderSort(_ key: String) {
        let column: Column
        if key == "label" {
            column = .store
        } else if key == "status" {
            column = .status
        } else if key == MissingItemDept.totalKey {
            column = .total
        } else if let dept = MissingItemDept(rawValue: key) {
            column = .dept(dept)
        } else {
            column = .total
        }
        let nextAscending = sort == column ? !ascending : column == .store
        sort = column
        ascending = nextAscending
        headerPin.active = column.key
        headerPin.ascending = nextAscending
        rebuildOrder(sort: column, ascending: nextAscending)
    }

    private func rebuildOrder(sort: Column, ascending: Bool) {
        guard !PulseLaunch.shouldSkipCollapsedStoreRebuild(expanded: headerPin.storesExpanded) else { return }
        let sorted = rows.sorted { lhs, rhs in
            let result = compare(lhs, rhs, sort: sort)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
        orderedCount = sorted.count
        snaps = sorted.prefix(limit).map { MissingItemsLineSnap($0, depts: depts) }
    }

    private func compare(_ lhs: MetricRow, _ rhs: MetricRow, sort: Column) -> ComparisonResult {
        switch sort {
        case .store:
            if let a = Int(lhs.storeNumber), let b = Int(rhs.storeNumber) {
                return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
            }
            return lhs.storeNumber.localizedStandardCompare(rhs.storeNumber)
        case .total:
            return numberOrder(
                HeartbeatMath.missingItemsRate(lhs, depts: depts),
                HeartbeatMath.missingItemsRate(rhs, depts: depts)
            )
        case .dept(let dept):
            return numberOrder(lhs.number(dept.rawValue), rhs.number(dept.rawValue))
        case .status:
            let a = healthRank(HeartbeatMath.missingItemsHealth(lhs, depts: depts))
            let b = healthRank(HeartbeatMath.missingItemsHealth(rhs, depts: depts))
            if a == b {
                return numberOrder(
                    HeartbeatMath.missingItemsRate(lhs, depts: depts),
                    HeartbeatMath.missingItemsRate(rhs, depts: depts)
                )
            }
            return a < b ? .orderedAscending : .orderedDescending
        }
    }

    private func numberOrder(_ a: Double?, _ b: Double?) -> ComparisonResult {
        let lhs = a ?? -1
        let rhs = b ?? -1
        if lhs == rhs { return .orderedSame }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }

    private func healthRank(_ health: Health) -> Int {
        switch health {
        case .risk: return 0
        case .watch: return 1
        case .good: return 2
        case .none: return 3
        }
    }
}

private struct MissingItemsStoreGrid: View {
    let snaps: [MissingItemsLineSnap]
    let depts: [MissingItemDept]
    let available: CGFloat
    let sortKey: String
    let ascending: Bool
    let onSelect: (String) -> Void
    @Binding var openStore: String?
    let shown: Int
    let total: Int
    let onMore: () -> Void

    var body: some View {
        let metrics = MILayout.metrics(depts: depts.count, showCount: false, available: available)
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 6, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(snaps) { snap in
                        MissingItemsStoreRow(
                            snap: snap,
                            depts: depts,
                            cellW: metrics.cellW,
                            expanded: openStore == snap.storeNumber,
                            onToggle: {
                                openStore = openStore == snap.storeNumber ? nil : snap.storeNumber
                            }
                        )
                        .equatable()
                        .frame(width: metrics.tableWidth, alignment: .leading)
                    }
                    if shown < total {
                        Button(action: onMore) {
                            Text("Show more · \(HeartbeatFormat.num(Double(shown))) of \(HeartbeatFormat.num(Double(total)))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .frame(width: metrics.tableWidth)
                    }
                } header: {
                    MissingItemsMetricHeader(
                        label: "Store",
                        showCount: false,
                        depts: depts,
                        cellW: metrics.cellW,
                        active: sortKey,
                        ascending: ascending,
                        onSelect: onSelect
                    )
                    .padding(.bottom, 4)
                    .frame(width: metrics.tableWidth, alignment: .leading)
                    .background(AppTheme.tableFill)
                }
            }
        }
    }
}

private struct MissingItemsRollupRow: Identifiable {
    let id: String
    let label: String
    let storeCount: Int
    let total: Double?
    let values: [String: Double]
    let health: Health
}

private enum MissingItemsGrain {
    case region, division, district, store

    var title: String {
        switch self {
        case .region: return "Regions"
        case .division: return "Markets"
        case .district: return "Districts"
        case .store: return "Store"
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

    var columnTitle: String {
        switch self {
        case .region: return "Region"
        case .division: return "Division"
        case .district: return "District"
        case .store: return "Store"
        }
    }

    var labelWidth: CGFloat {
        HubLayout.scopeLabelWidth(district: self == .district)
    }

    init(_ grain: DashScopeGrain) {
        switch grain {
        case .region: self = .region
        case .division: self = .division
        case .district: self = .district
        case .store: self = .store
        }
    }

    static func current(for filters: DashboardFilters) -> MissingItemsGrain? {
        PulseLaunch.sectionRollupGrains(filters: filters).first.map(MissingItemsGrain.init)
    }
}

private enum MissingItemsRollupBuilder {
    static func source(from all: [MetricRow], filters: DashboardFilters) -> [MetricRow] {
        all.filter { !$0.storeNumber.isEmpty }
    }

    static func rows(from stores: [MetricRow], grain: MissingItemsGrain, depts: [MissingItemDept]) -> [MissingItemsRollupRow] {
        var buckets: [String: [MetricRow]] = [:]
        for row in stores {
            let laborGrain: LaborRollupGrain
            switch grain {
            case .region: laborGrain = .region
            case .division: laborGrain = .division
            case .district: laborGrain = .district
            case .store: laborGrain = .store
            }
            guard let key = RollupMarketFill.acceptedGrainKey(row, grain: laborGrain) else { continue }
            buckets[key, default: []].append(row)
        }
        var result: [MissingItemsRollupRow] = []
        result.reserveCapacity(buckets.count)
        for (key, group) in buckets {
            let label: String
            switch grain {
            case .region, .division, .district:
                label = key
            case .store:
                let division = group.first?.division ?? ""
                label = division.isEmpty ? key : "\(key)  |  \(division)"
            }
            var values: [String: Double] = [:]
            for dept in depts {
                if let avg = HeartbeatMath.average(group.compactMap { $0.number(dept.rawValue) }) {
                    values[dept.rawValue] = avg
                }
            }
            let total = HeartbeatMath.average(group.compactMap { HeartbeatMath.missingItemsRate($0, depts: depts) })
            result.append(
                MissingItemsRollupRow(
                    id: key,
                    label: label,
                    storeCount: group.count,
                    total: total,
                    values: values,
                    health: MissingItemsMath.health(total)
                )
            )
        }
        return result.sorted { ($0.total ?? -1) > ($1.total ?? -1) }
    }
}

private struct MissingItemsLineSnap: Identifiable, Equatable {
    let id: UUID
    let storeNumber: String
    let label: String
    let district: String
    let om: String
    let total: String
    let totalValue: Double
    let health: Health
    let values: [String: String]
    let raw: [String: Double]

    init(_ row: MetricRow, depts: [MissingItemDept]) {
        id = row.id
        storeNumber = row.storeNumber
        label = HeartbeatMath.storeDisplayLabel(row)
        district = HeartbeatMath.canonicalDistrict(row.district)
        om = row.operationsOM
        let rate = HeartbeatMath.missingItemsRate(row, depts: depts)
        total = HeartbeatFormat.pct(rate)
        totalValue = rate ?? -1
        health = HeartbeatMath.missingItemsHealth(row, depts: depts)
        var formatted: [String: String] = [:]
        var numbers: [String: Double] = [:]
        for dept in MissingItemDept.allCases {
            if let value = row.number(dept.rawValue) {
                formatted[dept.rawValue] = HeartbeatFormat.pct(value)
                numbers[dept.rawValue] = value
            }
        }
        values = formatted
        raw = numbers
    }
}

private struct MissingItemsStoreRow: View, Equatable {
    let snap: MissingItemsLineSnap
    let depts: [MissingItemDept]
    let cellW: CGFloat
    var storeW: CGFloat = MILayout.storeW
    let expanded: Bool
    let onToggle: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.snap == rhs.snap && lhs.depts == rhs.depts && lhs.cellW == rhs.cellW && lhs.storeW == rhs.storeW && lhs.expanded == rhs.expanded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 10 : 0) {
            Button(action: onToggle) {
                MissingItemsCheapLine(snap: snap, depts: depts, cellW: cellW, storeW: storeW, expanded: expanded)
                    .equatable()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                MissingItemsStoreExpand(snap: snap, depts: depts)
            }
        }
        .tableRowCard(health: snap.health)
    }
}

private struct MissingItemsCheapLine: View, Equatable {
    let snap: MissingItemsLineSnap
    let depts: [MissingItemDept]
    let cellW: CGFloat
    var storeW: CGFloat = MILayout.storeW
    let expanded: Bool

    var body: some View {
        HStack(spacing: MILayout.gutter) {
            HStack(spacing: 4) {
                Text(snap.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
            }
            .frame(width: storeW, alignment: .leading)
            ForEach(depts) { dept in
                let value = snap.raw[dept.rawValue]
                cell(snap.values[dept.rawValue] ?? "—", MissingItemsMath.health(value), width: cellW)
            }
            cell(snap.total, snap.health, width: cellW)
            Text(snap.health.label.uppercased())
                .font(.caption.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .foregroundStyle(Color.white)
                .background(pill(snap.health), in: Capsule())
                .frame(width: MILayout.statusW, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private func cell(_ value: String, _ health: Health, width: CGFloat) -> some View {
        Text(value)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(ink(health))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: width, alignment: .center)
            .padding(.vertical, 6)
            .background(wash(health), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

    private func pill(_ health: Health) -> Color {
        switch health {
        case .good: return AppTheme.ok
        case .watch: return AppTheme.warn
        case .risk: return AppTheme.bad
        case .none: return AppTheme.textTertiary
        }
    }
}

private struct MissingItemsStoreExpand: View {
    let snap: MissingItemsLineSnap
    let depts: [MissingItemDept]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("District \(snap.district.isEmpty ? "—" : snap.district)  ·  \(snap.om.isEmpty ? "—" : snap.om)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140), spacing: 8)],
                spacing: 8
            ) {
                chip("Total", snap.total, snap.health)
                ForEach(depts) { dept in
                    let value = snap.raw[dept.rawValue]
                    chip(dept.title, snap.values[dept.rawValue] ?? "—", MissingItemsMath.health(value))
                }
            }
        }
        .padding(.bottom, 4)
    }

    private func chip(_ title: String, _ value: String, _ health: Health) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(ink(health))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(wash(health), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        case .none: return AppTheme.blueSoft.opacity(0.4)
        }
    }
}

private struct MissingItemsMetricLine: View {
    let label: String
    var count: Int? = nil
    let total: Double?
    let values: [String: Double]
    let depts: [MissingItemDept]
    let cellW: CGFloat
    var storeW: CGFloat = MILayout.storeW

    var body: some View {
        let health = MissingItemsMath.health(total)
        HStack(spacing: MILayout.gutter) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: storeW, alignment: .leading)
            if let count {
                Text(HeartbeatFormat.num(Double(count)))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: MILayout.countW, alignment: .center)
            }
            ForEach(depts) { dept in
                cell(HeartbeatFormat.pct(values[dept.rawValue]), MissingItemsMath.health(values[dept.rawValue]))
            }
            cell(HeartbeatFormat.pct(total), health)
            HealthBadge(health: health, prominent: true, compact: true)
                .frame(width: MILayout.statusW, alignment: .trailing)
        }
        .tableRowCard(health: health)
    }

    private func cell(_ value: String, _ health: Health) -> some View {
        Text(value)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(ink(health))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: cellW, alignment: .center)
            .padding(.vertical, 6)
            .background(wash(health), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

struct MissingItemsMetricHeader: View {
    let label: String
    var showCount: Bool = false
    let depts: [MissingItemDept]
    var cellW: CGFloat = MILayout.minCell
    var storeW: CGFloat = MILayout.storeW
    var active: String? = nil
    var ascending: Bool = false
    var onSelect: ((String) -> Void)? = nil

    var body: some View {
        HStack(spacing: MILayout.gutter) {
            head(label, key: "label", alignment: .leading)
                .frame(width: storeW, alignment: .leading)
            if showCount {
                head("Stores", key: "count", alignment: .center)
                    .frame(width: MILayout.countW, alignment: .center)
            }
            ForEach(depts) { dept in
                deptHead(dept)
                    .frame(width: cellW, alignment: .center)
            }
            head("Total", key: MissingItemDept.totalKey, alignment: .center)
                .frame(width: cellW, alignment: .center)
            head("Status", key: "status", alignment: .trailing)
                .frame(width: MILayout.statusW, alignment: .trailing)
        }
        .font(.caption.weight(.bold))
        .lineLimit(2)
        .minimumScaleFactor(0.75)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private func deptHead(_ dept: MissingItemDept) -> some View {
        let selected = active == dept.rawValue
        let content = VStack(spacing: 1) {
            HStack(spacing: 2) {
                Text(dept.code)
                if selected {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                }
            }
            Text(dept.short.uppercased())
        }
        .foregroundStyle(selected ? AppTheme.blue : AppTheme.text)
        .frame(width: cellW, alignment: .center)
        .contentShape(Rectangle())
        return Group {
            if let onSelect {
                Button { onSelect(dept.rawValue) } label: { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private func head(_ title: String, key: String, alignment: Alignment = .trailing) -> some View {
        let selected = active == key
        let content = HStack(spacing: 3) {
            Text(title.uppercased())
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
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

struct MissingItemsStickyStoreHeader: View {
    @EnvironmentObject private var pin: LaborHeaderPin
    let depts: [MissingItemDept]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Store")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
                Text("\(HeartbeatFormat.num(Double(pin.storeCount))) stores")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                MissingItemsMetricHeader(
                    label: "Store",
                    showCount: false,
                    depts: depts,
                    active: pin.active,
                    ascending: pin.ascending,
                    onSelect: { pin.onSelect?($0) }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(AppTheme.bg)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.cardBorder)
                .frame(height: 1)
        }
    }
}

struct MissingItemsRollupTable: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var headerPin: LaborHeaderPin
    let depts: [MissingItemDept]
    var pageWidth: CGFloat = 1000
    var section: MetricSection = .missingItems
    var forcedGrain: DashScopeGrain? = nil
    @State private var grain: MissingItemsGrain? = .division
    @State private var summary: [MissingItemsRollupRow] = []
    @State private var sortKey = MissingItemDept.totalKey
    @State private var sortAscending = false

    private var expanded: Bool { headerPin.rollupExpanded }

    var body: some View {
        Group {
        if let grain {
            let metrics = MILayout.metrics(
                depts: depts.count,
                showCount: grain != .store,
                available: max(pageWidth - 56, 320),
                storeW: grain.labelWidth
            )
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
                    HubAdaptiveHScroll(
                        minWidth: metrics.tableWidth,
                        minHeight: CGFloat(max(summary.count, 1)) * 48 + 64
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            MissingItemsMetricHeader(
                                label: grain.columnTitle,
                                showCount: grain != .store,
                                depts: depts,
                                cellW: metrics.cellW,
                                storeW: grain.labelWidth,
                                active: sortKey,
                                ascending: sortAscending,
                                onSelect: applySort
                            )
                            .frame(width: metrics.tableWidth, alignment: .leading)
                            ForEach(summary) { row in
                                MissingItemsMetricLine(
                                    label: row.label,
                                    count: grain == .store ? nil : row.storeCount,
                                    total: row.total,
                                    values: row.values,
                                    depts: depts,
                                    cellW: metrics.cellW,
                                    storeW: grain.labelWidth
                                )
                                .frame(width: metrics.tableWidth, alignment: .leading)
                            }
                        }
                        .frame(minWidth: metrics.tableWidth, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
            .background(AppTheme.tableFill)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .stroke(AppTheme.blue, lineWidth: 2.5)
            )
        }
        }
        .onAppear(perform: rebuild)
        .onChange(of: store.filterStamp) { _, _ in rebuild() }
        .onChange(of: depts.count) { _, _ in rebuild() }
        .onChange(of: section) { _, _ in rebuild() }
    }

    private func rebuild() {
        let next = forcedGrain.map(MissingItemsGrain.init) ?? MissingItemsGrain.current(for: store.filters)
        grain = next
        guard let next else { summary = []; return }
        let source = MissingItemsRollupBuilder.source(from: store.rollupStores(for: section), filters: store.filters)
        var rows = MissingItemsRollupBuilder.rows(from: source, grain: next, depts: depts)
        rows.removeAll { RollupMarketFill.hidesUnassignedMarket($0.label) }
        if next == .region {
            for name in RollupMarketFill.missingRegions(present: rows.map(\.label)) {
                rows.append(
                    MissingItemsRollupRow(
                        id: name,
                        label: name,
                        storeCount: 0,
                        total: nil,
                        values: [:],
                        health: .none
                    )
                )
            }
        }
        if next == .division {
            for extra in RollupMarketFill.missingDivisions(present: rows.map(\.label), markets: store.marketStores(), filters: store.filters) {
                rows.append(
                    MissingItemsRollupRow(
                        id: extra.name,
                        label: extra.name,
                        storeCount: extra.storeCount,
                        total: nil,
                        values: [:],
                        health: .none
                    )
                )
            }
            if let orphan = RollupMarketFill.unassignedIfRealOrphans(
                markets: store.marketStores(),
                isRoster: store.isOfficialRosterStore
            ) {
                rows.append(
                    MissingItemsRollupRow(
                        id: orphan.name,
                        label: orphan.name,
                        storeCount: orphan.storeCount,
                        total: nil,
                        values: [:],
                        health: .none
                    )
                )
            }
        }
        summary = rows
        applyCurrentSort()
    }

    private func applySort(_ key: String) {
        RollupColumnSort.toggle(current: &sortKey, ascending: &sortAscending, key: key)
        applyCurrentSort()
    }

    private func applyCurrentSort() {
        summary.sort { lhs, rhs in
            let result: ComparisonResult
            switch sortKey {
            case "label":
                result = RollupColumnSort.label(lhs.label, rhs.label)
            case "count":
                result = RollupColumnSort.count(lhs.storeCount, rhs.storeCount)
            case "status":
                result = RollupColumnSort.health(lhs.health, rhs.health)
            case MissingItemDept.totalKey:
                result = RollupColumnSort.number(lhs.total, rhs.total)
            default:
                result = RollupColumnSort.number(lhs.values[sortKey], rhs.values[sortKey])
            }
            return RollupColumnSort.ordered(result, ascending: sortAscending)
        }
    }
}

struct PreSubItemTable: View {
    @EnvironmentObject private var store: HeartbeatStore
    let rows: [MetricRow]
    var pageWidth: CGFloat = 1000

    private enum Column: String, CaseIterable, Identifiable {
        case store, item, pct, units, dollars, oosPct, oosDollars, status
        var id: String { rawValue }
        var key: String { rawValue }
        var title: String {
            switch self {
            case .store: return "Store"
            case .item: return "Item"
            case .pct: return "Pre-Sub %"
            case .units: return "Units"
            case .dollars: return "$ Pre-Sub"
            case .oosPct: return "OOS %"
            case .oosDollars: return "$ OOS"
            case .status: return "Status"
            }
        }
    }

    @State private var expanded = false
    @State private var sort = Column.units
    @State private var ascending = false
    @State private var limit = 80
    @State private var snaps: [PreSubItemSnap] = []
    @State private var orderedCount = 0

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    let next = !expanded
                    expanded = next
                    if next { rebuild() }
                } label: {
                    HubTableHeader(
                        icon: "barcode",
                        title: "Pre-Sub OOS Items",
                        accessory: rows.isEmpty
                            ? "Item rows fill from the Heartbeat pack after ready  ·  tap to expand"
                            : "\(HeartbeatFormat.num(Double(rows.count))) items  ·  tap to \(expanded ? "collapse" : "expand")",
                        expanded: expanded,
                        embedded: true
                    )
                }
                .buttonStyle(.plain)
                if expanded {
                    if rows.isEmpty {
                        EmptyHint(
                            symbol: "barcode",
                            title: "No item rows in this view",
                            detail: "Item rows fill from the Heartbeat pack after ready. Header filters still apply."
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    } else {
                        HubAdaptiveHScroll(
                            minWidth: PreSubItemLayout.floor,
                            minHeight: CGFloat(max(snaps.count, 1)) * 52 + 64
                        ) {
                            VStack(alignment: .leading, spacing: 0) {
                                PreSubItemColumns(
                                    snaps: snaps,
                                    sortKey: sort.key,
                                    ascending: ascending,
                                    onSelect: applySort
                                )
                                if orderedCount > snaps.count {
                                    Button {
                                        limit += 80
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
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                        .padding(.bottom, 12)
                    }
                }
            }
            .background(AppTheme.tableFill)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .stroke(AppTheme.blue, lineWidth: 2.5)
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(AppTheme.bg)
            .onAppear { rebuild() }
            .onChange(of: store.filterStamp) { _, _ in
                limit = 80
                if expanded { rebuild() }
            }
            .onChange(of: rows.count) { _, _ in
                limit = 80
                if expanded { rebuild() }
            }
            .onChange(of: rows.first?.storeNumber) { _, _ in
                if expanded { rebuild() }
            }
        }
        .transaction { $0.animation = nil }
    }

    private func applySort(_ key: String) {
        let column = Column.allCases.first { $0.key == key } ?? .units
        let nextAscending = sort == column ? !ascending : (column == .store || column == .item)
        sort = column
        ascending = nextAscending
        rebuild()
    }

    private func rebuild() {
        let sorted = rows.sorted { lhs, rhs in
            let result = compare(lhs, rhs)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
        orderedCount = sorted.count
        snaps = sorted.prefix(limit).map(PreSubItemSnap.init)
    }

    private func compare(_ lhs: MetricRow, _ rhs: MetricRow) -> ComparisonResult {
        switch sort {
        case .store:
            return HeartbeatFormat.storeOrder(lhs.storeNumber, rhs.storeNumber) ? .orderedAscending : .orderedDescending
        case .item:
            return (lhs.textPayload["bpn"] ?? "").localizedStandardCompare(rhs.textPayload["bpn"] ?? "")
        case .pct:
            return numberOrder(lhs.number("presub_pct"), rhs.number("presub_pct"))
        case .units:
            return numberOrder(lhs.number("presub_count"), rhs.number("presub_count"))
        case .dollars:
            return numberOrder(lhs.number("presub_dollars"), rhs.number("presub_dollars"))
        case .oosPct:
            return numberOrder(lhs.number("oos_pct"), rhs.number("oos_pct"))
        case .oosDollars:
            return numberOrder(lhs.number("oos_dollars"), rhs.number("oos_dollars"))
        case .status:
            let a = healthRank(HeartbeatMath.health(for: .preSubOOSItem, row: lhs))
            let b = healthRank(HeartbeatMath.health(for: .preSubOOSItem, row: rhs))
            if a == b { return numberOrder(lhs.number("presub_pct"), rhs.number("presub_pct")) }
            return a < b ? .orderedAscending : .orderedDescending
        }
    }

    private func numberOrder(_ a: Double?, _ b: Double?) -> ComparisonResult {
        let lhs = a ?? -1
        let rhs = b ?? -1
        if lhs == rhs { return .orderedSame }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }

    private func healthRank(_ health: Health) -> Int {
        switch health {
        case .risk: return 0
        case .watch: return 1
        case .good: return 2
        case .none: return 3
        }
    }
}

private struct PreSubItemSnap: Identifiable, Equatable {
    let id: UUID
    let store: String
    let division: String
    let item: String
    let pct: String
    let units: String
    let dollars: String
    let oosPct: String
    let oosDollars: String
    let health: Health

    init(_ row: MetricRow) {
        id = row.id
        store = row.storeNumber
        division = row.division
        item = row.textPayload["bpn"] ?? "—"
        pct = HeartbeatFormat.pct(row.number("presub_pct"))
        units = HeartbeatFormat.num(row.number("presub_count"), digits: 0)
        dollars = HeartbeatFormat.money(row.number("presub_dollars"))
        oosPct = HeartbeatFormat.pct(row.number("oos_pct"))
        oosDollars = HeartbeatFormat.money(row.number("oos_dollars"))
        health = HeartbeatMath.health(for: .preSubOOSItem, row: row)
    }
}

private enum PreSubItemLayout {
    static let storeW: CGFloat = 92
    static let itemW: CGFloat = 156
    static let statusW: CGFloat = 88
    static let valueMin: CGFloat = 96
    static let valueCount = 5
    static var floor: CGFloat {
        storeW + itemW + statusW + CGFloat(valueCount) * valueMin + 48
    }

    static func valueWidth(available: CGFloat) -> CGFloat {
        let reserved = storeW + itemW + statusW + 48
        let span = max(available, floor)
        return max(valueMin, (span - reserved) / CGFloat(valueCount))
    }
}

private struct PreSubItemColumns: View {
    let snaps: [PreSubItemSnap]
    let sortKey: String
    let ascending: Bool
    let onSelect: (String) -> Void
    @Environment(\.hubTableWidth) private var tableWidth

    private var valueW: CGFloat { PreSubItemLayout.valueWidth(available: tableWidth) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PreSubItemHeader(active: sortKey, ascending: ascending, onSelect: onSelect, valueW: valueW)
            ForEach(snaps) { snap in
                PreSubItemLine(snap: snap, valueW: valueW)
                    .padding(.vertical, 5)
            }
        }
    }
}

private struct PreSubItemHeader: View {
    let active: String
    let ascending: Bool
    let onSelect: (String) -> Void
    var valueW: CGFloat = PreSubItemLayout.valueMin

    var body: some View {
        HStack(spacing: 6) {
            head("Store", key: "store", alignment: .leading)
                .frame(width: PreSubItemLayout.storeW, alignment: .leading)
            head("Item", key: "item", alignment: .leading)
                .frame(width: PreSubItemLayout.itemW, alignment: .leading)
            head("Pre-Sub %", key: "pct")
                .frame(width: valueW, alignment: .trailing)
            head("Units", key: "units")
                .frame(width: valueW, alignment: .trailing)
            head("$ Pre-Sub", key: "dollars")
                .frame(width: valueW, alignment: .trailing)
            head("OOS %", key: "oosPct")
                .frame(width: valueW, alignment: .trailing)
            head("$ OOS", key: "oosDollars")
                .frame(width: valueW, alignment: .trailing)
            head("Status", key: "status", alignment: .trailing)
                .frame(width: PreSubItemLayout.statusW, alignment: .trailing)
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
        return Button { onSelect(key) } label: {
            HStack(spacing: 3) {
                Text(title.uppercased())
                if selected {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                }
            }
            .foregroundStyle(selected ? AppTheme.blue : AppTheme.text)
            .frame(maxWidth: .infinity, alignment: alignment)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PreSubItemLine: View, Equatable {
    let snap: PreSubItemSnap
    var valueW: CGFloat = PreSubItemLayout.valueMin

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.snap == rhs.snap && lhs.valueW == rhs.valueW
    }

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(snap.store)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !snap.division.isEmpty {
                    Text(snap.division)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(width: PreSubItemLayout.storeW, alignment: .leading)
            Text(snap.item)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.text)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(width: PreSubItemLayout.itemW, alignment: .leading)
            cell(snap.pct, snap.health)
            cell(snap.units, snap.health)
            cell(snap.dollars, snap.health)
            cell(snap.oosPct, .none)
            cell(snap.oosDollars, .none)
            HealthBadge(health: snap.health, prominent: true, compact: true)
                .frame(width: PreSubItemLayout.statusW, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .tableRowCard(health: snap.health)
    }

    private func cell(_ value: String, _ health: Health) -> some View {
        Text(value)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(ink(health))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(width: valueW, alignment: .trailing)
            .padding(.vertical, 6)
            .background(wash(health), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
