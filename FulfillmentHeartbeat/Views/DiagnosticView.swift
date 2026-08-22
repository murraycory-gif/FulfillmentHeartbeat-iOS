import SwiftUI

struct DiagnosticView: View {
    @EnvironmentObject private var store: HeartbeatStore

    var body: some View {
        DiagnosticPage(
            board: DiagnosticBoard.build(store: store),
            filterSummary: store.filters.summary
        )
    }
}

private struct DiagnosticPage: View {
    @EnvironmentObject private var router: HubRouter
    let board: DiagnosticSnapshot
    let filterSummary: String
    @State private var openPlaybook: MetricSection?
    @State private var openUnit: String?
    @State private var showPlaybook = true
    @State private var showRegion = true
    @State private var showMarket = true
    @State private var showDistrict = false
    @State private var showStore = false

    var body: some View {
        List {
            Section {
                DiagnosticIntro(filterSummary: filterSummary)
                    .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
            }
            Section {
                playbookSection
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
            }
            grainSection(board.regions, grain: .region, expanded: $showRegion, limit: nil)
            grainSection(board.markets, grain: .market, expanded: $showMarket, limit: nil)
            grainSection(board.districts, grain: .district, expanded: $showDistrict, limit: nil)
            grainSection(board.stores, grain: .store, expanded: $showStore, limit: 150)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg.ignoresSafeArea())
        .environment(\.defaultMinListRowHeight, 1)
    }

    private var playbookSection: some View {
        DiagnosticChrome(
            icon: "cross.case.fill",
            title: "At-risk playbook",
            accessory: playbookAccessory,
            expanded: showPlaybook,
            onToggle: { showPlaybook.toggle() }
        ) {
            DiagnosticPlaybookList(
                findings: board.filterFindings,
                open: openPlaybook,
                onToggle: { section in
                    openPlaybook = openPlaybook == section ? nil : section
                },
                onOpen: { section in
                    router.open(section: section)
                }
            )
        }
    }

    private var playbookAccessory: String {
        if board.filterFindings.isEmpty {
            return "No at-risk metrics in this filter"
        }
        return "\(board.filterFindings.count) metrics  ·  \(HeartbeatFormat.num(Double(board.riskStoreCount))) stores  ·  tap to \(showPlaybook ? "collapse" : "expand")"
    }

    private func grainSection(
        _ units: [DiagnosticUnit],
        grain: DiagnosticGrain,
        expanded: Binding<Bool>,
        limit: Int?
    ) -> some View {
        let atRisk = units.filter { unit in unit.riskStoreCount > 0 }
        let shown = limit == nil ? atRisk : Array(atRisk.prefix(limit ?? atRisk.count))
        let accessory = "\(atRisk.count) at risk  ·  \(units.count) \(grain.unitLabel)  ·  tap to \(expanded.wrappedValue ? "collapse" : "expand")"
        return Section {
            DiagnosticChrome(
                icon: grain.symbol,
                title: grain.title,
                accessory: accessory,
                expanded: expanded.wrappedValue,
                onToggle: { expanded.wrappedValue.toggle() }
            ) {
                DiagnosticUnitList(
                    grain: grain,
                    units: shown,
                    total: atRisk.count,
                    limit: limit,
                    openUnit: openUnit,
                    onToggle: { id in
                        openUnit = openUnit == id ? nil : id
                    }
                )
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(AppTheme.bg)
        }
    }
}

private struct DiagnosticIntro: View {
    var filterSummary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HubBanner(
                icon: HubDestination.diagnostics.symbol,
                title: "Operational Diagnostic",
                accessory: filterSummary
            )
            Text("At-risk drivers in this filter, why they lose sales and hurt the customer, and the action set to correct them.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 4)
        }
    }
}

private struct DiagnosticChrome<Content: View>: View {
    var icon: String
    var title: String
    var accessory: String
    var expanded: Bool
    var onToggle: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HubTableHeader(icon: icon, title: title, accessory: accessory, expanded: expanded)
            }
            .buttonStyle(.plain)
            if expanded {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.tableFill)
            }
        }
        .background(AppTheme.tableFill)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 2.5)
        )
    }
}

private struct DiagnosticPlaybookList: View {
    var findings: [DiagnosticFinding]
    var open: MetricSection?
    var onToggle: (MetricSection) -> Void
    var onOpen: (MetricSection) -> Void

    var body: some View {
        if findings.isEmpty {
            Text("Nothing in this filter is at risk. Keep the huddle, and use Filters if you want to inspect a market.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        } else {
            ForEach(findings) { finding in
                DiagnosticPlaybookCard(
                    finding: finding,
                    expanded: open == finding.section,
                    onToggle: { onToggle(finding.section) },
                    onOpen: { onOpen(finding.section) }
                )
            }
        }
    }
}

private struct DiagnosticPlaybookCard: View {
    var finding: DiagnosticFinding
    var expanded: Bool
    var onToggle: () -> Void
    var onOpen: () -> Void

    private var play: DiagnosticPlaybook {
        DiagnosticPlaybook.item(for: finding.section)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: finding.section.symbol)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.bad)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(play.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        Text("\(HeartbeatFormat.num(Double(finding.storeCount))) stores  ·  \(finding.valueText)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer(minLength: 8)
                    HealthBadge(health: .risk, prominent: true, compact: true)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.blue)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                DiagnosticCopyBlock(play: play)
                Button(action: onOpen) {
                    Text("Open \(play.title)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(AppTheme.badSoft.opacity(0.55), in: RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .stroke(AppTheme.bad.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct DiagnosticUnitList: View {
    var grain: DiagnosticGrain
    var units: [DiagnosticUnit]
    var total: Int
    var limit: Int?
    var openUnit: String?
    var onToggle: (String) -> Void

    var body: some View {
        if units.isEmpty {
            Text("No at-risk \(grain.unitLabel) in this filter.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        } else {
            ForEach(units) { unit in
                DiagnosticUnitRow(
                    unit: unit,
                    grain: grain,
                    expanded: openUnit == unit.id,
                    onToggle: { onToggle(unit.id) }
                )
            }
            if grain == .store, let cap = limit, total > cap {
                Text("Showing \(cap) of \(HeartbeatFormat.num(Double(total))) at-risk stores. Filter to a market or district to see the rest.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.top, 4)
            }
        }
    }
}

private struct DiagnosticUnitRow: View {
    var unit: DiagnosticUnit
    var grain: DiagnosticGrain
    var expanded: Bool
    var onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(unit.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        Text(unit.subtitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer(minLength: 8)
                    if unit.lostDollars > 0 {
                        Text(HeartbeatFormat.moneyShort(unit.lostDollars))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(AppTheme.bad)
                    }
                    Text("\(unit.riskStoreCount)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(AppTheme.bad)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.badSoft, in: Capsule())
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.blue)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(unit.findings) { finding in
                        DiagnosticFindingBlock(finding: finding)
                    }
                    if grain != .store, !unit.worstStores.isEmpty {
                        Text("Worst stores")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(AppTheme.textTertiary)
                            .tracking(0.4)
                        Text(unit.worstStores.joined(separator: "  ·  "))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.cardBorder)
                .frame(height: 1)
        }
    }
}

private struct DiagnosticFindingBlock: View {
    var finding: DiagnosticFinding

    private var play: DiagnosticPlaybook {
        DiagnosticPlaybook.item(for: finding.section)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: finding.section.symbol)
                    .foregroundStyle(AppTheme.bad)
                Text(play.title)
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text(finding.valueText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(AppTheme.bad)
            }
            DiagnosticCopyBlock(play: play)
        }
        .padding(10)
        .background(AppTheme.tableFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct DiagnosticCopyBlock: View {
    var play: DiagnosticPlaybook

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Why this loses sales")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(AppTheme.blue)
                Text(play.sales)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.text)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Why this hurts the customer")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(AppTheme.blue)
                Text(play.experience)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.text)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Action set")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(AppTheme.blue)
                ForEach(0..<play.actions.count, id: \.self) { index in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.blue)
                        Text(play.actions[index])
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.text)
                    }
                }
            }
        }
    }
}
