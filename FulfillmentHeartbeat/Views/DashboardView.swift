import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var pushedSection: MetricSection?
    @State private var showError = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    HubPanel(
                        icon: "waveform.path.ecg",
                        title: "Operational Heartbeat"
                    ) {
                        VStack(spacing: 12) {
                            if let lost = store.summaries.first(where: { $0.section == .lostRevenue }) {
                                DashLostBanner(
                                    summary: lost,
                                    flags: HeartbeatMath.lostRevenueActionFlags(store.displayRows(for: .lostRevenue))
                                ) { open(.lostRevenue) }
                            }
                            DashBriefingList(cards: briefingCards) { section in
                                open(section)
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
            if !store.seeded {
                Section {
                    HubCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No files yet")
                                .font(.headline)
                            Text("Open Upload to drop in the section workbooks, including the picker score card — or load the sample market to see the pulse.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                            Button("Load sample market") {
                                store.loadSampleMarket()
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .padding(.top, 4)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg.ignoresSafeArea())
        .environment(\.defaultMinListRowHeight, 1)
        .navigationDestination(item: $pushedSection) { section in
            SectionDetailView(section: section)
        }
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
        .onChange(of: showError) { _, presented in
            if !presented { store.errorMessage = nil }
        }
    }

    private var briefingCards: [SectionSummary] {
        MetricSection.dashboardCards
            .filter { $0 != .lostRevenue }
            .compactMap { section in store.summaries.first(where: { $0.section == section }) }
    }

    private func open(_ section: MetricSection) {
        if sizeClass == .regular {
            router.open(section: section)
        } else {
            pushedSection = section
        }
    }
}

private func dashInk(_ health: Health) -> Color { AppTheme.healthInk(health) }

private func dashWash(_ health: Health) -> Color { AppTheme.healthWash(health) }

struct DashLostBanner: View {
    let summary: SectionSummary
    let flags: [HeartbeatMath.FiveStarFlag]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
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
                DashFlagGrid(flags: flags, columns: 3)
            }
            .modifier(DashCardChrome(health: summary.health))
        }
        .buttonStyle(DashLiftStyle())
    }

    private var riskLine: String {
        let risk = HeartbeatFormat.num(Double(summary.riskCount))
        if summary.riskCount == 0 { return "0 stores at risk" }
        return "\(risk) stores at risk"
    }
}

struct DashFlagGrid: View {
    let flags: [HeartbeatMath.FiveStarFlag]
    var columns: Int

    var body: some View {
        if !flags.isEmpty {
            LazyVGrid(
                columns: HubLayout.grid(columns, spacing: 8, minWidth: 168),
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(flags) { flag in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(flag.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        HStack(spacing: 6) {
                            if !flag.value.isEmpty {
                                Text(flag.value)
                                    .font(.title3.weight(.bold).monospacedDigit())
                                    .foregroundStyle(dashInk(flag.health == .none ? .good : flag.health))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            if flag.stores > 0 || flag.value.isEmpty {
                                Text(flag.stores == 1 ? "1 \(String(flag.unit.dropLast()))" : "\(HeartbeatFormat.num(Double(flag.stores))) \(flag.unit)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(flag.value.isEmpty ? dashInk(flag.health) : AppTheme.textSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            if flag.health != .none {
                                HealthBadge(health: flag.health, prominent: true, compact: true)
                            }
                        }
                        .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.72))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(dashWash(flag.health == .none ? .good : flag.health).opacity(0.55))
                            }
                    )
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(dashInk(flag.health == .none ? .good : flag.health))
                            .frame(width: 4)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
    }
}

struct DashBriefingList: View {
    @EnvironmentObject private var store: HeartbeatStore
    let cards: [SectionSummary]
    let action: (MetricSection) -> Void
    @State private var width: CGFloat = 980

    var body: some View {
        VStack(spacing: 12) {
            ForEach(cards) { card in
                Button {
                    action(card.section)
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            DashCardGlyph(symbol: card.section.symbol, health: card.health)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.section == .pickPath ? "Pick Path Compliance" : card.section.title)
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
                        if card.section == .fiveStar {
                            metricFlags(HeartbeatMath.fiveStarActionFlags(store.displayRows(for: .fiveStar)))
                        } else if card.section == .scheduleQuality {
                            metricFlags(HeartbeatMath.scheduleActionFlags(store.displayRows(for: .scheduleQuality)))
                        } else if card.section == .pickPath {
                            metricFlags(
                                HeartbeatMath.pickPathActionFlags(
                                    stores: store.displayRows(for: .pickPath),
                                    shoppers: store.displayRows(for: .pickPathPicker)
                                )
                            )
                        } else if card.section == .pph {
                            metricFlags(
                                HeartbeatMath.pphActionFlags(
                                    stores: store.displayRows(for: .pph),
                                    shoppers: store.displayRows(for: .pickerScorecard)
                                )
                            )
                        } else if card.section == .dynacap {
                            metricFlags(HeartbeatMath.dynacapActionFlags(store.displayRows(for: .dynacap)))
                        } else if card.section == .pickerScorecard {
                            let picker = HeartbeatMath.pickerActionFlags(store.displayRows(for: .pickerScorecard))
                            VStack(alignment: .leading, spacing: 8) {
                                metricFlags(Array(picker.prefix(2)), columns: 2)
                                metricFlags(Array(picker.suffix(from: 2)), columns: min(6, max(2, HubLayout.flagColumns(count: 6, width: width))))
                            }
                        } else if card.section == .labor {
                            let labor = HeartbeatMath.laborActionFlags(store.displayRows(for: .labor))
                            VStack(alignment: .leading, spacing: 8) {
                                metricFlags(Array(labor.prefix(4)), columns: min(4, max(2, HubLayout.flagColumns(count: 4, width: width))))
                                metricFlags(Array(labor.suffix(from: 4)), columns: min(3, max(2, HubLayout.flagColumns(count: 3, width: width))))
                            }
                        }
                    }
                    .modifier(DashCardChrome(health: card.health))
                }
                .buttonStyle(DashLiftStyle())
            }
        }
        .readWidth($width)
    }

    @ViewBuilder
    private func metricFlags(_ flags: [HeartbeatMath.FiveStarFlag], columns: Int? = nil) -> some View {
        DashFlagGrid(
            flags: flags,
            columns: columns ?? HubLayout.flagColumns(count: flags.count, width: width)
        )
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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(dashWash(health))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(dashInk(health).opacity(0.18), lineWidth: 1)
            Image(systemName: symbol)
                .font(.title.weight(.semibold))
                .foregroundStyle(dashInk(health))
        }
        .frame(width: 56, height: 56)
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

    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(dashWash(health).opacity(0.42))
                    }
            }
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(dashInk(health))
                    .frame(width: 5)
                    .padding(.vertical, 14)
            }
            .overlay {
                if health == .risk {
                    RiskPulseRing(cornerRadius: 16, lineWidth: 2.5)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                }
            }
            .shadow(color: Color.black.opacity(0.10), radius: 10, y: 5)
            .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                    accessory: "Pickers Doing Well  ·  15+ orders  ·  tap to \(expanded ? "collapse" : "expand")",
                    expanded: expanded
                )
            }
            .buttonStyle(.plain)

            if expanded {
                Group {
                    if board.shopperCount == 0 {
                        Text("Upload a picker score card workbook to rank opportunity and strong shoppers.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        HStack(alignment: .top, spacing: 16) {
                            shopperColumn(
                                title: "Top opportunity",
                                subtitle: "15+ orders · underperforming vs the metric mix",
                                rows: board.opportunity,
                                empty: "No opportunity shoppers in this filter.",
                                tone: .risk,
                                action: onSelectOpportunity
                            )
                            shopperColumn(
                                title: "Doing well",
                                subtitle: "15+ orders · hitting the metric mix",
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
