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
        }
    }

    private var background: Color {
        switch health {
        case .good: return AppTheme.okSoft
        case .watch: return AppTheme.warnSoft
        case .risk: return AppTheme.badSoft
        }
    }
}

struct KpiTile: View {
    let label: String
    let value: String
    var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppTheme.text)
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .fill(AppTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
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
        filterMenu("Division", selection: store.filters.division, options: store.divisions.map { ($0, HeartbeatFormat.divisionLabel($0)) }) {
            store.setDivision($0)
        }
        filterMenu("District", selection: store.filters.district, options: store.districts.map { ($0, $0) }) {
            store.setDistrict($0)
        }
        filterMenu("Operations OM", selection: store.filters.om, options: store.operationsOMs.map { ($0, $0) }) {
            store.setOM($0)
        }
        filterMenu(
            "Store number",
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

    var body: some View {
        if rows.isEmpty {
            HubCard {
                EmptyHint(
                    symbol: "building.2",
                    title: "No stores in this view",
                    detail: "Adjust filters or upload a file for this section."
                )
            }
        } else {
            HubCard {
                VStack(spacing: 0) {
                    HStack {
                        header(section == .pickerScorecard ? "Shopper" : "Store")
                        header("Division")
                        header("OM")
                        header("Result")
                        header("Status")
                    }
                    .padding(.bottom, 10)
                    Divider().opacity(0.5)
                    ForEach(rows) { row in
                        let view = StoreCellViewModel.make(section: section, row: row)
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                if section == .pickerScorecard {
                                    Text(row.shopperName)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(row.storeNumber.isEmpty ? "—" : row.storeNumber) · \(row.storeName ?? "Store")")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                } else {
                                    Text(row.storeNumber.isEmpty ? "—" : row.storeNumber)
                                        .font(.subheadline.weight(.semibold).monospacedDigit())
                                    Text(row.storeName ?? "Unnamed store")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text(row.division.isEmpty ? "—" : row.division)
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
                        Divider().opacity(0.35)
                    }
                }
            }
        }
    }

    private func header(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(AppTheme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
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
