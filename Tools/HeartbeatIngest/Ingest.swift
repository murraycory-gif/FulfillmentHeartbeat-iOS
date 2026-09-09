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
        try PulseSQLite.write(rows: rows, uploads: uploads, seeded: true, to: sqlite)
        let size = (try FileManager.default.attributesOfItem(atPath: sqlite.path)[.size] as? NSNumber)?.intValue ?? 0
        print("Wrote \(rows.count) rows → \(sqlite.lastPathComponent) (\(size) bytes)")
        let loaded = Set(uploads.map(\.section))
        let missing = MetricSection.uploadOrder.filter { !loaded.contains($0) }
        if !missing.isEmpty {
            print("Missing: \(missing.map(\.title).joined(separator: ", "))")
        }
    }
}
