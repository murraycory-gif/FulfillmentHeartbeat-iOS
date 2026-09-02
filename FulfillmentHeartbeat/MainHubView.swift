import SwiftUI

enum HubDestination: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case upload
    case fiveStar
    case pickPath
    case prepNotReady
    case dynacap
    case scheduleQuality
    case pph
    case labor
    case pickerScorecard
    case lostRevenue
    case missingItems
    case preSubOOS
    case checklist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .checklist: return "Checklist"
        case .upload: return "Upload"
        case .fiveStar: return MetricSection.fiveStar.title
        case .pickPath: return MetricSection.pickPath.title
        case .prepNotReady: return MetricSection.prepNotReady.title
        case .dynacap: return MetricSection.dynacap.title
        case .scheduleQuality: return MetricSection.scheduleQuality.title
        case .pph: return MetricSection.pph.title
        case .labor: return MetricSection.labor.title
        case .pickerScorecard: return MetricSection.pickerScorecard.title
        case .lostRevenue: return "Loss Revenue ScoreCard"
        case .missingItems: return MetricSection.missingItems.bannerTitle
        case .preSubOOS: return MetricSection.preSubOOS.bannerTitle
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .checklist: return "checklist"
        case .upload: return "square.and.arrow.up"
        case .fiveStar: return MetricSection.fiveStar.symbol
        case .pickPath: return MetricSection.pickPath.symbol
        case .prepNotReady: return MetricSection.prepNotReady.symbol
        case .dynacap: return MetricSection.dynacap.symbol
        case .scheduleQuality: return MetricSection.scheduleQuality.symbol
        case .pph: return MetricSection.pph.symbol
        case .labor: return MetricSection.labor.symbol
        case .pickerScorecard: return MetricSection.pickerScorecard.symbol
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
        case .lostRevenue: return .lostRevenue
        case .missingItems: return .missingItems
        case .preSubOOS: return .preSubOOS
        case .dashboard, .checklist, .upload: return nil
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
        case .lostRevenue: return .lostRevenue
        case .missingItems: return .missingItems
        case .preSubOOS, .preSubOOSItem: return .preSubOOS
        case .aisleMapper: return .pickPath
        }
    }

    static var sectionItems: [HubDestination] { [.dashboard, .lostRevenue, .missingItems, .fiveStar, .preSubOOS, .pickPath, .prepNotReady, .dynacap, .scheduleQuality, .pickerScorecard, .pph, .labor, .checklist] }
    static var settingsItems: [HubDestination] { [.upload] }
    static var primaryTabs: [HubDestination] { [.dashboard, .upload] }
    static var metricItems: [HubDestination] { [.lostRevenue, .missingItems, .fiveStar, .preSubOOS, .pickPath, .prepNotReady, .dynacap, .scheduleQuality, .pickerScorecard, .pph, .labor] }
}

final class HubRouter: ObservableObject {
    @Published var destination: HubDestination
    @Published private(set) var sidebarNonce = 0

    var current: HubDestination { destination }

    init() {
        destination = .upload
    }

    func open(_ dest: HubDestination) {
        destination = dest
    }

    func open(section: MetricSection) {
        destination = .from(section: section)
    }

    func toggleSidebar() {
        sidebarNonce += 1
    }
}

struct MainHubView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var router = HubRouter()
    @StateObject private var coach = CoachGuide()
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    sidebar
                        .navigationSplitViewColumnWidth(min: 240, ideal: 272, max: 320)
                } detail: {
                    detail
                }
                .navigationSplitViewStyle(.balanced)
                .tint(AppTheme.blue)
                .toolbar(removing: .sidebarToggle)
            } else {
                TabView(selection: tabSelection) {
                    NavigationStack { DashboardView() }
                        .tabItem { Label("Dashboard", systemImage: HubDestination.dashboard.symbol) }
                        .tag(HubDestination.dashboard)
                        .hubChrome(showsFilters: true)
                    NavigationStack {
                        CompactSectionList()
                    }
                    .tabItem { Label("Pages", systemImage: "rectangle.stack.fill") }
                    .tag(HubDestination.checklist)
                    .hubChrome(showsFilters: true)
                    NavigationStack { UploadView() }
                        .tabItem { Label("Upload", systemImage: HubDestination.upload.symbol) }
                        .tag(HubDestination.upload)
                        .hubChrome(showsFilters: false)
                }
            }
        }
        .environmentObject(router)
        .environmentObject(coach)
        .onAppear {
            guard !store.needsRolePick else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                coach.presentIfNeeded(for: router.current)
            }
        }
        .onChange(of: store.needsRolePick) { _, needs in
            if !needs {
                router.open(.dashboard)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    coach.presentIfNeeded(for: .dashboard)
                }
            }
        }
        .onChange(of: router.destination) { _, dest in
            guard !store.needsRolePick else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                coach.presentIfNeeded(for: dest)
            }
        }

        .onChange(of: router.sidebarNonce) { _, _ in
            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .overlay {
            if coach.active != nil, !store.isImporting, !store.needsRolePick {
                CoachOverlay(guide: coach)
            }
        }
        .overlay {
            if store.isImporting {
                ZStack {
                    Color.black.opacity(0.22).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(AppTheme.blue)
                        Text(store.importLabel ?? "Reading workbook…")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Text("The dashboard stays responsive while the file is read.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                    .frame(maxWidth: 360)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                            .fill(AppTheme.card)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
                }
                .allowsHitTesting(true)
            }
        }
    }

    private var tabSelection: Binding<HubDestination> {
        Binding(
            get: {
                if router.current == .upload { return .upload }
                if router.current == .dashboard { return .dashboard }
                return .checklist
            },
            set: { dest in
                if dest == .checklist { return }
                router.destination = dest
            }
        )
    }

    private var sidebar: some View {
        List {
            Section("Sections") {
                ForEach(HubDestination.sectionItems) { item in
                    sidebarRow(item)
                }
            }
            Section("Settings") {
                ForEach(HubDestination.settingsItems) { item in
                    sidebarRow(item)
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
        return Button {
            router.open(item)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.healthWash(health))
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.healthInk(health).opacity(0.18), lineWidth: 1)
                    Image(systemName: item.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.healthInk(health))
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
                .fill(selected ? AppTheme.healthWash(health).opacity(0.85) : Color.clear)
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
    }

    private func navHealth(for dest: HubDestination) -> Health {
        switch dest {
        case .upload:
            return .none
        case .dashboard, .checklist:
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
            if router.current == .upload {
                UploadView()
                    .id("upload-\(store.filterStamp)")
                    .hubPageCanvas()
            } else {
                ScorecardPager(router: router, filterStamp: store.filterStamp) { dest in
                    AnyView(
                        page(for: dest)
                            .environmentObject(store)
                            .environmentObject(router)
                    )
                }
                .clipped()
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .hubChrome(
            showBack: router.current != .dashboard,
            showsFilters: router.current != .upload
        )
    }

    @ViewBuilder
    private func page(for dest: HubDestination) -> some View {
        switch dest {
        case .dashboard:
            DashboardView().hubPageCanvas()
        case .checklist:
            ChecklistView().hubPageCanvas()
        case .upload:
            UploadView().hubPageCanvas()
        case .fiveStar, .pickPath, .prepNotReady, .dynacap, .scheduleQuality, .pph, .labor, .pickerScorecard, .lostRevenue, .missingItems, .preSubOOS:
            if let section = dest.section {
                SectionDetailView(section: section).hubPageCanvas()
            }
        }
    }
}

#Preview {
    MainHubView()
        .environmentObject(HeartbeatStore())
}

struct CompactSectionList: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter

    private var pages: [HubDestination] {
        HubDestination.sectionItems.filter { $0 != .dashboard }
    }

    var body: some View {
        List {
            Section("ScoreCards") {
                ForEach(pages) { dest in
                    NavigationLink {
                        compactPage(for: dest)
                    } label: {
                        Label(dest.title, systemImage: dest.symbol)
                            .foregroundStyle(AppTheme.text)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg)
        .safeAreaInset(edge: .top, spacing: 0) {
            HubStickyPageBanner(
                icon: "rectangle.stack.fill",
                title: "Pages",
                accessory: "Open any scorecard"
            )
        }
    }

    @ViewBuilder
    private func compactPage(for dest: HubDestination) -> some View {
        switch dest {
        case .checklist:
            ChecklistView().hubPageCanvas()
        case .upload:
            UploadView().hubPageCanvas()
        case .dashboard:
            DashboardView().hubPageCanvas()
        default:
            if let section = dest.section {
                SectionDetailView(section: section).hubPageCanvas()
            }
        }
    }
}
