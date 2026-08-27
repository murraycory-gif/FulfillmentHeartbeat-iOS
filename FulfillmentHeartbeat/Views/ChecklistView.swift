import SwiftUI

struct ChecklistView: View {
    var body: some View {
        FulfillmentChecklistCard(showsHeader: false, startsExpanded: true)
            .background(AppTheme.bg.ignoresSafeArea())
    }
}
