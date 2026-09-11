import SwiftUI

enum HubNavSelection {
    static func lightsIcon(selected: Bool) -> Bool { selected }

    static func iconInk(selected: Bool, health: Health) -> Color {
        selected ? AppTheme.blue : AppTheme.healthInk(health)
    }

    static func iconWash(selected: Bool, health: Health) -> Color {
        selected ? AppTheme.blue.opacity(0.16) : AppTheme.healthWash(health)
    }
}

enum HubDestination: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case fiveStar
    case pickPath
    case prepNotReady
    case dynacap
    case scheduleQuality
    case pph
    case labor
    case pickerScorecard
    case sales
    case lostRevenue
    case missingItems
    case preSubOOS

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .fiveStar: return MetricSection.fiveStar.title
        case .pickPath: return MetricSection.pickPath.title
        case .prepNotReady: return MetricSection.prepNotReady.title
        case .dynacap: return MetricSection.dynacap.title
        case .scheduleQuality: return MetricSection.scheduleQuality.title
        case .pph: return MetricSection.pph.title
        case .labor: return MetricSection.labor.title
        case .pickerScorecard: return MetricSection.pickerScorecard.title
        case .sales: return MetricSection.sales.bannerTitle
        case .lostRevenue: return "Loss Revenue ScoreCard"
        case .missingItems: return MetricSection.missingItems.bannerTitle
        case .preSubOOS: return MetricSection.preSubOOS.bannerTitle
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .fiveStar: return MetricSection.fiveStar.symbol
        case .pickPath: return MetricSection.pickPath.symbol
        case .prepNotReady: return MetricSection.prepNotReady.symbol
        case .dynacap: return MetricSection.dynacap.symbol
        case .scheduleQuality: return MetricSection.scheduleQuality.symbol
        case .pph: return MetricSection.pph.symbol
        case .labor: return MetricSection.labor.symbol
        case .pickerScorecard: return MetricSection.pickerScorecard.symbol
        case .sales: return MetricSection.sales.symbol
        case .lostRevenue: return MetricSection.lostRevenue.symbol
        case .missingItems: return MetricSection.missingItems.symbol
        case .preSubOOS: return MetricSection.preSubOOS.symbol
        }
    }

    var section: MetricSection? {
        switch self {
        case .fiveStar: return .fiveStar
        case .pickPath: return .pickPath
        case .prepNotReady: return .prepNotReady
        case .dynacap: return .dynacap
        case .scheduleQuality: return .scheduleQuality
        case .pph: return .pph
        case .labor: return .labor
        case .pickerScorecard: return .pickerScorecard
        case .sales: return .sales
        case .lostRevenue: return .lostRevenue
        case .missingItems: return .missingItems
        case .preSubOOS: return .preSubOOS
        case .dashboard: return nil
        }
    }

    static func from(section: MetricSection) -> HubDestination {
        switch section {
        case .fiveStar: return .fiveStar
        case .pickPath, .pickPathPicker: return .pickPath
        case .prepNotReady: return .prepNotReady
        case .dynacap: return .dynacap
        case .scheduleQuality: return .scheduleQuality
        case .pph: return .pph
        case .labor: return .labor
        case .pickerScorecard: return .pickerScorecard
        case .sales: return .sales
        case .lostRevenue: return .lostRevenue
        case .missingItems: return .missingItems
        case .preSubOOS, .preSubOOSItem: return .preSubOOS
        case .aisleMapper: return .pickPath
        case .storeRoster: return .dashboard
        }
    }

    static var sectionItems: [HubDestination] { [.dashboard, .sales, .lostRevenue, .missingItems, .fiveStar, .preSubOOS, .pickPath, .prepNotReady, .dynacap, .scheduleQuality, .pickerScorecard, .pph, .labor] }
    static var settingsItems: [HubDestination] { [] }
    static var primaryTabs: [HubDestination] { [.dashboard] }
    static var metricItems: [HubDestination] { [.sales, .lostRevenue, .missingItems, .fiveStar, .preSubOOS, .pickPath, .prepNotReady, .dynacap, .scheduleQuality, .pickerScorecard, .pph, .labor] }
}

final class HubRouter: ObservableObject {
    @Published var destination: HubDestination
    /// Phone NavigationStack push. Dashboard stays `destination` so back works.
    @Published var pushedSection: MetricSection?
    @Published var sidebarOpen = false
    @Published var alertsOpen = false
    @Published var showCompactMenu = false
    @Published var showShare = false

    var current: HubDestination { destination }

    var activeSection: MetricSection? {
        PulseLaunch.activeScorecardSection(visible: destination, pushed: pushedSection)
    }

    init() {
        destination = .dashboard
    }

    func open(_ dest: HubDestination) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            destination = dest
            if dest == .dashboard {
                pushedSection = nil
            }
            sidebarOpen = false
            alertsOpen = false
        }
    }

    /// Pages sheet: apply the destination in the same turn as dismiss so the first tap opens.
    func openFromCompactPages(_ dest: HubDestination) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            destination = dest
            if dest == .dashboard {
                pushedSection = nil
            }
            sidebarOpen = false
            alertsOpen = false
            showCompactMenu = false
        }
    }

    func pushPhone(section: MetricSection) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            pushedSection = section
        }
    }

    func clearPushedSection() {
        guard pushedSection != nil else { return }
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            pushedSection = nil
        }
    }

    func open(section: MetricSection) {
        open(.from(section: section))
    }

    func toggleSidebar() {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            sidebarOpen.toggle()
            if sidebarOpen { alertsOpen = false }
        }
    }

    func toggleAlerts() {
        guard PulseLaunch.shouldOfferIPadCommandCenterAlertsDrawer() else {
            alertsOpen = false
            return
        }
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            alertsOpen.toggle()
            if alertsOpen { sidebarOpen = false }
        }
    }

    func closeSidebar() {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            sidebarOpen = false
        }
    }

    func closeDrawers() {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            sidebarOpen = false
            alertsOpen = false
        }
    }
}

struct MainHubView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var router = HubRouter()
    @State private var warmScorecards: [MetricSection] = []

    var body: some View {
        Group {
            if HubLayout.isMac, PulseLaunch.shouldPinMacCommandCenterRails() {
                macHub
            } else if sizeClass == .regular, !HubLayout.isPhoneDevice {
                padHub
            } else {
                detail
            }
        }
        .environmentObject(router)
        .sheet(isPresented: $router.showCompactMenu) {
            CompactNavSheet()
                .environmentObject(store)
                .environmentObject(router)
        }
        .sheet(isPresented: $router.showShare) {
            SharePulseSheet()
                .environmentObject(store)
                .environmentObject(router)
        }
        .onAppear {
            store.setVisibleDestination(router.current)
            rememberWarm(router.current)
        }
        .onChange(of: store.needsRolePick) { _, needs in
            if !needs, router.destination != .dashboard {
                router.open(.dashboard)
            }
        }
        .onChange(of: router.destination) { _, dest in
            store.setVisibleDestination(dest)
            rememberWarm(dest)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .overlay {
            ImportProgressOverlay()
        }
    }

    /// Mac Catalyst: persistent Pages rail + dense center. No Alerts column.
    private var macHub: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 220)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(AppTheme.bg.ignoresSafeArea())
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(AppTheme.cardBorder)
                        .frame(width: 1)
                }
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if PulseLaunch.shouldPinMacCommandCenterAlertsRail(), router.current == .dashboard {
                CommandCenterAlertsRail(open: { router.open(section: $0) })
                    .frame(width: 248)
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(AppTheme.cardBorder)
                            .frame(width: 1)
                    }
            }
        }
        .tint(AppTheme.blue)
    }

    /// Full-width Command Center. Pages drawer on demand. No Alerts rail.
    private var padHub: some View {
        let drawersOpen = router.sidebarOpen
        return detail
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar(removing: .sidebarToggle)
            .overlay {
                Color.black.opacity(drawersOpen ? 0.2 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(drawersOpen)
                    .onTapGesture { router.closeDrawers() }
                    .accessibilityHidden(!drawersOpen)
            }
            .overlay(alignment: .leading) {
                sidebar
                    .frame(width: 272)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(AppTheme.bg.ignoresSafeArea())
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(AppTheme.cardBorder)
                            .frame(width: 1)
                    }
                    .compositingGroup()
                    .shadow(color: .black.opacity(router.sidebarOpen ? 0.18 : 0), radius: 18, x: 6, y: 0)
                    .offset(x: router.sidebarOpen ? 0 : -280)
                    .allowsHitTesting(router.sidebarOpen)
                    .accessibilityHidden(!router.sidebarOpen)
            }
            .overlay(alignment: .trailing) {
                if PulseLaunch.shouldOfferIPadCommandCenterAlertsDrawer() {
                    CommandCenterAlertsRail(open: { router.open(section: $0) })
                        .frame(width: 280)
                        .frame(maxHeight: .infinity)
                        .background(AppTheme.bg.ignoresSafeArea())
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(AppTheme.cardBorder)
                                .frame(width: 1)
                        }
                        .compositingGroup()
                        .shadow(color: .black.opacity(router.alertsOpen ? 0.18 : 0), radius: 18, x: -6, y: 0)
                        .offset(x: router.alertsOpen ? 0 : 300)
                        .allowsHitTesting(router.alertsOpen)
                        .accessibilityHidden(!router.alertsOpen)
                }
            }
            .tint(AppTheme.blue)
    }

    private var sidebar: some View {
        List {
            Section("Sections") {
                ForEach(HubDestination.sectionItems) { item in
                    sidebarRow(item)
                }
            }
            if !HubDestination.settingsItems.isEmpty {
                Section("Settings") {
                    ForEach(HubDestination.settingsItems) { item in
                        sidebarRow(item)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbarBackground(AppTheme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HubNavLogo()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Text(BuildStamp.label)
                .font(.caption2.weight(.semibold).monospaced())
                .foregroundStyle(AppTheme.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(AppTheme.card, in: Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .padding(.top, 8)
                .frame(maxWidth: .infinity)
                .background(AppTheme.bg)
                .accessibilityLabel("Build \(BuildStamp.label)")
        }
    }

    private func sidebarRow(_ item: HubDestination) -> some View {
        let health = navHealth(for: item)
        let selected = router.destination == item
        let iconInk = HubNavSelection.iconInk(selected: selected, health: health)
        let iconWash = HubNavSelection.iconWash(selected: selected, health: health)
        return Button {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                router.open(item)
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconWash)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(iconInk.opacity(selected ? 0.45 : 0.18), lineWidth: selected ? 1.5 : 1)
                    Image(systemName: item.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(iconInk)
                }
                .frame(width: 28, height: 28)
                Text(item.title)
                    .font(.body.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? AppTheme.blue : AppTheme.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? AppTheme.blue.opacity(0.12) : Color.clear)
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
    }

    private func navHealth(for dest: HubDestination) -> Health {
        switch dest {
        case .dashboard:
            return store.summaries.map(\.health).max(by: { healthRank($0) < healthRank($1) }) ?? .none
        default:
            guard let section = dest.section else { return .none }
            return store.summary(for: section).health
        }
    }

    private func healthRank(_ health: Health) -> Int {
        switch health {
        case .none: return 0
        case .good: return 1
        case .watch: return 2
        case .risk: return 3
        }
    }


    @ViewBuilder
    private var detail: some View {
        NavigationStack {
            Group {
                if PulseLaunch.shouldUsePagingScroll() {
                    ScorecardPager(router: router) { dest in
                        AnyView(
                            page(for: dest)
                                .environmentObject(store)
                                .environmentObject(router)
                        )
                    }
                    .equatable()
                } else if PulseLaunch.shouldRemountPageOnDestinationChange() {
                    page(for: router.current)
                        .id(router.current)
                } else if PulseLaunch.shouldKeepDashboardHostWarm() {
                    warmDetail
                } else {
                    page(for: router.current)
                }
            }
            .clipped()
            .animation(nil, value: router.current)
        }
        .background(AppTheme.bg)
        .hubChrome(
            showBack: PulseLaunch.shouldShowScorecardDashboardBackControl()
                && router.current != .dashboard,
            showsFilters: true
        )
    }

    /// Dashboard stays mounted. Last scorecards stay mounted so a sidebar
    /// switch is opacity, not a SectionDetailView teardown.
    @ViewBuilder
    private var warmDetail: some View {
        ZStack {
            DashboardView()
                .hubPageCanvas()
                .opacity(router.current == .dashboard ? 1 : 0)
                .allowsHitTesting(router.current == .dashboard)
                .accessibilityHidden(router.current != .dashboard)
            ForEach(
                PulseLaunch.visibleScorecardSections(
                    current: router.current,
                    warmed: warmScorecards,
                    pushed: router.pushedSection
                ),
                id: \.self
            ) { section in
                SectionDetailView(section: section)
                    .hubPageCanvas()
                    .opacity(router.current.section == section ? 1 : 0)
                    .allowsHitTesting(router.current.section == section)
                    .accessibilityHidden(router.current.section != section)
            }
        }
    }

    private func rememberWarm(_ dest: HubDestination) {
        guard PulseLaunch.shouldKeepVisitedScorecardHostsWarm() else { return }
        warmScorecards = PulseLaunch.warmScorecardList(
            existing: warmScorecards,
            incoming: dest.section
        )
    }

    @ViewBuilder
    private func page(for dest: HubDestination) -> some View {
        switch dest {
        case .dashboard:
            DashboardView().hubPageCanvas()
        case .fiveStar, .pickPath, .prepNotReady, .dynacap, .scheduleQuality, .pph, .labor, .pickerScorecard, .sales, .lostRevenue, .missingItems, .preSubOOS:
            if let section = dest.section {
                SectionDetailView(section: section).hubPageCanvas()
            }
        }
    }
}

private struct ImportProgressOverlay: View {
    @EnvironmentObject private var store: HeartbeatStore

    var body: some View {
        if store.isImporting {
            ImportProgressCard(progress: store.importProgress)
        }
    }
}

private struct ImportProgressCard: View {
    @ObservedObject var progress: ImportProgress

    var body: some View {
        ZStack {
            Color.black.opacity(0.22).ignoresSafeArea()
            card
        }
        .allowsHitTesting(true)
    }

    private var card: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppTheme.blue)
            Text(PulseLaunch.displayLoadStatus(progress.label, tick: progress.loaded))
                .font(.headline)
                .multilineTextAlignment(.center)
            if progress.expected > 0 {
                Text("\(progress.loaded) of \(progress.expected) scorecards loaded")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
                    .multilineTextAlignment(.center)
                ProgressView(
                    value: Double(progress.loaded),
                    total: Double(max(progress.expected, 1))
                )
                .tint(AppTheme.blue)
                .padding(.horizontal, 8)
                if !progress.ready.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(progress.ready.suffix(8), id: \.self) { name in
                            Text("✓  \(name)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            }
            if progress.missing.isEmpty {
                Text("Stay in the app until every scorecard is counted.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Missing: \(progress.missing.joined(separator: ", "))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.bad)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(28)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .fill(AppTheme.card)
        )
        .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
    }
}

#Preview {
    MainHubView()
        .environmentObject(HeartbeatStore())
}

struct CompactNavSheet: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SECTIONS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textTertiary)
                        .padding(.horizontal, 4)
                    ForEach(HubDestination.sectionItems) { item in
                        navRow(item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(AppTheme.bg)
            .navigationTitle("Heartbeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { router.showCompactMenu = false }
                        .font(.body.weight(.semibold))
                        .frame(minWidth: HubLayout.phoneHitTarget, minHeight: HubLayout.phoneHitTarget)
                        .contentShape(Rectangle())
                }
            }
        }
        .presentationDetents([.large])
    }

    private func navRow(_ item: HubDestination) -> some View {
        let health = navHealth(for: item)
        let selected = router.destination == item
        let iconInk = PulseLaunch.shouldTintPhonePagesIconsWithHealth()
            ? HubNavSelection.iconInk(selected: selected, health: health)
            : (selected ? AppTheme.blue : AppTheme.text)
        let iconWash = PulseLaunch.shouldTintPhonePagesIconsWithHealth()
            ? HubNavSelection.iconWash(selected: selected, health: health)
            : AppTheme.blueSoft
        return Button {
            router.openFromCompactPages(item)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconWash)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(iconInk.opacity(selected ? 0.45 : 0.18), lineWidth: selected ? 1.5 : 1)
                    Image(systemName: item.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(iconInk)
                }
                .frame(width: 28, height: 28)
                Text(item.title)
                    .font(.body.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? AppTheme.blue : AppTheme.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: HubLayout.phoneHitTarget, alignment: .leading)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? AppTheme.blue.opacity(0.12) : Color.white)
        )
    }

    private func navHealth(for dest: HubDestination) -> Health {
        switch dest {
        case .dashboard:
            return store.summaries.map(\.health).max(by: { healthRank($0) < healthRank($1) }) ?? .none
        default:
            guard let section = dest.section else { return .none }
            return store.summary(for: section).health
        }
    }

    private func healthRank(_ health: Health) -> Int {
        switch health {
        case .none: return 0
        case .good: return 1
        case .watch: return 2
        case .risk: return 3
        }
    }
}
