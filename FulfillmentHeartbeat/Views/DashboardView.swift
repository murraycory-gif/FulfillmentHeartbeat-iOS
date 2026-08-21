import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var pushedSection: MetricSection?
    @State private var showError = false
    @State private var showLayoutGallery = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    PageHeadline(lead: "Fulfillment Heartbeat", accent: "Dashboard")
                    Button {
                        showLayoutGallery = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.grid.3x3.fill")
                                .font(.title3.weight(.semibold))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Preview 4 dashboard layouts")
                                    .font(.headline.weight(.bold))
                                Text("A Equal wall  ·  B Command strip  ·  C Grouped  ·  D Pulse table")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            Spacer()
                            Text("Open")
                                .font(.subheadline.weight(.bold))
                            Image(systemName: "chevron.right")
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    if store.summaries.contains(where: { $0.health == .risk || $0.health == .watch }) {
                        FulfillmentChecklistCard()
                    }
                    if let lost = store.summaries.first(where: { $0.section == .lostRevenue }) {
                        LostRevenueDashCard(summary: lost) {
                            if sizeClass == .regular {
                                router.open(section: .lostRevenue)
                            } else {
                                pushedSection = .lostRevenue
                            }
                        }
                    }
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(store.summaries.filter { $0.section != .lostRevenue }) { summary in
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
        .fullScreenCover(isPresented: $showLayoutGallery) {
            DashboardLayoutGallery(isPresented: $showLayoutGallery)
                .environmentObject(store)
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    HStack(spacing: 8) {
                        Text(summary.section == .pickPath ? "Pick Path Compliance" : summary.section.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        UpdatedStamp(date: summary.lastUploadedAt)
                    }
                    Spacer()
                    if summary.health != .none {
                        HealthBadge(health: summary.health, prominent: true)
                    }
                }
                if summary.section == .scheduleQuality {
                    schedulePair
                } else {
                    Text(summary.headlineText)
                        .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(ink)
                    Text(summary.headlineLabel)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                }
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(ink)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: AppTheme.radiusS, style: .continuous))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 220, alignment: .topLeading)
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

    private var schedulePair: some View {
        HStack(spacing: 16) {
            scheduleStat("Under Scheduled", summary.underScheduledCount)
            scheduleStat("Over Scheduled", summary.overScheduledCount)
        }
    }

    private func scheduleStat(_ title: String, _ count: Int) -> some View {
        let health: Health = count == 0 ? .good : .risk
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(HeartbeatFormat.num(Double(count)))
                    .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(health == .risk ? AppTheme.bad : AppTheme.ok)
                Text("stores")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(health == .risk ? AppTheme.bad : AppTheme.text)
            }
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
}

struct LostRevenueDashCard: View {
    let summary: SectionSummary
    let action: () -> Void
    @State private var pulseOn = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    HStack(spacing: 8) {
                        (Text("Loss Revenue ") + Text("ScoreCard").foregroundStyle(AppTheme.blue))
                            .font(.title3.weight(.bold))
                        UpdatedStamp(date: summary.lastUploadedAt)
                    }
                    Spacer()
                    if summary.health != .none {
                        HealthBadge(health: summary.health, prominent: true)
                    }
                }
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(summary.headlineText)
                            .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                        Text("Total Lost Revenue (Total Opportunity)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(HeartbeatFormat.pct(summary.lostRevenuePct))
                            .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                        Text("Total Lost Revenue % (Total Opportunity)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(ink)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: AppTheme.radiusS, style: .continuous))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 220, alignment: .topLeading)
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
        VStack(alignment: .leading, spacing: expanded ? 14 : 0) {
            Button {
                expanded.toggle()
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
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
                        }
                        Text("15+ orders  ·  tap to \(expanded ? "collapse" : "expand")")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.blueSoft, in: Circle())
                }
                .contentShape(Rectangle())
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
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
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
