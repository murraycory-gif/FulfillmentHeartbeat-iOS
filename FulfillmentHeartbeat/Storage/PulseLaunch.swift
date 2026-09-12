import Foundation

/// Launch and refresh rules for the on-device SQLite pack.
/// Keep this off the network and off SwiftUI so the boot path can be tested.
enum PulseLaunch {
    static let minimumPackBytes = 50_000
    static let stagingFileName = "heartbeat-cloud.sqlite"
    static let bootDownloadTimeout: TimeInterval = 60
    /// Let the hub settle before expanding grains. Cards already painted.
    static let grainPaintDelayNanoseconds: UInt64 = 2_800_000_000
    /// First scroll / nav after Dashboard lands must not fight pack/grain/picker work.
    static let hubFirstInteractionNanoseconds: UInt64 = 1_200_000_000
    /// Stream shoppers after splash so the dashboard card fills. Never on splash.
    static let streamPickerAfterReady = true
    /// After ready, first chunk only — do not await the rest of the pack.
    static let streamPickerSnappyAfterReady = true
    /// Shopper SQL stays off Dashboard. Streaming the full pack after ready
    /// plus per-store `sameStore` scans Jetsamed ~5GB on iPad (build 672).
    static func shouldStreamPickerOnDashboard() -> Bool { false }
    /// Hard cap so a join-page stream cannot grow without bound.
    static let pickerWarehouseCap = 4_000
    /// Do not start shopper streaming until Who's looking is done and the hub can scroll.
    static func shouldDeferPickerStreamUntilHubQuiet() -> Bool { true }
    /// Expand-table prefetch waits so it cannot steal the first scroll/nav turn.
    static func shouldDeferGrainTablesUntilHubQuiet() -> Bool { true }
    static let loadPageOnlyOnReady = false
    /// First shoppers so Picker / dashboard paint before the rest of the pack.
    static let pickerFirstPaintCount = 80
    static let pickerChunkCount = 250
    static let pickerUIStampStride = 800
    /// Yield so post-ready streaming cannot peg the CPU.
    static let pickerChunkPauseNanoseconds: UInt64 = 120_000_000

    /// Pages that join shopper rows into store tables after the pack is ready.
    static func needsShopperJoin(_ dest: HubDestination) -> Bool {
        dest == .pickerScorecard || dest == .pph || dest == .dynacap || dest == .pickPath
    }

    static func shouldStampPicker(
        replace: Bool,
        dest: HubDestination,
        count: Int,
        lastStampCount: Int
    ) -> Bool {
        guard needsShopperJoin(dest) else { return false }
        if replace { return true }
        return count - lastStampCount >= pickerUIStampStride
    }

    /// Heavy picker chrome only on join pages. Dashboard parks the warehouse without a SwiftUI stamp.
    static func shouldRefreshPickerChrome(replace: Bool, dest: HubDestination, stamp: Bool) -> Bool {
        guard needsShopperJoin(dest) else { return false }
        return replace || stamp
    }

    /// Skip SwiftUI / filterStamp work when a background chunk has nothing new to show.
    static func shouldTouchPickerUI(stamp: Bool, chrome: Bool) -> Bool {
        stamp || chrome
    }

    static func pickerRowKey(_ row: MetricRow) -> String {
        "\(row.storeNumber)|\(HeartbeatMath.canonicalShopper(row.shopperKey))"
    }

    static func mergePickerRows(existing: [MetricRow], incoming: [MetricRow]) -> [MetricRow] {
        guard !existing.isEmpty else { return incoming }
        guard !incoming.isEmpty else { return existing }
        var map: [String: MetricRow] = [:]
        map.reserveCapacity(existing.count + incoming.count)
        for row in existing {
            map[pickerRowKey(row)] = row
        }
        for row in incoming {
            map[pickerRowKey(row)] = row
        }
        return Array(map.values)
    }

    struct PPHPickerIndex: Equatable {
        var rows: [String: [MetricRow]] = [:]
        var counts: [String: Int] = [:]
    }

    /// One pass over shoppers. Keys include store aliases so "304" / "0304" hit the same bucket.
    static func pphPickerIndex(_ scorecard: [MetricRow]) -> PPHPickerIndex {
        var canonical: [String: [MetricRow]] = [:]
        canonical.reserveCapacity(min(scorecard.count, 2_048))
        for row in scorecard where row.number("pph") != nil {
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            guard !store.isEmpty else { continue }
            canonical[store, default: []].append(row)
        }
        var rows: [String: [MetricRow]] = [:]
        var counts: [String: Int] = [:]
        let aliases = canonical.count * 4
        rows.reserveCapacity(aliases)
        counts.reserveCapacity(aliases)
        for (store, group) in canonical {
            let n = group.count
            for alias in HeartbeatMath.storeAliases(store) {
                rows[alias] = group
                counts[alias] = n
            }
        }
        return PPHPickerIndex(rows: rows, counts: counts)
    }

    /// O(1). Missing key is 0 — never scan the shopper pack on the UI path.
    static func pphPickerCount(store: String, counts: [String: Int]) -> Int {
        let want = HeartbeatMath.canonicalStore(store)
        if want.isEmpty { return 0 }
        return counts[want] ?? counts[store] ?? 0
    }

    /// Sum O(1) lookups. Used by PPH rollup so body/rebuild never calls `pphPickers`.
    static func pphPickerTotal(storeNumbers: [String], counts: [String: Int]) -> Int {
        var total = 0
        for store in storeNumbers {
            total += pphPickerCount(store: store, counts: counts)
        }
        return total
    }

    /// Do not restart grain expand just because the user swiped back to Dashboard.
    static func shouldRestartGrainPaint(alreadySettled: Bool, dest: HubDestination) -> Bool {
        dest == .dashboard && !alreadySettled
    }

    static func shopperEmptyDetail(loading: Bool) -> String {
        loading
            ? "Loading shoppers…"
            : "Shoppers fill from the Heartbeat pack after ready."
    }

    /// Drop a paint or grain job when the user picked another filter.
    static func acceptPaint(generation: Int, current: Int, cancelled: Bool) -> Bool {
        !cancelled && generation == current
    }

    static func shouldPaintGrains(dashboardVisible: Bool, ready: Bool, rolePicked: Bool) -> Bool {
        dashboardVisible && ready && rolePicked
    }

    static func shouldRefreshPageOnly(pageVisible: Bool) -> Bool {
        pageVisible
    }

    /// Clear-all must flip pills / filterStamp on the same turn as the tap.
    static func shouldAcknowledgeFilterClearImmediately(previousActive: Bool, nextActive: Bool) -> Bool {
        previousActive && !nextActive
    }

    /// Company-wide chrome is always Regions 4 — never the last seat's store grain.
    static func shouldUseCompanyGrainWhenFiltersClear() -> Bool { true }

    /// Unfiltered pulse / Clear restore must paint East / South / California / West.
    static func unfilteredDashboardGrain() -> DashScopeGrain { .region }

    /// Seat grain only while a filter is on. Clear returns the 4-region book.
    static func dashboardGrain(filters: DashboardFilters, sessionRole: HeartbeatRole?) -> DashScopeGrain {
        if !filters.store.isEmpty || !filters.om.isEmpty || !filters.district.isEmpty {
            return .store
        }
        if !filters.division.isEmpty { return .district }
        if !filters.region.isEmpty { return .division }
        if shouldUseCompanyGrainWhenFiltersClear() { return .region }
        return sessionRole?.dashboardGrain ?? .region
    }

    /// Last-seat pending filters apply once. Clear / a new seat pick must not bounce them back.
    static func shouldDiscardPendingLaunchFiltersOnClear() -> Bool { true }

    static func shouldDiscardPendingLaunchFiltersOnRolePick() -> Bool { true }

    static func consumePendingLaunchFilters(
        pending: DashboardFilters?,
        filtersActive: Bool,
        needsRolePick: Bool
    ) -> (apply: DashboardFilters?, remaining: DashboardFilters?) {
        if needsRolePick { return (nil, pending) }
        guard let pending, pending.isActive else { return (nil, nil) }
        if filtersActive { return (nil, nil) }
        return (pending, nil)
    }

    /// Changing filters can coalesce; clear-all paints with no extra wait.
    static func filterPaintDelayNanoseconds(clearingAll: Bool) -> UInt64 {
        clearingAll ? 0 : 32_000_000
    }

    /// Restore the last company-wide pulse so tables are not stuck on the old filter.
    static func shouldRestoreUnfilteredPulseOnClear(hasCompanyWideCache: Bool) -> Bool {
        hasCompanyWideCache
    }

    /// Sidebar open/close must flip on the tap. Detail width stays put (no dashboard reflow).
    static func shouldAcknowledgeSidebarToggleImmediately() -> Bool { true }

    /// Keep the dashboard at full width while the pages drawer is open.
    static func shouldKeepDetailWidthWhenSidebarOpens() -> Bool { true }

    /// Paint cached banner + callouts on the tap. Do not leave a blank host.
    static func shouldPaintDestinationChromeImmediately() -> Bool { true }

    /// Scorecard store tables wait one turn so the new page's chrome can paint first.
    static func shouldPaintScorecardTablesAfterChrome() -> Bool { true }

    /// Grain paint / picker stream wait until the destination's first paint has committed.
    static func shouldDeferDestinationWorkOnNav() -> Bool { true }

    /// Seats are pickable from dashboard filter chips. Do not lock the hub
    /// behind a warehouse / company-pack read on a role gate.
    static func shouldHoldSeatPickerUntilWarehouseReady() -> Bool { false }

    /// Who's looking is not a required cold-open wall.
    static func shouldRequireRoleGateOnColdOpen() -> Bool { false }

    /// Single presenter lock. Cold open is company Command Center — RoleGateView
    /// must not mount from RootView, hub overlay, import, or a stuck needsRolePick.
    static func shouldMountRoleGate(needsRolePick: Bool) -> Bool {
        guard shouldRequireRoleGateOnColdOpen() else { return false }
        guard !shouldOpenCompanyCommandCenterOnColdOpen() else { return false }
        return needsRolePick
    }

    /// Cold open paints Command Center from the published company seat pack.
    static func shouldOpenCompanyCommandCenterOnColdOpen() -> Bool { true }

    /// Hide the header "Who's looking" pill. Seat changes are filter chips only.
    static func shouldShowRoleGatePill() -> Bool { false }

    /// Boot must not download/read the company seat object before the hub.
    /// Company install *is* the cold-open paint, via `swapToSeatPack(.company)`.
    static func shouldCacheCompanySeatChromeOnBootCriticalPath() -> Bool { false }

    /// If a role gate is ever shown, leave it before warehouse work.
    static func shouldLeaveRoleGateBeforeSeatWarehouse() -> Bool { true }

    /// A finished swap must publish Command Center chrome. Silent reuse is a no-op.
    static func shouldPublishCommandCenterAfterSeatSwap() -> Bool { true }

    /// Missing / unreadable seat pack is an error, not "keep the last tiles."
    static func shouldSilentNoOpOnSeatSwapFailure() -> Bool { false }

    /// Per-page Walkthrough / coach marks are gone — they blocked page open.
    static func shouldPresentCoachTours() -> Bool { false }

    /// One load only. No hub "building tables" banner after splash.
    static func shouldShowHubFillBanner(needsRolePick: Bool, warehouseHydrating: Bool) -> Bool {
        _ = needsRolePick
        _ = warehouseHydrating
        return false
    }

    /// RoleGate is Who's looking — never a second full-screen load.
    static func shouldShowSeatLoadStageOnRoleGate() -> Bool { false }

    /// Dashboard under Who's looking must not rebuild on every wave paint.
    static func shouldStampUIDuringRolePick() -> Bool { false }

    /// Who's looking is a full page — never a veil over a live hub.
    /// Overlaying MainHubView kept the pager + dashboard mounted and invalidating
    /// under the picker; that is the lag on the first vertical swipe after Continue.
    static func shouldMountHubUnderRoleGate() -> Bool { false }

    /// Horizontal UIPageViewController wrapping SwiftUI ScrollView fights vertical
    /// drags (nested UIScrollView). Sidebar / page taps still switch via HubRouter.
    static func shouldUsePagingScroll() -> Bool { false }

    /// Remounting every page with `.id` rebuilds the whole List on each sidebar tap.
    static func shouldRemountPageOnDestinationChange() -> Bool { false }

    /// Store row trees stay unbuilt until the chevron opens.
    static func shouldDeferStoreRowBuildUntilExpanded() -> Bool { true }

    /// Expand reads cache/packs only. Never walk the warehouse on the tap turn.
    static func shouldBuildExpandTableOffMain() -> Bool { true }

    /// Filling expand cache must not `filterStamp` the hub.
    static func shouldStampHubWhenExpandCacheFills() -> Bool { false }

    /// Warehouse / grain paints must not remount page tables while the user scrolls.
    static func shouldStampHubOnWarehousePaint() -> Bool { false }

    /// Grain / pageOnly / picker install must not bump `filterStamp` (25 rebuild sites).
    static func shouldStampGrainOrPageOnlyFill() -> Bool { shouldStampHubOnWarehousePaint() }

    /// Picker dashboard + `installSectionSlice` stay objectWillChange-only.
    static func shouldStampPickerOrPageOnlyInstall() -> Bool { false }

    /// Grain / pageOnly / picker cache writes must not invalidate the hub.
    /// `objectWillChange` remounts MainHub + page List the same way `filterStamp` did.
    static func shouldInvalidateHubOnBackgroundFill() -> Bool { false }

    /// Scorecard SQLite waits until chrome has committed so a sidebar tap stays snappy.
    static func shouldDeferSectionSQLUntilAfterChrome() -> Bool { true }

    static var pageSectionLoadDelayNanoseconds: UInt64 { 180_000_000 }

    /// Keep Dashboard mounted so returning from a scorecard is not a full remount.
    static func shouldKeepDashboardHostWarm() -> Bool { true }

    /// Keep the last N scorecard hosts mounted so sidebar switches are not a List teardown.
    /// Hidden scorecard Lists remounted on every EnvironmentObject ping and
    /// cooked the iPad after District Continue. Dashboard host stays warm.
    /// iPad / Mac stay off. iPhone Pages switches keep visited PhoneSectionPage hosts.
    static func shouldKeepVisitedScorecardHostsWarm() -> Bool { false }

    static func shouldKeepVisitedScorecardHostsWarmOnPhone() -> Bool { true }

    static func shouldKeepVisitedScorecardHostsWarm(phone: Bool) -> Bool {
        phone ? shouldKeepVisitedScorecardHostsWarmOnPhone() : shouldKeepVisitedScorecardHostsWarm()
    }

    /// Hidden phone scorecards keep the host; they must not rebuild grain/store
    /// cards on every HeartbeatStore ping (that is the old iPad cook).
    static func shouldRenderHiddenPhoneSectionHeavy() -> Bool { false }

    /// First phone section frame is hero + seat chips only. Grain / stores /
    /// picker lists wait one turn so Pages → Sales paints immediately.
    static func shouldDeferPhoneSectionHeavyUntilAfterChrome() -> Bool { true }

    /// Leaving a scorecard parks SQL (cancels in-flight). Returning reloads
    /// only if the warehouse still needs it.
    static func shouldCancelInFlightSectionSQLOnPageSwitch() -> Bool { true }

    /// Pages / sidebar destination wins over a leftover Command Center push.
    static func shouldPreferVisibleSectionOverPush() -> Bool { true }

    /// Pages / sidebar open is destination-based. Drop a leftover CC push so
    /// Labor is not still Sales after Pages → Labor.
    static func shouldClearPhonePushOnPagesOpen() -> Bool { true }

    /// Filter chip on a phone section: hero/chips from new chrome first,
    /// then grain / stores / picker on the next frame.
    static func shouldProgressivePaintPhoneSectionOnFilterSwap() -> Bool { true }

    static func shouldParkHiddenPhoneSection(isVisible: Bool) -> Bool {
        !isVisible && !shouldRenderHiddenPhoneSectionHeavy()
    }

    /// Warm dashboard + empty `warmScorecards` left Mac/iPad section taps blank.
    /// Always paint the opened scorecard — every platform, same host.
    static func shouldPaintVisibleScorecardOverWarmDashboard() -> Bool { true }

    static func visibleScorecardSections(
        current: HubDestination,
        warmed: [MetricSection],
        pushed: MetricSection? = nil
    ) -> [MetricSection] {
        guard shouldPaintVisibleScorecardOverWarmDashboard() else { return warmed }
        guard let section = activeScorecardSection(visible: current, pushed: pushed) else { return warmed }
        if warmed.contains(section) { return warmed }
        var next = warmed
        next.append(section)
        return next
    }

    /// One seat-swap plane for Clear, filter pills, and Continue.
    /// Cached chrome first. Never re-download a usable file. Never remount.
    enum SeatSwapPlan: Equatable {
        case reuseInPlace
        case paintCachedThenSwap
        case installLocalPack
        case downloadMissingPack
    }

    typealias CompanyClearPlan = SeatSwapPlan

    static func shouldReuseCachedCompanySeatOnClear() -> Bool { true }
    /// After a newer cloud pack lands, drop in-memory company chrome so Clear cannot paint Wednesday.
    static func shouldInvalidateCachedCompanySeatAfterCloudPromote() -> Bool { true }
    /// Clear / filter chips stay local. A newer cloud pack must replace the seat file anyway.
    static func shouldForceRedownloadCompanySeatWhenRemoteNewer() -> Bool { true }
    static func shouldSwapToCompanySeatAfterCloudPromote() -> Bool { true }
    static func shouldSyncCompanySeatAfterCloudHydrate() -> Bool { true }
    static func shouldRedownloadUsableCompanySeat() -> Bool { false }
    static func shouldWipeWarehouseBeforeCachedCompanyChrome() -> Bool { false }
    static func shouldStampHubOnClearToCompany() -> Bool { false }

    /// Filter pills use the same seat-swap rewrite as Clear.
    static func shouldReuseCachedSeatPackOnFilterChange() -> Bool { true }
    static func shouldRedownloadUsableSeatOnFilterChange() -> Bool { false }
    static func shouldStampHubOnFilterSwap() -> Bool { false }

    /// Clear / Company must call `swapToSeatPack(.company)` — never dual-wave
    /// market `restoreCompanyPack` as the primary.
    static func shouldClearCompanyViaSwapToSeatPack() -> Bool { true }
    static func shouldUseDualWaveMarketRestoreAsClearPrimary() -> Bool { false }

    static func shouldStampHubOnSeatSwap(clearingToCompany: Bool) -> Bool {
        clearingToCompany ? shouldStampHubOnClearToCompany() : shouldStampHubOnFilterSwap()
    }

    static func shouldRedownloadUsableSeatPack() -> Bool {
        shouldRedownloadUsableCompanySeat() || shouldRedownloadUsableSeatOnFilterChange()
    }

    static func seatSwapPlan(
        localUsable: Bool,
        alreadyOnPack: Bool,
        hasCachedChrome: Bool,
        forceReload: Bool = false
    ) -> SeatSwapPlan {
        if !localUsable { return .downloadMissingPack }
        if forceReload { return .installLocalPack }
        if alreadyOnPack, hasCachedChrome { return .reuseInPlace }
        if hasCachedChrome { return .paintCachedThenSwap }
        return .installLocalPack
    }

    static func companyClearPlan(
        localCompanyUsable: Bool,
        alreadyOnCompany: Bool,
        hasCompanyChrome: Bool
    ) -> CompanyClearPlan {
        seatSwapPlan(
            localUsable: localCompanyUsable,
            alreadyOnPack: alreadyOnCompany,
            hasCachedChrome: hasCompanyChrome
        )
    }

    /// `factsOwned` may stay true after a pack wipe left `latestBySection` empty.
    /// Early-return only when the owned warehouse actually has rows.
    static func shouldEarlyReturnOwnedSection(owned: Bool, rowCount: Int) -> Bool {
        owned && rowCount > 0
    }

    /// Wipe on pack swap must drop ownership so the next sqlite read is allowed.
    static func packSwapClearsFactOwnership() -> Bool { true }

    /// Warm / hidden pages must not rebuild Lists on hub pings.
    static func shouldRebuildHiddenWarmHostsOnHubPing() -> Bool { false }

    static func shouldRebuildPageOnFilterStamp(pageVisible: Bool) -> Bool {
        pageVisible || shouldRebuildHiddenWarmHostsOnHubPing()
    }

    /// `applySeatSliceNow` paints card chrome only. Grain tables fill off-main.
    static func shouldBuildGrainTablesOnSeatSlice() -> Bool { false }

    /// Flag grids walk every section on the Continue turn. Skip — paint fills later.
    static func shouldBuildCardFlagsOnSeatSlice() -> Bool { false }

    /// `lockPickerDashboard` builds the expand table on main. Seat readStores locks after.
    static func shouldLockPickerDashboardOnSeatSlice() -> Bool { false }

    /// Roster option rebuild is not Continue-turn work.
    static func shouldRefreshFilterOptionsOnSeatSlice() -> Bool { false }

    /// Full `paintFromWarehouse(light: false)` rebuilt every card's grain table
    /// and Jetsamed iPad ~4GB. Company expand is page/stream only.
    static func shouldScheduleLiveGrainPaint(filtersActive: Bool) -> Bool {
        _ = filtersActive
        return false
    }

    /// Never prefill all `MetricSection.dashboardCards` grainTables into RAM.
    /// Company is chrome + page SQL. District fills the open scorecard.
    static func shouldPrefillExpandTables(filtersActive: Bool) -> Bool {
        _ = filtersActive
        return false
    }

    /// LazyVStack card appear must not start 12 expand jobs while scrolling.
    static func shouldPrefetchExpandOnAppear() -> Bool { false }

    /// Seat picker paint must rebuild Healthy / Watch / At Risk from seat rows.
    static func shouldRebuildPickerIndexOnSeatPaint(filtersActive: Bool, seatRowCount: Int) -> Bool {
        filtersActive && seatRowCount > 0
    }

    static func shouldWipePickerIndexOnSeatClear() -> Bool { true }

    /// Continue / a new seat must drop the company index before readStores lands.
    static func shouldWipePickerIndexOnSeatApply() -> Bool { true }

    /// Company pulse / cache / heavy extras must not replace seat buckets.
    static func shouldRejectCompanyPickerIndexUnderSeat() -> Bool { true }

    static func pickerIndexMatchesSeat(visibleCount: Int, indexedAll: Int) -> Bool {
        visibleCount > 0 && indexedAll == visibleCount
    }

    static func maxWarmScorecardHosts(phone: Bool = false) -> Int {
        phone ? 12 : 2
    }

    static func warmScorecardList(
        existing: [MetricSection],
        incoming: MetricSection?,
        cap: Int = maxWarmScorecardHosts()
    ) -> [MetricSection] {
        guard let incoming else { return existing }
        var next = existing.filter { $0 != incoming }
        next.append(incoming)
        if next.count > cap {
            next.removeFirst(next.count - cap)
        }
        return next
    }

    /// Store snap trees stay empty until the user opens the HubStoreCard.
    static func shouldBuildStoreSnapsWhileCollapsed() -> Bool { false }

    static func shouldSkipCollapsedStoreRebuild(expanded: Bool) -> Bool {
        !expanded && !shouldBuildStoreSnapsWhileCollapsed()
    }

    /// Scorecard seat from the active filter. Most specific chip wins.
    enum SectionPageSeat: String, Equatable {
        case company
        case region
        case division
        case district
        case om
        case store
    }

    static func sectionPageSeat(filters: DashboardFilters) -> SectionPageSeat {
        if !filters.store.isEmpty { return .store }
        if !filters.om.isEmpty { return .om }
        if !filters.district.isEmpty { return .district }
        if !filters.division.isEmpty { return .division }
        if !filters.region.isEmpty { return .region }
        return .company
    }

    /// Filter → tables on every MetricSection detail page.
    /// Company: Regions + Markets. Region: Markets. Division: Districts + Stores.
    /// District / OM / Store: Stores once. Never a .store-grain rollup on top.
    static func sectionRollupGrains(filters: DashboardFilters) -> [DashScopeGrain] {
        switch sectionPageSeat(filters: filters) {
        case .company: return [.region, .division]
        case .region: return [.division]
        case .division: return [.district]
        case .district, .om, .store: return []
        }
    }

    /// Store-row tables: Division + District + OM + Store. Never Company / Region.
    static func shouldShowStoreTable(filters: DashboardFilters) -> Bool {
        switch sectionPageSeat(filters: filters) {
        case .division, .district, .om, .store: return true
        case .company, .region: return false
        }
    }

    /// Picker ScoreCard: exactly one shoppers table on Division / District / OM / Store.
    static func shouldShowPickerShoppersTable(filters: DashboardFilters) -> Bool {
        switch sectionPageSeat(filters: filters) {
        case .division, .district, .om, .store: return true
        case .company, .region: return false
        }
    }

    /// Top Opportunity / Doing well panel. Every seat, including Company (Cory iPhone shot).
    static func shouldShowPickerHighlights(filters: DashboardFilters) -> Bool {
        _ = filters
        return true
    }

    /// MUST H: Mac Catalyst Top Opportunity Pickers always keeps column headers.
    /// Phone cards stay headerless. iPad regular tables also keep headers.
    static func shouldShowPickerHighlightColumnHeaders(phone: Bool, mac: Bool = false) -> Bool {
        mac || !phone
    }

    /// Mac never uses phone picker cards for Top Opportunity — table + headers.
    static func shouldUsePickerHighlightPhoneCards(phone: Bool, mac: Bool = false) -> Bool {
        !mac && phone
    }

    /// Individual shopper picture strip / person cards. Division / District / OM / Store only.
    /// Never on total Company (or Region).
    static func shouldShowPickerIndividualPictures(filters: DashboardFilters) -> Bool {
        switch sectionPageSeat(filters: filters) {
        case .division, .district, .om, .store: return true
        case .company, .region: return false
        }
    }

    /// Empty “No shoppers in all shoppers” only when nothing already rendered in cohorts.
    static func shouldShowPickerAllShoppersEmpty(tableCount: Int, cohortCount: Int) -> Bool {
        tableCount == 0 && cohortCount == 0
    }

    /// Sales ScoreCard: week total + by-day above the grain rollup. Every filter seat.
    static func shouldShowSalesDayWeekBlock(filters: DashboardFilters) -> Bool {
        _ = filters
        return true
    }

    /// iPhone 13+ : idiom or compact always wins. Width < 600 only helps iPad split.
    /// Cached device profile is not consulted — that left 718 painting pad tables.
    static func shouldUsePickerPhoneCards(
        compact: Bool = false,
        phoneIdiom: Bool = false,
        phone: Bool = false,
        width: CGFloat = 0,
        mac: Bool = false
    ) -> Bool {
        if mac && !shouldApplyPhoneCompactChromeOnMac() { return false }
        if compact || phoneIdiom || phone { return true }
        return width > 0 && width < 600
    }

    /// Pad shopper/rollup headers must not exist in the phone view tree.
    /// Mac Catalyst compact windows still keep pad tables (MUST H / MUST M).
    static func shouldRefusePadShopperTable(
        compact: Bool = false,
        phoneIdiom: Bool = false,
        mac: Bool = false
    ) -> Bool {
        if mac && !shouldApplyPhoneCompactChromeOnMac() { return false }
        return compact || phoneIdiom
    }

    /// iPhone Pages list opens the destination on the first tap.
    static func shouldOpenPhonePagesOnFirstTap() -> Bool { true }

    /// Phone Pages icons use section health (same paint as iPad / Mac).
    static func shouldTintPhonePagesIconsWithHealth() -> Bool { true }

    /// Apple HIG ~44×44pt minimum on phone chrome. Mac / iPad keep their own sizes.
    /// Literal 44 — kitchen copies this file and must not import HubLayout / SwiftUI.
    static func phoneMinimumHitTarget() -> CGFloat { 44 }

    /// Markets/Regions never invent Unassigned from non-roster noise (Week 27: 21 / no %).
    /// Cooked Excel roster has 0 blank MARKET. Honest Unassigned only for roster stores
    /// that still have district/OM and a blank market after stamp.
    static func shouldHideUnassignedMarketGrain() -> Bool { true }

    /// StoreIdentity keys come from Excel Roster only when that sheet is present.
    static func shouldRosterGateRollupIdentities() -> Bool { true }

    /// Company Labor banner: only when the Power BI Total row is actually missing
    /// and chrome has no live TVA. Seat filters never inherit the global Total.
    static func shouldShowLaborTotalRowWarning(
        filtersActive: Bool,
        hasMarketTotal: Bool,
        hasLiveTVA: Bool
    ) -> Bool {
        !filtersActive && !hasMarketTotal && !hasLiveTVA
    }

    /// Heartbeat Assist is an ops coach: What's wrong / cause / SOP / labor / direction.
    static func shouldUseAssistCoachShape() -> Bool { true }

    static func assistCoachHeadings() -> [String] {
        ["WHAT'S WRONG", "WHAT'S CAUSING IT", "SHOPPER SOP", "LABOR / SCHEDULE", "DIRECTION"]
    }

    /// Pages / filter chips only. No top-left Dashboard chevron on scorecards.
    static func shouldShowScorecardDashboardBackControl() -> Bool { false }

    /// Phone header matches iPad: Pages stays, Back goes. Destination
    /// switches are Pages / Command Center cards — not a chrome chevron.
    /// `HubBrandBar.compactBar` must not mount a Back `HubNavControl`.
    static func shouldShowPhoneHeaderBack() -> Bool { false }

    /// One native vertical ScrollView. Nested UIPageViewController is off.
    static func shouldUseOneNativeVerticalHubScroll() -> Bool { !shouldUsePagingScroll() }

    /// Any higher-grain rollup on this scorecard (0–2 tables).
    static func shouldMountSectionRollup(filters: DashboardFilters) -> Bool {
        !sectionRollupGrains(filters: filters).isEmpty
    }

    static func shouldSkipStoreRowRebuild(filters: DashboardFilters, expanded: Bool) -> Bool {
        !shouldShowStoreTable(filters: filters) || shouldSkipCollapsedStoreRebuild(expanded: expanded)
    }

    /// Picker SQL must not start on the sidebar tap turn.
    static func shouldStartPickerStreamOnDestinationSwitch() -> Bool { false }

    /// Seat page-open first paint is `readStores(allowed)`, not company `streamPicker`.
    static func shouldLoadSeatPickerOnPageOpen(filtersActive: Bool) -> Bool { filtersActive }

    /// Every dashboard / join page uses the same seat pack path under a filter.
    static func shouldLoadSeatSectionOnPageOpen(filtersActive: Bool) -> Bool { filtersActive }

    /// Company chunk stream must not be the District first paint (often 0 shoppers).
    static func shouldStreamCompanyPickerForSeatFirstPaint() -> Bool { false }

    enum PickerPageFirstPaint: Equatable {
        case seatReadStores
        case companyStream
    }

    static var pageOpenSections: [MetricSection] {
        MetricSection.allCases
    }

    static func sectionPageFirstPaint(
        section: MetricSection,
        filtersActive: Bool
    ) -> PickerPageFirstPaint {
        if shouldLoadSeatSectionOnPageOpen(filtersActive: filtersActive),
           !shouldStreamCompanyPickerForSeatFirstPaint() {
            return .seatReadStores
        }
        return .companyStream
    }

    static func pickerPageFirstPaint(filtersActive: Bool) -> PickerPageFirstPaint {
        sectionPageFirstPaint(section: .pickerScorecard, filtersActive: filtersActive)
    }

    static func sectionNeedsShopperJoin(_ section: MetricSection) -> Bool {
        section == .pph || section == .dynacap || section == .pickPath
    }

    /// Join pages may stream company shoppers only when no seat filter is on.
    static func shouldStartCompanyPickerStreamOnJoinPage(filtersActive: Bool) -> Bool {
        !filtersActive && !shouldStreamCompanyPickerForSeatFirstPaint()
    }

    /// Hub-wide EnvironmentObject ping when seat shoppers land. Off — that
    /// remounts MainHub + warm Lists on the scroll thread after District
    /// Continue. Fill stays silent like grain; Picker page reads `pickerFacts`.
    static func shouldPublishPickerSeatFirstPaint() -> Bool { false }

    /// Join pages may ping once so a mid-fill Picker open still paints.
    /// Dashboard / other seats must not.
    static func shouldPublishPickerSeatOnVisiblePage(dest: HubDestination) -> Bool {
        !shouldPublishPickerSeatFirstPaint() && needsShopperJoin(dest)
    }

    /// First District scroll after Continue. Fills stay chrome-only.
    static func shouldAllowHubInvalidateDuringQuietScroll() -> Bool { false }

    static func hubQuietScrollNanoseconds() -> UInt64 { hubFirstInteractionNanoseconds }

    static func hubScrollSettled(interactiveAt: Date?, now: Date = Date()) -> Bool {
        guard let start = interactiveAt else { return false }
        return now.timeIntervalSince(start) >= Double(hubQuietScrollNanoseconds()) / 1_000_000_000
    }

    /// Publish seat shoppers only after the first scroll window — never during
    /// hub-quiet + active scroll. Chrome-only until then.
    static func shouldPublishSeatFill(
        dest: HubDestination,
        interactiveAt: Date?,
        now: Date = Date()
    ) -> Bool {
        if shouldPublishPickerSeatFirstPaint() { return false }
        guard shouldPublishPickerSeatOnVisiblePage(dest: dest) else { return false }
        if shouldAllowHubInvalidateDuringQuietScroll() { return true }
        return hubScrollSettled(interactiveAt: interactiveAt, now: now)
    }

    static func shouldStampFilterDuringQuietScroll() -> Bool { false }

    /// `pickerLoading` is `@Published`. Toggling it on Dashboard remounts the hub.
    static func shouldShowPickerLoadingOnSeatFill(dest: HubDestination) -> Bool {
        needsShopperJoin(dest)
    }

    /// `DashScopeStrip.onChange(filterStamp)` must not `prefetchExpand` every
    /// card after District Continue. Grain + picker already filled on the
    /// filter turn; a 12-card prefetch is the residual iPad scroll hitch.
    static func shouldPrefetchExpandOnFilterStamp() -> Bool { false }

    /// One load screen. Do not leave splash early just to show SeatLoadStage.
    static func shouldLeaveSplashForSeatLoad() -> Bool { false }

    /// Who's looking waits until the single load finishes — no second splash.
    static func shouldRevealRoleGateDuringWarehouseLoad() -> Bool { false }

    /// `finishLocalLaunch` must not keep hydrating into a second load stage.
    static func shouldKeepHydratingThroughFinishLocalLaunch() -> Bool {
        shouldRevealRoleGateDuringWarehouseLoad()
            && shouldPresentSeatBeforeWarehouse()
            && shouldHoldSeatPickerUntilWarehouseReady()
    }

    /// Off-actor. `HeartbeatStore` is `@MainActor`; detached pack reads must not hop back.
    static func materializeSectionRows(
        _ rows: [MetricRow],
        section: MetricSection,
        roster: [String: HeartbeatMath.StoreIdentity]
    ) -> [MetricRow] {
        switch section {
        case .labor:
            let stores = rows.filter {
                $0.textPayload["labor_grain"] == "store" && !$0.storeNumber.isEmpty
            }
            let fallback = rows.filter {
                $0.textPayload["labor_grain"] != "market" && !$0.storeNumber.isEmpty
            }
            return HeartbeatMath.applyRoster(
                HeartbeatMath.latestPerStore(stores.isEmpty ? fallback : stores),
                roster: roster
            )
        case .pickerScorecard, .pickPathPicker:
            return HeartbeatMath.applyRoster(HeartbeatMath.latestPerShopper(rows), roster: roster)
        case .lostRevenue:
            let source = rows.filter { $0.textPayload["lost_grain"] != "market" }
            var collapsed = HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(source), roster: roster)
            if let market = rows.first(where: { $0.textPayload["lost_grain"] == "market" }) {
                collapsed.append(market)
            }
            return collapsed
        case .dynacap:
            return HeartbeatMath.materializeDynacap(rows, roster: roster)
        case .pph:
            return HeartbeatMath.materializePPH(rows, roster: roster)
        default:
            return HeartbeatMath.applyRoster(HeartbeatMath.latestPerStore(rows), roster: roster)
        }
    }

    /// Option 8b: Pulse / Power BI Mobile briefing home. Not always-open ScoreCard tables.
    static func shouldUseCommandCenterHome() -> Bool { true }

    /// iPhone Command Center is a 1-column scroll of phone cards — not the
    /// iPad leftover-fill GeometryReader (that is why .392–.395 still looked
    /// like a squeezed pad briefing under the chrome).
    static func shouldUsePhoneNativeCommandCenter() -> Bool { true }

    /// Phone Command Center / THIS SEAT / section pages: tighter cards without
    /// shrinking iPad leftover-fill or Mac dashboard tables.
    static func shouldUseCompactPhoneCommandChrome() -> Bool { true }

    /// Compact phone header + Filters keep 44pt hits but drop title3 chrome.
    static func shouldUseCompactPhoneHeaderChrome() -> Bool { true }

    /// Pad leftover-fill stays on the existing density. Mac uses expanded readable chrome.
    static func shouldLeavePadMacCommandChromeUnchanged() -> Bool { true }

    /// Mac Catalyst / MacBook: bigger type, cards, tables, chips, filter chrome.
    /// Must not apply phone compact shrink. Whole-app scale, not one page.
    static func shouldUseExpandedMacReadableChrome() -> Bool { true }
    static func shouldApplyPhoneCompactChromeOnMac() -> Bool { false }
    static func shouldPaintMacHubDynamicType() -> Bool { true }
    /// Kitchen-safe lock for Mac hub Dynamic Type (HubLayout.MacReadable.dynamicTypeSize).
    static func macReadableDynamicTypeName() -> String { "xxxLarge" }
    /// Every section table / chip atom uses MacReadable metric fonts on Mac.
    static func shouldUseMacReadableMetricAtoms() -> Bool { true }

    /// Every section ScoreCard on iPhone is a 1-column scroll of cards —
    /// same bar as PhoneCommandCenterHome. Pad List + tableFill leftover
    /// stretch is what left Sales as a giant empty white panel on 722.
    static func shouldUsePhoneNativeSectionPages() -> Bool { true }

    /// FILE ROOT: when usesPhoneScorecards, SectionDetail must not mount
    /// List + *RollupTable / *Table hosts. Per-atom phone cards inside
    /// those pad shells is a reject (Sales white panel + By Day smash).
    static func shouldMountPadSectionListHost(usesPhoneScorecards: Bool) -> Bool {
        !(usesPhoneScorecards && shouldUsePhoneNativeSectionPages())
    }

    /// Every HubDestination metric page gets the same phone ScrollView shell.
    static func phoneNativeSectionPages() -> [MetricSection] {
        [
            .sales,
            .lostRevenue,
            .missingItems,
            .fiveStar,
            .preSubOOS,
            .pickPath,
            .prepNotReady,
            .dynacap,
            .scheduleQuality,
            .pickerScorecard,
            .pph,
            .labor,
        ]
    }

    /// Compact HubBrandBar is an HStack. ZStack overlay of Pages/Dashboard
    /// on BeatingHeartbeatMark is what collided on 722.
    static func shouldStackCompactHubBrandHorizontally() -> Bool { true }

    static func shouldOverlayCompactHeartbeatMark() -> Bool { false }

    static func shouldShowCompactHeartbeatWordmark(showBack: Bool) -> Bool {
        !showBack
    }

    /// HB-0828.398: filter swap paints cached/last-good chrome on the tap,
    /// then a cancellable thin pack install. Same speed bar as Pages nav.
    /// Full heavy caches on MainActor after every District / OM / Store chip
    /// is why phone felt frozen.
    static func shouldDeferHeavySeatInstallAfterCachedChrome() -> Bool { true }

    /// Keep heroes / glance / last rows until the incoming pack is ready.
    static func shouldKeepLastGoodSeatUntilIncomingPackReady() -> Bool { true }

    static func shouldUseHeavySeatCachesOnFilterSwap() -> Bool { false }

    static func shouldInstallSeatExpandTablesOnFilterSwap() -> Bool { false }

    /// PhoneCommandCenterHome / NavigationStack stay mounted across filter chips.
    static func shouldRemountPhoneHubOnFilterSwap() -> Bool { false }

    /// keepLastGoodSeat skips wipe, so section SQL must re-run after seatPaint.
    static func shouldReloadSectionSQLOnSeatPaintStamp() -> Bool { true }

    static var deferredSeatInstallDelayNanoseconds: UInt64 { 16_000_000 }

    static func shouldDelaySectionSQL(seatAlreadyPainted: Bool) -> Bool {
        shouldDeferSectionSQLUntilAfterChrome() && !seatAlreadyPainted
    }

    /// Home glance never mounts DashScopeStrip / store tables. Expand is a section open.
    static func shouldMountDashCalloutTablesOnHome() -> Bool { false }

    /// Mac Catalyst Command Center: pinned Pages sidebar + center only.
    static func shouldPinMacCommandCenterRails() -> Bool { true }

    /// Mac header Pages button is redundant once the rail can collapse in-place.
    static func shouldHideMacHeaderPagesButton() -> Bool { true }

    /// User can close the Mac Pages rail; the center then expands to the window.
    static func shouldAllowMacSidebarCollapse() -> Bool { true }

    /// Command Center / callouts must partition the live window — never overflow.
    static func shouldFitMacCommandCenterToWindow() -> Bool { true }

    /// Mac Catalyst window chrome owns the bottom edge. Do not paint under it.
    static func shouldRespectMacWindowSafeArea() -> Bool { true }

    static var macCollapsedSidebarWidth: CGFloat { 56 }
    static let macSidebarExpandedDefaultsKey = "hb.macSidebarExpanded"

    static func loadMacSidebarExpanded() -> Bool {
        if UserDefaults.standard.object(forKey: macSidebarExpandedDefaultsKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: macSidebarExpandedDefaultsKey)
    }

    static func storeMacSidebarExpanded(_ expanded: Bool) {
        UserDefaults.standard.set(expanded, forKey: macSidebarExpandedDefaultsKey)
    }

    /// No right Alerts column on Mac. Simplifies chrome / heat.
    static func shouldPinMacCommandCenterAlertsRail() -> Bool { false }

    /// iPad never pins Mac-style triple columns. Rails stay closed until opened.
    static func shouldPinCommandCenterRailsOnIPad() -> Bool { false }

    /// iPad land + port: Pages is an overlay drawer. Alerts stay off.
    static func shouldOfferIPadCommandCenterDrawers() -> Bool { true }

    /// No iPad Alerts pop-out / rail — same intent as Mac Alerts off.
    static func shouldOfferIPadCommandCenterAlertsDrawer() -> Bool { false }

    /// Halloween parade removed from Who's looking. Comedy copy + readiness stay.
    static func shouldPlaySeatLoadHalloween() -> Bool { false }

    static func shouldMountSeatLoadHalloween(warehouseHydrating: Bool) -> Bool {
        warehouseHydrating && shouldHoldSeatPickerUntilWarehouseReady() && shouldPlaySeatLoadHalloween()
    }

    static func shouldHoldSeatLoadHalloweenMinDwell() -> Bool { false }

    static func seatLoadHalloweenMinDwellNanoseconds() -> UInt64 { 1_400_000_000 }

    static func halloweenDwellRemainingNanoseconds(elapsedNanoseconds: UInt64) -> UInt64 {
        let minimum = seatLoadHalloweenMinDwellNanoseconds()
        return elapsedNanoseconds >= minimum ? 0 : minimum - elapsedNanoseconds
    }

    /// 12 fps Canvas offsets — cheap enough that seat load must not Jetsam.
    static var halloweenParadeFPS: Double { 12 }

    /// Seat warehouse must never leave Who's looking locked at presentingSeat ~40%.
    enum SeatWarehouseOutcome: Equatable {
        case completed
        case timedOut
        case failed
    }

    static func warehouseAfterSeatTimeoutNanoseconds() -> UInt64 { 25_000_000_000 }

    static func seatWarehouseTimeoutMessage() -> String {
        "The store pack timed out. Seats are unlocked — Continue, or Retry if the aisle is empty."
    }

    static func seatWarehouseUnlocksHydrating(_ outcome: SeatWarehouseOutcome) -> Bool { true }

    static func seatWarehouseShowsError(_ outcome: SeatWarehouseOutcome) -> Bool {
        outcome == .timedOut || outcome == .failed
    }

    static func shouldUnlockWarehouseHydratingAfterSeat(
        completed: Bool = false,
        timedOut: Bool = false,
        failed: Bool = false
    ) -> Bool {
        seatWarehouseUnlocksHydrating(
            timedOut ? .timedOut : failed ? .failed : .completed
        )
    }

    /// `true` when the timeout won and seats must unlock with an error.
    static func awaitSeatWarehouse(
        timeoutNanoseconds: UInt64,
        work: @escaping @Sendable () async -> Void
    ) async -> Bool {
        let job = Task { await work() }
        return await awaitSeatWarehouseTask(timeoutNanoseconds: timeoutNanoseconds, work: job)
    }

    static func awaitSeatWarehouseTask<T: Sendable>(
        timeoutNanoseconds: UInt64,
        work: Task<T, Never>
    ) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                _ = await work.value
                return false
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return true
            }
            let first = await group.next() ?? true
            group.cancelAll()
            return first
        }
    }

    /// Page HubStoreCard N is Heartbeat roster stores, not fact-present rows.
    static func hubStoreCardCount(_ rows: [MetricRow]) -> Int {
        uniqueStores(in: rows).count
    }

    /// Card storeCount under a seat is Heartbeat Stores N, not fact coverage.
    /// Company heroes use the same pin against the published roster gold.
    static func pinSeatStoreCount(_ summary: SectionSummary, seatStores: Int) -> SectionSummary {
        guard seatStores > 0 else { return summary }
        var next = summary
        next.storeCount = seatStores
        return next
    }

    /// Company Command Center: one roster gold on every tile (no 2189/2160/2159).
    static func pinCompanyRosterStoreCounts(
        _ summaries: [SectionSummary],
        rosterStores: Int
    ) -> [SectionSummary] {
        guard rosterStores > 0 else { return summaries }
        return summaries.map { pinSeatStoreCount($0, seatStores: rosterStores) }
    }

    /// Company glance / hero card from pack chrome. Summary-first — never a
    /// special picker stream. Lifts published `pickerShoppers` when the thin
    /// company pack dropped shopper tape.
    static func companyCommandCenterCard(
        _ card: SectionSummary,
        chrome: PulseDashChrome?,
        rosterStores: Int
    ) -> SectionSummary {
        var next = card
        if card.section == .pickerScorecard, (card.headline ?? 0) == 0, let chrome {
            if let lifted = pickerSummaryFromChrome(chrome) {
                next = lifted
            }
        }
        return pinSeatStoreCount(next, seatStores: rosterStores)
    }

    /// Sales Regions/Stores expand uses the sales rollup cache, not grain packs.
    /// Prefetch it with grain tables so the chevron is not headers-only.
    static func shouldPrefetchSalesExpandWithGrainTables() -> Bool { true }

    /// Real $ / orders only. An empty sales cache must not look like "Regions 4".
    static func salesExpandIsLive(_ rows: [SalesRollupRow]) -> Bool {
        rows.contains { ($0.pack.sales ?? 0) > 0 || ($0.pack.orders ?? 0) > 0 }
    }

    /// Chevron / table gate. Never open a header shell over an empty body.
    /// Picker is live when grain is live OR the pack/chrome has picker facts
    /// (caller must seed grain before first paint so the body is not empty).
    static func dashboardExpandIsLive(
        section: MetricSection,
        salesRows: [SalesRollupRow],
        grainRows: [HeartbeatMath.DashboardGrainTableRow],
        pickerFacts: Int = 0
    ) -> Bool {
        if section == .sales { return salesExpandIsLive(salesRows) }
        if section == .pickerScorecard {
            if HeartbeatMath.grainRowsAreLive(grainRows) { return true }
            return pickerFacts > 0
        }
        return HeartbeatMath.grainRowsAreLive(grainRows)
    }

    static func pickerFactsExist(
        chrome: PulseDashChrome?,
        latestCount: Int,
        sqliteCount: Int = 0
    ) -> Bool {
        latestCount > 0
            || sqliteCount > 0
            || (chrome?.pickerOK ?? false)
            || (chrome?.card(.pickerScorecard)?.headline ?? 0) > 0
    }

    /// Live expand caches only. Never `packs.count` — `placeholderGrainPacks`
    /// seeds four region lines with value "—" and paints "Regions 4" over headers.
    static func dashboardBannerCount(
        section: MetricSection,
        salesRows: [SalesRollupRow],
        grainRows: [HeartbeatMath.DashboardGrainTableRow]
    ) -> Int {
        guard dashboardExpandIsLive(section: section, salesRows: salesRows, grainRows: grainRows) else {
            return 0
        }
        return section == .sales ? salesRows.count : grainRows.count
    }

    /// Picker expand from pack chrome. Never stay inert when the pack has shoppers.
    /// Prefers the ingest grain table, then live packs, then the chrome board.
    /// A filtered miss on a market/region table must not return that empty scope
    /// (or the company book) — callers then build from seat shoppers.
    static func pickerExpandRows(
        from chrome: PulseDashChrome,
        filters: DashboardFilters = DashboardFilters(),
        grain _: DashScopeGrain = .region
    ) -> [HeartbeatMath.DashboardGrainTableRow] {
        if let encoded = chrome.tables[MetricSection.pickerScorecard.rawValue],
           HeartbeatMath.grainRowsAreLive(encoded) {
            let scoped = grainRowsScopedToFilter(encoded, filters: filters)
            if HeartbeatMath.grainRowsAreLive(scoped) { return scoped }
            if filters.isActive { return [] }
        }
        let packs = chrome.packs[MetricSection.pickerScorecard.rawValue] ?? []
        if !packs.isEmpty {
            let fromPacks = HeartbeatMath.dashboardGrainRowsFromPacks(packs, section: .pickerScorecard)
            if HeartbeatMath.grainRowsAreLive(fromPacks) {
                let scoped = grainRowsScopedToFilter(fromPacks, filters: filters)
                if HeartbeatMath.grainRowsAreLive(scoped) { return scoped }
                if filters.isActive { return [] }
            }
        }
        if filters.isActive { return [] }
        guard chrome.pickerOK else { return [] }
        let shoppers = max(chrome.pickerShoppers, Int(chrome.card(.pickerScorecard)?.headline ?? 0))
        let healthy = max(chrome.pickerStrong, 0)
        let risk = max(chrome.pickerOpportunity, 0)
        let watch = max(shoppers - healthy - risk, 0)
        let row = HeartbeatMath.DashboardGrainTableRow(
            label: "Company",
            storeCount: shoppers,
            values: [
                HeartbeatFormat.num(Double(shoppers)),
                HeartbeatFormat.num(Double(healthy)),
                HeartbeatFormat.num(Double(watch)),
                HeartbeatFormat.num(Double(risk)),
            ],
            health: .none
        )
        return [row]
    }

    /// Seat shoppers first. Unfiltered market packs are a fallback only.
    static func pickerSeatRows(
        filtered: [MetricRow],
        warehouse: [MetricRow],
        allowed: Set<String>?,
        filters: DashboardFilters,
        roster: [String: HeartbeatMath.StoreIdentity] = [:]
    ) -> [MetricRow] {
        if !filtered.isEmpty { return filtered }
        return PulseQuery.sliceSection(
            .pickerScorecard,
            rows: warehouse,
            allowed: allowed,
            filters: filters,
            roster: roster
        )
    }

    /// Filtered expandLive must not use the company chrome head (26,349) as a
    /// fake live signal over an empty district body.
    static func pickerExpandFactCount(
        filteredCount: Int,
        warehouseSlicedCount: Int,
        chromeCount: Int,
        filtersActive: Bool
    ) -> Int {
        if filtersActive {
            return max(filteredCount, warehouseSlicedCount)
        }
        return max(filteredCount, warehouseSlicedCount, chromeCount)
    }

    /// Live expand table for the current seat. Shopper facts win over chrome.
    static func pickerExpandTable(
        seatRows: [MetricRow],
        chrome: PulseDashChrome?,
        filters: DashboardFilters,
        grain: DashScopeGrain,
        packOrder: [String] = []
    ) -> [HeartbeatMath.DashboardGrainTableRow] {
        if !seatRows.isEmpty {
            let table = HeartbeatMath.dashboardGrainTableFilled(
                section: .pickerScorecard,
                rows: seatRows,
                grain: grain,
                order: packOrder
            )
            if pickerExpandHasStatusBuckets(table) { return table }
            if HeartbeatMath.grainRowsAreLive(table) { return table }
        }
        if let chrome {
            let chromeTable = pickerExpandRows(from: chrome, filters: filters, grain: grain)
            if HeartbeatMath.grainRowsAreLive(chromeTable) { return chromeTable }
        }
        return []
    }

    /// Expand must show Shoppers + Healthy / Watch / At Risk, not a dash-only thin list.
    static func pickerExpandHasStatusBuckets(_ rows: [HeartbeatMath.DashboardGrainTableRow]) -> Bool {
        let headers = HeartbeatMath.dashboardTableHeaders(.pickerScorecard)
        guard headers == ["Shoppers", "Healthy", "Watch", "At Risk"] else { return false }
        guard HeartbeatMath.grainRowsAreLive(rows) else { return false }
        guard let healthy = headers.firstIndex(of: "Healthy"),
              let watch = headers.firstIndex(of: "Watch"),
              let risk = headers.firstIndex(of: "At Risk") else { return false }
        return rows.contains { row in
            row.values.count == headers.count
                && [healthy, watch, risk].allSatisfy { index in
                    let text = row.values[index]
                    return !text.isEmpty && text != "—"
                }
        }
    }

    static func pickerExpandStatusTotals(_ rows: [HeartbeatMath.DashboardGrainTableRow]) -> (healthy: Double, watch: Double, risk: Double) {
        let headers = HeartbeatMath.dashboardTableHeaders(.pickerScorecard)
        let healthy = headers.firstIndex(of: "Healthy") ?? 1
        let watch = headers.firstIndex(of: "Watch") ?? 2
        let risk = headers.firstIndex(of: "At Risk") ?? 3
        func sum(_ index: Int) -> Double {
            rows.reduce(0) { partial, row in
                guard index < row.values.count else { return partial }
                return partial + (HeartbeatMath.parsePctToken(row.values[index]) ?? 0)
            }
        }
        return (sum(healthy), sum(watch), sum(risk))
    }

    /// Cached company/region grain must not stay under a store/district seat.
    static func grainMatchesSeat(
        _ rows: [HeartbeatMath.DashboardGrainTableRow],
        filters: DashboardFilters,
        grain: DashScopeGrain
    ) -> Bool {
        guard HeartbeatMath.grainRowsAreLive(rows) else { return false }
        guard grainTableMatchesCurrent(labels: rows.map(\.label), grain: grain) else { return false }
        return !filters.isActive || grain != .region
    }

    static func pickerGrainMatchesSeat(
        _ rows: [HeartbeatMath.DashboardGrainTableRow],
        filters: DashboardFilters,
        grain: DashScopeGrain
    ) -> Bool {
        grainMatchesSeat(rows, filters: filters, grain: grain)
    }

    /// Seat filters cannot be applied by matching grain labels
    /// (`East Region` vs District 3). Rebuild from `PulseQuery.slice`.
    static func grainRowsScopedToFilter(
        _ rows: [HeartbeatMath.DashboardGrainTableRow],
        filters: DashboardFilters,
        grain _: DashScopeGrain = .region
    ) -> [HeartbeatMath.DashboardGrainTableRow] {
        guard filters.isActive else { return rows }
        return []
    }

    /// Incoming paint must not drop a live picker (or any) expand table.
    /// Under a seat filter, company region tables must not ride along.
    static func mergeLiveGrainTables(
        incoming: [MetricSection: [HeartbeatMath.DashboardGrainTableRow]],
        live: [MetricSection: [HeartbeatMath.DashboardGrainTableRow]],
        grain: DashScopeGrain = .region,
        filtersActive: Bool = false
    ) -> [MetricSection: [HeartbeatMath.DashboardGrainTableRow]] {
        _ = filtersActive
        var next = incoming
        for (section, rows) in live {
            let incomingLive = HeartbeatMath.grainRowsAreLive(next[section] ?? [])
            if incomingLive { continue }
            guard HeartbeatMath.grainRowsAreLive(rows) else { continue }
            if !grainTableMatchesCurrent(labels: rows.map(\.label), grain: grain) {
                continue
            }
            next[section] = rows
        }
        return next
    }

    /// Seat expand may read live store packs. Never chrome East/South/CA/West labels.
    static func grainRowsFromSeatPacks(
        _ packs: [DashScopePack],
        section: MetricSection,
        grain: DashScopeGrain
    ) -> [HeartbeatMath.DashboardGrainTableRow] {
        let rows = HeartbeatMath.dashboardGrainRowsFromPacks(packs, section: section)
        guard HeartbeatMath.grainRowsAreLive(rows) else { return [] }
        guard grainTableMatchesCurrent(labels: rows.map(\.label), grain: grain) else { return [] }
        return rows
    }

    /// Continue must leave Who's looking immediately. Seat warehouse paints after.
    static func shouldRevealHubAfterSeatPaint() -> Bool { false }

    /// Horizontal page swipe must not steal vertical dashboard drags.
    /// Kept for the unused pager path; paging itself is off.
    static func shouldLockPagerScrollDirection() -> Bool { true }

    /// Grocery one-liners are banned on load. Keep the array empty.
    static let aisleQuips: [String] = []

    static func shouldShowGroceryLoadQuips() -> Bool { false }

    static var seatLoadTitle: String { "Loading Heartbeat" }

    static func seatLoadQuip(at index: Int) -> String {
        loadStatus(at: index)
    }

    static var seatLoadDirective: String {
        "Hang tight — seats unlock when the pack is on the floor."
    }

    static let blandBootPhrases = [
        "building store tables",
        "building today's pack",
        "building todays pack",
        "opening the floor",
        "reading dashboard chrome",
        "reading the store pack",
        "reading workbook",
        "reading master",
        "reading pre-sub",
        "reading sales",
        "reading loss",
        "setting the aisle",
        "choosing a seat",
        "setting the floor",
        "looking for a cloud pack",
        "loading the data",
        "loading store facts",
        "downloading workbook",
        "downloading ",
        "scorecards loaded"
    ]

    static func isBlandBootStatus(_ text: String) -> Bool {
        let lower = text.lowercased()
        return blandBootPhrases.contains { lower.contains($0) }
    }

    static func bootPhaseComedy(_ phase: BootPhase) -> String {
        phase.label
    }

    /// Load status the user can see. One phrase — never boot-phase theater.
    static func displayLoadStatus(_ raw: String?, tick: Int = 0) -> String {
        _ = raw
        _ = tick
        return seatLoadTitle
    }

    static func comedyLoadStatus(at tick: Int) -> String {
        loadStatus(at: tick)
    }

    static func loadStatus(at tick: Int) -> String {
        _ = tick
        return seatLoadTitle
    }

    static func isGroceryLoadQuip(_ text: String) -> Bool {
        let lower = text.lowercased()
        let banned = [
            "rotisserie", "scooter", "avocados unionized", "parkour",
            "ted talk", "kale filed", "oat milk", "candy corn",
            "blueberries posted", "pickles are in mediation", "price-match costco",
            "baguettes", "donuts in produce", "deli turkey", "watermelon",
            "pumpkin is holding", "bananas hostage"
        ]
        return banned.contains { lower.contains($0) }
    }

    /// Neighbor scorecards stay blank. Hydrating them makes filterStamp rebuild two extra full tables.
    static func shouldKeepNeighborPagesHydrated() -> Bool { false }

    /// Phone push keeps `router` on dashboard. Pushed section OR router.section
    /// is the active scorecard — never require `router != .dashboard`.
    static func activeScorecardSection(
        visible: HubDestination,
        pushed: MetricSection?
    ) -> MetricSection? {
        if shouldPreferVisibleSectionOverPush(), let section = visible.section {
            return section
        }
        return pushed ?? visible.section
    }

    /// `.task` id: load while this page is active, park (cancel) when it is not.
    /// `seatPaint` re-arms `ensureSectionLoaded` after forceReload/promote when
    /// keepLastGoodSeat skipped the warehouse wipe.
    static func sectionSQLTaskToken(
        section: MetricSection,
        filterSummary: String,
        isActive: Bool,
        seatPaint: Int = 0
    ) -> String {
        if shouldCancelInFlightSectionSQLOnPageSwitch(), !isActive {
            return "park-\(section.rawValue)"
        }
        if shouldReloadSectionSQLOnSeatPaintStamp() {
            return "load-\(section.rawValue)-\(filterSummary)-seat\(seatPaint)"
        }
        return "load-\(section.rawValue)-\(filterSummary)"
    }

    static func isActiveScorecardPage(
        visible: HubDestination,
        section: MetricSection,
        pushed: MetricSection?
    ) -> Bool {
        activeScorecardSection(visible: visible, pushed: pushed) == section
    }

    static func sectionOpenToken(
        visible: HubDestination,
        pushed: MetricSection?,
        section: MetricSection
    ) -> String {
        "\(visible)-\(pushed?.rawValue ?? "")-\(section.rawValue)"
    }

    /// SQLite / picker stream only for the page the user actually landed on — never mid-swipe.
    static func shouldLoadSection(
        visible: HubDestination,
        section: MetricSection,
        pushed: MetricSection? = nil
    ) -> Bool {
        guard let active = activeScorecardSection(visible: visible, pushed: pushed) else { return false }
        if active == section { return true }
        if active == .preSubOOS, section == .preSubOOSItem { return true }
        if active == .pickPath, section == .pickPathPicker { return true }
        return false
    }

    /// Picker filterStamp / board rebuild is join-page work. Dashboard already has cards.
    static func shouldRefreshPickersAfterFilter(dest: HubDestination) -> Bool {
        needsShopperJoin(dest)
    }

    /// Do not rebuild the PPH picker index during Dashboard paint — that re-walks shoppers on main.
    static func shouldRebuildPPHIndexDuringPaint(dest: HubDestination) -> Bool {
        needsShopperJoin(dest)
    }

    /// Clear-all already restored company-wide chrome. Do not re-paint the warehouse on that tap.
    static func shouldSkipWarehousePaintOnClear(restoredCompanyWide: Bool) -> Bool {
        restoredCompanyWide
    }

    /// Clear never walks the warehouse again. latestBySection is already company-wide.
    static func shouldPaintWarehouseOnClear() -> Bool { false }

    /// Company-wide region tables must not ride along with a district/store filter.
    static func grainTableMatchesCurrent(labels: [String], grain: DashScopeGrain) -> Bool {
        let regions = Set(MarketRegion.allCases.map(\.rawValue))
        let looksLikeRegions = labels.contains { regions.contains($0) }
        switch grain {
        case .region:
            return looksLikeRegions || labels.isEmpty
        case .division, .district, .store:
            return !looksLikeRegions
        }
    }

    /// Flag tiles from the unfiltered book (1,800 stores) must not appear on a 20-store district page.
    static func flagsMatchFilter(flagStores: [Int], scopedStores: Int) -> Bool {
        guard scopedStores > 0 else { return true }
        let biggest = flagStores.max() ?? 0
        return biggest <= max(scopedStores * 3, scopedStores + 24)
    }

    /// After the hub can scroll, pack I/O and section fill stay utility.
    /// userInitiated is only for a filter the user just saved — not wave 2, not hydrate.
    static func warehousePaintPriority(
        light: Bool,
        hubReady: Bool,
        firstSectionWave: Bool = false,
        filterPaint: Bool = false
    ) -> TaskPriority {
        if filterPaint { return .userInitiated }
        if hubReady { return .utility }
        if firstSectionWave { return .userInitiated }
        return light ? .userInitiated : .utility
    }

    /// SQLite / PulseCaches.build must not steal the first scroll after Who's looking.
    static func warehouseReadPriority(hubInteractive: Bool) -> TaskPriority {
        hubInteractive ? .utility : .userInitiated
    }

    /// Keep scorecard headers on screen while the new filter paint is in flight.
    static func shouldKeepLiveCalloutsUntilFilterPaint() -> Bool { true }

    /// Stamping before paint blanks every onChange(filterStamp) rebuild and remounts pills.
    static func shouldStampFilterBeforePaint() -> Bool { false }

    /// Roster option lists are filter-commit work, not every warehouse paint.
    static func shouldRefreshFilterOptionsOnEveryPaint() -> Bool { false }

    /// Facts / raw tape only when the warehouse is still thin. Never copy the full pack on filter.
    static func shouldPassRawRowsToPaint(needFacts: Bool, warehouseHasScoredStores: Bool) -> Bool {
        needFacts || !warehouseHasScoredStores
    }

    /// Filter slice already has latestBySection. prepareWarehouse overlays fight the Save tap.
    static func shouldPrepareWarehouseOnFilterPaint() -> Bool { false }

    /// Publishing the raw row tape during hydrate invalidates the whole hub on every wave.
    static func shouldPublishWarehouseRowsDuringHydrate() -> Bool { false }

    /// Excel facts adopt after the aisle can scroll — not on the wave-2 paint the user is dragging through.
    static func shouldAdoptFactsDuringInteractivePaint() -> Bool { false }

    /// Flag grids on the post-Continue paint compete with the first District scroll.
    static func shouldIncludeFlagsOnFilterPaint() -> Bool { false }

    /// PPH patch walks shoppers. Skip when the filtered week already has a Pure PPH.
    static func shouldPatchPPHOnPaint(hasFilteredPPH: Bool) -> Bool { !hasFilteredPPH }

    /// Do not wait for the full pack before the first scorecards paint.
    static func shouldPaintDashboardSectionsProgressively() -> Bool { true }

    /// Roster + the cards at the top of the dashboard. Paint these first.
    static var dashboardFirstWave: [MetricSection] {
        [.storeRoster, .sales, .lostRevenue, .missingItems, .fiveStar]
    }

    /// Remaining dashboard scorecards. Picker stays deferred.
    static var dashboardSecondWave: [MetricSection] {
        [.preSubOOS, .pickPath, .aisleMapper, .prepNotReady, .dynacap, .scheduleQuality, .pph, .labor]
    }

    /// Keep a live chrome/filter card when this paint has not loaded that section yet.
    /// Picker / Sales / Loss Revenue golds must not be replaced by an empty paint.
    static func mergeDashboardSummaries(
        painted: [SectionSummary],
        live: [SectionSummary],
        filtersActive: Bool = false
    ) -> [SectionSummary] {
        if filtersActive { return painted }
        let kept = Dictionary(uniqueKeysWithValues: live.map { ($0.section, $0) })
        return painted.map { card in
            guard let liveCard = kept[card.section] else { return card }
            let liveHead = liveCard.headline ?? 0
            let paintedHead = card.headline ?? 0
            if card.section == .pickerScorecard, liveHead > paintedHead { return liveCard }
            if card.storeCount == 0, paintedHead == 0,
               liveCard.storeCount > 0 || liveHead > 0 {
                return liveCard
            }
            return card
        }
    }

    static func pickerChromeBuckets(_ chrome: PulseDashChrome) -> (shoppers: Int, healthy: Int, watch: Int, risk: Int) {
        pickerShareBuckets(
            rows: [],
            chromeShoppers: max(chrome.pickerShoppers, Int(chrome.card(.pickerScorecard)?.headline ?? 0)),
            chromeStrong: chrome.pickerStrong,
            chromeOpportunity: max(chrome.pickerOpportunity, chrome.card(.pickerScorecard)?.riskCount ?? 0),
            grain: chrome.tables[MetricSection.pickerScorecard.rawValue] ?? []
        )
    }

    /// Same Healthy / Watch / At Risk keys as `dashboardActionFlags` / live tiles.
    static func pickerChromeActionFlags(_ chrome: PulseDashChrome) -> [HeartbeatMath.FiveStarFlag] {
        let buckets = pickerChromeBuckets(chrome)
        return HeartbeatMath.bandFlags(
            healthy: buckets.healthy,
            watch: buckets.watch,
            risk: buckets.risk,
            unit: "shoppers"
        )
    }

    static func shouldRejectZeroPickerFlags(
        _ flags: [HeartbeatMath.FiveStarFlag],
        chromeShoppers: Int
    ) -> Bool {
        shouldRejectZeroBandFlags(flags, liveCount: chromeShoppers)
    }

    /// Stale Healthy / Watch / At Risk of 0 while the page has stores/shoppers.
    static func shouldRejectZeroBandFlags(
        _ flags: [HeartbeatMath.FiveStarFlag],
        liveCount: Int
    ) -> Bool {
        guard liveCount > 0 else { return false }
        let band = flags.filter {
            let name = $0.name.lowercased()
            return name == "healthy" || name == "watch" || name == "at risk"
        }
        return band.isEmpty || band.allSatisfy { $0.stores == 0 }
    }

    /// Share tiles use live `dashboardActionFlags`, not cached zero bandFlags.
    static func shouldShareLiveActionFlags() -> Bool { true }

    /// Phone THIS SEAT chips use `dashboardTableValues` / hero pack keys — never
    /// ghost keys (`otp_pct`, `fill_rate_pct`, `quality_score`).
    ///
    /// FILE ROOT / regression: `336752c` HB-0828.397 added
    /// `PhoneSectionPage.seatChips` as a second key table (copied from pad
    /// `tiles`). Hero stayed live. Dual map deleted — one path only.
    static func shouldPaintSeatChipsFromDashboardTableValues() -> Bool { true }
    static func shouldUseGhostSeatChipKeys() -> Bool { false }
    /// Ghost 0 is banned. Do not paint `exception_count` / `pnr_count` zeros
    /// or invent extra alias chips on top of `dashboardTableValues`.
    static func shouldBanFalseZeroSeatChips() -> Bool { true }
    static func shouldAppendGhostSeatChipAliases() -> Bool { false }
    /// `336752c` dual map is dead. Do not restore `PhoneSectionPage.seatChips`
    /// switch-on-section ghost keys.
    static func shouldUseSeatChipDualMap() -> Bool { false }

    /// Same pack keys as the section hero + region `dashboardTableValues`.
    static func seatChipValues(
        section: MetricSection,
        rows: [MetricRow],
        displayedHealth: Health,
        pickerBuckets: (shoppers: Int, healthy: Int, watch: Int, risk: Int)? = nil,
        pickerChrome: (shoppers: Int, opportunity: Int, strong: Int)? = nil
    ) -> [(label: String, value: String, health: Health)] {
        if section == .pickerScorecard {
            return pickerSeatChips(
                rows: rows,
                displayedHealth: displayedHealth,
                buckets: pickerBuckets,
                chrome: pickerChrome
            )
        }
        if section == .labor {
            return laborSeatChips(rows: rows, displayedHealth: displayedHealth)
        }
        let scored = HeartbeatMath.dashboardTableValues(section, rows: rows)
        let fallback = seatChipFallback(displayedHealth, scored: scored)
        return zip(HeartbeatMath.dashboardTableHeaders(section), scored.values).map { header, value in
            (header, value, seatChipHealth(header: header, value: value, fallback: fallback))
        }
    }

    static func seatChipFallback(
        _ displayedHealth: Health,
        scored: (values: [String], health: Health)
    ) -> Health {
        if displayedHealth != .none { return displayedHealth }
        if scored.health != .none { return scored.health }
        if scored.values.contains(where: { $0 != "—" }) { return .good }
        return .none
    }

    static func pickerSeatChips(
        rows: [MetricRow],
        displayedHealth: Health,
        buckets: (shoppers: Int, healthy: Int, watch: Int, risk: Int)?,
        chrome: (shoppers: Int, opportunity: Int, strong: Int)?
    ) -> [(label: String, value: String, health: Health)] {
        let fromRows = HeartbeatMath.pickerStatusCounts(rows)
        let shoppers = max(chrome?.shoppers ?? 0, buckets?.shoppers ?? 0, fromRows.shoppers)
        let opportunity = max(chrome?.opportunity ?? 0, buckets?.risk ?? 0, fromRows.risk)
        let strong = max(chrome?.strong ?? 0, buckets?.healthy ?? 0, fromRows.healthy)
        let seat = displayedHealth == .none ? Health.watch : displayedHealth
        return [
            ("Shoppers", HeartbeatFormat.num(Double(shoppers)), seat),
            ("Opportunity", HeartbeatFormat.num(Double(opportunity)), opportunity == 0 ? .good : .risk),
            ("Doing Well", HeartbeatFormat.num(Double(strong)), .good),
        ]
    }

    /// Live `exception_count`, else `picks_total − picks_compliant`. Ghost 0 banned.
    /// Not a THIS SEAT chip — Pick Path chips are `dashboardTableHeaders` only.
    static func pickPathExceptions(stored: Double, total: Double, compliant: Double) -> Double {
        if stored > 0 { return stored }
        let derived = max(0, total - compliant)
        if shouldBanFalseZeroSeatChips(), total > 0 || compliant > 0 {
            return derived
        }
        return stored
    }

    /// Healthy / Watch / At Risk counts keep band colors. Other chips follow
    /// the hero / region tone so THIS SEAT is never flat grey when the page is live.
    static func seatChipHealth(header: String, value: String, fallback: Health) -> Health {
        switch header.lowercased() {
        case "healthy":
            return .good
        case "at risk", "below 74":
            return isZeroChipValue(value) ? .good : .risk
        case "watch" where !value.contains("%") && !value.contains("–") && !value.contains("-"):
            return isZeroChipValue(value) ? .good : .watch
        default:
            return fallback
        }
    }

    static func isZeroChipValue(_ value: String) -> Bool {
        let trimmed = value.replacingOccurrences(of: ",", with: "")
        return trimmed == "0" || trimmed == "0.0" || trimmed == "—" || trimmed.isEmpty
    }

    /// Labor THIS SEAT: same keys as Regions (`dashboardTableValues`). Weeks
    /// comes from pack `week` / `recordedOn` on those rows — never an empty
    /// `laborWeeksByStore` dash while Cost Target is live.
    static func laborSeatChips(
        rows: [MetricRow],
        displayedHealth: Health
    ) -> [(label: String, value: String, health: Health)] {
        let scored = HeartbeatMath.dashboardTableValues(.labor, rows: rows)
        let fallback: Health
        if displayedHealth != .none {
            fallback = displayedHealth
        } else if scored.health != .none {
            fallback = scored.health
        } else if scored.values.contains(where: { $0 != "—" }) {
            fallback = .good
        } else {
            fallback = .none
        }
        var chips = zip(HeartbeatMath.dashboardTableHeaders(.labor), scored.values).map { header, value in
            (header, value, seatChipHealth(header: header, value: value, fallback: fallback))
        }
        if let span = laborSeatWeekSpan(rows: rows) {
            chips.insert(("Weeks", span, fallback), at: 0)
        }
        return chips
    }

    /// Pack week ids on the same Labor rows that paint Cost Target / TVA.
    static func laborSeatWeekSpan(rows: [MetricRow]) -> String? {
        let ids = Set(rows.compactMap { row -> String? in
            for raw in [row.textPayload["week"], row.textPayload["week_id"], row.recordedOn] {
                if let value = raw, value.hasPrefix("20") { return value }
            }
            return nil
        }).sorted()
        guard let first = ids.first, let last = ids.last else { return nil }
        return first == last ? first : "\(first) thru \(last)"
    }

    static func pickerShareActionFlags(
        rows: [MetricRow],
        chromeShoppers: Int,
        chromeStrong: Int,
        chromeOpportunity: Int,
        grain: [HeartbeatMath.DashboardGrainTableRow]
    ) -> [HeartbeatMath.FiveStarFlag] {
        if !rows.isEmpty {
            let flags = HeartbeatMath.dashboardActionFlags(
                section: .pickerScorecard,
                rows: rows,
                includeAll: true
            )
            if !shouldRejectZeroPickerFlags(flags, chromeShoppers: chromeShoppers) {
                return flags
            }
        }
        let buckets = pickerShareBuckets(
            rows: rows,
            chromeShoppers: chromeShoppers,
            chromeStrong: chromeStrong,
            chromeOpportunity: chromeOpportunity,
            grain: grain
        )
        return HeartbeatMath.bandFlags(
            healthy: buckets.healthy,
            watch: buckets.watch,
            risk: buckets.risk,
            unit: "shoppers"
        )
    }

    static func pickerSummaryFromChrome(_ chrome: PulseDashChrome) -> SectionSummary? {
        let buckets = pickerChromeBuckets(chrome)
        guard buckets.shoppers > 0 else { return nil }
        if var card = chrome.card(.pickerScorecard) {
            card.headline = Double(buckets.shoppers)
            card.headlineLabel = "Shoppers"
            card.watchCount = buckets.watch
            card.riskCount = buckets.risk
            card.secondary = "\(buckets.risk) opportunity · \(buckets.healthy) doing well"
            if card.health == .none { card.health = .watch }
            return card
        }
        return SectionSummary(
            section: .pickerScorecard,
            storeCount: buckets.shoppers,
            headline: Double(buckets.shoppers),
            headlineLabel: "Shoppers",
            secondary: "\(buckets.risk) opportunity · \(buckets.healthy) doing well",
            health: .watch,
            watchCount: buckets.watch,
            riskCount: buckets.risk,
            lastFilename: nil,
            lastUploadedAt: nil
        )
    }

    /// Company cook keeps shopper tape out of sqlite and still publishes the
    /// picker summary card + `pickerShoppers` so Command Center is not 0.
    static func overlayCompanyPickerChrome(
        onto chrome: inout PulseDashChrome,
        marketRows: [MetricRow],
        uploads: [UploadRecord]
    ) {
        let pickerRows = marketRows.filter { $0.section == .pickerScorecard }
        guard !pickerRows.isEmpty else { return }
        let latest = HeartbeatMath.latestPerShopper(pickerRows)
        let summarized = HeartbeatMath.summarize(
            .pickerScorecard,
            rows: latest,
            upload: uploads.first { $0.section == .pickerScorecard }
        )
        let board = HeartbeatMath.pickerBoard(latest)
        chrome.pickerShoppers = max(chrome.pickerShoppers, board.shopperCount, Int(summarized.headline ?? 0))
        chrome.pickerOpportunity = max(chrome.pickerOpportunity, board.opportunityCount, summarized.riskCount)
        chrome.pickerStrong = max(chrome.pickerStrong, board.strongCount)
        if let idx = chrome.summaries.firstIndex(where: { $0.section == .pickerScorecard }) {
            chrome.summaries[idx] = summarized
        } else {
            chrome.summaries.append(summarized)
        }
    }

    static func pickerPacksAreLive(_ packs: [DashScopePack]) -> Bool {
        packs.contains { $0.line.count > 0 || (!$0.line.value.isEmpty && $0.line.value != "—") }
    }

    static func grainPacksArePlaceholders(_ packs: [MetricSection: [DashScopePack]]) -> Bool {
        let lines = packs.values.flatMap { $0 }
        guard !lines.isEmpty else { return true }
        return lines.allSatisfy { $0.line.value == "—" || $0.line.value.isEmpty }
    }

    static func mergeDashboardPacks(
        incoming: [MetricSection: [DashScopePack]],
        live: [MetricSection: [DashScopePack]],
        filtersActive: Bool = false
    ) -> [MetricSection: [DashScopePack]] {
        if filtersActive {
            if incoming.isEmpty || grainPacksArePlaceholders(incoming) {
                return live.isEmpty ? incoming : live
            }
            return incoming
        }
        var next = incoming
        if !pickerPacksAreLive(next[.pickerScorecard] ?? []),
           pickerPacksAreLive(live[.pickerScorecard] ?? []) {
            next[.pickerScorecard] = live[.pickerScorecard]
        }
        return next
    }

    /// One seat slice feeds every dashboard card, pack, grain table, and expand.
    static func seatSlice(
        warehouse: [MetricSection: [MetricRow]],
        roster: [String: HeartbeatMath.StoreIdentity],
        filters: DashboardFilters,
        uploads: [UploadRecord] = [],
        sessionRole: HeartbeatRole? = nil
    ) -> PulseQuery.View {
        PulseQuery.paint(
            warehouse: warehouse,
            roster: roster,
            filters: filters,
            grain: dashboardGrain(filters: filters, sessionRole: sessionRole),
            uploads: uploads,
            hidePicker: false,
            light: false,
            includePageOnly: true,
            includeFlags: true
        )
    }

    static func uniqueStores(in rows: [MetricRow]) -> Set<String> {
        Set(rows.compactMap { row in
            let store = HeartbeatMath.canonicalStore(row.storeNumber)
            return store.isEmpty ? nil : store
        })
    }

    static func summaryStoreCounts(
        _ summaries: [SectionSummary],
        sections: [MetricSection] = MetricSection.dashboardCards
    ) -> [MetricSection: Int] {
        Dictionary(uniqueKeysWithValues: sections.compactMap { section in
            summaries.first { $0.section == section }.map { (section, $0.storeCount) }
        })
    }

    /// O(1) store membership. Never `allowed.contains { sameStore }`.
    static func storeInScope(_ raw: String, allowed: Set<String>?) -> Bool {
        guard let allowed else { return true }
        return HeartbeatMath.storeInAllowed(raw, allowed: allowed)
    }

    /// Share picker appears before any HTML is built.
    static func shouldPresentShareSheetWithoutBuildingHTML() -> Bool { true }

    /// iOS Mail shows this HTML in the message body. Over this, attach the file instead.
    static let mailBodyMaxBytes = 400_000

    static func shouldSetHTMLMessageBody(utf8Count: Int) -> Bool {
        utf8Count > 80 && utf8Count <= mailBodyMaxBytes
    }

    /// Over the body cap, Mail gets a short HTML note plus the full HTML file.
    static func shouldAttachHTMLFile(utf8Count: Int) -> Bool {
        utf8Count > mailBodyMaxBytes
    }

    /// Who's looking wait is the safe time to swap a newer cloud pack (hub is not mounted).
    static func shouldCheckCloudPackDuringSeatWait() -> Bool { true }

    /// HB-0828.395 lock: the VStack pin path is dead. Chrome owns the top
    /// safe area via `content.safeAreaInset` in HubChromeModifier only.
    static func shouldPinHubChromeAboveContent() -> Bool { false }

    /// Notch wash lives on the inset HubBrandBar background, not the page.
    static func shouldGiveHubChromeItsOwnTopSafeArea() -> Bool { true }

    static func shouldClipPhoneContentBelowHubChrome() -> Bool { false }

    /// iPhone never mounts a second sticky store-header overlay (landscape
    /// `.regular` used to re-enable pad pins on top of the brand bar).
    static func shouldPinPhoneStickyStoreHeader() -> Bool { false }

    /// HubBrandBar is a safeAreaInset owner of the page, not a VStack sibling.
    static func shouldInsetHubChromeIntoContentSafeArea() -> Bool { true }

    /// Cloud facts/pack after Who's looking — not on splash, not in the first breath.
    static let cloudHydrateDelayNanoseconds: UInt64 = 12_000_000_000
    static let foregroundCloudQuietSeconds: TimeInterval = 90
    /// Pack freshness check may run again after this. Metadata only until a newer file exists.
    static let foregroundPackCheckQuietSeconds: TimeInterval = 12
    /// This project's TUS cap. Prefer the company seat over a 56MB market root.
    static let storageFileLimitBytes = 50_000_000
    /// Thin company Command Center. Market ~56MB Jetsams the 12" iPad.
    static let companySeatMaxBytes = 28_000_000

    static func shouldPullCloudPackOnColdOpen() -> Bool { true }
    static func shouldPullCloudPackOnForeground() -> Bool { true }
    static func shouldReplaceCompanySeatFromDownloadedRoot() -> Bool { true }
    static func isCompanySeatSizeAllowed(_ bytes: Int) -> Bool {
        bytes >= minimumPackBytes && bytes <= companySeatMaxBytes
    }
    /// Never copy the 56MB market root onto `packs/seat/company`.
    static func shouldCopyRootOntoCompanySeat(rootBytes: Int) -> Bool {
        shouldReplaceCompanySeatFromDownloadedRoot() && isCompanySeatSizeAllowed(rootBytes)
    }
    static func shouldPreferCompanySeatOverOversizedRoot(rootBytes: Int) -> Bool {
        rootBytes > companySeatMaxBytes
    }
    /// Re-arm page-scoped expand after promote. Never all dashboardCards at company.
    static func shouldInstallSeatExpandTablesAfterCloudPromote() -> Bool { true }
    static func shouldClearFactOwnershipAfterSeatPromote() -> Bool { true }
    static func shouldBuildCompanyGrainTablesOnWarehousePaint() -> Bool { false }

    /// Not on HeartbeatStore — `Task.detached` cannot call a MainActor static.
    /// Company scope returns empty so we never materialize all dashboardCards.
    static func grainTablesSkippingCompanyPrefill(
        latest: [MetricSection: [MetricRow]],
        grain: DashScopeGrain?,
        roster: [String: HeartbeatMath.StoreIdentity],
        packs: [MetricSection: [DashScopePack]],
        goalFallback: Double?,
        filtersActive: Bool
    ) -> [MetricSection: [HeartbeatMath.DashboardGrainTableRow]] {
        if !filtersActive, !shouldBuildCompanyGrainTablesOnWarehousePaint() {
            return [:]
        }
        return PulseCaches.grainTables(
            latest: latest,
            grain: grain,
            roster: roster,
            packs: packs,
            goalFallback: goalFallback
        )
    }
    static func isCompanyExpandScope(filtersActive: Bool, grain: DashScopeGrain) -> Bool {
        _ = grain
        return !filtersActive
    }
    /// Drop warehouse expand caches at company so a seat pull cannot keep ~4GB tables.
    static func shouldClearExpandCachesAtCompany(filtersActive: Bool, pad: Bool) -> Bool {
        _ = pad
        return !filtersActive
    }
    static func shouldPrefillAllExpandTablesAtCompany(pad: Bool) -> Bool {
        _ = pad
        return false
    }
    static func shouldSkipShoppersOnCompanyPadRead() -> Bool { true }
    static func companyPadSkippedSections() -> Set<MetricSection> {
        [.pickerScorecard, .pickPathPicker, .preSubOOSItem]
    }
    static func companyExpandRowCap(pad: Bool) -> Int { pad ? 8 : 32 }
    static func expandTableSections(visible: HubDestination, companyScope: Bool) -> [MetricSection] {
        if !companyScope { return MetricSection.dashboardCards }
        if let section = visible.section { return [section] }
        return [.sales, .lostRevenue, .missingItems, .fiveStar]
    }

    static func shouldPullCloudOnForeground(secondsSinceReady: TimeInterval) -> Bool {
        _ = secondsSinceReady
        return shouldPullCloudPackOnForeground()
    }

    static func parsePackTimestamp(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: trimmed) { return date }
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        if let date = basic.date(from: trimmed) { return date }
        let normalized = trimmed.replacingOccurrences(of: "Z", with: "+00:00")
        return fractional.date(from: normalized) ?? basic.date(from: normalized)
    }

    /// Cook `written_at` vs Storage `updated_at` for the same file is seconds to a few minutes.
    /// Slack keeps that from looping a refetch after a successful promote.
    static let packTimestampMatchSlack: TimeInterval = 15 * 60

    /// Storage `updated_at` / pack_meta.written_at. Empty local means the remote wins.
    static func remoteTimestampIsNewer(_ remote: String, than local: String, slack: TimeInterval = 0) -> Bool {
        if remote.isEmpty { return false }
        if local.isEmpty { return true }
        if let remoteDate = parsePackTimestamp(remote), let localDate = parsePackTimestamp(local) {
            return remoteDate > localDate.addingTimeInterval(slack)
        }
        return remote != local
    }

    static func shouldReplaceSeatFromNewerOnDiskRoot(rootWrittenAt: String, seatWrittenAt: String) -> Bool {
        remoteTimestampIsNewer(rootWrittenAt, than: seatWrittenAt)
    }

    /// Skip another facts.json parse when the warehouse already has the store tables.
    static func shouldLoadPublishedFacts(lostStores: Int, salesStores: Int, minimum: Int = 200) -> Bool {
        lostStores < minimum && salesStores < minimum
    }

    static func fileBytes(at url: URL) -> Int {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
    }

    static func isUsableFileSize(_ bytes: Int) -> Bool {
        bytes >= minimumPackBytes
    }

    /// Seat UI (Who's looking) must not wait on the warehouse walk.
    static func shouldPresentSeatBeforeWarehouse() -> Bool { true }

    /// Keep the seat they just picked when the pack finishes after the hub is already up.
    static func shouldKeepLastSeatOnPackLoad(seatPresented: Bool) -> Bool { seatPresented }

    /// Cold open is company Command Center. Never wall on Who's looking.
    static func shouldSkipRoleGateOnRelaunch(role: HeartbeatRole?, filtersActive: Bool) -> Bool {
        _ = role
        _ = filtersActive
        return !shouldRequireRoleGateOnColdOpen()
    }

    /// After they pick a seat, offer last book for that seat. They still tap Continue.
    static func suggestedSeatValues(role: HeartbeatRole, pending: DashboardFilters?) -> [String] {
        guard let pending, pending.isActive else { return [] }
        switch role {
        case .backstage: return []
        case .evp: return pending.regions
        case .director: return pending.divisions
        case .districtManager: return pending.districts
        case .om: return pending.oms
        case .store: return pending.stores
        }
    }

    /// Share needs filtered warehouse rows. Chrome-only District 03 would leak company grain.
    static func shouldAllowShare(warehouseHydrating: Bool) -> Bool { !warehouseHydrating }

    /// Presenting MFMailCompose over SharePulseSheet flashes then auto-dismisses (phone/iPad/Mac).
    static func shouldPresentMailOverActiveShareSheet() -> Bool { false }
    static func shouldDismissShareSheetBeforePresentingMail() -> Bool { true }
    static func shareMailUnavailableCopy() -> String {
        "Mail isn’t set up. The recap was copied — paste it into Outlook or Mail."
    }
    static var shareSheetDismissSettleNanoseconds: UInt64 { 350_000_000 }

    /// Mac Catalyst Share / New Message: bigger default, user-resizable, preview + notes.
    /// Mail presenter hop (dismiss sheet → keyWindowRoot → presentMail) stays Soft KEEP.
    static func shouldUseMacShareResizableSheet() -> Bool { true }
    static func shouldShowMacShareEmailPreview() -> Bool { true }
    static func shouldOfferShareComposeNotes() -> Bool { true }
    static func macShareSheetDefaultStep() -> Int { 1 }
    static func macShareSheetMinStep() -> Int { 0 }
    static func macShareSheetMaxStep() -> Int { 2 }
    static func macShareSheetWidth(step: Int) -> CGFloat {
        switch step {
        case 0: return 720
        case 2: return 1180
        default: return 960
        }
    }
    static func macShareSheetHeight(step: Int) -> CGFloat {
        switch step {
        case 0: return 560
        case 2: return 960
        default: return 780
        }
    }
    static let macShareSheetSizeDefaultsKey = "hb.macShareSheetSize"

    /// Apple Mail clips wide `overflow-x` tables. Stack each grain/store row
    /// as a 100% card so Regions columns stay readable on phone width.
    static func shouldStackShareTablesForMailClients() -> Bool { true }
    static func shouldClipShareTablesInMailClients() -> Bool { false }
    /// Old dataTable used nowrap 168/108/120 + width:auto (~1368px Loss, ~1044px 5 Star).
    static func shouldUseFixedNowrapShareTableColumns() -> Bool { false }

    /// Share Picker Healthy / Watch / At Risk. Live shopper rows first, then
    /// grain totals, then pack chrome. Does not expand company grainTables.
    static func pickerShareBuckets(
        rows: [MetricRow],
        chromeShoppers: Int,
        chromeStrong: Int,
        chromeOpportunity: Int,
        grain: [HeartbeatMath.DashboardGrainTableRow]
    ) -> (shoppers: Int, healthy: Int, watch: Int, risk: Int) {
        let fromRows = HeartbeatMath.pickerStatusCounts(rows)
        if fromRows.healthy + fromRows.watch + fromRows.risk > 0 {
            return fromRows
        }
        let grainTotals = pickerExpandStatusTotals(grain)
        if grainTotals.healthy + grainTotals.watch + grainTotals.risk > 0 {
            let head = max(
                chromeShoppers,
                fromRows.shoppers,
                grain.reduce(0) { $0 + $1.storeCount }
            )
            return (
                head,
                Int(grainTotals.healthy),
                Int(grainTotals.watch),
                Int(grainTotals.risk)
            )
        }
        let shoppers = max(chromeShoppers, fromRows.shoppers)
        let healthy = max(chromeStrong, 0)
        let risk = max(chromeOpportunity, 0)
        let watch = max(0, shoppers - healthy - risk)
        return (shoppers, healthy, watch, risk)
    }

    /// Boot copy that must move. One spinner phrase for 15s fails the reliability bar.
    enum BootPhase: Int, CaseIterable {
        case openingFloor = 1
        case readingChrome = 2
        case presentingSeat = 3
        case readingPack = 4
        case buildingTables = 5
        case paintingAisle = 6
        case ready = 7

        var label: String {
            PulseLaunch.seatLoadTitle
        }

        var fraction: Double {
            Double(rawValue) / Double(BootPhase.ready.rawValue)
        }
    }

    /// Chrome cards are enough to leave splash. Warehouse fill continues behind the seat UI.
    static func leaveSplashAfterChrome(paintedStoreCards: Int) -> Bool {
        paintedStoreCards > 0
    }

    /// Leave the splash when a real pack is in memory, or when Excel store
    /// facts already painted dashboard cards (bundled or cloud).
    static func leaveSplash(localPackBytes: Int, loadedRows: Int, paintedStoreCards: Int = 0) -> Bool {
        if paintedStoreCards > 0 { return true }
        return isUsableFileSize(localPackBytes) && loadedRows > 0
    }

    static func usablePaintedCards(_ summaries: [SectionSummary]) -> Int {
        summaries.filter { $0.storeCount >= 8 || ($0.headline ?? 0) > 0 }.count
    }

    /// Fetch when the device has nothing usable, storage `updated_at` is newer
    /// than pack_meta.written_at / UserDefaults, or the cloud file size moved.
    /// Same ~21MB company seat after Thursday cook must still refetch.
    /// Do not trust `hb.cloudPackUpdated` alone — a partial promote stamped it
    /// while Command Center kept reading the old seat sqlite.
    static func shouldFetchRemotePack(
        remoteBytes: Int,
        localBytes: Int,
        localRowsLoaded: Int,
        remoteUpdated: String = "",
        knownUpdated: String = "",
        localWrittenAt: String = ""
    ) -> Bool {
        guard isUsableFileSize(remoteBytes) else { return false }
        if remoteBytes > companySeatMaxBytes { return false }
        if localBytes < minimumPackBytes || localRowsLoaded == 0 { return true }
        if !localWrittenAt.isEmpty,
           remoteTimestampIsNewer(remoteUpdated, than: localWrittenAt, slack: packTimestampMatchSlack) {
            return true
        }
        if remoteTimestampIsNewer(remoteUpdated, than: knownUpdated) { return true }
        if !knownUpdated.isEmpty, !localWrittenAt.isEmpty,
           remoteTimestampIsNewer(knownUpdated, than: localWrittenAt, slack: packTimestampMatchSlack) {
            return true
        }
        if !remoteUpdated.isEmpty, remoteUpdated != knownUpdated { return true }
        return remoteBytes != localBytes
    }

    static func shouldStampCloudPackUpdated(downloadSucceeded: Bool, seatPromoted: Bool = true) -> Bool {
        downloadSucceeded && seatPromoted
    }

    /// Usable local company seat is allowed for splash paint. Cloud still wins
    /// when remote `updated_at` is newer than seat `written_at` — no app delete.
    static func staleCompanySeatRequiresCloudSync(
        remoteBytes: Int,
        localSeatBytes: Int,
        localRowsLoaded: Int,
        remoteUpdated: String,
        knownUpdated: String,
        localWrittenAt: String
    ) -> Bool {
        shouldForceRedownloadCompanySeatWhenRemoteNewer()
            && shouldFetchRemotePack(
                remoteBytes: remoteBytes,
                localBytes: localSeatBytes,
                localRowsLoaded: localRowsLoaded,
                remoteUpdated: remoteUpdated,
                knownUpdated: knownUpdated,
                localWrittenAt: localWrittenAt
            )
    }

    /// A promoted newer pack must paint in this session. iPad is `constrained`
    /// (skipExcel); skipping the reload left Wednesday on disk and old Sales on screen.
    static func reloadInSessionAfterFetch(constrained: Bool, localRowsLoaded: Int) -> Bool {
        true
    }

    static func missingPackMessage() -> String {
        "No Heartbeat pack is on this device, and the cloud pack did not load. Check the network and tap Try again."
    }
}
