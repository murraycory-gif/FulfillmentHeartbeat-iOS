import SwiftUI

enum DashLayoutOption: String, CaseIterable, Identifiable {
    case equalWall, commandStrip, grouped, pulseTable
    case exceptionConsole, kanban, briefing, spotlight

    var id: String { rawValue }

    var letter: String {
        switch self {
        case .equalWall: return "A"
        case .commandStrip: return "B"
        case .grouped: return "C"
        case .pulseTable: return "D"
        case .exceptionConsole: return "E"
        case .kanban: return "F"
        case .briefing: return "G"
        case .spotlight: return "H"
        }
    }

    var title: String {
        switch self {
        case .equalWall: return "Equal wall"
        case .commandStrip: return "Command strip"
        case .grouped: return "Grouped by job"
        case .pulseTable: return "Pulse table"
        case .exceptionConsole: return "Exception console"
        case .kanban: return "Health board"
        case .briefing: return "Briefing list"
        case .spotlight: return "Spotlight"
        }
    }

    var blurb: String {
        switch self {
        case .equalWall: return "Every scorecard the same size. Loss Revenue is not a hero."
        case .commandStrip: return "All KPIs in a thin row. Actions on the left. Loss Revenue still big."
        case .grouped: return "Customer promise on top. Labor and capacity underneath."
        case .pulseTable: return "Same compact table as Labor / 5 Star. Company pulse plus open actions."
        case .exceptionConsole: return "The 3 worst scorecards get the big cards. Everything else sits in a tray."
        case .kanban: return "At Risk / Watch / Healthy columns. Cards live in the bucket they belong in."
        case .briefing: return "One list, like Mail. Loss Revenue stays a slim banner. Fast to scan."
        case .spotlight: return "One featured problem on the left. The other eight as a tight stack on the right."
        }
    }

    var isNew: Bool {
        switch self {
        case .exceptionConsole, .kanban, .briefing, .spotlight: return true
        default: return false
        }
    }
}

struct DashboardLayoutGallery: View {
    @EnvironmentObject private var store: HeartbeatStore
    @Binding var isPresented: Bool
    @State private var option: DashLayoutOption = .exceptionConsole

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: 8) {
                layoutRow(Array(DashLayoutOption.allCases.prefix(4)))
                layoutRow(Array(DashLayoutOption.allCases.suffix(4)))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            Text(option.blurb)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
            ScrollView {
                Group {
                    switch option {
                    case .equalWall: equalWall
                    case .commandStrip: commandStrip
                    case .grouped: grouped
                    case .pulseTable: pulseTable
                    case .exceptionConsole: exceptionConsole
                    case .kanban: kanban
                    case .briefing: briefing
                    case .spotlight: spotlight
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(AppTheme.bg)
        }
        .background(AppTheme.bg.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pick a dashboard layout")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Text("Preview only  ·  tell me the letter after you look")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Button("Done") { isPresented = false }
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.blue, in: Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .background(AppTheme.card)
    }

    private func layoutRow(_ items: [DashLayoutOption]) -> some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                Button {
                    option = item
                } label: {
                    HStack(spacing: 6) {
                        Text(item.letter)
                            .font(.headline.weight(.bold))
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if item.isNew {
                            Text("NEW")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(option == item ? Color.white : AppTheme.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    (option == item ? Color.white.opacity(0.22) : AppTheme.blueSoft),
                                    in: Capsule()
                                )
                        }
                    }
                    .foregroundStyle(option == item ? Color.white : AppTheme.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        option == item ? AppTheme.blue : AppTheme.card,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(option == item ? AppTheme.blue : AppTheme.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cards: [SectionSummary] {
        MetricSection.dashboardCards.compactMap { section in
            store.summaries.first(where: { $0.section == section })
        }
    }

    private var lost: SectionSummary? {
        cards.first(where: { $0.section == .lostRevenue })
    }

    private var others: [SectionSummary] {
        cards.filter { $0.section != .lostRevenue }
    }

    private var promise: [SectionSummary] {
        cards.filter { [.lostRevenue, .fiveStar, .pickPath, .prepNotReady].contains($0.section) }
    }

    private var labor: [SectionSummary] {
        cards.filter { [.dynacap, .scheduleQuality, .pph, .labor, .pickerScorecard].contains($0.section) }
    }

    private var equalWall: some View {
        VStack(spacing: 14) {
            actionBar
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                ForEach(cards) { card in
                    LayoutMetricCard(summary: card, height: 168)
                }
            }
        }
    }

    private var commandStrip: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(cards) { card in
                    LayoutChip(summary: card)
                }
            }
            HStack(alignment: .top, spacing: 14) {
                LayoutActionList(limit: 8)
                    .frame(width: 340)
                VStack(spacing: 14) {
                    if let lost {
                        LayoutMetricCard(summary: lost, height: 168, dualLost: true)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                        ForEach(Array(others.prefix(4))) { card in
                            LayoutMetricCard(summary: card, height: 150)
                        }
                    }
                }
            }
        }
    }

    private var grouped: some View {
        VStack(alignment: .leading, spacing: 12) {
            actionBar
            Text("Customer promise")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.blue)
            Text("Revenue, stars, path, prep")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                ForEach(promise) { card in
                    LayoutMetricCard(summary: card, height: 180, dualLost: card.section == .lostRevenue)
                }
            }
            Text("Labor & capacity")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.blue)
                .padding(.top, 8)
            Text("How the work gets done")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 5), spacing: 14) {
                ForEach(labor) { card in
                    LayoutMetricCard(summary: card, height: 168)
                }
            }
        }
    }

    private var pulseTable: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                LayoutStatChip(label: "\(store.checklistOpenCount) open actions", health: store.checklistOpenCount > 0 ? .risk : .good)
                LayoutStatChip(label: lost.map { "\($0.headlineText) lost" } ?? "Lost revenue", health: lost?.health ?? .none)
                LayoutStatChip(label: "\(cards.filter { $0.health == .risk }.count) at risk", health: .risk)
                LayoutStatChip(label: "\(cards.filter { $0.health == .good }.count) healthy", health: .good)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Company pulse")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                    Text("\(cards.count) scorecards  ·  tap a row")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
                HStack {
                    Text("SCORECARD").frame(maxWidth: .infinity, alignment: .leading)
                    Text("HEADLINE").frame(width: 140, alignment: .trailing)
                    Text("GOAL").frame(width: 90, alignment: .trailing)
                    Text("COVERAGE").frame(width: 120, alignment: .trailing)
                    Text("STATUS").frame(width: 100, alignment: .trailing)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
                ForEach(cards) { card in
                    HStack(spacing: 8) {
                        Text(card.section == .pickPath ? "Pick Path Compliance" : card.section.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                        Text(card.headlineText)
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(LayoutTone.ink(card.health))
                            .frame(width: 140, alignment: .trailing)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(LayoutTone.wash(card.health), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text(goal(for: card.section))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.blue)
                            .frame(width: 90, alignment: .trailing)
                        Text(card.section == .pickerScorecard ? "Shoppers" : "\(HeartbeatFormat.num(Double(card.storeCount))) stores")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 120, alignment: .trailing)
                        HealthBadge(health: card.health, prominent: true, compact: true)
                            .frame(width: 100, alignment: .trailing)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(16)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
            LayoutActionList(limit: 5, horizontal: true)
        }
    }

    private var ranked: [SectionSummary] {
        cards.sorted { healthRank($0.health) < healthRank($1.health) }
    }

    private var worst: [SectionSummary] { Array(ranked.prefix(3)) }
    private var rest: [SectionSummary] { Array(ranked.dropFirst(3)) }

    private var exceptionConsole: some View {
        VStack(alignment: .leading, spacing: 14) {
            actionBar
            Text("Needs you now")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.bad)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                ForEach(worst) { card in
                    LayoutMetricCard(summary: card, height: 200, dualLost: card.section == .lostRevenue)
                }
            }
            Text("Everything else")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.blue)
            HStack(spacing: 10) {
                ForEach(rest) { card in
                    LayoutChip(summary: card)
                }
            }
        }
    }

    private var kanban: some View {
        HStack(alignment: .top, spacing: 14) {
            kanbanColumn("At risk", .risk, cards.filter { $0.health == .risk })
            kanbanColumn("Watch", .watch, cards.filter { $0.health == .watch })
            kanbanColumn("Healthy", .good, cards.filter { $0.health == .good || $0.health == .none })
        }
    }

    private func kanbanColumn(_ title: String, _ health: Health, _ items: [SectionSummary]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(LayoutTone.ink(health))
                Text("\(items.count)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(LayoutTone.ink(health))
                Spacer()
            }
            .padding(.horizontal, 4)
            if items.isEmpty {
                Text("None")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ForEach(items) { card in
                    LayoutMetricCard(summary: card, height: 132, dualLost: card.section == .lostRevenue)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(LayoutTone.wash(health).opacity(0.45), in: RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
    }

    private var briefing: some View {
        VStack(spacing: 14) {
            if let lost {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        (Text("Loss Revenue ") + Text("ScoreCard").foregroundStyle(AppTheme.blue))
                            .font(.headline.weight(.bold))
                        Text("Total opportunity")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Text(lost.headlineText)
                        .font(.title.weight(.bold).monospacedDigit())
                        .foregroundStyle(LayoutTone.ink(lost.health))
                    Text(HeartbeatFormat.pct(lost.lostRevenuePct))
                        .font(.title.weight(.bold).monospacedDigit())
                        .foregroundStyle(LayoutTone.ink(lost.health))
                    HealthBadge(health: lost.health, prominent: true)
                }
                .padding(16)
                .background(LayoutTone.wash(lost.health), in: RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
            }
            VStack(spacing: 0) {
                ForEach(Array(others.enumerated()), id: \.element.id) { index, card in
                    if index > 0 { Divider().opacity(0.35) }
                    HStack(spacing: 14) {
                        Image(systemName: card.section.symbol)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(LayoutTone.ink(card.health))
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.section == .pickPath ? "Pick Path Compliance" : card.section.title)
                                .font(.headline.weight(.bold))
                            Text(card.headlineLabel)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Text(card.headlineText)
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(LayoutTone.ink(card.health))
                        HealthBadge(health: card.health, prominent: true, compact: true)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 4)
                }
            }
            .padding(16)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
        }
    }

    private var spotlight: some View {
        HStack(alignment: .top, spacing: 16) {
            if let feature = ranked.first {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Spotlight")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                    Text(feature.section == .pickPath ? "Pick Path Compliance" : feature.section.title)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                    HealthBadge(health: feature.health, prominent: true)
                    Text(feature.headlineText)
                        .font(.system(size: 64, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(LayoutTone.ink(feature.health))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(feature.headlineLabel)
                        .font(.title3.weight(.semibold))
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Goal")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                            Text(goal(for: feature.section))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppTheme.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.section == .pickerScorecard ? "Shoppers" : "Stores")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                            Text(HeartbeatFormat.num(Double(feature.storeCount)))
                                .font(.title2.weight(.bold))
                        }
                    }
                    Spacer(minLength: 0)
                    Text("Biggest gap vs goal in this filter")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: 420, alignment: .topLeading)
                .background(LayoutTone.wash(feature.health), in: RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                        .stroke(LayoutTone.ink(feature.health).opacity(0.4), lineWidth: 1.5)
                )
            }
            VStack(spacing: 8) {
                ForEach(Array(ranked.dropFirst())) { card in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.section == .pickPath ? "Pick Path" : card.section.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(card.headlineLabel)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(card.headlineText)
                            .font(.headline.weight(.bold).monospacedDigit())
                            .foregroundStyle(LayoutTone.ink(card.health))
                        HealthBadge(health: card.health, prominent: true, compact: true)
                    }
                    .padding(12)
                    .background(LayoutTone.wash(card.health), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .frame(width: 420)
        }
    }

    private func healthRank(_ health: Health) -> Int {
        switch health {
        case .risk: return 0
        case .watch: return 1
        case .good: return 2
        case .none: return 3
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Text("Heartbeat")
                .font(.headline.weight(.bold))
            Text("|")
                .foregroundStyle(AppTheme.textTertiary)
            Text("ACTION ITEMS")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.bad, in: Capsule())
            Text("\(store.checklistOpenCount) OPEN")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(store.checklistOpenCount > 0 ? AppTheme.bad : AppTheme.ok, in: Capsule())
            Spacer()
            Image(systemName: "chevron.down")
                .foregroundStyle(AppTheme.blue)
        }
        .padding(14)
        .background(AppTheme.badSoft, in: RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .stroke(AppTheme.bad, lineWidth: 1)
        )
    }

    private func goal(for section: MetricSection) -> String {
        switch section {
        case .lostRevenue: return "3.5%"
        case .fiveStar: return "5.00"
        case .pickPath, .pickPathPicker: return "95%"
        case .prepNotReady: return "1.9h"
        case .dynacap: return "65"
        case .scheduleQuality: return "90%"
        case .pph: return "80"
        case .labor: return "0%"
        case .pickerScorecard: return "Mix"
        }
    }
}

private enum LayoutTone {
    static func ink(_ health: Health) -> Color {
        switch health {
        case .good: return AppTheme.ok
        case .watch: return AppTheme.warn
        case .risk: return AppTheme.bad
        case .none: return AppTheme.text
        }
    }

    static func wash(_ health: Health) -> Color {
        switch health {
        case .good: return AppTheme.okSoft
        case .watch: return AppTheme.warnSoft
        case .risk: return AppTheme.badSoft
        case .none: return AppTheme.card
        }
    }
}

private struct LayoutMetricCard: View {
    let summary: SectionSummary
    var height: CGFloat = 168
    var dualLost: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                if summary.health != .none {
                    HealthBadge(health: summary.health, prominent: true, compact: true)
                }
            }
            if dualLost, summary.section == .lostRevenue {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.headlineText)
                            .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(LayoutTone.ink(summary.health))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("Lost revenue")
                            .font(.subheadline.weight(.semibold))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(HeartbeatFormat.pct(summary.lostRevenuePct))
                            .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(LayoutTone.ink(summary.health))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("Lost %")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            } else {
                Text(summary.headlineText)
                    .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(LayoutTone.ink(summary.health))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(summary.headlineLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .background(LayoutTone.wash(summary.health), in: RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .stroke(LayoutTone.ink(summary.health).opacity(0.35), lineWidth: 1)
        )
    }

    private var title: String {
        if summary.section == .pickPath { return "Pick Path Compliance" }
        return summary.section.title
    }
}

private struct LayoutChip: View {
    let summary: SectionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(shortTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
            Text(summary.headlineText)
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(LayoutTone.ink(summary.health))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(LayoutTone.wash(summary.health), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(LayoutTone.ink(summary.health).opacity(0.35), lineWidth: 1)
        )
    }

    private var shortTitle: String {
        switch summary.section {
        case .lostRevenue: return "Loss Rev"
        case .fiveStar: return "5 Star"
        case .pickPath, .pickPathPicker: return "Pick Path"
        case .prepNotReady: return "Prep NR"
        case .dynacap: return "Dynacap"
        case .scheduleQuality: return "Schedule"
        case .pph: return "PPH"
        case .labor: return "Labor"
        case .pickerScorecard: return "Pickers"
        }
    }
}

private struct LayoutStatChip: View {
    let label: String
    let health: Health

    var body: some View {
        Text(label)
            .font(.headline.weight(.bold))
            .foregroundStyle(LayoutTone.ink(health))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LayoutTone.wash(health), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct LayoutActionList: View {
    @EnvironmentObject private var store: HeartbeatStore
    var limit: Int = 6
    var horizontal: Bool = false

    private var items: [(section: MetricSection, item: ChecklistDriverItem)] {
        var seen = Set<String>()
        var out: [(MetricSection, ChecklistDriverItem)] = []
        for section in MetricSection.checklistSections {
            for group in store.checklistGroups(for: section) {
                for item in group.items {
                    let key = item.title + "|" + item.subtitle
                    guard seen.insert(key).inserted else { continue }
                    guard !store.checklistItem(for: item, section: section).status.isClosed else { continue }
                    out.append((section, item))
                    if out.count == limit { return out }
                }
            }
        }
        return out
    }

    var body: some View {
        Group {
            if horizontal {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Open actions")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.bad)
                    HStack(spacing: 10) {
                        ForEach(items, id: \.item.id) { row in
                            actionCard(row.section, row.item)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Open actions")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.bad)
                        HealthBadge(health: .risk, prominent: true, compact: true)
                        Text("\(store.checklistOpenCount)")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.bad)
                        Spacer()
                    }
                    ForEach(items, id: \.item.id) { row in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                    .lineLimit(1)
                                Text(row.item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            HealthBadge(health: row.item.health, prominent: true, compact: true)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(14)
                .background(AppTheme.badSoft.opacity(0.55), in: RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                        .stroke(AppTheme.bad, lineWidth: 1)
                )
            }
        }
    }

    private func actionCard(_ section: MetricSection, _ item: ChecklistDriverItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
            Text(item.value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(LayoutTone.ink(item.health))
            HealthBadge(health: item.health, prominent: true, compact: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LayoutTone.wash(item.health), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
