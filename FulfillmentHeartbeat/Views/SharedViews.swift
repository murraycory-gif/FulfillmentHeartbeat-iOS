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
    var prominent: Bool = false

    var body: some View {
        Text(prominent ? health.label.uppercased() : health.label)
            .font(prominent ? .subheadline.weight(.heavy) : .caption.weight(.semibold))
            .tracking(prominent ? 0.4 : 0)
            .padding(.horizontal, prominent ? 14 : 10)
            .padding(.vertical, prominent ? 8 : 5)
            .foregroundStyle(prominent ? Color.white : foreground)
            .background(prominent ? solid : background, in: Capsule(style: .continuous))
            .shadow(color: prominent ? solid.opacity(0.35) : .clear, radius: 6, y: 2)
    }

    private var solid: Color {
        switch health {
        case .good: return AppTheme.ok
        case .watch: return AppTheme.warn
        case .risk: return AppTheme.bad
        case .none: return AppTheme.textTertiary
        }
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

struct UpdatedStamp: View {
    let date: Date?
    var wide: Bool = false

    private var empty: Bool { date == nil }

    var body: some View {
        Text(empty ? "NO DATA" : HeartbeatFormat.updated(date))
            .font(.subheadline.weight(.heavy))
            .tracking(empty ? 0.3 : 0)
            .multilineTextAlignment(.center)
            .frame(maxWidth: wide ? .infinity : nil)
            .padding(.horizontal, wide ? 16 : 12)
            .padding(.vertical, wide ? 10 : 7)
            .foregroundStyle(empty ? AppTheme.text : AppTheme.blue)
            .background(
                empty ? AppTheme.warnSoft : AppTheme.blueSoft,
                in: Capsule(style: .continuous)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(empty ? AppTheme.warn.opacity(0.45) : AppTheme.blue.opacity(0.22), lineWidth: 1)
            )
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
        .frame(maxWidth: .infinity, minHeight: 176, maxHeight: 176, alignment: .topLeading)
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
    var body: some View {
        ECGPulseView()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct ECGPulseView: UIViewRepresentable {
    func makeUIView(context: Context) -> ECGPulseUIView {
        ECGPulseUIView()
    }

    func updateUIView(_ uiView: ECGPulseUIView, context: Context) {}
}

final class ECGPulseUIView: UIView {
    private let track = CAShapeLayer()
    private let pulse = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        track.fillColor = nil
        pulse.fillColor = nil
        track.lineCap = .round
        pulse.lineCap = .round
        track.lineJoin = .round
        pulse.lineJoin = .round
        track.lineWidth = 2
        pulse.lineWidth = 3
        track.strokeColor = UIColor(red: 0.15, green: 0.42, blue: 0.95, alpha: 0.18).cgColor
        pulse.strokeColor = UIColor(red: 0.15, green: 0.42, blue: 0.95, alpha: 1).cgColor
        layer.addSublayer(track)
        layer.addSublayer(pulse)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = Self.ecgPath(in: bounds)
        track.frame = bounds
        pulse.frame = bounds
        track.path = path
        pulse.path = path
        startAnimation()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            pulse.removeAnimation(forKey: "beat")
        } else {
            startAnimation()
        }
    }

    private func startAnimation() {
        guard window != nil, bounds.width > 1 else { return }
        guard pulse.animation(forKey: "beat") == nil else { return }
        let start = CABasicAnimation(keyPath: "strokeStart")
        start.fromValue = 0
        start.toValue = 1
        let end = CABasicAnimation(keyPath: "strokeEnd")
        end.fromValue = 0.18
        end.toValue = 1.18
        let group = CAAnimationGroup()
        group.animations = [start, end]
        group.duration = 1.7
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .linear)
        group.isRemovedOnCompletion = false
        pulse.add(group, forKey: "beat")
    }

    private static func ecgPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let mid = rect.height * 0.55
        let width = max(rect.width, 1)
        let amp = rect.height * 0.36
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
        .fullScreenCover(isPresented: $showingFilters) {
            FilterSheet()
                .environmentObject(store)
        }
    }
}

struct FilterSheet: View {
    @EnvironmentObject private var store: HeartbeatStore
    @Environment(\.dismiss) private var dismiss
    @State private var original = DashboardFilters()
    @State private var confirmLeave = false
    @State private var focus: FilterFocus = .division

    private var isDirty: Bool { store.filters != original }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                summaryRow
                focusPicker
                FilterColumn(
                    title: focus.title,
                    prompt: focus.prompt,
                    allLabel: focus.allLabel,
                    selection: selection(for: focus),
                    options: options(for: focus),
                    onChange: { apply($0, to: focus) }
                )
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { requestClose() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if store.filters.isActive {
                        Button("Clear all") { store.clearFilters() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .alert("Would you like to save your filters?", isPresented: $confirmLeave) {
                Button("Save") { dismiss() }
                Button("Don't Save", role: .destructive) {
                    store.filters = original
                    dismiss()
                }
                Button("Keep editing", role: .cancel) {}
            } message: {
                Text("You changed Division, District, OM, or Store. Save to apply them on the dashboard.")
            }
        }
        .interactiveDismissDisabled(isDirty)
        .onAppear { original = store.filters }
    }

    private func requestClose() {
        if isDirty {
            confirmLeave = true
        } else {
            dismiss()
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            filterChip(.division)
            filterChip(.district)
            filterChip(.om)
            filterChip(.store)
        }
    }

    private func filterChip(_ item: FilterFocus) -> some View {
        Button {
            focus = item
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.chipTitle.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.textTertiary)
                Text(display(for: item))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selection(for: item).isEmpty ? AppTheme.textSecondary : AppTheme.blue)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                item == focus ? AppTheme.blueSoft : AppTheme.card,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(item == focus ? AppTheme.blue : AppTheme.cardBorder, lineWidth: item == focus ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var focusPicker: some View {
        Text("Search or tap a row in \(focus.title)")
            .font(.subheadline)
            .foregroundStyle(AppTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selection(for focus: FilterFocus) -> String {
        switch focus {
        case .division: return store.filters.division
        case .district: return store.filters.district
        case .om: return store.filters.om
        case .store: return store.filters.store
        }
    }

    private func display(for focus: FilterFocus) -> String {
        let value = selection(for: focus)
        return value.isEmpty ? focus.allLabel : value
    }

    private func options(for focus: FilterFocus) -> [(id: String, label: String)] {
        switch focus {
        case .division: return store.divisions.map { ($0, $0) }
        case .district: return store.districts.map { ($0, $0) }
        case .om: return store.operationsOMs.map { ($0, $0) }
        case .store: return store.stores.map { entry in
            (entry.number, entry.name.map { "\(entry.number) · \($0)" } ?? entry.number)
        }
        }
    }

    private func apply(_ value: String, to focus: FilterFocus) {
        switch focus {
        case .division: store.setDivision(value)
        case .district: store.setDistrict(value)
        case .om: store.setOM(value)
        case .store: store.setStore(value)
        }
    }
}

enum FilterFocus: String, Sendable {
    case division
    case district
    case om
    case store

    var title: String {
        switch self {
        case .division: return "Division"
        case .district: return "District"
        case .om: return "Operations manager"
        case .store: return "Store #"
        }
    }

    var chipTitle: String {
        switch self {
        case .division: return "Division"
        case .district: return "District"
        case .om: return "OM"
        case .store: return "Store"
        }
    }

    var prompt: String {
        switch self {
        case .division: return "Type a division"
        case .district: return "Type a district"
        case .om: return "Type an OM name"
        case .store: return "Type a store number"
        }
    }

    var allLabel: String {
        switch self {
        case .division: return "All divisions"
        case .district: return "All districts"
        case .om: return "All operations managers"
        case .store: return "All stores"
        }
    }
}

struct FilterColumn: View {
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
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.blue)
                TextField(prompt, text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .font(.body)
                    .onSubmit(applyExactOrFirst)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(focused ? AppTheme.blue : AppTheme.cardBorder, lineWidth: focused ? 2 : 1)
            )

            Text(query.isEmpty ? "\(options.count) options · scroll or tap" : "\(filtered.count) of \(options.count) match")
                .font(.caption)
                .foregroundStyle(AppTheme.textTertiary)

            List {
                row(id: "", label: allLabel, selected: selection.isEmpty) {
                    onChange("")
                    query = ""
                    focused = false
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                ForEach(filtered, id: \.id) { item in
                    row(id: item.id, label: item.label, selected: item.id == selection) {
                        onChange(item.id)
                        query = ""
                        focused = false
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                if filtered.isEmpty {
                    Text("No matches")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.visible)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func row(id: String, label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(label)
                    .font(.body.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? AppTheme.blueDeep : AppTheme.text)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.blue)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(
                selected ? AppTheme.blueSoft : AppTheme.bg,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
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
        case .pickPath, .pickPathPicker: return row.number("compliance_pct") ?? -1
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

struct PickPathTable: View {
    @EnvironmentObject private var store: HeartbeatStore
    let rows: [MetricRow]

    private enum Column: String, CaseIterable, Identifiable {
        case store, path, pph, orders, status
        var id: String { rawValue }
        var title: String {
            switch self {
            case .store: return "Store"
            case .path: return "Pick Path"
            case .pph: return "Avg PPH"
            case .orders: return "Orders"
            case .status: return "Status"
            }
        }
    }

    @State private var sort = Column.path
    @State private var ascending = true

    private var sortedRows: [MetricRow] {
        rows.sorted { lhs, rhs in
            let result = compare(lhs, rhs)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    var body: some View {
        if rows.isEmpty {
            Section {
                EmptyHint(
                    symbol: "point.topleft.down.to.point.bottomright.curvepath",
                    title: "No stores in this view",
                    detail: "Tap Avg compliance to see every store, or pick another callout."
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
        } else {
            Section {
                HStack {
                    Text("\(HeartbeatFormat.num(Double(rows.count))) stores")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 2, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
            Section {
                HStack(spacing: 12) {
                    ForEach(Column.allCases) { column in
                        Button {
                            if sort == column {
                                ascending.toggle()
                            } else {
                                sort = column
                                ascending = column == .store
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(column.title.uppercased())
                                    .font(.caption2.weight(.semibold))
                                    .tracking(0.5)
                                if sort == column {
                                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                                        .font(.caption2.weight(.bold))
                                }
                            }
                            .foregroundStyle(sort == column ? AppTheme.blue : AppTheme.textTertiary)
                            .frame(maxWidth: column == .store ? 180 : .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)

                ForEach(sortedRows) { row in
                    PickPathStoreCard(row: row, pickers: store.pickPathPickers(forStore: row.storeNumber))
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
            }
        }
    }

    private func compare(_ lhs: MetricRow, _ rhs: MetricRow) -> ComparisonResult {
        switch sort {
        case .store:
            if let a = Int(lhs.storeNumber), let b = Int(rhs.storeNumber) {
                return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
            }
            return lhs.storeNumber.localizedStandardCompare(rhs.storeNumber)
        case .path:
            return numberOrder(lhs.number("compliance_pct"), rhs.number("compliance_pct"))
        case .pph:
            return numberOrder(lhs.number("pph"), rhs.number("pph"))
        case .orders:
            return numberOrder(lhs.number("orders") ?? lhs.number("picks_total"), rhs.number("orders") ?? rhs.number("picks_total"))
        case .status:
            let a = healthRank(HeartbeatMath.health(for: .pickPath, row: lhs))
            let b = healthRank(HeartbeatMath.health(for: .pickPath, row: rhs))
            if a == b { return numberOrder(lhs.number("compliance_pct"), rhs.number("compliance_pct")) }
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

struct PickPathStoreCard: View {
    let row: MetricRow
    var pickers: [MetricRow] = []
    @State private var expanded = false

    var body: some View {
        let health = HeartbeatMath.health(for: .pickPath, row: row)
        let pphHealth = row.number("pph") == nil ? Health.none : HeartbeatMath.pphHealth(row)
        let path = row.number("compliance_pct")
        let pph = row.number("pph")
        let orders = row.number("orders") ?? row.number("picks_total")
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.storeNumber.isEmpty ? "—" : row.storeNumber)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppTheme.text)
                    if !row.division.isEmpty {
                        Text("|")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text(row.division)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    HealthBadge(health: health, prominent: true)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.blueSoft, in: Circle())
                }
            }
            .buttonStyle(.plain)
            Text(metaLine)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 8) {
                metric("Pick Path", HeartbeatFormat.pct(path), health)
                metric("Avg PPH", HeartbeatFormat.num(pph, digits: 1), pphHealth)
                metric("Orders", HeartbeatFormat.num(orders), .none)
            }
            if expanded {
                pickerBlock
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .fill(wash(health).opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .stroke(ink(health).opacity(health == .none ? 0.15 : 0.45), lineWidth: health == .risk || health == .watch ? 2 : 1.5)
        )
    }

    private var metaLine: String {
        let district = row.district.isEmpty ? "—" : row.district
        let om = row.operationsOM.isEmpty ? "—" : row.operationsOM
        let pickerLabel = pickers.isEmpty ? "Tap to view pickers" : "\(pickers.count) picker\(pickers.count == 1 ? "" : "s") · tap to \(expanded ? "hide" : "view")"
        return "District \(district)  ·  \(om)  ·  \(pickerLabel)"
    }

    @ViewBuilder
    private var pickerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pickers")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.text)
            if pickers.isEmpty {
                Text("Upload Pick Path Compliance Picker and Picker ScoreCard to see shoppers for this store.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, 6)
            } else {
                ForEach(pickers) { picker in
                    pickerRow(picker)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.card.opacity(0.9))
        )
    }

    private func pickerRow(_ picker: MetricRow) -> some View {
        let health = HeartbeatMath.health(for: .pickPathPicker, row: picker)
        let pphHealth = picker.number("pph") == nil ? Health.none : HeartbeatMath.pphHealth(picker)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(picker.shopperName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Spacer()
                HealthBadge(health: health, prominent: true)
            }
            HStack(spacing: 8) {
                metric("Pick Path", HeartbeatFormat.pct(picker.number("compliance_pct")), health)
                metric("Avg PPH", HeartbeatFormat.num(picker.number("pph"), digits: 1), pphHealth)
                metric("Orders", HeartbeatFormat.num(picker.number("orders") ?? picker.number("picks_total")), .none)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(wash(health).opacity(0.7))
        )
    }

    private func metric(_ name: String, _ value: String, _ health: Health) -> some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(1)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(ink(health))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(wash(health))
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

struct DynacapTable: View {
    let rows: [MetricRow]

    private enum Column: String, CaseIterable, Identifiable {
        case store, rate, util, status
        var id: String { rawValue }
        var title: String {
            switch self {
            case .store: return "Store"
            case .rate: return "Pieces / hr"
            case .util: return "Utilization"
            case .status: return "Status"
            }
        }
    }

    @State private var sort = Column.rate
    @State private var ascending = false

    private var sortedRows: [MetricRow] {
        rows.sorted { lhs, rhs in
            let result = compare(lhs, rhs)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    var body: some View {
        if rows.isEmpty {
            Section {
                EmptyHint(
                    symbol: "slider.horizontal.3",
                    title: "No stores in this view",
                    detail: "Tap Avg pieces / hour to see every store, or pick another callout."
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
        } else {
            Section {
                HStack {
                    Text("\(HeartbeatFormat.num(Double(rows.count))) stores")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 2, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
            Section {
                HStack(spacing: 12) {
                    ForEach(Column.allCases) { column in
                        Button {
                            if sort == column {
                                ascending.toggle()
                            } else {
                                sort = column
                                ascending = column == .store
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(column.title.uppercased())
                                    .font(.caption2.weight(.semibold))
                                    .tracking(0.5)
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
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)

                ForEach(sortedRows) { row in
                    DynacapStoreCard(row: row)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
            }
        }
    }

    private func compare(_ lhs: MetricRow, _ rhs: MetricRow) -> ComparisonResult {
        switch sort {
        case .store:
            if let a = Int(lhs.storeNumber), let b = Int(rhs.storeNumber) {
                return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
            }
            return lhs.storeNumber.localizedStandardCompare(rhs.storeNumber)
        case .rate:
            return numberOrder(lhs.number("dynacap_rate", "pieces_per_hour"), rhs.number("dynacap_rate", "pieces_per_hour"))
        case .util:
            return numberOrder(lhs.number("utilization_pct"), rhs.number("utilization_pct"))
        case .status:
            let a = healthRank(HeartbeatMath.health(for: .dynacap, row: lhs))
            let b = healthRank(HeartbeatMath.health(for: .dynacap, row: rhs))
            if a == b { return numberOrder(lhs.number("dynacap_rate", "pieces_per_hour"), rhs.number("dynacap_rate", "pieces_per_hour")) }
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

struct DynacapStoreCard: View {
    let row: MetricRow

    var body: some View {
        let health = HeartbeatMath.health(for: .dynacap, row: row)
        let rate = row.number("dynacap_rate", "pieces_per_hour")
        let util = row.number("utilization_pct")
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(row.storeNumber.isEmpty ? "—" : row.storeNumber)
                    .font(.title3.weight(.semibold).monospacedDigit())
                if !row.division.isEmpty {
                    Text("|")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text(row.division)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                HealthBadge(health: health, prominent: true)
            }
            Text(metaLine)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 8) {
                metric("Pieces / hr", HeartbeatFormat.num(rate, digits: 1), health)
                metric("Utilization", HeartbeatFormat.pct(util), .none)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .fill(wash(health).opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .stroke(ink(health).opacity(health == .none ? 0.15 : 0.45), lineWidth: health == .risk || health == .watch ? 2 : 1.5)
        )
    }

    private var metaLine: String {
        let district = row.district.isEmpty ? "—" : row.district
        let om = row.operationsOM.isEmpty ? "—" : row.operationsOM
        return "District \(district)  ·  \(om)"
    }

    private func metric(_ name: String, _ value: String, _ health: Health) -> some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(1)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(ink(health))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(wash(health))
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

struct ScheduleTable: View {
    let rows: [MetricRow]

    private enum Column: String, CaseIterable, Identifiable {
        case store, efficiency, under, over, status
        var id: String { rawValue }
        var title: String {
            switch self {
            case .store: return "Store"
            case .efficiency: return "Efficiency"
            case .under: return "Under"
            case .over: return "Over"
            case .status: return "Status"
            }
        }
    }

    @State private var sort = Column.efficiency
    @State private var ascending = true
    @State private var ordered: [MetricRow] = []

    var body: some View {
        if rows.isEmpty {
            Section {
                EmptyHint(
                    symbol: "calendar.badge.clock",
                    title: "No stores in this view",
                    detail: "Tap Avg efficiency to see every store, or pick another callout."
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
        } else {
            Section {
                HStack {
                    Text("\(HeartbeatFormat.num(Double(rows.count))) stores")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 2, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
            Section {
                HStack(spacing: 12) {
                    ForEach(Column.allCases) { column in
                        Button {
                            let nextSort = sort == column ? sort : column
                            let nextAscending = sort == column ? !ascending : column == .store
                            sort = nextSort
                            ascending = nextAscending
                            rebuildOrder(sort: nextSort, ascending: nextAscending)
                        } label: {
                            HStack(spacing: 4) {
                                Text(column.title.uppercased())
                                    .font(.caption2.weight(.semibold))
                                    .tracking(0.5)
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
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)

                ForEach(ordered, id: \.storeNumber) { row in
                    ScheduleStoreCard(row: row)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
            }
            .transaction { $0.animation = nil }
            .onAppear { rebuildOrder(sort: sort, ascending: ascending) }
            .onChange(of: rows.count) { _, _ in rebuildOrder(sort: sort, ascending: ascending) }
        }
    }

    private func rebuildOrder(sort: Column, ascending: Bool) {
        ordered = rows.sorted { lhs, rhs in
            let result = compare(lhs, rhs, sort: sort)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    private func compare(_ lhs: MetricRow, _ rhs: MetricRow, sort: Column) -> ComparisonResult {
        switch sort {
        case .store:
            if let a = Int(lhs.storeNumber), let b = Int(rhs.storeNumber) {
                return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
            }
            return lhs.storeNumber.localizedStandardCompare(rhs.storeNumber)
        case .efficiency:
            return numberOrder(lhs.number("schedule_efficiency_pct"), rhs.number("schedule_efficiency_pct"))
        case .under:
            return numberOrder(lhs.number("under_schedule_pct", "under_scheduled"), rhs.number("under_schedule_pct", "under_scheduled"))
        case .over:
            return numberOrder(lhs.number("over_schedule_pct", "over_scheduled"), rhs.number("over_schedule_pct", "over_scheduled"))
        case .status:
            let a = healthRank(HeartbeatMath.health(for: .scheduleQuality, row: lhs))
            let b = healthRank(HeartbeatMath.health(for: .scheduleQuality, row: rhs))
            if a == b { return numberOrder(lhs.number("schedule_efficiency_pct"), rhs.number("schedule_efficiency_pct")) }
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

struct ScheduleStoreCard: View {
    let row: MetricRow

    var body: some View {
        let health = HeartbeatMath.health(for: .scheduleQuality, row: row)
        let efficiency = row.number("schedule_efficiency_pct")
        let under = row.number("under_schedule_pct", "under_scheduled")
        let over = row.number("over_schedule_pct", "over_scheduled")
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(row.storeNumber.isEmpty ? "—" : row.storeNumber)
                    .font(.title3.weight(.semibold).monospacedDigit())
                if !row.division.isEmpty {
                    Text("|")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text(row.division)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                HealthBadge(health: health, prominent: true)
            }
            Text(metaLine)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 8) {
                metric("Efficiency", HeartbeatFormat.pct(efficiency), HeartbeatMath.band(efficiency, good: HeartbeatMath.scheduleGoal, watch: HeartbeatMath.scheduleWatch))
                metric("Under", HeartbeatFormat.pct(under), HeartbeatMath.varianceHealth(under))
                metric("Over", HeartbeatFormat.pct(over), HeartbeatMath.varianceHealth(over))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .fill(wash(health).opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .stroke(ink(health).opacity(health == .none ? 0.15 : 0.45), lineWidth: health == .risk || health == .watch ? 2 : 1.5)
        )
    }

    private var metaLine: String {
        let district = row.district.isEmpty ? "—" : row.district
        let om = row.operationsOM.isEmpty ? "—" : row.operationsOM
        return "District \(district)  ·  \(om)"
    }

    private func metric(_ name: String, _ value: String, _ health: Health) -> some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(1)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(ink(health))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(wash(health))
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

struct PPHTable: View {
    @EnvironmentObject private var store: HeartbeatStore
    let rows: [MetricRow]

    private enum Column: String, CaseIterable, Identifiable {
        case store, pph, pickers, status
        var id: String { rawValue }
        var title: String {
            switch self {
            case .store: return "Store"
            case .pph: return "Pure PPH"
            case .pickers: return "Pickers"
            case .status: return "Status"
            }
        }
    }

    @State private var sort = Column.pph
    @State private var ascending = true
    @State private var ordered: [MetricRow] = []
    @State private var counts: [String: Int] = [:]

    var body: some View {
        if rows.isEmpty {
            Section {
                EmptyHint(
                    symbol: "speedometer",
                    title: "No stores in this view",
                    detail: "Tap Avg pure PPH to see every store, or pick another callout."
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
        } else {
            Section {
                HStack {
                    Text("\(HeartbeatFormat.num(Double(rows.count))) stores")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 2, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
            Section {
                HStack(spacing: 12) {
                    ForEach(Column.allCases) { column in
                        Button {
                            let nextSort = sort == column ? sort : column
                            let nextAscending = sort == column ? !ascending : column == .store
                            sort = nextSort
                            ascending = nextAscending
                            rebuildOrder(sort: nextSort, ascending: nextAscending)
                        } label: {
                            HStack(spacing: 4) {
                                Text(column.title.uppercased())
                                    .font(.caption2.weight(.semibold))
                                    .tracking(0.5)
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
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)

                ForEach(ordered, id: \.storeNumber) { row in
                    PPHStoreCard(row: row, pickerCount: counts[row.storeNumber] ?? 0)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
            }
            .transaction { $0.animation = nil }
            .onAppear { rebuildOrder(sort: sort, ascending: ascending) }
            .onChange(of: rows.count) { _, _ in rebuildOrder(sort: sort, ascending: ascending) }
        }
    }

    private func rebuildOrder(sort: Column, ascending: Bool) {
        var nextCounts: [String: Int] = [:]
        nextCounts.reserveCapacity(rows.count)
        for row in rows {
            nextCounts[row.storeNumber] = store.pphPickerCount(forStore: row.storeNumber)
        }
        let next = rows.sorted { lhs, rhs in
            let result = compare(lhs, rhs, sort: sort, counts: nextCounts)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
        counts = nextCounts
        ordered = next
    }

    private func compare(_ lhs: MetricRow, _ rhs: MetricRow, sort: Column, counts: [String: Int]) -> ComparisonResult {
        switch sort {
        case .store:
            if let a = Int(lhs.storeNumber), let b = Int(rhs.storeNumber) {
                return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
            }
            return lhs.storeNumber.localizedStandardCompare(rhs.storeNumber)
        case .pph:
            return numberOrder(lhs.number("pph"), rhs.number("pph"))
        case .pickers:
            return numberOrder(Double(counts[lhs.storeNumber] ?? 0), Double(counts[rhs.storeNumber] ?? 0))
        case .status:
            let a = healthRank(HeartbeatMath.health(for: .pph, row: lhs))
            let b = healthRank(HeartbeatMath.health(for: .pph, row: rhs))
            if a == b { return numberOrder(lhs.number("pph"), rhs.number("pph")) }
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

struct PPHStoreCard: View {
    @EnvironmentObject private var store: HeartbeatStore
    let row: MetricRow
    var pickerCount: Int = 0
    @State private var expanded = false

    private var pickers: [MetricRow] {
        expanded ? store.pphPickers(forStore: row.storeNumber) : []
    }

    var body: some View {
        let health = HeartbeatMath.health(for: .pph, row: row)
        let pph = row.number("pph")
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.storeNumber.isEmpty ? "—" : row.storeNumber)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppTheme.text)
                    if !row.division.isEmpty {
                        Text("|")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text(row.division)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    HealthBadge(health: health, prominent: true)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.blueSoft, in: Circle())
                }
            }
            .buttonStyle(.plain)
            Text(metaLine)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 8) {
                metric("Pure PPH", HeartbeatFormat.num(pph, digits: 1), health)
                metric("Pickers", HeartbeatFormat.num(Double(pickerCount)), .none)
                metric("Goal", "80.0", .none, brand: true)
            }
            if expanded {
                pickerBlock
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .fill(wash(health).opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .stroke(ink(health).opacity(health == .none ? 0.15 : 0.45), lineWidth: health == .risk || health == .watch ? 2 : 1.5)
        )
    }

    private var metaLine: String {
        let district = row.district.isEmpty ? "—" : row.district
        let om = row.operationsOM.isEmpty ? "—" : row.operationsOM
        let pickerLabel = pickerCount == 0
            ? "Tap to view pickers"
            : "\(pickerCount) picker\(pickerCount == 1 ? "" : "s") · tap to \(expanded ? "hide" : "view")"
        return "District \(district)  ·  \(om)  ·  \(pickerLabel)"
    }

    @ViewBuilder
    private var pickerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pickers · Pure PPH")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.text)
            if pickers.isEmpty {
                Text("Upload Picker ScoreCard so shoppers for this store can expand here with their Pure PPH.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, 6)
            } else {
                ForEach(pickers) { picker in
                    pickerRow(picker)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.card.opacity(0.9))
        )
    }

    private func pickerRow(_ picker: MetricRow) -> some View {
        let health = HeartbeatMath.pphHealth(picker)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(picker.shopperName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Spacer()
                HealthBadge(health: health, prominent: true)
            }
            HStack(spacing: 8) {
                metric("Pure PPH", HeartbeatFormat.num(picker.number("pph"), digits: 1), health)
                metric("Orders", HeartbeatFormat.num(picker.number("orders")), .none)
                metric("Hours", HeartbeatFormat.num(picker.number("pick_hours"), digits: 1), .none)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(wash(health).opacity(0.7))
        )
    }

    private func metric(_ name: String, _ value: String, _ health: Health, brand: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(1)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(brand ? AppTheme.blue : ink(health))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
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
        case .none: return AppTheme.card
        }
    }
}

struct PickerShopperCard: View {
    let row: MetricRow
    var place: String

    var body: some View {
        let health = HeartbeatMath.pickerHealth(row)
        let metrics = HeartbeatMath.pickerMetricReadout(row)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(row.shopperName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                if !row.storeNumber.isEmpty {
                    Text("|")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("Store \(row.storeNumber)")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                if !place.isEmpty, place != row.storeNumber {
                    Text(place)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
                ForEach(metrics, id: \.name) { metric in
                    VStack(spacing: 3) {
                        Text(metric.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(metric.value)
                            .font(.headline.weight(.bold).monospacedDigit())
                            .foregroundStyle(ink(metric.health))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
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
        return division
    }
}

struct HubChromeModifier: ViewModifier {
    @EnvironmentObject private var router: HubRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    var showBack: Bool
    var showsFilters: Bool

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .tint(AppTheme.blue)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(removing: .sidebarToggle)
            .safeAreaInset(edge: .top, spacing: 0) {
                HubBrandBar(showBack: showBack, showsFilters: showsFilters)
            }
    }
}

struct HubBrandBar: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    var showBack: Bool
    var showsFilters: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
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
            HubNavLogo(pulse: true, height: markHeight)
            VStack(alignment: .leading, spacing: 2) {
                Text("Fulfillment Heartbeat")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if showsFilters {
                FilterBar()
            }
            Text(BuildStamp.label)
                .font(.caption2.weight(.semibold).monospaced())
                .foregroundStyle(AppTheme.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.card, in: Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
                .accessibilityLabel("Build \(BuildStamp.label)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 64)
        .background(AppTheme.bg)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.cardBorder)
                .frame(height: 1)
        }
    }

    private var markHeight: CGFloat {
        sizeClass == .regular ? 44 : 34
    }

    private var statusLine: String {
        "\(store.filters.summary) · \(HeartbeatFormat.updated(store.lastUpload?.uploadedAt))"
    }
}

extension View {
    func hubChrome(showBack: Bool = false, showsFilters: Bool = false) -> some View {
        modifier(HubChromeModifier(showBack: showBack, showsFilters: showsFilters))
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

    @State private var pulseOn = false

    private var riskCount: Int {
        store.summaries.filter { $0.health == .risk }.count
    }

    private var watchCount: Int {
        store.summaries.filter { $0.health == .watch }.count
    }

    private var pulseHealth: Health {
        if riskCount > 0 { return .risk }
        if watchCount > 0 { return .watch }
        return .none
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
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .stroke(stroke, lineWidth: pulseHealth == .none ? 1 : 2.4)
                .opacity(pulseHealth == .none ? 1 : (pulseOn ? 1 : 0.22))
        )
        .onAppear {
            guard pulseHealth == .risk || pulseHealth == .watch else { return }
            pulseOn = false
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                pulseOn = true
            }
        }
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

    private var fill: Color {
        switch pulseHealth {
        case .good: return AppTheme.okSoft
        case .watch: return AppTheme.warnSoft
        case .risk: return AppTheme.badSoft
        case .none: return AppTheme.card
        }
    }

    private var stroke: Color {
        switch pulseHealth {
        case .good: return AppTheme.ok.opacity(0.28)
        case .watch: return AppTheme.warn
        case .risk: return AppTheme.bad
        case .none: return AppTheme.cardBorder
        }
    }

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Text("Heartbeat")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Text("|")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textTertiary)
                Text("ACTION ITEMS")
                    .font(.subheadline.weight(.heavy))
                    .tracking(0.4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundStyle(Color.white)
                    .background(AppTheme.bad, in: Capsule(style: .continuous))
                    .shadow(color: AppTheme.bad.opacity(0.35), radius: 6, y: 2)
                Text("\(store.checklistOpenCount) OPEN")
                    .font(.title3.weight(.heavy))
                    .tracking(0.4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .foregroundStyle(Color.white)
                    .background(
                        store.checklistOpenCount > 0 ? AppTheme.bad : AppTheme.ok,
                        in: Capsule(style: .continuous)
                    )
                    .shadow(
                        color: (store.checklistOpenCount > 0 ? AppTheme.bad : AppTheme.ok).opacity(0.35),
                        radius: 6,
                        y: 2
                    )
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
