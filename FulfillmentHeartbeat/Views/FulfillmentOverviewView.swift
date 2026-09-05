import SwiftUI

struct FulfillmentOverviewView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let compact = HubLayout.isPhone(sizeClass)
        ScrollView {
            VStack(alignment: .leading, spacing: compact ? 10 : 12) {
                HubBanner(
                    icon: "square.grid.3x3.fill",
                    title: "Fulfillment Overview",
                    accessory: store.filters.summary,
                    trailing: store.sharedDataWindow()
                )
                ForEach(MetricSection.overviewCards) { section in
                    OverviewCalloutBar(
                        section: section,
                        summary: store.summary(for: section)
                    ) {
                        router.open(section: section)
                    }
                }
            }
            .padding(.horizontal, compact ? 12 : 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppTheme.bg.ignoresSafeArea())
    }
}

private struct OverviewCalloutBar: View {
    let section: MetricSection
    let summary: SectionSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: section.symbol)
                    .font(AppTheme.rounded(.title3, weight: .semibold))
                    .frame(width: 28)
                Text(section.overviewTitle)
                    .font(AppTheme.rounded(.title3, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(summary.headlineText)
                        .font(AppTheme.rounded(.subheadline, weight: .bold))
                    Text(statusLabel)
                        .font(AppTheme.rounded(.caption2, weight: .semibold))
                        .opacity(0.85)
                }
                Image(systemName: "chevron.right")
                    .font(AppTheme.rounded(.footnote, weight: .bold))
                    .opacity(0.7)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.overviewBar, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var statusLabel: String {
        if summary.storeCount == 0 { return "No data" }
        switch summary.health {
        case .risk: return "At risk"
        case .watch: return "Watch"
        case .good: return "Healthy"
        case .none: return "\(summary.storeCount) stores"
        }
    }
}
