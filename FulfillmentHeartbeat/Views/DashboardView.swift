import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var pushedSection: MetricSection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                FilterBar()
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(store.summaries) { summary in
                        SectionCard(summary: summary) {
                            if sizeClass == .regular {
                                router.open(section: summary.section)
                            } else {
                                pushedSection = summary.section
                            }
                        }
                    }
                }
                if !store.seeded {
                    HubCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No files yet")
                                .font(.headline)
                            Text("Open Upload to drop in 5 Star, pick path, prep not ready, Dynacap, and schedule quality workbooks — or load the sample market to see the pulse.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                            Button("Load sample market") {
                                store.loadSampleMarket()
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationDestination(item: $pushedSection) { section in
            SectionDetailView(section: section)
        }
        .alert("Couldn’t load", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var columns: [GridItem] {
        if sizeClass == .regular {
            return [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
            ]
        }
        return [GridItem(.flexible())]
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Market pulse")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Button {
                store.loadSampleMarket()
            } label: {
                Label(store.seeded ? "Reload sample" : "Load sample market", systemImage: "sparkles")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var subtitle: String {
        if let last = store.lastUpload {
            return "Updated \(HeartbeatFormat.relative(last.uploadedAt))"
        }
        return "Upload Excel or load a sample market"
    }
}

struct SectionCard: View {
    let summary: SectionSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text(summary.section.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.textSecondary)
                            if justUpdated {
                                Text("Just updated")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppTheme.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AppTheme.blueSoft, in: Capsule(style: .continuous))
                            }
                        }
                        Text(summary.headlineText)
                            .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(AppTheme.text)
                        Text(summary.headlineLabel)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    HealthBadge(health: summary.health)
                }
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(summary.secondary)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.text)
                        Text(metaLine)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: AppTheme.radiusS, style: .continuous))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .fill(AppTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var justUpdated: Bool {
        guard let uploadedAt = summary.lastUploadedAt else { return false }
        return Date().timeIntervalSince(uploadedAt) < 180
    }

    private var metaLine: String {
        var parts = ["\(summary.storeCount) store\(summary.storeCount == 1 ? "" : "s")"]
        if summary.riskCount > 0 {
            parts.append("\(summary.riskCount) at risk")
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    DashboardView()
        .environmentObject(HeartbeatStore())
        .environmentObject(HubRouter())
}
