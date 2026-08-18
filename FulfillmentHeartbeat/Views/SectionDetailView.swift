import SwiftUI

struct SectionDetailView: View {
    @EnvironmentObject private var store: HeartbeatStore
    let section: MetricSection

    private var summary: SectionSummary { store.summary(for: section) }
    private var snapshots: [MetricRow] { store.displayRows(for: section) }
    private var missingInFile: Bool {
        store.latest(for: section).isEmpty && !store.marketStores().isEmpty
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title)
                            .font(.largeTitle.weight(.semibold))
                        Text(section.blurb)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    FilterBar()

                    if missingInFile {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(AppTheme.blue)
                            Text("\(store.filters.division.isEmpty ? "This filter" : store.filters.division) isn’t in the \(section.short) workbook. Stores below come from PPH so the same division still shows across the app.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous))
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                        if section == .pph {
                            pphStatusTiles
                        } else if section == .pickPath {
                            pickPathStatusTiles
                        } else {
                            HubCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(summary.headlineLabel)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(AppTheme.textSecondary)
                                    HStack(alignment: .bottom) {
                                        Text(summary.headlineText)
                                            .font(.system(size: 32, weight: .semibold).monospacedDigit())
                                        Spacer()
                                        HealthBadge(health: summary.health)
                                    }
                                }
                            }
                            ForEach(tiles, id: \.label) { tile in
                                KpiTile(label: tile.label, value: tile.value)
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 20, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }

            StoreTable(section: section, rows: snapshots)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg.ignoresSafeArea())
        .environment(\.defaultMinListRowHeight, 1)
    }

    private var tiles: [(label: String, value: String)] {
        let rows = snapshots
        func avg(_ key: String) -> Double? {
            HeartbeatMath.average(rows.compactMap { $0.number(key) })
        }
        switch section {
        case .fiveStar:
            return [
                ("On-time promise", HeartbeatFormat.pct(avg("otp_pct"))),
                ("Fill rate", HeartbeatFormat.pct(avg("fill_rate_pct"))),
                ("Quality", HeartbeatFormat.pct(avg("quality_score"))),
            ]
        case .pickPath:
            return [
                ("Compliant picks", HeartbeatFormat.num(rows.reduce(0) { $0 + ($1.number("picks_compliant") ?? 0) })),
                ("Total picks", HeartbeatFormat.num(rows.reduce(0) { $0 + ($1.number("picks_total") ?? 0) })),
                ("Exceptions", HeartbeatFormat.num(rows.reduce(0) { $0 + ($1.number("exception_count") ?? 0) })),
            ]
        case .prepNotReady:
            return [
                ("Not ready", HeartbeatFormat.num(rows.reduce(0) { $0 + ($1.number("pnr_count") ?? 0) })),
                ("Orders due", HeartbeatFormat.num(rows.reduce(0) { $0 + ($1.number("orders_due") ?? 0) })),
                ("Avg late", "\(HeartbeatFormat.num(avg("avg_late_min"), digits: 1)) min"),
            ]
        case .dynacap:
            let aligned = rows.filter { HeartbeatMath.dynacapAligned($0) == true }.count
            return [
                ("Aligned stores", HeartbeatFormat.num(Double(aligned))),
                ("Pickup util", HeartbeatFormat.pct(avg("pickup_util_pct"))),
                ("Delivery util", HeartbeatFormat.pct(avg("delivery_util_pct"))),
            ]
        case .scheduleQuality:
            return [
                ("Efficiency", HeartbeatFormat.pct(avg("schedule_efficiency_pct"))),
                ("Over scheduled", HeartbeatFormat.num(rows.reduce(0) { $0 + ($1.number("over_scheduled") ?? 0) })),
                ("Under scheduled", HeartbeatFormat.num(rows.reduce(0) { $0 + ($1.number("under_scheduled") ?? 0) })),
            ]
        case .pph:
            let atGoal = rows.filter { ($0.number("pph") ?? 0) >= HeartbeatMath.pphGoal }.count
            let atRisk = rows.filter { ($0.number("pph") ?? .greatestFiniteMagnitude) < HeartbeatMath.pphRisk }.count
            let week = rows.compactMap(\.recordedOn).sorted().last
            return [
                ("Goal", "80.0"),
                ("At goal", HeartbeatFormat.num(Double(atGoal))),
                ("Below 74", HeartbeatFormat.num(Double(atRisk))),
                ("Week", week ?? "—"),
            ]
        case .pickerScorecard:
            let board = HeartbeatMath.pickerBoard(rows)
            return [
                ("Shoppers", HeartbeatFormat.num(Double(rows.count))),
                ("Opportunity", HeartbeatFormat.num(Double(board.opportunity.count))),
                ("Doing well", HeartbeatFormat.num(Double(board.strong.count))),
            ]
        }
    }

    @ViewBuilder
    private var pphStatusTiles: some View {
        let rows = snapshots
        let atGoal = rows.filter { ($0.number("pph") ?? 0) >= HeartbeatMath.pphGoal }.count
        let atRisk = rows.filter { ($0.number("pph") ?? .greatestFiniteMagnitude) < HeartbeatMath.pphRisk }.count
        let week = rows.compactMap(\.recordedOn).sorted().last ?? "—"
        KpiTile(label: "Avg pure PPH", value: summary.headlineText, hint: summary.health.label, tone: tone(for: summary.health))
        KpiTile(label: "Goal", value: "80.0", tone: .brand)
        KpiTile(label: "At goal", value: HeartbeatFormat.num(Double(atGoal)), tone: .good)
        KpiTile(label: "Below 74", value: HeartbeatFormat.num(Double(atRisk)), tone: .risk)
        KpiTile(label: "Week", value: week)
    }

    @ViewBuilder
    private var pickPathStatusTiles: some View {
        let rows = snapshots
        let atGoal = rows.filter { ($0.number("compliance_pct") ?? 0) >= HeartbeatMath.pickPathGoal }.count
        let atRisk = rows.filter { ($0.number("compliance_pct") ?? .greatestFiniteMagnitude) < HeartbeatMath.pickPathRisk }.count
        let orders = rows.reduce(0) { $0 + ($1.number("orders") ?? $1.number("picks_total") ?? 0) }
        let week = rows.compactMap(\.recordedOn).sorted().last ?? "—"
        KpiTile(label: "Avg compliance", value: summary.headlineText, hint: summary.health.label, tone: tone(for: summary.health))
        KpiTile(label: "Goal", value: "90%", tone: .brand)
        KpiTile(label: "At goal", value: HeartbeatFormat.num(Double(atGoal)), tone: .good)
        KpiTile(label: "Below 80%", value: HeartbeatFormat.num(Double(atRisk)), tone: .risk)
        KpiTile(label: "Orders", value: HeartbeatFormat.num(orders))
        KpiTile(label: "Week", value: week)
    }

    private func tone(for health: Health) -> KpiTile.Tone {
        switch health {
        case .good: return .good
        case .watch: return .watch
        case .risk: return .risk
        case .none: return .plain
        }
    }
}

#Preview {
    SectionDetailView(section: .fiveStar)
        .environmentObject(HeartbeatStore())
        .environmentObject(HubRouter())
}
