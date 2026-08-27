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
            return ["What files are missing?", "How do I load the master workbook?", "What does each KPI file drive?"]
        case .dashboard, .checklist:
            return ["What's at risk?", "Who is causing it?", "How do we fix it?", "What's on watch?", "What's healthy?"]
        case .fiveStar:
            return ["Which 5 Star KPIs are broken?", "Who is driving Flash and OTT?", "How do we get back to 5.00?"]
        case .pickPath:
            return ["Which stores are off path?", "Which shoppers are breaking path?", "How do we fix path compliance?"]
        case .prepNotReady:
            return ["Where is prep not ready hurting us?", "What should grocery own today?", "How do we cut PNR hours?"]
        case .dynacap:
            return ["Which stores are under 60 pieces/hour?", "Is Dynacap hiding a labor problem?", "How do we restore capacity?"]
        case .scheduleQuality:
            return ["Who is under or over scheduled?", "How is schedule hitting Flash?", "What do we change on the map?"]
        case .pph:
            return ["Which stores and shoppers are below PPH?", "Who is causing low PPH?", "How do we get to 80 PPH?"]
        case .labor:
            return ["Where is labor at risk?", "Is this call-offs or a bad map?", "What should we address first?"]
        case .pickerScorecard:
            return ["Which shoppers are the opportunity?", "Who is causing the issue?", "What should we coach today?"]
        case .lostRevenue:
            return ["Where are we losing sales?", "What's the biggest dollar bucket?", "How do we recover the opportunity?"]
        }
    }

    @MainActor
    static func answer(_ question: String, dest: HubDestination, store: HeartbeatStore) -> String {
        if dest == .upload {
            return uploadAnswer(question, store: store)
        }
        guard store.seeded else {
            return "No workbooks are loaded yet. Open Upload, load the master file or each KPI, then come back to Heartbeat Assist."
        }
        let pack = Pack.build(dest: dest, store: store)
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return briefing(pack) }
        let lower = q.lowercased()
        if let storeHit = pack.item(matchingStore: q) {
            return storeCard(storeHit)
        }
        if let person = pack.person(matching: q) {
            return personCard(person)
        }
        if looksLike(lower, ["healthy", "what's working", "whats working", "green"]) {
            return healthyCard(pack)
        }
        if looksLike(lower, ["watch", "on the line"]) {
            return watchCard(pack)
        }
        if looksLike(lower, ["who", "picker", "shopper", "ldap", "causing", "driver"]) {
            return whoCard(pack)
        }
        if looksLike(lower, ["fix", "resolve", "action", "address", "correct", "coach"]) {
            return fixCard(pack)
        }
        if looksLike(lower, ["risk", "broke", "broken", "issue", "wrong", "fail"]) {
            return riskCard(pack)
        }
        return briefing(pack, focus: q)
    }

    @MainActor
    static func briefing(dest: HubDestination, store: HeartbeatStore) -> String {
        answer("", dest: dest, store: store)
    }

    @MainActor
    private static func uploadAnswer(_ question: String, store: HeartbeatStore) -> String {
        let loaded = MetricSection.uploadOrder.filter { store.upload(for: $0) != nil }
        let missing = MetricSection.uploadOrder.filter { store.upload(for: $0) == nil }
        var lines = [
            "Heartbeat Assist — Upload",
            "",
            "ISSUE",
            missing.isEmpty
                ? "Every KPI workbook is loaded. Master load is the fastest way to refresh all of them at once."
                : "\(missing.count) KPI file\(missing.count == 1 ? "" : "s") still empty. The dashboard and checklist cannot call those sections until they land.",
            "",
            "WHO OWNS THE LOAD",
            "The person running Heartbeat. Linked master: \(store.linkedMasterName ?? "none").",
            "",
            "WHAT TO DO",
        ]
        if let name = store.linkedMasterName {
            lines.append("1. Tap Reload shared file to pull the latest \(name).")
        } else {
            lines.append("1. Choose the shared master .xlsx (tabs: Lost Revenue, 5 Star, Pick Path, Path Picker, Prep, Dynacap, Schedule, PPH, Labor, Picker ScoreCard).")
        }
        if !missing.isEmpty {
            lines.append("2. Or add individual files for: \(missing.map(\.title).joined(separator: ", ")).")
        }
        lines.append("3. After a load, set Region / Division / District / OM / Store and open Heartbeat Assist on each scorecard for Issue / Who / Fix.")
        if !loaded.isEmpty {
            lines.append("")
            lines.append("LOADED")
            for section in loaded {
                if let upload = store.upload(for: section) {
                    lines.append("• \(section.title) — \(upload.filename) · \(upload.rowCount) rows")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func briefing(_ pack: Pack, focus: String? = nil) -> String {
        var lines = [
            "Heartbeat Assist — \(pack.pageTitle)",
            pack.filter,
            "",
            "ISSUE",
        ]
        if pack.riskSections.isEmpty && pack.watchSections.isEmpty {
            lines.append("Nothing in this filter is at risk or on watch. Keep the standard huddle and protect the healthy stores.")
        } else {
            if !pack.riskSections.isEmpty {
                lines.append("AT RISK: " + pack.riskSections.map { "\($0.title) \($0.headline) (\($0.risk) stores)" }.joined(separator: " · "))
            }
            if !pack.watchSections.isEmpty {
                lines.append("WATCH: " + pack.watchSections.map { "\($0.title) \($0.headline) (\($0.watch) stores)" }.joined(separator: " · "))
            }
            if let top = pack.items.first {
                lines.append("Biggest callout: Store \(top.store) \(top.division) — \(top.section) \(top.value). \(top.findings.first?.fact ?? top.findings.first?.action ?? "")")
            }
        }
        lines.append("")
        lines.append("WHO IS CAUSING IT")
        lines.append(contentsOf: whoLines(pack))
        lines.append("")
        lines.append("WHAT TO DO")
        lines.append(contentsOf: fixLines(pack))
        if let focus, !focus.isEmpty {
            let hits = pack.items.filter { $0.matches(focus) }
            if !hits.isEmpty {
                lines.append("")
                lines.append("MATCHES FOR “\(focus)”")
                for item in hits.prefix(5) {
                    lines.append(contentsOf: item.block())
                    lines.append("")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func riskCard(_ pack: Pack) -> String {
        var lines = ["ISSUE — AT RISK", pack.filter, ""]
        if pack.riskSections.isEmpty {
            lines.append("No at-risk KPIs in this filter.")
        } else {
            for summary in pack.riskSections {
                lines.append("• \(summary.title): \(summary.headline) · \(summary.risk) stores at risk")
            }
            lines.append("")
            lines.append("WHO IS CAUSING IT")
            lines.append(contentsOf: whoLines(pack, health: Health.risk.label))
            lines.append("")
            lines.append("WHAT TO DO")
            lines.append(contentsOf: fixLines(pack))
        }
        return lines.joined(separator: "\n")
    }

    private static func watchCard(_ pack: Pack) -> String {
        var lines = ["ISSUE — WATCH", pack.filter, ""]
        if pack.watchSections.isEmpty {
            lines.append("Nothing is on watch in this filter.")
        } else {
            for summary in pack.watchSections {
                lines.append("• \(summary.title): \(summary.headline) · \(summary.watch) stores on watch")
            }
            lines.append("")
            lines.append("WHO IS CAUSING IT")
            lines.append(contentsOf: whoLines(pack, health: "Watch"))
            lines.append("")
            lines.append("WHAT TO DO")
            lines.append("1. Treat watch as a 48-hour save — coach before it flips to at risk.")
            lines.append(contentsOf: fixLines(pack).prefix(4))
        }
        return lines.joined(separator: "\n")
    }

    private static func healthyCard(_ pack: Pack) -> String {
        var lines = ["WHAT'S HEALTHY", pack.filter, ""]
        if pack.healthySections.isEmpty {
            lines.append("No KPI in this filter is fully healthy. Start with the at-risk list.")
        } else {
            for summary in pack.healthySections {
                lines.append("• \(summary.title): \(summary.headline) · \(summary.good) stores holding goal")
            }
            lines.append("")
            lines.append("Keep the huddle on the healthy pattern (right people, on path, prep ready) and copy it into the at-risk stores.")
        }
        return lines.joined(separator: "\n")
    }

    private static func whoCard(_ pack: Pack) -> String {
        var lines = ["WHO IS CAUSING IT", pack.filter, ""]
        lines.append(contentsOf: whoLines(pack))
        lines.append("")
        lines.append("WHAT TO DO")
        lines.append(contentsOf: fixLines(pack))
        return lines.joined(separator: "\n")
    }

    private static func fixCard(_ pack: Pack) -> String {
        var lines = ["WHAT TO DO", pack.filter, ""]
        lines.append(contentsOf: fixLines(pack))
        lines.append("")
        lines.append("Track each LDAP on the checklist: Addressed, Follow Up Needed, and a comment before the next huddle.")
        return lines.joined(separator: "\n")
    }

    private static func storeCard(_ item: Pack.Item) -> String {
        var lines = ["Store \(item.store)  ·  \(item.division)", item.section, ""]
        lines.append(contentsOf: item.block())
        return lines.joined(separator: "\n")
    }

    private static func personCard(_ person: Pack.Person) -> String {
        [
            "LDAP \(person.name)",
            "Store \(person.store)  ·  \(person.section)",
            "",
            "ISSUE",
            person.issues.joined(separator: "  ·  "),
            "",
            "WHO IS CAUSING IT",
            "\(person.name) on store \(person.store).",
            "",
            "WHAT TO DO",
            person.action,
        ].joined(separator: "\n")
    }

    private static func whoLines(_ pack: Pack, health: String? = nil) -> [String] {
        let people = pack.people.filter { health == nil || $0.health == health }
        let stores = pack.items.filter { health == nil || $0.health == health }
        if people.isEmpty && stores.isEmpty {
            return ["No named shopper or store is flagged in this view."]
        }
        var lines: [String] = []
        for person in people.prefix(8) {
            lines.append("• \(person.name)  ·  Store \(person.store)  ·  \(person.issues.joined(separator: ", "))  ·  \(person.health)")
        }
        if people.isEmpty {
            for item in stores.prefix(6) {
                lines.append("• Store \(item.store) \(item.division)  ·  \(item.section) \(item.value)  ·  \(item.health)")
            }
        }
        return lines
    }

    private static func fixLines(_ pack: Pack) -> [String] {
        var actions: [String] = []
        var seen = Set<String>()
        for item in pack.items.prefix(8) {
            for finding in item.findings.prefix(2) {
                let line = finding.action.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty, seen.insert(line).inserted else { continue }
                actions.append("\(actions.count + 1). Store \(item.store): \(line)")
            }
            for person in item.people.prefix(2) {
                let line = person.action.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty, seen.insert(line).inserted else { continue }
                actions.append("\(actions.count + 1). \(person.name): \(line)")
            }
        }
        if actions.isEmpty {
            return ["1. Hold the standard huddle. Nothing in this filter needs a recovery plan."]
        }
        return Array(actions.prefix(8))
    }

    private static func looksLike(_ haystack: String, _ keys: [String]) -> Bool {
        keys.contains { haystack.contains($0) }
    }

    private struct Pack {
        struct Summary {
            var title: String
            var headline: String
            var health: String
            var risk: Int
            var watch: Int
            var good: Int
        }

        struct Finding {
            var name: String
            var value: String
            var need: String
            var fact: String
            var action: String
            var health: String
        }

        struct Person {
            var name: String
            var store: String
            var section: String
            var issues: [String]
            var action: String
            var health: String
        }

        struct Item {
            var store: String
            var division: String
            var section: String
            var value: String
            var health: String
            var findings: [Finding]
            var people: [Person]

            func matches(_ query: String) -> Bool {
                let q = query.lowercased()
                if store.lowercased().contains(q) { return true }
                if division.lowercased().contains(q) { return true }
                if section.lowercased().contains(q) { return true }
                if findings.contains(where: { $0.name.lowercased().contains(q) || $0.fact.lowercased().contains(q) }) { return true }
                if people.contains(where: { $0.name.lowercased().contains(q) }) { return true }
                return false
            }

            func block() -> [String] {
                var lines = [
                    "ISSUE",
                    "\(section) is \(value) (\(health)).",
                ]
                for finding in findings.prefix(6) {
                    lines.append("• \(finding.name) \(finding.value) — need \(finding.need). \(finding.fact)")
                }
                lines.append("")
                lines.append("WHO IS CAUSING IT")
                if people.isEmpty {
                    lines.append("Store \(store) \(division) — no shopper LDAP flagged on this KPI. Own it at the store huddle.")
                } else {
                    for person in people.prefix(6) {
                        lines.append("• \(person.name)  ·  \(person.issues.joined(separator: ", "))")
                    }
                }
                lines.append("")
                lines.append("WHAT TO DO")
                var n = 1
                for finding in findings.prefix(4) where !finding.action.isEmpty {
                    lines.append("\(n). \(finding.action)")
                    n += 1
                }
                for person in people.prefix(4) where !person.action.isEmpty {
                    lines.append("\(n). \(person.name): \(person.action)")
                    n += 1
                }
                return lines
            }
        }

        var pageTitle: String
        var filter: String
        var summaries: [Summary]
        var items: [Item]

        var riskSections: [Summary] { summaries.filter { $0.health == Health.risk.label } }
        var watchSections: [Summary] { summaries.filter { $0.health == Health.watch.label } }
        var healthySections: [Summary] { summaries.filter { $0.health == Health.good.label } }
        var people: [Person] { items.flatMap(\.people) }

        func item(matchingStore query: String) -> Item? {
            let digits = query.filter(\.isNumber)
            guard digits.count >= 3 else { return nil }
            return items.first { $0.store.contains(digits) }
        }

        func person(matching query: String) -> Person? {
            let q = query.lowercased()
            return people.first { person in
                let name = person.name.lowercased()
                return name.count >= 3 && q.contains(name)
            }
        }

        @MainActor
        static func build(dest: HubDestination, store: HeartbeatStore) -> Pack {
            let sections: [MetricSection]
            if let section = dest.section {
                sections = [section]
            } else {
                sections = MetricSection.dashboardCards
            }
            let summaries: [Summary] = sections.map { section in
                let summary = store.summary(for: section)
                let good = max(0, summary.storeCount - summary.riskCount - summary.watchCount)
                return Summary(
                    title: section == .lostRevenue ? "Loss Revenue" : section.title,
                    headline: "\(summary.headlineLabel) \(summary.headlineText)",
                    health: summary.health.label,
                    risk: summary.riskCount,
                    watch: summary.watchCount,
                    good: good
                )
            }
            var items: [Item] = []
            for section in sections {
                let groups = store.checklistGroups(for: section)
                var count = 0
                for group in groups {
                    for item in group.items where item.health.needsAction {
                        guard count < 8 else { break }
                        items.append(
                            Item(
                                store: item.id.hasPrefix("store-") ? String(item.id.dropFirst(6)) : item.title,
                                division: item.subtitle,
                                section: section.title,
                                value: item.value,
                                health: item.health.label,
                                findings: item.findings.prefix(8).map {
                                    Finding(name: $0.name, value: $0.value, need: $0.need, fact: $0.fact, action: $0.action, health: $0.health.label)
                                },
                                people: item.people.prefix(6).map {
                                    Person(
                                        name: $0.name,
                                        store: item.id.hasPrefix("store-") ? String(item.id.dropFirst(6)) : item.title,
                                        section: section.title,
                                        issues: $0.issues,
                                        action: $0.action,
                                        health: $0.health.label
                                    )
                                }
                            )
                        )
                        count += 1
                    }
                }
            }
            if dest == .pickerScorecard || dest == .dashboard {
                let board = store.pickerBoard
                for row in board.opportunity.prefix(6) {
                    let readout = HeartbeatMath.pickerMetricReadout(row).filter { $0.health.needsAction }
                    guard !readout.isEmpty else { continue }
                    let name = row.shopperName.isEmpty ? (row.shopperId ?? row.shopperKey) : row.shopperName
                    items.append(
                        Item(
                            store: row.storeNumber,
                            division: row.division,
                            section: "Picker ScoreCard",
                            value: readout.map { "\($0.name) \($0.value)" }.joined(separator: " · "),
                            health: Health.risk.label,
                            findings: readout.map {
                                Finding(name: $0.name, value: $0.value, need: "goal", fact: "\($0.name) is off goal for this shopper.", action: "Coach \(name) on \($0.name) today. Pull the last 20 orders and stand with them on the floor.", health: $0.health.label)
                            },
                            people: [
                                Person(
                                    name: name,
                                    store: row.storeNumber,
                                    section: "Picker ScoreCard",
                                    issues: readout.map { "\($0.name) \($0.value)" },
                                    action: "Floor-coach \(name) on \(readout.map(\.name).joined(separator: ", ")). Do not leave it as a note — watch a wave.",
                                    health: Health.risk.label
                                )
                            ]
                        )
                    )
                }
            }
            return Pack(pageTitle: dest.title, filter: store.filters.summary, summaries: summaries, items: items)
        }
    }
}
