import Foundation

enum DiagnosticGrain: String {
    case region
    case market
    case district
    case store

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

struct DiagnosticFinding: Identifiable {
    var section: MetricSection
    var storeCount: Int
    var valueText: String
    var id: String { section.rawValue }
}

struct DiagnosticUnit: Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var storeCount: Int
    var riskStoreCount: Int
    var lostDollars: Double
    var findings: [DiagnosticFinding]
    var worstStores: [String]
}

struct DiagnosticPlaybook {
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

struct DiagnosticPulse {
    var storeNumber: String
    var division: String
    var district: String
    var findings: [DiagnosticFinding]
    var lost: Double
}

@MainActor
enum DiagnosticBoard {
    static func build(store: HeartbeatStore) -> DiagnosticSnapshot {
        let pulses = makePulses(store)
        var atRisk: [DiagnosticPulse] = []
        for pulse in pulses {
            if !pulse.findings.isEmpty {
                atRisk.append(pulse)
            }
        }
        return DiagnosticSnapshot(
            filterFindings: makeFilterFindings(atRisk, store: store),
            riskStoreCount: atRisk.count,
            regions: rollup(pulses, by: .region),
            markets: rollup(pulses, by: .market),
            districts: rollup(pulses, by: .district),
            stores: makeStores(atRisk)
        )
    }

    private static func makePulses(_ store: HeartbeatStore) -> [DiagnosticPulse] {
        let roster = store.marketStores()
        var rowByStore: [MetricSection: [String: MetricRow]] = [:]
        var pickerRisk: [String: String] = [:]

        let sections = MetricSection.dashboardCards
        for i in 0..<sections.count {
            let section = sections[i]
            let rows = store.displayRows(for: section)
            if section == .pickerScorecard {
                var grouped: [String: Int] = [:]
                for row in rows {
                    if HeartbeatMath.pickerHealth(row) == .risk {
                        let current = grouped[row.storeNumber] ?? 0
                        grouped[row.storeNumber] = current + 1
                    }
                }
                for (number, count) in grouped {
                    if count > 0 {
                        pickerRisk[number] = "\(HeartbeatFormat.num(Double(count))) opportunity pickers"
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

        var out: [DiagnosticPulse] = []
        for unit in roster {
            var findings: [DiagnosticFinding] = []
            var lost = 0.0
            if let text = pickerRisk[unit.storeNumber] {
                findings.append(DiagnosticFinding(section: .pickerScorecard, storeCount: 1, valueText: text))
            }
            for i in 0..<sections.count {
                let section = sections[i]
                if section == .pickerScorecard { continue }
                guard let rows = rowByStore[section], let row = rows[unit.storeNumber] else { continue }
                if HeartbeatMath.health(for: section, row: row) != .risk { continue }
                if section == .lostRevenue {
                    lost = row.number("lost_revenue") ?? 0
                }
                findings.append(DiagnosticFinding(section: section, storeCount: 1, valueText: callout(section, row)))
            }
            out.append(
                DiagnosticPulse(
                    storeNumber: unit.storeNumber,
                    division: unit.division,
                    district: unit.district,
                    findings: findings,
                    lost: lost
                )
            )
        }
        return out
    }

    private static func makeFilterFindings(_ atRisk: [DiagnosticPulse], store: HeartbeatStore) -> [DiagnosticFinding] {
        var result: [DiagnosticFinding] = []
        let sections = MetricSection.dashboardCards
        for i in 0..<sections.count {
            let section = sections[i]
            var count = 0
            for pulse in atRisk {
                var hit = false
                for finding in pulse.findings {
                    if finding.section == section {
                        hit = true
                        break
                    }
                }
                if hit { count += 1 }
            }
            if count == 0 { continue }
            let summary = store.summary(for: section)
            result.append(
                DiagnosticFinding(section: section, storeCount: count, valueText: summary.headlineText)
            )
        }
        return result
    }

    private static func rollup(_ pulses: [DiagnosticPulse], by grain: DiagnosticGrain) -> [DiagnosticUnit] {
        var buckets: [String: [DiagnosticPulse]] = [:]
        for pulse in pulses {
            let id = bucketKey(pulse, grain: grain)
            var list = buckets[id] ?? []
            list.append(pulse)
            buckets[id] = list
        }
        var units: [DiagnosticUnit] = []
        for (id, list) in buckets {
            var risk: [DiagnosticPulse] = []
            for pulse in list {
                if !pulse.findings.isEmpty {
                    risk.append(pulse)
                }
            }
            var counts: [MetricSection: Int] = [:]
            for pulse in risk {
                for finding in pulse.findings {
                    let current = counts[finding.section] ?? 0
                    counts[finding.section] = current + 1
                }
            }
            var findings: [DiagnosticFinding] = []
            let sections = MetricSection.dashboardCards
            for i in 0..<sections.count {
                let section = sections[i]
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
            let ranked = risk.sorted { lhs, rhs in
                if lhs.findings.count == rhs.findings.count {
                    return lhs.lost > rhs.lost
                }
                return lhs.findings.count > rhs.findings.count
            }
            var worst: [String] = []
            var n = 0
            for pulse in ranked {
                if n >= 6 { break }
                worst.append(pulse.storeNumber)
                n += 1
            }
            var lost = 0.0
            for pulse in list {
                lost += pulse.lost
            }
            units.append(
                DiagnosticUnit(
                    id: id,
                    title: bucketTitle(id, list: list, grain: grain),
                    subtitle: "\(HeartbeatFormat.num(Double(risk.count))) of \(HeartbeatFormat.num(Double(list.count))) stores at risk",
                    storeCount: list.count,
                    riskStoreCount: risk.count,
                    lostDollars: lost,
                    findings: findings,
                    worstStores: worst
                )
            )
        }
        units.sort { lhs, rhs in
            if lhs.riskStoreCount == rhs.riskStoreCount {
                return lhs.lostDollars > rhs.lostDollars
            }
            return lhs.riskStoreCount > rhs.riskStoreCount
        }
        return units
    }

    private static func bucketKey(_ pulse: DiagnosticPulse, grain: DiagnosticGrain) -> String {
        switch grain {
        case .region:
            if let region = MarketRegion.containing(pulse.division) {
                return region.rawValue
            }
            return "Unassigned region"
        case .market:
            if HeartbeatMath.normalize(pulse.division).isEmpty {
                return "Unknown market"
            }
            return pulse.division
        case .district:
            let district = pulse.district.trimmingCharacters(in: .whitespacesAndNewlines)
            if district.isEmpty {
                return "Unassigned district"
            }
            return district
        case .store:
            return pulse.storeNumber
        }
    }

    private static func bucketTitle(_ id: String, list: [DiagnosticPulse], grain: DiagnosticGrain) -> String {
        if grain == .market {
            return MarketRegion.canonicalName(id)
        }
        if grain == .district {
            let market = list.first.map { MarketRegion.canonicalName($0.division) } ?? ""
            if market.isEmpty {
                return id
            }
            return "\(id)  ·  \(market)"
        }
        return id
    }

    private static func makeStores(_ atRisk: [DiagnosticPulse]) -> [DiagnosticUnit] {
        let sorted = atRisk.sorted { lhs, rhs in
            if lhs.findings.count == rhs.findings.count {
                return lhs.lost > rhs.lost
            }
            return lhs.findings.count > rhs.findings.count
        }
        var units: [DiagnosticUnit] = []
        for pulse in sorted {
            let market = MarketRegion.canonicalName(pulse.division)
            var district = ""
            if !pulse.district.isEmpty {
                district = " · \(pulse.district)"
            }
            units.append(
                DiagnosticUnit(
                    id: "store-\(pulse.storeNumber)",
                    title: pulse.storeNumber,
                    subtitle: "\(market)\(district)  ·  \(pulse.findings.count) at-risk metrics",
                    storeCount: 1,
                    riskStoreCount: 1,
                    lostDollars: pulse.lost,
                    findings: pulse.findings,
                    worstStores: []
                )
            )
        }
        return units
    }

    private static func callout(_ section: MetricSection, _ row: MetricRow) -> String {
        switch section {
        case .lostRevenue:
            let dollars = HeartbeatFormat.money(row.number("lost_revenue"))
            let pct = HeartbeatFormat.pct(row.number("lost_revenue_pct"))
            return "\(dollars)  \(pct)"
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

struct DiagnosticSnapshot {
    var filterFindings: [DiagnosticFinding]
    var riskStoreCount: Int
    var regions: [DiagnosticUnit]
    var markets: [DiagnosticUnit]
    var districts: [DiagnosticUnit]
    var stores: [DiagnosticUnit]

    static let empty = DiagnosticSnapshot(
        filterFindings: [],
        riskStoreCount: 0,
        regions: [],
        markets: [],
        districts: [],
        stores: []
    )
}
