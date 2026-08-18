import SwiftUI
import UIKit

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
                        .stroke(tone == .plain ? AppTheme.cardBorder : tone.ink.opacity(0.18), lineWidth: 1)
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

    var body: some View {
        HStack(spacing: 6) {
            Image("HeartbeatMark")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(height: pulse ? 36 : 26)
                .accessibilityHidden(true)
            if pulse {
                HeartbeatTrace()
                    .frame(width: 260, height: 28)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("Fulfillment Heartbeat")
    }
}

struct HeartbeatTrace: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let path = Self.ecgPath(in: size)
                context.stroke(
                    path,
                    with: .color(AppTheme.blue.opacity(0.2)),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

                let cycle = 2.1
                let t = CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle)
                let head = t
                let tail = max(0, t - 0.16)
                if head > tail {
                    context.stroke(
                        path.trimmedPath(from: tail, to: head),
                        with: .color(AppTheme.blue),
                        style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
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

    var body: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(AppTheme.blue)
                    Text(store.filters.summary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                    if store.filters.isActive {
                        Button("Clear") { store.clearFilters() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.blue)
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 12) { fields }
                    VStack(alignment: .leading, spacing: 10) { fields }
                }
            }
        }
    }

    @ViewBuilder
    private var fields: some View {
        filterMenu("Division", selection: store.filters.division, options: store.divisions.map { ($0, $0) }) {
            store.setDivision($0)
        }
        filterMenu("District", selection: store.filters.district, options: store.districts.map { ($0, $0) }) {
            store.setDistrict($0)
        }
        filterMenu("Operations manager", selection: store.filters.om, options: store.operationsOMs.map { ($0, $0) }) {
            store.setOM($0)
        }
        filterMenu(
            "Store #",
            selection: store.filters.store,
            options: store.stores.map { entry in
                let label = entry.name.map { "\(entry.number) · \($0)" } ?? entry.number
                return (entry.number, label)
            }
        ) {
            store.setStore($0)
        }
    }

    private func filterMenu(
        _ title: String,
        selection: String,
        options: [(String, String)],
        onChange: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
            Menu {
                Button("All") { onChange("") }
                ForEach(options, id: \.0) { item in
                    Button(item.1) { onChange(item.0) }
                }
            } label: {
                HStack {
                    Text(label(for: selection, options: options))
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.radiusS, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
            }
        }
        .frame(minWidth: 160)
    }

    private func label(for selection: String, options: [(String, String)]) -> String {
        if selection.isEmpty { return "All" }
        return options.first(where: { $0.0 == selection })?.1 ?? selection
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

struct PickerScoreTable: View {
    @EnvironmentObject private var store: HeartbeatStore
    let rows: [MetricRow]

    private enum Column: String, CaseIterable, Identifiable {
        case picker, store, division, pph, ott, presub, oth, coe, orders, status
        var id: String { rawValue }
        var title: String {
            switch self {
            case .picker: return "Picker"
            case .store: return "Store"
            case .division: return "Division"
            case .pph: return "PPH"
            case .ott: return "OTT"
            case .presub: return "Presub"
            case .oth: return "OTH 5%"
            case .coe: return "COE"
            case .orders: return "Orders"
            case .status: return "Status"
            }
        }
    }

    @State private var sort = Column.pph
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
                    symbol: "person.2",
                    title: "No picker rows",
                    detail: "Upload the weekly Picker Scorecard workbook."
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
        } else {
            Section {
                ForEach(sortedRows) { row in
                    pickerRow(row)
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
                ascending = column == .picker || column == .division || column == .store
            }
        } label: {
            HStack(spacing: 4) {
                Text(column.title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.4)
                    .lineLimit(1)
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
        case .picker:
            return lhs.shopperName.localizedStandardCompare(rhs.shopperName)
        case .store:
            if let a = Int(lhs.storeNumber), let b = Int(rhs.storeNumber) {
                return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
            }
            return lhs.storeNumber.localizedStandardCompare(rhs.storeNumber)
        case .division:
            return lhs.division.localizedStandardCompare(rhs.division)
        case .pph:
            return numberOrder(lhs.number("pph"), rhs.number("pph"))
        case .ott:
            return numberOrder(lhs.number("ott_pct"), rhs.number("ott_pct"))
        case .presub:
            return numberOrder(lhs.number("presub_pct"), rhs.number("presub_pct"))
        case .oth:
            return numberOrder(lhs.number("oth5_pct"), rhs.number("oth5_pct"))
        case .coe:
            return numberOrder(lhs.number("coe_pct"), rhs.number("coe_pct"))
        case .orders:
            return numberOrder(lhs.number("orders"), rhs.number("orders"))
        case .status:
            let a = healthRank(HeartbeatMath.pickerHealth(lhs))
            let b = healthRank(HeartbeatMath.pickerHealth(rhs))
            if a == b { return numberOrder(lhs.number("pph"), rhs.number("pph")) }
            return a < b ? .orderedAscending : .orderedDescending
        }
    }

    private func numberOrder(_ lhs: Double?, _ rhs: Double?) -> ComparisonResult {
        let a = lhs ?? -9999
        let b = rhs ?? -9999
        if a == b { return .orderedSame }
        return a < b ? .orderedAscending : .orderedDescending
    }

    private func healthRank(_ health: Health) -> Int {
        switch health {
        case .good: return 0
        case .watch: return 1
        case .risk: return 2
        case .none: return 3
        }
    }

    private func pickerRow(_ row: MetricRow) -> some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.shopperName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(HeartbeatMath.pickerOpportunityText(row))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.storeNumber.isEmpty ? "—" : row.storeNumber)
                .font(.caption.monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(divisionLabel(for: row))
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            metricText(HeartbeatFormat.num(row.number("pph"), digits: 1), health: HeartbeatMath.pphHealth(row))
            metricText(HeartbeatFormat.pct(row.number("ott_pct")), health: HeartbeatMath.ottStar(row).health)
            metricText(HeartbeatFormat.pct(row.number("presub_pct")), health: HeartbeatMath.starMark(value: row.number("presub_pct"), full: 5, half: 6, invert: true).health)
            metricText(HeartbeatFormat.pct(row.number("oth5_pct")), health: HeartbeatMath.othStar(row).health)
            metricText(HeartbeatFormat.pct(row.number("coe_pct")), health: HeartbeatMath.coeStar(row).health)
            Text(HeartbeatFormat.num(row.number("orders")))
                .font(.caption.monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .leading)
            HealthBadge(health: HeartbeatMath.pickerHealth(row))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
    }

    private func metricText(_ value: String, health: Health) -> some View {
        let color: Color = {
            switch health {
            case .good: return AppTheme.ok
            case .watch: return AppTheme.warn
            case .risk: return AppTheme.bad
            case .none: return AppTheme.text
            }
        }()
        return Text(value)
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func divisionLabel(for row: MetricRow) -> String {
        if !row.division.isEmpty { return row.division }
        let division = store.identity(forStore: row.storeNumber).division
        return division.isEmpty ? "—" : division
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
                    HStack(spacing: 8) {
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
            .safeAreaInset(edge: .top, spacing: 0) {
                HubNavLogo(pulse: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                    .background(AppTheme.bg)
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

    private var riskCount: Int {
        store.summaries.filter { $0.health == .risk }.count
    }

    private var watchCount: Int {
        store.summaries.filter { $0.health == .watch }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if expanded {
                visibilityStrip
                ForEach(MetricSection.checklistSections) { section in
                    checklistRow(section)
                }
                sendBar
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .fill(AppTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                        .stroke(borderColor, lineWidth: riskCount > 0 ? 1.5 : 1)
                )
        )
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
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("eCommerce Fulfillment Checklist")
                            .font(.title2.weight(.semibold))
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
                        .multilineTextAlignment(.leading)
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
            callout(title: "At risk", value: "\(riskCount)", tone: riskCount > 0 ? .risk : .good)
            callout(title: "Watch", value: "\(watchCount)", tone: watchCount > 0 ? .watch : .good)
            callout(title: "Opportunity pickers", value: "\(store.pickerBoard.opportunityCount)", tone: store.pickerBoard.opportunityCount > 0 ? .risk : .good)
            callout(title: "Open items", value: "\(store.checklistOpenCount)", tone: store.checklistOpenCount > 0 ? .watch : .good)
        }
    }

    private func callout(title: String, value: String, tone: KpiTile.Tone) -> some View {
        KpiTile(label: title, value: value, tone: tone)
    }

    private func checklistRow(_ section: MetricSection) -> some View {
        let summary = store.summary(for: section)
        let item = store.checklistItem(for: section)
        let drivers = store.checklistDrivers(for: section)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(section.title)
                            .font(.headline)
                        HealthBadge(health: summary.health)
                    }
                    Text("\(summary.headlineLabel): \(summary.headlineText) · \(summary.secondary)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
            }
            if !drivers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section == .pickerScorecard ? "Pickers causing it" : "Stores causing it")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                    ForEach(drivers, id: \.self) { line in
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(AppTheme.text)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(driverBackground(summary.health), in: RoundedRectangle(cornerRadius: AppTheme.radiusS, style: .continuous))
            }
            HStack(spacing: 8) {
                ForEach([ChecklistStatus.fixed, .followUp, .notCovered]) { status in
                    statusChip(status, selected: item.status == status) {
                        store.setChecklistStatus(status, for: section)
                    }
                }
            }
            TextField("Comments for follow up", text: commentBinding(section), axis: .vertical)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .lineLimit(1...4)
                .padding(10)
                .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: AppTheme.radiusS, style: .continuous))
        }
        .padding(.top, 8)
        Divider().opacity(0.35)
    }

    private func driverBackground(_ health: Health) -> Color {
        switch health {
        case .risk: return AppTheme.badSoft
        case .watch: return AppTheme.warnSoft
        default: return AppTheme.bg
        }
    }

    private func statusChip(_ status: ChecklistStatus, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(status.label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
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
        case .fixed: return AppTheme.ok
        case .followUp: return AppTheme.warn
        case .notCovered: return AppTheme.blue
        }
    }

    private func commentBinding(_ section: MetricSection) -> Binding<String> {
        Binding(
            get: { store.checklistItem(for: section).comment },
            set: { store.setChecklistComment($0, for: section) }
        )
    }

    private var sendBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.checklistReadyToSend {
                ShareLink(
                    item: store.checklistEmailText(),
                    subject: Text(store.checklistEmailSubject()),
                    message: Text(store.checklistEmailText())
                ) {
                    Label("Email leaders", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button {} label: {
                    Label("Set a status on every KPI to email leaders", systemImage: "paperplane")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(true)
            }
        }
        .padding(.top, 4)
    }
}
