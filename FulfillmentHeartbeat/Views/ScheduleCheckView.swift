import SwiftUI

/// Upcoming Weeks Schedule Check. Action Needed, Summary, then Store Detail.
/// The hub Filters drive every grain. Rows come from `schedule_pack` in the open sqlite.
struct ScheduleCheckView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var tab: Tab = .action
    @State private var sort: Sort = .store
    @State private var ascending = true

    private enum Tab: String, CaseIterable, Identifiable {
        case action = "Action Needed"
        case summary = "Summary"
        case detail = "Store Detail"
        var id: String { rawValue }
    }

    private enum Sort {
        case store, division, sales, under, over, fourUnder, eff, pch
    }

    var body: some View {
        Group {
            if store.scheduleCheck == nil && !store.scheduleCheckReady {
                ProgressView("Loading schedule check")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let pack = store.scheduleCheck {
                loaded(pack)
            } else {
                noData
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.bg)
        .task { store.loadScheduleCheck() }
    }

    private var noData: some View {
        VStack(spacing: 8) {
            Text("NO DATA")
                .font(.title.weight(.bold))
                .foregroundStyle(AppTheme.textTertiary)
            Text("Schedule Review Week file is not on this device.")
                .font(.body)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loaded(_ pack: ScheduleCheckPack) -> some View {
        let summary = ScheduleCheckMath.summary(pack: pack, filters: store.filters)
        return VStack(alignment: .leading, spacing: 12) {
            Picker("Schedule check", selection: $tab) {
                ForEach(Tab.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, pagePadding)
            Group {
                switch tab {
                case .action:
                    actionPage(pack, summary: summary)
                case .summary:
                    summaryPage(pack, summary: summary)
                case .detail:
                    detailPage(pack)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .refreshable { await store.reloadScheduleCheck() }
    }

    /// Vertical scroll fills the space under the tabs. A two-axis scroll around
    /// a lazy stack lays out at height 0, so the scope line and rows never paint.
    private func actionPage(_ pack: ScheduleCheckPack, summary: ScheduleScopeSummary) -> some View {
        let groups = ScheduleCheckMath.actionGroups(pack: pack, filters: store.filters)
        return ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                if let note = ScheduleCheckMath.bannerMismatch(pack: pack, summary: summary, filters: store.filters) {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("\(summary.actionCount) stores · sales ≥ $30,000 and (under ≥ 10% or 4-wk under > 9% or over ≥ 15%)")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if groups.isEmpty {
                    Text("No stores qualify in this scope.")
                        .font(.body)
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 0) {
                        header(actionColumns)
                        ForEach(groups) { group in
                            Text("\(group.division) · \(group.region) · \(group.stores.count)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.blueSoft)
                            ForEach(group.stores) { store in
                                actionRow(store)
                                Divider().overlay(AppTheme.cardBorder)
                            }
                        }
                    }
                    .frame(minWidth: actionWidth, alignment: .leading)
                }
            }
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func summaryPage(_ pack: ScheduleCheckPack, summary: ScheduleScopeSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: kpiColumns, spacing: 10) {
                    kpi("Under", HeartbeatFormat.pct(summary.under), ScheduleCheckMath.percentHealth(summary.under, notScheduled: false))
                    kpi("Over", HeartbeatFormat.pct(summary.over), ScheduleCheckMath.percentHealth(summary.over, notScheduled: false))
                    kpi("Pch vs Sch", HeartbeatFormat.pct(summary.pch), nil)
                    kpi("Sch Eff", HeartbeatFormat.pct(summary.eff), ScheduleCheckMath.effHealth(summary.eff, notScheduled: false))
                    kpi("# Under", HeartbeatMath.groupedCount(summary.underCount), nil)
                    kpi("# Over", HeartbeatMath.groupedCount(summary.overCount), nil)
                    kpi("Stores in scope", HeartbeatMath.groupedCount(summary.scope), nil)
                }
                if let note = ScheduleCheckMath.companyMarketNote(summary, filters: store.filters) {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Text("Eff goal ≥ 90% is green. Ranked worst efficiency first.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                marketBlock(pack.markets)
                rankBlock(
                    title: "Region",
                    rows: ScheduleCheckMath.rankedRegions(pack: pack, filters: store.filters),
                    showsDivision: false
                )
                rankBlock(
                    title: "Division",
                    rows: ScheduleCheckMath.rankedDivisions(pack: pack, filters: store.filters),
                    showsDivision: true
                )
            }
            .padding(.horizontal, pagePadding)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Header and store rows share one scroll that has a real viewport.
    /// A nested horizontal scroll with `minHeight` of every store line lays
    /// the page out blank, and it builds all 2,000+ rows on the tap.
    /// Empty is the pack: this page does not invent schedule rows.
    private func detailPage(_ pack: ScheduleCheckPack) -> some View {
        let rows = sorted(ScheduleCheckMath.scoped(pack, filters: store.filters))
        return Group {
            if rows.isEmpty {
                Text("No stores in this scope.")
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                GeometryReader { proxy in
                    ScrollView([.horizontal, .vertical]) {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            Section {
                                ForEach(rows) { store in
                                    detailRow(store)
                                        .frame(width: detailWidth, height: ScheduleCheckMath.detailRowHeight, alignment: .leading)
                                    Divider().overlay(AppTheme.cardBorder)
                                        .frame(width: detailWidth)
                                }
                            } header: {
                                header(detailColumns, tappable: true)
                                    .frame(width: detailWidth, height: ScheduleCheckMath.detailHeaderHeight, alignment: .leading)
                                    .background(AppTheme.bg)
                            }
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Market Look rows from the pack, including United and Total.
    private func marketBlock(_ markets: [ScheduleMarket]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Market Look")
                .font(.headline)
                .foregroundStyle(AppTheme.text)
                .padding(.bottom, 8)
            ForEach(markets) { market in
                HStack(spacing: 12) {
                    Text(market.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(HeartbeatFormat.pct(market.under))
                        .frame(width: 72, alignment: .trailing)
                    Text(HeartbeatFormat.pct(market.over))
                        .frame(width: 72, alignment: .trailing)
                    Text(HeartbeatFormat.pct(market.eff))
                        .frame(width: 72, alignment: .trailing)
                }
                .font(cellFont)
                .foregroundStyle(AppTheme.text)
                .padding(.vertical, 6)
                Divider().overlay(AppTheme.cardBorder)
            }
        }
        .padding(.bottom, 16)
    }

    private func kpi(_ title: String, _ value: String, _ health: Health?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(ink(health))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(wash(health), in: RoundedRectangle(cornerRadius: AppTheme.radiusS, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusS, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func rankBlock(title: String, rows: [ScheduleRankRow], showsDivision: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.text)
                .padding(.bottom, 8)
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        if showsDivision {
                            plain("Region", 120)
                            plain("Division", 140)
                        } else {
                            plain("Region", 160)
                        }
                        plain("Under", 80)
                        plain("Over", 80)
                        plain("Pch vs Sch", 90)
                        plain("Sch Eff", 80)
                        plain("# Under", 80)
                        plain("# Over", 80)
                        plain("Scope", 70)
                    }
                    .font(cellFont.weight(.semibold))
                    ForEach(rows) { row in
                        HStack(spacing: 0) {
                            if showsDivision {
                                plain(row.region, 120)
                                plain(row.division, 140)
                            } else {
                                plain(row.region, 160)
                            }
                            heat(HeartbeatFormat.pct(row.under), 80, ScheduleCheckMath.percentHealth(row.under, notScheduled: false))
                            heat(HeartbeatFormat.pct(row.over), 80, ScheduleCheckMath.percentHealth(row.over, notScheduled: false))
                            plain(HeartbeatFormat.pct(row.pch), 90)
                            heat(HeartbeatFormat.pct(row.eff), 80, ScheduleCheckMath.effHealth(row.eff, notScheduled: false))
                            plain(HeartbeatMath.groupedCount(row.underCount), 80)
                            plain(HeartbeatMath.groupedCount(row.overCount), 80)
                            plain(HeartbeatMath.groupedCount(row.scope), 70)
                        }
                        Divider().overlay(AppTheme.cardBorder)
                    }
                }
            }
        }
    }

    private var actionColumns: [(String, CGFloat, Sort?)] {
        [
            ("Region", 110, nil), ("Division", 120, nil), ("District", 72, nil), ("OM", 120, nil),
            ("Store", 120, nil), ("Avg Sales", 96, nil), ("Under", 72, nil), ("Over", 64, nil),
            ("4 Wk Under", 88, nil), ("Sch Eff", 72, nil), ("Pch vs Sch", 88, nil),
            ("Hit U", 52, nil), ("Hit 4W", 56, nil), ("Hit O", 52, nil),
        ] + dayColumns
    }

    private var detailColumns: [(String, CGFloat, Sort?)] {
        [
            ("Region", 110, nil), ("Division", 120, .division), ("District", 72, nil), ("OM", 120, nil),
            ("Store", 120, .store), ("Avg Sales", 96, .sales), ("Under", 72, .under), ("Over", 64, .over),
            ("4 Wk Under", 88, .fourUnder), ("Sch Eff", 72, .eff), ("Pch vs Sch", 88, .pch),
            ("Hit U", 52, nil), ("Hit 4W", 56, nil), ("Hit O", 52, nil),
        ] + dayColumns
    }

    private var dayColumns: [(String, CGFloat, Sort?)] {
        ScheduleCheckMath.dayNames.flatMap { name in
            [(name + " U", 52, nil), (name + " O", 52, nil)]
        }
    }

    private var actionWidth: CGFloat { actionColumns.reduce(0) { $0 + $1.1 } }
    private var detailWidth: CGFloat { detailColumns.reduce(0) { $0 + $1.1 } }

    private func header(_ columns: [(String, CGFloat, Sort?)], tappable: Bool = false) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                if tappable, let key = column.2 {
                    Button {
                        if sort == key {
                            ascending.toggle()
                        } else {
                            sort = key
                            ascending = key == .store || key == .division
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Text(column.0)
                            if sort == key {
                                Image(systemName: ascending ? "chevron.up" : "chevron.down")
                                    .font(.caption2.weight(.bold))
                            }
                        }
                        .frame(width: column.1, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(column.0)
                        .frame(width: column.1, alignment: .leading)
                }
            }
        }
        .font(cellFont.weight(.semibold))
        .foregroundStyle(AppTheme.textSecondary)
        .padding(.vertical, 6)
        .background(AppTheme.tableFill)
    }

    private func actionRow(_ row: ScheduleStore) -> some View {
        HStack(spacing: 0) {
            identity(row)
            metrics(row)
            days(row)
        }
    }

    private func detailRow(_ row: ScheduleStore) -> some View {
        actionRow(row)
    }

    private func identity(_ row: ScheduleStore) -> some View {
        HStack(spacing: 0) {
            plain(row.region, 110)
            plain(row.division, 120)
            plain(row.district, 72)
            plain(row.om, 120)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.store)
                    .foregroundStyle(AppTheme.text)
                if row.notScheduled {
                    Text("Not scheduled yet")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .font(cellFont)
            .frame(width: 120, alignment: .leading)
        }
    }

    private func metrics(_ row: ScheduleStore) -> some View {
        let gray = row.notScheduled
        return HStack(spacing: 0) {
            plain(HeartbeatFormat.money(row.sales), 96)
            heat(HeartbeatFormat.pct(row.under), 72, ScheduleCheckMath.percentHealth(row.under, notScheduled: gray))
            heat(HeartbeatFormat.pct(row.over), 64, ScheduleCheckMath.percentHealth(row.over, notScheduled: gray))
            heat(HeartbeatFormat.pct(row.fourUnder), 88, ScheduleCheckMath.percentHealth(row.fourUnder, notScheduled: false))
            heat(HeartbeatFormat.pct(row.eff), 72, ScheduleCheckMath.effHealth(row.eff, notScheduled: gray))
            plain(HeartbeatFormat.pct(row.pch), 88)
            plain(row.hitUnder ? "Yes" : "—", 52)
            plain(row.hitFourWeek ? "Yes" : "—", 56)
            plain(row.hitOver ? "Yes" : "—", 52)
        }
    }

    private func days(_ row: ScheduleStore) -> some View {
        let gray = row.notScheduled
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                let under = index < row.dayUnder.count ? row.dayUnder[index] : nil
                let over = index < row.dayOver.count ? row.dayOver[index] : nil
                heat(HeartbeatFormat.pct(under), 52, ScheduleCheckMath.percentHealth(under, notScheduled: gray))
                heat(HeartbeatFormat.pct(over), 52, ScheduleCheckMath.percentHealth(over, notScheduled: gray))
            }
        }
    }

    private func plain(_ text: String, _ width: CGFloat) -> some View {
        Text(text.isEmpty ? "—" : text)
            .font(cellFont)
            .foregroundStyle(AppTheme.text)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.vertical, 6)
            .frame(width: width, alignment: .leading)
    }

    private func heat(_ text: String, _ width: CGFloat, _ health: Health) -> some View {
        Text(text)
            .font(cellFont.weight(.semibold))
            .foregroundStyle(ink(health))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.vertical, 6)
            .frame(width: width, alignment: .leading)
            .background(wash(health))
    }

    private func sorted(_ rows: [ScheduleStore]) -> [ScheduleStore] {
        rows.sorted { lhs, rhs in
            let cmp = compare(lhs, rhs)
            if cmp == 0 { return HeartbeatFormat.storeOrder(lhs.store, rhs.store) }
            return ascending ? cmp < 0 : cmp > 0
        }
    }

    private func compare(_ lhs: ScheduleStore, _ rhs: ScheduleStore) -> Int {
        switch sort {
        case .store:
            return HeartbeatFormat.storeOrder(lhs.store, rhs.store) ? -1 : (lhs.store == rhs.store ? 0 : 1)
        case .division:
            let order = lhs.division.localizedStandardCompare(rhs.division)
            if order == .orderedSame { return 0 }
            return order == .orderedAscending ? -1 : 1
        case .sales:
            return pair(lhs.sales, rhs.sales)
        case .under:
            return pair(lhs.under, rhs.under)
        case .over:
            return pair(lhs.over, rhs.over)
        case .fourUnder:
            return pair(lhs.fourUnder, rhs.fourUnder)
        case .eff:
            return pair(lhs.eff, rhs.eff)
        case .pch:
            return pair(lhs.pch, rhs.pch)
        }
    }

    private func pair(_ lhs: Double?, _ rhs: Double?) -> Int {
        switch (lhs, rhs) {
        case let (left?, right?) where left < right: return -1
        case let (left?, right?) where left > right: return 1
        case (nil, _?): return 1
        case (_?, nil): return -1
        default: return 0
        }
    }

    private var kpiColumns: [GridItem] {
        let count = HubLayout.runsOnMac ? 4 : (sizeClass == .regular ? 3 : 2)
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    private var pagePadding: CGFloat { HubLayout.runsOnMac ? 24 : 12 }

    private var cellFont: Font { HubLayout.runsOnMac ? .subheadline : .caption }

    private func ink(_ health: Health?) -> Color {
        switch health {
        case .good: return AppTheme.ok
        case .watch: return AppTheme.warn
        case .risk: return AppTheme.bad
        case .some(.none): return AppTheme.textTertiary
        case nil: return AppTheme.text
        }
    }

    private func wash(_ health: Health?) -> Color {
        switch health {
        case .good: return AppTheme.okSoft
        case .watch: return AppTheme.warnSoft
        case .risk: return AppTheme.badSoft
        case .some(.none): return AppTheme.tableFill
        case nil: return Color.clear
        }
    }
}
