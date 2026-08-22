import SwiftUI

struct DiagnosticView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @State private var openPlaybook: MetricSection?
    @State private var openUnit: String?
    @State private var expanded: Set<DiagnosticGrain> = [.playbook, .region, .market]

    private var board: DiagnosticBoard { DiagnosticBoard.build(store: store) }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HubBanner(
                        icon: HubDestination.diagnostics.symbol,
                        title: "Operational Diagnostic",
                        accessory: store.filters.summary
                    )
                    Text("At-risk drivers in this filter, why they lose sales and hurt the customer, and the action set to correct them.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 4)
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }

            Section {
                playbookPanel
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
            }

            ForEach(DiagnosticGrain.rollups, id: \.self) { grain in
                Section {
                    grainPanel(grain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg.ignoresSafeArea())
        .environment(\.defaultMinListRowHeight, 1)
    }

    private var playbookPanel: some View {
        let findings = board.filterFindings
        return VStack(spacing: 0) {
            Button { toggle(.playbook) } label: {
                HubTableHeader(
                    icon: "cross.case.fill",
                    title: "At-risk playbook",
                    accessory: findings.isEmpty
                        ? "No at-risk metrics in this filter"
                        : "\(findings.count) metrics  ·  \(HeartbeatFormat.num(Double(board.riskStoreCount))) stores  ·  tap to \(expanded.contains(.playbook) ? "collapse" : "expand")",
                    expanded: expanded.contains(.playbook)
                )
            }
            .buttonStyle(.plain)

            if expanded.contains(.playbook) {
                VStack(alignment: .leading, spacing: 12) {
                    if findings.isEmpty {
                        Text("Nothing in this filter is at risk. Keep the huddle, and use Filters if you want to inspect a market.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        ForEach(findings) { finding in
                            playbookCard(finding)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.card)
            }
        }
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 2.5)
        )
    }

    private func grainPanel(_ grain: DiagnosticGrain) -> some View {
        let units = board.units(for: grain)
        let riskUnits = units.filter { $0.riskStoreCount > 0 }
        return VStack(spacing: 0) {
            Button { toggle(grain) } label: {
                HubTableHeader(
                    icon: grain.symbol,
                    title: grain.title,
                    accessory: "\(riskUnits.count) at risk  ·  \(units.count) \(grain.unitLabel)  ·  tap to \(expanded.contains(grain) ? "collapse" : "expand")",
                    expanded: expanded.contains(grain)
                )
            }
            .buttonStyle(.plain)

            if expanded.contains(grain) {
                VStack(alignment: .leading, spacing: 8) {
                    if riskUnits.isEmpty {
                        Text("No at-risk \(grain.unitLabel) in this filter.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        ForEach(Array(riskUnits.prefix(grain == .store ? 150 : riskUnits.count))) { unit in
                            unitRow(unit, grain: grain)
                        }
                        if grain == .store, riskUnits.count > 150 {
                            Text("Showing 150 of \(HeartbeatFormat.num(Double(riskUnits.count))) at-risk stores. Filter to a market or district to see the rest.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.card)
            }
        }
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 2.5)
        )
    }

    private func playbookCard(_ finding: DiagnosticFinding) -> some View {
        let play = DiagnosticPlaybook.item(for: finding.section)
        let open = openPlaybook == finding.section
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    openPlaybook = open ? nil : finding.section
                }
            } label: {
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
                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.blue)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                diagnosticCopy(play)
                Button {
                    router.open(section: finding.section)
                } label: {
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

    private func unitRow(_ unit: DiagnosticUnit, grain: DiagnosticGrain) -> some View {
        let open = openUnit == unit.id
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    openUnit = open ? nil : unit.id
                }
            } label: {
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
                            .font(.headline.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppTheme.bad)
                    }
                    Text("\(unit.riskStoreCount)")
                        .font(.headline.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppTheme.bad)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.badSoft, in: Capsule())
                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.blue)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(unit.findings) { finding in
                        let play = DiagnosticPlaybook.item(for: finding.section)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: finding.section.symbol)
                                    .foregroundStyle(AppTheme.bad)
                                Text(play.title)
                                    .font(.subheadline.weight(.bold))
                                Spacer()
                                Text(finding.valueText)
                                    .font(.subheadline.weight(.bold).monospacedDigit())
                                    .foregroundStyle(AppTheme.bad)
                            }
                            diagnosticCopy(play, compact: true)
                        }
                        .padding(10)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            Rectangle().fill(AppTheme.cardBorder).frame(height: 1)
        }
    }

    private func diagnosticCopy(_ play: DiagnosticPlaybook, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            labeledBlock("Why this loses sales", play.sales, compact: compact)
            labeledBlock("Why this hurts the customer", play.experience, compact: compact)
            VStack(alignment: .leading, spacing: 4) {
                Text("Action set")
                    .font(compact ? .caption.weight(.heavy) : .subheadline.weight(.heavy))
                    .foregroundStyle(AppTheme.blue)
                    .tracking(0.3)
                ForEach(Array(play.actions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.blue)
                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.text)
                    }
                }
            }
        }
    }

    private func labeledBlock(_ title: String, _ detail: String, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(compact ? .caption.weight(.heavy) : .subheadline.weight(.heavy))
                .foregroundStyle(AppTheme.blue)
                .tracking(0.3)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(AppTheme.text)
        }
    }

    private func toggle(_ grain: DiagnosticGrain) {
        if expanded.contains(grain) {
            expanded.remove(grain)
        } else {
            expanded.insert(grain)
        }
    }
}

private enum DiagnosticGrain: String, CaseIterable, Identifiable, Hashable {
    case playbook
    case region
    case market
    case district
    case store

    var id: String { rawValue }

    static var rollups: [DiagnosticGrain] { [.region, .market, .district, .store] }

    var title: String {
        switch self {
        case .playbook: return "At-risk playbook"
        case .region: return "Region"
        case .market: return "Markets"
        case .district: return "District"
        case .store: return "Store"
        }
    }

    var symbol: String {
        switch self {
        case .playbook: return "cross.case.fill"
        case .region: return "globe.americas.fill"
        case .market: return "map.fill"
        case .district: return "square.grid.2x2.fill"
        case .store: return "storefront.fill"
        }
    }

    var unitLabel: String {
        switch self {
        case .playbook: return "metrics"
        case .region: return "regions"
        case .market: return "markets"
        case .district: return "districts"
        case .store: return "stores"
        }
    }
}

private struct DiagnosticFinding: Identifiable {
    var section: MetricSection
    var storeCount: Int
    var valueText: String
    var id: String { section.rawValue }
}

private struct DiagnosticUnit: Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var storeCount: Int
    var riskStoreCount: Int
    var lostDollars: Double
    var findings: [DiagnosticFinding]
    var worstStores: [String]
}

private struct DiagnosticStorePulse {
    var store: HeartbeatMath.MarketStore
    var findings: [DiagnosticFinding]
    var lost: Double
}

private struct DiagnosticBoard {
    var filterFindings: [DiagnosticFinding]
    var riskStoreCount: Int
    var regions: [DiagnosticUnit]
    var markets: [DiagnosticUnit]
    var districts: [DiagnosticUnit]
    var stores: [DiagnosticUnit]

    func units(for grain: DiagnosticGrain) -> [DiagnosticUnit] {
        switch grain {
        case .playbook: return []
        case .region: return regions
        case .market: return markets
        case .district: return districts
        case .store: return stores
        }
    }

    static func build(store: HeartbeatStore) -> DiagnosticBoard {
        let roster = store.marketStores()
        var rowByStore: [MetricSection: [String: MetricRow]] = [:]
        var pickerRisk: [String: Int] = [:]
        var pickerValue: [String: String] = [:]

        for section in MetricSection.dashboardCards {
            let rows = store.displayRows(for: section)
            if section == .pickerScorecard {
                var grouped: [String: [MetricRow]] = [:]
                for row in rows { grouped[row.storeNumber, default: []].append(row) }
                for (number, shoppers) in grouped {
                    let risk = shoppers.filter { HeartbeatMath.pickerHealth($0) == .risk }.count
                    if risk > 0 {
                        pickerRisk[number] = risk
                        pickerValue[number] = "\(HeartbeatFormat.num(Double(risk))) opportunity pickers"
                    }
                }
                continue
            }
            var map: [String: MetricRow] = [:]
            for row in rows {
                if row.textPayload["lost_grain"] == "market" { continue }
                if row.textPayload["labor_grain"] == "market" { continue }
                if row.storeNumber.isEmpty { continue }
                map[row.storeNumber] = row
            }
            rowByStore[section] = map
        }

        var pulses: [DiagnosticStorePulse] = []
        pulses.reserveCapacity(roster.count)
        for unit in roster {
            var findings: [DiagnosticFinding] = []
            var lost = 0.0
            for section in MetricSection.dashboardCards {
                if section == .pickerScorecard {
                    if let count = pickerRisk[unit.storeNumber] {
                        findings.append(
                            DiagnosticFinding(
                                section: section,
                                storeCount: 1,
                                valueText: pickerValue[unit.storeNumber] ?? "\(count) pickers"
                            )
                        )
                    }
                    continue
                }
                guard let row = rowByStore[section]?[unit.storeNumber] else { continue }
                if HeartbeatMath.health(for: section, row: row) != .risk { continue }
                if section == .lostRevenue {
                    lost = row.number("lost_revenue") ?? 0
                }
                findings.append(
                    DiagnosticFinding(
                        section: section,
                        storeCount: 1,
                        valueText: callout(section, row)
                    )
                )
            }
            pulses.append(DiagnosticStorePulse(store: unit, findings: findings, lost: lost))
        }

        let atRisk = pulses.filter { !$0.findings.isEmpty }

        func rollup(
            key: (DiagnosticStorePulse) -> String,
            title: (String, [DiagnosticStorePulse]) -> String,
            subtitle: ([DiagnosticStorePulse]) -> String
        ) -> [DiagnosticUnit] {
            let grouped = Dictionary(grouping: pulses, by: key)
            return grouped.keys.sorted { lhs, rhs in
                let l = grouped[lhs] ?? []
                let r = grouped[rhs] ?? []
                let lRisk = l.filter { !$0.findings.isEmpty }.count
                let rRisk = r.filter { !$0.findings.isEmpty }.count
                if lRisk != rRisk { return lRisk > rRisk }
                let lLost = l.reduce(0) { $0 + $1.lost }
                let rLost = r.reduce(0) { $0 + $1.lost }
                return lLost > rLost
            }
            .compactMap { id -> DiagnosticUnit? in
                let group = grouped[id] ?? []
                let risk = group.filter { !$0.findings.isEmpty }
                var counts: [MetricSection: (Int, String)] = [:]
                for pulse in risk {
                    for finding in pulse.findings {
                        let current = counts[finding.section]?.0 ?? 0
                        counts[finding.section] = (current + 1, finding.valueText)
                    }
                }
                let findings = MetricSection.dashboardCards.compactMap { section -> DiagnosticFinding? in
                    guard let pair = counts[section] else { return nil }
                    return DiagnosticFinding(section: section, storeCount: pair.0, valueText: "\(HeartbeatFormat.num(Double(pair.0))) stores")
                }
                let worst = risk.sorted { lhs, rhs in
                    if lhs.findings.count != rhs.findings.count { return lhs.findings.count > rhs.findings.count }
                    return lhs.lost > rhs.lost
                }
                .prefix(6)
                .map { pulse in
                    let name = pulse.store.storeNumber
                    return name
                }
                return DiagnosticUnit(
                    id: id,
                    title: title(id, group),
                    subtitle: subtitle(group),
                    storeCount: group.count,
                    riskStoreCount: risk.count,
                    lostDollars: group.reduce(0) { $0 + $1.lost },
                    findings: findings,
                    worstStores: Array(worst)
                )
            }
        }

        let regions = rollup(
            key: { MarketRegion.containing($0.store.division)?.rawValue ?? "Unassigned region" },
            title: { id, _ in id },
            subtitle: { group in
                let risk = group.filter { !$0.findings.isEmpty }.count
                return "\(HeartbeatFormat.num(Double(risk))) of \(HeartbeatFormat.num(Double(group.count))) stores at risk"
            }
        )
        let markets = rollup(
            key: { HeartbeatMath.normalize($0.store.division).isEmpty ? "Unknown market" : $0.store.division },
            title: { id, _ in MarketRegion.canonicalName(id) },
            subtitle: { group in
                let risk = group.filter { !$0.findings.isEmpty }.count
                return "\(HeartbeatFormat.num(Double(risk))) of \(HeartbeatFormat.num(Double(group.count))) stores at risk"
            }
        )
        let districts = rollup(
            key: {
                let district = $0.store.district.trimmingCharacters(in: .whitespacesAndNewlines)
                if district.isEmpty { return "Unassigned district" }
                return district
            },
            title: { id, group in
                let market = group.first.map { MarketRegion.canonicalName($0.store.division) } ?? ""
                return market.isEmpty ? id : "\(id)  ·  \(market)"
            },
            subtitle: { group in
                let risk = group.filter { !$0.findings.isEmpty }.count
                return "\(HeartbeatFormat.num(Double(risk))) of \(HeartbeatFormat.num(Double(group.count))) stores at risk"
            }
        )
        let stores: [DiagnosticUnit] = atRisk.sorted { lhs, rhs in
            if lhs.findings.count != rhs.findings.count { return lhs.findings.count > rhs.findings.count }
            return lhs.lost > rhs.lost
        }
        .map { pulse in
            let name = pulse.store.storeNumber
            let market = MarketRegion.canonicalName(pulse.store.division)
            let district = pulse.store.district.isEmpty ? "" : " · \(pulse.store.district)"
            return DiagnosticUnit(
                id: "store-\(name)",
                title: name,
                subtitle: "\(market)\(district)  ·  \(pulse.findings.count) at-risk metrics",
                storeCount: 1,
                riskStoreCount: 1,
                lostDollars: pulse.lost,
                findings: pulse.findings,
                worstStores: []
            )
        }

        let filterFindings: [DiagnosticFinding] = MetricSection.dashboardCards.compactMap { section in
            let count = atRisk.filter { pulse in pulse.findings.contains { $0.section == section } }.count
            guard count > 0 else { return nil }
            let summary = store.summary(for: section)
            return DiagnosticFinding(section: section, storeCount: count, valueText: summary.headlineText)
        }

        return DiagnosticBoard(
            filterFindings: filterFindings,
            riskStoreCount: atRisk.count,
            regions: regions,
            markets: markets,
            districts: districts,
            stores: stores
        )
    }

    private static func callout(_ section: MetricSection, _ row: MetricRow) -> String {
        switch section {
        case .lostRevenue:
            return "\(HeartbeatFormat.money(row.number("lost_revenue")))  \(HeartbeatFormat.pct(row.number("lost_revenue_pct")))"
        case .fiveStar:
            return HeartbeatFormat.stars(row.number("star_rating"))
        case .pickPath, .pickPathPicker:
            return HeartbeatFormat.pct(row.number("compliance_pct"))
        case .prepNotReady:
            return HeartbeatFormat.pct(row.number("pnr_rate_pct"))
        case .dynacap:
            return HeartbeatFormat.num(row.number("dynacap_rate", "pieces_per_hour"), digits: 1)
        case .scheduleQuality:
            return HeartbeatFormat.pct(row.number("schedule_efficiency_pct"))
        case .pph:
            return HeartbeatFormat.num(row.number("pph"), digits: 1)
        case .labor:
            return HeartbeatFormat.pct(row.number("target_vs_actual_pct"))
        case .pickerScorecard:
            return "Opportunity pickers"
        }
    }
}

private struct DiagnosticPlaybook {
    var title: String
    var sales: String
    var experience: String
    var actions: [String]

    static func item(for section: MetricSection) -> DiagnosticPlaybook {
        switch section {
        case .lostRevenue:
            return DiagnosticPlaybook(
                title: "Loss Revenue",
                sales: "Every missed, refunded, or substituted item is eComm demand this store already had and did not keep. High lost-revenue % is sales leaking out of the same orders sister stores capture.",
                experience: "The customer does not get what they ordered. Trust drops fast — they skip the next order or leave for another banner.",
                actions: [
                    "Pull the top lost-item categories for this store and own them in the daily huddle.",
                    "Pair OOS and presub coaching with the pickers driving the leak.",
                    "Stand a 10-minute lost-revenue review until the store is back under 5%.",
                ]
            )
        case .fiveStar:
            return DiagnosticPlaybook(
                title: "5 Star Metrics",
                sales: "Ratings under 4.0 cut repeat orders and visibility in the app. Flash, presubs, OTT, and OTH5 are the path from a shop to a reorder.",
                experience: "Late, incomplete, or poorly substituted orders are how the customer feels the store. One bad shop becomes a 1-star review.",
                actions: [
                    "Attack Flash and OTT first — they move the rating fastest.",
                    "Coach presubs: only offer a true like-for-like, then confirm.",
                    "Protect OTH5 on eligible orders. Walk the lowest-rated stores this week.",
                ]
            )
        case .pickPath, .pickPathPicker:
            return DiagnosticPlaybook(
                title: "Pick Path Compliance",
                sales: "Off-path shops burn minutes. Minutes lost at peak means fewer orders leave the window and more get cancelled.",
                experience: "Wandering the store delays DUG and raises misses. The customer waits longer for a worse basket.",
                actions: [
                    "Retrain every shopper under 80% this week, on the floor, with the path map.",
                    "Managers walk two low-compliance pickers per shift.",
                    "Post path compliance at the huddle board until the store is back over 90%.",
                ]
            )
        case .prepNotReady:
            return DiagnosticPlaybook(
                title: "Prep Not Ready",
                sales: "Hours spent waiting on bakery, deli, or meat are hours not picking. Capacity drops and we start declining orders.",
                experience: "Prepared foods show up late or missing. DUG times slip and the customer notices the holes.",
                actions: [
                    "Align production to the pick wave, not the other way around.",
                    "Run a 30-minute prep-ready board for bakery, deli, and meat.",
                    "Escalate any department over 2.5% PNR the same day.",
                ]
            )
        case .dynacap:
            return DiagnosticPlaybook(
                title: "Dynacap Setting",
                sales: "A cap set too low leaves demand we could have taken. A cap set too high overloads pickers and we miss, so the next day’s cap gets cut.",
                experience: "Overloaded pickers rush, miss items, and stretch wait time. Under-capped stores turn customers away before they order.",
                actions: [
                    "Set pickup and delivery to the recommended values — no local overrides.",
                    "Review every store under 60 pieces / hour with the OM this week.",
                    "Do not lower Dynacap to hide a labor or path problem.",
                ]
            )
        case .scheduleQuality:
            return DiagnosticPlaybook(
                title: "Schedule Quality",
                sales: "Under-scheduled hours mean we cannot pick the demand sitting in the app. Over-scheduled hours are cost with no extra sales.",
                experience: "Thin coverage at peak is long waits and more misses. Extra coverage at the wrong time does not help the customer.",
                actions: [
                    "Rebuild the week wherever under or over is above 5%.",
                    "Match coverage to the demand curve, not last week’s habit.",
                    "Lock a mid-week edit so Friday and Sunday are staffed before they break.",
                ]
            )
        case .pph:
            return DiagnosticPlaybook(
                title: "PPH Pure Picks Per Hour",
                sales: "Low PPH is fewer units per labor hour, so the store cannot take the volume the app is offering.",
                experience: "Slow shops stretch wait time and push orders late. The customer feels the delay before they see the bag.",
                actions: [
                    "Fix path and staging on every store under 74 PPH.",
                    "Pull non-pick work off pickers during the wave.",
                    "Pair a strong picker with the slowest shopper for two shifts, then re-measure.",
                ]
            )
        case .labor:
            return DiagnosticPlaybook(
                title: "Labor",
                sales: "Hours above earned work are cost that does not create a sale. Hours below earned work mean we turn down demand we already paid to generate.",
                experience: "Wrong staffing is either nobody to shop the order or a rushed, incomplete shop.",
                actions: [
                    "Get Target vs Actual under 3% this week.",
                    "Use earned hours as the daily target, not scheduled hours.",
                    "Do not add hours that are not in the forecast — move them to the peak instead.",
                ]
            )
        case .pickerScorecard:
            return DiagnosticPlaybook(
                title: "Picker ScoreCard",
                sales: "Opportunity pickers drive refunds, presubs, and low PPH. That is the leak inside the store, one shopper at a time.",
                experience: "The customer feels that one shopper: wrong items, holes, slow DUG. One name can sink the store rating.",
                actions: [
                    "Coach the top 10 opportunity pickers side-by-side this week.",
                    "Keep them off peak until they hit the metric mix.",
                    "Put the strong-picker list on the huddle board and copy what they do.",
                ]
            )
        }
    }
}
