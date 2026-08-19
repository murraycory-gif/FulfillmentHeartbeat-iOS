import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var pushedSection: MetricSection?

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    if store.summaries.contains(where: { $0.health == .risk || $0.health == .watch }) {
                        FulfillmentChecklistCard()
                    }
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(store.summaries) { summary in
                            SectionCard(summary: summary) {
                                if sizeClass == .regular {
                                    router.open(section: summary.section)
                                } else {
                                    pushedSection = summary.section
                                }
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
        .alert("Couldn’t load", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var columns: [GridItem] {
        if sizeClass == .regular {
            return [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
            ]
        }
        return [GridItem(.flexible())]
    }
}

struct SectionCard: View {
    let summary: SectionSummary
    let action: () -> Void
    @State private var pulseOn = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text(summary.section.title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                            UpdatedStamp(date: summary.lastUploadedAt)
                        }
                        Text(summary.headlineText)
                            .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(ink)
                        Text(summary.headlineLabel)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    if summary.health != .none {
                        HealthBadge(health: summary.health, prominent: true)
                    }
                }
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(summary.secondary)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.text)
                        Text(metaLine)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(ink)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: AppTheme.radiusS, style: .continuous))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .stroke(stroke, lineWidth: shouldPulse ? 2.4 : 1)
                    .opacity(shouldPulse ? (pulseOn ? 1 : 0.22) : 1)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            guard shouldPulse else { return }
            pulseOn = false
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                pulseOn = true
            }
        }
    }

    private var shouldPulse: Bool {
        summary.health == .risk || summary.health == .watch
    }

    private var fill: Color {
        switch summary.health {
        case .good: return AppTheme.okSoft
        case .watch: return AppTheme.warnSoft
        case .risk: return AppTheme.badSoft
        case .none: return AppTheme.card
        }
    }

    private var stroke: Color {
        switch summary.health {
        case .good: return AppTheme.ok.opacity(0.28)
        case .watch: return AppTheme.warn
        case .risk: return AppTheme.bad
        case .none: return AppTheme.cardBorder
        }
    }

    private var ink: Color {
        switch summary.health {
        case .good: return AppTheme.ok
        case .watch: return AppTheme.warn
        case .risk: return AppTheme.bad
        case .none: return AppTheme.blue
        }
    }

    private var metaLine: String {
        var parts = ["\(summary.storeCount) store\(summary.storeCount == 1 ? "" : "s")"]
        if summary.riskCount > 0 {
            parts.append("\(summary.riskCount) at risk")
        }
        return parts.joined(separator: " · ")
    }
}

struct PickerHighlightsPanel: View {
    @EnvironmentObject private var store: HeartbeatStore
    var onSelectOpportunity: () -> Void = {}
    var onSelectStrong: () -> Void = {}
    @State private var expanded = true

    private var board: HeartbeatMath.PickerBoard {
        store.pickerBoard
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text("Top Opportunity Pickers")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.bad)
                    Text("|")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("Pickers Doing Well")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.ok)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.blueSoft, in: Circle())
                }
            }
            .buttonStyle(.plain)

            if expanded {
                if board.shopperCount == 0 {
                    Text("Upload a picker score card workbook to rank opportunity and strong shoppers.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    HStack(alignment: .top, spacing: 16) {
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
        }
        .padding(20)
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

    private func shopperColumn(
        title: String,
        subtitle: String,
        rows: [MetricRow],
        empty: String,
        tone: Health,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tone == .risk ? AppTheme.bad : AppTheme.ok)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if rows.isEmpty {
                Text(empty)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(rows) { row in
                    Button(action: action) {
                        PickerShopperCard(row: row, place: "\(row.storeNumber) · \(divisionLabel(for: row))")
                    }
                    .buttonStyle(.plain)
                    if row.id != rows.last?.id {
                        Divider().opacity(0.28)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .fill(tone == .risk ? AppTheme.badSoft.opacity(0.55) : AppTheme.okSoft.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .stroke(tone == .risk ? AppTheme.bad : AppTheme.ok, lineWidth: 2)
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
