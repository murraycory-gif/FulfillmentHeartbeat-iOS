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

    static func prompts(for dest: HubDestination) -> [String] {
        switch dest {
        case .upload:
            return pagePrompts(.upload)
        case .dashboard, .checklist:
            return hubPrompts
        default:
            return pagePrompts(dest)
        }
    }

    private static var hubPrompts: [String] {
        var seen = Set<String>()
        var out: [String] = [
            "What's at risk across the heartbeat?",
            "Who is the worst district?",
            "Which stores are causing the most damage?",
            "Which shoppers should we coach first?",
        ]
        for dest in HubDestination.sectionItems {
            guard dest.section != nil else { continue }
            for prompt in pagePrompts(dest) where seen.insert(prompt).inserted {
                out.append(prompt)
            }
        }
        if seen.insert("How do we fix it?").inserted { out.append("How do we fix it?") }
        if seen.insert("What's healthy?").inserted { out.append("What's healthy?") }
        return out
    }

    private static func pagePrompts(_ dest: HubDestination) -> [String] {
        switch dest {
        case .upload:
            return [
                "What files are missing?",
                "How do I load the master workbook?",
                "What does each KPI file drive?",
            ]
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
                "Which stores are failing 5 Star?",
                "Which shoppers are driving Flash, OTT, and Presub?",
            ]
        case .pickPath:
            return [
                "Who is the worst district for pick path?",
                "Which stores are off path?",
                "Which shoppers are breaking path?",
                "How do we fix path compliance?",
                "Which stores have stale aisle maps?",
                "Who has the oldest sequence update?",
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
        case .dashboard, .checklist:
            return [
                "What's at risk across the heartbeat?",
                "Who is the worst district?",
                "Which stores are causing the most damage?",
                "Which shoppers should we coach first?",
            ]
        }
    }

    @MainActor
    static func answer(_ question: String, dest: HubDestination, store: HeartbeatStore) -> String {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            return "Ask a question about \(dest.title). Use a prompt below or type a store, district, LDAP, or KPI."
        }
        if dest == .upload {
            return uploadAnswer(q, store: store)
        }
        guard store.seeded else {
            return "No workbooks are loaded yet. Open Upload, load the master file or each KPI, then come back."
        }
        let brain = Brain(dest: dest, store: store)
        return brain.answer(q)
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

    @MainActor
    private struct Brain {
        let dest: HubDestination
        let store: HeartbeatStore

        var filter: String { store.filters.summary }
        var sections: [MetricSection] {
            if let section = dest.section { return [section] }
            return MetricSection.dashboardCards
        }

        func answer(_ raw: String) -> String {
            let q = raw.lowercased()
            if let storeHit = namedStore(in: raw) {
                return storeBrief(storeHit)
            }
            if let person = namedShopper(in: raw) {
                return shopperBrief(person)
            }
            if let district = namedDistrict(in: raw) {
                return districtBrief(district)
            }
            if has(q, ["district"]) {
                return districtBrief(nil)
            }
            if has(q, ["shopper", "picker", "ldap", "coach"]) {
                return shopperBrief(nil)
            }
            if has(q, ["bucket", "item", "oos", "refund", "kill", "cancel", "dollar"]) && focuses(.lostRevenue) {
                return bucketBrief()
            }
            if has(q, ["missing", "aisle"]) && (focuses(.missingItems) || dest == .dashboard) {
                return missingItemsBrief()
            }
            if has(q, ["flash", "ott", "presub", "oth", "coe", "5 star", "five star"]) {
                return fiveStarBrief()
            }
            if has(q, ["path", "compliance", "aisle map", "aisle mapper", "sequence update", "stale aisle"]) {
                return pathBrief()
            }
            if has(q, ["healthy", "working", "green"]) {
                return healthyBrief()
            }
            if has(q, ["watch"]) {
                return watchBrief()
            }
            if has(q, ["fix", "recover", "action", "address", "correct", "map"]) {
                return fixBrief()
            }
            if has(q, ["store", "worst store", "losing", "failing", "below", "at risk", "risk"]) {
                return storeRankBrief()
            }
            return overview()
        }

        private func overview() -> String {
            var lines = header("Pulse")
            lines.append("ISSUE")
            let risk = sections.compactMap { section -> String? in
                let summary = store.summary(for: section)
                guard summary.health == .risk || summary.health == .watch else { return nil }
                return "\(label(section)): \(summary.headlineText) · \(summary.riskCount) at risk · \(summary.watchCount) watch"
            }
            if risk.isEmpty {
                lines.append("Nothing in this filter is at risk or on watch.")
            } else {
                lines.append(contentsOf: risk.map { "• \($0)" })
            }
            lines.append("")
            lines.append(contentsOf: districtLines(limit: 3))
            lines.append("")
            lines.append(contentsOf: storeLines(limit: 5))
            lines.append("")
            lines.append(contentsOf: shopperLines(limit: 5))
            lines.append("")
            lines.append(contentsOf: fixLines())
            return lines.joined(separator: "\n")
        }

        private func districtBrief(_ name: String?) -> String {
            var lines = header("Districts")
            if let name {
                lines.append("ISSUE")
                lines.append("District \(name) in \(filter).")
                for section in sections {
                    let rows = rows(section).filter { $0.district.compare(name, options: .caseInsensitive) == .orderedSame }
                    guard !rows.isEmpty else { continue }
                    let risk = rows.filter { HeartbeatMath.health(for: section, row: $0) == .risk }.count
                    let watch = rows.filter { HeartbeatMath.health(for: section, row: $0) == .watch }.count
                    let metric = metricLine(section, rows)
                    lines.append("• \(label(section)): \(metric) · \(rows.count) stores · \(risk) at risk · \(watch) watch")
                }
                lines.append("")
                lines.append(contentsOf: storeLines(limit: 8, district: name))
                lines.append("")
                lines.append(contentsOf: shopperLines(limit: 6, district: name))
                lines.append("")
                lines.append(contentsOf: fixLines(district: name))
            } else {
                lines.append(contentsOf: districtLines(limit: 8))
                lines.append("")
                lines.append("WHAT TO DO")
                if let worst = rankedDistricts(section: primarySection).first {
                    lines.append("1. Start in \(worst.name) — \(worst.detail). Pull those stores into the filter and work the biggest dollar / lowest KPI first.")
                } else {
                    lines.append("1. No district is off goal in this filter.")
                }
            }
            return lines.joined(separator: "\n")
        }

        private func storeRankBrief() -> String {
            var lines = header("Stores")
            lines.append(contentsOf: storeLines(limit: 10))
            lines.append("")
            lines.append(contentsOf: shopperLines(limit: 6))
            lines.append("")
            lines.append(contentsOf: fixLines())
            return lines.joined(separator: "\n")
        }

        private func storeBrief(_ number: String) -> String {
            var lines = header("Store \(number)")
            lines.append("ISSUE")
            var found = false
            for section in MetricSection.dashboardCards {
                guard let row = rows(section).first(where: { HeartbeatMath.canonicalStore($0.storeNumber) == HeartbeatMath.canonicalStore(number) }) else { continue }
                found = true
                let health = HeartbeatMath.health(for: section, row: row)
                lines.append("• \(label(section)): \(metricLine(section, [row])) · \(health.label)")
            }
            if !found {
                lines.append("Store \(number) is not in this filter.")
                return lines.joined(separator: "\n")
            }
            let latest = latestMap()
            if let row = rows(primarySection).first(where: { HeartbeatMath.canonicalStore($0.storeNumber) == HeartbeatMath.canonicalStore(number) }) {
                let item = HeartbeatMath.makeChecklistItem(section: primarySection, row: row, division: row.division, latest: latest)
                lines.append("")
                lines.append("WHY")
                for finding in item.findings.prefix(6) {
                    lines.append("• \(finding.name) \(finding.value) — need \(finding.need). \(finding.fact)")
                }
                lines.append("")
                lines.append("WHO IS CAUSING IT")
                if item.people.isEmpty {
                    lines.append("No shopper LDAP is flagged. Own it at the store huddle — district \(row.district.isEmpty ? "unassigned" : row.district).")
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
            }
            return lines.joined(separator: "\n")
        }

        private func shopperBrief(_ name: String?) -> String {
            var lines = header("Shoppers")
            if let name, let row = pickers().first(where: { shopperNames($0).contains { $0.localizedCaseInsensitiveContains(name) } }) {
                let ldap = row.shopperName.isEmpty ? (row.shopperId ?? row.shopperKey) : row.shopperName
                let readout = HeartbeatMath.pickerMetricReadout(row).filter { $0.health.needsAction }
                lines.append("ISSUE")
                lines.append("\(ldap) at store \(row.storeNumber) \(row.division).")
                if readout.isEmpty {
                    lines.append("No off-goal picker KPIs on this LDAP in the current filter.")
                } else {
                    for item in readout {
                        lines.append("• \(item.name) \(item.value) · \(item.health.label)")
                    }
                }
                if let path = pathPicker(matching: row) {
                    let pct = path.number("compliance_pct")
                    lines.append("• Path \(HeartbeatFormat.pct(pct)) · \(HeartbeatMath.band(pct, good: HeartbeatMath.pickPathGoal, watch: HeartbeatMath.pickPathRisk).label)")
                }
                lines.append("")
                lines.append("WHO IS CAUSING IT")
                lines.append("\(ldap) on store \(row.storeNumber).")
                lines.append("")
                lines.append("WHAT TO DO")
                lines.append("1. Floor-coach \(ldap) on \(readout.map(\.name).joined(separator: ", ")). Watch a live wave — do not leave it as a note.")
                lines.append("2. If path is off, walk the first 10 picks with them and reset the handheld path.")
            } else {
                lines.append(contentsOf: shopperLines(limit: 10, district: nil))
                lines.append("")
                lines.append(contentsOf: fixLines())
            }
            return lines.joined(separator: "\n")
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
            lines.append("Total lost revenue in this filter: \(HeartbeatFormat.money(total)).")
            for bucket in buckets where bucket.1 > 0 {
                let share = (total ?? 0) > 0 ? bucket.1 / (total ?? 1) * 100 : 0
                lines.append("• \(bucket.0): \(HeartbeatFormat.money(bucket.1))  (\(HeartbeatFormat.pct(share)) of the loss)")
            }
            lines.append("")
            lines.append(contentsOf: storeLines(limit: 6))
            lines.append("")
            lines.append("WHAT TO DO")
            if let top = buckets.first, top.1 > 0 {
                lines.append("1. Attack \(top.0) first — it is the largest dollar bucket.")
            }
            lines.append("2. Walk the top stores below with grocery (OOS) and the pick team (refunds / LDAP cancels).")
            lines.append("3. Kill switch only stays on if the crew cannot hold the wave — otherwise put capacity back.")
            return lines.joined(separator: "\n")
        }

        private func fiveStarBrief() -> String {
            let rows = storeRows(.fiveStar)
            let flags = HeartbeatMath.fiveStarActionFlags(rows)
            var lines = header("5 Star")
            lines.append("ISSUE")
            if flags.isEmpty {
                lines.append("OTT, Flash, Presubs, COE, and OTH 5% are healthy in this filter.")
            } else {
                for flag in flags {
                    lines.append("• \(flag.name) \(flag.value) · \(flag.health.label) · \(flag.stores) stores")
                }
            }
            lines.append("")
            lines.append(contentsOf: districtLines(limit: 5, section: .fiveStar))
            lines.append("")
            lines.append(contentsOf: shopperLines(limit: 8))
            lines.append("")
            lines.append(contentsOf: fixLines())
            return lines.joined(separator: "\n")
        }

        private func pathBrief() -> String {
            var lines = header("Pick path")
            let pathRows = storeRows(.pickPath)
            let staleMapper = pathRows.filter { AisleMapperMath.health(AisleMapperMath.mapperISO($0)) == .risk }.count
            let staleSeq = pathRows.filter { AisleMapperMath.health(AisleMapperMath.sequenceISO($0)) == .risk }.count
            if staleMapper + staleSeq > 0 {
                lines.append("ISSUE")
                lines.append("\(staleMapper) stores have aisle maps older than 90 days. \(staleSeq) have sequence updates older than 90 days. Mapper and Sequence columns live on the Pick Path store table.")
                lines.append("")
            }
            lines.append(contentsOf: districtLines(limit: 5, section: .pickPath))
            lines.append("")
            lines.append(contentsOf: storeLines(limit: 6, section: .pickPath))
            lines.append("")
            lines.append(contentsOf: shopperLines(limit: 8))
            lines.append("")
            lines.append(contentsOf: fixLines())
            return lines.joined(separator: "\n")
        }

        private func missingItemsBrief() -> String {
            var lines = header("Missing items")
            lines.append("Goal 5% or less. 5.01–6.50% is watch. Over 6.50% is at risk.")
            lines.append("")
            lines.append(contentsOf: districtLines(limit: 5, section: .missingItems))
            lines.append("")
            lines.append(contentsOf: storeLines(limit: 8, section: .missingItems))
            lines.append("")
            lines.append("Fix aisle tags in the hottest departments first — grocery, produce, meat, bakery.")
            return lines.joined(separator: "\n")
        }

        private func healthyBrief() -> String {
            var lines = header("Healthy")
            let healthy = sections.compactMap { section -> String? in
                let summary = store.summary(for: section)
                guard summary.health == .good else { return nil }
                let good = max(0, summary.storeCount - summary.riskCount - summary.watchCount)
                return "\(label(section)): \(summary.headlineText) · \(good) stores holding goal"
            }
            if healthy.isEmpty {
                lines.append("No KPI in this filter is fully healthy. Start with the at-risk list.")
            } else {
                lines.append(contentsOf: healthy.map { "• \($0)" })
                lines.append("")
                lines.append("Copy the healthy pattern (right people, on path, prep ready) into the at-risk stores.")
            }
            return lines.joined(separator: "\n")
        }

        private func watchBrief() -> String {
            var lines = header("Watch")
            let watch = sections.compactMap { section -> String? in
                let summary = store.summary(for: section)
                guard summary.watchCount > 0 else { return nil }
                return "\(label(section)): \(summary.headlineText) · \(summary.watchCount) on watch"
            }
            if watch.isEmpty {
                lines.append("Nothing is on watch in this filter.")
            } else {
                lines.append(contentsOf: watch.map { "• \($0)" })
                lines.append("")
                lines.append("Treat watch as a 48-hour save — coach before it flips to at risk.")
            }
            return lines.joined(separator: "\n")
        }

        private func fixBrief() -> String {
            var lines = header("Actions")
            lines.append(contentsOf: fixLines())
            return lines.joined(separator: "\n")
        }

        private func header(_ title: String) -> [String] {
            ["Heartbeat Assist — \(dest.title)", filter, "", title.uppercased(), ""]
        }

        private func districtLines(limit: Int, section: MetricSection? = nil) -> [String] {
            let ranked = rankedDistricts(section: section ?? primarySection)
            var lines = ["WHO IS THE WORST DISTRICT"]
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
            let section = section ?? primarySection
            let ranked = HeartbeatMath.topOpportunityStores(
                section: section,
                rows: storeRows(section).filter { district == nil || $0.district.compare(district ?? "", options: .caseInsensitive) == .orderedSame },
                limit: limit
            )
            var lines = ["WHICH STORES"]
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
            var lines = ["WHO IS CAUSING IT (SHOPPERS)"]
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
            var lines = ["WHAT TO DO"]
            let ranked = HeartbeatMath.topOpportunityStores(
                section: primarySection,
                rows: storeRows(primarySection).filter { district == nil || $0.district.compare(district ?? "", options: .caseInsensitive) == .orderedSame },
                limit: 4
            )
            let latest = latestMap()
            var n = 1
            var seen = Set<String>()
            for row in ranked {
                let item = HeartbeatMath.makeChecklistItem(section: primarySection, row: row, division: row.division, latest: latest)
                if let action = item.findings.first?.action, seen.insert(action).inserted {
                    lines.append("\(n). Store \(row.storeNumber): \(action)")
                    n += 1
                }
                if let person = item.people.first, seen.insert(person.action).inserted {
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
            for row in storeRows(section) {
                let name = row.district.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                let score = HeartbeatMath.opportunitySortValue(section: section, row: row)
                var bucket = buckets[name] ?? (0, 0, 0)
                bucket.score += score
                bucket.n += 1
                if HeartbeatMath.health(for: section, row: row) == .risk { bucket.risk += 1 }
                buckets[name] = bucket
            }
            return buckets.map { key, value in
                RankedDistrict(
                    name: key,
                    detail: "\(metricLine(section, storeRows(section).filter { $0.district == key })) · \(value.risk) at risk",
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
                if let district, row.district.compare(district, options: .caseInsensitive) != .orderedSame,
                   row.division.compare(district, options: .caseInsensitive) != .orderedSame {
                    continue
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

        private var primarySection: MetricSection {
            dest.section ?? .lostRevenue
        }

        private func focuses(_ section: MetricSection) -> Bool {
            dest == .dashboard || dest == .checklist || dest.section == section
        }

        private func rows(_ section: MetricSection) -> [MetricRow] {
            store.latest(for: section)
        }

        private func storeRows(_ section: MetricSection) -> [MetricRow] {
            rows(section).filter { !HeartbeatMath.isIgnoredStore($0.storeNumber) && $0.textPayload["lost_grain"] != "market" }
        }

        private func pickers() -> [MetricRow] {
            HeartbeatMath.topOpportunityStores(section: .pickerScorecard, rows: rows(.pickerScorecard).filter { HeartbeatMath.isRealPicker($0) }, limit: 40)
        }

        private func pathPicker(matching row: MetricRow) -> MetricRow? {
            let aliases = HeartbeatMath.shopperAliases(row)
            return rows(.pickPathPicker).first { path in
                HeartbeatMath.isRealPicker(path) && HeartbeatMath.shopperAliases(path).contains(where: { aliases.contains($0) })
            }
        }

        private func latestMap() -> [MetricSection: [MetricRow]] {
            Dictionary(uniqueKeysWithValues: MetricSection.allCases.map { ($0, store.latest(for: $0)) })
        }

        private func namedStore(in query: String) -> String? {
            let digits = query.split(whereSeparator: { !$0.isNumber }).map(String.init).first { $0.count >= 3 && $0.count <= 5 }
            return digits
        }

        private func namedDistrict(in query: String) -> String? {
            let lower = query.lowercased()
            return store.districts.first { name in
                name.count >= 2 && lower.contains(name.lowercased())
            }
        }

        private func namedShopper(in query: String) -> String? {
            let tokens = query.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
            for token in tokens where token.count >= 4 {
                if pickers().contains(where: { shopperNames($0).contains { $0.localizedCaseInsensitiveContains(token) } }) {
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

        private func has(_ haystack: String, _ keys: [String]) -> Bool {
            keys.contains { haystack.contains($0) }
        }
    }
}
