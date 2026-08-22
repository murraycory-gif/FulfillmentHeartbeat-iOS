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

struct HubBanner: View {
    var icon: String
    var title: String
    var accessory: String? = nil
    var clipped: Bool = true

    var body: some View {
        let bar = HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let accessory, !accessory.isEmpty {
                    Text(accessory)
                        .font(.subheadline.weight(.semibold))
                        .opacity(0.9)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            Spacer(minLength: 8)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.blue)

        if clipped {
            bar.clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
        } else {
            bar
        }
    }
}

struct HubPanel<Content: View>: View {
    var icon: String
    var title: String
    var accessory: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HubBanner(icon: icon, title: title, accessory: accessory, clipped: false)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(AppTheme.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 2.5)
        )
    }
}

struct HubTableHeader: View {
    var icon: String
    var title: String
    var accessory: String
    var expanded: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(accessory)
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.9)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 8)
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .font(.headline.weight(.semibold))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.blue)
        .contentShape(Rectangle())
    }
}

struct PickerScoreCardTitle: View {
    var font: Font = .title2.weight(.semibold)

    var body: some View {
        PageHeadline(lead: "Picker", accent: "ScoreCard", font: font, showsFilter: false)
    }
}

struct PageHeadline: View {
    @EnvironmentObject private var store: HeartbeatStore
    var lead: String
    var accent: String? = nil
    var blurb: String? = nil
    var font: Font = .largeTitle.weight(.semibold)
    var showsFilter: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                titleText
                    .font(font)
                    .fixedSize(horizontal: true, vertical: false)
                if showsFilter {
                    Text("|")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.textTertiary)
                    filterSummaryText
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Spacer(minLength: 0)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityText)
            if let blurb, !blurb.isEmpty {
                Text(blurb)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var titleText: Text {
        if let accent, !accent.isEmpty {
            return Text(lead + " ") + Text(accent).foregroundStyle(AppTheme.blue)
        }
        return Text(lead)
    }

    private var filterSummaryText: Text {
        let parts = store.filters.summaryParts
        var result = Text("")
        for (index, part) in parts.enumerated() {
            if index > 0 {
                result = result + Text(" · ").foregroundStyle(AppTheme.textTertiary)
            }
            result = result + Text(part.text).foregroundStyle(part.active ? AppTheme.blue : AppTheme.text)
        }
        return result
    }

    private var accessibilityText: String {
        let name = accent == nil ? lead : "\(lead) \(accent!)"
        return showsFilter ? "\(name). \(store.filters.summary)" : name
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
    var compact: Bool = false

    var body: some View {
        Text(prominent ? health.label.uppercased() : health.label)
            .font(badgeFont)
            .tracking(compact ? 0 : (prominent ? 0.4 : 0))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .fixedSize(horizontal: true, vertical: true)
            .padding(.horizontal, compact ? 8 : (prominent ? 14 : 10))
            .padding(.vertical, compact ? 5 : (prominent ? 8 : 5))
            .foregroundStyle(prominent ? Color.white : foreground)
            .background(prominent ? solid : background, in: Capsule(style: .continuous))
            .shadow(color: prominent && !compact ? solid.opacity(0.35) : .clear, radius: compact ? 0 : 6, y: 2)
    }

    private var badgeFont: Font {
        if compact { return .caption.weight(.heavy) }
        return prominent ? .subheadline.weight(.heavy) : .caption.weight(.semibold)
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
    @State private var draft = DashboardFilters()
    @State private var confirmLeave = false
    @State private var focus: FilterFocus = .region

    private var isDirty: Bool { draft != original }

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
                    options: store.filterChoices(focus: focus, draft: draft),
                    onChange: { apply($0, to: focus) }
                )
                .id(focus)
                .transaction { $0.animation = nil }
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
                    if draft.isActive {
                        Button("Clear all") { applyDraft(DashboardFilters()) }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndClose() }
                        .fontWeight(.bold)
                }
            }
            .alert("Would you like to save your filters?", isPresented: $confirmLeave) {
                Button("Save") { saveAndClose() }
                Button("Don't Save", role: .destructive) {
                    store.commitFilters(original)
                    dismiss()
                }
                Button("Keep editing", role: .cancel) {}
            } message: {
                Text("You changed Region, Division, District, OM, or Store. Save to apply them on the dashboard.")
            }
        }
        .interactiveDismissDisabled(isDirty)
        .onAppear {
            original = store.filters
            draft = store.filters
        }
    }

    private func saveAndClose() {
        store.commitFilters(draft)
        dismiss()
    }

    private func requestClose() {
        if isDirty {
            confirmLeave = true
        } else {
            dismiss()
        }
    }

    private var summaryRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                filterChip(.region)
                filterChip(.division)
            }
            HStack(spacing: 10) {
                filterChip(.district)
                filterChip(.om)
                filterChip(.store)
            }
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
        case .region: return draft.region
        case .division: return draft.division
        case .district: return draft.district
        case .om: return draft.om
        case .store: return draft.store
        }
    }

    private func display(for focus: FilterFocus) -> String {
        let value = selection(for: focus)
        return value.isEmpty ? focus.allLabel : value
    }

    private func apply(_ value: String, to focus: FilterFocus) {
        var next = draft
        switch focus {
        case .region:
            next = DashboardFilters(region: value, division: "", district: "", om: "", store: "")
        case .division:
            next.division = value
            next.district = ""
            next.om = ""
            next.store = ""
            if value.isEmpty {
                // keep region
            } else if let match = MarketRegion.containing(value) {
                next.region = match.rawValue
            }
        case .district:
            next.district = value
            next.om = ""
            next.store = ""
        case .om:
            next.om = value
            next.store = ""
        case .store:
            next.store = value
        }
        applyDraft(next)
    }

    private func applyDraft(_ next: DashboardFilters) {
        draft = next
        Task { @MainActor in
            await Task.yield()
            store.commitFilters(next)
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
                if section == .lostRevenue { return "Lost $" }
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
        case .labor: return row.number("target_vs_actual_pct") ?? -1
        case .pickerScorecard: return HeartbeatMath.pickerComposite(row)
        case .lostRevenue: return row.number("lost_revenue") ?? -1
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
                    if section == .dynacap || section == .scheduleQuality || section == .fiveStar || section == .prepNotReady || section == .lostRevenue {
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
    @EnvironmentObject private var headerPin: LaborHeaderPin
    let rows: [MetricRow]

    private enum Column: String, CaseIterable, Identifiable {
        case store, path, pph, orders, status
        var id: String { rawValue }
        var key: String {
            switch self {
            case .store: return "label"
            case .path: return "path"
            case .pph: return "pph"
            case .orders: return "orders"
            case .status: return "status"
            }
        }
    }

    @State private var sort = Column.path
    @State private var ascending = true
    @State private var snaps: [PickPathLineSnap] = []
    @State private var openStore: String?

    private var expanded: Bool { headerPin.storesExpanded }

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
                Button {
                    let next = !headerPin.storesExpanded
                    headerPin.storesExpanded = next
                    headerPin.tableOpen = next
                    if !next { headerPin.pinned = false }
                    if next { rebuildOrder(sort: sort, ascending: ascending) }
                } label: {
                    HubTableHeader(
                            icon: "storefront.fill",
                            title: "Store",
                            accessory: "\(HeartbeatFormat.num(Double(rows.count))) stores  ·  tap to \(expanded ? "collapse" : "expand")",
                            expanded: expanded
                        )
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 2.5)
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: expanded ? 4 : 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
                .onAppear {
                    headerPin.tableOpen = headerPin.storesExpanded
                    headerPin.storeCount = rows.count
                    headerPin.active = sort.key
                    headerPin.ascending = ascending
                    headerPin.onSelect = applyHeaderSort
                }
            }
            if expanded {
                Section {
                    PickPathMetricHeader(
                        label: "Store",
                        showCount: false,
                        active: sort.key,
                        ascending: ascending,
                        onSelect: applyHeaderSort
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: LaborHeaderMinYKey.self,
                                value: (geo.frame(in: .global).minY / 12).rounded() * 12
                            )
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 2, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
                    ForEach(snaps) { snap in
                        PickPathStoreRow(
                            snap: snap,
                            expanded: openStore == snap.storeNumber,
                            onToggle: {
                                openStore = openStore == snap.storeNumber ? nil : snap.storeNumber
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                    }
                }
                .transaction { $0.animation = nil }
                .onAppear { rebuildOrder(sort: sort, ascending: ascending) }
                .onChange(of: rows.count) { _, _ in
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
                .onChange(of: rows.first?.storeNumber) { _, _ in
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
            }
        }
    }

    private func applyHeaderSort(_ key: String) {
        let column = Column.allCases.first { $0.key == key } ?? .path
        let nextAscending = sort == column ? !ascending : column == .store
        sort = column
        ascending = nextAscending
        headerPin.active = column.key
        headerPin.ascending = nextAscending
        rebuildOrder(sort: column, ascending: nextAscending)
    }

    private func rebuildOrder(sort: Column, ascending: Bool) {
        snaps = rows.sorted { lhs, rhs in
            let result = compare(lhs, rhs, sort: sort)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }.map(PickPathLineSnap.init)
    }

    private func compare(_ lhs: MetricRow, _ rhs: MetricRow, sort: Column) -> ComparisonResult {
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
            return numberOrder(PickPathMath.orders(lhs), PickPathMath.orders(rhs))
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

private enum PickPathMath {
    static func orders(_ row: MetricRow) -> Double? {
        row.number("orders") ?? row.number("picks_total")
    }

    static func pathHealth(_ value: Double?) -> Health {
        guard value != nil else { return .none }
        return HeartbeatMath.band(value, good: HeartbeatMath.pickPathGoal, watch: HeartbeatMath.pickPathRisk)
    }

    static func pphHealth(_ value: Double?) -> Health {
        guard value != nil else { return .none }
        return HeartbeatMath.band(value, good: HeartbeatMath.pphGoal, watch: HeartbeatMath.pphRisk)
    }
}

private struct PickPathRollupRow: Identifiable {
    let id: String
    let label: String
    let storeCount: Int
    let path: Double?
    let pph: Double?
    let orders: Double?

    var health: Health { PickPathMath.pathHealth(path) }
}

private enum PickPathRollupBuilder {
    static func grain(for filters: DashboardFilters) -> LaborRollupGrain? {
        LaborRollupBuilder.grain(for: filters)
    }

    static func source(from all: [MetricRow], filters: DashboardFilters) -> [MetricRow] {
        let stores = all.filter { !$0.storeNumber.isEmpty }
        if !filters.division.isEmpty || !filters.region.isEmpty {
            return stores.filter { filters.includesDivision($0.division) }
        }
        if !filters.district.isEmpty {
            let divisions = Set(
                stores.filter { HeartbeatMath.matches($0.district, filters.district) }.map(\.division)
            )
            return stores.filter { divisions.contains($0.division) }
        }
        if !filters.om.isEmpty {
            let divisions = Set(
                stores.filter { HeartbeatMath.matches($0.operationsOM, filters.om) }.map(\.division)
            )
            return stores.filter { divisions.contains($0.division) }
        }
        return stores
    }

    static func rows(from stores: [MetricRow], grain: LaborRollupGrain) -> [PickPathRollupRow] {
        var buckets: [String: [MetricRow]] = [:]
        for row in stores {
            let key: String
            switch grain {
            case .division:
                key = row.division.isEmpty ? "Unassigned" : MarketRegion.canonicalName(row.division)
            case .district:
                key = row.district.isEmpty ? "Unassigned" : row.district
            case .store:
                key = HeartbeatMath.canonicalStore(row.storeNumber)
            }
            guard !key.isEmpty else { continue }
            buckets[key, default: []].append(row)
        }
        var result: [PickPathRollupRow] = []
        result.reserveCapacity(buckets.count)
        for (key, group) in buckets {
            let label: String
            switch grain {
            case .division, .district:
                label = key
            case .store:
                let division = group.first?.division ?? ""
                label = division.isEmpty ? key : "\(key)  |  \(division)"
            }
            let orderValues = group.compactMap(PickPathMath.orders)
            result.append(
                PickPathRollupRow(
                    id: key,
                    label: label,
                    storeCount: group.count,
                    path: HeartbeatMath.average(group.compactMap { $0.number("compliance_pct") }),
                    pph: HeartbeatMath.average(group.compactMap { $0.number("pph") }),
                    orders: orderValues.isEmpty ? nil : orderValues.reduce(0, +)
                )
            )
        }
        return result.sorted { ($0.path ?? 999) < ($1.path ?? 999) }
    }
}

private struct PickPathLineSnap: Identifiable, Equatable {
    let id: UUID
    let storeNumber: String
    let label: String
    let district: String
    let om: String
    let path: String
    let pph: String
    let orders: String
    let health: Health
    let pathHealth: Health
    let pphHealth: Health
    let pathValue: Double
    let pphValue: Double
    let ordersValue: Double

    init(_ row: MetricRow) {
        id = row.id
        storeNumber = row.storeNumber
        label = row.division.isEmpty
            ? (row.storeNumber.isEmpty ? "—" : row.storeNumber)
            : "\(row.storeNumber)  |  \(row.division)"
        district = row.district
        om = row.operationsOM
        let pathNum = row.number("compliance_pct")
        let pphNum = row.number("pph")
        let ordersNum = PickPathMath.orders(row)
        path = HeartbeatFormat.pct(pathNum)
        pph = HeartbeatFormat.num(pphNum, digits: 1)
        orders = HeartbeatFormat.num(ordersNum)
        health = HeartbeatMath.health(for: .pickPath, row: row)
        pathHealth = PickPathMath.pathHealth(pathNum)
        pphHealth = PickPathMath.pphHealth(pphNum)
        pathValue = pathNum ?? -1
        pphValue = pphNum ?? -1
        ordersValue = ordersNum ?? -1
    }
}

private struct PickPathCheapLine: View, Equatable {
    let snap: PickPathLineSnap
    let expanded: Bool

    var body: some View {
        HStack(spacing: 6) {
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
            .frame(minWidth: 132, maxWidth: 190, alignment: .leading)
            cell(snap.path, snap.pathHealth)
            cell(snap.pph, snap.pphHealth)
            cell(snap.orders, .none)
            Text(snap.health.label.uppercased())
                .font(.caption.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .foregroundStyle(Color.white)
                .background(pill(snap.health), in: Capsule())
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private func cell(_ value: String, _ health: Health) -> some View {
        Text(value)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(ink(health))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
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

private struct PickPathMetricLine: View, Equatable {
    let label: String
    var count: Int? = nil
    let path: Double?
    let pph: Double?
    let orders: Double?

    var body: some View {
        let health = PickPathMath.pathHealth(path)
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
            cell(HeartbeatFormat.pct(path), health)
            cell(HeartbeatFormat.num(pph, digits: 1), PickPathMath.pphHealth(pph))
            cell(HeartbeatFormat.num(orders), .none)
            HealthBadge(health: health, prominent: true, compact: true)
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private func cell(_ value: String, _ health: Health) -> some View {
        Text(value)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(ink(health))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
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
        case .none: return Color.clear
        }
    }
}

struct PickPathMetricHeader: View {
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
            head("Pick Path", key: "path")
            head("Avg PPH", key: "pph")
            head("Orders", key: "orders")
            head("Status", key: "status", alignment: .trailing)
                .frame(width: 88, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .tracking(0.4)
        .lineLimit(1)
        .minimumScaleFactor(0.65)
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
        .foregroundStyle(selected ? AppTheme.blue : AppTheme.textTertiary)
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

struct PickPathStickyStoreHeader: View {
    @EnvironmentObject private var pin: LaborHeaderPin

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
            PickPathMetricHeader(
                label: "Store",
                showCount: false,
                active: pin.active,
                ascending: pin.ascending,
                onSelect: { pin.onSelect?($0) }
            )
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

struct PickPathRollupTable: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var headerPin: LaborHeaderPin

    private var expanded: Bool { headerPin.rollupExpanded }

    var body: some View {
        if let grain, !summary.isEmpty {
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
                    VStack(alignment: .leading, spacing: 10) {
                    PickPathMetricHeader(label: grain.columnTitle, showCount: grain != .store)
                    ForEach(summary) { row in
                        PickPathMetricLine(
                            label: row.label,
                            count: grain == .store ? nil : row.storeCount,
                            path: row.path,
                            pph: row.pph,
                            orders: row.orders
                        )
                    }
                                    }
                    .padding(16)
                }
            }
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .stroke(AppTheme.blue, lineWidth: 2.5)
            )
        }
    }

    private var grain: LaborRollupGrain? {
        PickPathRollupBuilder.grain(for: store.filters)
    }

    private var summary: [PickPathRollupRow] {
        guard let grain else { return [] }
        let source = PickPathRollupBuilder.source(from: store.displayRows(for: .pickPath), filters: store.filters)
        var rows = PickPathRollupBuilder.rows(from: source, grain: grain)
        if grain == .division {
            for extra in RollupMarketFill.missingDivisions(present: rows.map(\.label), markets: store.marketStores(), filters: store.filters) {
                rows.append(PickPathRollupRow(id: extra.name, label: extra.name, storeCount: extra.storeCount, path: nil, pph: nil, orders: nil))
            }
            rows.sort { ($0.path ?? 999) < ($1.path ?? 999) }
        }
        return rows
    }
}

private struct PickPathStoreRow: View {
    let snap: PickPathLineSnap
    let expanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 10 : 0) {
            Button(action: onToggle) {
                PickPathCheapLine(snap: snap, expanded: expanded)
                    .equatable()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                PickPathStoreExpand(snap: snap)
            }
        }
    }
}

private struct PickPathStoreExpand: View {
    @EnvironmentObject private var store: HeartbeatStore
    let snap: PickPathLineSnap

    private var pickers: [MetricRow] {
        store.pickPathPickers(forStore: snap.storeNumber).sorted {
            ($0.number("compliance_pct") ?? 999) < ($1.number("compliance_pct") ?? 999)
        }
    }

    private var chips: [(String, String, Health)] {
        [
            ("Pick Path", snap.path, snap.pathHealth),
            ("Avg PPH", snap.pph, snap.pphHealth),
            ("Orders", snap.orders, .none),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("District \(snap.district.isEmpty ? "—" : snap.district)  ·  \(snap.om.isEmpty ? "—" : snap.om)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            chipGrid
            pickerBlock
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.card.opacity(0.9))
        )
    }

    private var chipGrid: some View {
        HStack(spacing: 8) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, item in
                metric(item.0, item.1, item.2)
            }
        }
    }

    @ViewBuilder
    private var pickerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pickers.isEmpty ? "Pickers" : "Pickers  ·  \(pickers.count)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.text)
            if pickers.isEmpty {
                Text("Upload Pick Path Compliance Picker and Picker ScoreCard to see shoppers for this store.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, 6)
            } else {
                HStack(spacing: 6) {
                    Text("PICKER")
                        .frame(minWidth: 132, maxWidth: 190, alignment: .leading)
                    Text("PICK PATH")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("AVG PPH")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("ORDERS")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("STATUS")
                        .frame(width: 88, alignment: .trailing)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .tracking(0.4)
                ForEach(pickers) { picker in
                    pickerLine(picker)
                }
            }
        }
    }

    private func pickerLine(_ picker: MetricRow) -> some View {
        let health = HeartbeatMath.health(for: .pickPathPicker, row: picker)
        let path = picker.number("compliance_pct")
        let pph = picker.number("pph")
        let orders = PickPathMath.orders(picker)
        return HStack(spacing: 6) {
            Text(picker.shopperName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: 132, maxWidth: 190, alignment: .leading)
            cell(HeartbeatFormat.pct(path), health)
            cell(HeartbeatFormat.num(pph, digits: 1), PickPathMath.pphHealth(pph))
            cell(HeartbeatFormat.num(orders), .none)
            Text(health.label.uppercased())
                .font(.caption.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .foregroundStyle(Color.white)
                .background(pill(health), in: Capsule())
                .frame(width: 88, alignment: .trailing)
        }
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
            HealthBadge(health: health)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(wash(health))
        )
    }

    private func cell(_ value: String, _ health: Health) -> some View {
        Text(value)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(ink(health))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
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
        case .none: return AppTheme.card
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

struct DynacapTable: View {
    @EnvironmentObject private var headerPin: LaborHeaderPin
    let rows: [MetricRow]

    private enum Column: String, CaseIterable, Identifiable {
        case store, rate, goal, util, status
        var id: String { rawValue }
        var key: String {
            switch self {
            case .store: return "label"
            case .rate: return "rate"
            case .goal: return "goal"
            case .util: return "util"
            case .status: return "status"
            }
        }
    }

    @State private var sort = Column.rate
    @State private var ascending = false
    @State private var snaps: [DynacapLineSnap] = []
    @State private var openStore: String?

    private var expanded: Bool { headerPin.storesExpanded }

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
                Button {
                    let next = !headerPin.storesExpanded
                    headerPin.storesExpanded = next
                    headerPin.tableOpen = next
                    if !next { headerPin.pinned = false }
                    if next { rebuildOrder(sort: sort, ascending: ascending) }
                } label: {
                    HubTableHeader(
                            icon: "storefront.fill",
                            title: "Store",
                            accessory: "\(HeartbeatFormat.num(Double(rows.count))) stores  ·  tap to \(expanded ? "collapse" : "expand")",
                            expanded: expanded
                        )
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 2.5)
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: expanded ? 4 : 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
                .onAppear {
                    headerPin.tableOpen = headerPin.storesExpanded
                    headerPin.storeCount = rows.count
                    headerPin.active = sort.key
                    headerPin.ascending = ascending
                    headerPin.onSelect = applyHeaderSort
                }
            }
            if expanded {
                Section {
                    DynacapMetricHeader(
                        label: "Store",
                        showCount: false,
                        active: sort.key,
                        ascending: ascending,
                        onSelect: applyHeaderSort
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: LaborHeaderMinYKey.self,
                                value: (geo.frame(in: .global).minY / 12).rounded() * 12
                            )
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 2, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
                    ForEach(snaps) { snap in
                        DynacapStoreRow(
                            snap: snap,
                            expanded: openStore == snap.storeNumber,
                            onToggle: {
                                openStore = openStore == snap.storeNumber ? nil : snap.storeNumber
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                    }
                }
                .transaction { $0.animation = nil }
                .onAppear { rebuildOrder(sort: sort, ascending: ascending) }
                .onChange(of: rows.count) { _, _ in
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
                .onChange(of: rows.first?.storeNumber) { _, _ in
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
            }
        }
    }

    private func applyHeaderSort(_ key: String) {
        let column = Column.allCases.first { $0.key == key } ?? .rate
        let nextAscending = sort == column ? !ascending : column == .store
        sort = column
        ascending = nextAscending
        headerPin.active = column.key
        headerPin.ascending = nextAscending
        rebuildOrder(sort: column, ascending: nextAscending)
    }

    private func rebuildOrder(sort: Column, ascending: Bool) {
        snaps = rows.sorted { lhs, rhs in
            let result = compare(lhs, rhs, sort: sort)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }.map(DynacapLineSnap.init)
    }

    private func compare(_ lhs: MetricRow, _ rhs: MetricRow, sort: Column) -> ComparisonResult {
        switch sort {
        case .store:
            if let a = Int(lhs.storeNumber), let b = Int(rhs.storeNumber) {
                return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
            }
            return lhs.storeNumber.localizedStandardCompare(rhs.storeNumber)
        case .rate, .goal:
            return numberOrder(DynacapMath.rate(lhs), DynacapMath.rate(rhs))
        case .util:
            return numberOrder(lhs.number("utilization_pct"), rhs.number("utilization_pct"))
        case .status:
            let a = healthRank(HeartbeatMath.health(for: .dynacap, row: lhs))
            let b = healthRank(HeartbeatMath.health(for: .dynacap, row: rhs))
            if a == b { return numberOrder(DynacapMath.rate(lhs), DynacapMath.rate(rhs)) }
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

private enum DynacapMath {
    static let goalText = "65.0"

    static func rate(_ row: MetricRow) -> Double? {
        row.number("dynacap_rate", "pieces_per_hour")
    }

    static func rateHealth(_ value: Double?) -> Health {
        guard value != nil else { return .none }
        return HeartbeatMath.band(value, good: HeartbeatMath.dynacapGoal, watch: HeartbeatMath.dynacapRisk)
    }
}

private struct DynacapRollupRow: Identifiable {
    let id: String
    let label: String
    let storeCount: Int
    let rate: Double?
    let util: Double?

    var health: Health { DynacapMath.rateHealth(rate) }
}

private enum DynacapRollupBuilder {
    static func grain(for filters: DashboardFilters) -> LaborRollupGrain? {
        LaborRollupBuilder.grain(for: filters)
    }

    static func source(from all: [MetricRow], filters: DashboardFilters) -> [MetricRow] {
        let stores = all.filter { !$0.storeNumber.isEmpty && DynacapMath.rate($0) != nil }
        if !filters.division.isEmpty || !filters.region.isEmpty {
            return stores.filter { filters.includesDivision($0.division) }
        }
        if !filters.district.isEmpty {
            let divisions = Set(
                stores.filter { HeartbeatMath.matches($0.district, filters.district) }.map(\.division)
            )
            return stores.filter { divisions.contains($0.division) }
        }
        if !filters.om.isEmpty {
            let divisions = Set(
                stores.filter { HeartbeatMath.matches($0.operationsOM, filters.om) }.map(\.division)
            )
            return stores.filter { divisions.contains($0.division) }
        }
        return stores
    }

    static func rows(from stores: [MetricRow], grain: LaborRollupGrain) -> [DynacapRollupRow] {
        var buckets: [String: [MetricRow]] = [:]
        for row in stores {
            let key: String
            switch grain {
            case .division:
                key = row.division.isEmpty ? "Unassigned" : MarketRegion.canonicalName(row.division)
            case .district:
                key = row.district.isEmpty ? "Unassigned" : row.district
            case .store:
                key = HeartbeatMath.canonicalStore(row.storeNumber)
            }
            guard !key.isEmpty else { continue }
            buckets[key, default: []].append(row)
        }
        var result: [DynacapRollupRow] = []
        result.reserveCapacity(buckets.count)
        for (key, group) in buckets {
            let label: String
            switch grain {
            case .division, .district:
                label = key
            case .store:
                let division = group.first?.division ?? ""
                label = division.isEmpty ? key : "\(key)  |  \(division)"
            }
            result.append(
                DynacapRollupRow(
                    id: key,
                    label: label,
                    storeCount: group.count,
                    rate: HeartbeatMath.average(group.compactMap(DynacapMath.rate)),
                    util: HeartbeatMath.average(group.compactMap { $0.number("utilization_pct") })
                )
            )
        }
        return result.sorted { ($0.rate ?? 999) < ($1.rate ?? 999) }
    }
}

private struct DynacapLineSnap: Identifiable, Equatable {
    let id: UUID
    let storeNumber: String
    let label: String
    let district: String
    let om: String
    let rate: String
    let util: String
    let health: Health
    let rateValue: Double
    let utilValue: Double

    init(_ row: MetricRow) {
        id = row.id
        storeNumber = row.storeNumber
        label = row.division.isEmpty
            ? (row.storeNumber.isEmpty ? "—" : row.storeNumber)
            : "\(row.storeNumber)  |  \(row.division)"
        district = row.district
        om = row.operationsOM
        let rateNum = DynacapMath.rate(row)
        let utilNum = row.number("utilization_pct")
        rate = HeartbeatFormat.num(rateNum, digits: 1)
        util = HeartbeatFormat.pct(utilNum)
        health = HeartbeatMath.health(for: .dynacap, row: row)
        rateValue = rateNum ?? -1
        utilValue = utilNum ?? -1
    }
}

private struct DynacapCheapLine: View, Equatable {
    let snap: DynacapLineSnap
    let expanded: Bool

    var body: some View {
        HStack(spacing: 6) {
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
            .frame(minWidth: 132, maxWidth: 190, alignment: .leading)
            cell(snap.rate, snap.health)
            cell(DynacapMath.goalText, .none, brand: true)
            cell(snap.util, .none)
            Text(snap.health.label.uppercased())
                .font(.caption.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .foregroundStyle(Color.white)
                .background(pill(snap.health), in: Capsule())
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 4)
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
            .background(brand ? AppTheme.blueSoft : wash(health), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

private struct DynacapMetricLine: View, Equatable {
    let label: String
    var count: Int? = nil
    let rate: Double?
    let util: Double?

    var body: some View {
        let health = DynacapMath.rateHealth(rate)
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
            cell(HeartbeatFormat.num(rate, digits: 1), health)
            cell(DynacapMath.goalText, .none, brand: true)
            cell(HeartbeatFormat.pct(util), .none)
            HealthBadge(health: health, prominent: true, compact: true)
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 4)
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

struct DynacapMetricHeader: View {
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
            head("Pieces / hr", key: "rate")
            head("Goal", key: "goal")
            head("Utilization", key: "util")
            head("Status", key: "status", alignment: .trailing)
                .frame(width: 88, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .tracking(0.4)
        .lineLimit(1)
        .minimumScaleFactor(0.65)
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
        .foregroundStyle(selected ? AppTheme.blue : AppTheme.textTertiary)
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

struct DynacapStickyStoreHeader: View {
    @EnvironmentObject private var pin: LaborHeaderPin

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
            DynacapMetricHeader(
                label: "Store",
                showCount: false,
                active: pin.active,
                ascending: pin.ascending,
                onSelect: { pin.onSelect?($0) }
            )
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

struct DynacapRollupTable: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var headerPin: LaborHeaderPin

    private var expanded: Bool { headerPin.rollupExpanded }

    var body: some View {
        if let grain, !summary.isEmpty {
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
                    VStack(alignment: .leading, spacing: 10) {
                    DynacapMetricHeader(label: grain.columnTitle, showCount: grain != .store)
                    ForEach(summary) { row in
                        DynacapMetricLine(
                            label: row.label,
                            count: grain == .store ? nil : row.storeCount,
                            rate: row.rate,
                            util: row.util
                        )
                    }
                                    }
                    .padding(16)
                }
            }
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .stroke(AppTheme.blue, lineWidth: 2.5)
            )
        }
    }

    private var grain: LaborRollupGrain? {
        DynacapRollupBuilder.grain(for: store.filters)
    }

    private var summary: [DynacapRollupRow] {
        guard let grain else { return [] }
        let source = DynacapRollupBuilder.source(from: store.displayRows(for: .dynacap), filters: store.filters)
        var rows = DynacapRollupBuilder.rows(from: source, grain: grain)
        if grain == .division {
            for extra in RollupMarketFill.missingDivisions(present: rows.map(\.label), markets: store.marketStores(), filters: store.filters) {
                rows.append(DynacapRollupRow(id: extra.name, label: extra.name, storeCount: extra.storeCount, rate: nil, util: nil))
            }
            rows.sort { ($0.rate ?? 999) < ($1.rate ?? 999) }
        }
        return rows
    }
}

private struct DynacapStoreRow: View {
    let snap: DynacapLineSnap
    let expanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 10 : 0) {
            Button(action: onToggle) {
                DynacapCheapLine(snap: snap, expanded: expanded)
                    .equatable()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                DynacapStoreExpand(snap: snap)
            }
        }
    }
}

private struct DynacapStoreExpand: View {
    let snap: DynacapLineSnap

    private var chips: [(String, String, Health, Bool)] {
        [
            ("Pieces / hr", snap.rate, snap.health, false),
            ("Goal", DynacapMath.goalText, .none, true),
            ("Utilization", snap.util, .none, false),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("District \(snap.district.isEmpty ? "—" : snap.district)  ·  \(snap.om.isEmpty ? "—" : snap.om)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 8) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, item in
                    metric(item.0, item.1, item.2, brand: item.3)
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

    private func metric(_ name: String, _ value: String, _ health: Health, brand: Bool) -> some View {
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
            if !brand {
                HealthBadge(health: health)
            }
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

struct PrepTable: View {
    @EnvironmentObject private var headerPin: LaborHeaderPin
    let rows: [MetricRow]

    private enum Column: String, CaseIterable, Identifiable {
        case store, pnr, goal, watch, status
        var id: String { rawValue }
        var key: String {
            switch self {
            case .store: return "label"
            case .pnr: return "pnr"
            case .goal: return "goal"
            case .watch: return "watch"
            case .status: return "status"
            }
        }
    }

    @State private var sort = Column.pnr
    @State private var ascending = false
    @State private var snaps: [PrepLineSnap] = []
    @State private var openStore: String?

    private var expanded: Bool { headerPin.storesExpanded }

    var body: some View {
        if rows.isEmpty {
            Section {
                EmptyHint(
                    symbol: "clock.badge.exclamationmark",
                    title: "No stores in this view",
                    detail: "Tap Avg PNR hours to see every store, or pick another callout."
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
        } else {
            Section {
                Button {
                    let next = !headerPin.storesExpanded
                    headerPin.storesExpanded = next
                    headerPin.tableOpen = next
                    if !next { headerPin.pinned = false }
                    if next { rebuildOrder(sort: sort, ascending: ascending) }
                } label: {
                    HubTableHeader(
                            icon: "storefront.fill",
                            title: "Store",
                            accessory: "\(HeartbeatFormat.num(Double(rows.count))) stores  ·  tap to \(expanded ? "collapse" : "expand")",
                            expanded: expanded
                        )
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 2.5)
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: expanded ? 4 : 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
                .onAppear {
                    headerPin.tableOpen = headerPin.storesExpanded
                    headerPin.storeCount = rows.count
                    headerPin.active = sort.key
                    headerPin.ascending = ascending
                    headerPin.onSelect = applyHeaderSort
                }
            }
            if expanded {
                Section {
                    PrepMetricHeader(
                        label: "Store",
                        showCount: false,
                        active: sort.key,
                        ascending: ascending,
                        onSelect: applyHeaderSort
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: LaborHeaderMinYKey.self,
                                value: (geo.frame(in: .global).minY / 12).rounded() * 12
                            )
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 2, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
                    ForEach(snaps) { snap in
                        PrepStoreRow(
                            snap: snap,
                            expanded: openStore == snap.storeNumber,
                            onToggle: {
                                openStore = openStore == snap.storeNumber ? nil : snap.storeNumber
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                    }
                }
                .transaction { $0.animation = nil }
                .onAppear { rebuildOrder(sort: sort, ascending: ascending) }
                .onChange(of: rows.count) { _, _ in
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
                .onChange(of: rows.first?.storeNumber) { _, _ in
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
            }
        }
    }

    private func applyHeaderSort(_ key: String) {
        let column = Column.allCases.first { $0.key == key } ?? .pnr
        let nextAscending = sort == column ? !ascending : column == .store
        sort = column
        ascending = nextAscending
        headerPin.active = column.key
        headerPin.ascending = nextAscending
        rebuildOrder(sort: column, ascending: nextAscending)
    }

    private func rebuildOrder(sort: Column, ascending: Bool) {
        snaps = rows.sorted { lhs, rhs in
            let result = compare(lhs, rhs, sort: sort)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }.map(PrepLineSnap.init)
    }

    private func compare(_ lhs: MetricRow, _ rhs: MetricRow, sort: Column) -> ComparisonResult {
        switch sort {
        case .store:
            if let a = Int(lhs.storeNumber), let b = Int(rhs.storeNumber) {
                return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
            }
            return lhs.storeNumber.localizedStandardCompare(rhs.storeNumber)
        case .pnr, .goal, .watch:
            return numberOrder(lhs.number("pnr_rate_pct"), rhs.number("pnr_rate_pct"))
        case .status:
            let a = healthRank(HeartbeatMath.health(for: .prepNotReady, row: lhs))
            let b = healthRank(HeartbeatMath.health(for: .prepNotReady, row: rhs))
            if a == b { return numberOrder(lhs.number("pnr_rate_pct"), rhs.number("pnr_rate_pct")) }
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

private enum PrepMath {
    static let goalText = "1.9%"
    static let watchText = "1.9–2.5%"

    static func pnrHealth(_ value: Double?) -> Health {
        guard value != nil else { return .none }
        return HeartbeatMath.band(value, good: HeartbeatMath.pnrGoal, watch: HeartbeatMath.pnrWatch, invert: true)
    }
}

private struct PrepRollupRow: Identifiable {
    let id: String
    let label: String
    let storeCount: Int
    let pnr: Double?

    var health: Health { PrepMath.pnrHealth(pnr) }
}

private enum PrepRollupBuilder {
    static func grain(for filters: DashboardFilters) -> LaborRollupGrain? {
        LaborRollupBuilder.grain(for: filters)
    }

    static func source(from all: [MetricRow], filters: DashboardFilters) -> [MetricRow] {
        let stores = all.filter { !$0.storeNumber.isEmpty && $0.number("pnr_rate_pct") != nil }
        if !filters.division.isEmpty || !filters.region.isEmpty {
            return stores.filter { filters.includesDivision($0.division) }
        }
        if !filters.district.isEmpty {
            let divisions = Set(
                stores.filter { HeartbeatMath.matches($0.district, filters.district) }.map(\.division)
            )
            return stores.filter { divisions.contains($0.division) }
        }
        if !filters.om.isEmpty {
            let divisions = Set(
                stores.filter { HeartbeatMath.matches($0.operationsOM, filters.om) }.map(\.division)
            )
            return stores.filter { divisions.contains($0.division) }
        }
        return stores
    }

    static func rows(from stores: [MetricRow], grain: LaborRollupGrain) -> [PrepRollupRow] {
        var buckets: [String: [MetricRow]] = [:]
        for row in stores {
            let key: String
            switch grain {
            case .division:
                key = row.division.isEmpty ? "Unassigned" : MarketRegion.canonicalName(row.division)
            case .district:
                key = row.district.isEmpty ? "Unassigned" : row.district
            case .store:
                key = HeartbeatMath.canonicalStore(row.storeNumber)
            }
            guard !key.isEmpty else { continue }
            buckets[key, default: []].append(row)
        }
        var result: [PrepRollupRow] = []
        result.reserveCapacity(buckets.count)
        for (key, group) in buckets {
            let label: String
            switch grain {
            case .division, .district:
                label = key
            case .store:
                let division = group.first?.division ?? ""
                label = division.isEmpty ? key : "\(key)  |  \(division)"
            }
            result.append(
                PrepRollupRow(
                    id: key,
                    label: label,
                    storeCount: group.count,
                    pnr: HeartbeatMath.average(group.compactMap { $0.number("pnr_rate_pct") })
                )
            )
        }
        return result.sorted { ($0.pnr ?? -1) > ($1.pnr ?? -1) }
    }
}

private struct PrepLineSnap: Identifiable, Equatable {
    let id: UUID
    let storeNumber: String
    let label: String
    let district: String
    let om: String
    let pnr: String
    let health: Health
    let pnrValue: Double

    init(_ row: MetricRow) {
        id = row.id
        storeNumber = row.storeNumber
        label = row.division.isEmpty
            ? (row.storeNumber.isEmpty ? "—" : row.storeNumber)
            : "\(row.storeNumber)  |  \(row.division)"
        district = row.district
        om = row.operationsOM
        let pnrNum = row.number("pnr_rate_pct")
        pnr = HeartbeatFormat.pct(pnrNum)
        health = HeartbeatMath.health(for: .prepNotReady, row: row)
        pnrValue = pnrNum ?? -1
    }
}

private struct PrepCheapLine: View, Equatable {
    let snap: PrepLineSnap
    let expanded: Bool

    var body: some View {
        HStack(spacing: 6) {
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
            .frame(minWidth: 132, maxWidth: 190, alignment: .leading)
            cell(snap.pnr, snap.health)
            cell(PrepMath.goalText, .none, brand: true)
            cell(PrepMath.watchText, .watch)
            Text(snap.health.label.uppercased())
                .font(.caption.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .foregroundStyle(Color.white)
                .background(pill(snap.health), in: Capsule())
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 4)
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
            .background(brand ? AppTheme.blueSoft : wash(health), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

private struct PrepMetricLine: View, Equatable {
    let label: String
    var count: Int? = nil
    let pnr: Double?

    var body: some View {
        let health = PrepMath.pnrHealth(pnr)
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
            cell(HeartbeatFormat.pct(pnr), health)
            cell(PrepMath.goalText, .none, brand: true)
            cell(PrepMath.watchText, .watch)
            HealthBadge(health: health, prominent: true, compact: true)
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 4)
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

struct PrepMetricHeader: View {
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
            head("PNR Hours %", key: "pnr")
            head("Goal", key: "goal")
            head("Watch", key: "watch")
            head("Status", key: "status", alignment: .trailing)
                .frame(width: 88, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .tracking(0.4)
        .lineLimit(1)
        .minimumScaleFactor(0.65)
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
        .foregroundStyle(selected ? AppTheme.blue : AppTheme.textTertiary)
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

struct PrepStickyStoreHeader: View {
    @EnvironmentObject private var pin: LaborHeaderPin

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
            PrepMetricHeader(
                label: "Store",
                showCount: false,
                active: pin.active,
                ascending: pin.ascending,
                onSelect: { pin.onSelect?($0) }
            )
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

struct PrepRollupTable: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var headerPin: LaborHeaderPin

    private var expanded: Bool { headerPin.rollupExpanded }

    var body: some View {
        if let grain, !summary.isEmpty {
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
                    VStack(alignment: .leading, spacing: 10) {
                    PrepMetricHeader(label: grain.columnTitle, showCount: grain != .store)
                    ForEach(summary) { row in
                        PrepMetricLine(
                            label: row.label,
                            count: grain == .store ? nil : row.storeCount,
                            pnr: row.pnr
                        )
                    }
                                    }
                    .padding(16)
                }
            }
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .stroke(AppTheme.blue, lineWidth: 2.5)
            )
        }
    }

    private var grain: LaborRollupGrain? {
        PrepRollupBuilder.grain(for: store.filters)
    }

    private var summary: [PrepRollupRow] {
        guard let grain else { return [] }
        let source = PrepRollupBuilder.source(from: store.displayRows(for: .prepNotReady), filters: store.filters)
        var rows = PrepRollupBuilder.rows(from: source, grain: grain)
        if grain == .division {
            for extra in RollupMarketFill.missingDivisions(present: rows.map(\.label), markets: store.marketStores(), filters: store.filters) {
                rows.append(PrepRollupRow(id: extra.name, label: extra.name, storeCount: extra.storeCount, pnr: nil))
            }
            rows.sort { ($0.pnr ?? -1) > ($1.pnr ?? -1) }
        }
        return rows
    }
}

private struct PrepStoreRow: View {
    let snap: PrepLineSnap
    let expanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 10 : 0) {
            Button(action: onToggle) {
                PrepCheapLine(snap: snap, expanded: expanded)
                    .equatable()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                PrepStoreExpand(snap: snap)
            }
        }
    }
}

private struct PrepStoreExpand: View {
    let snap: PrepLineSnap

    private var chips: [(String, String, Health, Bool)] {
        [
            ("PNR Hours %", snap.pnr, snap.health, false),
            ("Goal", PrepMath.goalText, .none, true),
            ("Watch", PrepMath.watchText, .watch, false),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("District \(snap.district.isEmpty ? "—" : snap.district)  ·  \(snap.om.isEmpty ? "—" : snap.om)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 8) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, item in
                    metric(item.0, item.1, item.2, brand: item.3)
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

    private func metric(_ name: String, _ value: String, _ health: Health, brand: Bool) -> some View {
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
            if !brand {
                HealthBadge(health: health)
            }
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

struct FiveStarTable: View {
    @EnvironmentObject private var headerPin: LaborHeaderPin
    let rows: [MetricRow]

    private enum Column: String, CaseIterable, Identifiable {
        case store, rating, flash, presub, coe, ott, oth, status
        var id: String { rawValue }
        var key: String {
            switch self {
            case .store: return "label"
            case .rating: return "rating"
            case .flash: return "flash"
            case .presub: return "presub"
            case .coe: return "coe"
            case .ott: return "ott"
            case .oth: return "oth"
            case .status: return "status"
            }
        }
    }

    @State private var sort = Column.rating
    @State private var ascending = true
    @State private var snaps: [FiveStarLineSnap] = []
    @State private var openStore: String?

    private var expanded: Bool { headerPin.storesExpanded }

    var body: some View {
        if rows.isEmpty {
            Section {
                EmptyHint(
                    symbol: "star",
                    title: "No stores in this view",
                    detail: "Tap Avg star rating to see every store, or pick another callout."
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
        } else {
            Section {
                Button {
                    let next = !headerPin.storesExpanded
                    headerPin.storesExpanded = next
                    headerPin.tableOpen = next
                    if !next { headerPin.pinned = false }
                    if next { rebuildOrder(sort: sort, ascending: ascending) }
                } label: {
                    HubTableHeader(
                            icon: "storefront.fill",
                            title: "Store",
                            accessory: "\(HeartbeatFormat.num(Double(rows.count))) stores  ·  tap to \(expanded ? "collapse" : "expand")",
                            expanded: expanded
                        )
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 2.5)
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: expanded ? 4 : 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
                .onAppear {
                    headerPin.tableOpen = headerPin.storesExpanded
                    headerPin.storeCount = rows.count
                    headerPin.active = sort.key
                    headerPin.ascending = ascending
                    headerPin.onSelect = applyHeaderSort
                }
            }
            if expanded {
                Section {
                    FiveStarMetricHeader(
                        label: "Store",
                        showCount: false,
                        active: sort.key,
                        ascending: ascending,
                        onSelect: applyHeaderSort
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: LaborHeaderMinYKey.self,
                                value: (geo.frame(in: .global).minY / 12).rounded() * 12
                            )
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 2, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
                    ForEach(snaps) { snap in
                        FiveStarStoreRow(
                            snap: snap,
                            expanded: openStore == snap.storeNumber,
                            onToggle: {
                                openStore = openStore == snap.storeNumber ? nil : snap.storeNumber
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                    }
                }
                .transaction { $0.animation = nil }
                .onAppear { rebuildOrder(sort: sort, ascending: ascending) }
                .onChange(of: rows.count) { _, _ in
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
                .onChange(of: rows.first?.storeNumber) { _, _ in
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
            }
        }
    }

    private func applyHeaderSort(_ key: String) {
        let column = Column.allCases.first { $0.key == key } ?? .rating
        let nextAscending = sort == column ? !ascending : column == .store
        sort = column
        ascending = nextAscending
        headerPin.active = column.key
        headerPin.ascending = nextAscending
        rebuildOrder(sort: column, ascending: nextAscending)
    }

    private func rebuildOrder(sort: Column, ascending: Bool) {
        snaps = rows.sorted { lhs, rhs in
            let result = compare(lhs, rhs, sort: sort)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }.map(FiveStarLineSnap.init)
    }

    private func compare(_ lhs: MetricRow, _ rhs: MetricRow, sort: Column) -> ComparisonResult {
        switch sort {
        case .store:
            if let a = Int(lhs.storeNumber), let b = Int(rhs.storeNumber) {
                return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
            }
            return lhs.storeNumber.localizedStandardCompare(rhs.storeNumber)
        case .rating:
            return numberOrder(lhs.number("star_rating"), rhs.number("star_rating"))
        case .flash:
            return numberOrder(lhs.number("flash_pct"), rhs.number("flash_pct"))
        case .presub:
            return numberOrder(lhs.number("presub_pct"), rhs.number("presub_pct"))
        case .coe:
            return numberOrder(lhs.number("coe_pct"), rhs.number("coe_pct"))
        case .ott:
            return numberOrder(lhs.number("ott_pct"), rhs.number("ott_pct"))
        case .oth:
            return numberOrder(lhs.number("oth5_pct"), rhs.number("oth5_pct"))
        case .status:
            let a = healthRank(HeartbeatMath.health(for: .fiveStar, row: lhs))
            let b = healthRank(HeartbeatMath.health(for: .fiveStar, row: rhs))
            if a == b { return numberOrder(lhs.number("star_rating"), rhs.number("star_rating")) }
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

private struct FiveStarRollupRow: Identifiable {
    let id: String
    let label: String
    let storeCount: Int
    let rating: Double?
    let flash: Double?
    let presub: Double?
    let coe: Double?
    let ott: Double?
    let oth: Double?

    var health: Health {
        guard rating != nil else { return .none }
        return HeartbeatMath.band(rating, good: 4.5, watch: HeartbeatMath.fiveStarPass)
    }
}

private enum FiveStarRollupBuilder {
    static func grain(for filters: DashboardFilters) -> LaborRollupGrain? {
        LaborRollupBuilder.grain(for: filters)
    }

    static func source(from all: [MetricRow], filters: DashboardFilters) -> [MetricRow] {
        let stores = all.filter { !$0.storeNumber.isEmpty }
        if !filters.division.isEmpty || !filters.region.isEmpty {
            return stores.filter { filters.includesDivision($0.division) }
        }
        if !filters.district.isEmpty {
            let divisions = Set(
                stores.filter { HeartbeatMath.matches($0.district, filters.district) }.map(\.division)
            )
            return stores.filter { divisions.contains($0.division) }
        }
        if !filters.om.isEmpty {
            let divisions = Set(
                stores.filter { HeartbeatMath.matches($0.operationsOM, filters.om) }.map(\.division)
            )
            return stores.filter { divisions.contains($0.division) }
        }
        return stores
    }

    static func rows(from stores: [MetricRow], grain: LaborRollupGrain) -> [FiveStarRollupRow] {
        var buckets: [String: [MetricRow]] = [:]
        for row in stores {
            let key: String
            switch grain {
            case .division:
                key = row.division.isEmpty ? "Unassigned" : MarketRegion.canonicalName(row.division)
            case .district:
                key = row.district.isEmpty ? "Unassigned" : row.district
            case .store:
                key = HeartbeatMath.canonicalStore(row.storeNumber)
            }
            guard !key.isEmpty else { continue }
            buckets[key, default: []].append(row)
        }
        var result: [FiveStarRollupRow] = []
        result.reserveCapacity(buckets.count)
        for (key, group) in buckets {
            let label: String
            switch grain {
            case .division, .district:
                label = key
            case .store:
                let division = group.first?.division ?? ""
                label = division.isEmpty ? key : "\(key)  |  \(division)"
            }
            result.append(
                FiveStarRollupRow(
                    id: key,
                    label: label,
                    storeCount: group.count,
                    rating: HeartbeatMath.average(group.compactMap { $0.number("star_rating") }),
                    flash: HeartbeatMath.average(group.compactMap { $0.number("flash_pct") }),
                    presub: HeartbeatMath.average(group.compactMap { $0.number("presub_pct") }),
                    coe: HeartbeatMath.average(group.compactMap { $0.number("coe_pct") }),
                    ott: HeartbeatMath.average(group.compactMap { $0.number("ott_pct") }),
                    oth: HeartbeatMath.average(group.compactMap { $0.number("oth5_pct") })
                )
            )
        }
        return result.sorted { ($0.rating ?? 99) < ($1.rating ?? 99) }
    }
}

private struct FiveStarLineSnap: Identifiable, Equatable {
    let id: UUID
    let storeNumber: String
    let label: String
    let district: String
    let om: String
    let rating: String
    let flash: String
    let presub: String
    let coe: String
    let ott: String
    let oth: String
    let health: Health
    let ratingHealth: Health
    let flashHealth: Health
    let presubHealth: Health
    let coeHealth: Health
    let ottHealth: Health
    let othHealth: Health
    let ratingValue: Double
    let flashValue: Double
    let presubValue: Double
    let coeValue: Double
    let ottValue: Double
    let othValue: Double

    init(_ row: MetricRow) {
        id = row.id
        storeNumber = row.storeNumber
        label = row.division.isEmpty
            ? (row.storeNumber.isEmpty ? "—" : row.storeNumber)
            : "\(row.storeNumber)  |  \(row.division)"
        district = row.district
        om = row.operationsOM
        let ratingNum = row.number("star_rating")
        let flashNum = row.number("flash_pct")
        let presubNum = row.number("presub_pct")
        let coeNum = row.number("coe_pct")
        let ottNum = row.number("ott_pct")
        let othNum = row.number("oth5_pct")
        rating = HeartbeatFormat.stars(ratingNum)
        flash = HeartbeatFormat.pct(flashNum)
        presub = HeartbeatFormat.pct(presubNum)
        coe = HeartbeatFormat.pct(coeNum)
        ott = HeartbeatFormat.pct(ottNum)
        oth = HeartbeatFormat.pct(othNum)
        health = HeartbeatMath.fiveStarHealth(row)
        ratingHealth = health
        flashHealth = HeartbeatMath.flashStar(row).health
        presubHealth = HeartbeatMath.presubStar(row).health
        coeHealth = HeartbeatMath.coeStar(row).health
        ottHealth = HeartbeatMath.ottStar(row).health
        othHealth = HeartbeatMath.othStar(row).health
        ratingValue = ratingNum ?? -1
        flashValue = flashNum ?? -1
        presubValue = presubNum ?? -1
        coeValue = coeNum ?? -1
        ottValue = ottNum ?? -1
        othValue = othNum ?? -1
    }
}

private struct FiveStarCheapLine: View, Equatable {
    let snap: FiveStarLineSnap
    let expanded: Bool

    var body: some View {
        HStack(spacing: 6) {
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
            .frame(minWidth: 132, maxWidth: 190, alignment: .leading)
            cell(snap.rating, snap.ratingHealth)
            cell(snap.flash, snap.flashHealth)
            cell(snap.presub, snap.presubHealth)
            cell(snap.coe, snap.coeHealth)
            cell(snap.ott, snap.ottHealth)
            cell(snap.oth, snap.othHealth)
            Text(snap.health.label.uppercased())
                .font(.caption.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .foregroundStyle(Color.white)
                .background(pill(snap.health), in: Capsule())
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private func cell(_ value: String, _ health: Health) -> some View {
        Text(value)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(ink(health))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
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

private struct FiveStarMetricLine: View, Equatable {
    let label: String
    var count: Int? = nil
    let rating: Double?
    let flash: Double?
    let presub: Double?
    let coe: Double?
    let ott: Double?
    let oth: Double?

    var body: some View {
        let health = rating == nil ? Health.none : HeartbeatMath.band(rating, good: 4.5, watch: HeartbeatMath.fiveStarPass)
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
            cell(HeartbeatFormat.stars(rating), health)
            cell(HeartbeatFormat.pct(flash), HeartbeatMath.starMark(value: flash, full: 75, half: 55).health)
            cell(HeartbeatFormat.pct(presub), HeartbeatMath.starMark(value: presub, full: 5, half: 6, invert: true).health)
            cell(HeartbeatFormat.pct(coe), HeartbeatMath.starMark(value: coe, full: 20, half: 0).health)
            cell(HeartbeatFormat.pct(ott), HeartbeatMath.starMark(value: ott, full: 95, half: 90).health)
            cell(HeartbeatFormat.pct(oth), HeartbeatMath.starMark(value: oth, full: 92, half: 78).health)
            HealthBadge(health: health, prominent: true, compact: true)
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private func cell(_ value: String, _ health: Health) -> some View {
        Text(value)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(ink(health))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
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
        case .none: return Color.clear
        }
    }
}

struct FiveStarMetricHeader: View {
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
            head("Rating", key: "rating")
            head("Flash", key: "flash")
            head("Presubs", key: "presub")
            head("COE", key: "coe")
            head("OTT", key: "ott")
            head("OTH 5%", key: "oth")
            head("Status", key: "status", alignment: .trailing)
                .frame(width: 88, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .tracking(0.4)
        .lineLimit(1)
        .minimumScaleFactor(0.65)
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
        .foregroundStyle(selected ? AppTheme.blue : AppTheme.textTertiary)
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

struct FiveStarStickyStoreHeader: View {
    @EnvironmentObject private var pin: LaborHeaderPin

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
            FiveStarMetricHeader(
                label: "Store",
                showCount: false,
                active: pin.active,
                ascending: pin.ascending,
                onSelect: { pin.onSelect?($0) }
            )
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

struct FiveStarRollupTable: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var headerPin: LaborHeaderPin

    private var expanded: Bool { headerPin.rollupExpanded }

    var body: some View {
        if let grain, !summary.isEmpty {
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
                    VStack(alignment: .leading, spacing: 10) {
                    FiveStarMetricHeader(label: grain.columnTitle, showCount: grain != .store)
                    ForEach(summary) { row in
                        FiveStarMetricLine(
                            label: row.label,
                            count: grain == .store ? nil : row.storeCount,
                            rating: row.rating,
                            flash: row.flash,
                            presub: row.presub,
                            coe: row.coe,
                            ott: row.ott,
                            oth: row.oth
                        )
                    }
                                    }
                    .padding(16)
                }
            }
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .stroke(AppTheme.blue, lineWidth: 2.5)
            )
        }
    }

    private var grain: LaborRollupGrain? {
        FiveStarRollupBuilder.grain(for: store.filters)
    }

    private var summary: [FiveStarRollupRow] {
        guard let grain else { return [] }
        let source = FiveStarRollupBuilder.source(from: store.displayRows(for: .fiveStar), filters: store.filters)
        var rows = FiveStarRollupBuilder.rows(from: source, grain: grain)
        if grain == .division {
            for extra in RollupMarketFill.missingDivisions(present: rows.map(\.label), markets: store.marketStores(), filters: store.filters) {
                rows.append(
                    FiveStarRollupRow(
                        id: extra.name,
                        label: extra.name,
                        storeCount: extra.storeCount,
                        rating: nil,
                        flash: nil,
                        presub: nil,
                        coe: nil,
                        ott: nil,
                        oth: nil
                    )
                )
            }
            rows.sort { ($0.rating ?? 99) < ($1.rating ?? 99) }
        }
        return rows
    }
}

private struct FiveStarStoreRow: View {
    let snap: FiveStarLineSnap
    let expanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 10 : 0) {
            Button(action: onToggle) {
                FiveStarCheapLine(snap: snap, expanded: expanded)
                    .equatable()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                FiveStarStoreExpand(snap: snap)
            }
        }
    }
}

private struct FiveStarStoreExpand: View {
    let snap: FiveStarLineSnap

    private var chips: [(String, String, Health)] {
        [
            ("Rating", snap.rating, snap.ratingHealth),
            ("Flash", snap.flash, snap.flashHealth),
            ("Presubs", snap.presub, snap.presubHealth),
            ("COE", snap.coe, snap.coeHealth),
            ("OTT", snap.ott, snap.ottHealth),
            ("OTH 5%", snap.oth, snap.othHealth),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("District \(snap.district.isEmpty ? "—" : snap.district)  ·  \(snap.om.isEmpty ? "—" : snap.om)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            chipGrid
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.card.opacity(0.9))
        )
    }

    private var chipGrid: some View {
        let rows = stride(from: 0, to: chips.count, by: 3).map { Array(chips[$0..<min($0 + 3, chips.count)]) }
        return VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, item in
                        metric(item.0, item.1, item.2)
                    }
                }
            }
        }
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
            HealthBadge(health: health)
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

struct FiveStarStoreCard: View {
    let row: MetricRow

    var body: some View {
        let health = HeartbeatMath.health(for: .fiveStar, row: row)
        let rating = row.number("star_rating")
        let flash = HeartbeatMath.flashStar(row)
        let presub = HeartbeatMath.presubStar(row)
        let coe = HeartbeatMath.coeStar(row)
        let ott = HeartbeatMath.ottStar(row)
        let oth = HeartbeatMath.othStar(row)
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
                metric("Rating", HeartbeatFormat.stars(rating), health)
                metric("Flash", HeartbeatFormat.pct(row.number("flash_pct")), flash.health)
                metric("Presubs", HeartbeatFormat.pct(row.number("presub_pct")), presub.health)
            }
            HStack(spacing: 8) {
                metric("COE", HeartbeatFormat.pct(row.number("coe_pct")), coe.health)
                metric("OTT", HeartbeatFormat.pct(row.number("ott_pct")), ott.health)
                metric("OTH 5%", HeartbeatFormat.pct(row.number("oth5_pct")), oth.health)
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
            HealthBadge(health: health)
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

private enum LaborRollupGrain {
    case division, district, store

    var title: String {
        switch self {
        case .division: return "Markets"
        case .district: return "By district"
        case .store: return "Store"
        }
    }

    var symbol: String {
        switch self {
        case .division: return "map.fill"
        case .district: return "square.grid.2x2.fill"
        case .store: return "storefront.fill"
        }
    }

    var columnTitle: String {
        switch self {
        case .division: return "Division"
        case .district: return "District"
        case .store: return "Store"
        }
    }
}

private enum RollupMarketFill {
    static func missingDivisions(
        present: [String],
        markets: [HeartbeatMath.MarketStore],
        filters: DashboardFilters
    ) -> [(name: String, storeCount: Int)] {
        let seen = Set(present.map { HeartbeatMath.normalize(MarketRegion.canonicalName($0)) })
        let counts = Dictionary(
            grouping: markets,
            by: { MarketRegion.canonicalName($0.division) }
        )
        .filter { !$0.key.isEmpty }
        .mapValues(\.count)
        return MarketRegion.companyDivisions(for: filters).compactMap { name in
            guard !seen.contains(HeartbeatMath.normalize(name)) else { return nil }
            return (name: name, storeCount: counts[name] ?? 0)
        }
    }
}

private struct LaborRollupRow: Identifiable {
    let id: String
    let label: String
    let storeCount: Int
    let tva: Double?
    let cost: Double?
    let act: Double?
    let efficiency: Double?
    let uplh: Double?
    let wage: Double?
    let aiv: Double?
}

private enum LaborRollupBuilder {
    static func grain(for filters: DashboardFilters) -> LaborRollupGrain? {
        if !filters.store.isEmpty { return nil }
        if !filters.division.isEmpty || !filters.district.isEmpty || !filters.om.isEmpty {
            return .district
        }
        return .division
    }

    static func source(from all: [MetricRow], filters: DashboardFilters) -> [MetricRow] {
        let stores = all.filter {
            $0.textPayload["labor_grain"] != "market" && !$0.storeNumber.isEmpty
        }
        if !filters.division.isEmpty {
            return stores.filter { filters.includesDivision($0.division) }
        }
        if !filters.region.isEmpty {
            return stores.filter { filters.includesDivision($0.division) }
        }
        if !filters.district.isEmpty {
            let divisions = Set(
                stores.filter { HeartbeatMath.matches($0.district, filters.district) }.map(\.division)
            )
            return stores.filter { divisions.contains($0.division) }
        }
        if !filters.om.isEmpty {
            let divisions = Set(
                stores.filter { HeartbeatMath.matches($0.operationsOM, filters.om) }.map(\.division)
            )
            return stores.filter { divisions.contains($0.division) }
        }
        return stores
    }

    static func rows(from stores: [MetricRow], grain: LaborRollupGrain) -> [LaborRollupRow] {
        var buckets: [String: [MetricRow]] = [:]
        for row in stores {
            if row.textPayload["labor_grain"] == "market" { continue }
            let key: String
            switch grain {
            case .division:
                key = row.division.isEmpty ? "Unassigned" : MarketRegion.canonicalName(row.division)
            case .district:
                key = row.district.isEmpty ? "Unassigned" : row.district
            case .store:
                key = HeartbeatMath.canonicalStore(row.storeNumber)
            }
            guard !key.isEmpty else { continue }
            buckets[key, default: []].append(row)
        }
        var result: [LaborRollupRow] = []
        result.reserveCapacity(buckets.count)
        for (key, group) in buckets {
            let label: String
            switch grain {
            case .division, .district:
                label = key
            case .store:
                let division = group.first?.division ?? ""
                label = division.isEmpty ? key : "\(key)  |  \(division)"
            }
            result.append(
                LaborRollupRow(
                    id: key,
                    label: label,
                    storeCount: group.count,
                    tva: HeartbeatMath.laborRollup(group, key: "target_vs_actual_pct"),
                    cost: HeartbeatMath.laborRollup(group, key: "cost_trgt_pct"),
                    act: HeartbeatMath.laborRollup(group, key: "act_cost_pct"),
                    efficiency: HeartbeatMath.laborRollup(group, key: "schedule_efficiency_pct"),
                    uplh: HeartbeatMath.laborRollup(group, key: "uplh_impact_pct"),
                    wage: HeartbeatMath.laborRollup(group, key: "wage_impact_pct"),
                    aiv: HeartbeatMath.laborRollup(group, key: "aiv_impact_pct")
                )
            )
        }
        return result.sorted { ($0.tva ?? -999) > ($1.tva ?? -999) }
    }
}

private struct LaborLineSnap: Identifiable, Equatable {
    let id: UUID
    let storeNumber: String
    let label: String
    let district: String
    let om: String
    let week: String
    let tva: String
    let cost: String
    let act: String
    let efficiency: String
    let uplh: String
    let wage: String
    let aiv: String
    let tvaHealth: Health
    let actHealth: Health
    let effHealth: Health
    let uplhHealth: Health
    let wageHealth: Health
    let aivHealth: Health

    init(_ row: MetricRow) {
        id = row.id
        storeNumber = row.storeNumber
        label = row.division.isEmpty
            ? (row.storeNumber.isEmpty ? "—" : row.storeNumber)
            : "\(row.storeNumber)  |  \(row.division)"
        district = row.district
        om = row.operationsOM
        week = row.textPayload["week"].flatMap { $0.isEmpty ? nil : $0 } ?? "store totals"
        let tvaValue = row.number("target_vs_actual_pct")
        let costValue = row.number("cost_trgt_pct")
        let actValue = row.number("act_cost_pct")
        let effValue = row.number("schedule_efficiency_pct")
        let uplhValue = row.number("uplh_impact_pct")
        let wageValue = row.number("wage_impact_pct")
        let aivValue = row.number("aiv_impact_pct")
        tva = HeartbeatFormat.pct(tvaValue)
        cost = HeartbeatFormat.pct(costValue)
        act = HeartbeatFormat.pct(actValue)
        efficiency = HeartbeatFormat.pct(effValue)
        uplh = HeartbeatFormat.pct(uplhValue)
        wage = HeartbeatFormat.pct(wageValue)
        aiv = HeartbeatFormat.pct(aivValue)
        tvaHealth = HeartbeatMath.laborHealth(tvaValue)
        if let actValue, let costValue {
            actHealth = actValue <= costValue ? .good : .risk
        } else {
            actHealth = .none
        }
        effHealth = HeartbeatMath.band(effValue, good: HeartbeatMath.scheduleGoal, watch: HeartbeatMath.scheduleWatch)
        uplhHealth = Self.impact(uplhValue)
        wageHealth = Self.impact(wageValue)
        aivHealth = Self.impact(aivValue)
    }

    private static func impact(_ value: Double?) -> Health {
        guard let value else { return .none }
        return value <= 0 ? .good : .risk
    }
}

private struct LaborCheapLine: View, Equatable {
    let snap: LaborLineSnap
    let expanded: Bool

    var body: some View {
        HStack(spacing: 6) {
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
            .frame(minWidth: 132, maxWidth: 190, alignment: .leading)
            cell(snap.tva, snap.tvaHealth)
            cell(snap.cost, .none, brand: true)
            cell(snap.act, snap.actHealth)
            cell(snap.efficiency, snap.effHealth)
            cell(snap.uplh, snap.uplhHealth)
            cell(snap.wage, snap.wageHealth)
            cell(snap.aiv, snap.aivHealth)
            Text(snap.tvaHealth.label.uppercased())
                .font(.caption.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .foregroundStyle(Color.white)
                .background(pill(snap.tvaHealth), in: Capsule())
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private func cell(_ value: String, _ health: Health, brand: Bool = false) -> some View {
        Text(value)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(brand ? AppTheme.blue : ink(health))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background(brand ? AppTheme.blueSoft : wash(health), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

private struct LaborMetricLine: View, Equatable {
    let label: String
    var count: Int? = nil
    let tva: Double?
    let cost: Double?
    let act: Double?
    let efficiency: Double?
    let uplh: Double?
    let wage: Double?
    let aiv: Double?
    var chevronExpanded: Bool? = nil

    var body: some View {
        let tvaHealth = HeartbeatMath.laborHealth(tva)
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let chevronExpanded {
                    Image(systemName: chevronExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                }
            }
            .frame(minWidth: 132, maxWidth: 190, alignment: .leading)
            if let count {
                Text(HeartbeatFormat.num(Double(count)))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 58, alignment: .trailing)
            }
            cell(HeartbeatFormat.pct(tva), tvaHealth)
            cell(HeartbeatFormat.pct(cost), .none, brand: true)
            cell(HeartbeatFormat.pct(act), actHealth(act, cost))
            cell(HeartbeatFormat.pct(efficiency), HeartbeatMath.band(efficiency, good: HeartbeatMath.scheduleGoal, watch: HeartbeatMath.scheduleWatch))
            cell(HeartbeatFormat.pct(uplh), impact(uplh))
            cell(HeartbeatFormat.pct(wage), impact(wage))
            cell(HeartbeatFormat.pct(aiv), impact(aiv))
            HealthBadge(health: tvaHealth, prominent: true, compact: true)
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private func cell(_ value: String, _ health: Health, brand: Bool = false) -> some View {
        Text(value)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(brand ? AppTheme.blue : ink(health))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(brand ? AppTheme.blueSoft : wash(health))
            )
    }

    private func impact(_ value: Double?) -> Health {
        guard let value else { return .none }
        return value <= 0 ? .good : .risk
    }

    private func actHealth(_ act: Double?, _ cost: Double?) -> Health {
        guard let act, let cost else { return .none }
        return act <= cost ? .good : .risk
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

struct LaborHeaderMinYKey: PreferenceKey {
    static var defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        let next = nextValue()
        switch (value, next) {
        case let (a?, b?): value = min(a, b)
        case (nil, let b?): value = b
        default: break
        }
    }
}

struct LaborListTopKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

final class LaborHeaderPin: ObservableObject {
    @Published var tableOpen = true
    @Published var storesExpanded = true
    @Published var rollupExpanded = true
    @Published var pinned = false
    @Published var active = "tva"
    @Published var ascending = false
    @Published var storeCount = 0
    var listTop: CGFloat = 0
    var onSelect: ((String) -> Void)?

    func openOnPageEnter() {
        storesExpanded = true
        rollupExpanded = true
        tableOpen = true
        pinned = false
    }

    func updatePin(headerMinY: CGFloat?) {
        guard storesExpanded else {
            if pinned { pinned = false }
            return
        }
        guard let headerMinY else { return }
        let top = listTop
        if pinned {
            if headerMinY > top + 44 { pinned = false }
        } else if headerMinY <= top + 10 {
            pinned = true
        }
    }
}

struct LaborStickyStoreHeader: View {
    @EnvironmentObject private var pin: LaborHeaderPin

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
            LaborMetricHeader(
                label: "Store",
                showCount: false,
                active: pin.active,
                ascending: pin.ascending,
                onSelect: { pin.onSelect?($0) }
            )
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

struct LaborMetricHeader: View {
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
            head("Tgt vs Act", key: "tva")
            head("CostTrgt%", key: "cost")
            head("ActCost%", key: "act")
            head("Sch Effi%", key: "eff")
            head("UPLH", key: "uplh")
            head("Wage", key: "wage")
            head("AIV", key: "aiv")
            head("Status", key: "status", alignment: .trailing)
                .frame(width: 88, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .tracking(0.4)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
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
        .foregroundStyle(selected ? AppTheme.blue : AppTheme.textTertiary)
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

struct LaborRollupTable: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var headerPin: LaborHeaderPin

    private var expanded: Bool { headerPin.rollupExpanded }

    var body: some View {
        if let grain, !summary.isEmpty {
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
                    VStack(alignment: .leading, spacing: 10) {
                        LaborMetricHeader(label: grain.columnTitle, showCount: grain != .store)
                        ForEach(summary) { row in
                            LaborMetricLine(
                                label: row.label,
                                count: grain == .store ? nil : row.storeCount,
                                tva: row.tva,
                                cost: row.cost,
                                act: row.act,
                                efficiency: row.efficiency,
                                uplh: row.uplh,
                                wage: row.wage,
                                aiv: row.aiv
                            )
                        }
                                        }
                    .padding(16)
                }
                }
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 2.5)
                )
        }
    }

    private var grain: LaborRollupGrain? {
        LaborRollupBuilder.grain(for: store.filters)
    }

    private var summary: [LaborRollupRow] {
        guard let grain else { return [] }
        let source = LaborRollupBuilder.source(from: store.displayRows(for: .labor), filters: store.filters)
        var rows = LaborRollupBuilder.rows(from: source, grain: grain)
        if grain == .division {
            for extra in RollupMarketFill.missingDivisions(present: rows.map(\.label), markets: store.marketStores(), filters: store.filters) {
                rows.append(
                    LaborRollupRow(
                        id: extra.name,
                        label: extra.name,
                        storeCount: extra.storeCount,
                        tva: nil,
                        cost: nil,
                        act: nil,
                        efficiency: nil,
                        uplh: nil,
                        wage: nil,
                        aiv: nil
                    )
                )
            }
            rows.sort { ($0.tva ?? -999) > ($1.tva ?? -999) }
        }
        return rows
    }
}

struct LaborTable: View {
    @EnvironmentObject private var headerPin: LaborHeaderPin
    let rows: [MetricRow]

    private enum Column: String, CaseIterable, Identifiable {
        case store, tva, cost, actual, efficiency, uplh, wage, aiv, status
        var id: String { rawValue }
        var title: String {
            switch self {
            case .store: return "Store"
            case .tva: return "Tgt vs Act"
            case .cost: return "CostTrgt%"
            case .actual: return "ActCost%"
            case .efficiency: return "Sch Effi%"
            case .uplh: return "UPLH"
            case .wage: return "Wage"
            case .aiv: return "AIV"
            case .status: return "Status"
            }
        }
        var key: String {
            switch self {
            case .store: return "label"
            case .tva: return "tva"
            case .cost: return "cost"
            case .actual: return "act"
            case .efficiency: return "eff"
            case .uplh: return "uplh"
            case .wage: return "wage"
            case .aiv: return "aiv"
            case .status: return "status"
            }
        }
    }

    @State private var sort = Column.tva
    @State private var ascending = false
    @State private var snaps: [LaborLineSnap] = []
    @State private var openStore: String?

    private var expanded: Bool { headerPin.storesExpanded }

    var body: some View {
        if rows.isEmpty {
            Section {
                EmptyHint(
                    symbol: "dollarsign.circle",
                    title: "No stores in this view",
                    detail: "Tap Target vs Actual to see every store, or pick another callout."
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
        } else {
            Section {
                Button {
                    let next = !headerPin.storesExpanded
                    headerPin.storesExpanded = next
                    headerPin.tableOpen = next
                    if !next { headerPin.pinned = false }
                    if next { rebuildOrder(sort: sort, ascending: ascending) }
                } label: {
                    HubTableHeader(
                            icon: "storefront.fill",
                            title: "Store",
                            accessory: "\(HeartbeatFormat.num(Double(rows.count))) stores  ·  tap to \(expanded ? "collapse" : "expand")",
                            expanded: expanded
                        )
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 2.5)
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: expanded ? 4 : 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
                .onAppear {
                    headerPin.tableOpen = headerPin.storesExpanded
                    headerPin.storeCount = rows.count
                    headerPin.active = sort.key
                    headerPin.ascending = ascending
                    headerPin.onSelect = applyHeaderSort
                }
            }
            if expanded {
                Section {
                    LaborMetricHeader(
                        label: "Store",
                        showCount: false,
                        active: sort.key,
                        ascending: ascending,
                        onSelect: applyHeaderSort
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: LaborHeaderMinYKey.self,
                                value: (geo.frame(in: .global).minY / 12).rounded() * 12
                            )
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 2, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
                    ForEach(snaps) { snap in
                        LaborStoreRow(
                            snap: snap,
                            expanded: openStore == snap.storeNumber,
                            onToggle: {
                                openStore = openStore == snap.storeNumber ? nil : snap.storeNumber
                            }
                        )
                            .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(AppTheme.bg)
                    }
                }
                .transaction { $0.animation = nil }
                .onAppear { rebuildOrder(sort: sort, ascending: ascending) }
                .onChange(of: rows.count) { _, _ in
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
                .onChange(of: rows.first?.storeNumber) { _, _ in
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
            }
        }
    }

    private func applyHeaderSort(_ key: String) {
        let column = Column.allCases.first { $0.key == key } ?? .tva
        let nextAscending = sort == column ? !ascending : column == .store
        sort = column
        ascending = nextAscending
        headerPin.active = column.key
        headerPin.ascending = nextAscending
        rebuildOrder(sort: column, ascending: nextAscending)
    }

    private func rebuildOrder(sort: Column, ascending: Bool) {
        snaps = rows.sorted { lhs, rhs in
            let result = compare(lhs, rhs, sort: sort)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }.map(LaborLineSnap.init)
    }

    private func compare(_ lhs: MetricRow, _ rhs: MetricRow, sort: Column) -> ComparisonResult {
        switch sort {
        case .store:
            if let a = Int(lhs.storeNumber), let b = Int(rhs.storeNumber) {
                return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
            }
            return lhs.storeNumber.localizedStandardCompare(rhs.storeNumber)
        case .tva:
            return numberOrder(lhs.number("target_vs_actual_pct"), rhs.number("target_vs_actual_pct"))
        case .cost:
            return numberOrder(lhs.number("cost_trgt_pct"), rhs.number("cost_trgt_pct"))
        case .actual:
            return numberOrder(lhs.number("act_cost_pct"), rhs.number("act_cost_pct"))
        case .efficiency:
            return numberOrder(lhs.number("schedule_efficiency_pct"), rhs.number("schedule_efficiency_pct"))
        case .uplh:
            return numberOrder(lhs.number("uplh_impact_pct"), rhs.number("uplh_impact_pct"))
        case .wage:
            return numberOrder(lhs.number("wage_impact_pct"), rhs.number("wage_impact_pct"))
        case .aiv:
            return numberOrder(lhs.number("aiv_impact_pct"), rhs.number("aiv_impact_pct"))
        case .status:
            let a = healthRank(HeartbeatMath.health(for: .labor, row: lhs))
            let b = healthRank(HeartbeatMath.health(for: .labor, row: rhs))
            if a == b { return numberOrder(lhs.number("target_vs_actual_pct"), rhs.number("target_vs_actual_pct")) }
            return a < b ? .orderedAscending : .orderedDescending
        }
    }

    private func numberOrder(_ a: Double?, _ b: Double?) -> ComparisonResult {
        let lhs = a ?? -999
        let rhs = b ?? -999
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

private struct LaborChip {
    let name: String
    let value: String
    let health: Health
    var brand: Bool = false

    init(_ name: String, _ value: String, _ health: Health, brand: Bool = false) {
        self.name = name
        self.value = value
        self.health = health
        self.brand = brand
    }
}

private struct LaborStoreRow: View {
    let snap: LaborLineSnap
    let expanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 10 : 0) {
            Button(action: onToggle) {
                LaborCheapLine(snap: snap, expanded: expanded)
                    .equatable()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                LaborStoreExpand(
                    storeNumber: snap.storeNumber,
                    district: snap.district,
                    om: snap.om,
                    week: snap.week
                )
            }
        }
    }
}

struct LaborStoreExpand: View {
    @EnvironmentObject private var store: HeartbeatStore
    let storeNumber: String
    let district: String
    let om: String
    let week: String
    @State private var openWeek: String?

    private var weeks: [MetricRow] {
        store.laborWeeks(forStore: storeNumber)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("District \(district.isEmpty ? "—" : district)  ·  \(om.isEmpty ? "—" : om)  ·  \(week)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            weekBlock
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .onAppear {
            if openWeek == nil {
                let latest = weeks.first
                openWeek = latest?.textPayload["week"] ?? latest?.recordedOn
            }
        }
    }

    @ViewBuilder
    private var weekBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By week")
                .font(.subheadline.weight(.bold))
            if weeks.isEmpty {
                Text("This Labor file is store totals. Week and day drill-in needs the Total company day export.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(weeks) { week in
                    weekCard(week)
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

    private func weekCard(_ week: MetricRow) -> some View {
        let health = HeartbeatMath.laborHealth(week)
        let weekId = week.textPayload["week"] ?? week.recordedOn ?? "—"
        let isOpen = openWeek == weekId
        let days = isOpen ? store.laborDays(from: week).filter {
            ($0.chargedHrs ?? 0) > 0 || ($0.empowerHrs ?? 0) > 0 || ($0.schHrs ?? 0) > 0
        } : []
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    openWeek = isOpen ? nil : weekId
                }
            } label: {
                HStack {
                    Text("Week \(weekId)")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    HealthBadge(health: health, prominent: true)
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                }
            }
            .buttonStyle(.plain)
            laborGrid(from: week, health: health)
            if isOpen {
                VStack(alignment: .leading, spacing: 8) {
                    Text("By day")
                        .font(.subheadline.weight(.bold))
                    if days.isEmpty {
                        Text("No charged days in this week.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        ForEach(days) { day in
                            dayCard(day, week: week)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(wash(health).opacity(0.55))
        )
    }

    private func dayCard(_ day: LaborDay, week: MetricRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayDate(day.date))
                .font(.headline.weight(.semibold))
            laborGrid(day: day, week: week)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.bg)
        )
    }

    private func laborGrid(from row: MetricRow, health _: Health) -> some View {
        laborChipGrid(laborStoreChips(row))
    }

    private func laborGrid(day: LaborDay, week: MetricRow) -> some View {
        laborChipGrid(laborDayChips(day, week: week))
    }

    private func laborStoreChips(_ row: MetricRow) -> [LaborChip] {
        let tva = row.number("target_vs_actual_pct")
        let cost = row.number("cost_trgt_pct")
        let act = row.number("act_cost_pct")
        let efficiency = row.number("schedule_efficiency_pct")
        let over = row.number("over_schedule_pct")
        var chips: [LaborChip] = []
        chips.append(LaborChip("Tgt vs Act", HeartbeatFormat.pct(tva), HeartbeatMath.laborHealth(tva)))
        chips.append(LaborChip("CostTrgt%", HeartbeatFormat.pct(cost), .none, brand: true))
        chips.append(LaborChip("ActCost%", HeartbeatFormat.pct(act), actCostHealth(act, cost)))
        chips.append(LaborChip("Charged Hrs", HeartbeatFormat.num(row.number("charged_hrs"), digits: 1), .none))
        chips.append(LaborChip("Act Hrs", HeartbeatFormat.num(row.number("act_hrs"), digits: 1), .none))
        chips.append(LaborChip("Empower", HeartbeatFormat.num(row.number("empower_hrs"), digits: 1), .none))
        chips.append(LaborChip("Sch Hrs", HeartbeatFormat.num(row.number("sch_hrs"), digits: 1), .none))
        chips.append(LaborChip("Earned Hrs", HeartbeatFormat.num(row.number("earned_hrs"), digits: 1), .none))
        chips.append(LaborChip("ActCost$", HeartbeatFormat.money(row.number("act_cost_dollar")), .none))
        chips.append(LaborChip("Over %", HeartbeatFormat.pct(over), HeartbeatMath.varianceHealth(over)))
        chips.append(LaborChip("Sch Effi%", HeartbeatFormat.pct(efficiency), HeartbeatMath.band(efficiency, good: HeartbeatMath.scheduleGoal, watch: HeartbeatMath.scheduleWatch)))
        chips.append(LaborChip("Earned Util", HeartbeatFormat.pct(row.number("earned_hrs_util")), .none))
        chips.append(LaborChip("UPLH", HeartbeatFormat.pct(row.number("uplh_impact_pct")), impactHealth(row.number("uplh_impact_pct"))))
        chips.append(LaborChip("Wage", HeartbeatFormat.pct(row.number("wage_impact_pct")), impactHealth(row.number("wage_impact_pct"))))
        chips.append(LaborChip("AIV", HeartbeatFormat.pct(row.number("aiv_impact_pct")), impactHealth(row.number("aiv_impact_pct"))))
        return chips
    }

    private func laborDayChips(_ day: LaborDay, week: MetricRow) -> [LaborChip] {
        let cost = week.number("cost_trgt_pct")
        var chips: [LaborChip] = []
        chips.append(LaborChip("Charged Hrs", HeartbeatFormat.num(day.chargedHrs, digits: 1), .none))
        chips.append(LaborChip("Empower", HeartbeatFormat.num(day.empowerHrs, digits: 1), .none))
        chips.append(LaborChip("Sch Hrs", HeartbeatFormat.num(day.schHrs, digits: 1), .none))
        chips.append(LaborChip("Earned Hrs", HeartbeatFormat.num(day.earnedHrs, digits: 1), .none))
        chips.append(LaborChip("ActCost%", HeartbeatFormat.pct(day.actCostPct), actCostHealth(day.actCostPct, cost)))
        chips.append(LaborChip("Over %", HeartbeatFormat.pct(day.overSchedulePct), HeartbeatMath.varianceHealth(day.overSchedulePct)))
        chips.append(LaborChip("Sch Effi%", HeartbeatFormat.pct(day.scheduleEfficiencyPct), HeartbeatMath.band(day.scheduleEfficiencyPct, good: HeartbeatMath.scheduleGoal, watch: HeartbeatMath.scheduleWatch)))
        chips.append(LaborChip("Earned Util", HeartbeatFormat.pct(day.earnedHrsUtil), .none))
        return chips
    }

    private func laborChipGrid(_ items: [LaborChip]) -> some View {
        let rows = stride(from: 0, to: items.count, by: 4).map { Array(items[$0..<min($0 + 4, items.count)]) }
        return VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, item in
                        metric(item.name, item.value, item.health, brand: item.brand)
                    }
                    if row.count < 4 {
                        ForEach(0..<(4 - row.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func displayDate(_ raw: String) -> String {
        guard raw.count >= 10 else { return raw.isEmpty ? "—" : raw }
        let parts = raw.prefix(10).split(separator: "-")
        guard parts.count == 3 else { return raw }
        return "\(parts[1])/\(parts[2])/\(parts[0])"
    }

    private func metric(_ name: String, _ value: String, _ health: Health, brand: Bool = false) -> some View {
        let shouldPulse = health == .risk || health == .watch
        return VStack(spacing: 4) {
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(brand ? AppTheme.blue : ink(health))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(brand ? AppTheme.blueSoft : wash(health))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(brand ? AppTheme.blue.opacity(0.45) : chipStroke(health), lineWidth: shouldPulse ? 2 : 1)
        )
    }

    private func impactHealth(_ value: Double?) -> Health {
        guard let value else { return .none }
        return value <= 0 ? .good : .risk
    }

    private func actCostHealth(_ act: Double?, _ cost: Double?) -> Health {
        guard let act, let cost else { return .none }
        return act <= cost ? .good : .risk
    }

    private func chipStroke(_ health: Health) -> Color {
        switch health {
        case .good: return AppTheme.ok.opacity(0.35)
        case .watch: return AppTheme.warn
        case .risk: return AppTheme.bad
        case .none: return Color.clear
        }
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

private struct LostRevenueRollupRow: Identifiable {
    let id: String
    let label: String
    let storeCount: Int
    let lost: Double?
    let pct: Double?
    let goal: Double?
    let sales: Double?
    let post: Double?
    let refund: Double?
    let missed: Double?

    var health: Health { HeartbeatMath.lostRevenueHealth(pct: pct) }
}

private enum LostRevenueMath {
    static func sum(_ rows: [MetricRow], _ key: String) -> Double? {
        let values = rows.compactMap { $0.number(key) }
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    static func ratio(_ dollars: Double?, _ sales: Double?) -> Double? {
        guard let dollars, let sales, sales > 0 else { return nil }
        return dollars / sales * 100
    }

    static func pack(_ rows: [MetricRow]) -> LostRevenueRollupRow {
        let sales = sum(rows, "ecomm_sales")
        let lost = sum(rows, "lost_revenue")
        let goalDollars = sum(rows, "lost_revenue_goal")
        return LostRevenueRollupRow(
            id: "tmp",
            label: "",
            storeCount: rows.count,
            lost: lost,
            pct: ratio(lost, sales) ?? HeartbeatMath.average(rows.compactMap { $0.number("lost_revenue_pct") }),
            goal: ratio(goalDollars, sales) ?? HeartbeatMath.average(rows.compactMap { $0.number("lost_revenue_goal_pct") }),
            sales: sales,
            post: sum(rows, "post_sub_oos_foregone"),
            refund: sum(rows, "refund_lost"),
            missed: sum(rows, "missed_sales")
        )
    }
}

private enum LostRevenueRollupBuilder {
    static func grain(for filters: DashboardFilters) -> LaborRollupGrain? {
        LaborRollupBuilder.grain(for: filters)
    }

    static func source(from all: [MetricRow], filters: DashboardFilters) -> [MetricRow] {
        let stores = all.filter {
            $0.textPayload["lost_grain"] != "market" && !$0.storeNumber.isEmpty
        }
        if !filters.division.isEmpty || !filters.region.isEmpty {
            return stores.filter { filters.includesDivision($0.division) }
        }
        if !filters.district.isEmpty {
            let divisions = Set(
                stores.filter { HeartbeatMath.matches($0.district, filters.district) }.map(\.division)
            )
            return stores.filter { divisions.contains($0.division) }
        }
        if !filters.om.isEmpty {
            let divisions = Set(
                stores.filter { HeartbeatMath.matches($0.operationsOM, filters.om) }.map(\.division)
            )
            return stores.filter { divisions.contains($0.division) }
        }
        return stores
    }

    static func rows(from stores: [MetricRow], grain: LaborRollupGrain) -> [LostRevenueRollupRow] {
        var buckets: [String: [MetricRow]] = [:]
        for row in stores {
            let key: String
            switch grain {
            case .division:
                key = row.division.isEmpty ? "Unassigned" : MarketRegion.canonicalName(row.division)
            case .district:
                key = row.district.isEmpty ? "Unassigned" : row.district
            case .store:
                key = HeartbeatMath.canonicalStore(row.storeNumber)
            }
            guard !key.isEmpty else { continue }
            buckets[key, default: []].append(row)
        }
        var result: [LostRevenueRollupRow] = []
        result.reserveCapacity(buckets.count)
        for (key, group) in buckets {
            let packed = LostRevenueMath.pack(group)
            let label: String
            switch grain {
            case .division, .district:
                label = key
            case .store:
                let division = group.first?.division ?? ""
                label = division.isEmpty ? key : "\(key)  |  \(division)"
            }
            result.append(
                LostRevenueRollupRow(
                    id: key,
                    label: label,
                    storeCount: packed.storeCount,
                    lost: packed.lost,
                    pct: packed.pct,
                    goal: packed.goal,
                    sales: packed.sales,
                    post: packed.post,
                    refund: packed.refund,
                    missed: packed.missed
                )
            )
        }
        return result.sorted { ($0.lost ?? -1) > ($1.lost ?? -1) }
    }
}

private struct LostRevenueLineSnap: Identifiable, Equatable {
    let id: UUID
    let storeNumber: String
    let label: String
    let district: String
    let om: String
    let lost: String
    let pct: String
    let goal: String
    let sales: String
    let post: String
    let refund: String
    let missed: String
    let health: Health
    let lostValue: Double
    let pctValue: Double
    let goalValue: Double
    let salesValue: Double
    let postValue: Double
    let refundValue: Double
    let missedValue: Double

    init(_ row: MetricRow) {
        id = row.id
        storeNumber = row.storeNumber
        label = row.division.isEmpty
            ? (row.storeNumber.isEmpty ? "—" : row.storeNumber)
            : "\(row.storeNumber)  |  \(row.division)"
        district = row.district
        om = row.operationsOM
        let lostNum = row.number("lost_revenue")
        let pctNum = row.number("lost_revenue_pct")
        let goalNum = row.number("lost_revenue_goal_pct")
        let salesNum = row.number("ecomm_sales")
        let postNum = row.number("post_sub_oos_foregone")
        let refundNum = row.number("refund_lost")
        let missedNum = row.number("missed_sales")
        lost = HeartbeatFormat.moneyShort(lostNum)
        pct = HeartbeatFormat.pct(pctNum)
        goal = HeartbeatFormat.pct(goalNum)
        sales = HeartbeatFormat.moneyShort(salesNum)
        post = HeartbeatFormat.moneyShort(postNum)
        refund = HeartbeatFormat.moneyShort(refundNum)
        missed = HeartbeatFormat.moneyShort(missedNum)
        health = HeartbeatMath.lostRevenueHealth(pct: pctNum)
        lostValue = lostNum ?? -1
        pctValue = pctNum ?? -1
        goalValue = goalNum ?? -1
        salesValue = salesNum ?? -1
        postValue = postNum ?? -1
        refundValue = refundNum ?? -1
        missedValue = missedNum ?? -1
    }
}

private struct LostRevenueCheapLine: View, Equatable {
    let snap: LostRevenueLineSnap
    let expanded: Bool

    var body: some View {
        HStack(spacing: 6) {
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
            .frame(minWidth: 132, maxWidth: 190, alignment: .leading)
            cell(snap.lost, snap.health)
            cell(snap.pct, snap.health)
            cell(snap.goal, .none, brand: true)
            cell(snap.sales, .none, brand: true)
            cell(snap.post, .none)
            cell(snap.refund, .none)
            cell(snap.missed, .none)
            Text(snap.health.label.uppercased())
                .font(.caption.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .foregroundStyle(Color.white)
                .background(pill(snap.health), in: Capsule())
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 4)
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
            .background(brand ? AppTheme.blueSoft : wash(health), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

private struct LostRevenueMetricLine: View, Equatable {
    let label: String
    var count: Int? = nil
    let lost: Double?
    let pct: Double?
    let goal: Double?
    let sales: Double?
    let post: Double?
    let refund: Double?
    let missed: Double?

    var body: some View {
        let health = HeartbeatMath.lostRevenueHealth(pct: pct)
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
            cell(HeartbeatFormat.moneyShort(lost), health)
            cell(HeartbeatFormat.pct(pct), health)
            cell(HeartbeatFormat.pct(goal), .none, brand: true)
            cell(HeartbeatFormat.moneyShort(sales), .none, brand: true)
            cell(HeartbeatFormat.moneyShort(post), .none)
            cell(HeartbeatFormat.moneyShort(refund), .none)
            cell(HeartbeatFormat.moneyShort(missed), .none)
            HealthBadge(health: health, prominent: true, compact: true)
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 4)
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

struct LostRevenueMetricHeader: View {
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
            head("Lost $", key: "lost")
            head("Lost %", key: "pct")
            head("Goal %", key: "goal")
            head("eComm $", key: "sales")
            head("Post Sub", key: "post")
            head("Refund", key: "refund")
            head("Missed", key: "missed")
            head("Status", key: "status", alignment: .trailing)
                .frame(width: 88, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .tracking(0.4)
        .lineLimit(1)
        .minimumScaleFactor(0.65)
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
        .foregroundStyle(selected ? AppTheme.blue : AppTheme.textTertiary)
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

struct LostRevenueStickyStoreHeader: View {
    @EnvironmentObject private var pin: LaborHeaderPin

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
            LostRevenueMetricHeader(
                label: "Store",
                showCount: false,
                active: pin.active,
                ascending: pin.ascending,
                onSelect: { pin.onSelect?($0) }
            )
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

struct LostRevenueRollupTable: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var headerPin: LaborHeaderPin

    private var expanded: Bool { headerPin.rollupExpanded }

    var body: some View {
        if let grain, !summary.isEmpty {
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
                    VStack(alignment: .leading, spacing: 10) {
                    LostRevenueMetricHeader(label: grain.columnTitle, showCount: grain != .store)
                    ForEach(summary) { row in
                        LostRevenueMetricLine(
                            label: row.label,
                            count: grain == .store ? nil : row.storeCount,
                            lost: row.lost,
                            pct: row.pct,
                            goal: row.goal,
                            sales: row.sales,
                            post: row.post,
                            refund: row.refund,
                            missed: row.missed
                        )
                    }
                                    }
                    .padding(16)
                }
            }
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .stroke(AppTheme.blue, lineWidth: 2.5)
            )
        }
    }

    private var grain: LaborRollupGrain? {
        LostRevenueRollupBuilder.grain(for: store.filters)
    }

    private var summary: [LostRevenueRollupRow] {
        guard let grain else { return [] }
        let source = LostRevenueRollupBuilder.source(from: store.displayRows(for: .lostRevenue), filters: store.filters)
        var rows = LostRevenueRollupBuilder.rows(from: source, grain: grain)
        if grain == .division {
            for extra in RollupMarketFill.missingDivisions(present: rows.map(\.label), markets: store.marketStores(), filters: store.filters) {
                rows.append(
                    LostRevenueRollupRow(
                        id: extra.name,
                        label: extra.name,
                        storeCount: extra.storeCount,
                        lost: nil,
                        pct: nil,
                        goal: nil,
                        sales: nil,
                        post: nil,
                        refund: nil,
                        missed: nil
                    )
                )
            }
            rows.sort { ($0.lost ?? -1) > ($1.lost ?? -1) }
        }
        return rows
    }
}

struct LostRevenueTable: View {
    @EnvironmentObject private var headerPin: LaborHeaderPin
    let rows: [MetricRow]

    private enum Column: String, CaseIterable, Identifiable {
        case store, lost, pct, goal, sales, post, refund, missed, status
        var id: String { rawValue }
        var key: String {
            switch self {
            case .store: return "label"
            case .lost: return "lost"
            case .pct: return "pct"
            case .goal: return "goal"
            case .sales: return "sales"
            case .post: return "post"
            case .refund: return "refund"
            case .missed: return "missed"
            case .status: return "status"
            }
        }
    }

    @State private var sort = Column.lost
    @State private var ascending = false
    @State private var snaps: [LostRevenueLineSnap] = []
    @State private var openStore: String?

    private var expanded: Bool { headerPin.storesExpanded }

    var body: some View {
        if rows.isEmpty {
            Section {
                EmptyHint(
                    symbol: "chart.line.downtrend.xyaxis",
                    title: "No stores in this view",
                    detail: "Tap Total lost revenue to see every store, or pick another callout."
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
        } else {
            Section {
                Button {
                    let next = !headerPin.storesExpanded
                    headerPin.storesExpanded = next
                    headerPin.tableOpen = next
                    if !next { headerPin.pinned = false }
                    if next { rebuildOrder(sort: sort, ascending: ascending) }
                } label: {
                    HubTableHeader(
                            icon: "storefront.fill",
                            title: "Store",
                            accessory: "\(HeartbeatFormat.num(Double(rows.count))) stores  ·  tap to \(expanded ? "collapse" : "expand")",
                            expanded: expanded
                        )
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 2.5)
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: expanded ? 4 : 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
                .onAppear {
                    headerPin.tableOpen = headerPin.storesExpanded
                    headerPin.storeCount = rows.count
                    headerPin.active = sort.key
                    headerPin.ascending = ascending
                    headerPin.onSelect = applyHeaderSort
                }
            }
            if expanded {
                Section {
                    LostRevenueMetricHeader(
                        label: "Store",
                        showCount: false,
                        active: sort.key,
                        ascending: ascending,
                        onSelect: applyHeaderSort
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: LaborHeaderMinYKey.self,
                                value: (geo.frame(in: .global).minY / 12).rounded() * 12
                            )
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 2, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
                    ForEach(snaps) { snap in
                        LostRevenueStoreRow(
                            snap: snap,
                            expanded: openStore == snap.storeNumber,
                            onToggle: {
                                openStore = openStore == snap.storeNumber ? nil : snap.storeNumber
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                    }
                }
                .transaction { $0.animation = nil }
                .onAppear { rebuildOrder(sort: sort, ascending: ascending) }
                .onChange(of: rows.count) { _, _ in
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
                .onChange(of: rows.first?.storeNumber) { _, _ in
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
            }
        }
    }

    private func applyHeaderSort(_ key: String) {
        let column = Column.allCases.first { $0.key == key } ?? .lost
        let nextAscending = sort == column ? !ascending : column == .store
        sort = column
        ascending = nextAscending
        headerPin.active = column.key
        headerPin.ascending = nextAscending
        rebuildOrder(sort: column, ascending: nextAscending)
    }

    private func rebuildOrder(sort: Column, ascending: Bool) {
        snaps = rows.sorted { lhs, rhs in
            let result = compare(lhs, rhs, sort: sort)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }.map(LostRevenueLineSnap.init)
    }

    private func compare(_ lhs: MetricRow, _ rhs: MetricRow, sort: Column) -> ComparisonResult {
        switch sort {
        case .store:
            if let a = Int(lhs.storeNumber), let b = Int(rhs.storeNumber) {
                return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
            }
            return lhs.storeNumber.localizedStandardCompare(rhs.storeNumber)
        case .lost:
            return numberOrder(lhs.number("lost_revenue"), rhs.number("lost_revenue"))
        case .pct:
            return numberOrder(lhs.number("lost_revenue_pct"), rhs.number("lost_revenue_pct"))
        case .goal:
            return numberOrder(lhs.number("lost_revenue_goal_pct"), rhs.number("lost_revenue_goal_pct"))
        case .sales:
            return numberOrder(lhs.number("ecomm_sales"), rhs.number("ecomm_sales"))
        case .post:
            return numberOrder(lhs.number("post_sub_oos_foregone"), rhs.number("post_sub_oos_foregone"))
        case .refund:
            return numberOrder(lhs.number("refund_lost"), rhs.number("refund_lost"))
        case .missed:
            return numberOrder(lhs.number("missed_sales"), rhs.number("missed_sales"))
        case .status:
            let a = healthRank(HeartbeatMath.lostRevenueHealth(lhs))
            let b = healthRank(HeartbeatMath.lostRevenueHealth(rhs))
            if a == b { return numberOrder(lhs.number("lost_revenue_pct"), rhs.number("lost_revenue_pct")) }
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

private struct LostRevenueStoreRow: View {
    let snap: LostRevenueLineSnap
    let expanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 10 : 0) {
            Button(action: onToggle) {
                LostRevenueCheapLine(snap: snap, expanded: expanded)
                    .equatable()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                LostRevenueStoreExpand(snap: snap)
            }
        }
    }
}

private struct LostRevenueStoreExpand: View {
    let snap: LostRevenueLineSnap

    private var chips: [(String, String, Health, Bool)] {
        [
            ("Lost $", snap.lost, snap.health, false),
            ("Lost %", snap.pct, snap.health, false),
            ("FY2026 Goal", snap.goal, .none, true),
            ("eComm sales", snap.sales, .none, true),
            ("Post Sub OOS", snap.post, .none, false),
            ("Refund", snap.refund, .none, false),
            ("Missed sales", snap.missed, .none, false),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("District \(snap.district.isEmpty ? "—" : snap.district)  ·  \(snap.om.isEmpty ? "—" : snap.om)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            chipGrid
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.card.opacity(0.9))
        )
    }

    private var chipGrid: some View {
        let rows = stride(from: 0, to: chips.count, by: 4).map { Array(chips[$0..<min($0 + 4, chips.count)]) }
        return VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, item in
                        metric(item.0, item.1, item.2, brand: item.3)
                    }
                    if row.count < 4 {
                        ForEach(0..<(4 - row.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func metric(_ name: String, _ value: String, _ health: Health, brand: Bool) -> some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(brand ? AppTheme.blue : ink(health))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
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

struct ScheduleTable: View {
    @EnvironmentObject private var headerPin: LaborHeaderPin
    let rows: [MetricRow]

    private enum Column: String, CaseIterable, Identifiable {
        case store, efficiency, goal, under, over, status
        var id: String { rawValue }
        var key: String {
            switch self {
            case .store: return "label"
            case .efficiency: return "efficiency"
            case .goal: return "goal"
            case .under: return "under"
            case .over: return "over"
            case .status: return "status"
            }
        }
    }

    @State private var sort = Column.efficiency
    @State private var ascending = true
    @State private var snaps: [ScheduleLineSnap] = []
    @State private var openStore: String?

    private var expanded: Bool { headerPin.storesExpanded }

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
                Button {
                    let next = !headerPin.storesExpanded
                    headerPin.storesExpanded = next
                    headerPin.tableOpen = next
                    if !next { headerPin.pinned = false }
                    if next { rebuildOrder(sort: sort, ascending: ascending) }
                } label: {
                    HubTableHeader(
                            icon: "storefront.fill",
                            title: "Store",
                            accessory: "\(HeartbeatFormat.num(Double(rows.count))) stores  ·  tap to \(expanded ? "collapse" : "expand")",
                            expanded: expanded
                        )
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 2.5)
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: expanded ? 4 : 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
                .onAppear {
                    headerPin.tableOpen = headerPin.storesExpanded
                    headerPin.storeCount = rows.count
                    headerPin.active = sort.key
                    headerPin.ascending = ascending
                    headerPin.onSelect = applyHeaderSort
                }
            }
            if expanded {
                Section {
                    ScheduleMetricHeader(
                        label: "Store",
                        showCount: false,
                        active: sort.key,
                        ascending: ascending,
                        onSelect: applyHeaderSort
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: LaborHeaderMinYKey.self,
                                value: (geo.frame(in: .global).minY / 12).rounded() * 12
                            )
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 2, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
                    ForEach(snaps) { snap in
                        ScheduleStoreRow(
                            snap: snap,
                            expanded: openStore == snap.storeNumber,
                            onToggle: {
                                openStore = openStore == snap.storeNumber ? nil : snap.storeNumber
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                    }
                }
                .transaction { $0.animation = nil }
                .onAppear { rebuildOrder(sort: sort, ascending: ascending) }
                .onChange(of: rows.count) { _, _ in
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
                .onChange(of: rows.first?.storeNumber) { _, _ in
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
            }
        }
    }

    private func applyHeaderSort(_ key: String) {
        let column = Column.allCases.first { $0.key == key } ?? .efficiency
        let nextAscending = sort == column ? !ascending : column == .store
        sort = column
        ascending = nextAscending
        headerPin.active = column.key
        headerPin.ascending = nextAscending
        rebuildOrder(sort: column, ascending: nextAscending)
    }

    private func rebuildOrder(sort: Column, ascending: Bool) {
        snaps = rows.sorted { lhs, rhs in
            let result = compare(lhs, rhs, sort: sort)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }.map(ScheduleLineSnap.init)
    }

    private func compare(_ lhs: MetricRow, _ rhs: MetricRow, sort: Column) -> ComparisonResult {
        switch sort {
        case .store:
            if let a = Int(lhs.storeNumber), let b = Int(rhs.storeNumber) {
                return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
            }
            return lhs.storeNumber.localizedStandardCompare(rhs.storeNumber)
        case .efficiency, .goal:
            return numberOrder(ScheduleMath.efficiency(lhs), ScheduleMath.efficiency(rhs))
        case .under:
            return numberOrder(ScheduleMath.under(lhs), ScheduleMath.under(rhs))
        case .over:
            return numberOrder(ScheduleMath.over(lhs), ScheduleMath.over(rhs))
        case .status:
            let a = healthRank(HeartbeatMath.health(for: .scheduleQuality, row: lhs))
            let b = healthRank(HeartbeatMath.health(for: .scheduleQuality, row: rhs))
            if a == b { return numberOrder(ScheduleMath.efficiency(lhs), ScheduleMath.efficiency(rhs)) }
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

private enum ScheduleMath {
    static let goalText = "90%"

    static func efficiency(_ row: MetricRow) -> Double? {
        row.number("schedule_efficiency_pct")
    }

    static func under(_ row: MetricRow) -> Double? {
        row.number("under_schedule_pct", "under_scheduled")
    }

    static func over(_ row: MetricRow) -> Double? {
        row.number("over_schedule_pct", "over_scheduled")
    }

    static func efficiencyHealth(_ value: Double?) -> Health {
        guard value != nil else { return .none }
        return HeartbeatMath.band(value, good: HeartbeatMath.scheduleGoal, watch: HeartbeatMath.scheduleWatch)
    }
}

private struct ScheduleRollupRow: Identifiable {
    let id: String
    let label: String
    let storeCount: Int
    let efficiency: Double?
    let under: Double?
    let over: Double?

    var health: Health {
        let underHealth = HeartbeatMath.varianceHealth(under)
        let overHealth = HeartbeatMath.varianceHealth(over)
        let efficiencyHealth = ScheduleMath.efficiencyHealth(efficiency)
        let ranks: [Health: Int] = [.none: 0, .good: 1, .watch: 2, .risk: 3]
        return [underHealth, overHealth, efficiencyHealth].max { (ranks[$0] ?? 0) < (ranks[$1] ?? 0) } ?? .none
    }
}

private enum ScheduleRollupBuilder {
    static func grain(for filters: DashboardFilters) -> LaborRollupGrain? {
        LaborRollupBuilder.grain(for: filters)
    }

    static func source(from all: [MetricRow], filters: DashboardFilters) -> [MetricRow] {
        let stores = all.filter { !$0.storeNumber.isEmpty && ScheduleMath.efficiency($0) != nil }
        if !filters.division.isEmpty || !filters.region.isEmpty {
            return stores.filter { filters.includesDivision($0.division) }
        }
        if !filters.district.isEmpty {
            let divisions = Set(
                stores.filter { HeartbeatMath.matches($0.district, filters.district) }.map(\.division)
            )
            return stores.filter { divisions.contains($0.division) }
        }
        if !filters.om.isEmpty {
            let divisions = Set(
                stores.filter { HeartbeatMath.matches($0.operationsOM, filters.om) }.map(\.division)
            )
            return stores.filter { divisions.contains($0.division) }
        }
        return stores
    }

    static func rows(from stores: [MetricRow], grain: LaborRollupGrain) -> [ScheduleRollupRow] {
        var buckets: [String: [MetricRow]] = [:]
        for row in stores {
            let key: String
            switch grain {
            case .division:
                key = row.division.isEmpty ? "Unassigned" : MarketRegion.canonicalName(row.division)
            case .district:
                key = row.district.isEmpty ? "Unassigned" : row.district
            case .store:
                key = HeartbeatMath.canonicalStore(row.storeNumber)
            }
            guard !key.isEmpty else { continue }
            buckets[key, default: []].append(row)
        }
        var result: [ScheduleRollupRow] = []
        result.reserveCapacity(buckets.count)
        for (key, group) in buckets {
            let label: String
            switch grain {
            case .division, .district:
                label = key
            case .store:
                let division = group.first?.division ?? ""
                label = division.isEmpty ? key : "\(key)  |  \(division)"
            }
            result.append(
                ScheduleRollupRow(
                    id: key,
                    label: label,
                    storeCount: group.count,
                    efficiency: HeartbeatMath.average(group.compactMap(ScheduleMath.efficiency)),
                    under: HeartbeatMath.average(group.compactMap(ScheduleMath.under)),
                    over: HeartbeatMath.average(group.compactMap(ScheduleMath.over))
                )
            )
        }
        return result.sorted { ($0.efficiency ?? 999) < ($1.efficiency ?? 999) }
    }
}

private struct ScheduleLineSnap: Identifiable, Equatable {
    let id: UUID
    let storeNumber: String
    let label: String
    let district: String
    let om: String
    let efficiency: String
    let under: String
    let over: String
    let health: Health
    let efficiencyHealth: Health
    let underHealth: Health
    let overHealth: Health
    let efficiencyValue: Double
    let underValue: Double
    let overValue: Double

    init(_ row: MetricRow) {
        id = row.id
        storeNumber = row.storeNumber
        label = row.division.isEmpty
            ? (row.storeNumber.isEmpty ? "—" : row.storeNumber)
            : "\(row.storeNumber)  |  \(row.division)"
        district = row.district
        om = row.operationsOM
        let efficiencyNum = ScheduleMath.efficiency(row)
        let underNum = ScheduleMath.under(row)
        let overNum = ScheduleMath.over(row)
        efficiency = HeartbeatFormat.pct(efficiencyNum)
        under = HeartbeatFormat.pct(underNum)
        over = HeartbeatFormat.pct(overNum)
        health = HeartbeatMath.health(for: .scheduleQuality, row: row)
        efficiencyHealth = ScheduleMath.efficiencyHealth(efficiencyNum)
        underHealth = HeartbeatMath.varianceHealth(underNum)
        overHealth = HeartbeatMath.varianceHealth(overNum)
        efficiencyValue = efficiencyNum ?? -1
        underValue = underNum ?? -1
        overValue = overNum ?? -1
    }
}

private struct ScheduleCheapLine: View, Equatable {
    let snap: ScheduleLineSnap
    let expanded: Bool

    var body: some View {
        HStack(spacing: 6) {
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
            .frame(minWidth: 132, maxWidth: 190, alignment: .leading)
            cell(snap.efficiency, snap.efficiencyHealth)
            cell(ScheduleMath.goalText, .none, brand: true)
            cell(snap.under, snap.underHealth)
            cell(snap.over, snap.overHealth)
            Text(snap.health.label.uppercased())
                .font(.caption.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .foregroundStyle(Color.white)
                .background(pill(snap.health), in: Capsule())
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 4)
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
            .background(brand ? AppTheme.blueSoft : wash(health), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

private struct ScheduleMetricLine: View, Equatable {
    let label: String
    var count: Int? = nil
    let efficiency: Double?
    let under: Double?
    let over: Double?

    var body: some View {
        let health = ScheduleRollupRow(id: label, label: label, storeCount: count ?? 0, efficiency: efficiency, under: under, over: over).health
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
            cell(HeartbeatFormat.pct(efficiency), ScheduleMath.efficiencyHealth(efficiency))
            cell(ScheduleMath.goalText, .none, brand: true)
            cell(HeartbeatFormat.pct(under), HeartbeatMath.varianceHealth(under))
            cell(HeartbeatFormat.pct(over), HeartbeatMath.varianceHealth(over))
            HealthBadge(health: health, prominent: true, compact: true)
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 4)
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

struct ScheduleMetricHeader: View {
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
            head("Efficiency", key: "efficiency")
            head("Goal", key: "goal")
            head("Under", key: "under")
            head("Over", key: "over")
            head("Status", key: "status", alignment: .trailing)
                .frame(width: 88, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .tracking(0.4)
        .lineLimit(1)
        .minimumScaleFactor(0.65)
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
        .foregroundStyle(selected ? AppTheme.blue : AppTheme.textTertiary)
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

struct ScheduleStickyStoreHeader: View {
    @EnvironmentObject private var pin: LaborHeaderPin

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
            ScheduleMetricHeader(
                label: "Store",
                showCount: false,
                active: pin.active,
                ascending: pin.ascending,
                onSelect: { pin.onSelect?($0) }
            )
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

struct ScheduleRollupTable: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var headerPin: LaborHeaderPin

    private var expanded: Bool { headerPin.rollupExpanded }

    var body: some View {
        if let grain, !summary.isEmpty {
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
                    VStack(alignment: .leading, spacing: 10) {
                    ScheduleMetricHeader(label: grain.columnTitle, showCount: grain != .store)
                    ForEach(summary) { row in
                        ScheduleMetricLine(
                            label: row.label,
                            count: grain == .store ? nil : row.storeCount,
                            efficiency: row.efficiency,
                            under: row.under,
                            over: row.over
                        )
                    }
                                    }
                    .padding(16)
                }
            }
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .stroke(AppTheme.blue, lineWidth: 2.5)
            )
        }
    }

    private var grain: LaborRollupGrain? {
        ScheduleRollupBuilder.grain(for: store.filters)
    }

    private var summary: [ScheduleRollupRow] {
        guard let grain else { return [] }
        let source = ScheduleRollupBuilder.source(from: store.displayRows(for: .scheduleQuality), filters: store.filters)
        var rows = ScheduleRollupBuilder.rows(from: source, grain: grain)
        if grain == .division {
            for extra in RollupMarketFill.missingDivisions(present: rows.map(\.label), markets: store.marketStores(), filters: store.filters) {
                rows.append(ScheduleRollupRow(id: extra.name, label: extra.name, storeCount: extra.storeCount, efficiency: nil, under: nil, over: nil))
            }
            rows.sort { ($0.efficiency ?? 999) < ($1.efficiency ?? 999) }
        }
        return rows
    }
}

private struct ScheduleStoreRow: View {
    let snap: ScheduleLineSnap
    let expanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 10 : 0) {
            Button(action: onToggle) {
                ScheduleCheapLine(snap: snap, expanded: expanded)
                    .equatable()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                ScheduleStoreExpand(snap: snap)
            }
        }
    }
}

private struct ScheduleStoreExpand: View {
    let snap: ScheduleLineSnap

    private var chips: [(String, String, Health, Bool)] {
        [
            ("Efficiency", snap.efficiency, snap.efficiencyHealth, false),
            ("Goal", ScheduleMath.goalText, .none, true),
            ("Under", snap.under, snap.underHealth, false),
            ("Over", snap.over, snap.overHealth, false),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("District \(snap.district.isEmpty ? "—" : snap.district)  ·  \(snap.om.isEmpty ? "—" : snap.om)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            chipGrid
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.card.opacity(0.9))
        )
    }

    private var chipGrid: some View {
        let rows = stride(from: 0, to: chips.count, by: 3).map { Array(chips[$0..<min($0 + 3, chips.count)]) }
        return VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, item in
                        metric(item.0, item.1, item.2, brand: item.3)
                    }
                }
            }
        }
    }

    private func metric(_ name: String, _ value: String, _ health: Health, brand: Bool) -> some View {
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
            if !brand {
                HealthBadge(health: health)
            }
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

struct PPHTable: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var headerPin: LaborHeaderPin
    let rows: [MetricRow]

    private enum Column: String, CaseIterable, Identifiable {
        case store, pph, pickers, goal, status
        var id: String { rawValue }
        var key: String {
            switch self {
            case .store: return "label"
            case .pph: return "pph"
            case .pickers: return "pickers"
            case .goal: return "goal"
            case .status: return "status"
            }
        }
    }

    @State private var sort = Column.pph
    @State private var ascending = true
    @State private var snaps: [PPHLineSnap] = []
    @State private var openStore: String?

    private var expanded: Bool { headerPin.storesExpanded }

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
                Button {
                    let next = !headerPin.storesExpanded
                    headerPin.storesExpanded = next
                    headerPin.tableOpen = next
                    if !next { headerPin.pinned = false }
                    if next { rebuildOrder(sort: sort, ascending: ascending) }
                } label: {
                    HubTableHeader(
                            icon: "storefront.fill",
                            title: "Store",
                            accessory: "\(HeartbeatFormat.num(Double(rows.count))) stores  ·  tap to \(expanded ? "collapse" : "expand")",
                            expanded: expanded
                        )
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 2.5)
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: expanded ? 4 : 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
                .onAppear {
                    headerPin.tableOpen = headerPin.storesExpanded
                    headerPin.storeCount = rows.count
                    headerPin.active = sort.key
                    headerPin.ascending = ascending
                    headerPin.onSelect = applyHeaderSort
                }
            }
            if expanded {
                Section {
                    PPHMetricHeader(
                        label: "Store",
                        showCount: false,
                        active: sort.key,
                        ascending: ascending,
                        onSelect: applyHeaderSort
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: LaborHeaderMinYKey.self,
                                value: (geo.frame(in: .global).minY / 12).rounded() * 12
                            )
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 2, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
                    ForEach(snaps) { snap in
                        PPHStoreRow(
                            snap: snap,
                            expanded: openStore == snap.storeNumber,
                            onToggle: {
                                openStore = openStore == snap.storeNumber ? nil : snap.storeNumber
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                    }
                }
                .transaction { $0.animation = nil }
                .onAppear { rebuildOrder(sort: sort, ascending: ascending) }
                .onChange(of: rows.count) { _, _ in
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
                .onChange(of: rows.first?.storeNumber) { _, _ in
                    rebuildOrder(sort: sort, ascending: ascending)
                    headerPin.storeCount = rows.count
                }
            }
        }
    }

    private func applyHeaderSort(_ key: String) {
        let column = Column.allCases.first { $0.key == key } ?? .pph
        let nextAscending = sort == column ? !ascending : column == .store
        sort = column
        ascending = nextAscending
        headerPin.active = column.key
        headerPin.ascending = nextAscending
        rebuildOrder(sort: column, ascending: nextAscending)
    }

    private func rebuildOrder(sort: Column, ascending: Bool) {
        let counts = Dictionary(uniqueKeysWithValues: rows.map { ($0.storeNumber, store.pphPickerCount(forStore: $0.storeNumber)) })
        snaps = rows.sorted { lhs, rhs in
            let result = compare(lhs, rhs, sort: sort, counts: counts)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }.map { PPHLineSnap($0, pickerCount: counts[$0.storeNumber] ?? 0) }
    }

    private func compare(_ lhs: MetricRow, _ rhs: MetricRow, sort: Column, counts: [String: Int]) -> ComparisonResult {
        switch sort {
        case .store:
            if let a = Int(lhs.storeNumber), let b = Int(rhs.storeNumber) {
                return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
            }
            return lhs.storeNumber.localizedStandardCompare(rhs.storeNumber)
        case .pph, .goal:
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

private enum PPHMath {
    static let goalText = "80.0"

    static func pphHealth(_ value: Double?) -> Health {
        guard value != nil else { return .none }
        return HeartbeatMath.band(value, good: HeartbeatMath.pphGoal, watch: HeartbeatMath.pphRisk)
    }
}

private struct PPHRollupRow: Identifiable {
    let id: String
    let label: String
    let storeCount: Int
    let pph: Double?
    let pickers: Int

    var health: Health { PPHMath.pphHealth(pph) }
}

private enum PPHRollupBuilder {
    static func grain(for filters: DashboardFilters) -> LaborRollupGrain? {
        LaborRollupBuilder.grain(for: filters)
    }

    static func source(from all: [MetricRow], filters: DashboardFilters) -> [MetricRow] {
        let stores = all.filter { !$0.storeNumber.isEmpty && $0.number("pph") != nil }
        if !filters.division.isEmpty || !filters.region.isEmpty {
            return stores.filter { filters.includesDivision($0.division) }
        }
        if !filters.district.isEmpty {
            let divisions = Set(
                stores.filter { HeartbeatMath.matches($0.district, filters.district) }.map(\.division)
            )
            return stores.filter { divisions.contains($0.division) }
        }
        if !filters.om.isEmpty {
            let divisions = Set(
                stores.filter { HeartbeatMath.matches($0.operationsOM, filters.om) }.map(\.division)
            )
            return stores.filter { divisions.contains($0.division) }
        }
        return stores
    }

    static func rows(from stores: [MetricRow], grain: LaborRollupGrain, pickerCount: (String) -> Int) -> [PPHRollupRow] {
        var buckets: [String: [MetricRow]] = [:]
        for row in stores {
            let key: String
            switch grain {
            case .division:
                key = row.division.isEmpty ? "Unassigned" : MarketRegion.canonicalName(row.division)
            case .district:
                key = row.district.isEmpty ? "Unassigned" : row.district
            case .store:
                key = HeartbeatMath.canonicalStore(row.storeNumber)
            }
            guard !key.isEmpty else { continue }
            buckets[key, default: []].append(row)
        }
        var result: [PPHRollupRow] = []
        result.reserveCapacity(buckets.count)
        for (key, group) in buckets {
            let label: String
            switch grain {
            case .division, .district:
                label = key
            case .store:
                let division = group.first?.division ?? ""
                label = division.isEmpty ? key : "\(key)  |  \(division)"
            }
            result.append(
                PPHRollupRow(
                    id: key,
                    label: label,
                    storeCount: group.count,
                    pph: HeartbeatMath.average(group.compactMap { $0.number("pph") }),
                    pickers: group.reduce(0) { $0 + pickerCount($1.storeNumber) }
                )
            )
        }
        return result.sorted { ($0.pph ?? 999) < ($1.pph ?? 999) }
    }
}

private struct PPHLineSnap: Identifiable, Equatable {
    let id: UUID
    let storeNumber: String
    let label: String
    let district: String
    let om: String
    let pph: String
    let pickers: String
    let health: Health
    let pphValue: Double
    let pickerValue: Double

    init(_ row: MetricRow, pickerCount: Int) {
        id = row.id
        storeNumber = row.storeNumber
        label = row.division.isEmpty
            ? (row.storeNumber.isEmpty ? "—" : row.storeNumber)
            : "\(row.storeNumber)  |  \(row.division)"
        district = row.district
        om = row.operationsOM
        let pphNum = row.number("pph")
        pph = HeartbeatFormat.num(pphNum, digits: 1)
        pickers = HeartbeatFormat.num(Double(pickerCount))
        health = HeartbeatMath.health(for: .pph, row: row)
        pphValue = pphNum ?? -1
        pickerValue = Double(pickerCount)
    }
}

private struct PPHCheapLine: View, Equatable {
    let snap: PPHLineSnap
    let expanded: Bool

    var body: some View {
        HStack(spacing: 6) {
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
            .frame(minWidth: 132, maxWidth: 190, alignment: .leading)
            cell(snap.pph, snap.health)
            cell(snap.pickers, .none)
            cell(PPHMath.goalText, .none, brand: true)
            Text(snap.health.label.uppercased())
                .font(.caption.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .foregroundStyle(Color.white)
                .background(pill(snap.health), in: Capsule())
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 4)
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
            .background(brand ? AppTheme.blueSoft : wash(health), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

private struct PPHMetricLine: View, Equatable {
    let label: String
    var count: Int? = nil
    let pph: Double?
    let pickers: Int

    var body: some View {
        let health = PPHMath.pphHealth(pph)
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
            cell(HeartbeatFormat.num(pph, digits: 1), health)
            cell(HeartbeatFormat.num(Double(pickers)), .none)
            cell(PPHMath.goalText, .none, brand: true)
            HealthBadge(health: health, prominent: true, compact: true)
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 4)
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

struct PPHMetricHeader: View {
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
            head("Pure PPH", key: "pph")
            head("Pickers", key: "pickers")
            head("Goal", key: "goal")
            head("Status", key: "status", alignment: .trailing)
                .frame(width: 88, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .tracking(0.4)
        .lineLimit(1)
        .minimumScaleFactor(0.65)
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
        .foregroundStyle(selected ? AppTheme.blue : AppTheme.textTertiary)
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

struct PPHStickyStoreHeader: View {
    @EnvironmentObject private var pin: LaborHeaderPin

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
            PPHMetricHeader(
                label: "Store",
                showCount: false,
                active: pin.active,
                ascending: pin.ascending,
                onSelect: { pin.onSelect?($0) }
            )
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

struct PPHRollupTable: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var headerPin: LaborHeaderPin

    private var expanded: Bool { headerPin.rollupExpanded }

    var body: some View {
        if let grain, !summary.isEmpty {
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
                    VStack(alignment: .leading, spacing: 10) {
                    PPHMetricHeader(label: grain.columnTitle, showCount: grain != .store)
                    ForEach(summary) { row in
                        PPHMetricLine(
                            label: row.label,
                            count: grain == .store ? nil : row.storeCount,
                            pph: row.pph,
                            pickers: row.pickers
                        )
                    }
                                    }
                    .padding(16)
                }
            }
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .stroke(AppTheme.blue, lineWidth: 2.5)
            )
        }
    }

    private var grain: LaborRollupGrain? {
        PPHRollupBuilder.grain(for: store.filters)
    }

    private var summary: [PPHRollupRow] {
        guard let grain else { return [] }
        let source = PPHRollupBuilder.source(from: store.displayRows(for: .pph), filters: store.filters)
        var rows = PPHRollupBuilder.rows(from: source, grain: grain, pickerCount: { store.pphPickerCount(forStore: $0) })
        if grain == .division {
            for extra in RollupMarketFill.missingDivisions(present: rows.map(\.label), markets: store.marketStores(), filters: store.filters) {
                rows.append(PPHRollupRow(id: extra.name, label: extra.name, storeCount: extra.storeCount, pph: nil, pickers: 0))
            }
            rows.sort { ($0.pph ?? 999) < ($1.pph ?? 999) }
        }
        return rows
    }
}

private struct PPHStoreRow: View {
    let snap: PPHLineSnap
    let expanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 10 : 0) {
            Button(action: onToggle) {
                PPHCheapLine(snap: snap, expanded: expanded)
                    .equatable()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                PPHStoreExpand(snap: snap)
            }
        }
    }
}

private struct PPHStoreExpand: View {
    @EnvironmentObject private var store: HeartbeatStore
    let snap: PPHLineSnap

    private var pickers: [MetricRow] {
        store.pphPickers(forStore: snap.storeNumber).sorted {
            ($0.number("pph") ?? 999) < ($1.number("pph") ?? 999)
        }
    }

    private var chips: [(String, String, Health, Bool)] {
        [
            ("Pure PPH", snap.pph, snap.health, false),
            ("Pickers", snap.pickers, .none, false),
            ("Goal", PPHMath.goalText, .none, true),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("District \(snap.district.isEmpty ? "—" : snap.district)  ·  \(snap.om.isEmpty ? "—" : snap.om)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            chipGrid
            pickerBlock
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.card.opacity(0.9))
        )
    }

    private var chipGrid: some View {
        HStack(spacing: 8) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, item in
                metric(item.0, item.1, item.2, brand: item.3)
            }
        }
    }

    @ViewBuilder
    private var pickerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pickers.isEmpty ? "Pickers · Pure PPH" : "Pickers · Pure PPH  ·  \(pickers.count)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.text)
            if pickers.isEmpty {
                Text("Upload Picker ScoreCard so shoppers for this store can expand here with their Pure PPH.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, 6)
            } else {
                HStack(spacing: 6) {
                    Text("PICKER")
                        .frame(minWidth: 132, maxWidth: 190, alignment: .leading)
                    Text("PURE PPH")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("ORDERS")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("HOURS")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("STATUS")
                        .frame(width: 88, alignment: .trailing)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .tracking(0.4)
                ForEach(pickers) { picker in
                    pickerLine(picker)
                }
            }
        }
    }

    private func pickerLine(_ picker: MetricRow) -> some View {
        let health = HeartbeatMath.pphHealth(picker)
        return HStack(spacing: 6) {
            Text(picker.shopperName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: 132, maxWidth: 190, alignment: .leading)
            cell(HeartbeatFormat.num(picker.number("pph"), digits: 1), health)
            cell(HeartbeatFormat.num(picker.number("orders")), .none)
            cell(HeartbeatFormat.num(picker.number("pick_hours"), digits: 1), .none)
            Text(health.label.uppercased())
                .font(.caption.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .foregroundStyle(Color.white)
                .background(pill(health), in: Capsule())
                .frame(width: 88, alignment: .trailing)
        }
    }

    private func metric(_ name: String, _ value: String, _ health: Health, brand: Bool) -> some View {
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
            if !brand, health != .none {
                HealthBadge(health: health)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(brand ? AppTheme.blueSoft : wash(health))
        )
    }

    private func cell(_ value: String, _ health: Health) -> some View {
        Text(value)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(ink(health))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
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
        case .none: return AppTheme.card
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

struct PickerScoreTable: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var headerPin: LaborHeaderPin
    var focus: PickerFocus = .all

    private enum Column: String, CaseIterable, Identifiable {
        case shopper, pph, presub, oos, ott, oth5, refund, status
        var id: String { rawValue }
        var key: String {
            switch self {
            case .shopper: return "label"
            case .pph: return "pph"
            case .presub: return "presub"
            case .oos: return "oos"
            case .ott: return "ott"
            case .oth5: return "oth5"
            case .refund: return "refund"
            case .status: return "status"
            }
        }
        var sort: PickerSort {
            switch self {
            case .shopper: return .name
            case .pph: return .pph
            case .presub: return .presub
            case .oos: return .oos
            case .ott: return .ott
            case .oth5: return .oth5
            case .refund: return .refund
            case .status: return .status
            }
        }
    }

    @State private var sort = Column.pph
    @State private var ascending = true
    @State private var limit = 150
    @State private var snaps: [PickerLineSnap] = []
    @State private var openShopper: String?

    private var expanded: Bool { headerPin.storesExpanded }
    private var total: Int { store.pickerCount(for: focus) }

    var body: some View {
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
                Button {
                    let next = !headerPin.storesExpanded
                    headerPin.storesExpanded = next
                    headerPin.tableOpen = next
                    if !next { headerPin.pinned = false }
                    if next { rebuildPage() }
                } label: {
                    HubTableHeader(
                            icon: "person.2.fill",
                            title: "Shopper",
                            accessory: pageCaption + "  ·  tap to \(expanded ? "collapse" : "expand")",
                            expanded: expanded
                        )
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 2.5)
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: expanded ? 4 : 20, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
                .onAppear {
                    headerPin.tableOpen = headerPin.storesExpanded
                    headerPin.storeCount = total
                    headerPin.active = sort.key
                    headerPin.ascending = ascending
                    headerPin.onSelect = applyHeaderSort
                    rebuildPage()
                }
                .onChange(of: focus) { _, _ in
                    limit = 150
                    openShopper = nil
                    rebuildPage()
                }
                .onChange(of: store.filterStamp) { _, _ in
                    limit = 150
                    rebuildPage()
                }
                .onChange(of: total) { _, _ in
                    rebuildPage()
                }
            }
            if expanded {
                Section {
                    PickerMetricHeader(
                        label: "Shopper",
                        active: sort.key,
                        ascending: ascending,
                        showRefund: true,
                        onSelect: applyHeaderSort
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: LaborHeaderMinYKey.self,
                                value: (geo.frame(in: .global).minY / 12).rounded() * 12
                            )
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 2, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
                    ForEach(snaps) { snap in
                        PickerStoreRow(
                            snap: snap,
                            expanded: openShopper == snap.id.uuidString,
                            onToggle: {
                                openShopper = openShopper == snap.id.uuidString ? nil : snap.id.uuidString
                            },
                            showRefund: true
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                    }
                    if snaps.count < total {
                        Button {
                            limit += 150
                            rebuildPage()
                        } label: {
                            Text("Show more · \(snaps.count) of \(HeartbeatFormat.num(Double(total)))")
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
                .transaction { $0.animation = nil }
            }
        }
    }

    private var pageCaption: String {
        if snaps.count < total {
            return "Showing \(snaps.count) of \(HeartbeatFormat.num(Double(total))) · \(focus.title)"
        }
        return "\(HeartbeatFormat.num(Double(total))) shoppers · \(focus.title)"
    }

    private func applyHeaderSort(_ key: String) {
        let column = Column.allCases.first { $0.key == key } ?? .pph
        let nextAscending = sort == column ? !ascending : column.sort.defaultAscending
        sort = column
        ascending = nextAscending
        headerPin.active = column.key
        headerPin.ascending = nextAscending
        rebuildPage()
    }

    private func rebuildPage() {
        headerPin.storeCount = total
        snaps = store.pickerPage(focus: focus, sort: sort.sort, ascending: ascending, limit: limit).map {
            PickerLineSnap($0, division: place(for: $0))
        }
    }

    private func place(for row: MetricRow) -> String {
        let division = row.division.isEmpty ? store.identity(forStore: row.storeNumber).division : row.division
        return division
    }
}

struct PickerLineSnap: Identifiable, Equatable {
    let id: UUID
    let shopperKey: String
    let storeNumber: String
    let label: String
    let division: String
    let pph: String
    let presub: String
    let oos: String
    let ott: String
    let oth5: String
    let hours: String
    let subs: String
    let orders: String
    let dug: String
    let refund: String
    let othElig: String
    let coe: String
    let health: Health
    let pphHealth: Health
    let presubHealth: Health
    let oosHealth: Health
    let ottHealth: Health
    let oth5Health: Health
    let refundHealth: Health
    let othEligHealth: Health
    let coeHealth: Health

    init(_ row: MetricRow, division: String) {
        id = row.id
        shopperKey = row.shopperKey
        storeNumber = row.storeNumber
        let store = row.storeNumber.isEmpty ? "" : "Store \(row.storeNumber)"
        label = store.isEmpty ? row.shopperName : "\(row.shopperName)  |  \(store)"
        self.division = division
        pph = HeartbeatFormat.num(row.number("pph"), digits: 1)
        presub = HeartbeatFormat.pct(row.number("presub_pct"))
        oos = HeartbeatFormat.pct(row.number("oos_pct"))
        ott = HeartbeatFormat.pct(row.number("ott_pct"))
        oth5 = HeartbeatFormat.pct(row.number("oth5_pct"))
        hours = HeartbeatFormat.num(row.number("pick_hours"), digits: 1)
        subs = HeartbeatFormat.num(row.number("subs"))
        orders = HeartbeatFormat.num(row.number("orders"))
        dug = HeartbeatFormat.num(row.number("dug_orders"))
        refund = HeartbeatFormat.money(row.number("refund_amt"))
        othElig = HeartbeatFormat.pct(row.number("oth_elig_pct"))
        coe = HeartbeatFormat.pct(row.number("coe_pct"))
        health = HeartbeatMath.pickerHealth(row)
        pphHealth = row.number("pph") == nil ? .none : HeartbeatMath.pphHealth(row)
        presubHealth = row.number("presub_pct") == nil ? .none : HeartbeatMath.presubStar(row).health
        oosHealth = row.number("oos_pct") == nil ? .none : HeartbeatMath.oosStar(row).health
        ottHealth = row.number("ott_pct") == nil ? .none : HeartbeatMath.ottStar(row).health
        oth5Health = row.number("oth5_pct") == nil ? .none : HeartbeatMath.othStar(row).health
        refundHealth = HeartbeatMath.refundHealth(row)
        othEligHealth = row.number("oth_elig_pct") == nil ? .none : HeartbeatMath.othEligStar(row).health
        coeHealth = row.number("coe_pct") == nil ? .none : HeartbeatMath.coeStar(row).health
    }
}

private struct PickerCheapLine: View, Equatable {
    let snap: PickerLineSnap
    let expanded: Bool
    var showRefund: Bool = false

    var body: some View {
        HStack(spacing: 6) {
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
            .frame(minWidth: 148, maxWidth: 220, alignment: .leading)
            cell(snap.pph, snap.pphHealth)
            cell(snap.presub, snap.presubHealth)
            cell(snap.oos, snap.oosHealth)
            cell(snap.ott, snap.ottHealth)
            cell(snap.oth5, snap.oth5Health)
            if showRefund {
                cell(snap.refund, snap.refundHealth)
            }
            Text(snap.health.label.uppercased())
                .font(.caption.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .foregroundStyle(Color.white)
                .background(pill(snap.health), in: Capsule())
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private func cell(_ value: String, _ health: Health) -> some View {
        Text(value)
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(ink(health))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
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

struct PickerMetricHeader: View {
    let label: String
    var active: String? = nil
    var ascending: Bool = false
    var showRefund: Bool = false
    var onSelect: ((String) -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            head(label, key: "label", alignment: .leading)
                .frame(minWidth: 148, maxWidth: 220, alignment: .leading)
            head("PPH", key: "pph")
            head("Presub", key: "presub")
            head("OOS", key: "oos")
            head("OTT", key: "ott")
            head("OTH5", key: "oth5")
            if showRefund {
                head("Refund", key: "refund")
            }
            head("Status", key: "status", alignment: .trailing)
                .frame(width: 88, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .tracking(0.4)
        .lineLimit(1)
        .minimumScaleFactor(0.65)
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
        .foregroundStyle(selected ? AppTheme.blue : AppTheme.textTertiary)
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

struct PickerStickyStoreHeader: View {
    @EnvironmentObject private var pin: LaborHeaderPin

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Shopper")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
                Text("\(HeartbeatFormat.num(Double(pin.storeCount))) shoppers")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
            }
            PickerMetricHeader(
                label: "Shopper",
                active: pin.active,
                ascending: pin.ascending,
                showRefund: true,
                onSelect: { pin.onSelect?($0) }
            )
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

struct PickerStoreRow: View {
    let snap: PickerLineSnap
    let expanded: Bool
    let onToggle: () -> Void
    var showRefund: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 10 : 0) {
            Button(action: onToggle) {
                PickerCheapLine(snap: snap, expanded: expanded, showRefund: showRefund)
                    .equatable()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                PickerStoreExpand(snap: snap)
            }
        }
    }
}

struct PickerStoreExpand: View {
    let snap: PickerLineSnap

    private var chips: [(String, String, Health, Bool)] {
        [
            ("PPH", snap.pph, snap.pphHealth, false),
            ("Presub", snap.presub, snap.presubHealth, false),
            ("OOS", snap.oos, snap.oosHealth, false),
            ("OTT", snap.ott, snap.ottHealth, false),
            ("OTH5", snap.oth5, snap.oth5Health, false),
            ("OTH Elig", snap.othElig, snap.othEligHealth, false),
            ("Hours", snap.hours, .none, false),
            ("Subs", snap.subs, .none, false),
            ("Orders", snap.orders, .none, false),
            ("DUG", snap.dug, .none, false),
            ("COE", snap.coe, snap.coeHealth, false),
            ("Refund", snap.refund, snap.refundHealth, false),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(metaLine)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            chipGrid
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.card.opacity(0.9))
        )
    }

    private var metaLine: String {
        let store = snap.storeNumber.isEmpty ? "—" : snap.storeNumber
        let division = snap.division.isEmpty ? "—" : snap.division
        return "Store \(store)  ·  \(division)"
    }

    private var chipGrid: some View {
        let rows = stride(from: 0, to: chips.count, by: 6).map { Array(chips[$0..<min($0 + 6, chips.count)]) }
        return VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, item in
                        metric(item.0, item.1, item.2, brand: item.3)
                    }
                }
            }
        }
    }

    private func metric(_ name: String, _ value: String, _ health: Health, brand: Bool) -> some View {
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
            if !brand, health != .none {
                HealthBadge(health: health)
            }
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

struct HubChromeModifier: ViewModifier {
    @EnvironmentObject private var router: HubRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    var showBack: Bool
    var showsFilters: Bool

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.bg.ignoresSafeArea())
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
}

extension View {
    func hubChrome(showBack: Bool = false, showsFilters: Bool = false) -> some View {
        modifier(HubChromeModifier(showBack: showBack, showsFilters: showsFilters))
    }

    func hubPageCanvas() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppTheme.bg.ignoresSafeArea())
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
        VStack(spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 12) {
                visibilityStrip
                if expanded {
                    VStack(spacing: 8) {
                        ForEach(MetricSection.checklistSections) { section in
                            sectionBlock(section)
                        }
                    }
                    sendBar
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill)
            .overlay {
                if pulseHealth == .risk || pulseHealth == .watch {
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .stroke(stroke, lineWidth: 3)
                        .opacity(pulseOn ? 1 : 0.18)
                        .padding(3)
                        .allowsHitTesting(false)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 2.5)
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
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "checklist")
                    .font(.title3.weight(.semibold))
                Text("Operational Heartbeat Checklist")
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("ACTION ITEMS")
                    .font(.caption.weight(.heavy))
                    .tracking(0.4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(Color.white)
                    .background(AppTheme.bad, in: Capsule(style: .continuous))
                Text("\(store.checklistOpenCount) OPEN")
                    .font(.caption.weight(.heavy))
                    .tracking(0.4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(Color.white)
                    .background(
                        store.checklistOpenCount > 0 ? AppTheme.bad : AppTheme.ok,
                        in: Capsule(style: .continuous)
                    )
                Spacer(minLength: 8)
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.blue)
            .contentShape(Rectangle())
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
