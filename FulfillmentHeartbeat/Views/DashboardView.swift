import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var pushedSection: MetricSection?

    var body: some View {
        List {
            Section {
                header
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
            }
            Section {
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
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
            Section {
                FulfillmentChecklistCard()
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
            }
            Section {
                PickerScoreCard {
                    if sizeClass == .regular {
                        router.open(section: .pickerScorecard)
                    } else {
                        pushedSection = .pickerScorecard
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 16, trailing: 20))
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

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            HubNavLogo(pulse: true, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text("Fulfillment Heartbeat")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            FilterBar()
        }
    }

    private var subtitle: String {
        if let last = store.lastUpload {
            return "\(store.filters.summary) · Updated \(HeartbeatFormat.relative(last.uploadedAt))"
        }
        return store.filters.summary
    }
}

struct SectionCard: View {
    let summary: SectionSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text(summary.section.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.textSecondary)
                            if justUpdated {
                                Text("Just updated")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppTheme.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AppTheme.blueSoft, in: Capsule(style: .continuous))
                            }
                        }
                        Text(summary.headlineText)
                            .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(ink)
                        Text(summary.headlineLabel)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    HealthBadge(health: summary.health)
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
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                            .stroke(stroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
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
        case .watch: return AppTheme.warn.opacity(0.28)
        case .risk: return AppTheme.bad.opacity(0.28)
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

    private var justUpdated: Bool {
        guard let uploadedAt = summary.lastUploadedAt else { return false }
        return Date().timeIntervalSince(uploadedAt) < 180
    }

    private var metaLine: String {
        var parts = ["\(summary.storeCount) store\(summary.storeCount == 1 ? "" : "s")"]
        if summary.riskCount > 0 {
            parts.append("\(summary.riskCount) at risk")
        }
        return parts.joined(separator: " · ")
    }
}

struct PickerScoreCard: View {
    @EnvironmentObject private var store: HeartbeatStore
    let action: () -> Void

    private var board: HeartbeatMath.PickerBoard {
        store.pickerBoard
    }

    private var upload: UploadRecord? { store.upload(for: .pickerScorecard) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Picker Score Card")
                            .font(.title2.weight(.semibold))
                        if let uploadedAt = upload?.uploadedAt, Date().timeIntervalSince(uploadedAt) < 180 {
                            Text("Just updated")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppTheme.blueSoft, in: Capsule(style: .continuous))
                        }
                    }
                    Text("Shoppers underperforming on PPH, Presubs, OTH5, or COE — versus those running strong.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Button(action: action) {
                    HStack(spacing: 6) {
                        Text("View all")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
                }
                .buttonStyle(.plain)
            }

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
                        tone: .risk
                    )
                    shopperColumn(
                        title: "Doing well",
                        subtitle: "Hitting the metric mix",
                        rows: board.strong,
                        empty: "No strong shoppers in this filter.",
                        tone: .good
                    )
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
        tone: Health
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
                        shopperRow(row)
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

    private func shopperRow(_ row: MetricRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.shopperName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Text("\(row.storeNumber) · \(divisionLabel(for: row))")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            HStack(spacing: 8) {
                ForEach(HeartbeatMath.pickerMetricReadout(row), id: \.name) { metric in
                    VStack(spacing: 2) {
                        Text(metric.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text(metric.value)
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(metricColor(metric.health))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(metricWash(metric.health))
                    )
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func metricColor(_ health: Health) -> Color {
        switch health {
        case .good: return AppTheme.ok
        case .watch: return AppTheme.warn
        case .risk: return AppTheme.bad
        case .none: return AppTheme.text
        }
    }

    private func metricWash(_ health: Health) -> Color {
        switch health {
        case .good: return AppTheme.okSoft
        case .watch: return AppTheme.warnSoft
        case .risk: return AppTheme.badSoft
        case .none: return AppTheme.card
        }
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
