import SwiftUI

/// Pulse / Power BI Mobile briefing density. Layout math is testable off SwiftUI.
enum CommandCenterLayout {
    static let heroSections: [MetricSection] = [.sales, .lostRevenue, .fiveStar]
    static let gutter: CGFloat = 8
    static let minGlanceHeight: CGFloat = 132
    static let minHeroHeight: CGFloat = 120

    /// Every operational dashboard card that is not a navy hero.
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

    /// Phone home is a 1-column scroll. Pad leftover-fill. Mac scrolls readable tiles.
    static func glanceColumns(width: CGFloat, phone: Bool, portrait: Bool) -> Int {
        if phone { return 1 }
        if portrait {
            return 2
        }
        if width >= 980 { return 5 }
        if width >= 820 { return 4 }
        return 3
    }

    static func heroColumns(width: CGFloat, phone: Bool, portrait: Bool) -> Int {
        if phone { return 1 }
        return 3
    }

    /// Readable navy hero on iPhone 13 (390) / 17 Pro. Not the 51pt leftover slice.
    static func phoneHeroMinHeight() -> CGFloat {
        PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 100 : 124
    }

    static func phoneGlanceMinHeight() -> CGFloat {
        PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 78 : 96
    }

    static func phoneHomeStackSpacing() -> CGFloat {
        PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 8 : 12
    }

    static func phoneHomeHorizontalPadding() -> CGFloat {
        PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 12 : 16
    }

    static func phoneHomeTopPadding() -> CGFloat {
        PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 4 : 8
    }

    static func phoneHomeBottomPadding() -> CGFloat {
        PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 16 : 28
    }

    static func phoneHeroValueSize() -> CGFloat {
        PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 28 : 34
    }

    static func phoneHeroCardPadding() -> CGFloat {
        PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 12 : 16
    }

    static func phoneHeroCorner() -> CGFloat {
        PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 14 : 18
    }

    static func phoneScorecardAccentWidth() -> CGFloat {
        PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 5 : 8
    }

    static func phoneScorecardStackSpacing() -> CGFloat {
        PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 8 : 14
    }

    static func phoneScorecardPadding() -> CGFloat {
        PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 12 : 16
    }

    static func phoneScorecardCorner() -> CGFloat {
        PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 14 : 18
    }

    static func phoneScorecardChipMinHeight() -> CGFloat {
        PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 44 : 56
    }

    static func phoneScorecardChipPadding() -> CGFloat {
        PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 8 : 12
    }

    static func phoneScorecardChipSpacing() -> CGFloat {
        PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 6 : 10
    }

    static func phoneScorecardShadowRadius() -> CGFloat {
        PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 4 : 10
    }

    /// Phone must scroll. Do not stretch tiles to consume leftover viewport.
    static func shouldFillPhoneViewport() -> Bool { false }

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

    /// Mac Catalyst: readable MUST M sizes. Do not shrink tiles to leftover
    /// `geo.size.height`. Caller uses `MacCommandCenterFit.overflows` to scroll.
    static func macCommandCenterFit(
        availableHeight: CGFloat,
        glanceCards: Int,
        glanceColumns: Int,
        portrait: Bool
    ) -> MacCommandCenterFit {
        let header: CGFloat = PulseLaunch.shouldUseExpandedMacReadableChrome() ? 28 : 16
        let pad: CGFloat = PulseLaunch.shouldUseExpandedMacReadableChrome() ? 16 : 12
        let rows = rowCount(cards: glanceCards, columns: max(glanceColumns, 1))
        let stackGutters = gutter * 2
        let glanceGutters = gutter * CGFloat(max(rows - 1, 0))
        let hero = heroBandHeight(
            phone: false,
            portrait: portrait,
            available: 1000,
            mac: true
        )
        let glance = leftoverGlanceFloor(mac: true)
        let used = header + pad + stackGutters + hero + CGFloat(rows) * glance + glanceGutters
        _ = availableHeight
        return MacCommandCenterFit(
            heroHeight: hero,
            glanceTileHeight: glance,
            headerHeight: header,
            pad: pad,
            usedHeight: used
        )
    }

    static func leftoverGlanceFloor(mac: Bool) -> CGFloat {
        mac && PulseLaunch.shouldUseExpandedMacReadableChrome()
            ? HubLayout.MacReadable.glanceFloor
            : minGlanceHeight
    }

    static func heroBandHeight(phone: Bool, portrait: Bool, available: CGFloat, mac: Bool = false) -> CGFloat {
        if phone {
            return portrait ? 168 : 128
        }
        if mac, PulseLaunch.shouldUseExpandedMacReadableChrome() {
            let fraction = portrait ? 0.22 : 0.23
            return min(HubLayout.MacReadable.heroBandMax, max(156, available * fraction))
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

    /// GeometryReader can freeze the snapshot passed into a tile. Live
    /// `summary` + `seatPaintStamp` is the dashboard filter paint.
    static func paintedCard(_ card: SectionSummary, store: HeartbeatStore) -> SectionSummary {
        _ = store.seatPaintStamp
        guard PulseLaunch.shouldBindCommandCenterDashboardToSeatPaint() else { return card }
        return store.summary(for: card.section)
    }

    /// Empty chrome stays empty. Never paint `.none` as Healthy when the
    /// headline or store count is still 0 (company Picker 0 / Healthy reject).
    static func sectionPills(
        card: SectionSummary,
        flags: [HeartbeatMath.FiveStarFlag]
    ) -> [HeartbeatMath.FiveStarFlag] {
        let named = flags.filter { !$0.value.isEmpty && $0.value != "—" }
        if displayedHealth(card) == .none || ((card.headline ?? 0) == 0 && card.storeCount == 0) {
            return Array(named.prefix(6))
        }
        if !named.isEmpty { return Array(named.prefix(6)) }
        let healthy = max(0, card.storeCount - card.watchCount - card.riskCount)
        return [
            HeartbeatMath.FiveStarFlag(name: "Healthy", value: HeartbeatFormat.num(Double(healthy)), health: .good, stores: healthy),
            HeartbeatMath.FiveStarFlag(name: "Watch", value: HeartbeatFormat.num(Double(card.watchCount)), health: card.watchCount == 0 ? .good : .watch, stores: card.watchCount),
            HeartbeatMath.FiveStarFlag(name: "At Risk", value: HeartbeatFormat.num(Double(card.riskCount)), health: card.riskCount == 0 ? .good : .risk, stores: card.riskCount),
        ]
    }

    static func displayedHealth(_ card: SectionSummary) -> Health {
        if card.health == .none, (card.headline ?? 0) == 0 || card.storeCount == 0 {
            return .none
        }
        if card.health == .none {
            return .none
        }
        return card.health
    }

    /// One SF Symbol per metric. Reuses the scorecard / sidebar glyph.
    static func glanceSymbol(_ section: MetricSection) -> String {
        section.symbol
    }

    /// Tight brand-blue title strip across the top of each glance card.
    static func glanceTitleUsesBlueBanner() -> Bool { true }

    /// SF Symbol sits under the value, horizontally centered.
    static func glanceIconCentered() -> Bool { true }

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

struct MacCommandCenterFit: Equatable {
    var heroHeight: CGFloat
    var glanceTileHeight: CGFloat
    var headerHeight: CGFloat
    var pad: CGFloat
    var usedHeight: CGFloat

    static func overflows(availableHeight: CGFloat, usedHeight: CGFloat) -> Bool {
        usedHeight > availableHeight + 1
    }
}

/// iPhone 13+ / 17 Pro dashboard. Portrait-first 1-column scroll.
/// No GeometryReader leftover-fill — that packed 3 navy heroes into 168pt
/// (~51pt each) and a 2-col glance grid under Pages + Filters + banner.
struct PhoneCommandCenterHome: View {
    @EnvironmentObject private var store: HeartbeatStore
    var open: (MetricSection) -> Void

    var body: some View {
        let _ = store.seatPaintStamp
        let _ = store.filters.summary
        ScrollView {
            VStack(alignment: .leading, spacing: CommandCenterLayout.phoneHomeStackSpacing()) {
                ForEach(heroCards) { card in
                    PhoneCommandHeroCard(card: card) {
                        open(card.section)
                    }
                }
                Text("AT-A-GLANCE · ALL SECTIONS")
                    .font(AppTheme.rounded(.caption, weight: .heavy))
                    .tracking(0.7)
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.top, PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 4 : 8)
                ForEach(glanceCards) { card in
                    PhoneCommandGlanceCard(card: card) {
                        open(card.section)
                    }
                }
            }
            .padding(.horizontal, CommandCenterLayout.phoneHomeHorizontalPadding())
            .padding(.top, CommandCenterLayout.phoneHomeTopPadding())
            .padding(.bottom, CommandCenterLayout.phoneHomeBottomPadding())
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(PulseLaunch.shouldOfferPullToRefreshSeatPack() ? .always : .basedOnSize)
        .hubSeatPackRefreshable()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var heroCards: [SectionSummary] {
        _ = store.seatPaintStamp
        return CommandCenterLayout.heroSections.map { store.summary(for: $0) }
    }

    private var glanceCards: [SectionSummary] {
        _ = store.seatPaintStamp
        return CommandCenterLayout.glanceSections.map { store.summary(for: $0) }
    }
}

struct PhoneCommandHeroCard: View {
    @EnvironmentObject private var store: HeartbeatStore
    let card: SectionSummary
    var action: (() -> Void)? = nil

    private var painted: SectionSummary {
        CommandCenterLayout.paintedCard(card, store: store)
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) { hero }
                    .buttonStyle(.plain)
            } else {
                hero
            }
        }
        .frame(minHeight: HubLayout.phoneHitTarget)
        .accessibilityLabel("\(CommandCenterLayout.glanceTitle(painted.section)), \(CommandCenterLayout.compactValue(painted)), \(CommandCenterLayout.displayedHealth(painted).label), Stores \(painted.storeCount)")
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 6 : 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(CommandCenterLayout.glanceTitle(painted.section))
                    .font(AppTheme.rounded(PulseLaunch.shouldUseCompactPhoneCommandChrome() ? .headline : .title3, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(2)
                Spacer(minLength: 8)
                HealthBadge(
                    health: CommandCenterLayout.displayedHealth(painted),
                    prominent: true,
                    compact: PulseLaunch.shouldUseCompactPhoneCommandChrome()
                )
            }
            Text(CommandCenterLayout.compactValue(painted))
                .font(AppTheme.rounded(size: CommandCenterLayout.phoneHeroValueSize(), weight: .bold).monospacedDigit())
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.gold)
                    .frame(width: PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 6 : 8, height: PulseLaunch.shouldUseCompactPhoneCommandChrome() ? 6 : 8)
                Text("Stores \(painted.storeCount)")
                    .font(AppTheme.rounded(PulseLaunch.shouldUseCompactPhoneCommandChrome() ? .subheadline : .body, weight: .bold).monospacedDigit())
                    .foregroundStyle(AppTheme.gold)
                Spacer(minLength: 0)
            }
        }
        .padding(CommandCenterLayout.phoneHeroCardPadding())
        .frame(maxWidth: .infinity, minHeight: CommandCenterLayout.phoneHeroMinHeight(), alignment: .leading)
        .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: CommandCenterLayout.phoneHeroCorner(), style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: CommandCenterLayout.phoneHeroCorner(), style: .continuous))
    }
}

struct PhoneCommandGlanceCard: View {
    @EnvironmentObject private var store: HeartbeatStore
    let card: SectionSummary
    let action: () -> Void

    private var painted: SectionSummary {
        CommandCenterLayout.paintedCard(card, store: store)
    }

    var body: some View {
        PhoneScorecardRow(
            title: CommandCenterLayout.glanceTitle(painted.section),
            subtitle: painted.storeCount > 0 ? "\(painted.storeCount) stores" : nil,
            chips: [
                PhoneMetricChip(
                    label: "Result",
                    value: CommandCenterLayout.compactValue(painted),
                    health: CommandCenterLayout.displayedHealth(painted)
                ),
            ],
            health: CommandCenterLayout.displayedHealth(painted),
            onTap: action
        )
        .frame(minHeight: CommandCenterLayout.phoneGlanceMinHeight())
    }
}

/// iPad leftover-fill briefing. Mac scrolls readable tiles. Phone uses PhoneCommandCenterHome.
struct CommandCenterHome: View {
    @EnvironmentObject private var store: HeartbeatStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    var open: (MetricSection) -> Void

    private var phone: Bool { HubLayout.isPhone(sizeClass) }

    var body: some View {
        let _ = store.seatPaintStamp
        let _ = store.filters.summary
        let heroes = heroCards
        let glances = glanceCards
        if phone, PulseLaunch.shouldUsePhoneNativeCommandCenter() {
            PhoneCommandCenterHome(open: open)
        } else if HubLayout.isMac, !PulseLaunch.shouldFillMacViewport() {
            macScrollingHome(heroes: heroes, glances: glances)
        } else {
            padLeftoverHome(heroes: heroes, glances: glances)
        }
    }

    /// MUST K: intrinsic MUST M tiles + ScrollView. `overflows()` decides bounce.
    /// Do not lock height to `geo.size.height` or leftover-fill Prep off-screen.
    private func macScrollingHome(heroes: [SectionSummary], glances: [SectionSummary]) -> some View {
        GeometryReader { geo in
            let _ = store.seatPaintStamp
            let portrait = geo.size.height > geo.size.width
            let cards = PulseLaunch.shouldSampleCommandCenterCardsInsideGeometryReaderOnly()
                ? glanceCards
                : glances
            let cols = CommandCenterLayout.glanceColumns(width: geo.size.width, phone: false, portrait: portrait)
            let fit = CommandCenterLayout.macCommandCenterFit(
                availableHeight: geo.size.height,
                glanceCards: max(cards.count, 1),
                glanceColumns: cols,
                portrait: portrait
            )
            let overflow = MacCommandCenterFit.overflows(
                availableHeight: geo.size.height,
                usedHeight: fit.usedHeight
            )
            ScrollView {
                VStack(spacing: CommandCenterLayout.gutter) {
                    heroBand(height: fit.heroHeight, portrait: portrait, width: geo.size.width, heroes: heroes)
                    glanceHeader
                    glanceGrid(cards: cards, columns: cols, tileHeight: fit.glanceTileHeight)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, fit.pad)
                .frame(width: geo.size.width, alignment: .top)
            }
            // Viewport is the window. Content stays intrinsic — do not leftover-fill.
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .scrollIndicators(
                PulseLaunch.shouldToggleMacScrollIndicatorsFromFit() && overflow
                    ? .visible
                    : .hidden
            )
            .scrollBounceBehavior(
                PulseLaunch.shouldOfferPullToRefreshSeatPack() ? .always : .basedOnSize
            )
            .hubSeatPackRefreshable()
        }
    }

    private func padLeftoverHome(heroes: [SectionSummary], glances: [SectionSummary]) -> some View {
        GeometryReader { geo in
            let _ = store.seatPaintStamp
            let portrait = geo.size.height > geo.size.width
            let cards = PulseLaunch.shouldSampleCommandCenterCardsInsideGeometryReaderOnly()
                ? glanceCards
                : glances
            let cols = CommandCenterLayout.glanceColumns(width: geo.size.width, phone: phone, portrait: portrait)
            let heroH = CommandCenterLayout.heroBandHeight(
                phone: phone,
                portrait: portrait,
                available: geo.size.height,
                mac: false
            )
            let header: CGFloat = 20
            let pad: CGFloat = 12
            let leftover = max(
                CommandCenterLayout.leftoverGlanceFloor(mac: false),
                geo.size.height - heroH - header - pad - CommandCenterLayout.gutter
            )
            let tileH = CommandCenterLayout.glanceTileHeight(
                remaining: leftover,
                cards: max(cards.count, 1),
                columns: cols
            )
            let fitted = VStack(spacing: CommandCenterLayout.gutter) {
                heroBand(height: heroH, portrait: portrait, width: geo.size.width, heroes: heroes)
                glanceHeader
                glanceGrid(cards: cards, columns: cols, tileHeight: tileH)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            if PulseLaunch.shouldOfferPullToRefreshSeatPack() {
                ScrollView {
                    fitted
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.always)
                .hubSeatPackRefreshable()
            } else {
                fitted
            }
        }
    }

    private var heroCards: [SectionSummary] {
        _ = store.seatPaintStamp
        return CommandCenterLayout.heroSections.map { store.summary(for: $0) }
    }

    private var glanceCards: [SectionSummary] {
        _ = store.seatPaintStamp
        return CommandCenterLayout.glanceSections.map { store.summary(for: $0) }
    }

    private func heroBand(
        height: CGFloat,
        portrait: Bool,
        width: CGFloat,
        heroes: [SectionSummary]
    ) -> some View {
        let cols = CommandCenterLayout.heroColumns(width: width, phone: phone, portrait: portrait)
        let rows = CommandCenterLayout.rowCount(cards: heroes.count, columns: cols)
        let tile = max(
            96,
            (height - CommandCenterLayout.gutter * CGFloat(max(rows - 1, 0))) / CGFloat(rows)
        )
        return LazyVGrid(
            columns: HubLayout.grid(cols, spacing: CommandCenterLayout.gutter, minWidth: 64),
            spacing: CommandCenterLayout.gutter
        ) {
            ForEach(heroes) { card in
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
                .font(AppTheme.rounded(HubLayout.MacReadable.enabled ? .subheadline : .caption2, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(AppTheme.textTertiary)
            Spacer(minLength: 0)
        }
        .frame(height: phone ? 14 : (HubLayout.MacReadable.enabled ? 28 : 16))
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
                .frame(
                    minHeight: tileHeight,
                    maxHeight: HubLayout.isMac && !PulseLaunch.shouldFillMacViewport()
                        ? nil
                        : .infinity
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: HubLayout.isMac && !PulseLaunch.shouldFillMacViewport()
                ? nil
                : .infinity,
            alignment: .top
        )
    }
}

struct CommandCenterHeroTile: View {
    @EnvironmentObject private var store: HeartbeatStore
    let card: SectionSummary
    let action: () -> Void

    private var painted: SectionSummary {
        CommandCenterLayout.paintedCard(card, store: store)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(CommandCenterLayout.glanceTitle(painted.section))
                        .font(AppTheme.rounded(HubLayout.MacReadable.enabled ? .title2 : .title3, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    HealthBadge(health: CommandCenterLayout.displayedHealth(painted), prominent: true, compact: false)
                }
                Text(CommandCenterLayout.compactValue(painted))
                    .font(AppTheme.rounded(size: HubLayout.MacReadable.enabled ? HubLayout.MacReadable.heroValue : 28, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.gold)
                        .frame(width: 7, height: 7)
                    Text("Stores \(painted.storeCount)")
                        .font(AppTheme.rounded(HubLayout.MacReadable.enabled ? .subheadline : .caption, weight: .bold).monospacedDigit())
                        .foregroundStyle(AppTheme.gold)
                    Spacer(minLength: 0)
                }
            }
            .padding(HubLayout.MacReadable.enabled ? 16 : 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(CommandCenterLayout.glanceTitle(painted.section)), \(CommandCenterLayout.compactValue(painted)), \(CommandCenterLayout.displayedHealth(painted).label), Stores \(painted.storeCount)")
    }
}

struct CommandCenterGlanceTile: View {
    @EnvironmentObject private var store: HeartbeatStore
    let card: SectionSummary
    let action: () -> Void

    private var painted: SectionSummary {
        CommandCenterLayout.paintedCard(card, store: store)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 6) {
                    Text(CommandCenterLayout.glanceTitle(painted.section))
                        .font(AppTheme.rounded(HubLayout.MacReadable.enabled ? .title3 : .headline, weight: .heavy))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 4)
                    HealthBadge(health: CommandCenterLayout.displayedHealth(painted), compact: false)
                }
                .padding(.horizontal, HubLayout.MacReadable.enabled ? 12 : 10)
                .padding(.vertical, HubLayout.MacReadable.enabled ? 10 : 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.blue)

                VStack(spacing: 6) {
                    Text(CommandCenterLayout.compactValue(painted))
                        .font(AppTheme.rounded(size: HubLayout.MacReadable.enabled ? HubLayout.MacReadable.glanceValue : 26, weight: .bold).monospacedDigit())
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    CommandCenterGlanceIcon(
                        section: painted.section,
                        health: CommandCenterLayout.displayedHealth(painted)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(CommandCenterLayout.glanceTitle(painted.section)), \(CommandCenterLayout.compactValue(painted)), \(CommandCenterLayout.displayedHealth(painted).label)")
    }
}

struct CommandCenterGlanceIcon: View {
    let section: MetricSection
    let health: Health

    var body: some View {
        GeometryReader { geo in
            let side = min(max(22, min(geo.size.width * 0.38, geo.size.height * 0.82)), 40)
            Image(systemName: CommandCenterLayout.glanceSymbol(section))
                .font(.system(size: side, weight: .semibold))
                .foregroundStyle(AppTheme.healthInk(health))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .accessibilityHidden(true)
    }
}

struct CommandCenterAlertsRail: View {
    @EnvironmentObject private var store: HeartbeatStore
    var open: (MetricSection) -> Void = { _ in }

    private var cards: [SectionSummary] {
        _ = store.seatPaintStamp
        return CommandCenterLayout.alertRank(MetricSection.dashboardCards.map { store.summary(for: $0) })
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

/// Scorecard chrome from the same pack card the Command Center tile used.
struct CommandCenterSectionHero: View {
    let card: SectionSummary
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var phone: Bool { HubLayout.isPhone(sizeClass) }

    var body: some View {
        VStack(alignment: .leading, spacing: phone ? 4 : 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(CommandCenterLayout.glanceTitle(card.section))
                    .font(AppTheme.rounded(phone ? .subheadline : .headline, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.92))
                Spacer(minLength: 8)
                HealthBadge(health: CommandCenterLayout.displayedHealth(card), prominent: true, compact: true)
            }
            Text(CommandCenterLayout.compactValue(card))
                .font(AppTheme.rounded(size: phone ? 26 : 34, weight: .bold).monospacedDigit())
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
            HStack(spacing: 6) {
                Circle()
                    .fill(AppTheme.gold)
                    .frame(width: 7, height: 7)
                Text("Stores \(card.storeCount)")
                    .font(AppTheme.rounded(phone ? .caption : .subheadline, weight: .bold).monospacedDigit())
                    .foregroundStyle(AppTheme.gold)
                Spacer(minLength: 0)
            }
        }
        .padding(phone ? 10 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: phone ? 12 : 14, style: .continuous))
        .accessibilityLabel("\(CommandCenterLayout.glanceTitle(card.section)), \(CommandCenterLayout.compactValue(card)), \(CommandCenterLayout.displayedHealth(card).label), Stores \(card.storeCount)")
    }
}

struct CommandCenterStatusPills: View {
    let card: SectionSummary
    let flags: [HeartbeatMath.FiveStarFlag]

    var body: some View {
        let pills = CommandCenterLayout.sectionPills(card: card, flags: flags)
        if !pills.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(pills, id: \.name) { pill in
                        HStack(spacing: 6) {
                            Text(pill.name)
                                .font(AppTheme.rounded(.caption2, weight: .bold))
                            Text(pill.value)
                                .font(AppTheme.rounded(.caption, weight: .bold).monospacedDigit())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .foregroundStyle(AppTheme.healthInk(pill.health == .none ? .none : pill.health))
                        .background(AppTheme.healthWash(pill.health), in: Capsule(style: .continuous))
                    }
                }
            }
        }
    }
}
