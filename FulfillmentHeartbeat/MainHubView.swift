import SwiftUI

enum HubDestination: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case diagnostics
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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .diagnostics: return "Diagnostic"
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
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .diagnostics: return "stethoscope"
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
        default: return nil
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
        }
    }

    static var sectionItems: [HubDestination] { [.dashboard, .diagnostics, .lostRevenue, .fiveStar, .pickPath, .prepNotReady, .dynacap, .scheduleQuality, .pph, .labor, .pickerScorecard] }
    static var settingsItems: [HubDestination] { [.upload] }
    static var primaryTabs: [HubDestination] { [.dashboard, .upload] }
    static var metricItems: [HubDestination] { [.lostRevenue, .fiveStar, .pickPath, .prepNotReady, .dynacap, .scheduleQuality, .pph, .labor, .pickerScorecard] }
}

final class HubRouter: ObservableObject {
    @Published var destination: HubDestination = .dashboard
    @Published private(set) var sidebarNonce = 0

    var current: HubDestination { destination }

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
                    NavigationStack { UploadView() }
                        .tabItem { Label("Upload", systemImage: HubDestination.upload.symbol) }
                        .tag(HubDestination.upload)
                }
            }
        }
        .environmentObject(router)
        .onChange(of: router.destination) { _, _ in
            columnVisibility = .detailOnly
        }
        .onChange(of: router.sidebarNonce) { _, _ in
            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
        }
        .background(AppTheme.bg.ignoresSafeArea())
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
            get: { router.current == .upload ? .upload : .dashboard },
            set: { router.destination = $0 }
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
    }

    private func sidebarRow(_ item: HubDestination) -> some View {
        Button {
            router.open(item)
        } label: {
            Label(item.title, systemImage: item.symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(router.destination == item ? AppTheme.blueDeep : AppTheme.text)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(router.destination == item ? AppTheme.blueSoft : Color.clear)
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
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
        case .diagnostics:
            DiagnosticView().hubPageCanvas()
        case .upload:
            UploadView().hubPageCanvas()
        case .fiveStar, .pickPath, .prepNotReady, .dynacap, .scheduleQuality, .pph, .labor, .pickerScorecard, .lostRevenue:
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
