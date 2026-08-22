import SwiftUI

struct ChecklistView: View {
    @EnvironmentObject private var store: HeartbeatStore

    private var openCount: Int { store.checklistOpenCount }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HubBanner(
                        icon: HubDestination.checklist.symbol,
                        title: "Operational Heartbeat Checklist",
                        accessory: accessory
                    )
                    Text("Action items for at-risk and watch metrics in this filter. Work them in order, then swipe to Diagnostic.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 4)
                    FulfillmentChecklistCard(showsHeader: false, startsExpanded: true)
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg.ignoresSafeArea())
        .environment(\.defaultMinListRowHeight, 1)
    }

    private var accessory: String {
        let open = openCount == 0 ? "0 open" : "\(openCount) open"
        return "\(store.filters.summary)  ·  \(open)"
    }
}
