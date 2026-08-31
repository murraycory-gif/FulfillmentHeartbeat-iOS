import Foundation

enum HeartbeatAssist {
    struct Message: Identifiable, Equatable {
        enum Role { case user, assist }
        let id: UUID
        let role: Role
        let text: String

        init(id: UUID = UUID(), role: Role, text: String) {
            self.id = id
            self.role = role
            self.text = text
        }
    }

    enum Intent: Equatable {
        case overview
        case districts
        case stores
        case shoppers
        case buckets
        case fiveStar
        case path
        case missing
        case prep
        case dynacap
        case schedule
        case pph
        case labor
        case picker
        case healthy
        case watch
        case fix
        case upload
        case store(String)
        case district(String)
        case shopper(String)
    }

    static func prompts(for dest: HubDestination) -> [String] {
        pagePrompts(dest)
    }

    static func pagePrompts(_ dest: HubDestination) -> [String] {
        switch dest {
        case .upload:
            return [
                "What files are missing?",
                "How do I load the master workbook?",
                "What does each KPI file drive?",
            ]
        case .dashboard:
            return [
                "What's at risk across the heartbeat?",
                "Who is the worst district?",
                "Which stores are causing the most damage?",
                "Which shoppers should we coach first?",
                "How do we fix it today?",
            ]
        case .checklist:
            return []
        case .lostRevenue:
            return [
                "Who is the worst district for lost revenue?",
                "Which stores are losing the most dollars?",
                "What's the biggest dollar bucket?",
                "How do we recover the opportunity?",
            ]
        case .missingItems:
            return [
                "Who is the worst district for missing items?",
                "Which stores are over 6.50% missing aisle tags?",
                "Which departments are the hottest?",
                "How do we get missing items to 5%?",
            ]
        case .fiveStar:
            return [
                "Which 5 Star KPIs are broken?",
                "Who is the worst district for 5 Star?",
                "Which stores have the worst Presub?",
                "Which shoppers are driving Flash, OTT, and Presub?",
            ]
        case .pickPath:
            return [
                "Who is the worst district for pick path?",
                "Which stores are off path?",
                "Which shoppers are breaking path?",
                "Which stores have stale aisle maps?",
                "How do we fix path compliance?",
            ]
        case .prepNotReady:
            return [
                "Who is the worst district for prep not ready?",
                "Which stores have the highest PNR?",
                "What should grocery own today?",
                "How do we cut PNR hours?",
            ]
        case .dynacap:
            return [
                "Which stores are under 60 pieces/hour?",
                "Who is the worst district for Dynacap?",
                "Is Dynacap hiding a labor problem?",
                "How do we restore capacity?",
            ]
        case .scheduleQuality:
            return [
                "Who is the worst district for schedule quality?",
                "Which stores are under or over scheduled?",
                "Is this a map problem or no-shows?",
                "What do we change on the map?",
            ]
        case .pph:
            return [
                "Who is the worst district for PPH?",
                "Which stores are below 74 PPH?",
                "Which shoppers are dragging PPH?",
                "How do we get to 80 PPH?",
            ]
        case .labor:
            return [
                "Who is the worst district for labor?",
                "Which stores are over target?",
                "Is this call-offs or a bad map?",
                "What should we address first?",
            ]
        case .pickerScorecard:
            return [
                "Which shoppers are the top opportunity?",
                "Which shoppers are breaking Presub, OTT, and OOS?",
                "Who should we coach today?",
                "Which stores have the weakest shopper mix?",
            ]
        }
    }

    static func intent(for question: String, dest: HubDestination) -> Intent {
        let q = normalize(question)
        if dest == .upload { return .upload }
        if dest == .checklist { return .overview }
        if let mapped = promptIntents(dest)[q] { return mapped }
        return keywordIntent(q, dest: dest)
    }

    private static func promptIntents(_ dest: HubDestination) -> [String: Intent] {
        var map: [String: Intent] = [:]
        for prompt in pagePrompts(dest) {
            map[normalize(prompt)] = mappedPrompt(prompt, dest: dest)
        }
        return map
    }

    private static func mappedPrompt(_ prompt: String, dest: HubDestination) -> Intent {
        let q = normalize(prompt)
        if q.contains("bucket") || q.contains("dollar bucket") { return .buckets }
        if q.contains("department") || q.contains("hottest") { return .missing }
        if q.contains("presub") && dest == .fiveStar && q.contains("store") { return .stores }
        if q.contains("5 star kpi") || q.contains("kpis are broken") { return .fiveStar }
        if q.contains("stale aisle") || q.contains("sequence") { return .path }
        if q.contains("grocery own") || q.contains("pnr") || q.contains("prep") { return dest == .prepNotReady ? .prep : .prep }
        if q.contains("hiding a labor") { return .dynacap }
        if q.contains("pieces/hour") || q.contains("dynacap") { return .dynacap }
        if q.contains("no-shows") || q.contains("map problem") || q.contains("change on the map") { return .schedule }
        if q.contains("under or over scheduled") { return .schedule }
        if q.contains("call-offs") || q.contains("over target") { return .labor }
        if q.contains("get to 80") || q.contains("dragging pph") { return q.contains("shopper") ? .shoppers : .pph }
        if q.contains("below 74") { return .stores }
        if q.contains("weakest shopper") { return .stores }
        if q.contains("top opportunity") || q.contains("coach today") || q.contains("breaking presub") { return .shoppers }
        if q.contains("shopper") || q.contains("coach") || q.contains("ldap") { return .shoppers }
        if q.contains("district") { return .districts }
        if q.contains("store") { return .stores }
        if q.contains("healthy") { return .healthy }
        if q.contains("fix") || q.contains("recover") || q.contains("cut pnr") || q.contains("get missing") || q.contains("restore") || q.contains("address first") || q.contains("fix path") { return .fix }
        if q.contains("at risk") || q.contains("across the heartbeat") { return .overview }
        return .overview
    }

    private static func keywordIntent(_ q: String, dest: HubDestination) -> Intent {
        if dest == .lostRevenue, has(q, ["bucket", "oos", "refund", "kill switch", "cancel"]) { return .buckets }
        if dest == .fiveStar || has(q, ["flash", "ott", "presub", "oth", "coe", "5 star", "five star"]) {
            if dest == .fiveStar || has(q, ["5 star", "five star", "flash", "ott", "presub", "coe", "oth"]) {
                if has(q, ["shopper", "picker", "coach"]) { return .shoppers }
                if has(q, ["district"]) { return .districts }
                if dest == .fiveStar, has(q, ["store", "fail", "presub"]) { return .stores }
                if dest != .fiveStar, has(q, ["5 star", "five star", "flash", "ott", "presub"]) { return .fiveStar }
            }
        }
        if dest == .missingItems || has(q, ["missing", "aisle tag"]) { return has(q, ["district"]) ? .districts : .missing }
        if dest == .pickPath || has(q, ["path", "aisle map", "sequence"]) { return has(q, ["shopper"]) ? .shoppers : .path }
        if dest == .prepNotReady || has(q, ["prep", "pnr"]) { return has(q, ["district"]) ? .districts : .prep }
        if dest == .dynacap || has(q, ["dynacap", "pieces"]) { return .dynacap }
        if dest == .scheduleQuality || has(q, ["schedule", "no-show", "under scheduled"]) { return .schedule }
        if dest == .labor || has(q, ["labor", "tva", "call-off", "call off"]) { return has(q, ["district"]) ? .districts : .labor }
        if dest == .pph || has(q, ["pph", "pure pph"]) { return has(q, ["shopper"]) ? .shoppers : .pph }
        if dest == .pickerScorecard || has(q, ["shopper", "picker", "ldap", "coach"]) { return .shoppers }
        if has(q, ["healthy", "green"]) { return .healthy }
        if has(q, ["watch"]) { return .watch }
        if has(q, ["fix", "recover", "action", "address", "today"]) { return .fix }
        if has(q, ["district"]) { return .districts }
        if has(q, ["store"]) { return .stores }
        return .overview
    }

    @MainActor
    static func answer(_ question: String, dest: HubDestination, store: HeartbeatStore) -> String {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            return "Ask about \(dest.title) in \(store.filters.summary). Tap a prompt or type a store, district, or LDAP."
        }
        if dest == .upload {
            return uploadAnswer(q, store: store)
        }
        guard store.seeded else {
            return "No workbooks are loaded yet. Open Upload, load the master file or each KPI, then come back."
        }
        var intent = intent(for: q, dest: dest)
        let brain = Brain(dest: dest, store: store)
        if case .overview = intent, let storeHit = brain.namedStore(in: q) {
            intent = .store(storeHit)
        } else if case .overview = intent, let person = brain.namedShopper(in: q) {
            intent = .shopper(person)
        } else if case .overview = intent, let district = brain.namedDistrict(in: q) {
            intent = .district(district)
        } else if dest != .upload {
            if let storeHit = brain.namedStore(in: q), has(normalize(q), ["store"]) || q.split(whereSeparator: { !$0.isNumber }).contains(where: { $0.count >= 3 }) {
                if !pagePrompts(dest).map(normalize).contains(normalize(q)) {
                    intent = .store(storeHit)
                }
            }
        }
        return brain.answer(intent, question: q)
    }

    @MainActor
    private static func uploadAnswer(_ question: String, store: HeartbeatStore) -> String {
        let loaded = MetricSection.uploadOrder.filter { store.upload(for: $0) != nil }
        let missing = MetricSection.uploadOrder.filter { store.upload(for: $0) == nil }
        var lines = [
            "ISSUE",
            missing.isEmpty
                ? "Every KPI workbook is loaded. Reload the shared master to refresh them together."
                : "\(missing.count) KPI file\(missing.count == 1 ? "" : "s") still empty: \(missing.map(\.title).joined(separator: ", ")).",
            "",
            "WHAT TO DO",
        ]
        if let name = store.linkedMasterName {
            lines.append("1. Tap Reload shared file for \(name).")
        } else {
            lines.append("1. Choose the shared master .xlsx with every KPI tab.")
        }
        if !missing.isEmpty {
            lines.append("2. Or add individual files for: \(missing.map(\.title).joined(separator: ", ")).")
        }
        if !loaded.isEmpty {
            lines.append("")
            lines.append("LOADED")
            for section in loaded {
                if let upload = store.upload(for: section) {
                    lines.append("• \(section.title) — \(upload.filename)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func normalize(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func has(_ haystack: String, _ keys: [String]) -> Bool {
        keys.contains { haystack.contains($0) }
    }

    @MainActor
    private struct Brain {
        let dest: HubDestination
        let store: HeartbeatStore

        var filter: String { store.filters.summary }
        var primary: MetricSection { dest.section ?? .lostRevenue }

        func answer(_ intent: HeartbeatAssist.Intent, question _: String) -> String {
            switch intent {
            case .overview: return overview()
            case .districts: return districtBrief(nil)
            case .stores: return storeRankBrief()
            case .shoppers: return shopperBrief(nil)
            case .buckets: return bucketBrief()
            case .fiveStar: return fiveStarBrief()
            case .path: return pathBrief()
            case .missing: return missingItemsBrief()
            case .prep: return prepBrief()
            case .dynacap: return dynacapBrief()
            case .schedule: return scheduleBrief()
            case .pph: return pphBrief()
            case .labor: return laborBrief()
            case .picker: return shopperBrief(nil)
            case .healthy: return healthyBrief()
            case .watch: return watchBrief()
            case .fix: return fixBrief()
            case .upload: return "Open Upload to load files."
            case .store(let number): return storeBrief(number)
            case .district(let name): return districtBrief(name)
            case .shopper(let name): return shopperBrief(name)
            }
        }

        private func overview() -> String {
            var lines = header("Pulse")
            lines.append("ISSUE")
            let cards = HeartbeatMath.dashboardCallouts(store.summaries, role: store.sessionRole)
            let risk = cards.filter { $0.health == .risk || $0.health == .watch }
            if risk.isEmpty {
                lines.append("Nothing in \(filter) is at risk or on watch.")
            } else {
                lines.append("\(risk.count) KPI\(risk.count == 1 ? "" : "s") need a look in \(filter).")
                for summary in risk {
                    lines.append("• \(label(summary.section)): \(summary.headlineText)  ·  \(summary.health.label)  ·  \(summary.riskCount) at risk / \(summary.watchCount) watch")
                }
            }
            lines.append("")
            lines.append(contentsOf: districtLines(limit: 5))
            lines.append("")
            lines.append(contentsOf: storeLines(limit: 8))
            lines.append("")
            lines.append(contentsOf: shopperLines(limit: 6))
            lines.append("")
            lines.append(contentsOf: fixLines())
            return join(lines)
        }

        private func districtBrief(_ name: String?) -> String {
            var lines = header("Districts")
            if let name {
                lines.append("ISSUE")
                lines.append("District \(name) · \(filter).")
                for section in focusSections {
                    let rows = storeRows(section).filter { HeartbeatMath.matches($0.district, name) }
                    guard !rows.isEmpty else { continue }
                    let risk = rows.filter { HeartbeatMath.health(for: section, row: $0) == .risk }.count
                    let watch = rows.filter { HeartbeatMath.health(for: section, row: $0) == .watch }.count
                    lines.append("• \(label(section)): \(metricLine(section, rows))  ·  \(rows.count) stores  ·  \(risk) at risk / \(watch) watch")
                }
                lines.append("")
                lines.append(contentsOf: storeLines(limit: 8, district: name))
                lines.append("")
                lines.append(contentsOf: shopperLines(limit: 6, district: name))
                lines.append("")
                lines.append(contentsOf: fixLines(district: name))
            } else {
                let ranked = rankedDistricts(section: primary)
                if ranked.isEmpty {
                    lines.append("ISSUE")
                    lines.append("No district rollup in \(filter). Stores may be missing a district on the roster.")
                } else {
                    lines.append("ISSUE")
                    let worst = ranked[0]
                    lines.append("\(worst.name) is the worst district for \(label(primary)) in \(filter) — \(worst.detail).")
                    lines.append("")
                    lines.append(contentsOf: districtLines(limit: 8))
                    lines.append("")
                    lines.append("WHAT TO DO")
                    lines.append("1. Filter to \(worst.name) and work the top stores below.")
                    lines.append(contentsOf: Array(storeLines(limit: 5, district: worst.name).dropFirst()))
                }
            }
            return join(lines)
        }

        private func storeRankBrief() -> String {
            var lines = header("Stores")
            let ranked = HeartbeatMath.topOpportunityStores(section: primary, rows: storeRows(primary), limit: 12)
            lines.append("ISSUE")
            if ranked.isEmpty {
                lines.append("No at-risk or watch stores for \(label(primary)) in \(filter).")
            } else {
                let top = ranked[0]
                lines.append("Store \(top.storeNumber) is the biggest miss on \(label(primary)) — \(metricLine(primary, [top])) · \(HeartbeatMath.health(for: primary, row: top).label).")
            }
            lines.append("")
            lines.append(contentsOf: storeLines(limit: 12))
            lines.append("")
            lines.append(contentsOf: shopperLines(limit: 6))
            lines.append("")
            lines.append(contentsOf: fixLines())
            return join(lines)
        }

        private func storeBrief(_ number: String) -> String {
            var lines = header("Store \(number)")
            lines.append("ISSUE")
            var found = false
            for section in MetricSection.dashboardCards {
                guard let row = storeRows(section).first(where: { HeartbeatMath.canonicalStore($0.storeNumber) == HeartbeatMath.canonicalStore(number) }) else { continue }
                found = true
                let health = HeartbeatMath.health(for: section, row: row)
                lines.append("• \(label(section)): \(metricLine(section, [row]))  ·  \(health.label)")
            }
            if !found {
                lines.append("Store \(number) is not in \(filter).")
                return join(lines)
            }
            let latest = latestMap()
            if let row = storeRows(primary).first(where: { HeartbeatMath.canonicalStore($0.storeNumber) == HeartbeatMath.canonicalStore(number) }) {
                let item = HeartbeatMath.makeChecklistItem(section: primary, row: row, division: row.division, latest: latest)
                lines.append("")
                lines.append("WHY")
                if item.findings.isEmpty {
                    lines.append("No driver notes on \(label(primary)) for this store.")
                } else {
                    for finding in item.findings.prefix(6) {
                        lines.append("• \(finding.name) \(finding.value) — need \(finding.need). \(finding.fact)")
                    }
                }
                lines.append("")
                lines.append("WHO")
                if item.people.isEmpty {
                    lines.append("No shopper LDAP is flagged. Own it in the store huddle — district \(row.district.isEmpty ? "unassigned" : row.district).")
                } else {
                    for person in item.people.prefix(8) {
                        lines.append("• \(person.name)  ·  \(person.issues.joined(separator: ", "))")
                    }
                }
                lines.append("")
                lines.append("WHAT TO DO")
                var n = 1
                for finding in item.findings.prefix(4) where !finding.action.isEmpty {
                    lines.append("\(n). \(finding.action)")
                    n += 1
                }
                for person in item.people.prefix(4) where !person.action.isEmpty {
                    lines.append("\(n). \(person.name): \(person.action)")
                    n += 1
                }
                if n == 1 {
                    lines.append("1. Walk this store's huddle against the KPI tiles above.")
                }
            }
            return join(lines)
        }

        private func shopperBrief(_ name: String?) -> String {
            var lines = header("Shoppers")
            if let name, let row = pickers().first(where: { shopperNames($0).contains { $0.localizedCaseInsensitiveContains(name) } }) {
                let ldap = row.shopperName.isEmpty ? (row.shopperId ?? row.shopperKey) : row.shopperName
                let readout = HeartbeatMath.pickerMetricReadout(row).filter { $0.health.needsAction }
                lines.append("ISSUE")
                lines.append("\(ldap) at store \(row.storeNumber) · \(row.division)\(row.district.isEmpty ? "" : " · \(row.district)").")
                if readout.isEmpty {
                    lines.append("No off-goal picker KPIs on this LDAP in the current filter.")
                } else {
                    for item in readout {
                        lines.append("• \(item.name) \(item.value)  ·  \(item.health.label)")
                    }
                }
                if let path = pathPicker(matching: row) {
                    let pct = path.number("compliance_pct")
                    lines.append("• Path \(HeartbeatFormat.pct(pct))  ·  \(HeartbeatMath.band(pct, good: HeartbeatMath.pickPathGoal, watch: HeartbeatMath.pickPathRisk).label)")
                }
                lines.append("")
                lines.append("WHAT TO DO")
                lines.append("1. Floor-coach \(ldap) on \(readout.map(\.name).joined(separator: ", ")). Watch a live wave — do not leave it as a note.")
                lines.append("2. If path is off, walk the first 10 picks with them and reset the handheld path.")
            } else {
                lines.append("ISSUE")
                let people = rankedShoppers(limit: 10, district: nil)
                if people.isEmpty {
                    lines.append("No shopper LDAP is off goal in \(filter). The miss is store-level (capacity, schedule, prep, or OOS).")
                } else {
                    lines.append("\(people.count) shoppers need a coach in \(filter). Start with \(people[0].name) at store \(people[0].store).")
                }
                lines.append("")
                lines.append(contentsOf: shopperLines(limit: 10, district: nil))
                lines.append("")
                lines.append(contentsOf: fixLines())
            }
            return join(lines)
        }

        private func bucketBrief() -> String {
            let rows = storeRows(.lostRevenue)
            let oos = sum(rows, "post_sub_oos_foregone")
            let refund = sum(rows, "refund_lost") ?? sum(rows, "refund_amt")
            let cancel = sum(rows, "cancelled_lost")
            let kill = sum(rows, "kill_switch_lost")
            let total = sum(rows, "lost_revenue")
            var buckets: [(String, Double)] = [
                ("Post-sub OOS (unfilled after a sub)", oos ?? 0),
                ("Refunds — fulfillment reasons", refund ?? 0),
                ("Cancelled orders (LDAP driven)", cancel ?? 0),
                ("Kill switch lost sales", kill ?? 0),
            ]
            buckets.sort { $0.1 > $1.1 }
            var lines = header("Lost revenue buckets")
            lines.append("ISSUE")
            lines.append("Total lost revenue in \(filter): \(HeartbeatFormat.money(total)).")
            for bucket in buckets where bucket.1 > 0 {
                let share = (total ?? 0) > 0 ? bucket.1 / (total ?? 1) * 100 : 0
                lines.append("• \(bucket.0): \(HeartbeatFormat.money(bucket.1))  (\(HeartbeatFormat.pct(share)) of the loss)")
            }
            lines.append("")
            lines.append(contentsOf: storeLines(limit: 8, section: .lostRevenue))
            lines.append("")
            lines.append("WHAT TO DO")
            if let top = buckets.first, top.1 > 0 {
                lines.append("1. Attack \(top.0) first — largest dollar bucket.")
            }
            lines.append("2. Walk the top stores with grocery (OOS) and the pick team (refunds / LDAP cancels).")
            lines.append("3. Kill switch stays on only if the crew cannot hold the wave.")
            return join(lines)
        }

        private func fiveStarBrief() -> String {
            let rows = storeRows(.fiveStar)
            let flags = HeartbeatMath.fiveStarActionFlags(rows, includeAll: true)
            var lines = header("5 Star")
            lines.append("ISSUE")
            let broken = flags.filter { $0.health.needsAction }
            if broken.isEmpty {
                lines.append("OTT, Flash, Presubs, COE, and OTH 5% are holding in \(filter).")
            } else {
                lines.append("Broken 5 Star KPIs in \(filter):")
                for flag in flags {
                    lines.append("• \(flag.name) \(flag.value)  ·  \(flag.health.label)  ·  \(flag.stores) stores")
                }
            }
            lines.append("")
            lines.append(contentsOf: districtLines(limit: 5, section: .fiveStar))
            lines.append("")
            lines.append(contentsOf: storeLines(limit: 8, section: .fiveStar))
            lines.append("")
            lines.append(contentsOf: shopperLines(limit: 8))
            lines.append("")
            lines.append(contentsOf: fixLines())
            return join(lines)
        }

        private func pathBrief() -> String {
            var lines = header("Pick path")
            let pathRows = storeRows(.pickPath)
            let avg = HeartbeatMath.average(pathRows.compactMap { $0.number("compliance_pct") })
            let staleMapper = pathRows.filter { AisleMapperMath.health(AisleMapperMath.mapperISO($0)) == .risk }.count
            let staleSeq = pathRows.filter { AisleMapperMath.health(AisleMapperMath.sequenceISO($0)) == .risk }.count
            lines.append("ISSUE")
            lines.append("Avg path \(HeartbeatFormat.pct(avg)) in \(filter). Goal 90%. Below 80% is at risk.")
            if staleMapper + staleSeq > 0 {
                lines.append("\(staleMapper) stores have aisle maps older than 90 days. \(staleSeq) have sequence updates older than 90 days.")
            }
            lines.append("")
            lines.append(contentsOf: districtLines(limit: 5, section: .pickPath))
            lines.append("")
            lines.append(contentsOf: storeLines(limit: 8, section: .pickPath))
            lines.append("")
            lines.append(contentsOf: shopperLines(limit: 8))
            lines.append("")
            lines.append(contentsOf: fixLines())
            return join(lines)
        }

        private func missingItemsBrief() -> String {
            var lines = header("Missing items")
            let rows = storeRows(.missingItems)
            let avg = HeartbeatMath.average(rows.compactMap { $0.number(MissingItemDept.totalKey) })
            lines.append("ISSUE")
            lines.append("Avg missing aisle tags \(HeartbeatFormat.pct(avg)) in \(filter). Goal 5% or less. 5.01–6.50% watch. Over 6.50% at risk.")
            var depts: [(MissingItemDept, Double)] = MissingItemDept.allCases.compactMap { dept in
                let value = HeartbeatMath.average(rows.compactMap { $0.number(dept.rawValue) })
                guard let value, value > 0 else { return nil }
                return (dept, value)
            }
            depts.sort { $0.1 > $1.1 }
            if !depts.isEmpty {
                lines.append("")
                lines.append("HOTTEST DEPARTMENTS")
                for (index, item) in depts.prefix(6).enumerated() {
                    lines.append("\(index + 1). \(item.0.title)  ·  \(HeartbeatFormat.pct(item.1))  ·  \(HeartbeatMath.missingItemsHealth(pct: item.1).label)")
                }
            }
            lines.append("")
            lines.append(contentsOf: districtLines(limit: 5, section: .missingItems))
            lines.append("")
            lines.append(contentsOf: storeLines(limit: 8, section: .missingItems))
            lines.append("")
            lines.append("WHAT TO DO")
            if let hot = depts.first {
                lines.append("1. Print and hang aisle tags in \(hot.0.short) first — hottest department at \(HeartbeatFormat.pct(hot.1)).")
            }
            lines.append("2. Audit the at-risk stores below before the next cutover.")
            return join(lines)
        }

        private func prepBrief() -> String {
            var lines = header("Prep not ready")
            let rows = storeRows(.prepNotReady)
            let avg = HeartbeatMath.average(rows.compactMap { $0.number("pnr_rate_pct") })
            lines.append("ISSUE")
            lines.append("Avg PNR hours \(HeartbeatFormat.pct(avg)) in \(filter). Goal 1.9% or less. Above 2.5% is at risk. Grocery owns prep, not e-comm.")
            lines.append("")
            lines.append(contentsOf: districtLines(limit: 5, section: .prepNotReady))
            lines.append("")
            lines.append(contentsOf: storeLines(limit: 10, section: .prepNotReady))
            lines.append("")
            lines.append("WHAT TO DO")
            lines.append("1. Grocery lead walks the prep list 60 minutes before the first e-comm wave.")
            lines.append("2. Cut produce / meat / bakery items that are not staged — do not let pickers hunt the back room.")
            lines.append("3. Recheck PNR after the next peak; if it does not drop, the prep map is wrong, not the pickers.")
            return join(lines)
        }

        private func dynacapBrief() -> String {
            var lines = header("Dynacap")
            let rows = storeRows(.dynacap)
            let avg = HeartbeatMath.average(rows.compactMap { $0.number("dynacap_rate", "pieces_per_hour") })
            let slow = rows.filter { ($0.number("dynacap_rate") ?? $0.number("pieces_per_hour") ?? 999) < 60 }
            let labor = store.summary(for: .labor)
            lines.append("ISSUE")
            lines.append("Avg Dynacap \(HeartbeatFormat.num(avg, digits: 1)) pieces/hour in \(filter). Under 60 is a capacity miss.")
            if !slow.isEmpty {
                lines.append("\(slow.count) store\(slow.count == 1 ? "" : "s") under 60 pieces/hour.")
            }
            if labor.health.needsAction {
                lines.append("Labor is also \(labor.health.label.lowercased()) (\(labor.headlineText)). Dynacap may be hiding a map / call-off problem — do not add hours until the map is right.")
            }
            lines.append("")
            lines.append(contentsOf: districtLines(limit: 5, section: .dynacap))
            lines.append("")
            lines.append(contentsOf: storeLines(limit: 8, section: .dynacap))
            lines.append("")
            lines.append("WHAT TO DO")
            lines.append("1. Restore capacity on the slowest stores — staging, batching, and full waves, not extra bodies first.")
            if labor.health.needsAction {
                lines.append("2. Pair with Labor: \(labor.headlineText). Fix call-offs and the map before adding hours.")
            }
            return join(lines)
        }

        private func scheduleBrief() -> String {
            var lines = header("Schedule quality")
            let rows = storeRows(.scheduleQuality)
            let avg = HeartbeatMath.average(rows.compactMap { $0.number("schedule_efficiency_pct") })
            let under = rows.filter { ($0.number("under_schedule_pct") ?? 0) > 0 }.count
            let over = rows.filter { ($0.number("over_schedule_pct") ?? 0) > 0 }.count
            lines.append("ISSUE")
            lines.append("Schedule efficiency \(HeartbeatFormat.pct(avg)) in \(filter). \(under) under-scheduled · \(over) over-scheduled.")
            lines.append("If PPH is healthy and the map is fat, it is a map problem. If call-offs are high, it is no-shows.")
            lines.append("")
            lines.append(contentsOf: districtLines(limit: 5, section: .scheduleQuality))
            lines.append("")
            lines.append(contentsOf: storeLines(limit: 8, section: .scheduleQuality))
            lines.append("")
            lines.append("WHAT TO DO")
            lines.append("1. Rebuild the map on over-scheduled stores — cut hours that never pick.")
            lines.append("2. On under-scheduled stores, fill the gaps with trained pickers, not overtime on the same LDAPS.")
            return join(lines)
        }

        private func pphBrief() -> String {
            var lines = header("PPH")
            let rows = storeRows(.pph)
            let avg = HeartbeatMath.average(rows.compactMap { $0.number("pph") ?? $0.number("pure_pph") })
            let below = rows.filter { ($0.number("pph") ?? $0.number("pure_pph") ?? 999) < 74 }.count
            lines.append("ISSUE")
            lines.append("Avg PPH \(HeartbeatFormat.num(avg, digits: 1)) in \(filter). Goal 80. Below 74 is at risk. \(below) store\(below == 1 ? "" : "s") below 74.")
            lines.append("")
            lines.append(contentsOf: districtLines(limit: 5, section: .pph))
            lines.append("")
            lines.append(contentsOf: storeLines(limit: 8, section: .pph))
            lines.append("")
            lines.append(contentsOf: shopperLines(limit: 8))
            lines.append("")
            lines.append("WHAT TO DO")
            lines.append("1. Coach the lowest-PPH shoppers on path, staging, and not walking for missing prep.")
            lines.append("2. If PNR is high, grocery has to stage first — pickers cannot make 80 while hunting the back room.")
            return join(lines)
        }

        private func laborBrief() -> String {
            var lines = header("Labor")
            let rows = storeRows(.labor)
            let avg = HeartbeatMath.average(rows.compactMap { $0.number("target_vs_actual_pct") })
            let over = rows.filter { ($0.number("target_vs_actual_pct") ?? 0) > HeartbeatMath.laborWatch }.count
            lines.append("ISSUE")
            lines.append("Target vs actual \(HeartbeatFormat.pct(avg)) in \(filter). \(over) store\(over == 1 ? "" : "s") over the watch band.")
            let schedule = store.summary(for: .scheduleQuality)
            if schedule.health.needsAction {
                lines.append("Schedule quality is \(schedule.health.label.lowercased()) (\(schedule.headlineText)) — this is likely a map problem, not just call-offs.")
            }
            lines.append("")
            lines.append(contentsOf: districtLines(limit: 5, section: .labor))
            lines.append("")
            lines.append(contentsOf: storeLines(limit: 8, section: .labor))
            lines.append("")
            lines.append("WHAT TO DO")
            lines.append("1. Over target + fat map: cut hours on the next build.")
            lines.append("2. Over target + thin map: call-offs. Fill trained pickers, do not keep paying overtime on the same names.")
            return join(lines)
        }

        private func healthyBrief() -> String {
            var lines = header("Healthy")
            let healthy = focusSections.compactMap { section -> String? in
                let summary = store.summary(for: section)
                guard summary.health == .good else { return nil }
                let good = max(0, summary.storeCount - summary.riskCount - summary.watchCount)
                return "\(label(section)): \(summary.headlineText)  ·  \(good) stores holding goal"
            }
            if healthy.isEmpty {
                lines.append("No KPI in \(filter) is fully healthy. Start with the at-risk list.")
            } else {
                lines.append(contentsOf: healthy.map { "• \($0)" })
                lines.append("")
                lines.append("Copy the healthy pattern (right people, on path, prep ready) into the at-risk stores.")
            }
            return join(lines)
        }

        private func watchBrief() -> String {
            var lines = header("Watch")
            let watch = focusSections.compactMap { section -> String? in
                let summary = store.summary(for: section)
                guard summary.watchCount > 0 else { return nil }
                return "\(label(section)): \(summary.headlineText)  ·  \(summary.watchCount) on watch"
            }
            if watch.isEmpty {
                lines.append("Nothing is on watch in \(filter).")
            } else {
                lines.append(contentsOf: watch.map { "• \($0)" })
                lines.append("")
                lines.append("Treat watch as a 48-hour save — coach before it flips to at risk.")
            }
            return join(lines)
        }

        private func fixBrief() -> String {
            var lines = header("Actions")
            lines.append(contentsOf: fixLines())
            return join(lines)
        }

        private func header(_ title: String) -> [String] {
            ["Heartbeat Assist — \(dest.title)", filter, "", title.uppercased(), ""]
        }

        private func join(_ lines: [String]) -> String {
            lines.joined(separator: "\n")
        }

        private var focusSections: [MetricSection] {
            if let section = dest.section { return [section] }
            return MetricSection.dashboardCards
        }

        private func districtLines(limit: Int, section: MetricSection? = nil) -> [String] {
            let section = section ?? primary
            let ranked = rankedDistricts(section: section)
            var lines = ["WORST DISTRICTS"]
            if ranked.isEmpty {
                lines.append("No district rollup in this filter.")
                return lines
            }
            for (index, item) in ranked.prefix(limit).enumerated() {
                lines.append("\(index + 1). \(item.name)  ·  \(item.detail)  ·  \(item.stores) stores")
            }
            return lines
        }

        private func storeLines(limit: Int, district: String? = nil, section: MetricSection? = nil) -> [String] {
            let section = section ?? primary
            let ranked = HeartbeatMath.topOpportunityStores(
                section: section,
                rows: storeRows(section).filter { district == nil || HeartbeatMath.matches($0.district, district ?? "") },
                limit: limit
            )
            var lines = ["STORES TO WORK"]
            if ranked.isEmpty {
                lines.append("No at-risk or watch stores in this view.")
                return lines
            }
            for (index, row) in ranked.enumerated() {
                let health = HeartbeatMath.health(for: section, row: row)
                let districtName = row.district.isEmpty ? row.division : row.district
                lines.append("\(index + 1). Store \(row.storeNumber)  ·  \(districtName)  ·  \(metricLine(section, [row]))  ·  \(health.label)")
            }
            return lines
        }

        private func shopperLines(limit: Int, district: String? = nil) -> [String] {
            var lines = ["SHOPPERS TO COACH"]
            let people = rankedShoppers(limit: limit, district: district)
            if people.isEmpty {
                lines.append("No shopper LDAP is off goal in this view. The issue is store-level (capacity, schedule, prep, or OOS).")
                return lines
            }
            for (index, person) in people.enumerated() {
                lines.append("\(index + 1). \(person.name)  ·  Store \(person.store)  ·  \(person.issues)  ·  \(person.health)")
            }
            return lines
        }

        private func fixLines(district: String? = nil) -> [String] {
            var lines = ["WHAT TO DO TODAY"]
            let ranked = HeartbeatMath.topOpportunityStores(
                section: primary,
                rows: storeRows(primary).filter { district == nil || HeartbeatMath.matches($0.district, district ?? "") },
                limit: 4
            )
            let latest = latestMap()
            var n = 1
            var seen = Set<String>()
            for row in ranked {
                let item = HeartbeatMath.makeChecklistItem(section: primary, row: row, division: row.division, latest: latest)
                if let action = item.findings.first?.action, seen.insert(action).inserted {
                    lines.append("\(n). Store \(row.storeNumber): \(action)")
                    n += 1
                }
                if let person = item.people.first, !person.action.isEmpty, seen.insert(person.action).inserted {
                    lines.append("\(n). \(person.name): \(person.action)")
                    n += 1
                }
            }
            if n == 1 {
                lines.append("1. Hold the standard huddle. Nothing in this filter needs a recovery plan.")
            }
            return lines
        }

        private struct RankedDistrict {
            var name: String
            var detail: String
            var stores: Int
            var score: Double
        }

        private func rankedDistricts(section: MetricSection) -> [RankedDistrict] {
            var buckets: [String: (score: Double, n: Int, risk: Int)] = [:]
            let rows = storeRows(section)
            for row in rows {
                let name = HeartbeatMath.canonicalDistrict(row.district)
                guard !name.isEmpty else { continue }
                let score = HeartbeatMath.opportunitySortValue(section: section, row: row)
                var bucket = buckets[name] ?? (0, 0, 0)
                bucket.score += score
                bucket.n += 1
                if HeartbeatMath.health(for: section, row: row) == .risk { bucket.risk += 1 }
                buckets[name] = bucket
            }
            return buckets.map { key, value in
                let group = rows.filter { HeartbeatMath.canonicalDistrict($0.district) == key }
                return RankedDistrict(
                    name: key,
                    detail: "\(metricLine(section, group)) · \(value.risk) at risk",
                    stores: value.n,
                    score: value.score
                )
            }
            .sorted { $0.score > $1.score }
        }

        private struct RankedShopper {
            var name: String
            var store: String
            var issues: String
            var health: String
        }

        private func rankedShoppers(limit: Int, district: String?) -> [RankedShopper] {
            var out: [RankedShopper] = []
            for row in pickers() {
                if let district {
                    let hit = HeartbeatMath.matches(row.district, district) || HeartbeatMath.matches(row.division, district)
                    if !hit { continue }
                }
                let readout = HeartbeatMath.pickerMetricReadout(row).filter { $0.health.needsAction }
                var issues = readout.map { "\($0.name) \($0.value)" }
                if let path = pathPicker(matching: row) {
                    let pct = path.number("compliance_pct")
                    let health = HeartbeatMath.band(pct, good: HeartbeatMath.pickPathGoal, watch: HeartbeatMath.pickPathRisk)
                    if health.needsAction {
                        issues.insert("Path \(HeartbeatFormat.pct(pct))", at: 0)
                    }
                }
                guard !issues.isEmpty else { continue }
                let health: Health = readout.contains(where: { $0.health == .risk }) ? .risk : .watch
                let name = row.shopperName.isEmpty ? (row.shopperId ?? row.shopperKey) : row.shopperName
                out.append(RankedShopper(name: name, store: row.storeNumber, issues: issues.joined(separator: " · "), health: health.label))
                if out.count >= limit { break }
            }
            return out
        }

        private func storeRows(_ section: MetricSection) -> [MetricRow] {
            store.displayRows(for: section).filter {
                !HeartbeatMath.isIgnoredStore($0.storeNumber) && $0.textPayload["lost_grain"] != "market"
            }
        }

        private func pickers() -> [MetricRow] {
            HeartbeatMath.topOpportunityStores(
                section: .pickerScorecard,
                rows: store.displayRows(for: .pickerScorecard).filter { HeartbeatMath.isRealPicker($0) },
                limit: 40
            )
        }

        private func pathPicker(matching row: MetricRow) -> MetricRow? {
            let aliases = HeartbeatMath.shopperAliases(row)
            return store.displayRows(for: .pickPathPicker).first { path in
                HeartbeatMath.isRealPicker(path) && HeartbeatMath.shopperAliases(path).contains(where: { aliases.contains($0) })
            }
        }

        private func latestMap() -> [MetricSection: [MetricRow]] {
            Dictionary(uniqueKeysWithValues: MetricSection.allCases.map { ($0, store.displayRows(for: $0)) })
        }

        func namedStore(in query: String) -> String? {
            query.split(whereSeparator: { !$0.isNumber }).map(String.init).first { $0.count >= 3 && $0.count <= 5 }
        }

        func namedDistrict(in query: String) -> String? {
            let lower = " \(HeartbeatAssist.normalize(query)) "
            return store.districts.first { name in
                name.count >= 2 && lower.contains(" \(name.lowercased()) ")
            }
        }

        func namedShopper(in query: String) -> String? {
            let tokens = query.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
            let stops: Set<String> = [
                "worst", "lost", "district", "stores", "which", "what", "should", "coach", "first",
                "revenue", "items", "path", "ready", "hours", "star", "flash", "presub", "labor",
                "below", "most", "dollars", "bucket", "biggest", "healthy", "watch", "fix",
                "recover", "opportunity", "today", "grocery", "shoppers", "pickers", "compliance",
                "schedule", "quality", "capacity", "hiding", "problem", "shows", "change", "stale",
                "aisle", "maps", "sequence", "update", "oldest", "missing", "broken", "driving",
            ]
            for token in tokens where token.count >= 4 && !stops.contains(token.lowercased()) {
                if pickers().contains(where: { shopperNames($0).contains { $0.compare(token, options: .caseInsensitive) == .orderedSame } }) {
                    return token
                }
            }
            return nil
        }

        private func shopperNames(_ row: MetricRow) -> [String] {
            [row.shopperName, row.shopperId ?? "", row.shopperKey].filter { !$0.isEmpty }
        }

        private func metricLine(_ section: MetricSection, _ rows: [MetricRow]) -> String {
            switch section {
            case .lostRevenue:
                return HeartbeatFormat.money(sum(rows, "lost_revenue"))
            case .fiveStar:
                return HeartbeatFormat.stars(HeartbeatMath.average(rows.compactMap { $0.number("star_rating") }))
            case .pickPath, .pickPathPicker:
                return HeartbeatFormat.pct(HeartbeatMath.average(rows.compactMap { $0.number("compliance_pct") }))
            case .prepNotReady:
                return HeartbeatFormat.pct(HeartbeatMath.average(rows.compactMap { $0.number("pnr_rate_pct") }))
            case .dynacap:
                return HeartbeatFormat.num(HeartbeatMath.average(rows.compactMap { $0.number("dynacap_rate", "pieces_per_hour") }), digits: 1)
            case .scheduleQuality:
                return HeartbeatFormat.pct(HeartbeatMath.average(rows.compactMap { $0.number("schedule_efficiency_pct") }))
            case .pph:
                return HeartbeatFormat.num(HeartbeatMath.average(rows.compactMap { $0.number("pph") ?? $0.number("pure_pph") }), digits: 1)
            case .labor:
                return HeartbeatFormat.pct(HeartbeatMath.average(rows.compactMap { $0.number("target_vs_actual_pct") }))
            case .pickerScorecard:
                return "\(rows.count) shoppers"
            case .missingItems:
                return HeartbeatFormat.pct(HeartbeatMath.average(rows.compactMap { $0.number(MissingItemDept.totalKey) }))
            case .aisleMapper:
                return "\(rows.count) stores"
            }
        }

        private func sum(_ rows: [MetricRow], _ key: String) -> Double? {
            let values = rows.compactMap { $0.number(key) }
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +)
        }

        private func label(_ section: MetricSection) -> String {
            section == .lostRevenue ? "Loss Revenue" : section.title
        }
    }
}
