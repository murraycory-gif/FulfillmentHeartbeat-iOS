import Foundation

enum DiagnosticGrain: String {
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

struct DiagnosticBoard {
    var filterFindings: [DiagnosticFinding]
    var riskStoreCount: Int
    var regions: [DiagnosticUnit]
    var markets: [DiagnosticUnit]
    var districts: [DiagnosticUnit]
    var stores: [DiagnosticUnit]

    static func build(store: HeartbeatStore) -> DiagnosticBoard {
        let pulses = makePulses(store)
        let atRisk = pulses.filter { !$0.findings.isEmpty }
        return DiagnosticBoard(
            filterFindings: makeFilterFindings(atRisk, store: store),
            riskStoreCount: atRisk.count,
            regions: makeRegions(pulses),
            markets: makeMarkets(pulses),
            districts: makeDistricts(pulses),
            stores: makeStores(atRisk)
        )
    }

    private struct Pulse {
        var store: HeartbeatMath.MarketStore
        var findings: [DiagnosticFinding]
        var lost: Double
    }

    private static func makePulses(_ store: HeartbeatStore) -> [Pulse] {
        let roster = store.marketStores()
        var rowByStore: [MetricSection: [String: MetricRow]] = [:]
        var pickerRisk: [String: String] = [:]

        for section in MetricSection.dashboardCards {
            let rows = store.displayRows(for: section)
            if section == .pickerScorecard {
                var grouped: [String: Int] = [:]
                for row in rows {
                    if HeartbeatMath.pickerHealth(row) == .risk {
                        grouped[row.storeNumber, default: 0] += 1
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

        var out: [Pulse] = []
        out.reserveCapacity(roster.count)
        for unit in roster {
            var findings: [DiagnosticFinding] = []
            var lost = 0.0
            if let text = pickerRisk[unit.storeNumber] {
                findings.append(DiagnosticFinding(section: .pickerScorecard, storeCount: 1, valueText: text))
            }
            for section in MetricSection.dashboardCards {
                if section == .pickerScorecard { continue }
                guard let row = rowByStore[section]?[unit.storeNumber] else { continue }
                if HeartbeatMath.health(for: section, row: row) != .risk { continue }
                if section == .lostRevenue {
                    lost = row.number("lost_revenue") ?? 0
                }
                findings.append(DiagnosticFinding(section: section, storeCount: 1, valueText: callout(section, row)))
            }
            out.append(Pulse(store: unit, findings: findings, lost: lost))
        }
        return out
    }

    private static func makeFilterFindings(_ atRisk: [Pulse], store: HeartbeatStore) -> [DiagnosticFinding] {
        var result: [DiagnosticFinding] = []
        for section in MetricSection.dashboardCards {
            var count = 0
            for pulse in atRisk {
                for finding in pulse.findings where finding.section == section {
                    count += 1
                    break
                }
            }
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

    private static func makeRegions(_ pulses: [Pulse]) -> [DiagnosticUnit] {
        group(pulses, key: { pulse in
            MarketRegion.containing(pulse.store.division)?.rawValue ?? "Unassigned region"
        }, title: { key, _ in key })
    }

    private static func makeMarkets(_ pulses: [Pulse]) -> [DiagnosticUnit] {
        group(pulses, key: { pulse in
            HeartbeatMath.normalize(pulse.store.division).isEmpty ? "Unknown market" : pulse.store.division
        }, title: { key, _ in MarketRegion.canonicalName(key) })
    }

    private static func makeDistricts(_ pulses: [Pulse]) -> [DiagnosticUnit] {
        group(pulses, key: { pulse in
            let district = pulse.store.district.trimmingCharacters(in: .whitespacesAndNewlines)
            return district.isEmpty ? "Unassigned district" : district
        }, title: { key, group in
            let market = group.first.map { MarketRegion.canonicalName($0.store.division) } ?? ""
            if market.isEmpty { return key }
            return "\(key)  ·  \(market)"
        })
    }

    private static func makeStores(_ atRisk: [Pulse]) -> [DiagnosticUnit] {
        let sorted = atRisk.sorted { lhs, rhs in
            if lhs.findings.count != rhs.findings.count {
                return lhs.findings.count > rhs.findings.count
            }
            return lhs.lost > rhs.lost
        }
        var units: [DiagnosticUnit] = []
        units.reserveCapacity(sorted.count)
        for pulse in sorted {
            let market = MarketRegion.canonicalName(pulse.store.division)
            var district = ""
            if !pulse.store.district.isEmpty {
                district = " · \(pulse.store.district)"
            }
            units.append(
                DiagnosticUnit(
                    id: "store-\(pulse.store.storeNumber)",
                    title: pulse.store.storeNumber,
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

    private static func group(
        _ pulses: [Pulse],
        key: (Pulse) -> String,
        title: (String, [Pulse]) -> String
    ) -> [DiagnosticUnit] {
        var buckets: [String: [Pulse]] = [:]
        for pulse in pulses {
            let id = key(pulse)
            buckets[id, default: []].append(pulse)
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
            let ranked = risk.sorted { lhs, rhs in
                if lhs.findings.count != rhs.findings.count {
                    return lhs.findings.count > rhs.findings.count
                }
                return lhs.lost > rhs.lost
            }
            var worst: [String] = []
            for pulse in ranked.prefix(6) {
                worst.append(pulse.store.storeNumber)
            }
            var lost = 0.0
            for pulse in group {
                lost += pulse.lost
            }
            units.append(
                DiagnosticUnit(
                    id: id,
                    title: title(id, group),
                    subtitle: "\(HeartbeatFormat.num(Double(risk.count))) of \(HeartbeatFormat.num(Double(group.count))) stores at risk",
                    storeCount: group.count,
                    riskStoreCount: risk.count,
                    lostDollars: lost,
                    findings: findings,
                    worstStores: worst
                )
            )
        }
        units.sort { lhs, rhs in
            if lhs.riskStoreCount != rhs.riskStoreCount {
                return lhs.riskStoreCount > rhs.riskStoreCount
            }
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
