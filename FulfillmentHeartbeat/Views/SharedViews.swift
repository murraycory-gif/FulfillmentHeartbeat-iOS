import SwiftUI
import UIKit
import MessageUI

struct HubCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .fill(AppTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
            )
    }
}

struct PickerScoreCardTitle: View {
    var font: Font = .title2.weight(.semibold)

    var body: some View {
        (Text("Picker ") + Text("ScoreCard").foregroundStyle(AppTheme.blue))
            .font(font)
    }
}

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(AppTheme.textTertiary)
    }
}

struct HealthBadge: View {
    let health: Health

    var body: some View {
        Text(health.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(foreground)
            .background(background, in: Capsule(style: .continuous))
    }

    private var foreground: Color {
        switch health {
        case .good: return AppTheme.ok
        case .watch: return AppTheme.warn
        case .risk: return AppTheme.bad
        case .none: return AppTheme.textTertiary
        }
    }

    private var background: Color {
        switch health {
        case .good: return AppTheme.okSoft
        case .watch: return AppTheme.warnSoft
        case .risk: return AppTheme.badSoft
        case .none: return AppTheme.blueSoft
        }
    }
}

struct KpiTile: View {
    let label: String
    let value: String
    var hint: String? = nil
    var tone: Tone = .plain
    var selected: Bool = false
    var action: (() -> Void)? = nil

    enum Tone {
        case plain, brand, good, watch, risk

        var fill: Color {
            switch self {
            case .plain: return AppTheme.card
            case .brand: return AppTheme.blueSoft
            case .good: return AppTheme.okSoft
            case .watch: return AppTheme.warnSoft
            case .risk: return AppTheme.badSoft
            }
        }

        var ink: Color {
            switch self {
            case .plain: return AppTheme.text
            case .brand: return AppTheme.blueDeep
            case .good: return AppTheme.ok
            case .watch: return AppTheme.warn
            case .risk: return AppTheme.bad
            }
        }

        var caption: Color {
            switch self {
            case .plain: return AppTheme.textSecondary
            default: return ink.opacity(0.85)
            }
        }
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { tile }
                    .buttonStyle(.plain)
            } else {
                tile
            }
        }
    }

    private var tile: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(tone.caption)
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(tone.ink)
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(tone.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .fill(tone.fill)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                        .stroke(selected ? tone.ink : (tone == .plain ? AppTheme.cardBorder : tone.ink.opacity(0.18)), lineWidth: selected ? 2 : 1)
                )
        )
    }
}

struct EmptyHint: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(AppTheme.blue)
            Text(title).font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

struct HubIconButton: View {
    let symbol: String
    var label: String = ""
    var emphasized: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(emphasized ? Color.white : AppTheme.blue)
                .frame(width: 40, height: 36)
                .background(
                    (emphasized ? AppTheme.blue : AppTheme.blueSoft),
                    in: Capsule(style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label.isEmpty ? symbol : label)
    }
}

struct HubNavLogo: View {
    var pulse: Bool = false
    var height: CGFloat = 32

    var body: some View {
        HStack(spacing: pulse ? -4 : 6) {
            BrandMarkImage(height: height)
            if pulse {
                HeartbeatTrace()
                    .frame(width: 168, height: max(22, height - 10))
                    .offset(x: -2)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("Fulfillment Heartbeat")
    }
}

struct HeartbeatTrace: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.periodic(from: .now, by: scenePhase == .active ? 0.12 : 60)) { timeline in
            Canvas { context, size in
                let path = Self.ecgPath(in: size)
                context.stroke(
                    path,
                    with: .color(AppTheme.blue.opacity(0.18)),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
                let cycle = 2.2
                let t = CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle)
                let head = t
                let tail = max(0, t - 0.18)
                if head > tail {
                    context.stroke(
                        path.trimmedPath(from: tail, to: head),
                        with: .color(AppTheme.blue),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    static func ecgPath(in size: CGSize) -> Path {
        var path = Path()
        let mid = size.height * 0.55
        let width = max(size.width, 1)
        let amp = size.height * 0.36

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * width, y: mid - y * amp)
        }

        path.move(to: point(0, 0))
        path.addLine(to: point(0.06, 0))
        path.addLine(to: point(0.10, 0.18))
        path.addLine(to: point(0.16, 0))
        path.addLine(to: point(0.20, -0.22))
        path.addLine(to: point(0.28, 1.0))
        path.addLine(to: point(0.34, -0.32))
        path.addLine(to: point(0.40, 0))
        path.addLine(to: point(0.50, 0.28))
        path.addLine(to: point(0.58, 0))
        path.addLine(to: point(1.0, 0))
        return path
    }
}

struct FilterBar: View {
    @EnvironmentObject private var store: HeartbeatStore
    @State private var showingFilters = false

    var body: some View {
        HStack(spacing: 8) {
            if store.filters.isActive {
                Button("Clear") { store.clearFilters() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
            }
            Button {
                showingFilters = true
            } label: {
                Label("Filters", systemImage: "line.3.horizontal.decrease.circle.fill")
            }
            .buttonStyle(BrandButtonStyle())
        }
        .sheet(isPresented: $showingFilters) {
            FilterSheet()
                .environmentObject(store)
        }
    }
}

struct FilterSheet: View {
    @EnvironmentObject private var store: HeartbeatStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                FilterSearchSection(
                    title: "Division",
                    prompt: "Search divisions",
                    allLabel: "All divisions",
                    selection: store.filters.division,
                    options: store.divisions.map { ($0, $0) },
                    onChange: store.setDivision
                )
                FilterSearchSection(
                    title: "District",
                    prompt: "Search districts",
                    allLabel: "All districts",
                    selection: store.filters.district,
                    options: store.districts.map { ($0, $0) },
                    onChange: store.setDistrict
                )
                FilterSearchSection(
                    title: "Operations manager",
                    prompt: "Search operations managers",
                    allLabel: "All operations managers",
                    selection: store.filters.om,
                    options: store.operationsOMs.map { ($0, $0) },
                    onChange: store.setOM
                )
                FilterSearchSection(
                    title: "Store #",
                    prompt: "Search store number",
                    allLabel: "All stores",
                    selection: store.filters.store,
                    options: store.stores.map { entry in
                        let label = entry.name.map { "\(entry.number) · \($0)" } ?? entry.number
                        return (entry.number, label)
                    },
                    onChange: store.setStore
                )
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if store.filters.isActive {
                        Button("Clear all") { store.clearFilters() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct FilterSearchSection: View {
    let title: String
    let prompt: String
    let allLabel: String
    let selection: String
    let options: [(id: String, label: String)]
    let onChange: (String) -> Void
    @State private var query = ""
    @FocusState private var focused: Bool

    private var filtered: [(id: String, label: String)] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return options }
        return options.filter {
            $0.label.localizedCaseInsensitiveContains(trimmed)
                || $0.id.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.blue)
                TextField(prompt, text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .onSubmit(applyExactOrFirst)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                onChange("")
                query = ""
            } label: {
                HStack {
                    Text(allLabel)
                    Spacer()
                    if selection.isEmpty {
                        Image(systemName: "checkmark")
                            .foregroundStyle(AppTheme.blue)
                    }
                }
            }
            ForEach(filtered, id: \.id) { item in
                Button {
                    onChange(item.id)
                    query = ""
                    focused = false
                } label: {
                    HStack {
                        Text(item.label)
                            .foregroundStyle(AppTheme.text)
                        Spacer()
                        if item.id == selection {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppTheme.blue)
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text(title)
                Spacer()
                if !selection.isEmpty {
                    Text(currentLabel)
                        .foregroundStyle(AppTheme.blue)
                }
            }
        } footer: {
            Text(query.isEmpty ? "\(options.count) options" : "\(filtered.count) of \(options.count) match")
        }
    }

    private var currentLabel: String {
        options.first(where: { $0.id == selection })?.label ?? selection
    }

    private func applyExactOrFirst() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            onChange("")
            return
        }
        if let exact = options.first(where: { $0.id.compare(trimmed, options: [.caseInsensitive, .numeric]) == .orderedSame }) {
            onChange(exact.id)
            query = ""
            focused = false
            return
        }
        if filtered.count == 1 {
            onChange(filtered[0].id)
            query = ""
            focused = false
        }
    }
}

struct StoreTable: View {
    let section: MetricSection
    let rows: [MetricRow]

    private enum Column: String, CaseIterable, Identifiable {
        case store, district, om, result, status
        var id: String { rawValue }

        func title(for section: MetricSection) -> String {
            switch self {
            case .store: return section == .pickerScorecard ? "Shopper" : "Store"
            case .district: return "District"
            case .om: return "OM"
            case .result:
                if section == .pph { return "PPH" }
                if section == .prepNotReady { return "PNR %" }
                return "Result"
            case .status: return "Status"
            }
        }
    }

    @State private var sort = Column.store
    @State private var ascending = true

    private var sortedRows: [MetricRow] {
        rows.sorted { lhs, rhs in
            let result = compare(lhs, rhs, by: sort)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    var body: some View {
        if rows.isEmpty {
            Section {
                EmptyHint(
                    symbol: "building.2",
                    title: "No stores in this view",
                    detail: "Adjust filters or upload a file for this section."
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
        } else {
            Section {
                ForEach(sortedRows) { row in
                    storeRow(row)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(AppTheme.card)
                }
            } header: {
                HStack(spacing: 0) {
                    ForEach(Column.allCases) { column in
                        sortHeader(column)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(AppTheme.card)
                .textCase(nil)
                .listRowInsets(EdgeInsets())
            }
        }
    }

    private func sortHeader(_ column: Column) -> some View {
        Button {
            if sort == column {
                ascending.toggle()
            } else {
                sort = column
                ascending = column == .result || column == .status ? false : true
            }
        } label: {
            HStack(spacing: 4) {
                Text(column.title(for: section).uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.6)
                if sort == column {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                }
            }
            .foregroundStyle(sort == column ? AppTheme.blue : AppTheme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func compare(_ lhs: MetricRow, _ rhs: MetricRow, by column: Column) -> ComparisonResult {
        switch column {
        case .store:
            if section == .pickerScorecard {
                return lhs.shopperName.localizedStandardCompare(rhs.shopperName)
            }
            if let a = Int(lhs.storeNumber), let b = Int(rhs.storeNumber) {
                return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
            }
            return lhs.storeNumber.localizedStandardCompare(rhs.storeNumber)
        case .district:
            return lhs.district.localizedStandardCompare(rhs.district)
        case .om:
            return lhs.operationsOM.localizedStandardCompare(rhs.operationsOM)
        case .result:
            let a = sortValue(lhs)
            let b = sortValue(rhs)
            if a == b { return .orderedSame }
            return a < b ? .orderedAscending : .orderedDescending
        case .status:
            let a = healthRank(HeartbeatMath.health(for: section, row: lhs))
            let b = healthRank(HeartbeatMath.health(for: section, row: rhs))
            if a == b { return compare(lhs, rhs, by: .result) }
            return a < b ? .orderedAscending : .orderedDescending
        }
    }

    private func healthRank(_ health: Health) -> Int {
        switch health {
        case .good: return 0
        case .watch: return 1
        case .risk: return 2
        case .none: return 3
        }
    }

    private func sortValue(_ row: MetricRow) -> Double {
        switch section {
        case .fiveStar: return row.number("star_rating") ?? -1
        case .pickPath: return row.number("compliance_pct") ?? -1
        case .prepNotReady: return row.number("pnr_rate_pct") ?? -1
        case .dynacap: return row.number("dynacap_rate", "pieces_per_hour") ?? (HeartbeatMath.dynacapAligned(row) == true ? 1 : 0)
        case .scheduleQuality: return row.number("schedule_efficiency_pct") ?? -1
        case .pph: return row.number("pph") ?? -1
        case .pickerScorecard: return HeartbeatMath.pickerComposite(row)
        }
    }

    private func storeRow(_ row: MetricRow) -> some View {
        let view = StoreCellViewModel.make(section: section, row: row)
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if section == .pickerScorecard {
                    Text(row.shopperName)
                        .font(.subheadline.weight(.semibold))
                    Text(row.storeNumber.isEmpty ? "—" : row.storeNumber)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    Text(row.storeNumber.isEmpty ? "—" : row.storeNumber)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    if section == .dynacap || section == .scheduleQuality || section == .fiveStar || section == .prepNotReady {
                        Text(row.division.isEmpty ? "—" : row.division)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else if let name = row.storeName, !name.isEmpty {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.district.isEmpty ? "—" : row.district)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.operationsOM.isEmpty ? "—" : row.operationsOM)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(view.primary)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text(view.extra)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HealthBadge(health: HeartbeatMath.health(for: section, row: row))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
    }
}

struct PickerShopperCard: View {
    let row: MetricRow
    var place: String

    var body: some View {
        let health = HeartbeatMath.pickerHealth(row)
        let metrics = HeartbeatMath.pickerMetricReadout(row)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.shopperName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Text(place)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            HStack(spacing: 8) {
                ForEach(metrics, id: \.name) { metric in
                    VStack(spacing: 3) {
                        Text(metric.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text(metric.value)
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(ink(metric.health))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(wash(metric.health))
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .fill(wash(health).opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .stroke(ink(health).opacity(0.35), lineWidth: 1.5)
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
        case .none: return AppTheme.card
        }
    }
}

struct PickerScoreTable: View {
    @EnvironmentObject private var store: HeartbeatStore
    var focus: PickerFocus = .all

    @State private var sort = PickerSort.pph
    @State private var ascending = true
    @State private var limit = 150

    private var total: Int { store.pickerCount(for: focus) }
    private var page: [MetricRow] {
        store.pickerPage(focus: focus, sort: sort, ascending: ascending, limit: limit)
    }

    var body: some View {
        Section {
            HStack {
                Text(pageCaption)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Menu {
                    ForEach(PickerSort.allCases) { option in
                        Button {
                            if sort == option {
                                ascending.toggle()
                            } else {
                                sort = option
                                ascending = option != .pph
                            }
                        } label: {
                            if sort == option {
                                Label(option.title, systemImage: ascending ? "chevron.up" : "chevron.down")
                            } else {
                                Text(option.title)
                            }
                        }
                    }
                } label: {
                    Label("Sort \(sort.title)", systemImage: "arrow.up.arrow.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.blue)
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 4, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(AppTheme.bg)
            .onChange(of: focus) { _, _ in
                limit = 150
            }
        }

        if total == 0 {
            Section {
                EmptyHint(
                    symbol: "person.2",
                    title: "No shoppers in \(focus.title.lowercased())",
                    detail: "Tap another callout above, or upload the weekly Picker Scorecard."
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
        } else {
            Section {
                ForEach(page) { row in
                    PickerShopperCard(row: row, place: place(for: row))
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
                if page.count < total {
                    Button {
                        limit += 150
                    } label: {
                        Text("Show more · \(page.count) of \(HeartbeatFormat.num(Double(total)))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 16, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
                }
            }
        }
    }

    private var pageCaption: String {
        if page.count < total {
            return "Showing \(page.count) of \(HeartbeatFormat.num(Double(total))) · \(focus.title)"
        }
        return "Showing \(HeartbeatFormat.num(Double(total))) · \(focus.title)"
    }

    private func place(for row: MetricRow) -> String {
        let division = row.division.isEmpty ? store.identity(forStore: row.storeNumber).division : row.division
        if row.storeNumber.isEmpty { return division.isEmpty ? "—" : division }
        if division.isEmpty { return row.storeNumber }
        return "\(row.storeNumber) · \(division)"
    }
}

struct HubChromeModifier: ViewModifier {
    @EnvironmentObject private var router: HubRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    var showBack: Bool

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .tint(AppTheme.blue)
            .toolbarBackground(AppTheme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 10) {
                        if sizeClass == .regular {
                            HubIconButton(symbol: "sidebar.left", label: "Menu", emphasized: true) {
                                router.toggleSidebar()
                            }
                        }
                        if showBack {
                            HubIconButton(symbol: "chevron.left", label: "Dashboard") {
                                router.open(.dashboard)
                            }
                        }
                    }
                }
            }
    }
}

extension View {
    func hubChrome(showBack: Bool = false) -> some View {
        modifier(HubChromeModifier(showBack: showBack))
    }
}

struct HideSystemSidebarToggle: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = Sentinel()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? Sentinel)?.hideSoon()
    }

    final class Sentinel: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            hideSoon()
        }

        func hideSoon() {
            hideNow()
            DispatchQueue.main.async { self.hideNow() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.hideNow() }
        }

        private func hideNow() {
            guard let root = window?.rootViewController else { return }
            hide(in: root)
        }

        private func hide(in controller: UIViewController) {
            if let split = controller as? UISplitViewController {
                split.displayModeButtonVisibility = .never
            }
            for child in controller.children {
                hide(in: child)
            }
            if let presented = controller.presentedViewController {
                hide(in: presented)
            }
        }
    }
}

struct FulfillmentChecklistCard: View {
    @EnvironmentObject private var store: HeartbeatStore
    @State private var expanded = false
    @State private var openSection: MetricSection?
    @State private var commentingID: String?
    @State private var recipientDraft = ""
    @State private var showingMail = false
    @State private var mailError: String?

    private var riskCount: Int {
        store.summaries.filter { $0.health == .risk }.count
    }

    private var watchCount: Int {
        store.summaries.filter { $0.health == .watch }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if expanded {
                visibilityStrip
                VStack(spacing: 8) {
                    ForEach(MetricSection.checklistSections) { section in
                        sectionBlock(section)
                    }
                }
                sendBar
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .fill(AppTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                        .stroke(borderColor, lineWidth: riskCount > 0 ? 1.5 : 1)
                )
        )
        .onChange(of: expanded) { _, isOpen in
            if isOpen, openSection == nil {
                openSection = MetricSection.checklistSections.first { store.summary(for: $0).health == .risk }
                    ?? MetricSection.checklistSections.first { store.summary(for: $0).health == .watch }
            }
        }
        .sheet(isPresented: $showingMail) {
            MailComposeView(
                recipients: store.checklistRecipients,
                subject: store.checklistEmailSubject(),
                html: store.checklistEmailHTML(),
                plain: store.checklistEmailText()
            ) { result in
                showingMail = false
                if result == .failed {
                    mailError = "Mail didn’t send. Check that this iPad has a Mail account, or copy the recap."
                }
            }
        }
        .alert("Couldn’t send", isPresented: Binding(
            get: { mailError != nil },
            set: { if !$0 { mailError = nil } }
        )) {
            Button("Copy recap") {
                UIPasteboard.general.string = store.checklistEmailText()
                mailError = nil
            }
            Button("OK", role: .cancel) { mailError = nil }
        } message: {
            Text(mailError ?? "")
        }
    }

    private var borderColor: Color {
        if riskCount > 0 { return AppTheme.bad.opacity(0.45) }
        if watchCount > 0 { return AppTheme.warn.opacity(0.45) }
        return AppTheme.cardBorder
    }

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("eCommerce Fulfillment Checklist")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                        if store.checklistOpenCount > 0 {
                            Text("\(store.checklistOpenCount) open")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.bad)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppTheme.badSoft, in: Capsule(style: .continuous))
                        }
                    }
                    Text(expanded ? store.filters.summary : collapsedSummary)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.blueSoft, in: Circle())
            }
        }
        .buttonStyle(.plain)
    }

    private var collapsedSummary: String {
        var parts: [String] = []
        if riskCount > 0 { parts.append("\(riskCount) at risk") }
        if watchCount > 0 { parts.append("\(watchCount) watch") }
        if store.pickerBoard.opportunityCount > 0 {
            parts.append("\(store.pickerBoard.opportunityCount) opportunity pickers")
        }
        if parts.isEmpty { return "All KPIs healthy in this filter" }
        return parts.joined(separator: " · ")
    }

    private var visibilityStrip: some View {
        HStack(spacing: 8) {
            compactStat("At risk", "\(riskCount)", riskCount > 0 ? AppTheme.bad : AppTheme.ok, riskCount > 0 ? AppTheme.badSoft : AppTheme.okSoft)
            compactStat("Watch", "\(watchCount)", watchCount > 0 ? AppTheme.warn : AppTheme.ok, watchCount > 0 ? AppTheme.warnSoft : AppTheme.okSoft)
            compactStat("Open", "\(store.checklistOpenCount)", store.checklistOpenCount > 0 ? AppTheme.warn : AppTheme.ok, store.checklistOpenCount > 0 ? AppTheme.warnSoft : AppTheme.okSoft)
        }
    }

    private func compactStat(_ label: String, _ value: String, _ ink: Color, _ wash: Color) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(ink)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(wash, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func visibleItems(for section: MetricSection) -> [ChecklistDriverItem] {
        var items: [ChecklistDriverItem] = []
        var seen = Set<String>()
        for group in store.checklistGroups(for: section) {
            for item in group.items {
                if seen.insert(item.title + "|" + item.subtitle).inserted {
                    items.append(item)
                }
                if items.count == 5 { return items }
            }
        }
        return items
    }

    private func previewLine(for items: [ChecklistDriverItem]) -> String {
        if items.isEmpty { return "No issues in this filter" }
        return items.prefix(3).map { "\($0.title.replacingOccurrences(of: "Store ", with: "#")) \($0.value)" }.joined(separator: "  ·  ")
    }

    private func sectionBlock(_ section: MetricSection) -> some View {
        let summary = store.summary(for: section)
        let items = visibleItems(for: section)
        let isOpen = openSection == section
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    openSection = isOpen ? nil : section
                    commentingID = nil
                }
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(headlineColor(summary.health))
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(section.short)
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            HealthBadge(health: summary.health)
                        }
                        if !isOpen {
                            Text(previewLine(for: items))
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Text(summary.headlineText)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(headlineColor(summary.health))
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(width: 28, height: 28)
                }
            }
            .buttonStyle(.plain)

            if isOpen {
                if items.isEmpty {
                    Text("Nothing to action in this filter.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        issueRow(item, section: section, rank: index + 1)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .fill(sectionWash(summary.health))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .stroke(headlineColor(summary.health).opacity(summary.health == .none ? 0.12 : 0.28), lineWidth: 1)
        )
    }

    private func issueRow(_ item: ChecklistDriverItem, section: MetricSection, rank: Int) -> some View {
        let action = store.checklistItem(for: item, section: section)
        let showComment = commentingID == item.id || !action.comment.isEmpty
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text("\(rank)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppTheme.blue)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.blueSoft, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(minWidth: 140, alignment: .leading)
                Text(item.value)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(headlineColor(item.health))
                    .frame(minWidth: 72, alignment: .trailing)
                Spacer(minLength: 8)
                HStack(spacing: 8) {
                    ForEach([ChecklistStatus.addressed, .followUp, .notCovered]) { status in
                        statusChip(status, selected: action.status == status) {
                            store.setChecklistStatus(status, for: item, section: section)
                        }
                    }
                }
                Button {
                    withAnimation { commentingID = showComment && commentingID == item.id ? nil : item.id }
                } label: {
                    Image(systemName: action.comment.isEmpty ? "text.bubble" : "text.bubble.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(action.comment.isEmpty ? AppTheme.textTertiary : AppTheme.blue)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.blueSoft.opacity(action.comment.isEmpty ? 0.45 : 1), in: Circle())
                }
                .buttonStyle(.plain)
            }
            if showComment {
                TextField("Note for follow up", text: commentBinding(item, section: section), axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .lineLimit(1...4)
                    .padding(12)
                    .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sectionWash(_ health: Health) -> Color {
        switch health {
        case .risk: return AppTheme.badSoft.opacity(0.45)
        case .watch: return AppTheme.warnSoft.opacity(0.45)
        case .good: return AppTheme.okSoft.opacity(0.35)
        case .none: return AppTheme.bg
        }
    }

    private func headlineColor(_ health: Health) -> Color {
        switch health {
        case .good: return AppTheme.ok
        case .watch: return AppTheme.warn
        case .risk: return AppTheme.bad
        case .none: return AppTheme.text
        }
    }

    private func statusChip(_ status: ChecklistStatus, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(status.shortLabel)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .foregroundStyle(selected ? .white : chipColor(status))
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? chipColor(status) : chipColor(status).opacity(0.14))
                )
        }
        .buttonStyle(.plain)
    }

    private func chipColor(_ status: ChecklistStatus) -> Color {
        switch status {
        case .open: return AppTheme.textTertiary
        case .addressed: return AppTheme.ok
        case .followUp: return AppTheme.warn
        case .notCovered: return AppTheme.blue
        }
    }

    private func commentBinding(_ item: ChecklistDriverItem, section: MetricSection) -> Binding<String> {
        Binding(
            get: { store.checklistItem(for: item, section: section).comment },
            set: { store.setChecklistComment($0, for: item, section: section) }
        )
    }

    private var sendBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("leader@company.com", text: $recipientDraft)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: AppTheme.radiusS, style: .continuous))
                    .onSubmit(addRecipient)
                Button("Add", action: addRecipient)
                    .buttonStyle(BrandButtonStyle())
                Button(action: sendChecklist) {
                    Label("Email", systemImage: "paperplane.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .opacity(store.canSendChecklist ? 1 : 0.55)
            }
            if !store.checklistRecipients.isEmpty {
                FlexibleEmailChips(emails: store.checklistRecipients) { email in
                    store.removeChecklistRecipient(email)
                }
            }
        }
        .padding(.top, 4)
    }

    private func addRecipient() {
        store.addChecklistRecipient(recipientDraft)
        recipientDraft = ""
    }

    private func sendChecklist() {
        if !recipientDraft.isEmpty { addRecipient() }
        guard store.canSendChecklist else {
            mailError = "Add at least one leader email, then tap Email."
            return
        }
        if MFMailComposeViewController.canSendMail() {
            showingMail = true
            return
        }
        let subject = store.checklistEmailSubject().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = store.checklistEmailText().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let to = store.checklistRecipients.joined(separator: ",")
        if let url = URL(string: "mailto:\(to)?subject=\(subject)&body=\(body)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return
        }
        UIPasteboard.general.string = store.checklistEmailText()
        mailError = "Mail isn’t set up on this iPad. The recap was copied so you can paste it into an email."
    }
}

struct FlexibleEmailChips: View {
    let emails: [String]
    let onRemove: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(emails, id: \.self) { email in
                HStack(spacing: 6) {
                    Text(email)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Button {
                        onRemove(email)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(AppTheme.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.blueSoft, in: Capsule(style: .continuous))
            }
        }
    }
}

struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let html: String
    let plain: String
    let onFinish: (MFMailComposeResult) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIViewController {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = context.coordinator
            mail.setToRecipients(recipients)
            mail.setSubject(subject)
            mail.setMessageBody(html, isHTML: true)
            return mail
        }
        let fallback = UIActivityViewController(activityItems: [plain], applicationActivities: nil)
        fallback.completionWithItemsHandler = { _, completed, _, _ in
            onFinish(completed ? .sent : .cancelled)
        }
        return fallback
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (MFMailComposeResult) -> Void
        init(onFinish: @escaping (MFMailComposeResult) -> Void) { self.onFinish = onFinish }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            onFinish(result)
        }
    }
}
