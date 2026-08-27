import SwiftUI

struct ChecklistView: View {
    @EnvironmentObject private var store: HeartbeatStore

    private var openCount: Int { store.checklistOpenCount }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                HubBanner(
                    icon: HubDestination.checklist.symbol,
                    title: "Operational Heartbeat Checklist",
                    accessory: accessory
                )
                Text("Action items for at-risk and watch metrics in this filter. Work them in order.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 4)
                FulfillmentChecklistCard(showsHeader: false, startsExpanded: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.bg.ignoresSafeArea())
    }

    private var accessory: String {
        let open = openCount == 0 ? "0 open" : "\(openCount) open"
        return "\(store.filters.summary)  ·  \(open)"
    }
}
