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
                                DashLostBanner(summary: lost) { open(.lostRevenue) }
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

private func dashInk(_ health: Health) -> Color {
    switch health {
    case .good: return AppTheme.ok
    case .watch: return AppTheme.warn
    case .risk: return AppTheme.bad
    case .none: return AppTheme.text
    }
}

private func dashWash(_ health: Health) -> Color {
    switch health {
    case .good: return AppTheme.okSoft
    case .watch: return AppTheme.warnSoft
    case .risk: return AppTheme.badSoft
    case .none: return AppTheme.tableFill
    }
}

struct DashLostBanner: View {
    let summary: SectionSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    (Text("Loss Revenue ") + Text("ScoreCard").foregroundStyle(AppTheme.blue))
                        .font(.title2.weight(.bold))
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
            .padding(18)
            .background(dashWash(summary.health), in: RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var riskLine: String {
        let risk = HeartbeatFormat.num(Double(summary.riskCount))
        if summary.riskCount == 0 { return "0 stores at risk" }
        return "\(risk) stores at risk"
    }
}

struct DashBriefingList: View {
    let cards: [SectionSummary]
    let action: (MetricSection) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                if index > 0 { Divider().opacity(0.35) }
                Button {
                    action(card.section)
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: card.section.symbol)
                            .font(.title.weight(.semibold))
                            .foregroundStyle(dashInk(card.health))
                            .frame(width: 44)
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
                    .padding(.vertical, 16)
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(AppTheme.tableFill, in: RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 1.5)
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
