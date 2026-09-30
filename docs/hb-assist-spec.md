# Heartbeat Assist: Problem → Resolution cards (design spec)

Status: design only. No code in this document has been written to the repo.
Repo read: `murraycory-gif/FulfillmentHeartbeat-iOS`, branch `main`, commit **`e44f1405dc377b79f1e8711e6b4f9b582e8a8004`** (2026-09-25 12:45 PM CT, "Drop the unused facts_section_store partial index (#47)").
Read through GitHub MCP only. Nothing was cloned.

**v2 (Fri Sep 25 2026, 8:28 PM CT): owner additions relayed by the CoS.**
- **Build target:** the CoS is building Assist on the **477 line**, PR #45 head `0dcad79201cba43c75e6a70e2cfe67b6339eeaec`. On that line, `HubDestination` has 13 cases and **no `.checklist` or `.upload`** (see §10 and §13).
- **Resolution checks** now come from `PLAYBOOK.md` (one JSON data file, `playbook.json`). There are two check types, floor and auto (§4.1).
- **"More checks ›" row** added to the card (§4, part 6b).
- **Cause chain and a "Why" line** on the Loss Revenue card (§4, part 4a; §4.2).
- **New acceptance checks:** §15, checks 26–35.

> **Build mismatch.** The screenshot does not match `main`. The strings "Stores 2161" and the chip "What's wrong and what should we do first?" are not on `main`. They are on the seat-shell branch line: `cursor/grain-first-seat-shell-b84a` @ `f38b748` and `cursor/command-center-8b-3389` @ `53e8895`. Both have the same `AssistEngine.swift`, with `seatWrong()` and "WHAT'S WRONG / DIRECTION". This spec targets `main`, which is what was asked. Every rule here also applies to the branch. Section 13 lists the branch-only destinations.

---

## 1. What changes, in one paragraph

Today Assist answers every question with one long text bubble. The bubble has ALL-CAPS headers ("ISSUE", "WORST DISTRICTS", "WHAT TO DO TODAY") and "·"-chained bullets. It also mixes units: the Picker ScoreCard reports "24671 at risk", which are shoppers, next to "Stores 2161". The new Assist answers with a short **"Fix these first"** header and then **ranked Problem → Resolution cards**. Each card says what's wrong in plain words and shows the one number that matters. It names the scope and gives 1 to 3 actions, each with an owner role and a button that opens the right screen. Order comes from one published formula. All logic is on-device and templated from pack fields. There is no LLM and no network. The layout is one column and is identical on iPhone, iPad, and Mac.

## 2. Hard rules

1. **Nothing invented.** Every number on screen comes from a pack field or an existing `HeartbeatMath` rollup of pack fields. Each is cited in section 9 and in the appendix. If a field is missing for the scope, that element is left out. It is never filled in or estimated.
2. **Targets come from `HeartbeatMath` constants.** Examples: `pnrGoal = 1.9` and `pickPathGoal = 90`. The pack does not carry targets. The only pack-side targets are `cost_trgt_pct` (Labor) and `sales_plan` / `sales_plan_pct` (Sales).
   - **Exception:** an auto check in `PLAYBOOK.md` may use an **owner standard** relayed by the CoS, and its `thresholdSource` must say so. Today the only one is the PPH floor 65. Owner standards never change ranking; ranking keeps the §6 bands.
   - The owner's "30 items in the first 15 minutes" standard is not in the pack. It is only ever a floor question, never a computed number.
3. **Deterministic.** The same pack, scope, and question always give the same text in the same order on every device. Scores are rounded to 4 decimals before comparing.
4. **Offline.** Assist code must not reference `PulseCloud`, `URLSession`, or any network API. Answers are built only from `HeartbeatStore` in-memory data: `summaries`, `displayRows(for:)`, `filters`, `stores`, `districts`, and `operationsOMs`.
5. **No names we don't have.** Owners are role labels, such as "District managers" or "Grocery lead". The only person names allowed are shopper names from `shopper_name` / `shopper_id` on Picker ScoreCard and Pick Path Picker rows. The pack has no OM, district manager, or store leader names (see Gaps).

## 3. Screen layout (identical on all three platforms)

Top to bottom, inside the existing full-screen cover (`HubBrandBar.showAssist` → `HeartbeatAssistSheet`):

1. **Title bar**: "Done" on the left and "Heartbeat Assist" in the center. This is unchanged.
2. **Scope line.** One line in plain words (see 8.1), for example "Total company" or "District 12". It replaces today's `"\(router.current.title)  ·  \(store.filters.summary)"`. The data window from `dataWindow(for:)` / `sharedDataWindow()` sits under it in caption style.
3. **Transcript.** The user's question appears as a right-aligned bubble. The answer is a stack of blocks, not a text bubble:
   - the stale banner (only if stale, see 10.2)
   - the "Fix these first" header (section 7)
   - cards 1 to 3
   - "More issues (n)". This is a collapsed row that expands to show cards 4 and up in the same card format.
   - "How this was ranked". This is a collapsed row with one plain line per card (see 6.5).
   - "No data here for: …" (only if some scorecards have no rows in scope)
4. **Suggested chips.** A single column of at most 4 chips (section 11).
5. **Composer**: "Ask Heartbeat Assist…" plus the send button. This is unchanged.

**Width rule (the only per-device difference).**
- Content column width = `min(availableWidth − 32, 680)` points, centered. Cards, the header, chips, and the composer all use this column.
- There is never more than one column. Replace today's chip grid (`LazyVGrid(columns: [GridItem(.adaptive(minimum: 320))])`, which turns into 2 or 3 columns on iPad and Mac) with a `VStack`. Replace the 980-point bubble (`frame(maxWidth: 980)`) with the 680-point column.
- Nothing branches on `horizontalSizeClass`, `HubLayout.isPhone`, or platform inside Assist.
- Wrapping depends only on Dynamic Type size, never on device. At accessibility sizes (AX1 and up), the three-column fact row stacks vertically on every platform.

## 4. Card anatomy

Every card has the same seven parts in this order, plus part 4a (Loss Revenue only) and part 6b (when there are more checks). A part is skipped only where noted.

| # | Part | Content | Style |
|---|------|---------|-------|
| 1 | Rank + metric + status | "#1  Schedule Quality" on the left. A status pill on the right: "At risk", "Watch", or "Stores failing" (a healthy average with stores off goal, see 6.1). The pill uses text, an SF Symbol, and color, never color alone. | caption, semibold |
| 2 | Problem headline | Plain sentence of 90 characters or fewer, from the metric's template (section 9) | title3, semibold, wraps |
| 3 | The one number | Label over value. Above store scope: label "Stores at risk", value "{R} of {N}". At store scope: label = the metric's name, value = the store's value. | label: caption; value: title, bold, monospaced digits |
| 4 | Fact row | Up to 3 equal label-over-value cells: **Average** (`SectionSummary.headlineText`), **Goal** (the constant), and **On watch** ({W}) or the metric-specific third cell from section 9. A fourth element, **Trend**, appears only when section 5 allows it; it replaces the third cell. | caption over body |
| 4a | Why (Loss Revenue only) | One line from §4.2, e.g. "Why: low capacity, from late orders (OTT 88.0%) and slow picking (PPH 58.0)." It names only causes that are failing at the scope in view, and is hidden if none are. The whole line is one button (at least 44 points tall) that expands the failing auto checks of the named causes, for the same scope. | subheadline; cause names semibold |
| 5 | Scope | "Scope: {scope label}" (8.1). At company level it adds "(all regions, divisions, districts, OMs, stores)". | footnote, secondary |
| 6 | What to do | Heading "What to do", then 1 to 3 numbered actions, taken from the metric's `PLAYBOOK.md` checks in `order` (§4.1). A **floor** check shows the yes/no question, an optional detail line, "Owner: {role}", and "Open {screen} ›". A **failing auto** check shows its fail statement with the value (e.g. "PPH 58, under 65"), "Owner: {role}", and "Open {screen} ›". The whole action row is one button, at least 44 points tall. Above store scope, only 2 checks show; action 3 stays "Start with {child}" (8.2). | body / footnote / body in accent color |
| 6b | More checks | Collapsed row "More checks ›" under the actions. It expands to show the remaining floor checks and every **passing** auto check (with its pass statement), in `order`, in the same row format. It is hidden when there are none. | body, accent; expanded rows as part 6 |
| 7 | Tap-through | Footer button "See all {R} stores ›", or "Open {metric page} ›" at store scope. Tapping card parts 1 to 4 does the same thing. | body, semibold, accent |

**Tap behavior.** Tapping a destination does four things:
1. Dismisses the Assist cover.
2. Applies the filter change, if any, with `store.setDivision` / `setDistrict` / `setOM` / `setStore` or `store.commitFilters(DashboardFilters(region:…))`.
3. Calls `router.open(section:)` or `router.open(.dashboard)`.
4. Leaves the transcript as it was. Reopening Assist shows the same answer, rebuilt for the new scope only if the user asks again.

**Wording templates.** Use `{}` placeholders. Plural rules: "1 store" or "N stores". Numbers use the formats in section 12.

### 4.1 Checks: floor vs. auto (from `PLAYBOOK.md`)

**Floor check** (`type: "floor"`):
- A yes/no question of 12 words or fewer (owner wording is kept exactly, even if longer). "No" means the fix.
- It may have one `detail` line, e.g. under "Is store PI (perpetual inventory) accurate?": "Check PI accuracy; look for out-of-stocks showing as on-hand."
- The app never answers it; the leader does, on the floor.

**Auto check** (`type: "auto"`):
- Computed on the device from `packFields`: the first key present when `combine` is `first`, or every key when `combine` is `any`. Each key is tested against `threshold` with `comparator`.
- It is rendered as a **statement with the value, never a question.**
  - At store scope, it uses `passText` / `failText` with the store's value.
  - Above store scope, it uses `scopePassText` / `scopeFailText`:
    - with `rollup: avg`, `{value}` is the metric's `SectionSummary.headlineText`, and the check fails when that value breaks the threshold;
    - with `rollup: countFailing`, the check fails when any store fails;
    - `{k}` of `{n}` is the number of stores failing (a `[...]` segment containing `{k}` is dropped when `k` = 0).
- **Examples:**
  - "Under-scheduled: yes (Sch vs Tgt 7.2%, over 5%, Pch vs Sch 4.1%)"
  - "PPH 58, under 65"
  - Above store scope: "PPH 61.3, under 65; 12 of 40 stores under 65" (sample values)
- **States:**
  - **fail:** eligible for the part 6 action slots.
  - **pass:** goes to part 6b, with a text-plus-symbol "OK", never color alone.
  - **no data:** hidden (§9: an action without data is dropped).
- Numbers follow §14. Templates never contain "·".

**Slots.** Actions are filled with the first 3 checks (2 above store scope) that are floor checks or failing auto checks, in `order`. Everything else goes to part 6b.

### 4.2 Cause chain and the Why line

`PLAYBOOK.md` gives every entry a `causes` list.

**Owner's chain:**
1. Loss Revenue ("Lost Sales") is caused by low capacity.
2. Low capacity is caused by Poor OTT (5 Star OTT) and Low PPH.

Low capacity is modeled as the **Reduced Capacity Missed Sales** bucket (`missed_sales` / `missed_sales_pct`, or `reduced_capacity`, in `lostRevenueMetricFlags`).

**When the Why line shows.** It appears on the Loss Revenue card only, and only if the Reduced Capacity bucket health is watch or risk **at the scope in view**. It then names the failing children only:

| Cause | Failing at store scope | Failing above store scope |
|---|---|---|
| Poor OTT | `ottStar(row)` is not `.full` (`ott_pct` < 95) | the OTT entry in `fiveStarActionFlags` is watch or risk |
| Low PPH | the `PPH under 65` auto check fails (owner floor 65) | the same check fails on the scope rollup |

**Templates** (`{ott}` = OTT % for the scope, `{pph}` = PPH for the scope, `{missed}` = Reduced Capacity dollars, all as §14):
- Both failing: "Why: low capacity, from late orders (OTT {ott}%) and slow picking (PPH {pph})."
- OTT only: "Why: low capacity, from late orders (OTT {ott}%)."
- PPH only: "Why: low capacity, from slow picking (PPH {pph})."
- Neither: "Why: low capacity ({missed} missed sales)."
- Reduced Capacity healthy or no data: **no Why line.**

**Tapping** the Why line expands, in place, the failing auto checks of each named cause for the same scope (OTT: "Under-scheduled", "PPH under 65"; PPH: "PPH under 65"). Each keeps its own "Open {screen} ›". Causes marked `causesConfirm` in `PLAYBOOK.md` are **not** used in the Why line until the owner confirms them.

**PPH band note.** Owner decision: Assist ranking and the PPH card status use one band, `AssistRank.pphRankingBand`: At risk < 65, Watch 65 to < 80, Healthy >= 80. The gap band is 15 (80 → 65). Dashboard and other pages keep `pphGoal` 80 / `pphRisk` 74. The same 65 is the auto-check floor and the Why line.

## 5. Trend: when it may appear

| Metric | Trend source | Text | If missing |
|---|---|---|---|
| Sales | `HeartbeatMath.salesRollupYoY(current:yoyPct:)` over `sales_dollars` and `sales_yoy_pct` | "Trend: up {x}% vs last year" or "Trend: down {x}% vs last year" | omit |
| Any other metric | `HeartbeatStore.history(for:)`, only when it returns 2 or more `HistoryPoint`s (2 or more distinct `recordedOn` dates in scope) | "Trend: {up/down} {Δ} since {shortDate(previous.date)}" | omit (this is the normal case) |

For all other metrics the pack has **no prior-period field** (see Gaps). The trend cell is not drawn. There is no placeholder dash.

## 6. Ranking formula

### 6.1 Which metrics can be ranked
A metric `m` in `MetricSection.dashboardCards` becomes a card when all of these are true:
- `m` is not `.pickerScorecard`. Its `riskCount` counts shoppers, not stores. It is used as the "who" in actions and by the shopper chip instead.
- `summary.health != .none` and `summary.storeCount > 0`.
- `R + W > 0`, where `R = summary.riskCount` and `W = summary.watchCount` (`SectionSummary`, built in `HeartbeatMath.summarize`).

A metric with `R + W == 0` is **healthy**. It is left out of the cards and counted in the healthy line (10.4).

### 6.2 Score
```
Score(m) = S × N × (1 + D̄)

S  (severity)     = 3 if summary.health == .risk
                    2 if summary.health == .watch
                    1 if summary.health == .good but R + W > 0   ("Stores failing")
N  (stores hit)   = R + 0.5 × W
D̄  (distance off) = mean, over every store row in scope whose
                    HeartbeatMath.health(for: m, row:) is .risk or .watch,
                    of  min(3, gap / band)          (table 6.3)
```
Why `(1 + D̄)`: a watch store just past the goal still counts. D̄ can push a metric up by at most 4 times.

### 6.3 Gap and band per metric
Store values come from `displayRows(for:)`. "Goal" and "risk line" are the `HeartbeatMath` constants used by `band(...)`.

| Metric (section raw value) | Field | gap | band |
|---|---|---|---|
| Pick Path (`pick_path`) | `compliance_pct` | max(0, 90 − v) | 10 (90 → 80) |
| Missing Items (`missing_items`) | `mi_pct` | max(0, v − 5) | 1.5 (5 → 6.5) |
| Pre-Sub OOS (`pre_sub_oos`) | `mi_pct` | max(0, v − 5) | 1.5 |
| Prep Not Ready (`prep_not_ready`) | `pnr_rate_pct` | max(0, v − 1.9) | 0.6 (1.9 → 2.5) |
| Dynacap (`dynacap`) | `dynacap_rate`, else `pieces_per_hour` | max(0, 65 − v) | 5 (65 → 60). If the row has no rate and `dynacapAligned == false`, gap/band = 1. |
| Schedule (`schedule_quality`) | `schedule_efficiency_pct`, `staffing_efficiency_pct`, `under_schedule_pct`, `over_schedule_pct` | the largest of: (90 − eff)/5, (90 − staff)/5, (under − 0.05)/4.95, (over − 0.05)/4.95, floored at 0 | already normalized |
| PPH (`pph`) | `pph` | max(0, 80 − v) | 15 (80 → 65). Assist only: At risk < 65, Watch 65 to < 80, Healthy >= 80. Other pages stay 80 / 74. |
| Labor (`labor`) | `target_vs_actual_pct` | max(0, v − 0) | 3 (0 → 3) |
| 5 Star (`five_star`) | `star_rating` | max(0, 4.5 − v) | 0.5 (4.5 → 4.0) |
| Loss Revenue (`lost_revenue`) | `lost_revenue_pct` | max(0, v − 3) | 2 (3 → 5) |
| Sales (`sales`) | `sales_yoy_pct` if present, else `sales_plan_pct` | yoy: max(0, 0 − v); plan: max(0, 100 − v) | yoy: 3 (0 → −3); plan: 5 (100 → 95) |

Rows in `HeartbeatMath.ignoredStores` (`210`, `239`) and Loss Revenue rows with `lost_grain == "market"` are skipped. This is the same filter `Brain.storeRows` uses today.

### 6.4 Order and tie-breaks
Sort by Score, highest first. If two Scores match (after rounding to 4 decimals), break the tie in this order:
1. higher R
2. higher W
3. higher D̄
4. earlier in `MetricSection.dashboardCards` order: Sales, Loss Revenue, Missing Items, 5 Star, Pre-Sub OOS, Pick Path, Prep Not Ready, Dynacap, Schedule, Picker, PPH, Labor.

This replaces the "5 Star at risk always first" pin in `dashboardCallouts` for Assist only. The Dashboard itself is unchanged.

**Store scope.** When one store is selected, R and W are each 0 or 1 for that store, so N is 0.5 or 1 and D̄ is that store's own gap/band. The formula reduces to `S × N × (1 + gap/band)`, where S comes from the store's own health (risk 3, watch 2).

### 6.5 "How this was ranked" (for trust and for QC)
Collapsed by default. It shows one line per card, built only from the numbers above. Example:
"Schedule Quality: at risk, 1,822 at-risk and 246 watch stores, on average 0.8 of a band past goal."

### 6.6 Worked example (screenshot numbers, company scope)
From the screenshot (All regions, All divisions, All districts, All OMs, All stores):

| Metric | health | R | W | N = R + 0.5W | S | S × N (before D̄) |
|---|---|---|---|---|---|---|
| Schedule Quality 90.1% | At risk | 1,822 | 246 | 1,945 | 3 | 5,835 |
| Missing Items 7.6% | At risk | 1,340 | 574 | 1,627 | 3 | 4,881 |
| Dynacap Setting 67.9 | Healthy (average ≥ 65) | 802 | 157 | 880.5 | 1 | 880.5 |
| Pick Path 79.9% | At risk | cut off in screenshot | cut off | n/a | 3 | n/a |
| "24671 at risk / 0 watch" (Picker ScoreCard, counts shoppers) | not ranked | | | | | |

The final order needs D̄, which comes from the store rows and is not visible in a screenshot. If D̄ were equal for Schedule and Missing Items, the order would be Schedule, then Missing Items, then Dynacap. QC checks the real order with the fixture in 14.2.

Note: Schedule is "At risk" even though its average (90.1%) is above goal (90%). That is because `summarize` marks it at risk when any store is at risk or more than 5% under or over. This is exactly why the big number is **stores at risk**, not the average.

## 7. "Fix these first" header

- Title: "Fix these 3 first", or "Fix these 2 first" / "Fix this first" when fewer issues qualify.
- Up to 3 lines, one per top card. Each line is at most 48 characters: `{rank}. {metric short name}: {R} of {N} stores`. At store scope: `{rank}. {metric short name}: {value} (goal {goal})`.
- Tapping a line scrolls to that card.
- It has no other text. It shows only when at least 1 card qualifies.
- Metric short names come from `MetricSection.overviewLead` ("Schedule", "Missing Items", "Pick Path", "5 Star", …).

Example: "Fix these 3 first" / "1. Schedule: 1,822 of 2,161 stores" / "2. Missing Items: 1,340 of 2,161 stores" / "3. …"

## 8. Scope rules

### 8.1 Level, label, owner
The level is read from `store.filters` (`DashboardFilters`). The deepest non-empty field wins. When a field holds several values (newline-separated), `DashboardFilters.display` gives the label, for example "District 12 + 2 more".

| Level | Trigger | Scope label | "Stores at risk" value | Owner role (next level down) | Child unit for "worst" | Filter action on tap |
|---|---|---|---|---|---|---|
| Company | no filters | "Total company" | "{R} of {N}" | Region EVPs | region (`MarketRegion`) | `commitFilters(region:)` |
| Region | `region` | "{region}", e.g. "East Region" | "{R} of {N}" | Market directors | market (division) | `setDivision` |
| Division | `division` | "{division} market" | "{R} of {N}" | District managers | district | `setDistrict` |
| District | `district` | "District {district}" | "{R} of {N}" | Operations managers | OM (`MetricRow.operationsOM`) | `setOM` |
| OM | `om` | "OM {om}" (this is OM_AREA/OM_ID text, not a person) | "{R} of {N}" | Store leaders | store | `setStore` |
| Store | `store` | "Store {number}, {storeName}" (name from roster `name`; the name is left off if missing) | the store's value | Store leader, plus the functional owner in section 9 | none | none |

`N` is that metric's `summary.storeCount` (stores with data for that metric in scope). It is **not** the roster total, which is why N can differ between cards.

### 8.2 What changes at each level
- **Wording.** Headlines use "{R} of {N} stores" above store level. At store level they speak to the store: "Your pick path is 71.4% (goal 90%)". There is no "of" count at store level.
- **Owner.** Section 9 defines the owner per metric: the level owner above store, the functional owner at store.
- **Actions.** Above store, action 3 is always "Start with {worst child}" (8.3). At store level, action 3 turns into a named-shopper action where the metric has shopper data, or is dropped.
- **Store counts.** They are always recomputed from the scoped `summaries`. No cached company numbers are used under a filter.

### 8.3 Worst child ("Who is the worst district?" and similar)
For each child unit in scope, compute `ChildScore = Σ Score(m)` over the eligible metrics, using only that child's rows. S is the child's own rollup health from `HeartbeatMath.summarize` on those rows.
- Tie-breaks: more stores with at least one at-risk metric (a union of store numbers, so no store is double-counted), then name A to Z.
- The answer shows the top 3 children as cards, in the same anatomy:
  - Headline: "{child label} has the most stores in trouble". Cards 2 and 3 say "…is next".
  - Big number: "Stores with an at-risk scorecard: {u} of {n}".
  - Facts: "Worst scorecard" = {metric short name}; "Its stores at risk" = {r} of {n}.
  - Actions: (1) "Open {child}", which applies the child filter and opens Dashboard. (2) "Work {metric} first", which applies the child filter and opens that metric page.
  - Owner: the child-level role from 8.1.

This fixes a bug in today's `districtBrief(nil)`. On the Dashboard it ranks by `primary = dest.section ?? .lostRevenue`, so "worst district" there silently means worst for Loss Revenue.

## 9. Resolution rules per metric

Notation: `R`, `W`, and `N` come from `SectionSummary`. `{avg}` = `summary.headlineText`. `{child}` = worst child (8.3). "Level owner" = the owner in 8.1. Destinations are `HubDestination` cases on `main` (`MainHubView.swift`); on the 477 line they are the 13 cases in `Domain.swift` (§13).

**v2: checks replace free-form actions.** Actions 1–2 below remain as the data-bearing lines, e.g. "Hang aisle tags in {dept} first." When one has data, it may take action slot 1. The remaining slots come from the metric's `PLAYBOOK.md` checks (§4.1). Owner additions:
- **High Pre Subs.** This is the owner's name for Pre-Sub OOS (`presub_pct`). The same key drives the 5 Star Presub part. Both get the display name "High Pre Subs" and these first checks, in order:
  1. "Are shoppers using radios?"
  2. "Is the whole store using radios?"
  3. "Is store PI (perpetual inventory) accurate?"
- **Low PPH.** First check: "Are shoppers picking 30 items within the first 15 minutes of their run or shift start?"
- **Poor OTT.** The first two checks are auto: "Under-scheduled" (`under_schedule_pct` > `scheduleVarianceWatch` 5, with `under_adherence_pct` "Pch vs Sch" shown as support) and "PPH under 65".

The trigger for a card is always `R + W > 0` (6.1). Action 3 above store level is always "Start with {child}: {r} of {n} stores at risk", owned by the child-level role, opening Dashboard filtered to that child. It is not repeated in each row below.

| Metric | Headline (above store / at store) | Fact row | Actions 1–2 (show only if their data exists) | Store-level owner | Destination |
|---|---|---|---|---|---|
| **Schedule Quality** | "Schedules don't fit the work at {R} of {N} stores" / "Your schedule efficiency is {v}% (goal 90%)" | Average {avg}. Goal 90%. Under/over: `underScheduledCount` / `overScheduledCount` stores more than 5% off. | (1) if over > 0: "Cut hours that never pick at the {over} over-scheduled stores on the next schedule build." (2) if under > 0: "Fill open peaks at the {under} under-scheduled stores with trained shoppers, not overtime." At store level, use the store's `under_schedule_pct` / `over_schedule_pct`. | Store leader | `.scheduleQuality` |
| **Missing Items** | "Items are missing aisle tags at {R} of {N} stores" / "{v}% of your items have no aisle tag (goal 5% or less)" | Average {avg}. Goal 5% or less. On watch {W}. | (1) "Hang aisle tags in {dept} first. It averages {x}% missing." The hottest `MissingItemDept` is the highest average of `mi_grocery`…`mi_bakery_pkgd`. (2) if Aisle Mapper dates exist: "Refresh aisle maps older than 90 days at {k} stores." (`aisle_mapper_date` via `AisleMapperMath.health == .risk`) | Grocery lead | `.missingItems`; (2) → `.pickPath` (the store table shows mapper dates) |
| **Pick Path Compliance** | "Shoppers are off the pick path at {R} of {N} stores" / "Your pick path is {v}% (goal 90%)" | Average {avg}. Goal 90%. On watch {W}. | (1) "Coach the lowest path scores first, starting with {shopper_name} at store {store} ({compliance_pct}%)." Source: `pick_path_picker` rows, lowest `compliance_pct`, `isRealPicker`. (2) "Update aisle maps older than 90 days at {k} stores and sequences at {j} stores." (`aisle_mapper_date`, `aisle_sequence_date`) | Store leader (coach) and the named shopper | `.pickPath` |
| **5 Star** | "{R} of {N} stores are below 4.0 stars" / "Your store is at {v} stars (healthy is 4.50+)" | Average {avg}. Healthy at 4.50+. Weakest part: the `fiveStarActionFlags` entry with the most risk stores, shown as "{name}: {stores} stores". | (1) By weakest part. Pre Sub OOS% → "Confirm the home location is empty before any sub." OTT / OTH 5% → "Stage complete totes before the cutoff." COE → "Scan every substitution and age-restricted item." Flash → "Close the lowest star first. Flash is the weakest." (2) "Coach the shoppers missing {part}, starting with {shopper_name} at store {store}." Source: picker rows where that part's `StarMark` is not `.full`. | Store leader and the named shopper | `.fiveStar`; (2) → `.pickerScorecard` |
| **Pre-Sub OOS** | "Items are out before substitution at {R} of {N} stores" / "{v}% of your ordered items were out before sub (goal 5% or less)" | Average {avg}. Goal 5% or less. On watch {W}. | (1) "Fix on-hands and pick-face fills in {dept} first ({x}%)." (2) if `pre_sub_oos_item` rows exist: "Walk the top item, {bpn}, with grocery today ({presub_pct}%)." | Grocery lead | `.preSubOOS` |
| **Prep Not Ready** | "Prep isn't ready when shoppers pick at {R} of {N} stores" / "{v}% of your pick hours were lost to prep (goal 1.9% or less)" | Average {avg}. Goal 1.9% or less. On watch {W}. | (1) "Stage produce, meat, and bakery 60 minutes before the first eComm wave." (2) if the PPH summary needs action: "Expect PPH to follow. It averages {pph avg} against a goal of 80." | Grocery lead | `.prepNotReady` |
| **Dynacap Setting** | "Capacity is set below 60 pieces an hour at {R} of {N} stores". If there is no rate, only the aligned check: "Capacity doesn't match the recommended setting at {R} of {N} stores". At store: "Your capacity is {v} pieces an hour (goal 65)". | Average {avg}. Goal 65. On watch {W}. | (1) "Set pickup and delivery capacity to the recommended values." (`pickup_capacity`/`rec_pickup`, `delivery_capacity`/`rec_delivery`) (2) if the Labor summary needs action: "Check Labor before adding hours. Target vs Actual is {labor avg}." | Store leader | `.dynacap`; (2) → `.labor` |
| **PPH** | "Shoppers pick fewer than 74 an hour at {R} of {N} stores" / "Your pure PPH is {v} (goal 80)" | Average {avg}. Goal 80. On watch {W}. | (1) "Coach the slowest shoppers, starting with {shopper_name} at store {store} ({pph})." Source: `picker_scorecard` rows with the lowest `pph` and `pickerHasVolume`. (2) if the Prep Not Ready summary needs action: "Get prep staged first. Prep Not Ready is {pnr avg}." | Store leader and the named shopper | `.pph`; (1) → `.pickerScorecard`; (2) → `.prepNotReady` |
| **Labor** | "Labor is more than 3% over target at {R} of {N} stores" / "Your labor is {v} vs target (goal 0% or less)" | Target vs Actual {avg}. Goal 0% or less. On watch {W}. | (1) if the Schedule summary needs action: "Fix the schedule first. {over} stores are over-scheduled." Otherwise: "Schedules are holding, so compare hours worked to hours scheduled." (2) at store level, if `act_cost_pct` > `cost_trgt_pct`: "Actual cost {act}% is over the {trgt}% target." | Store leader | `.labor`; (1) → `.scheduleQuality` |
| **Loss Revenue** | "{$} in lost sales. {R} of {N} stores are above 5%." / "Your store lost {$}, {pct}% of eComm sales (goal 3% or less)" | Total lost {avg} (money). Lost % = `lostRevenuePct`. Goal 3% or less. | (1) By the largest-dollar bucket in `lostRevenueMetricFlags`. Post Sub OOS Foregone → "Walk the top out-of-stocks with grocery. Check the backroom before every mark-out." Refund $ Fulfillment → "Audit fulfillment refunds. Recover and restage found items before refunding." Cancelled Orders LDAP → "Review every LDAP cancel with the shopper the same day." Kill Switch Lost Sales → "Keep kill switch off unless capacity is truly blocked." Reduced Capacity Missed Sales → "Put capacity back when the crew can hold the wave." (2) Name that bucket's dollars: "{bucket}: {$}." | By bucket: OOS → Grocery lead; refunds, cancels, and kill switch → Store leader | `.lostRevenue`; Reduced Capacity → `.dynacap` |
| **Sales** | "Sales are down versus last year at {R} of {N} stores" / "Your eComm sales are {$}, {yoy}% vs last year" | eComm sales {avg}. YoY = `salesRollupYoY` (the trend cell). Plan % if `sales_plan_pct` exists. | (1) "Open the down stores and check their 5 Star and Loss Revenue cards." | Store leader | `.sales` |
| **Picker ScoreCard** | Not a ranked card. It answers the shopper chip: "{opportunityCount} shoppers need coaching" | Shoppers {headline}. Doing well = `strongCount`. | One card per shopper, top 5, using `pickerMetricReadout` items where `needsAction`. "Floor-coach {name} on {failing items} during a live wave." | Store leader | `.pickerScorecard` |

Rules for every metric:
- An action whose data is missing is dropped, never reworded into a guess. If fewer than 1 action remains, the card shows the tap-through only. In practice action 3 (worst child) always exists above store level.
- Each action keeps to one verb sentence of 110 characters or fewer.
- Today's engine says "call-offs" and "no-shows" as fact. The pack has no call-off field, so the new copy never states them as fact (see Labor row).

## 10. Empty, stale, and healthy states

| State | Trigger (exact) | Copy | Buttons |
|---|---|---|---|
| **No pack** | `store.seeded == false`, or every `summaries[i].health == .none` | Title: "No Heartbeat data on this device yet." Body on `main`: "Assist answers only from the Heartbeat pack. Load it on Upload, or wait for today's pack to download." Body on the 477 line (no Upload screen): "Assist answers only from the Heartbeat pack. The Heartbeat pack comes from the server. Dashboard fills when it is on the device." (The second and third sentences are existing copy in `AssistEngine.swift` @ 0dcad79.) | `main`: "Open Upload" → `.upload`. 477 line: "Open Dashboard" → `.dashboard` |
| **Stale pack** | The newest `SectionSummary.lastUploadedAt` is more than 36 hours old. The 36-hour threshold is a proposed constant for the owner to confirm. | Banner above the answer, which still renders: "These numbers are from {data window or shortDate}. Today's pack hasn't loaded yet." | none |
| **No data for scope** | Filters active and every dashboard metric has `storeCount == 0` | Title: "No Heartbeat numbers for {scope label}." Body: "The pack has no rows for this filter. Clear it or pick another area." | "Clear filters" → `store.clearFilters()` |
| **Healthy** | At least 1 metric has data and no metric qualifies under 6.1 | Title: "Nothing needs fixing in {scope label}." Body: "All {k} scorecards with data are at goal." Then one line: "Closest to its goal: {metric} at {avg} (goal {goal})." This uses the smallest rollup margin and is left out if unknown. | chips from 11.2 |
| **Some scorecards empty** | Some metrics have `storeCount == 0` | Last line of the answer: "No data here for: {comma list of short names}." | none |
| **Unknown question** | See 12.2 | "I can answer from the numbers on this device. Try one of these:" followed by the current chips | chips |

## 11. Suggested chips

At most 4 chips, in one column, in the same order and with the same text on every device. Each label is 40 characters or fewer. Tapping a chip sends its text as the user's question. The chips are rebuilt after every answer and every scope change.

### 11.1 Issues state (at least 1 ranked card)
| Slot | Above store | Store |
|---|---|---|
| 1 | "What should we fix first?" | "What should this store fix first?" |
| 2 | "Which {child unit} is worst?" (region / market / district / OM / store per 8.1) | "Which shoppers need coaching here?" (only if picker rows exist; otherwise "What's on watch here?") |
| 3 | "Tell me more about {#1 short name}" | "Tell me more about {#1 short name}" |
| 4 | "Which shoppers need coaching?" if picker opportunity > 0; otherwise "What's on watch?" | "What's on watch here?" (skip if already slot 2) |

### 11.2 Healthy state
1. "What's on watch?" (only if any W > 0)
2. "Which {child unit} is worst?" (still answerable, and shows the lowest margins)
3. "Which shoppers need coaching?" (only if picker opportunity > 0)

### 11.3 Empty states
- No pack and no scope data: no chips.
- Stale: normal chips.

## 12. Free-text questions

### 12.1 Mapping to the same intents
Normalize the question: lowercase, curly apostrophes to straight, trim. Then match in this order. The first match wins.

| Order | Intent | Matches when | Answer |
|---|---|---|---|
| 1 | Store | A 3–5 digit token that exists in `store.stores` (a fix: today `namedStore` accepts any 3–5 digit number) | Cards for that store, scoped as in 8.1 store level, without changing global filters. Tapping an action applies `setStore`. |
| 2 | District / OM / market / region | A name in `store.districts`, `operationsOMs`, `divisions`, or `MarketRegion` names appears as a whole word | Cards for that unit |
| 3 | Shopper | A token of 4 or more characters that matches a `shopper_name` / `shopper_id` in scope | That shopper's card (Picker row in section 9) |
| 4 | Worst child | "worst", "bottom", "lowest", or "who is", plus district / store / market / region / om | 8.3 |
| 5 | Fix first | "fix", "first", "wrong", "priority", "do today", "start" | Header and cards |
| 6 | Metric detail | Metric synonyms: schedule; missing / aisle tag; path / aisle map; 5 star / five star / flash / presub / ott / oth / coe; pre-sub / oos; prep / pnr; dynacap / capacity; pph / picks per hour; labor / tva / cost; lost / loss / refund / cancel / kill switch; sales / yoy | A single card for that metric, even if healthy. A healthy metric uses the headline "{metric} is at goal: {avg} (goal {goal})". |
| 7 | Shoppers | "shopper", "picker", "ldap", "coach" | Picker cards |
| 8 | Watch | "watch" | Cards limited to metrics with W > 0, headline "{W} stores are close to missing {metric}" |
| 9 | Healthy | "healthy", "green", "holding", "good" | A list of healthy metrics, each shown as label over value (avg and goal) |
| — | Fallback | Nothing matched | Copy from section 10 |

The same question text with the same scope always gives the same intent. Chips are just preset questions that go through this same table.

### 12.2 Out of range
Questions about anything the pack does not hold go to the fallback. Examples: weather, "why" questions with no mapped metric, future forecasts, people who are not shoppers. Assist never guesses a cause.

## 13. Destinations: what exists and what does not

**Exists on `main`** (`HubDestination` in `MainHubView.swift`):
- `.dashboard`
- `.sales`
- `.lostRevenue` (page title "Loss Revenue ScoreCard")
- `.missingItems`
- `.fiveStar`
- `.preSubOOS`
- `.pickPath` (includes pickers and aisle map dates)
- `.prepNotReady`
- `.dynacap`
- `.scheduleQuality`
- `.pickerScorecard`
- `.pph`
- `.labor`
- `.checklist`
- `.upload`

**Exists on the 477 line** (PR #45 @ `0dcad79`; `HubDestination` moved to `Domain.swift`): the 13 cases above from `.dashboard` through `.labor`. **`.checklist` and `.upload` do not exist there.** Every card, check, state, or chip that would open Checklist or Upload opens **`.dashboard`** instead on that line.

Scope changes use `HeartbeatStore.setDivision`, `setDistrict`, `setOM`, `setStore`, `commitFilters`, and `clearFilters`. The filter bar has "Clear" (`FilterBar` in `SharedViews.swift`).

**Does not exist on `main` (flagged).** The card falls back to the nearest existing destination:
| Wanted | Status | Fallback in this spec |
|---|---|---|
| Seat pages: Company / Region / Division / District / OM / Store, with "Clear" plus a tappable crumb | Only on branch `cursor/grain-first-seat-shell-b84a` (`SeatHubView.swift`, `SeatChromeBanner`) | Apply the filter, then `.dashboard` |
| A single-store detail page | None on `main` | `setStore`, then `.dashboard` or the metric page |
| Deep link to one shopper | None | `.pickerScorecard` (with the store filter when known) |
| Deep link that preselects a Missing Items / Pre-Sub department chip | Not found | Open the page. The action text names the department. |
| Deep link that pre-sorts a store table worst-first | Not found | Open the page |
| `.checklist` / `.upload` on the 477 line (PR #45 @ `0dcad79`) | Removed from `HubDestination` on that line | `.dashboard` |

## 14. Formatting rules

1. **Numbers match the Dashboard.**
   - Rollups use `SectionSummary.headlineText` as-is: 1 decimal for %, 2 decimals for Labor %, 2 decimals for 5 Star, 1 decimal for PPH and Dynacap, whole dollars via `HeartbeatFormat.money`.
   - Store-level values use the same precision per metric.
   - Counts use `NumberFormatter` `.decimal`, so "1,822" and never "1822".
   - Do not use `HeartbeatFormat.pct` (2 decimals) anywhere a Dashboard value uses 1.
2. **Plain words.**
   - No ALL-CAPS headings. Today's "ISSUE", "WHAT TO DO", and `title.uppercased()` go away.
   - No "·" chains. Write full sentences, or use label-over-value cells.
   - Say "stores" or "shoppers", never a bare count.
3. **Label over value.** Every number has a small label above it. No number appears inline in a run-on list.
4. **Tap targets.** Chips, action rows, the header lines, and the footer button are each at least 44 × 44 points. There is at least 8 points of spacing between tappable rows.
5. **Dynamic Type.**
   - Only text styles (`.caption`, `.body`, `.title3`, …). No fixed sizes except the existing 32-point send icon.
   - At AX1 and up, the fact row stacks vertically.
   - Nothing truncates. Everything wraps.
6. **Dark mode.**
   - Replace hard-coded `Color.white` backgrounds in `AssistView.swift` (the prompt bank, composer, and assist bubble) with semantic or `AppTheme` surfaces that adapt.
   - The status pill uses text and a symbol, so it still reads in grayscale.
7. **Accessibility.** Each card is one accessibility element with a combined label: "Rank 1, Schedule Quality, at risk. {headline}. {R} of {N} stores at risk. Scope {scope}." Actions are separate buttons labeled "{verb sentence}. Owner {role}. Opens {screen}."
8. **Length.**
   - Headline: 90 characters or fewer.
   - Action: 110 characters or fewer.
   - Header line: 48 characters or fewer.
   - Chip: 40 characters or fewer.
   - At most 3 cards before "More issues (n)".

## 15. Acceptance checks (QC scores each as PASS or FAIL on iPhone, iPad, and Mac)

Setup: use the same pack on all three devices, installed from the same build. Airplane mode is on unless a check says otherwise. Run each check on each device and record a separate PASS or FAIL for each.

| # | Check | How to observe | iPhone | iPad | Mac |
|---|---|---|---|---|---|
| 1 | Same answer everywhere | Ask "What should we fix first?" at company scope. Card order, headlines, numbers, actions, and chip text are word-for-word the same on all three devices. | | | |
| 2 | Single column | The answer and the chips are in one column. On iPad landscape and a full-width Mac window, the content column is no wider than 680 points and is centered. | | | |
| 3 | Header present | "Fix these N first" appears above the cards with N = min(3, qualifying metrics). Each line is 48 characters or fewer and tapping it scrolls to that card. | | | |
| 4 | Card parts | Every card shows: rank + metric + status pill, a plain headline, the "Stores at risk" number (or the store value), the fact row, "Scope: …", "What to do" with 1–3 actions each having an owner and "Open … ›", "More checks ›" when the metric has more checks, and a footer tap-through. | | | |
| 5 | Numbers match the Dashboard | For each card, Average equals that metric's Dashboard headline, and R, W, and N match its Dashboard at-risk, watch, and store counts in the same scope. | | | |
| 6 | Ranking matches the formula | Load fixture 15.2 (a unit test or debug pack). The order is exactly B, A, C, D, and "How this was ranked" shows the fixture's R, W, and D̄. | | | |
| 7 | Healthy metrics excluded | No card appears for a metric with R + W = 0. The metric is counted in the healthy line or omitted. | | | |
| 8 | Picker not ranked | No ranked card uses shopper counts as stores. The "24671 at risk" style line is gone. | | | |
| 9 | Tap-through works | Every action and footer dismisses Assist, applies the stated filter, and lands on the named screen, showing the scope label's filter in the filter bar. | | | |
| 10 | Worst child | "Which district is worst?" at a division scope returns 3 district cards ranked per 8.3, each with "Open District …" that filters correctly. | | | |
| 11 | Scope rewrites wording | Change the filter from company to a district to a store and ask again. The scope label, "{R} of {N}", owner role, and action 3 change as in 8.1. At store scope, headlines say "Your …" and show no "of" count. | | | |
| 12 | Store name | At store scope, the label reads "Store {number}, {name}" when the roster has a name, and "Store {number}" when it doesn't. | | | |
| 13 | Trend only when real | A trend cell appears on Sales (YoY) only when `sales_yoy_pct` is present. It appears on another metric only if history has 2 or more dates. There are no dashes or placeholder trends. | | | |
| 14 | No invented names | Owner lines show role labels only, and the only person names are shoppers from the pack. | | | |
| 15 | No-pack state | On a fresh install with no pack: the exact no-pack copy appears with no chips, plus "Open Upload" on `main`, or "Open Dashboard" (landing on Dashboard) on the 477 line. | | | |
| 16 | No-data-for-scope state | A filter with no rows shows the exact copy and a "Clear filters" button that clears. | | | |
| 17 | Healthy state | With a fixture where everything is at goal: "Nothing needs fixing in {scope}." and the healthy chips. | | | |
| 18 | Stale banner | With a pack whose newest upload is more than 36 hours old, the banner shows above the cards and the cards still render. | | | |
| 19 | Chips | At most 4 chips, in one column, following 11.1 / 11.2 for the state and scope. Tapping one produces the same answer as typing its text. | | | |
| 20 | Free text | "whats wrong in store {valid number}" gives that store's cards. "store 99999" (not in the roster) gives the fallback. "pnr" gives a single Prep Not Ready card. | | | |
| 21 | Formatting | No ALL-CAPS headings, no "·" in the answer, and every count has thousands separators. | | | |
| 22 | Dynamic Type | At AX3, nothing truncates, the fact row stacks, and the layout is identical across devices. | | | |
| 23 | Dark mode | All text is readable. There are no white slabs in the prompt bank, composer, or cards. | | | |
| 24 | Deterministic | Asking the same question twice gives identical text and order. | | | |
| 25 | No network | With airplane mode on, every answer above still works. A code search of the Assist files shows no `URLSession`, `PulseCloud`, or network calls. | | | |
| 26 | Floor vs. auto rendering | On the 5 Star OTT ("Poor OTT") card at store scope, floor checks read as questions ending in "?". Auto checks read as statements with a number and no "?", e.g. "PPH 58, under 65". Both show "Owner: …" and "Open … ›". | | | |
| 27 | Auto check values match | For a store, the value in "PPH {v}, under 65" equals that store's `pph` (or `pure_pph`) on the PPH page. "Under-scheduled" shows yes exactly when `under_schedule_pct` > 5, and its Sch vs Tgt value equals the Schedule Quality page. Above store scope, "{k} of {n} stores" matches a manual count in the same filter. | | | |
| 28 | Auto check slots | A passing auto check never takes an action slot. It appears under "More checks ›" with "OK" text and a symbol. An auto check whose field is missing for the scope does not appear anywhere. | | | |
| 29 | More checks row | On a card whose entry has more checks than fit, "More checks ›" is collapsed by default. It expands to the remaining checks in playbook order, and is absent when there are none. Each row is at least 44 points tall. | | | |
| 30 | Owner wording | The High Pre Subs card (Pre-Sub OOS, and the 5 Star Presub part) shows, in order: "Are shoppers using radios?", "Is the whole store using radios?", "Is store PI (perpetual inventory) accurate?" with the detail line. The PPH card's first check is "Are shoppers picking 30 items within the first 15 minutes of their run or shift start?". The wording is word-for-word, with no "(confirm)" shown. | | | |
| 31 | Why line shown | With a fixture where Reduced Capacity Missed Sales is watch or risk and OTT and PPH (< 65) both fail at the scope, the Loss Revenue card shows "Why: low capacity, from late orders (OTT {ott}%) and slow picking (PPH {pph})." with the values matching the 5 Star and PPH pages for the same scope. | | | |
| 32 | Why line names only failing causes | Same fixture, but PPH ≥ 65: the line names OTT only. OTT full and PPH < 65: PPH only. Both healthy: "Why: low capacity ({missed} missed sales)." | | | |
| 33 | Why line hidden | With Reduced Capacity healthy or absent at the scope, no Why line appears, even if OTT or PPH fail. Change scope to a store where it fails, ask again, and the line appears for that store only. | | | |
| 34 | Why line tap | Tapping the Why line expands the failing auto checks of the named causes for the same scope. Each "Open … ›" lands on the right page with the same filter. | | | |
| 35 | 477 destinations | On a build from PR #45 @ `0dcad79`, no card, check, state, or chip tries to open Checklist or Upload. Those fall back to Dashboard. Every destination in `playbook.json` opens. | | | |
| 36 | Assist opens with no hitch | Open Assist, then ask "What should we fix first?". The sheet appears immediately and the answer fills in without freezing the screen. | | | |

### 15.2 Ranking fixture (for check 6)
Company scope, all rows in one region. Expected scores:

| Metric | health | R | W | D̄ | Score | Rank |
|---|---|---|---|---|---|---|
| A = Missing Items | risk | 10 | 4 | 0.50 | 3 × 12 × 1.5 = 54 | 2 |
| B = Pick Path | risk | 8 | 10 | 1.00 | 3 × 13 × 2.0 = 78 | 1 |
| C = Dynacap | good (average ≥ 65) | 30 | 0 | 0.20 | 1 × 30 × 1.2 = 36 | 3 |
| D = PPH | watch | 0 | 20 | 0.40 | 2 × 10 × 1.4 = 28 | 4 |

PPH's 0.40 is twenty stores at 74. Under the Assist band that is Watch (65 to < 80), and (80 − 74) / 15 = 0.40. A store under 65 is At risk and would raise R. Other pages still color 74 as the risk line.

Tie-break test: add E = Labor (risk, R = 8, W = 10, D̄ = 1.00, so Score 78, the same as B). E ranks after B because R and W tie, D̄ ties, and Pick Path comes before Labor in `dashboardCards`.

---

## Appendix A: Evidence (main @ `e44f1405dc377b79f1e8711e6b4f9b582e8a8004`)

| File | What it holds | Key symbols and fields |
|---|---|---|
| `FulfillmentHeartbeat/Views/AssistView.swift` | The Assist sheet | `HeartbeatAssistSheet`, `HubBanner(title: "Heartbeat Assist", accessory: router.current.title · filters.summary)`, prompt header "Ask anything across the heartbeat", `LazyVGrid(.adaptive(minimum: 320))`, bubble `maxWidth: 980`, `TextField("Ask Heartbeat Assist…")`, `Color.white` surfaces, `ask()` → `HeartbeatAssist.answer` |
| `FulfillmentHeartbeat/Models/AssistEngine.swift` | Answer builder | `HeartbeatAssist.Intent` (overview, districts, stores, shoppers, buckets, fiveStar, path, missing, prep, dynacap, schedule, pph, labor, picker, healthy, watch, fix, upload, store, district, shopper); `pagePrompts` (Dashboard: "What's at risk across the heartbeat?", "Who is the worst district?", "Which stores are causing the most damage?", "Which shoppers should we coach first?", "How do we fix it today?"); `mappedPrompt`, `keywordIntent`; `Brain.overview()` bullet `"• {label}: {headlineText}  ·  {health.label}  ·  {riskCount} at risk / {watchCount} watch"`; `header()` with `uppercased()`; `rankedDistricts` (uses `opportunitySortValue`); `namedStore` (any 3–5 digits) |
| `FulfillmentHeartbeat/Models/Domain.swift` | Model, status, and thresholds | `MetricSection` (16 cases, below); `MetricRow {section, division, operationsOM, storeNumber, storeName, recordedOn, payload[String: Double], textPayload[String: String]}`, `district` = `textPayload["district"]`, `omArea` = `textPayload["om_area"]`, `shopperName`/`shopperId`; `Health {good, watch, risk, none}`, labels "Healthy", "Watch", "At risk", "No data"; `SectionSummary {storeCount, headline, headlineLabel, secondary, health, watchCount, riskCount, lastFilename, lastUploadedAt, underScheduledCount, overScheduledCount, lostRevenuePct}` and `headlineText`; `HeartbeatMath.summarize`, `health(for:row:)`, `band`, `dashboardCallouts` (5 Star pin), `opportunitySortValue`, `topOpportunityStores`, `history`, `fiveStarActionFlags`, `lostRevenueMetricFlags`, `scheduleActionFlags`, `laborActionFlags`, `dynacapActionFlags`, `preSubActionFlags`, `pickPathMetricFlags`, `pickerMetricReadout`, `salesRollupYoY`; constants `pnrGoal 1.9`, `pnrWatch 2.5`, `pphGoal 80`, `pphRisk 74`, `laborWatch 3`, `lostRevenueGood 3`, `lostRevenueWatch 5`, `salesPlanGood 100`, `salesPlanWatch 95`, `missingItemsGoal 5`, `missingItemsWatch 6.5`, `pickPathGoal 90`, `pickPathRisk 80`, `dynacapGoal 65`, `dynacapRisk 60`, `scheduleGoal 90`, `scheduleWatch 85`, `scheduleVarianceWatch 5`, 5 Star band 4.5 / 4.0; `HeartbeatRole` (backstage, evp, director, districtManager, om); `DashScopeGrain` (region, division, district, store); `DashboardFilters {region, division, district, om, store}` and `summary` ("All regions · All divisions · All districts · All OMs · All stores"); `MarketRegion` (East, South, California, West → divisions); `MissingItemDept` (`mi_grocery`…`mi_bakery_pkgd`, total `mi_pct`); `AisleMapperMath` (`aisle_mapper_date`, `aisle_sequence_date`, 90-day risk); `HeartbeatFormat` |
| `FulfillmentHeartbeat/Storage/HeartbeatStore.swift` | Data access | `seeded`, `filters`, `sessionRole`, `summaries`, `summary(for:)`, `displayRows(for:)`, `history(for:)`, `dataWindow(for:)` (`textPayload["data_window"]`), `sharedDataWindow()`, `divisions`/`districts`/`operationsOMs`/`stores`, `effectiveDashboardGrain`, `setDivision`/`setDistrict`/`setOM`/`setStore`/`commitFilters`/`clearFilters` |
| `FulfillmentHeartbeat/Storage/PulseSQLite.swift` | Pack format | `heartbeat.sqlite`: `pack_meta(schema_version, seeded, written_at, uploads_json, counts_json)`, `facts(id, section, store_number, division, operations_om, store_name, recorded_on, payload_json, text_json)`, `dash_chrome`; `Pack.writtenAt` |
| `FulfillmentHeartbeat/Storage/PulseFacts.swift` | facts.json | `PulseFactRow {store, division, district, om, name, numbers, text}`; sections roster, lostRevenue, sales, fiveStar |
| `FulfillmentHeartbeat/Storage/PulseCloud.swift` | Network (pack download only; Assist must not use it) | R2 host, `downloadPack`, `downloadFacts` |
| `FulfillmentHeartbeat/MainHubView.swift` | Navigation | `HubDestination` (15 cases), `HubRouter.open(_:)` / `open(section:)` |
| `FulfillmentHeartbeat/Views/SharedViews.swift` | Assist entry, filter bar | `HubBrandBar.assistButton` → `.fullScreenCover { HeartbeatAssistSheet() }`; `FilterBar` "Clear" |
| `FulfillmentHeartbeat/Models/ChecklistDiagnosis.swift` | Existing action copy reused in section 9 | e.g. "Set pickup and delivery to the recommended values…", the refund, LDAP cancel, and kill switch lines |
| `FulfillmentHeartbeat.xcodeproj/project.pbxproj` | Platforms | `TARGETED_DEVICE_FAMILY = "1,2,6"`, `SUPPORTS_MACCATALYST = YES` (iPhone, iPad, Mac from one target) |
| Branch only: `cursor/grain-first-seat-shell-b84a` @ `f38b748036d22171de4280654f9f9ca1805e9543` | Screenshot build line | `AssistEngine.swift` with `seatWrong()` ("… · Stores {storeCount}"), chip "What's wrong and what should we do first?", `coach()` sections; `Views/SeatHubView.swift` (`SeatChromeBanner` Clear + crumb, `SeatPageView`) |

**Metrics found** (`MetricSection`, raw value → title):
- Dashboard metrics (12, `dashboardCards`):
  - `sales` → Sales
  - `lost_revenue` → Loss Revenue
  - `missing_items` → Missing Items
  - `five_star` → 5 Star Metrics (parts: Flash `flash_pct`, Presub `presub_pct`, COE `coe_pct`, OTT `ott_pct`, OTH5 `oth5_pct`)
  - `pre_sub_oos` → Pre-Sub OOS
  - `pick_path` → Pick Path Compliance
  - `prep_not_ready` → Prep Not Ready
  - `dynacap` → Dynacap Setting
  - `schedule_quality` → Schedule Quality
  - `picker_scorecard` → Picker ScoreCard
  - `pph` → PPH Pure Picks Per Hour
  - `labor` → Labor
- Supporting sections (4):
  - `pick_path_picker` → Pick Path Compliance Picker
  - `aisle_mapper` → Aisle Mapper
  - `pre_sub_oos_item` → Pre-Sub OOS Item
  - `store_roster` → Roster

**Main per-store fields used:**
- Pick Path: `compliance_pct`
- Missing Items / Pre-Sub OOS: `mi_pct`, `mi_*`
- Prep Not Ready: `pnr_rate_pct`
- Dynacap: `dynacap_rate` / `pieces_per_hour`, `pickup_capacity`, `delivery_capacity`, `rec_pickup`, `rec_delivery`, `utilization_pct`
- Schedule: `schedule_efficiency_pct`, `staffing_efficiency_pct`, `under_schedule_pct`, `over_schedule_pct`
- PPH: `pph`
- Labor: `target_vs_actual_pct`, `act_cost_pct`, `cost_trgt_pct`
- 5 Star: `star_rating`
- Loss Revenue: `lost_revenue`, `lost_revenue_pct`, `ecomm_sales`, `post_sub_oos_foregone`, `refund_lost`, `cancelled_lost`, `kill_switch_lost`, `missed_sales` / `reduced_capacity`
- Sales: `sales_dollars`, `sales_yoy_pct`, `sales_plan`, `sales_plan_pct`, `sales_orders`
- Picker: `pph`, `presub_pct`, `oos_pct`, `ott_pct`, `oth5_pct`, `coe_pct`, `refund_amt`, `orders`, `pick_hours`
- Pre-Sub OOS Item: `presub_pct`, `bpn` (text)

## Appendix B: Gaps (fields and destinations that do not exist)

1. **No prior-period or trend fields** for any metric except Sales (`sales_yoy_pct`). `HeartbeatMath.history` only gives a trend if the loaded rows carry 2 or more `recordedOn` dates, and summaries use `latestPerStore`. The trend cell is therefore omitted for most metrics.
2. **Targets are not in the pack.** They are app constants in `HeartbeatMath`. The exceptions are Labor `cost_trgt_pct` and Sales `sales_plan` / `sales_plan_pct`.
3. **No owner names.** `om` is OM_AREA/OM_ID text, and `district` is a district label. There is no OM, district manager, or store leader name. Only shopper names exist (`shopper_name`, `shopper_id`). Owners are therefore role labels.
4. **Pack freshness is not exposed.** `pack_meta.written_at` is read into `PulseSQLite.Pack.writtenAt`, but `HeartbeatStore` on `main` does not expose it. The stale check uses `SectionSummary.lastUploadedAt` and the `data_window` text instead. The 36-hour threshold is a proposed constant for the owner to confirm.
5. **Region is not a pack field.** It is derived from division by `MarketRegion`'s hard-coded map.
6. **No call-off or no-show field.** Today's Labor and Schedule copy states call-offs as fact. The new copy must not.
7. **"N stores" differs by metric.** It is `summary.storeCount` (stores with data for that metric), not the roster total.
8. **Picker ScoreCard `riskCount` counts shoppers**, not stores. It is excluded from ranking.
9. **Destinations missing on `main`:**
   - seat pages (Company / Region / Division / District / OM / Store) with Clear + crumb (branch only)
   - a single-store detail page
   - a single-shopper deep link
   - a department-chip deep link on Missing Items / Pre-Sub
   - a worst-first sort deep link
   Fallbacks are in section 13.
10. **Screenshot vs `main`:** the screenshot build is from the seat-shell branch line, not `main` (see top note).

**v2 additions (477 line, PR #45 @ `0dcad79`):**

- **No store-level sub rate.** "High Pre Subs" uses `presub_pct`. Picker `subs` is an unbanded count. The item-level `subs_pct` is parsed but never read by `Domain.swift`.
- **Under-scheduled has two candidate definitions:**
  - The code's definition is `under_schedule_pct` (Sch vs Tgt) > 5.
  - The owner's example is "Pch vs Sch", which is `under_adherence_pct`. It is parsed but has no band. (confirm)
- **PPH ranking (owner decision):** Assist ranks At risk < 65, Watch 65 to < 80, Healthy >= 80. Other pages keep 80 / 74.
- **"30 items in the first 15 minutes" has no pack field.** It stays a floor question only.
- **`.checklist` / `.upload` are absent on the 477 line.** They fall back to `.dashboard`.
