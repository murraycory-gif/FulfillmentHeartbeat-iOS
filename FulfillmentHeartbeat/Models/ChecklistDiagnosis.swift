import Foundation

extension HeartbeatMath {
    static func makeChecklistItem(
        section: MetricSection,
        row: MetricRow,
        division: String,
        latest: [MetricSection: [MetricRow]]
    ) -> ChecklistDriverItem {
        let cell = StoreCellViewModel.make(section: section, row: row)
        let store = canonicalStore(row.storeNumber)
        let findings = diagnoseStore(section: section, row: row, store: store, latest: latest)
            .filter { $0.health.needsAction }
        let people = checklistPeople(section: section, store: store, latest: latest)
            .filter { $0.health.needsAction }
        let itemHealth: Health = {
            if findings.contains(where: { $0.health == .risk }) || people.contains(where: { $0.health == .risk }) {
                return .risk
            }
            if findings.contains(where: { $0.health == .watch }) || people.contains(where: { $0.health == .watch }) {
                return .watch
            }
            return health(for: section, row: row)
        }()
        return ChecklistDriverItem(
            id: "store-\(store)",
            title: "Store \(row.storeNumber)",
            subtitle: division.isEmpty ? "Store" : division,
            value: cell.primary,
            health: itemHealth,
            broken: findings.map { "\($0.name) \($0.value) (need \($0.need))" }.joined(separator: "  ·  "),
            shoppers: findings.map(\.shoppers).filter { !$0.isEmpty }.joined(separator: "  ·  "),
            action: findings.map(\.action).joined(separator: " "),
            findings: findings,
            people: people
        )
    }

    private static func rowForStore(_ latest: [MetricSection: [MetricRow]], _ section: MetricSection, _ store: String) -> MetricRow? {
        latest[section]?.first { canonicalStore($0.storeNumber) == store }
    }

    private static func pickersForStore(_ latest: [MetricSection: [MetricRow]], _ store: String) -> [MetricRow] {
        (latest[.pickerScorecard] ?? []).filter { canonicalStore($0.storeNumber) == store && isRealPicker($0) }
    }

    private static func pathPickersForStore(_ latest: [MetricSection: [MetricRow]], _ store: String) -> [MetricRow] {
        let scorecard = pickersForStore(latest, store)
        let aliases = Set(scorecard.flatMap(shopperAliases))
        return (latest[.pickPathPicker] ?? []).filter { row in
            guard isRealPicker(row) else { return false }
            if canonicalStore(row.storeNumber) == store { return true }
            return shopperAliases(row).contains { aliases.contains($0) }
        }
    }

    private static func diagnoseStore(
        section: MetricSection,
        row: MetricRow,
        store: String,
        latest: [MetricSection: [MetricRow]]
    ) -> [ChecklistFinding] {
        let labor = rowForStore(latest, .labor, store)
        let schedule = rowForStore(latest, .scheduleQuality, store)
        let path = rowForStore(latest, .pickPath, store)
        let pph = rowForStore(latest, .pph, store)
        let prep = rowForStore(latest, .prepNotReady, store)
        let pickers = pickersForStore(latest, store)
        let pathPickers = pathPickersForStore(latest, store)
        switch section {
        case .fiveStar:
            return diagnoseFiveStar(row, labor: labor, schedule: schedule, path: path, pph: pph, prep: prep, pickers: pickers)
        case .pickPath, .pickPathPicker:
            return diagnosePath(path ?? row, pph: pph, pathPickers: pathPickers)
        case .pph:
            return diagnosePPH(pph ?? row, path: path, labor: labor, pickers: pickers)
        case .labor:
            return diagnoseLabor(labor ?? row, schedule: schedule, pph: pph)
        case .scheduleQuality:
            return diagnoseSchedule(schedule ?? row, labor: labor)
        case .prepNotReady:
            return diagnosePrep(rowForStore(latest, .prepNotReady, store) ?? row)
        case .dynacap:
            return diagnoseDynacap(row, labor: labor, pph: pph)
        case .lostRevenue:
            return diagnoseLost(row, pickers: pickers)
        case .missingItems:
            return diagnoseMissingItems(row)
        case .preSubOOS:
            return diagnosePreSubOOS(row)
        case .pickerScorecard, .aisleMapper, .preSubOOSItem:
            return []
        }
    }

    private static func diagnoseFiveStar(
        _ row: MetricRow,
        labor: MetricRow?,
        schedule: MetricRow?,
        path: MetricRow?,
        pph: MetricRow?,
        prep: MetricRow?,
        pickers: [MetricRow]
    ) -> [ChecklistFinding] {
        var out: [ChecklistFinding] = []
        if row.number("flash_pct") != nil || row.number("flash_star") != nil, flashStar(row).health != .good {
            out.append(flashFinding(row, labor: labor, schedule: schedule, path: path, pph: pph, prep: prep))
        }
        if row.number("presub_pct") != nil || row.number("presub_star") != nil, presubStar(row).health != .good {
            out.append(presubFinding(row, pickers: pickers))
        }
        if row.number("ott_pct") != nil || row.number("ott_star") != nil, ottStar(row).health != .good {
            out.append(ottFinding(row, labor: labor, schedule: schedule, path: path, pph: pph, prep: prep, pickers: pickers))
        }
        if row.number("oth5_pct") != nil || row.number("oth5_star") != nil, othStar(row).health != .good {
            out.append(othFinding(row, labor: labor, schedule: schedule, pickers: pickers))
        }
        if row.number("oos_pct") != nil || row.number("oos_star") != nil, oosStar(row).health != .good {
            out.append(oosFinding(row, pickers: pickers))
        }
        if out.isEmpty {
            out.append(ChecklistFinding(
                name: "Star rating",
                value: HeartbeatFormat.stars(row.number("star_rating")),
                need: "≥ 4.50",
                health: fiveStarHealth(row),
                fact: "Overall rating is off goal. Open 5 Star for the component mix.",
                shoppers: "",
                action: "Walk Flash, Presub, OTT, and OTH5 on this store today and close the lowest star first."
            ))
        }
        return out
    }

    private static func staffingFacts(labor: MetricRow?, schedule: MetricRow?) -> [String] {
        var facts: [String] = []
        let under = schedule?.number("under_schedule_pct", "under_scheduled")
        let over = schedule?.number("over_schedule_pct", "over_scheduled") ?? labor?.number("over_schedule_pct")
        let tva = labor?.number("target_vs_actual_pct")
        let sch = labor?.number("sch_hrs")
        let act = labor?.number("act_hrs")
        let earned = labor?.number("earned_hrs")
        if let under, under > scheduleVarianceWatch {
            facts.append("Under-scheduled \(HeartbeatFormat.pct(under)) — the map is short at peak.")
        }
        if let over, over > scheduleVarianceWatch {
            facts.append("Over-scheduled \(HeartbeatFormat.pct(over)) — hours sit on the clock at the wrong time.")
        }
        if let sch, let act, sch > 0 {
            let miss = sch - act
            let missPct = miss / sch * 100
            if missPct >= 8 {
                facts.append("Sch \(HeartbeatFormat.num(sch, digits: 1)) hrs vs punch \(HeartbeatFormat.num(act, digits: 1)) hrs — \(HeartbeatFormat.num(miss, digits: 1)) scheduled hours never punched (\(HeartbeatFormat.pct(missPct))). That is call-offs / no-shows, not a missing-schedule problem.")
            } else if missPct <= -8 {
                facts.append("Punch \(HeartbeatFormat.num(act, digits: 1)) hrs vs sch \(HeartbeatFormat.num(sch, digits: 1)) hrs — crew is overpunching \(HeartbeatFormat.pct(-missPct)).")
            }
        }
        if let tva {
            if tva > laborWatch {
                facts.append("Tgt vs Act \(HeartbeatFormat.pct(tva)) over target — cost is high.")
            } else if tva < -laborWatch {
                facts.append("Tgt vs Act \(HeartbeatFormat.pct(tva)) under target — punch is light versus the plan.")
            }
        }
        if let earned, let act, earned > 0 {
            let util = act / earned * 100
            if util < 90 {
                facts.append("Punched \(HeartbeatFormat.num(act, digits: 1)) hrs vs earned \(HeartbeatFormat.num(earned, digits: 1)) — utilization \(HeartbeatFormat.pct(util)). Demand is there; people are not.")
            }
        }
        return facts
    }

    private static func flashFinding(
        _ row: MetricRow,
        labor: MetricRow?,
        schedule: MetricRow?,
        path: MetricRow?,
        pph: MetricRow?,
        prep: MetricRow?
    ) -> ChecklistFinding {
        let value = row.number("flash_pct")
        var facts = ["Flash is \(HeartbeatFormat.pct(value)). Goal is 75% for a full star."]
        facts.append(contentsOf: staffingFacts(labor: labor, schedule: schedule))
        if let pphRow = pph, let pphValue = pphRow.number("pph"), pphHealth(pphRow) != .good {
            facts.append("PPH \(HeartbeatFormat.num(pphValue, digits: 1)) vs \(Int(pphGoal)) — the crew that did punch cannot clear the wave.")
        }
        if let path, let compliance = path.number("compliance_pct"), band(compliance, good: pickPathGoal, watch: pickPathRisk) != .good {
            facts.append("Path \(HeartbeatFormat.pct(compliance)) vs 90% — pickers are off-path so Flash slots collapse even if bodies are in the building.")
        }
        if let prep, let pnr = prep.number("pnr_rate_pct"), health(for: .prepNotReady, row: prep) != .good {
            facts.append("Prep not ready \(HeartbeatFormat.pct(pnr)) — pickers wait on bakery/deli/meat and Flash dies.")
        }
        let under = schedule?.number("under_schedule_pct", "under_scheduled") ?? 0
        let sch = labor?.number("sch_hrs") ?? 0
        let act = labor?.number("act_hrs") ?? 0
        let missPct = sch > 0 ? (sch - act) / sch * 100 : 0
        let over = schedule?.number("over_schedule_pct", "over_scheduled") ?? labor?.number("over_schedule_pct") ?? 0
        let action: String
        if missPct >= 8 {
            action = "Audit eComm call-offs and no-shows. \(HeartbeatFormat.num(sch - act, digits: 1)) scheduled hours never punched — do not add hours until the people on the schedule actually show up."
        } else if under > scheduleVarianceWatch {
            action = "Rebuild the map into order-drop windows. Under-scheduled \(HeartbeatFormat.pct(under)) is why Flash is \(HeartbeatFormat.pct(value))."
        } else if over > scheduleVarianceWatch {
            action = "Do not add hours. Over-scheduled \(HeartbeatFormat.pct(over)) and Flash is still \(HeartbeatFormat.pct(value)) — move coverage to pickup peaks."
        } else {
            action = "Stand a Flash huddle at every order-drop window until Flash holds 75%+. Protect the first 15 minutes of the wave."
        }
        return ChecklistFinding(
            name: "Flash",
            value: HeartbeatFormat.pct(value),
            need: "≥ 75%",
            health: flashStar(row).health,
            fact: facts.joined(separator: " "),
            shoppers: "",
            action: action
        )
    }

    private static func presubFinding(_ row: MetricRow, pickers: [MetricRow]) -> ChecklistFinding {
        let value = row.number("presub_pct")
        let names = namedPickers(pickers, failing: { presubStar($0).health != .good })
            .map { "\($0.shopperName)  Presub \(HeartbeatFormat.pct($0.number("presub_pct")))" }
        var facts = ["Presub is \(HeartbeatFormat.pct(value)). Goal is under 5%."]
        if row.number("oos_pct") != nil, oosStar(row).health != .good {
            facts.append("OOS \(HeartbeatFormat.pct(row.number("oos_pct"))) is feeding substitutions — inventory is part of this, not only picker skill.")
        }
        let who = names.prefix(3).map { $0.components(separatedBy: "  ").first ?? $0 }.joined(separator: ", ")
        let action = who.isEmpty
            ? "Only offer a true like-for-like, then confirm. Walk the last 20 substitutions on this store today."
            : "Coach \(who) side-by-side on substitutions until Presub is under 5%."
        return ChecklistFinding(
            name: "Presub",
            value: HeartbeatFormat.pct(value),
            need: "< 5%",
            health: presubStar(row).health,
            fact: facts.joined(separator: " "),
            shoppers: names.prefix(3).joined(separator: "  ·  "),
            action: action
        )
    }

    private static func ottFinding(
        _ row: MetricRow,
        labor: MetricRow?,
        schedule: MetricRow?,
        path: MetricRow?,
        pph: MetricRow?,
        prep: MetricRow?,
        pickers: [MetricRow]
    ) -> ChecklistFinding {
        let value = row.number("ott_pct")
        let names = namedPickers(pickers, failing: { ottStar($0).health != .good })
            .map { "\($0.shopperName)  OTT \(HeartbeatFormat.pct($0.number("ott_pct")))" }
        var facts = ["OTT is \(HeartbeatFormat.pct(value)). Goal is 95%."]
        facts.append(contentsOf: staffingFacts(labor: labor, schedule: schedule).prefix(2))
        if let pph, let pphValue = pph.number("pph"), pphHealth(pph) != .good {
            facts.append("PPH \(HeartbeatFormat.num(pphValue, digits: 1)) is stretching shops past the window.")
        }
        if let path, let compliance = path.number("compliance_pct"), band(compliance, good: pickPathGoal, watch: pickPathRisk) != .good {
            facts.append("Path \(HeartbeatFormat.pct(compliance)) — off-path shops miss the pickup time.")
        }
        if let prep, let pnr = prep.number("pnr_rate_pct"), pnr > pnrWatch {
            facts.append("Prep not ready \(HeartbeatFormat.pct(pnr)) is holding bags.")
        }
        let who = names.prefix(3).map { $0.components(separatedBy: "  ").first ?? $0 }.joined(separator: ", ")
        let action = who.isEmpty
            ? "Protect the pickup window. Stage complete orders 15 minutes early until OTT holds 95%."
            : "Walk \(who) on on-time staging. Do not start a new shop inside 20 minutes of a due time."
        return ChecklistFinding(
            name: "OTT",
            value: HeartbeatFormat.pct(value),
            need: "≥ 95%",
            health: ottStar(row).health,
            fact: facts.joined(separator: " "),
            shoppers: names.prefix(3).joined(separator: "  ·  "),
            action: action
        )
    }

    private static func othFinding(
        _ row: MetricRow,
        labor: MetricRow?,
        schedule: MetricRow?,
        pickers: [MetricRow]
    ) -> ChecklistFinding {
        let value = row.number("oth5_pct")
        let names = namedPickers(pickers, failing: { othStar($0).health != .good })
            .map { "\($0.shopperName)  OTH5 \(HeartbeatFormat.pct($0.number("oth5_pct")))" }
        var facts = ["OTH5 is \(HeartbeatFormat.pct(value)). Goal is 92%."]
        facts.append(contentsOf: staffingFacts(labor: labor, schedule: schedule).prefix(2))
        let who = names.prefix(3).map { $0.components(separatedBy: "  ").first ?? $0 }.joined(separator: ", ")
        let action = who.isEmpty
            ? "Keep eligible orders in the hour they were promised. Do not park them for the next wave."
            : "Coach \(who) to finish eligible orders in-hour. No new shop until the due-hour board is clear."
        return ChecklistFinding(
            name: "OTH5",
            value: HeartbeatFormat.pct(value),
            need: "≥ 92%",
            health: othStar(row).health,
            fact: facts.joined(separator: " "),
            shoppers: names.prefix(3).joined(separator: "  ·  "),
            action: action
        )
    }

    private static func oosFinding(_ row: MetricRow, pickers: [MetricRow]) -> ChecklistFinding {
        let value = row.number("oos_pct")
        let names = namedPickers(pickers, failing: { oosStar($0).health != .good })
            .map { "\($0.shopperName)  OOS \(HeartbeatFormat.pct($0.number("oos_pct")))" }
        let who = names.prefix(3).map { $0.components(separatedBy: "  ").first ?? $0 }.joined(separator: ", ")
        let action = who.isEmpty
            ? "Own top OOS items in the huddle. Check backroom before you mark out."
            : "Walk \(who) on look-time, and pull this store's top OOS items with grocery today."
        return ChecklistFinding(
            name: "OOS",
            value: HeartbeatFormat.pct(value),
            need: "< 3%",
            health: oosStar(row).health,
            fact: "OOS is \(HeartbeatFormat.pct(value)). Goal is under 3%. This is backroom and shelf availability first, picker look-time second.",
            shoppers: names.prefix(3).joined(separator: "  ·  "),
            action: action
        )
    }

    private static func diagnosePath(_ row: MetricRow, pph: MetricRow?, pathPickers: [MetricRow]) -> [ChecklistFinding] {
        let value = row.number("compliance_pct")
        let names = pathPickers
            .sorted { ($0.number("compliance_pct") ?? 101) < ($1.number("compliance_pct") ?? 101) }
            .filter { band($0.number("compliance_pct"), good: pickPathGoal, watch: pickPathRisk) != .good }
            .prefix(3)
            .map { "\($0.shopperName)  Path \(HeartbeatFormat.pct($0.number("compliance_pct")))" }
        var facts = ["Path compliance is \(HeartbeatFormat.pct(value)). Goal is 90%."]
        if let pph, let pphValue = pph.number("pph"), pphHealth(pph) != .good {
            facts.append("PPH \(HeartbeatFormat.num(pphValue, digits: 1)) moves with path — off-path shops burn minutes.")
        }
        let who = names.map { $0.components(separatedBy: "  ").first ?? $0 }.joined(separator: ", ")
        let action = who.isEmpty
            ? "Retrain every shopper under 80% this week on the floor with the path map."
            : "Retrain \(who) on the path map this week. Managers walk two low-compliance pickers per shift."
        return [ChecklistFinding(
            name: "Path compliance",
            value: HeartbeatFormat.pct(value),
            need: "≥ 90%",
            health: band(value, good: pickPathGoal, watch: pickPathRisk),
            fact: facts.joined(separator: " "),
            shoppers: names.joined(separator: "  ·  "),
            action: action
        )]
    }

    private static func diagnosePPH(_ row: MetricRow, path: MetricRow?, labor: MetricRow?, pickers: [MetricRow]) -> [ChecklistFinding] {
        let value = row.number("pph")
        let names = namedPickers(pickers, failing: { pphHealth($0) != .good })
            .map { "\($0.shopperName)  PPH \(HeartbeatFormat.num($0.number("pph"), digits: 1))" }
        var facts = ["PPH is \(HeartbeatFormat.num(value, digits: 1)). Goal is \(Int(pphGoal))."]
        facts.append(contentsOf: staffingFacts(labor: labor, schedule: nil).prefix(1))
        if let path, let compliance = path.number("compliance_pct"), band(compliance, good: pickPathGoal, watch: pickPathRisk) != .good {
            facts.append("Path \(HeartbeatFormat.pct(compliance)) is dragging PPH.")
        }
        let who = names.prefix(3).map { $0.components(separatedBy: "  ").first ?? $0 }.joined(separator: ", ")
        let action = who.isEmpty
            ? "Fix path and staging. Pull non-pick work off pickers during the wave until PPH holds \(Int(pphGoal))."
            : "Pair \(who) with a strong picker for two shifts. Pull non-pick work off them during the wave."
        return [ChecklistFinding(
            name: "PPH",
            value: HeartbeatFormat.num(value, digits: 1),
            need: "≥ \(Int(pphGoal))",
            health: pphHealth(row),
            fact: facts.joined(separator: " "),
            shoppers: names.prefix(3).joined(separator: "  ·  "),
            action: action
        )]
    }

    private static func diagnoseLabor(_ row: MetricRow, schedule: MetricRow?, pph: MetricRow?) -> [ChecklistFinding] {
        let tva = row.number("target_vs_actual_pct")
        var facts = staffingFacts(labor: row, schedule: schedule)
        if let pph, let pphValue = pph.number("pph"), pphHealth(pph) != .good {
            facts.append("PPH \(HeartbeatFormat.num(pphValue, digits: 1)) — hours are not turning into picks.")
        }
        let sch = row.number("sch_hrs") ?? 0
        let act = row.number("act_hrs") ?? 0
        let missPct = sch > 0 ? (sch - act) / sch * 100 : 0
        let action: String
        if missPct >= 8 {
            action = "Hours are scheduled and not punched. Run the no-show / call-off list before you change the map."
        } else if (tva ?? 0) > laborWatch {
            action = "Get Tgt vs Act under 3%. Do not add hours — move them to the peak."
        } else {
            action = "Use earned hours as the daily target, not scheduled hours."
        }
        return [ChecklistFinding(
            name: "Tgt vs Act",
            value: HeartbeatFormat.pct(tva),
            need: "≤ 0% healthy · ≤ 3% watch",
            health: laborHealth(tva),
            fact: facts.isEmpty ? "Labor is off the Target vs Actual goal." : facts.joined(separator: " "),
            shoppers: "",
            action: action
        )]
    }

    private static func diagnoseSchedule(_ row: MetricRow, labor: MetricRow?) -> [ChecklistFinding] {
        var out: [ChecklistFinding] = []
        let under = row.number("under_schedule_pct", "under_scheduled")
        let over = row.number("over_schedule_pct", "over_scheduled")
        if let under, varianceHealth(under) != .good {
            out.append(ChecklistFinding(
                name: "Under-scheduled",
                value: HeartbeatFormat.pct(under),
                need: "≤ 5%",
                health: varianceHealth(under),
                fact: "Under-scheduled \(HeartbeatFormat.pct(under)). Peak windows do not have enough people on the map.",
                shoppers: "",
                action: "Rebuild the week into order-drop and pickup peaks. Do not leave holes on Friday and Sunday."
            ))
        }
        if let over, varianceHealth(over) != .good {
            out.append(ChecklistFinding(
                name: "Over-scheduled",
                value: HeartbeatFormat.pct(over),
                need: "≤ 5%",
                health: varianceHealth(over),
                fact: "Over-scheduled \(HeartbeatFormat.pct(over)). Hours are paid at the wrong time.",
                shoppers: "",
                action: "Cut or move those hours to the demand curve. Extra coverage off-peak does not buy Flash or OTT."
            ))
        }
        if out.isEmpty {
            out.append(ChecklistFinding(
                name: "Schedule efficiency",
                value: HeartbeatFormat.pct(row.number("schedule_efficiency_pct")),
                need: "≥ \(Int(scheduleGoal))%",
                health: band(row.number("schedule_efficiency_pct"), good: scheduleGoal, watch: scheduleWatch),
                fact: staffingFacts(labor: labor, schedule: row).joined(separator: " "),
                shoppers: "",
                action: "Match coverage to the demand curve, not last week's habit."
            ))
        }
        return out
    }

    private static func diagnosePrep(_ row: MetricRow) -> [ChecklistFinding] {
        [ChecklistFinding(
            name: "Prep not ready",
            value: HeartbeatFormat.pct(row.number("pnr_rate_pct")),
            need: "< \(HeartbeatFormat.num(pnrWatch, digits: 1))%",
            health: health(for: .prepNotReady, row: row),
            fact: "Prep not ready is \(HeartbeatFormat.pct(row.number("pnr_rate_pct"))). Bakery, deli, or meat is late to the pick wave, so shops stall and DUG slips.",
            shoppers: "",
            action: "Run a 30-minute prep-ready board for bakery, deli, and meat. Escalate any department over 2.5% the same day."
        )]
    }

    private static func diagnoseMissingItems(_ row: MetricRow) -> [ChecklistFinding] {
        let rate = row.number(MissingItemDept.totalKey)
        let hottest = MissingItemDept.allCases
            .compactMap { dept -> (MissingItemDept, Double)? in
                guard let value = row.number(dept.rawValue) else { return nil }
                return (dept, value)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
        let hotText = hottest.isEmpty
            ? "Aisle tags are missing on the pick path."
            : hottest.map { "\($0.0.short) \(HeartbeatFormat.pct($0.1))" }.joined(separator: " · ")
        return [ChecklistFinding(
            name: "Missing items",
            value: HeartbeatFormat.pct(rate),
            need: "≤ \(HeartbeatFormat.num(HeartbeatMath.missingItemsGoal, digits: 0))%",
            health: health(for: .missingItems, row: row),
            fact: "Missing aisle tags are \(HeartbeatFormat.pct(rate)). Hottest departments: \(hotText). Shoppers cannot find items, so OOS, subs, and lost revenue climb.",
            shoppers: "",
            action: "Fix aisle tags for the hottest departments first. Anything over 6.50% is at risk — own grocery, produce, meat, and bakery the same day."
        )]
    }

    private static func diagnosePreSubOOS(_ row: MetricRow) -> [ChecklistFinding] {
        let rate = row.number(MissingItemDept.totalKey)
        let hottest = MissingItemDept.allCases
            .compactMap { dept -> (MissingItemDept, Double)? in
                guard let value = row.number(dept.rawValue) else { return nil }
                return (dept, value)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
        let hotText = hottest.isEmpty
            ? "Pre-sub OOS is high before a substitute is offered."
            : hottest.map { "\($0.0.short) \(HeartbeatFormat.pct($0.1))" }.joined(separator: " · ")
        return [ChecklistFinding(
            name: "Pre-Sub OOS",
            value: HeartbeatFormat.pct(rate),
            need: "≤ \(HeartbeatFormat.num(HeartbeatMath.missingItemsGoal, digits: 0))%",
            health: health(for: .preSubOOS, row: row),
            fact: "Pre-substitution OOS is \(HeartbeatFormat.pct(rate)). Hottest departments: \(hotText). Empty pick faces force subs, 5 Star Presub, and lost revenue.",
            shoppers: "",
            action: "Fill the hottest departments first. Confirm on-hands, then pick the home location before substituting. Anything over 6.50% is at risk."
        )]
    }

    private static func diagnoseDynacap(_ row: MetricRow, labor: MetricRow?, pph: MetricRow?) -> [ChecklistFinding] {
        var facts = ["Dynacap rate is \(HeartbeatFormat.num(row.number("dynacap_rate", "pieces_per_hour"), digits: 1))."]
        facts.append(contentsOf: staffingFacts(labor: labor, schedule: nil).prefix(1))
        if let pph, let pphValue = pph.number("pph"), pphHealth(pph) != .good {
            facts.append("PPH \(HeartbeatFormat.num(pphValue, digits: 1)) — do not cut the cap to hide a labor or path problem.")
        }
        return [ChecklistFinding(
            name: "Dynacap rate",
            value: HeartbeatFormat.num(row.number("dynacap_rate", "pieces_per_hour"), digits: 1),
            need: "≥ \(Int(dynacapGoal))",
            health: health(for: .dynacap, row: row),
            fact: facts.joined(separator: " "),
            shoppers: "",
            action: "Set pickup and delivery to the recommended values. Do not lower Dynacap to hide Flash, path, or PPH."
        )]
    }

    private static func diagnoseLost(_ row: MetricRow, pickers: [MetricRow]) -> [ChecklistFinding] {
        var out: [ChecklistFinding] = []
        func add(
            name: String,
            value: String,
            need: String,
            health: Health,
            fact: String,
            action: String,
            raw: Double?
        ) {
            guard let raw else { return }
            guard health.needsAction else { return }
            out.append(ChecklistFinding(
                name: name,
                value: value,
                need: need,
                health: health,
                fact: fact,
                shoppers: "",
                action: action
            ))
        }

        let lost = row.number("lost_revenue")
        let lostPct = row.number("lost_revenue_pct")
        let lostHealth = lostRevenueHealth(pct: lostPct)
        add(
            name: "Total Lost Revenue",
            value: HeartbeatFormat.money(lost),
            need: "under 5% of eComm",
            health: lostHealth,
            fact: "Total lost revenue (total opportunity) is \(HeartbeatFormat.money(lost)). This is demand the store already had and did not fulfill.",
            action: "Own the mix in the huddle: post-sub OOS, fulfillment refunds, LDAP cancels, and kill switch. Work the largest dollar bucket first.",
            raw: lost
        )
        add(
            name: "Total Lost Revenue %",
            value: HeartbeatFormat.pct(lostPct),
            need: "≤ 3% healthy · ≤ 5% watch",
            health: lostHealth,
            fact: "Lost revenue is \(HeartbeatFormat.pct(lostPct)) of eComm sales. Goal is under 3%.",
            action: "Get this store under 5% this week and 3% to hold. Start with the biggest dollar driver below.",
            raw: lostPct
        )

        let post = row.number("post_sub_oos_foregone")
        let postPct = row.number("post_sub_oos_foregone_pct")
        let postHealth = lostRevenueHealth(pct: postPct)
        add(
            name: "Post Sub OOS Foregone Revenue",
            value: HeartbeatFormat.money(post),
            need: "drive to $0",
            health: postPct == nil ? (post ?? 0) > 0 ? .risk : .good : postHealth,
            fact: "Post-sub OOS foregone revenue (total opportunity) is \(HeartbeatFormat.money(post)). After a substitution, the original item still went unfilled.",
            action: "Audit backroom and top OOS items before pickers mark out. Grocery owns the list; eComm owns look-time.",
            raw: post
        )
        add(
            name: "Post Sub OOS Foregone Revenue %",
            value: HeartbeatFormat.pct(postPct),
            need: "≤ 3%",
            health: postHealth,
            fact: "Post-sub OOS is \(HeartbeatFormat.pct(postPct)) of eComm. This is inventory and look-time, not a refund problem.",
            action: "Walk the top OOS items with grocery today. Check the backroom before every mark-out.",
            raw: postPct
        )

        let refund = row.number("refund_lost")
        let refundPct = row.number("refund_lost_pct")
        let refundHealth = lostRevenueHealth(pct: refundPct)
        add(
            name: "Refund $ Fulfillment Reasons",
            value: HeartbeatFormat.money(refund),
            need: "drive to $0",
            health: refundPct == nil ? (refund ?? 0) > 0 ? .risk : .good : refundHealth,
            fact: "Refund $ for fulfillment reasons (total opportunity) is \(HeartbeatFormat.money(refund)). These are refunds we caused in the shop, not the customer.",
            action: "Audit fulfillment-reason refunds. Recover the found item and restage before a refund is offered.",
            raw: refund
        )
        add(
            name: "Refund $ Fulfillment Reasons %",
            value: HeartbeatFormat.pct(refundPct),
            need: "≤ 3%",
            health: refundHealth,
            fact: "Fulfillment refunds are \(HeartbeatFormat.pct(refundPct)) of eComm.",
            action: "Cut fulfillment refunds. Coach found-item recovery and staging accuracy on this store.",
            raw: refundPct
        )

        let capacity = row.number("reduced_capacity")
        add(
            name: "Total Reduced Capacity",
            value: HeartbeatFormat.num(capacity, digits: 1),
            need: "0",
            health: (capacity ?? 0) > 0 ? .risk : .good,
            fact: "Total reduced capacity is \(HeartbeatFormat.num(capacity, digits: 1)). Capacity was taken down on this store.",
            action: "Confirm Dynacap and kill-switch settings are not hiding a labor or path problem. Put capacity back when the crew can hold the wave.",
            raw: capacity
        )

        let cancelled = row.number("cancelled_lost")
        let cancelledPct = row.number("cancelled_lost_pct")
        let cancelledHealth = lostRevenueHealth(pct: cancelledPct)
        add(
            name: "Cancelled Orders LDAP Lost Sales",
            value: HeartbeatFormat.money(cancelled),
            need: "drive to $0",
            health: cancelledPct == nil ? (cancelled ?? 0) > 0 ? .risk : .good : cancelledHealth,
            fact: "Cancelled orders (LDAP driven) lost sales (total opportunity) is \(HeartbeatFormat.money(cancelled)). A shopper dropped these orders.",
            action: "Pull the LDAP cancel list. Walk the cancel reason with that shopper before the next wave. Do not let LDAP cancels become the overflow valve.",
            raw: cancelled
        )
        add(
            name: "Cancelled Orders LDAP Lost Sales %",
            value: HeartbeatFormat.pct(cancelledPct),
            need: "≤ 3%",
            health: cancelledHealth,
            fact: "LDAP-driven cancels are \(HeartbeatFormat.pct(cancelledPct)) of eComm.",
            action: "Stop LDAP-driven cancels. Managers review every cancel with the shopper the same day.",
            raw: cancelledPct
        )

        let killOrders = row.number("kill_switch_orders")
        add(
            name: "Kill Switch Lost Orders",
            value: HeartbeatFormat.num(killOrders),
            need: "0 orders",
            health: (killOrders ?? 0) > 0 ? .risk : .good,
            fact: "Kill switch lost \(HeartbeatFormat.num(killOrders)) orders. The store turned demand off.",
            action: "Review who flipped kill switch and whether coverage could have held the wave. Kill switch is last resort, not a labor tool.",
            raw: killOrders
        )
        let killSales = row.number("kill_switch_lost")
        add(
            name: "Kill Switch Lost Sales",
            value: HeartbeatFormat.money(killSales),
            need: "$0",
            health: (killSales ?? 0) > 0 ? .risk : .good,
            fact: "Kill switch lost sales (using $90) (total opportunity) is \(HeartbeatFormat.money(killSales)).",
            action: "Do not use kill switch as a labor workaround. Each flipped order is about $90 of demand we already had.",
            raw: killSales
        )
        let killPct = row.number("kill_switch_pct")
        add(
            name: "Kill Switch %",
            value: HeartbeatFormat.pct(killPct),
            need: "0%",
            health: (killPct ?? 0) > 0 ? .risk : lostRevenueHealth(pct: killPct),
            fact: "Kill switch is \(HeartbeatFormat.pct(killPct)) of eComm (total opportunity).",
            action: "Keep kill switch off unless safety or true capacity is blocked. Put the hours on the map instead.",
            raw: killPct
        )

        return out
    }

    private static func namedPickers(_ pickers: [MetricRow], failing: (MetricRow) -> Bool) -> [MetricRow] {
        pickers
            .filter(failing)
            .sorted { ($0.number("orders") ?? 0) > ($1.number("orders") ?? 0) }
    }

    private static func checklistPeople(
        section: MetricSection,
        store: String,
        latest: [MetricSection: [MetricRow]]
    ) -> [ChecklistShopper] {
        var byID: [String: (row: MetricRow, issues: [(String, String, Health)])] = [:]
        func add(_ row: MetricRow, _ issues: [(String, String, Health)]) {
            guard isRealPicker(row) else { return }
            let weak = issues.filter { $0.2 == .risk || $0.2 == .watch }
            guard !weak.isEmpty else { return }
            let id = canonicalShopper(row.shopperKey.isEmpty ? row.shopperName : row.shopperKey)
            guard !id.isEmpty else { return }
            if var existing = byID[id] {
                for issue in weak where !existing.issues.contains(where: { $0.0 == issue.0 }) {
                    existing.issues.append(issue)
                }
                byID[id] = existing
            } else {
                byID[id] = (row, weak)
            }
        }

        switch section {
        case .pickPath, .pickPathPicker:
            for row in pathPickersForStore(latest, store) {
                let path = row.number("compliance_pct")
                add(row, [("Path", HeartbeatFormat.pct(path), band(path, good: pickPathGoal, watch: pickPathRisk))])
            }
            for row in pickersForStore(latest, store) {
                add(row, pickerMetricReadout(row).filter { ["PPH", "Presub", "OOS"].contains($0.name) }.map { ($0.name, $0.value, $0.health) })
            }
        case .fiveStar:
            for row in pickersForStore(latest, store) {
                add(row, pickerMetricReadout(row).filter { ["OTT", "Presub", "OOS", "OTH5", "COE", "OTH Elig"].contains($0.name) }.map { ($0.name, $0.value, $0.health) })
            }
        case .pph, .dynacap, .labor:
            for row in pickersForStore(latest, store) {
                add(row, pickerMetricReadout(row).filter { $0.name == "PPH" }.map { ($0.name, $0.value, $0.health) })
            }
        default:
            break
        }

        return byID.values
            .map { entry in
                let health: Health = entry.issues.contains(where: { $0.2 == .risk }) ? .risk : .watch
                let name = entry.row.shopperName.isEmpty ? entry.row.shopperId ?? entry.row.shopperKey : entry.row.shopperName
                return ChecklistShopper(
                    id: canonicalShopper(entry.row.shopperKey.isEmpty ? name : entry.row.shopperKey),
                    name: name,
                    issues: entry.issues.map { "\($0.0) \($0.1)" },
                    action: shopperAction(name: name, issues: entry.issues),
                    health: health
                )
            }
            .sorted { lhs, rhs in
                if lhs.health != rhs.health { return healthRank(lhs.health) > healthRank(rhs.health) }
                return lhs.name < rhs.name
            }
            .prefix(8)
            .map { $0 }
    }

    private static func healthRank(_ health: Health) -> Int {
        switch health {
        case .risk: return 3
        case .watch: return 2
        case .good: return 1
        case .none: return 0
        }
    }

    private static func shopperAction(name: String, issues: [(String, String, Health)]) -> String {
        let names = Set(issues.map(\.0))
        var parts: [String] = []
        if names.contains("Presub") {
            parts.append("Walk substitutions side-by-side — like-for-like only, then confirm.")
        }
        if names.contains("OOS") {
            parts.append("Check the backroom before a mark-out. Own this shopper's top OOS items in the huddle.")
        }
        if names.contains("PPH") {
            parts.append("Pair with a strong picker for two shifts. Pull non-pick work off them during the wave.")
        }
        if names.contains("OTT") {
            parts.append("Do not start a new shop inside 20 minutes of a due time. Stage complete orders 15 minutes early.")
        }
        if names.contains("OTH5") || names.contains("OTH Elig") {
            parts.append("Finish eligible orders in-hour. No new shop until the due-hour board is clear.")
        }
        if names.contains("COE") {
            parts.append("Slow down at checkout — scan accuracy over speed until COE holds.")
        }
        if names.contains("Path") {
            parts.append("Retrain on the path map this week. Manager walks two shops with them on the floor.")
        }
        if names.contains("Refund") {
            parts.append("Audit this shopper's refunds. Recover the found item before a refund is offered.")
        }
        if parts.isEmpty {
            let list = issues.map(\.0).joined(separator: ", ")
            return "Coach \(name) on \(list) this week, side-by-side, then keep them off peak until it holds."
        }
        return parts.joined(separator: " ")
    }
}
