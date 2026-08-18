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
    case pickerScorecard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .upload: return "Upload"
        case .fiveStar: return MetricSection.fiveStar.title
        case .pickPath: return MetricSection.pickPath.title
        case .prepNotReady: return MetricSection.prepNotReady.title
        case .dynacap: return MetricSection.dynacap.title
        case .scheduleQuality: return MetricSection.scheduleQuality.title
        case .pph: return MetricSection.pph.title
        case .pickerScorecard: return MetricSection.pickerScorecard.title
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .upload: return "square.and.arrow.up"
        case .fiveStar: return MetricSection.fiveStar.symbol
        case .pickPath: return MetricSection.pickPath.symbol
        case .prepNotReady: return MetricSection.prepNotReady.symbol
        case .dynacap: return MetricSection.dynacap.symbol
        case .scheduleQuality: return MetricSection.scheduleQuality.symbol
        case .pph: return MetricSection.pph.symbol
        case .pickerScorecard: return MetricSection.pickerScorecard.symbol
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
        case .pickerScorecard: return .pickerScorecard
        default: return nil
        }
    }

    static func from(section: MetricSection) -> HubDestination {
        switch section {
        case .fiveStar: return .fiveStar
        case .pickPath: return .pickPath
        case .prepNotReady: return .prepNotReady
        case .dynacap: return .dynacap
        case .scheduleQuality: return .scheduleQuality
        case .pph: return .pph
        case .pickerScorecard: return .pickerScorecard
        }
    }

    static var primaryTabs: [HubDestination] { [.dashboard, .upload] }
    static var metricItems: [HubDestination] { [.fiveStar, .pickPath, .prepNotReady, .dynacap, .scheduleQuality, .pph, .pickerScorecard] }
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
            Section {
                ForEach(HubDestination.primaryTabs) { item in
                    sidebarRow(item)
                }
            }
            Section("Sections") {
                ForEach(HubDestination.metricItems) { item in
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
        .safeAreaInset(edge: .top, spacing: 0) {
            Text("MARKET OPERATIONS")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(AppTheme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
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
            view(for: router.current)
        }
    }

    @ViewBuilder
    private func view(for dest: HubDestination) -> some View {
        switch dest {
        case .dashboard:
            DashboardView().hubChrome()
        case .upload:
            UploadView().hubChrome(showBack: true)
        case .fiveStar, .pickPath, .prepNotReady, .dynacap, .scheduleQuality, .pph, .pickerScorecard:
            if let section = dest.section {
                SectionDetailView(section: section).hubChrome(showBack: true)
            }
        }
    }
}

#Preview {
    MainHubView()
        .environmentObject(HeartbeatStore())
}
