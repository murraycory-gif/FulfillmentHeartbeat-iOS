import SwiftUI

/// Pulse / Power BI Mobile briefing density. Layout math is testable off SwiftUI.
enum CommandCenterLayout {
    static let heroSections: [MetricSection] = [.sales, .lostRevenue, .fiveStar]
    static let gutter: CGFloat = 6
    static let minGlanceHeight: CGFloat = 112
    static let minHeroHeight: CGFloat = 96
    static let sparkBars = 8

    /// Every operational dashboard card that is not a navy hero — fills the leftover viewport.
    static var glanceSections: [MetricSection] {
        [
            .labor,
            .pickerScorecard,
            .dynacap,
            .pph,
            .missingItems,
            .scheduleQuality,
            .pickPath,
            .preSubOOS,
            .prepNotReady,
        ]
    }

    static func isHero(_ section: MetricSection) -> Bool {
        heroSections.contains(section)
    }

    static func coversEveryDashboardSection(heroes: [MetricSection] = heroSections, glance: [MetricSection] = glanceSections) -> Bool {
        Set(heroes + glance) == Set(MetricSection.dashboardCards)
    }

    static func glanceColumns(width: CGFloat, phone: Bool, portrait: Bool) -> Int {
        if phone {
            return width >= 700 ? 3 : 2
        }
        if portrait {
            return 2
        }
        if width >= 980 { return 5 }
        if width >= 820 { return 4 }
        return 3
    }

    static func heroColumns(width: CGFloat, phone: Bool, portrait: Bool) -> Int {
        if phone, !portrait, width >= 700 { return 3 }
        if phone, portrait { return 1 }
        return 3
    }

    static func rowCount(cards: Int, columns: Int) -> Int {
        let cols = max(columns, 1)
        return max(1, Int(ceil(Double(cards) / Double(cols))))
    }

    /// Stretch glance tiles so heroes + grid consume the leftover height (no blank lower half).
    static func glanceTileHeight(
        remaining: CGFloat,
        cards: Int,
        columns: Int,
        spacing: CGFloat = gutter
    ) -> CGFloat {
        let rows = rowCount(cards: cards, columns: columns)
        let gutters = spacing * CGFloat(max(rows - 1, 0))
        let raw = (remaining - gutters) / CGFloat(rows)
        return max(minGlanceHeight, raw)
    }

    static func heroBandHeight(phone: Bool, portrait: Bool, available: CGFloat) -> CGFloat {
        if phone {
            return portrait ? 112 : 100
        }
        let fraction = portrait ? 0.15 : 0.16
        return min(128, max(minHeroHeight, available * fraction))
    }

    static func fillsViewport(
        remaining: CGFloat,
        tileHeight: CGFloat,
        cards: Int,
        columns: Int,
        spacing: CGFloat = gutter
    ) -> Bool {
        let rows = rowCount(cards: cards, columns: columns)
        let used = CGFloat(rows) * tileHeight + spacing * CGFloat(max(rows - 1, 0))
        return used + 1 >= remaining || remaining <= minGlanceHeight
    }

    static func glanceTitle(_ section: MetricSection) -> String {
        switch section {
        case .lostRevenue: return "Loss"
        case .fiveStar: return "5 Star"
        case .missingItems: return "Missing"
        case .pickerScorecard: return "Picker"
        case .pickPath: return "Pick Path"
        case .prepNotReady: return "Prep"
        case .preSubOOS: return "Pre-Sub"
        case .scheduleQuality: return "Schedule"
        default: return section.overviewLead
        }
    }

    static func compactValue(_ card: SectionSummary) -> String {
        if card.section == .sales || card.section == .lostRevenue {
            return HeartbeatFormat.moneyShort(card.headline)
        }
        return card.headlineText
    }

    /// Empty chrome stays empty. Never paint `.none` as Healthy when the
    /// headline or store count is still 0 (company Picker 0 / Healthy reject).
    static func displayedHealth(_ card: SectionSummary) -> Health {
        if card.health == .none, (card.headline ?? 0) == 0 || card.storeCount == 0 {
            return .none
        }
        if card.health == .none {
            return .none
        }
        return card.health
    }

    static func barFraction(_ card: SectionSummary) -> CGFloat {
        switch card.health {
        case .good: return 0.92
        case .watch: return 0.58
        case .risk: return 0.30
        case .none: return 0.10
        }
    }

    /// Cheap Pulse-style spark. Heights come from this card's health / risk — not invented KPIs.
    static func sparkHeights(_ card: SectionSummary) -> [CGFloat] {
        let peak = barFraction(card)
        let seed = card.storeCount + card.watchCount * 3 + card.riskCount * 5
        let wave: [CGFloat] = [0.52, 0.64, 0.46, 0.72, 0.58, 0.84, 0.68, 1.0]
        return wave.enumerated().map { index, step in
            let wobble = CGFloat((seed + index * 7) % 11) / 80
            return min(1, max(0.16, step * peak - wobble))
        }
    }

    static func alertRank(_ cards: [SectionSummary]) -> [SectionSummary] {
        cards.sorted { lhs, rhs in
            if lhs.health.dashboardRank != rhs.health.dashboardRank {
                return lhs.health.dashboardRank < rhs.health.dashboardRank
            }
            return (MetricSection.dashboardCards.firstIndex(of: lhs.section) ?? 99)
                < (MetricSection.dashboardCards.firstIndex(of: rhs.section) ?? 99)
        }
    }
}

struct CommandCenterHome: View {
    @EnvironmentObject private var store: HeartbeatStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    var open: (MetricSection) -> Void

    private var phone: Bool { HubLayout.isPhone(sizeClass) }

    var body: some View {
        GeometryReader { geo in
            let portrait = geo.size.height > geo.size.width
            let cards = glanceCards
            let cols = CommandCenterLayout.glanceColumns(width: geo.size.width, phone: phone, portrait: portrait)
            let heroH = CommandCenterLayout.heroBandHeight(phone: phone, portrait: portrait, available: geo.size.height)
            let header: CGFloat = phone ? 18 : 20
            let pad: CGFloat = phone ? 10 : 12
            let leftover = max(
                CommandCenterLayout.minGlanceHeight,
                geo.size.height - heroH - header - pad - CommandCenterLayout.gutter
            )
            let tileH = CommandCenterLayout.glanceTileHeight(
                remaining: leftover,
                cards: max(cards.count, 1),
                columns: cols
            )
            let content = VStack(spacing: CommandCenterLayout.gutter) {
                heroBand(height: heroH, portrait: portrait, width: geo.size.width)
                glanceHeader
                glanceGrid(cards: cards, columns: cols, tileHeight: tileH)
            }
            .padding(.horizontal, phone ? 10 : 12)
            .padding(.bottom, phone ? 6 : 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if phone, leftover < CommandCenterLayout.minGlanceHeight * 3 {
                ScrollView {
                    content
                }
                .scrollIndicators(.hidden)
            } else {
                content
            }
        }
    }

    private var heroCards: [SectionSummary] {
        CommandCenterLayout.heroSections.map { store.summary(for: $0) }
    }

    private var glanceCards: [SectionSummary] {
        CommandCenterLayout.glanceSections.map { store.summary(for: $0) }
    }

    private func heroBand(height: CGFloat, portrait: Bool, width: CGFloat) -> some View {
        let cols = CommandCenterLayout.heroColumns(width: width, phone: phone, portrait: portrait)
        let rows = CommandCenterLayout.rowCount(cards: heroCards.count, columns: cols)
        let tile = max(
            96,
            (height - CommandCenterLayout.gutter * CGFloat(max(rows - 1, 0))) / CGFloat(rows)
        )
        return LazyVGrid(
            columns: HubLayout.grid(cols, spacing: CommandCenterLayout.gutter, minWidth: 64),
            spacing: CommandCenterLayout.gutter
        ) {
            ForEach(heroCards) { card in
                CommandCenterHeroTile(card: card) {
                    open(card.section)
                }
                .frame(minHeight: tile, maxHeight: .infinity)
            }
        }
        .frame(height: height)
    }

    private var glanceHeader: some View {
        HStack {
            Text("AT-A-GLANCE · ALL SECTIONS")
                .font(AppTheme.rounded(.caption2, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(AppTheme.textTertiary)
            Spacer(minLength: 0)
        }
        .frame(height: phone ? 14 : 16)
    }

    private func glanceGrid(cards: [SectionSummary], columns: Int, tileHeight: CGFloat) -> some View {
        LazyVGrid(
            columns: HubLayout.grid(columns, spacing: CommandCenterLayout.gutter, minWidth: 64),
            spacing: CommandCenterLayout.gutter
        ) {
            ForEach(cards) { card in
                CommandCenterGlanceTile(card: card) {
                    open(card.section)
                }
                .frame(minHeight: tileHeight, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct CommandCenterHeroTile: View {
    let card: SectionSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(CommandCenterLayout.glanceTitle(card.section))
                        .font(AppTheme.rounded(.subheadline, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.92))
                    Spacer(minLength: 4)
                    HealthBadge(health: CommandCenterLayout.displayedHealth(card), prominent: true, compact: true)
                }
                Text(CommandCenterLayout.compactValue(card))
                    .font(AppTheme.rounded(size: 26, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.gold)
                        .frame(width: 7, height: 7)
                    Text("Stores \(card.storeCount)")
                        .font(AppTheme.rounded(.caption, weight: .bold).monospacedDigit())
                        .foregroundStyle(AppTheme.gold)
                    Spacer(minLength: 0)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(CommandCenterLayout.glanceTitle(card.section)), \(CommandCenterLayout.compactValue(card)), \(CommandCenterLayout.displayedHealth(card).label), Stores \(card.storeCount)")
    }
}

struct CommandCenterGlanceTile: View {
    let card: SectionSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(CommandCenterLayout.glanceTitle(card.section))
                        .font(AppTheme.rounded(.caption, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    HealthBadge(health: CommandCenterLayout.displayedHealth(card), compact: true)
                }
                Text(CommandCenterLayout.compactValue(card))
                    .font(AppTheme.rounded(size: 24, weight: .bold).monospacedDigit())
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                CommandCenterSpark(
                    heights: CommandCenterLayout.sparkHeights(card),
                    health: CommandCenterLayout.displayedHealth(card)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(CommandCenterLayout.glanceTitle(card.section)), \(CommandCenterLayout.compactValue(card)), \(CommandCenterLayout.displayedHealth(card).label)")
    }
}

struct CommandCenterSpark: View {
    var heights: [CGFloat]
    var health: Health

    var body: some View {
        GeometryReader { geo in
            let bars = heights.isEmpty ? [0.55] : heights
            let gap: CGFloat = 3
            let width = max(3, (geo.size.width - gap * CGFloat(max(bars.count - 1, 0))) / CGFloat(max(bars.count, 1)))
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, fraction in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(AppTheme.healthInk(health))
                        .frame(width: width, height: max(6, geo.size.height * min(max(fraction, 0.12), 1)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}

struct CommandCenterMeter: View {
    var fraction: CGFloat
    var health: Health

    var body: some View {
        CommandCenterSpark(heights: Array(repeating: fraction, count: 1), health: health)
            .frame(height: 5)
    }
}

struct CommandCenterAlertsRail: View {
    @EnvironmentObject private var store: HeartbeatStore
    var open: (MetricSection) -> Void = { _ in }

    private var cards: [SectionSummary] {
        CommandCenterLayout.alertRank(MetricSection.dashboardCards.map { store.summary(for: $0) })
    }

    private var liveStores: Int {
        cards.map(\.storeCount).max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ALERTS")
                .font(AppTheme.rounded(.caption2, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(AppTheme.textTertiary)
            Text(store.filters.summary)
                .font(AppTheme.rounded(.caption, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(cards) { card in
                        Button {
                            open(card.section)
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(AppTheme.healthInk(CommandCenterLayout.displayedHealth(card)))
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(CommandCenterLayout.glanceTitle(card.section))
                                        .font(AppTheme.rounded(.caption, weight: .bold))
                                        .foregroundStyle(AppTheme.text)
                                    Text(CommandCenterLayout.compactValue(card))
                                        .font(AppTheme.rounded(.caption, weight: .bold).monospacedDigit())
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer(minLength: 4)
                                HealthBadge(health: CommandCenterLayout.displayedHealth(card), compact: true)
                            }
                            .padding(8)
                            .background(AppTheme.healthWash(CommandCenterLayout.displayedHealth(card)), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
            HStack(spacing: 6) {
                Circle().fill(AppTheme.gold).frame(width: 7, height: 7)
                Text("Live \(liveStores) stores")
                    .font(AppTheme.rounded(.caption2, weight: .bold))
                    .foregroundStyle(AppTheme.gold)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.bg)
    }
}
