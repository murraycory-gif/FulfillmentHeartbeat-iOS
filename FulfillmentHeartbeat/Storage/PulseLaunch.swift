import Foundation

/// Launch and refresh rules for the on-device SQLite pack.
/// Keep this off the network and off SwiftUI so the boot path can be tested.
enum PulseLaunch {
    static let minimumPackBytes = 50_000
    static let stagingFileName = "heartbeat-cloud.sqlite"
    static let bootDownloadTimeout: TimeInterval = 25
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
    static func shouldKeepVisitedScorecardHostsWarm() -> Bool { false }

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
        hasCachedChrome: Bool
    ) -> SeatSwapPlan {
        if !localUsable { return .downloadMissingPack }
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

    /// Full `paintFromWarehouse(light: false)` under a seat fights the first scroll.
    static func shouldScheduleLiveGrainPaint(filtersActive: Bool) -> Bool { !filtersActive }

    /// 12-section expand prefill while they drag the District dashboard.
    static func shouldPrefillExpandTables(filtersActive: Bool) -> Bool { !filtersActive }

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

    static func maxWarmScorecardHosts() -> Int { 2 }

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

    /// Store-row tables / snap rebuilds belong on District, OM, and Store only.
    /// Company + Region (and division-only) stay summary / higher-grain.
    static func shouldShowStoreTable(filters: DashboardFilters) -> Bool {
        !filters.district.isEmpty || !filters.om.isEmpty || !filters.store.isEmpty
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

    /// Home glance never mounts DashScopeStrip / store tables. Expand is a section open.
    static func shouldMountDashCalloutTablesOnHome() -> Bool { false }

    /// Mac Catalyst Command Center: pinned Pages sidebar + center only.
    static func shouldPinMacCommandCenterRails() -> Bool { true }

    /// No right Alerts column on Mac. Simplifies chrome / heat.
    static func shouldPinMacCommandCenterAlertsRail() -> Bool { false }

    /// iPad never pins Mac-style triple columns. Rails stay closed until opened.
    static func shouldPinCommandCenterRailsOnIPad() -> Bool { false }

    /// iPad land + port: Pages / Alerts are overlay drawers, not pinned columns.
    static func shouldOfferIPadCommandCenterDrawers() -> Bool { true }

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
        pushed ?? visible.section
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

    static func pickerSummaryFromChrome(_ chrome: PulseDashChrome) -> SectionSummary? {
        let shoppers = max(chrome.pickerShoppers, Int(chrome.card(.pickerScorecard)?.headline ?? 0))
        guard shoppers > 0 else { return nil }
        if let card = chrome.card(.pickerScorecard), (card.headline ?? 0) > 0 {
            return card
        }
        if var card = chrome.card(.pickerScorecard) {
            card.headline = Double(shoppers)
            card.headlineLabel = "Shoppers"
            if card.health == .none {
                card.secondary = "\(chrome.pickerOpportunity) opportunity · \(chrome.pickerStrong) doing well"
                card.health = .watch
                card.riskCount = max(card.riskCount, chrome.pickerOpportunity)
            }
            return card
        }
        return SectionSummary(
            section: .pickerScorecard,
            storeCount: shoppers,
            headline: Double(shoppers),
            headlineLabel: "Shoppers",
            secondary: "\(chrome.pickerOpportunity) opportunity · \(chrome.pickerStrong) doing well",
            health: .watch,
            watchCount: 0,
            riskCount: chrome.pickerOpportunity,
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

    /// Pin the brand / greeting / filter bar in flow above the page. safeAreaInset
    /// loses to page `ignoresSafeArea` after the pager was removed — cards hide under chrome.
    static func shouldPinHubChromeAboveContent() -> Bool { true }

    /// Cloud facts/pack after Who's looking — not on splash, not in the first breath.
    static let cloudHydrateDelayNanoseconds: UInt64 = 12_000_000_000
    static let foregroundCloudQuietSeconds: TimeInterval = 90

    static func shouldPullCloudOnForeground(secondsSinceReady: TimeInterval) -> Bool {
        secondsSinceReady >= foregroundCloudQuietSeconds
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

    /// Fetch when the device has nothing usable, the cloud file is a different
    /// size, or storage `updated_at` moved. SQLite page alignment often keeps
    /// the same byte length after Wednesday lands — size-only compare skipped it.
    /// A new app stamp must not force a download by itself (jetsam on 4GB).
    static func shouldFetchRemotePack(
        remoteBytes: Int,
        localBytes: Int,
        localRowsLoaded: Int,
        remoteUpdated: String = "",
        knownUpdated: String = ""
    ) -> Bool {
        guard isUsableFileSize(remoteBytes) else { return false }
        if localRowsLoaded == 0 { return true }
        if !remoteUpdated.isEmpty, remoteUpdated != knownUpdated { return true }
        return remoteBytes != localBytes
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
