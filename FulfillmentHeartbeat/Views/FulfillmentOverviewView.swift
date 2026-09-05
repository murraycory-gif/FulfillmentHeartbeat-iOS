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
                    OverviewMetricCard(section: section)
                }
            }
            .padding(.horizontal, compact ? 12 : 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppTheme.bg.ignoresSafeArea())
    }
}

private struct OverviewMetricCard: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    let section: MetricSection

    private var summary: SectionSummary { store.summary(for: section) }
    private var expanded: Bool { section == .sales }
    private var phone: Bool { HubLayout.isPhone(sizeClass) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if section != .sales {
                    router.open(section: section)
                }
            } label: {
                HStack(spacing: phone ? 8 : 12) {
                    Image(systemName: section.symbol)
                        .font(AppTheme.rounded(phone ? .body : .title3, weight: .semibold))
                        .frame(width: phone ? 22 : 28)
                    Text(section.overviewLead)
                        .font(AppTheme.rounded(phone ? .body : .title3, weight: .bold))
                        .lineLimit(1)
                    Text("|")
                        .font(AppTheme.rounded(phone ? .body : .title3, weight: .regular))
                        .opacity(0.45)
                    Text("Overview")
                        .font(AppTheme.rounded(phone ? .callout : .title3, weight: .semibold))
                        .opacity(0.62)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(summary.headlineText)
                        .font(AppTheme.rounded(.subheadline, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HealthBadge(health: summary.health, prominent: true, compact: true)
                    Image(systemName: expanded ? "chevron.up" : "chevron.right")
                        .font(AppTheme.rounded(.footnote, weight: .bold))
                        .opacity(0.7)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, phone ? 12 : 16)
                .padding(.vertical, phone ? 10 : 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.overviewBar)
            }
            .buttonStyle(.plain)
            if section == .sales {
                OverviewSalesBlock()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: phone ? 14 : 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: phone ? 14 : 18, style: .continuous)
                .stroke(AppTheme.overviewBar, lineWidth: 2.5)
        )
    }
}
