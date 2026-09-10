import Foundation

@main
enum HeartbeatIngest {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count >= 3 else {
            fputs("Usage: HeartbeatIngest <workbook.xlsx> <out.sqlite>\n", stderr)
            exit(2)
        }
        let xlsx = URL(fileURLWithPath: args[1])
        let sqlite = URL(fileURLWithPath: args[2])
        let data = try Data(contentsOf: xlsx)
        guard data.count > 1_000 else {
            fputs("Workbook is empty.\n", stderr)
            exit(1)
        }
        print("Cooking \(xlsx.lastPathComponent) (\(data.count) bytes)…")
        let sheets = try WorkbookParser.parseMaster(data: data, filename: xlsx.lastPathComponent) { loaded, total, name in
            print("  \(loaded)/\(total) \(name)")
        }
        var rows: [MetricRow] = []
        var uploads: [UploadRecord] = []
        rows.reserveCapacity(20_000)
        for sheet in sheets {
            let incoming = sheet.rows.map { $0.asRow(section: sheet.section) }
            rows.append(contentsOf: incoming)
            uploads.append(
                UploadRecord(
                    section: sheet.section,
                    filename: "\(xlsx.lastPathComponent) · \(sheet.sheetName)",
                    rowCount: incoming.count
                )
            )
            print("  \(sheet.section.title): \(incoming.count) rows")
        }
        print("Cooking dashboard tiles…")
        let caches = PulseCaches.build(
            rows: rows,
            filters: DashboardFilters(),
            uploads: uploads,
            heavy: true,
            grain: .region
        )
        let chrome = PulseDashChrome.from(caches)
        try PulseSQLite.write(rows: rows, uploads: uploads, seeded: true, chrome: chrome, to: sqlite)
        let size = (try FileManager.default.attributesOfItem(atPath: sqlite.path)[.size] as? NSNumber)?.intValue ?? 0
        print("Wrote \(rows.count) rows + \(chrome.summaries.count) dashboard cards → \(sqlite.lastPathComponent) (\(size) bytes)")
        for summary in chrome.summaries {
            let head = summary.headline.map { String(format: "%.2f", $0) } ?? "—"
            print("  card \(summary.section.rawValue): stores=\(summary.storeCount) head=\(head) risk=\(summary.riskCount)")
        }
        print("  picker shoppers=\(chrome.pickerShoppers) opportunity=\(chrome.pickerOpportunity) strong=\(chrome.pickerStrong)")
        let pickerTable = chrome.tables[MetricSection.pickerScorecard.rawValue] ?? []
        print("  picker expand live=\(HeartbeatMath.grainRowsAreLive(pickerTable)) rows=\(pickerTable.count)")
        for section in [MetricSection.lostRevenue, .labor, .sales, .fiveStar] {
            let count = rows.filter {
                $0.section == section && !HeartbeatMath.canonicalStore($0.storeNumber).isEmpty
            }.count
            print("  \(section.rawValue) store facts=\(count)")
        }
        for section in [MetricSection.lostRevenue, .labor, .sales, .fiveStar, .pickerScorecard] {
            let packs = chrome.packs[section.rawValue] ?? []
            guard !packs.isEmpty else { continue }
            print("  \(section.rawValue) regions:")
            for pack in packs {
                print("    \(pack.line.label): \(pack.line.value) stores=\(pack.line.count) kids=\(pack.children.count)")
            }
        }
        let loaded = Set(uploads.map(\.section))
        let missingSheets = MetricSection.uploadOrder.filter { !loaded.contains($0) }
        if !missingSheets.isEmpty {
            print("Missing sheets: \(missingSheets.map(\.title).joined(separator: ", "))")
        }
        if !chrome.isComplete {
            let missing = chrome.missingTitles.joined(separator: ", ")
            fputs("Kitchen refused to publish: dashboard tiles missing \(missing).\n", stderr)
            exit(1)
        }
        print("Dashboard tiles complete.")
    }
}
