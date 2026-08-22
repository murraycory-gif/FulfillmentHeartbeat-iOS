import SwiftUI

struct DiagnosticView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @State private var openPlaybook: MetricSection?
    @State private var openUnit: String?
    @State private var showPlaybook = true
    @State private var showRegion = true
    @State private var showMarket = true
    @State private var showDistrict = false
    @State private var showStore = false

    private var board: DiagnosticBoard {
        DiagnosticBoard.build(store: store)
    }

    var body: some View {
        List {
            Section {
                intro
                    .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.bg)
            }
            Section {
                panel(
                    icon: "cross.case.fill",
                    title: "At-risk playbook",
                    accessory: playbookAccessory,
                    expanded: showPlaybook,
                    toggle: { showPlaybook.toggle() }
                ) {
                    playbookBody
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
            Section {
                grainSection(
                    grain: .region,
                    units: board.regions,
                    expanded: showRegion,
                    toggle: { showRegion.toggle() }
                )
            }
            Section {
                grainSection(
                    grain: .market,
                    units: board.markets,
                    expanded: showMarket,
                    toggle: { showMarket.toggle() }
                )
            }
            Section {
                grainSection(
                    grain: .district,
                    units: board.districts,
                    expanded: showDistrict,
                    toggle: { showDistrict.toggle() }
                )
            }
            Section {
                grainSection(
                    grain: .store,
                    units: board.stores,
                    expanded: showStore,
                    toggle: { showStore.toggle() }
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg.ignoresSafeArea())
        .environment(\.defaultMinListRowHeight, 1)
    }

    private var intro: some View {
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
    }

    private var playbookAccessory: String {
        if board.filterFindings.isEmpty {
            return "No at-risk metrics in this filter"
        }
        return "\(board.filterFindings.count) metrics  ·  \(HeartbeatFormat.num(Double(board.riskStoreCount))) stores  ·  tap to \(showPlaybook ? "collapse" : "expand")"
    }

    @ViewBuilder
    private var playbookBody: some View {
        if board.filterFindings.isEmpty {
            Text("Nothing in this filter is at risk. Keep the huddle, and use Filters if you want to inspect a market.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        } else {
            ForEach(board.filterFindings) { finding in
                DiagnosticPlaybookCard(
                    finding: finding,
                    expanded: openPlaybook == finding.section,
                    onToggle: {
                        openPlaybook = openPlaybook == finding.section ? nil : finding.section
                    },
                    onOpen: { router.open(section: finding.section) }
                )
            }
        }
    }

    private func grainSection(
        grain: DiagnosticGrain,
        units: [DiagnosticUnit],
        expanded: Bool,
        toggle: @escaping () -> Void
    ) -> some View {
        let atRisk = units.filter { $0.riskStoreCount > 0 }
        let shown = grain == .store ? Array(atRisk.prefix(150)) : atRisk
        return panel(
            icon: grain.symbol,
            title: grain.title,
            accessory: "\(atRisk.count) at risk  ·  \(units.count) \(grain.unitLabel)  ·  tap to \(expanded ? "collapse" : "expand")",
            expanded: expanded,
            toggle: toggle
        ) {
            if atRisk.isEmpty {
                Text("No at-risk \(grain.unitLabel) in this filter.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(shown) { unit in
                    DiagnosticUnitRow(
                        unit: unit,
                        grain: grain,
                        expanded: openUnit == unit.id,
                        onToggle: {
                            openUnit = openUnit == unit.id ? nil : unit.id
                        }
                    )
                }
                if grain == .store, atRisk.count > 150 {
                    Text("Showing 150 of \(HeartbeatFormat.num(Double(atRisk.count))) at-risk stores. Filter to a market or district to see the rest.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.top, 4)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(AppTheme.bg)
    }

    private func panel<Content: View>(
        icon: String,
        title: String,
        accessory: String,
        expanded: Bool,
        toggle: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Button(action: toggle) {
                HubTableHeader(icon: icon, title: title, accessory: accessory, expanded: expanded)
            }
            .buttonStyle(.plain)
            if expanded {
                VStack(alignment: .leading, spacing: 12) {
                    content()
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
}

private struct DiagnosticPlaybookCard: View {
    let finding: DiagnosticFinding
    let expanded: Bool
    let onToggle: () -> Void
    let onOpen: () -> Void

    var body: some View {
        let play = DiagnosticPlaybook.item(for: finding.section)
        return VStack(alignment: .leading, spacing: 10) {
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
                DiagnosticCopyBlock(play: play, compact: false)
                Button("Open \(play.title)", action: onOpen)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
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

private struct DiagnosticUnitRow: View {
    let unit: DiagnosticUnit
    let grain: DiagnosticGrain
    let expanded: Bool
    let onToggle: () -> Void

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
                            .font(.headline.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppTheme.bad)
                    }
                    Text("\(unit.riskStoreCount)")
                        .font(.headline.weight(.bold).monospacedDigit())
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
            Rectangle().fill(AppTheme.cardBorder).frame(height: 1)
        }
    }
}

private struct DiagnosticFindingBlock: View {
    let finding: DiagnosticFinding

    var body: some View {
        let play = DiagnosticPlaybook.item(for: finding.section)
        return VStack(alignment: .leading, spacing: 6) {
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
            DiagnosticCopyBlock(play: play, compact: true)
        }
        .padding(10)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct DiagnosticCopyBlock: View {
    let play: DiagnosticPlaybook
    var compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            labeled("Why this loses sales", play.sales)
            labeled("Why this hurts the customer", play.experience)
            VStack(alignment: .leading, spacing: 4) {
                Text("Action set")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(AppTheme.blue)
                    .tracking(0.3)
                ForEach(Array(play.actions.enumerated()), id: \.offset) { pair in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(pair.offset + 1).")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.blue)
                        Text(pair.element)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.text)
                    }
                }
            }
        }
    }

    private func labeled(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(AppTheme.blue)
                .tracking(0.3)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(AppTheme.text)
        }
    }
}

private enum DiagnosticGrain: String, Hashable {
    case region, market, district, store

    var title: String {
        switch self {
        case .region: return "Region"
        case .market: return "Markets"
        case .district: return "District"
        case .store: return "Store"
        }
    }

    var symbol: String {
        switch self {
        case .region: return "globe.americas.fill"
        case .market: return "map.fill"
        case .district: return "square.grid.2x2.fill"
        case .store: return "storefront.fill"
        }
    }

    var unitLabel: String {
        switch self {
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

    static func build(store: HeartbeatStore) -> DiagnosticBoard {
        let pulses = pulses(from: store)
        let atRisk = pulses.filter { !$0.findings.isEmpty }
        return DiagnosticBoard(
            filterFindings: filterFindings(from: atRisk, store: store),
            riskStoreCount: atRisk.count,
            regions: regionUnits(pulses),
            markets: marketUnits(pulses),
            districts: districtUnits(pulses),
            stores: storeUnits(atRisk)
        )
    }

    private static func pulses(from store: HeartbeatStore) -> [DiagnosticStorePulse] {
        let roster = store.marketStores()
        var rowByStore: [MetricSection: [String: MetricRow]] = [:]
        var pickerRisk: [String: String] = [:]

        for section in MetricSection.dashboardCards {
            let rows = store.displayRows(for: section)
            if section == .pickerScorecard {
                var grouped: [String: Int] = [:]
                for row in rows where HeartbeatMath.pickerHealth(row) == .risk {
                    grouped[row.storeNumber, default: 0] += 1
                }
                for (number, count) in grouped where count > 0 {
                    pickerRisk[number] = "\(HeartbeatFormat.num(Double(count))) opportunity pickers"
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

        var out: [DiagnosticStorePulse] = []
        out.reserveCapacity(roster.count)
        for unit in roster {
            var findings: [DiagnosticFinding] = []
            var lost = 0.0
            if let text = pickerRisk[unit.storeNumber] {
                findings.append(DiagnosticFinding(section: .pickerScorecard, storeCount: 1, valueText: text))
            }
            for section in MetricSection.dashboardCards where section != .pickerScorecard {
                guard let row = rowByStore[section]?[unit.storeNumber] else { continue }
                guard HeartbeatMath.health(for: section, row: row) == .risk else { continue }
                if section == .lostRevenue {
                    lost = row.number("lost_revenue") ?? 0
                }
                findings.append(
                    DiagnosticFinding(section: section, storeCount: 1, valueText: callout(section, row))
                )
            }
            out.append(DiagnosticStorePulse(store: unit, findings: findings, lost: lost))
        }
        return out
    }

    private static func filterFindings(from atRisk: [DiagnosticStorePulse], store: HeartbeatStore) -> [DiagnosticFinding] {
        var result: [DiagnosticFinding] = []
        for section in MetricSection.dashboardCards {
            let count = atRisk.filter { pulse in pulse.findings.contains { $0.section == section } }.count
            if count == 0 { continue }
            result.append(
                DiagnosticFinding(
                    section: section,
                    storeCount: count,
                    valueText: store.summary(for: section).headlineText
                )
            )
        }
        return result
    }

    private static func regionUnits(_ pulses: [DiagnosticStorePulse]) -> [DiagnosticUnit] {
        group(
            pulses,
            key: { MarketRegion.containing($0.store.division)?.rawValue ?? "Unassigned region" },
            title: { key, _ in key }
        )
    }

    private static func marketUnits(_ pulses: [DiagnosticStorePulse]) -> [DiagnosticUnit] {
        group(
            pulses,
            key: {
                HeartbeatMath.normalize($0.store.division).isEmpty ? "Unknown market" : $0.store.division
            },
            title: { key, _ in MarketRegion.canonicalName(key) }
        )
    }

    private static func districtUnits(_ pulses: [DiagnosticStorePulse]) -> [DiagnosticUnit] {
        group(
            pulses,
            key: {
                let district = $0.store.district.trimmingCharacters(in: .whitespacesAndNewlines)
                return district.isEmpty ? "Unassigned district" : district
            },
            title: { key, group in
                let market = group.first.map { MarketRegion.canonicalName($0.store.division) } ?? ""
                return market.isEmpty ? key : "\(key)  ·  \(market)"
            }
        )
    }

    private static func storeUnits(_ atRisk: [DiagnosticStorePulse]) -> [DiagnosticUnit] {
        atRisk.sorted { lhs, rhs in
            if lhs.findings.count != rhs.findings.count { return lhs.findings.count > rhs.findings.count }
            return lhs.lost > rhs.lost
        }
        .map { pulse in
            let market = MarketRegion.canonicalName(pulse.store.division)
            let district = pulse.store.district.isEmpty ? "" : " · \(pulse.store.district)"
            return DiagnosticUnit(
                id: "store-\(pulse.store.storeNumber)",
                title: pulse.store.storeNumber,
                subtitle: "\(market)\(district)  ·  \(pulse.findings.count) at-risk metrics",
                storeCount: 1,
                riskStoreCount: 1,
                lostDollars: pulse.lost,
                findings: pulse.findings,
                worstStores: []
            )
        }
    }

    private static func group(
        _ pulses: [DiagnosticStorePulse],
        key: (DiagnosticStorePulse) -> String,
        title: (String, [DiagnosticStorePulse]) -> String
    ) -> [DiagnosticUnit] {
        var buckets: [String: [DiagnosticStorePulse]] = [:]
        for pulse in pulses {
            buckets[key(pulse), default: []].append(pulse)
        }
        var units: [DiagnosticUnit] = []
        for (id, group) in buckets {
            let risk = group.filter { !$0.findings.isEmpty }
            var counts: [MetricSection: Int] = [:]
            for pulse in risk {
                for finding in pulse.findings {
                    counts[finding.section, default: 0] += 1
                }
            }
            var findings: [DiagnosticFinding] = []
            for section in MetricSection.dashboardCards {
                if let count = counts[section], count > 0 {
                    findings.append(
                        DiagnosticFinding(
                            section: section,
                            storeCount: count,
                            valueText: "\(HeartbeatFormat.num(Double(count))) stores"
                        )
                    )
                }
            }
            let worst = risk.sorted { lhs, rhs in
                if lhs.findings.count != rhs.findings.count { return lhs.findings.count > rhs.findings.count }
                return lhs.lost > rhs.lost
            }
            .prefix(6)
            .map(\.store.storeNumber)
            units.append(
                DiagnosticUnit(
                    id: id,
                    title: title(id, group),
                    subtitle: "\(HeartbeatFormat.num(Double(risk.count))) of \(HeartbeatFormat.num(Double(group.count))) stores at risk",
                    storeCount: group.count,
                    riskStoreCount: risk.count,
                    lostDollars: group.reduce(0) { $0 + $1.lost },
                    findings: findings,
                    worstStores: Array(worst)
                )
            )
        }
        units.sort { lhs, rhs in
            if lhs.riskStoreCount != rhs.riskStoreCount { return lhs.riskStoreCount > rhs.riskStoreCount }
            return lhs.lostDollars > rhs.lostDollars
        }
        return units
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
                sales: "A cap set too low leaves demand we could have taken. A cap set too high overloads pickers and we miss, so the next day's cap gets cut.",
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
                    "Match coverage to the demand curve, not last week's habit.",
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
