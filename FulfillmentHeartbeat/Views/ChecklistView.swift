import SwiftUI

struct FulfillmentChecklistCard: View {
    @EnvironmentObject private var store: HeartbeatStore
    @State private var expanded = true

    private var riskCount: Int {
        store.summaries.filter { $0.health == .risk }.count
    }

    private var watchCount: Int {
        store.summaries.filter { $0.health == .watch }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if expanded {
                visibilityStrip
                ForEach(MetricSection.checklistSections) { section in
                    checklistRow(section)
                }
                sendBar
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .fill(AppTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                        .stroke(borderColor, lineWidth: riskCount > 0 ? 1.5 : 1)
                )
        )
    }

    private var borderColor: Color {
        if riskCount > 0 { return AppTheme.bad.opacity(0.45) }
        if watchCount > 0 { return AppTheme.warn.opacity(0.45) }
        return AppTheme.cardBorder
    }

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("eCommerce Fulfillment Checklist")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                        if store.checklistOpenCount > 0 {
                            Text("\(store.checklistOpenCount) open")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.bad)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppTheme.badSoft, in: Capsule(style: .continuous))
                        }
                    }
                    Text(expanded ? store.filters.summary : collapsedSummary)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.blueSoft, in: Circle())
            }
        }
        .buttonStyle(.plain)
    }

    private var collapsedSummary: String {
        var parts: [String] = []
        if riskCount > 0 { parts.append("\(riskCount) at risk") }
        if watchCount > 0 { parts.append("\(watchCount) watch") }
        if store.pickerBoard.opportunityCount > 0 {
            parts.append("\(store.pickerBoard.opportunityCount) opportunity pickers")
        }
        if parts.isEmpty { return "All KPIs healthy in this filter" }
        return parts.joined(separator: " · ")
    }

    private var visibilityStrip: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
            callout(title: "At risk", value: "\(riskCount)", tone: riskCount > 0 ? .risk : .good)
            callout(title: "Watch", value: "\(watchCount)", tone: watchCount > 0 ? .watch : .good)
            callout(title: "Opportunity pickers", value: "\(store.pickerBoard.opportunityCount)", tone: store.pickerBoard.opportunityCount > 0 ? .risk : .good)
            callout(title: "Open items", value: "\(store.checklistOpenCount)", tone: store.checklistOpenCount > 0 ? .watch : .good)
        }
    }

    private func callout(title: String, value: String, tone: KpiTile.Tone) -> some View {
        KpiTile(label: title, value: value, tone: tone)
    }

    private func checklistRow(_ section: MetricSection) -> some View {
        let summary = store.summary(for: section)
        let item = store.checklistItem(for: section)
        let drivers = store.checklistDrivers(for: section)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(section.title)
                            .font(.headline)
                        HealthBadge(health: summary.health)
                    }
                    Text("\(summary.headlineLabel): \(summary.headlineText) · \(summary.secondary)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
            }
            if !drivers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section == .pickerScorecard ? "Pickers causing it" : "Stores causing it")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                    ForEach(drivers, id: \.self) { line in
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(AppTheme.text)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(driverBackground(summary.health), in: RoundedRectangle(cornerRadius: AppTheme.radiusS, style: .continuous))
            }
            HStack(spacing: 8) {
                ForEach([ChecklistStatus.fixed, .followUp, .notCovered]) { status in
                    statusChip(status, selected: item.status == status) {
                        store.setChecklistStatus(status, for: section)
                    }
                }
            }
            TextField("Comments for follow up", text: commentBinding(section), axis: .vertical)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .lineLimit(1...4)
                .padding(10)
                .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: AppTheme.radiusS, style: .continuous))
        }
        .padding(.top, 8)
        Divider().opacity(0.35)
    }

    private func driverBackground(_ health: Health) -> Color {
        switch health {
        case .risk: return AppTheme.badSoft
        case .watch: return AppTheme.warnSoft
        default: return AppTheme.bg
        }
    }

    private func statusChip(_ status: ChecklistStatus, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(status.label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(selected ? .white : chipColor(status))
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? chipColor(status) : chipColor(status).opacity(0.14))
                )
        }
        .buttonStyle(.plain)
    }

    private func chipColor(_ status: ChecklistStatus) -> Color {
        switch status {
        case .open: return AppTheme.textTertiary
        case .fixed: return AppTheme.ok
        case .followUp: return AppTheme.warn
        case .notCovered: return AppTheme.blue
        }
    }

    private func commentBinding(_ section: MetricSection) -> Binding<String> {
        Binding(
            get: { store.checklistItem(for: section).comment },
            set: { store.setChecklistComment($0, for: section) }
        )
    }

    private var sendBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.checklistReadyToSend {
                ShareLink(
                    item: store.checklistEmailText(),
                    subject: Text(store.checklistEmailSubject()),
                    message: Text(store.checklistEmailText())
                ) {
                    Label("Email leaders", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button {} label: {
                    Label("Set a status on every KPI to email leaders", systemImage: "paperplane")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(true)
            }
        }
        .padding(.top, 4)
    }
}