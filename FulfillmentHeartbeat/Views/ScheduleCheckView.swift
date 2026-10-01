import SwiftUI

enum ScheduleCheckSegment: String, CaseIterable, Identifiable {
    case action = "Action"
    case summary = "Summary"
    case stores = "Stores"

    var id: String { rawValue }
}

private enum ScheduleCheckSort: String, CaseIterable, Identifiable {
    case under = "Under"
    case over = "Over"
    case sales = "Sales"
    case store = "Store"

    var id: String { rawValue }
}

struct ScheduleCheckView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var segment: ScheduleCheckSegment = .action
    @State private var sort: ScheduleCheckSort = .under
    @State private var limit = 40

    var body: some View {
        layout(scoped: ScheduleCheckMath.scopedStores(from: store.displayRows(for: .scheduleQuality)) { number in
            store.identity(forStore: number)
        })
    }

    private func layout(scoped: [ScheduleCheckStore]) -> some View {
        let company = ScheduleCheckMath.company(scoped)
        let action = scoped.filter(ScheduleCheckMath.isAction)
        let missing = ScheduleCheckMath.missingSections(scoped)
        return VStack(spacing: 0) {
            if !HubLayout.isPhone(sizeClass) {
                HubStickyPageBanner(
                    icon: "list.clipboard.fill",
                    title: "Schedule Check",
                    accessory: store.filters.summary,
                    trailing: store.dataWindow(for: .scheduleQuality)
                )
            }
            Picker("Schedule Check", selection: $segment) {
                ForEach(ScheduleCheckSegment.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, HubLayout.isPhone(sizeClass) ? 12 : 16)
            .padding(.bottom, 6)
            List {
                Section {
                    intro(company: company, actionCount: action.count, missing: missing)
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .listRowSeparator(.hidden)
                        .listRowBackground(AppTheme.bg)
                }
                switch segment {
                case .action:
                    actionSection(action, scope: company.scope, missingSales: !scoped.contains { $0.avgSales != nil })
                case .summary:
                    summarySection(scoped, company: company)
                case .stores:
                    storeSection(scoped)
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(0)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 1)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .task { await store.ensureSectionLoaded(.scheduleQuality) }
        .onChange(of: store.filterStamp) { _, _ in limit = 40 }
        .onChange(of: segment) { _, _ in limit = 40 }
    }

    private func intro(company: ScheduleCheckRollup, actionCount: Int, missing: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Action needs sales ≥ $30K and under ≥ 10%, 4-week under > 9%, or over ≥ 15%. Over heat is 0% green and any over red.")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: HubLayout.grid(4, spacing: 6, minWidth: 120), spacing: 6) {
                tile("Stores in scope", HeartbeatFormat.num(Double(company.scope)), "Same count in This week and regions", .none)
                tile("Action", HeartbeatFormat.num(Double(actionCount)), "Clear the gate in this filter", actionCount == 0 ? .good : .risk)
                tile("Under", HeartbeatFormat.pct(company.under), "Average of stores in scope", ScheduleCheckMath.underHeat(company.under))
                tile("Over", HeartbeatFormat.pct(company.over), "0% green · any over red", ScheduleCheckMath.overHeat(company.over))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("THIS WEEK")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(AppTheme.blue)
                HStack(spacing: 8) {
                    weekBit("Stores", HeartbeatFormat.num(Double(company.scope)))
                    weekBit("Under scheduled", HeartbeatFormat.num(Double(company.underStores)))
                    weekBit("Over scheduled", HeartbeatFormat.num(Double(company.overStores)))
                    weekBit("Efficiency", HeartbeatFormat.pct(company.efficiency))
                    weekBit("Pch Vs Sch", HeartbeatFormat.pct(company.pch))
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.tableFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            if !missing.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(company.scope == 0 ? "No schedule facts in this filter" : "Pack sections still missing")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                    ForEach(missing, id: \.self) { item in
                        Text("·  \(item)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Dynacap East, PNR hours, and Prep are not filled on this page.")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                        .padding(.top, 2)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.warnSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func actionSection(_ rows: [ScheduleCheckStore], scope: Int, missingSales: Bool) -> some View {
        Section {
            if rows.isEmpty {
                EmptyHint(
                    symbol: "checkmark.circle",
                    title: "No action stores",
                    detail: missingSales
                        ? "Average sales is not in this pack, so the $30K gate cannot pass. \(scope) stores are in scope for the other views."
                        : "No store in this filter has average sales of at least $30,000 and under ≥ 10%, 4-week under over 9%, or over ≥ 15%."
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 12, trailing: 12))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            } else {
                tableBlock(
                    title: "Action",
                    accessory: "\(HeartbeatFormat.num(Double(rows.count))) of \(HeartbeatFormat.num(Double(scope))) stores",
                    rows: ordered(rows),
                    showsStar: false
                )
            }
        }
    }

    @ViewBuilder
    private func summarySection(_ stores: [ScheduleCheckStore], company: ScheduleCheckRollup) -> some View {
        Section {
            if stores.isEmpty {
                EmptyHint(
                    symbol: "calendar.badge.clock",
                    title: "No schedule facts",
                    detail: "Summary uses the same stores as Action and Stores. Load Schedule Quality, or cook the Week 31 black tabs."
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 12, trailing: 12))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    summaryCard("Total Company", [company])
                    summaryCard("Region", ScheduleCheckMath.regions(stores))
                    summaryCard("Division / Market", ScheduleCheckMath.divisions(stores))
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 12, trailing: 12))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            }
        }
    }

    @ViewBuilder
    private func storeSection(_ rows: [ScheduleCheckStore]) -> some View {
        Section {
            if rows.isEmpty {
                EmptyHint(
                    symbol: "storefront",
                    title: "No stores in this filter",
                    detail: "Store detail lists every store that has a schedule fact. It does not pad the roster."
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 12, trailing: 12))
                .listRowSeparator(.hidden)
                .listRowBackground(AppTheme.bg)
            } else {
                tableBlock(
                    title: "Stores",
                    accessory: "\(HeartbeatFormat.num(Double(rows.count))) stores",
                    rows: ordered(rows),
                    showsStar: true
                )
            }
        }
    }

    private func tableBlock(title: String, accessory: String, rows: [ScheduleCheckStore], showsStar: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
                Text(accessory)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Menu {
                    ForEach(ScheduleCheckSort.allCases) { item in
                        Button(item.rawValue) { sort = item }
                    }
                } label: {
                    Text(sort.rawValue)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                }
            }
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 4) {
                    headerRow(showsStar: showsStar)
                    ForEach(Array(rows.prefix(limit))) { row in
                        storeRow(row, showsStar: showsStar)
                    }
                }
                .padding(.bottom, 4)
            }
            if rows.count > limit {
                Button {
                    limit += 40
                } label: {
                    Text("Show more · \(HeartbeatFormat.num(Double(min(limit, rows.count)))) of \(HeartbeatFormat.num(Double(rows.count)))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(AppTheme.tableFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.blue, lineWidth: 1.5))
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 12, trailing: 12))
        .listRowSeparator(.hidden)
        .listRowBackground(AppTheme.bg)
    }

    private func headerRow(showsStar: Bool) -> some View {
        HStack(spacing: 4) {
            head("Region", 88, leading: true)
            head("Division", 96, leading: true)
            head("Dist", 44, leading: true)
            head("OM", 110, leading: true)
            head("Store", 48, leading: true)
            head("Avg sales", 78)
            head("Under", 52)
            head("Over", 52)
            head("4wk U", 52)
            head("Eff", 52)
            head("Pch", 52)
            if showsStar {
                head("4wk O", 52)
                head("Star", 40)
            }
            ForEach(ScheduleCheckDay.allCases) { day in
                head("\(day.short)U", 34)
            }
            ForEach(ScheduleCheckDay.allCases) { day in
                head("\(day.short)O", 34)
            }
        }
    }

    private func storeRow(_ row: ScheduleCheckStore, showsStar: Bool) -> some View {
        HStack(spacing: 4) {
            label(row.region, 88)
            label(row.division, 96)
            label(row.district.isEmpty ? "—" : row.district, 44)
            label(row.om.isEmpty ? "—" : row.om, 110)
            label(row.store, 48)
            metric(HeartbeatFormat.money(row.avgSales), .none, 78)
            metric(HeartbeatFormat.pct(row.underPct), ScheduleCheckMath.underHeat(row.underPct), 52)
            metric(HeartbeatFormat.pct(row.overPct), ScheduleCheckMath.overHeat(row.overPct), 52)
            metric(HeartbeatFormat.pct(row.fourWeekUnder), ScheduleCheckMath.fourWeekUnderHeat(row.fourWeekUnder), 52)
            metric(HeartbeatFormat.pct(row.efficiency), .none, 52)
            metric(HeartbeatFormat.pct(row.pchVsSch), .none, 52)
            if showsStar {
                metric(HeartbeatFormat.pct(row.fourWeekOver), ScheduleCheckMath.overHeat(row.fourWeekOver), 52)
                metric(row.star5.map { String(format: "%.1f", $0) } ?? "—", .none, 40)
            }
            ForEach(Array(row.dayUnder.enumerated()), id: \.offset) { _, value in
                metric(HeartbeatFormat.pct(value), ScheduleCheckMath.underHeat(value), 34)
            }
            ForEach(Array(row.dayOver.enumerated()), id: \.offset) { _, value in
                metric(HeartbeatFormat.pct(value), ScheduleCheckMath.overHeat(value), 34)
            }
        }
    }

    private func summaryCard(_ title: String, _ rows: [ScheduleCheckRollup]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppTheme.blue)
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        head(title == "Total Company" ? "Company" : title, 140, leading: true)
                        head("Under", 58)
                        head("Over", 58)
                        head("Pch", 58)
                        head("Eff", 58)
                        head("# Under", 58)
                        head("# Over", 58)
                        head("Stores", 58)
                    }
                    ForEach(rows) { row in
                        HStack(spacing: 4) {
                            label(row.label, 140)
                            metric(HeartbeatFormat.pct(row.under), ScheduleCheckMath.underHeat(row.under), 58)
                            metric(HeartbeatFormat.pct(row.over), ScheduleCheckMath.overHeat(row.over), 58)
                            metric(HeartbeatFormat.pct(row.pch), .none, 58)
                            metric(HeartbeatFormat.pct(row.efficiency), .none, 58)
                            metric(HeartbeatFormat.num(Double(row.underStores)), .none, 58)
                            metric(HeartbeatFormat.num(Double(row.overStores)), .none, 58)
                            metric(HeartbeatFormat.num(Double(row.scope)), .none, 58)
                        }
                    }
                }
            }
            Text("Stores column uses the same in-scope set as the tiles above.")
                .font(.caption2)
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(8)
        .background(AppTheme.tableFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.blue, lineWidth: 1.5))
    }

    private func ordered(_ rows: [ScheduleCheckStore]) -> [ScheduleCheckStore] {
        rows.sorted { lhs, rhs in
            switch sort {
            case .under:
                return (lhs.underPct ?? -1) > (rhs.underPct ?? -1)
            case .over:
                return (lhs.overPct ?? -1) > (rhs.overPct ?? -1)
            case .sales:
                return (lhs.avgSales ?? -1) > (rhs.avgSales ?? -1)
            case .store:
                return (Int(lhs.store) ?? 0) < (Int(rhs.store) ?? 0)
            }
        }
    }

    private func tile(_ title: String, _ value: String, _ detail: String, _ health: Health) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
            Text(value)
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(ink(health))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(wash(health), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    private func weekBit(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(1)
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func head(_ title: String, _ width: CGFloat, leading: Bool = false) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(AppTheme.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: width, alignment: leading ? .leading : .trailing)
    }

    private func label(_ text: String, _ width: CGFloat) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.text)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: width, alignment: .leading)
    }

    private func metric(_ text: String, _ health: Health, _ width: CGFloat) -> some View {
        Text(text)
            .font(.caption2.weight(.bold).monospacedDigit())
            .foregroundStyle(ink(health))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(width: width, alignment: .trailing)
            .padding(.vertical, 2)
            .background(wash(health), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func ink(_ health: Health) -> Color {
        switch health {
        case .good: return AppTheme.ok
        case .watch: return AppTheme.warn
        case .risk: return AppTheme.bad
        case .none: return AppTheme.text
        }
    }

    private func wash(_ health: Health) -> Color {
        switch health {
        case .good: return AppTheme.okSoft
        case .watch: return AppTheme.warnSoft
        case .risk: return AppTheme.badSoft
        case .none: return AppTheme.card
        }
    }
}
