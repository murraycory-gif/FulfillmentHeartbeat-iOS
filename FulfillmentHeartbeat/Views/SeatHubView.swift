import SwiftUI

/// iPhone + iPad grain-first shell. Navigate by seat, not section.
/// Mac never mounts this — `MainHubView` keeps Command Center + Pages.
struct SeatHubView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @StateObject private var router = HubRouter()

    var body: some View {
        NavigationStack {
            SeatPageView()
                .hubChrome(showBack: false, showsFilters: true)
        }
        .environmentObject(router)
        .sheet(isPresented: $router.showShare) {
            SharePulseSheet()
                .environmentObject(store)
                .environmentObject(router)
        }
        .onAppear {
            store.setVisibleDestination(.dashboard)
        }
        .onChange(of: store.needsRolePick) { _, needs in
            if !needs {
                store.setVisibleDestination(.dashboard)
            }
        }
        .overlay {
            if store.isImporting {
                ImportProgressCard(progress: store.importProgress)
            }
        }
    }
}

/// One scroll: every metric module for the current seat. Filter chips / Clear
/// still drive Company → Region → Division → District → OM → Store.
struct SeatPageView: View {
    @EnvironmentObject private var store: HeartbeatStore

    var body: some View {
        let _ = store.seatPaintStamp
        let _ = store.filters.summary
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CommandCenterLayout.phoneHomeStackSpacing()) {
                Text(PulseLaunch.seatBannerTitle(filters: store.filters))
                    .font(AppTheme.rounded(.title2, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                    .accessibilityAddTraits(.isHeader)
                ForEach(PulseLaunch.seatPageMetricSections(), id: \.self) { section in
                    PhoneSectionPage(section: section, embeddedInSeat: true)
                }
                Text(BuildStamp.label)
                    .font(.caption2.weight(.semibold).monospaced())
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.card, in: Capsule(style: .continuous))
                    .overlay(Capsule(style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
                    .padding(.top, 8)
                    .accessibilityLabel("Build \(BuildStamp.label)")
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
        .background(AppTheme.bg)
    }
}

#Preview {
    SeatHubView()
        .environmentObject(HeartbeatStore())
}
