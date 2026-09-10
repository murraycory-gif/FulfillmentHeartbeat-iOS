import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var pushedSection: MetricSection?
    @State private var showError = false

    var body: some View {
        dashboardBody
            .opacity(store.needsRolePick ? 0 : 1)
            .allowsHitTesting(!store.needsRolePick)
    }

    private var dashboardBody: some View {
        VStack(spacing: 0) {
            if !HubLayout.isPhone(sizeClass) {
                HubStickyPageBanner(
                    icon: "waveform.path.ecg",
                    title: "Operational Heartbeat",
                    accessory: store.filters.summary,
                    trailing: store.sharedDataWindow()
                )
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    if briefingCards.isEmpty, store.seeded {
                        HStack {
                            Spacer()
                            VStack(spacing: 10) {
                                ProgressView()
                                    .tint(AppTheme.blue)
                                Text("Setting the aisle…")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .padding(.top, 40)
                            Spacer()
                        }
                    }
                    ForEach(briefingCards) { card in
                        DashCallout(
                            card: card,
                            flags: store.dashboardFlags(for: card.section),
                            grains: store.dashboardGrains(for: card.section),
                            grain: store.effectiveDashboardGrain
                        ) {
                            open(card.section)
                        }
                        .equatable()
                        .padding(.horizontal, HubLayout.isPhone(sizeClass) ? 12 : 20)
                        .padding(.vertical, HubLayout.isPhone(sizeClass) ? 5 : 6)
                    }
                    if !store.seeded {
                        HubCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Waiting for the pack")
                                    .font(.headline)
                                Text("Dashboard fills from the Heartbeat pack on this device. Stay here — shopper cards land after ready.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .transaction { $0.animation = nil }
            .navigationDestination(item: $pushedSection) { section in
                SectionDetailView(section: section)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .alert("Couldn’t load", isPresented: $showError) {
            Button("OK", role: .cancel) {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onChange(of: store.errorMessage) { _, message in
            showError = message != nil
        }
        .onChange(of: router.destination) { _, dest in
            if dest == .dashboard {
                pushedSection = nil
            }
        }
        .onChange(of: showError) { _, presented in
            if !presented { store.errorMessage = nil }
        }
    }

    private var briefingCards: [SectionSummary] {
        HeartbeatMath.dashboardCallouts(
            store.summaries,
            role: store.sessionRole,
            storeScoped: !store.filters.store.isEmpty
        )
    }

    private func open(_ section: MetricSection) {
        if HubLayout.isPhone(sizeClass) {
            pushedSection = section
        } else {
            router.open(section: section)
        }
    }
}

private func dashInk(_ health: Health) -> Color { AppTheme.healthInk(health) }

private func dashWash(_ health: Health) -> Color { AppTheme.healthWash(health) }

private func statusFlags(_ flags: [HeartbeatMath.FiveStarFlag]) -> [HeartbeatMath.FiveStarFlag] {
    let named = Dictionary(uniqueKeysWithValues: flags.map { ($0.name.lowercased(), $0) })
    func pick(_ name: String, health: Health) -> HeartbeatMath.FiveStarFlag {
        named[name.lowercased()] ?? HeartbeatMath.FiveStarFlag(name: name, value: "", health: health, stores: 0)
    }
    if named["healthy"] != nil || named["watch"] != nil || named["at risk"] != nil {
        return [pick("Healthy", health: .good), pick("Watch", health: .watch), pick("At Risk", health: .risk)]
    }
    return flags
}

private func phoneMoney(_ value: Double?) -> String? {
    guard let value else { return nil }
    let sign = value < 0 ? "-" : ""
    let amount = abs(value)
    if amount >= 1_000_000_000 {
        return "\(sign)$\(String(format: "%.1f", amount / 1_000_000_000))B"
    }
    if amount >= 1_000_000 {
        return "\(sign)$\(String(format: "%.1f", amount / 1_000_000))M"
    }
    if amount >= 10_000 {
        return "\(sign)$\(String(format: "%.0f", amount / 1_000))K"
    }
    return nil
}

struct PhonePulseCard: View {
    let card: SectionSummary
    let flags: [HeartbeatMath.FiveStarFlag]
    let grains: [DashScopePack]
    let grain: DashScopeGrain?
    var extraPct: Double? = nil
    var tappable: Bool = true
    let action: () -> Void

    private var titleText: String {
        if card.section == .lostRevenue { return "Loss Revenue" }
        if card.section == .pickPath { return "Pick Path" }
        return card.section.title
    }

    private var valueText: String {
        phoneMoney(card.headline) ?? card.headlineText
    }

    private var riskText: String {
        let n = HeartbeatFormat.num(Double(card.riskCount))
        let unit = card.section == .pickerScorecard ? "pickers" : "stores"
        if card.riskCount == 0 { return "No \(unit) at risk" }
        return "\(n) \(unit) at risk"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if tappable {
                Button(action: action) {
                    header
                }
                .buttonStyle(DashLiftStyle())
            } else {
                header
            }
            PhoneFlagStrip(flags: statusFlags(flags))
            if let grain {
                DashScopeStrip(section: card.section, grain: grain, packs: grains, width: 390)
            }
        }
        .modifier(DashCardChrome(health: card.health))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            DashCardGlyph(symbol: card.section.symbol, health: card.health, compact: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(AppTheme.rounded(.subheadline, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                Text(riskText)
                    .font(AppTheme.rounded(.caption, weight: .semibold))
                    .foregroundStyle(dashInk(card.riskCount == 0 ? .good : .risk))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                Text(valueText)
                    .font(AppTheme.rounded(.title3, weight: .bold).monospacedDigit())
                    .foregroundStyle(dashInk(card.health))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                if let extraPct {
                    Text(HeartbeatFormat.pct(extraPct))
                        .font(AppTheme.rounded(.caption, weight: .bold).monospacedDigit())
                        .foregroundStyle(dashInk(card.health))
                        .lineLimit(1)
                }
                HealthBadge(health: card.health, prominent: true, compact: true)
            }
            if tappable {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
    }
}

struct PhoneFlagStrip: View {
    let flags: [HeartbeatMath.FiveStarFlag]

    private var shown: [HeartbeatMath.FiveStarFlag] {
        flags
    }

    var body: some View {
        if shown.isEmpty {
            EmptyView()
        } else {
            let columns = shown.count > 3 ? [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)] : Array(repeating: GridItem(.flexible(), spacing: 6), count: shown.count)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(shown) { flag in
                    let tone = flag.health == .none ? Health.good : flag.health
                    VStack(spacing: 2) {
                        Text(phoneFlagValue(flag))
                            .font(AppTheme.rounded(.title3, weight: .bold).monospacedDigit())
                            .foregroundStyle(dashInk(tone))
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .fixedSize(horizontal: true, vertical: false)
                        Text(phoneFlagName(flag.name))
                            .font(AppTheme.rounded(.caption, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 6)
                    .background(AppTheme.healthWash(tone), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(dashInk(tone).opacity(0.22), lineWidth: 1)
                    )
                }
            }
        }
    }

    private func phoneFlagValue(_ flag: HeartbeatMath.FiveStarFlag) -> String {
        if !flag.value.isEmpty { return flag.value }
        if flag.stores > 0 { return HeartbeatFormat.num(Double(flag.stores)) }
        return "—"
    }

    private func phoneFlagName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("total lost") { return "Lost Revenue" }
        if lower.contains("post sub") { return "Post Sub" }
        if lower.contains("refund") { return "Refunds" }
        if lower.contains("reduced") { return "Capacity" }
        if lower.contains("missed sales") { return "Missed Sales" }
        if lower.contains("cancel") { return "Cancels" }
        if lower.contains("kill") { return "Kill Switch" }
        if lower.contains("pre sub") { return "Pre Sub" }
        if name.count <= 14 { return name }
        return name.split(separator: "(").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? name
    }
}

struct DashLostBanner: View {
    let summary: SectionSummary
    let flags: [HeartbeatMath.FiveStarFlag]
    var grains: [DashScopePack] = []
    var grain: DashScopeGrain? = nil
    var width: CGFloat = 980
    let action: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var flagsOpen = false

    private var compact: Bool { HubLayout.isPhone(sizeClass) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: action) {
                if compact {
                    compactHeader
                } else {
                    wideHeader
                }
            }
            .buttonStyle(DashLiftStyle())
            if !compact {
                DashFlagGrid(
                    flags: statusFlags(flags),
                    width: width
                )
            }
            if let grain {
                DashScopeStrip(section: summary.section, grain: grain, packs: grains, width: width)
            }
        }
        .modifier(DashCardChrome(health: summary.health))
    }

    private var wideHeader: some View {
        HStack(spacing: 16) {
            DashCardGlyph(symbol: summary.section.symbol, health: summary.health)
            VStack(alignment: .leading, spacing: 4) {
                Text("Loss Revenue ScoreCard")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Text("Total Lost Revenue (Total Opportunity)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Text(riskLine)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(dashInk(summary.riskCount == 0 ? .good : summary.health))
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(summary.headlineText)
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(dashInk(summary.health))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("Dollars")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text(HeartbeatFormat.pct(summary.lostRevenuePct))
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(dashInk(summary.health))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("Lost %")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            HealthBadge(health: summary.health, prominent: true)
            Image(systemName: "chevron.right")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                DashCardGlyph(symbol: summary.section.symbol, health: summary.health, compact: true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Loss Revenue ScoreCard")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Total Lost Revenue (Total Opportunity)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.top, 6)
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.headlineText)
                        .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(dashInk(summary.health))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("Dollars")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(HeartbeatFormat.pct(summary.lostRevenuePct))
                        .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(dashInk(summary.health))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("Lost %")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer(minLength: 4)
                HealthBadge(health: summary.health, prominent: true)
            }
            Text(riskLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(dashInk(summary.riskCount == 0 ? .good : summary.health))
        }
    }

    private var riskLine: String {
        let risk = HeartbeatFormat.num(Double(summary.riskCount))
        if summary.riskCount == 0 { return "0 stores at risk" }
        return "\(risk) stores at risk"
    }
}

struct DashScopeStrip: View {
    @EnvironmentObject private var store: HeartbeatStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    let section: MetricSection
    let grain: DashScopeGrain
    let packs: [DashScopePack]
    var width: CGFloat
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 10 : 8) {
            Button {
                var txn = Transaction()
                txn.animation = nil
                withTransaction(txn) { expanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: grain.symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.white)
                    Text(grain.title)
                        .font(AppTheme.rounded(HubLayout.isPhone(sizeClass) ? .caption : .subheadline, weight: .bold))
                        .foregroundStyle(Color.white)
                    Text("\(bannerCount)")
                        .font(AppTheme.rounded(.caption, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Spacer(minLength: 8)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, HubLayout.isPhone(sizeClass) ? 10 : 14)
                .padding(.vertical, HubLayout.isPhone(sizeClass) ? 8 : 10)
                .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                expandedTables
            }
        }
        .transaction { $0.animation = nil }
    }

    private var bannerCount: Int {
        let scoped = store.dashboardScopeCount(grain)
        if scoped > 0 { return scoped }
        if section == .sales { return store.cachedSalesScopeRows.count }
        let live = packs.filter {
            $0.line.count > 0 || (!$0.line.value.isEmpty && $0.line.value != "—")
        }
        return live.isEmpty ? packs.count : live.count
    }

    @ViewBuilder
    private var expandedTables: some View {
        VStack(alignment: .leading, spacing: 10) {
            if section == .sales {
                OverviewSalesAlignedTable(
                    title: grain.title,
                    rows: Array(store.cachedSalesScopeRows.prefix(20)),
                    showCount: grain != .store
                )
                if !store.cachedSalesDayRows.isEmpty {
                    OverviewSalesAlignedTable(title: "By Day", rows: store.cachedSalesDayRows, showCount: false)
                        .padding(.top, 8)
                }
            } else {
                OverviewMetricAlignedTable(
                    title: grain.title,
                    headers: HeartbeatMath.dashboardTableHeaders(section),
                    rows: Array(store.dashboardGrainRows(for: section).prefix(40)),
                    showCount: grain != .store
                )
            }
        }
    }
}

struct OverviewMetricAlignedTable: View {
    let title: String
    let headers: [String]
    let rows: [HeartbeatMath.DashboardGrainTableRow]
    var showCount: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.hubTableWidth) private var tableWidth

    private var phone: Bool { HubLayout.isPhone(sizeClass) }
    private var valueWidth: CGFloat {
        HubLayout.evenValueWidth(
            available: tableWidth,
            phone: phone,
            columns: headers.count,
            showCount: showCount
        )
    }

    var body: some View {
        HubAdaptiveHScroll(minWidth: HubLayout.readableTableFloor(phone: phone, columns: headers.count, showCount: showCount)) {
            VStack(alignment: .leading, spacing: 0) {
                row(
                    label: "Scope",
                    stores: "Stores",
                    values: headers,
                    health: nil,
                    header: true
                )
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                    row(
                        label: item.label,
                        stores: HeartbeatFormat.num(Double(item.storeCount)),
                        values: item.values,
                        health: item.health == .none && item.storeCount > 0 ? .good : item.health,
                        header: false,
                        stripe: index.isMultiple(of: 2)
                    )
                }
            }
        }
        .accessibilityLabel("\(title) table")
    }

    private func row(
        label: String,
        stores: String,
        values: [String],
        health: Health?,
        header: Bool,
        stripe: Bool = false
    ) -> some View {
        HStack(spacing: 6) {
            Text(header ? label.uppercased() : label)
                .font(AppTheme.rounded(header ? .caption2 : .subheadline, weight: header ? .bold : .semibold))
                .foregroundStyle(header ? AppTheme.textSecondary : AppTheme.text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: HubLayout.readableLabelWidth(phone: phone, available: tableWidth), alignment: .leading)
            if showCount {
                cell(stores, header: header, secondary: true)
            }
            ForEach(Array(values.enumerated()), id: \.offset) { _, text in
                cell(text, header: header, tone: header ? nil : health)
            }
            Group {
                if header {
                    Text("STATUS")
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

struct PhoneGrainRow: View {
    let label: String
    let value: String
    let count: Int?
    let health: Health

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(AppTheme.rounded(.subheadline, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let count, count > 0 {
                    Text(count == 1 ? "1 store" : "\(count) stores")
                        .font(AppTheme.rounded(.caption2, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(AppTheme.rounded(.subheadline, weight: .bold).monospacedDigit())
                .foregroundStyle(dashInk(health))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HealthBadge(health: health, prominent: true, compact: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

struct DashScopeGrainCard: View {
    @EnvironmentObject private var store: HeartbeatStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    let pack: DashScopePack
    let grain: DashScopeGrain
    let flags: [HeartbeatMath.FiveStarFlag]
    let width: CGFloat
    let section: MetricSection
    @State private var open = false
    @State private var children: [DashScopeLine] = []
    @State private var childFlags: [String: [HeartbeatMath.FiveStarFlag]] = [:]

    private var line: DashScopeLine { pack.line }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: toggleOpen) {
                header
            }
            .buttonStyle(.plain)
            if !flags.isEmpty {
                DashFlagGrid(
                    flags: flags,
                    width: max(width - 24, 200)
                )
            }
            if open {
                ForEach(children) { child in
                    childBlock(child)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
    }

    private var header: some View {
        Group {
            if HubLayout.isPhone(sizeClass) {
                phoneHeader
            } else {
                wideHeader
            }
        }
    }

    private var phoneHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(line.label)
                    .font(AppTheme.rounded(.subheadline, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer()
                HealthBadge(health: displayHealth, prominent: true, compact: true)
            }
            Text(line.value)
                .font(AppTheme.rounded(.title3, weight: .bold).monospacedDigit())
                .foregroundStyle(dashInk(displayHealth))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if grain != .store {
                Text(storeCountLine(line.count, title: true))
                    .font(AppTheme.rounded(.caption, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var wideHeader: some View {
        HStack(spacing: 10) {
            Text(line.label)
                .font(AppTheme.rounded(.subheadline, weight: .bold))
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 168, alignment: .leading)
            if grain != .store {
                Text(storeCountLine(line.count, title: true))
                    .font(AppTheme.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 88, alignment: .trailing)
            }
            Text(line.value)
                .font(AppTheme.rounded(.subheadline, weight: .bold).monospacedDigit())
                .foregroundStyle(dashInk(displayHealth))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .trailing)
            HealthBadge(health: displayHealth, prominent: true, compact: true)
                .frame(width: 84, alignment: .trailing)
            if grain != .store {
                Image(systemName: open ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
            }
        }
    }

    private func childBlock(_ child: DashScopeLine) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(child.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(child.value)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(dashInk(child.health == .none ? .good : child.health))
                if grain != .store {
                    Text(storeCountLine(child.count, title: false))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                HealthBadge(health: child.health, prominent: true, compact: true)
            }
            if section != .sales, let metrics = childFlags[child.label], !metrics.isEmpty {
                DashFlagGrid(
                    flags: metrics,
                    width: max(width - 36, 200)
                )
            }
        }
        .padding(.leading, 12)
    }

    private var displayHealth: Health {
        line.health == .none ? .good : line.health
    }

    private func storeCountLine(_ count: Int, title: Bool) -> String {
        if count == 1 { return title ? "1 Store" : "1 store" }
        return title ? "\(count) Stores" : "\(count) stores"
    }

    private func toggleOpen() {
        let next = !open
        open = next
        guard next, children.isEmpty, grain != .store else { return }
        if !pack.children.isEmpty {
            children = Array(pack.children.prefix(40))
        } else {
            children = Array(store.dashboardGrainChildren(section: section, label: pack.line.label).prefix(40))
        }
        guard section != .sales, section != .pickerScorecard else { return }
        let childGrain: DashScopeGrain
        switch grain {
        case .region: childGrain = .division
        case .division: childGrain = .district
        default: childGrain = .store
        }
        childFlags = store.metricFlags(for: section, grain: childGrain, labels: children.map(\.label))
    }
}

struct DashFlagGrid: View {
    let flags: [HeartbeatMath.FiveStarFlag]
    var columns: Int = 0
    var width: CGFloat = 980
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if flags.isEmpty {
            EmptyView()
        } else {
            let cols = HubLayout.calloutColumns(count: flags.count, width: width, sizeClass: sizeClass)
            let phone = HubLayout.isPhone(sizeClass)
            LazyVGrid(
                columns: HubLayout.grid(cols, spacing: HubLayout.calloutGridSpacing, minWidth: HubLayout.calloutMinWidth(phone: phone)),
                spacing: HubLayout.calloutGridSpacing
            ) {
                ForEach(flags) { flag in
                    DashFlagChip(flag: flag)
                }
            }
        }
    }
}

private struct DashFlagChip: View {
    let flag: HeartbeatMath.FiveStarFlag
    var stacked: Bool = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var compact: Bool { HubLayout.isPhone(sizeClass) }
    private var tone: Health { flag.health == .none ? .good : flag.health }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 6) {
                Text(flag.name)
                    .font(AppTheme.rounded(compact ? .subheadline : .headline, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if tone != .none {
                    HealthBadge(health: tone, prominent: true, compact: true)
                }
            }
            Text(flag.value.isEmpty ? countLine : flag.value)
                .font(.system(size: HubLayout.calloutValueSize(phone: compact), weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(dashInk(tone))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .fixedSize(horizontal: true, vertical: false)
            Text(flag.value.isEmpty ? (tone.label) : countLine)
                .font(AppTheme.rounded(.caption, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(compact ? 10 : 11)
        .padding(.leading, 4)
        .frame(maxWidth: .infinity, minHeight: HubLayout.calloutMinHeight(phone: compact), alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.healthWash(tone).opacity(0.42))
                }
        }
        .overlay(alignment: .leading) {
            Capsule()
                .fill(AppTheme.healthInk(tone))
                .frame(width: 4)
                .padding(.vertical, 10)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.healthInk(tone).opacity(tone == .risk ? 0.9 : 0.22), lineWidth: tone == .risk ? 2 : 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 3, y: 1)
    }

    private var countLine: String {
        let unit = flag.unit.isEmpty ? "stores" : flag.unit
        let label = flag.stores == 1 && unit.hasSuffix("s") ? String(unit.dropLast()) : unit
        return "\(HeartbeatFormat.num(Double(flag.stores))) \(label)"
    }
}

struct DashCallout: View, Equatable {
    let card: SectionSummary
    let flags: [HeartbeatMath.FiveStarFlag]
    let grains: [DashScopePack]
    let grain: DashScopeGrain?
    let action: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var width: CGFloat = 980
    @State private var flagsOpen = false

    private var compact: Bool { HubLayout.isPhone(sizeClass) }

    static func == (lhs: DashCallout, rhs: DashCallout) -> Bool {
        lhs.card == rhs.card && lhs.flags == rhs.flags && lhs.grains == rhs.grains && lhs.grain == rhs.grain
    }

    var body: some View {
        Group {
            if compact {
                PhonePulseCard(
                    card: card,
                    flags: flags,
                    grains: grains,
                    grain: grain,
                    extraPct: card.section == .lostRevenue ? card.lostRevenuePct : nil,
                    action: action
                )
            } else if card.section == .lostRevenue {
                DashLostBanner(summary: card, flags: flags, grains: grains, grain: grain, width: width, action: action)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: action) {
                        wideHeader
                    }
                    .buttonStyle(DashLiftStyle())
                    DashFlagGrid(
                        flags: statusFlags(flags),
                        width: width
                    )
                    if let grain {
                        DashScopeStrip(section: card.section, grain: grain, packs: grains, width: width)
                    }
                }
                .modifier(DashCardChrome(health: card.health))
            }
        }
        .readWidth($width)
    }

    private var titleText: String {
        card.section == .pickPath ? "Pick Path Compliance" : card.section.title
    }

    private var wideHeader: some View {
        HStack(spacing: 16) {
            DashCardGlyph(symbol: card.section.symbol, health: card.health)
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Text(card.headlineLabel)
                    .font(.title3)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(riskLine(for: card))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(dashInk(card.riskCount == 0 ? .good : .risk))
            }
            Spacer(minLength: 8)
            Text(card.headlineText)
                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(dashInk(card.health))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            HealthBadge(health: card.health, prominent: true)
            Image(systemName: "chevron.right")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                DashCardGlyph(symbol: card.section.symbol, health: card.health, compact: true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(titleText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(card.headlineLabel)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.top, 6)
            }
            HStack(alignment: .center, spacing: 10) {
                Text(card.headlineText)
                    .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(dashInk(card.health))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                Text(riskLine(for: card))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(dashInk(card.riskCount == 0 ? .good : .risk))
                    .multilineTextAlignment(.trailing)
                HealthBadge(health: card.health, prominent: true)
            }
        }
    }

    @ViewBuilder
    private func compactFlagBlock(_ flags: [HeartbeatMath.FiveStarFlag]) -> some View {
        if flags.isEmpty {
            EmptyView()
        } else {
            Button {
                flagsOpen.toggle()
            } label: {
                HStack(spacing: 8) {
                    Text("\(flags.count) metrics")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                    Text("tap to \(flagsOpen ? "collapse" : "expand")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer(minLength: 4)
                    Image(systemName: flagsOpen ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                }
            }
            .buttonStyle(.plain)
            if flagsOpen {
                DashFlagGrid(flags: flags, columns: 1)
            }
        }
    }

    @ViewBuilder
    private func flagBlock(_ flags: [HeartbeatMath.FiveStarFlag]) -> some View {
        if flags.isEmpty {
            EmptyView()
        } else {
            DashFlagGrid(flags: flags, columns: flags.count)
        }
    }

    private func riskLine(for card: SectionSummary) -> String {
        if card.section == .pickerScorecard {
            let n = HeartbeatFormat.num(Double(card.riskCount))
            return card.riskCount == 0 ? "0 pickers at risk" : "\(n) pickers at risk"
        }
        let risk = HeartbeatFormat.num(Double(card.riskCount))
        if card.riskCount == 0 { return "0 stores at risk" }
        return "\(risk) stores at risk"
    }
}

private struct DashCardGlyph: View {
    let symbol: String
    let health: Health
    var compact: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                .fill(AppTheme.blueSoft)
            RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                .stroke(AppTheme.blue.opacity(0.16), lineWidth: 1)
            Image(systemName: symbol)
                .font((compact ? Font.title3 : Font.title).weight(.semibold))
                .foregroundStyle(dashInk(health))
        }
        .frame(width: compact ? 36 : 56, height: compact ? 36 : 56)
        .shadow(color: dashInk(health).opacity(0.16), radius: 4, y: 2)
    }
}

private struct DashLiftStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct DashCardChrome: ViewModifier {
    let health: Health
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        let phone = HubLayout.isPhone(sizeClass)
        content
            .padding(phone ? 12 : 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: phone ? 12 : 16, style: .continuous)
                    .fill(Color.white)
            }
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(dashInk(health))
                    .frame(width: 4)
                    .padding(.vertical, phone ? 10 : 14)
            }
            .overlay {
                RoundedRectangle(cornerRadius: phone ? 12 : 16, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: phone ? 12 : 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1)
            .contentShape(RoundedRectangle(cornerRadius: phone ? 12 : 16, style: .continuous))
    }
}

struct PickerHighlightsPanel: View {
    @EnvironmentObject private var store: HeartbeatStore
    var onSelectOpportunity: () -> Void = {}
    var onSelectStrong: () -> Void = {}
    @State private var expanded = true
    @State private var openShopper: String?

    private var board: HeartbeatMath.PickerBoard {
        store.pickerBoard
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                expanded.toggle()
            } label: {
                HubTableHeader(
                    icon: "person.2.fill",
                    title: "Top Opportunity Pickers",
                    accessory: "Pickers Doing Well  ·  tap to \(expanded ? "collapse" : "expand")",
                    expanded: expanded
                )
            }
            .buttonStyle(.plain)

            if expanded {
                Group {
                    if board.shopperCount == 0 {
                        Text(store.pickerLoading ? "Loading shoppers…" : "Shoppers fill from the Heartbeat pack after ready.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            shopperColumn(
                                title: "Top opportunity",
                                subtitle: "Underperforming vs the metric mix",
                                rows: board.opportunity,
                                empty: "No opportunity shoppers in this filter.",
                                tone: .risk,
                                action: onSelectOpportunity
                            )
                            shopperColumn(
                                title: "Doing well",
                                subtitle: "Hitting the metric mix",
                                rows: board.strong,
                                empty: "No strong shoppers in this filter.",
                                tone: .good,
                                action: onSelectStrong
                            )
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.tableFill)
            }
        }
        .background(AppTheme.tableFill)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 2.5)
        )
    }

    private func shopperColumn(
        title: String,
        subtitle: String,
        rows: [MetricRow],
        empty: String,
        tone: Health,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(tone == .risk ? AppTheme.bad : AppTheme.ok)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if rows.isEmpty {
                Text(empty)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                PickerMetricHeader(label: "Shopper")
                ForEach(rows) { row in
                    PickerStoreRow(
                        snap: PickerLineSnap(row, division: divisionLabel(for: row)),
                        expanded: openShopper == row.id.uuidString,
                        onToggle: {
                            openShopper = openShopper == row.id.uuidString ? nil : row.id.uuidString
                        }
                    )
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .fill(tone == .risk ? AppTheme.badSoft.opacity(0.45) : AppTheme.okSoft.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .stroke(tone == .risk ? AppTheme.bad : AppTheme.ok, lineWidth: 1.5)
        )
    }

    private func divisionLabel(for row: MetricRow) -> String {
        if !row.division.isEmpty { return row.division }
        let division = store.identity(forStore: row.storeNumber).division
        return division.isEmpty ? "Store" : division
    }
}

#Preview {
    DashboardView()
        .environmentObject(HeartbeatStore())
        .environmentObject(HubRouter())
}
