import SwiftUI

struct RoleGateView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var role: HeartbeatRole?
    @State private var query = ""
    @State private var selected: Set<String> = []

    private var phone: Bool { HubLayout.isPhone(sizeClass) }

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: phone ? 22 : 28) {
                    if let role {
                        scopeHeader(role)
                        scopeStep(role)
                    } else {
                        seatHeader
                        roleStep
                    }
                }
                .padding(.horizontal, phone ? 20 : 36)
                .padding(.vertical, phone ? 20 : 36)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if role != nil {
                continueBar
            }
        }
        .contentShape(Rectangle())
        .preferredColorScheme(.light)
    }

    private var seatHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            BeatingHeartbeatMark(height: phone ? 40 : 56, showsTrace: true, forceTrace: true)
            Text("Who’s looking?")
                .font(phone ? .largeTitle.weight(.bold) : .largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.text)
            Text("Pick a seat. The dashboard only includes that book of business.")
                .font(phone ? .body : .title3)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if store.sessionRole != nil {
                Button("Stay in this view") {
                    store.finishRoleGate()
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.blue)
                .padding(.top, 2)
            }
            Text("Choose a seat")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.top, 8)
            if store.warehouseHydrating {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppTheme.blue)
                    Text(store.aisleFillCaption)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }
                .padding(.top, 4)
            }
        }
    }

    private func scopeHeader(_ role: HeartbeatRole) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: backToSeats) {
                Label("Back to Who’s looking", systemImage: "chevron.left")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
                    .frame(minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to Who’s looking")

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: role.symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 6) {
                    Text(scopeTitle(role))
                        .font(phone ? .title2.weight(.bold) : .title.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                    Text(scopeDetail(role))
                        .font(phone ? .body : .title3)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var roleStep: some View {
        VStack(spacing: 14) {
            ForEach(HeartbeatRole.allCases) { item in
                Button {
                    pick(item)
                } label: {
                    roleCard(item)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pick(_ item: HeartbeatRole) {
        if item == .backstage {
            store.applyLaunchRole(.backstage)
        } else {
            query = ""
            selected = []
            role = item
        }
    }

    private func backToSeats() {
        role = nil
        query = ""
        selected = []
    }

    private func roleCard(_ item: HeartbeatRole) -> some View {
        HStack(alignment: .center, spacing: phone ? 14 : 18) {
            Image(systemName: item.symbol)
                .font((phone ? Font.title3 : Font.title2).weight(.semibold))
                .foregroundStyle(AppTheme.blue)
                .frame(width: phone ? 36 : 44, height: phone ? 36 : 44)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font((phone ? Font.headline : Font.title3).weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    .multilineTextAlignment(.leading)
                Text(item.detail)
                    .font(phone ? .subheadline : .body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(.horizontal, phone ? 16 : 20)
        .padding(.vertical, phone ? 16 : 20)
        .frame(minHeight: phone ? 84 : 96, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .stroke(AppTheme.blue.opacity(0.18), lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private func scopeStep(_ role: HeartbeatRole) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            searchField(role.searchPrompt)
            selectedSummary(role)
            switch role {
            case .evp:
                choiceList(choices: evpChoices, empty: "No regions available.")
            case .director:
                directorList
            case .districtManager:
                choiceList(
                    choices: filteredDistricts,
                    empty: "No districts in the Heartbeat pack yet. Stay here — the pack fills after ready."
                )
            case .om:
                choiceList(
                    choices: filteredOMs,
                    empty: "No operations managers in the Heartbeat pack yet. Stay here — the pack fills after ready."
                )
            case .store:
                choiceList(
                    choices: filteredStores,
                    empty: "No stores in the Heartbeat pack yet. Stay here — the pack fills after ready."
                )
            case .backstage:
                EmptyView()
            }
        }
    }

    private var continueBar: some View {
        let count = selected.count
        let noun = role.map { count == 1 ? $0.pickNoun : "\($0.pickNoun)s" } ?? "items"
        return VStack(spacing: 10) {
            Button(action: continueIntoDashboard) {
                Text(count == 0 ? "Select at least one" : "Continue with \(count) \(noun)")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(count == 0)
            .opacity(count == 0 ? 0.45 : 1)
            Button("Back to Who’s looking", action: backToSeats)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.blue)
                .frame(minHeight: 36)
        }
        .padding(.horizontal, phone ? 20 : 36)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(AppTheme.bg.opacity(0.96))
    }

    private func continueIntoDashboard() {
        guard let role, !selected.isEmpty else { return }
        let joined = selected.sorted().joined(separator: "\n")
        switch role {
        case .evp:
            store.applyLaunchRole(.evp, region: joined)
        case .director:
            store.applyLaunchRole(.director, division: joined)
        case .districtManager:
            store.applyLaunchRole(.districtManager, district: joined)
        case .om:
            store.applyLaunchRole(.om, om: joined)
        case .store:
            store.applyLaunchRole(.store, store: joined)
        case .backstage:
            store.applyLaunchRole(.backstage)
        }
    }

    private func searchField(_ prompt: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            TextField(prompt, text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .stroke(AppTheme.blue.opacity(0.22), lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private func selectedSummary(_ role: HeartbeatRole) -> some View {
        let count = selected.count
        let noun = count == 1 ? role.pickNoun : "\(role.pickNoun)s"
        VStack(alignment: .leading, spacing: 10) {
            Text(count == 0 ? "Nothing selected yet · tap one or many" : "\(count) \(noun) selected")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(count == 0 ? AppTheme.textSecondary : AppTheme.blue)
            if count > 0 {
                FlowChips(titles: selectedLabels(role), onRemove: { selected.remove($0) })
            }
        }
    }

    private func selectedLabels(_ role: HeartbeatRole) -> [(id: String, label: String)] {
        let lookup = Dictionary(uniqueKeysWithValues: allChoices(role).map { ($0.id, $0.label) })
        return selected.sorted().map { id in
            (id: id, label: lookup[id] ?? id)
        }
    }

    private func allChoices(_ role: HeartbeatRole) -> [(id: String, label: String)] {
        switch role {
        case .evp: return evpChoices
        case .director: return directorChoices
        case .districtManager: return filteredDistricts
        case .om: return filteredOMs
        case .store: return filteredStores
        case .backstage: return []
        }
    }

    private var evpChoices: [(id: String, label: String)] {
        MarketRegion.allCases.map { region in
            (id: region.rawValue, label: region.rawValue)
        }
        .filter { matchesQuery($0.label) || matchesQuery($0.id) }
    }

    private var directorChoices: [(id: String, label: String)] {
        MarketRegion.allCases.flatMap { region in
            region.gateDivisions.map { division in
                (id: division, label: division)
            }
        }
    }

    private var directorList: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(MarketRegion.allCases) { region in
                let markets = region.gateDivisions
                    .map { (id: $0, label: $0, detail: region.rawValue) }
                    .filter { matchesQuery($0.label) || matchesQuery($0.detail) }
                if !markets.isEmpty {
                    Text(region.rawValue)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                        .padding(.top, 4)
                    ForEach(markets, id: \.id) { item in
                        choiceCard(id: item.id, title: item.label, detail: item.detail)
                    }
                }
            }
        }
    }

    private func choiceList(choices: [(id: String, label: String)], empty: String) -> some View {
        Group {
            if choices.isEmpty {
                Text(empty)
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, 12)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 10) {
                    ForEach(choices, id: \.id) { item in
                        choiceCard(id: item.id, title: item.label, detail: nil)
                    }
                }
            }
        }
    }

    private func choiceCard(id: String, title: String, detail: String?) -> some View {
        let on = selected.contains(id)
        return Button {
            if on {
                selected.remove(id)
            } else {
                selected.insert(id)
            }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(on ? AppTheme.blue : AppTheme.textTertiary)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                        .multilineTextAlignment(.leading)
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(minHeight: 64, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                    .fill(on ? AppTheme.blue.opacity(0.08) : AppTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                    .stroke(on ? AppTheme.blue : AppTheme.blue.opacity(0.16), lineWidth: on ? 2 : 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func scopeTitle(_ role: HeartbeatRole) -> String {
        switch role {
        case .evp: return "Choose region(s)"
        case .director: return "Choose market(s)"
        case .districtManager: return "Choose district(s)"
        case .om: return "Choose OM(s)"
        case .store: return "Choose store(s)"
        case .backstage: return ""
        }
    }

    private func scopeDetail(_ role: HeartbeatRole) -> String {
        switch role {
        case .evp:
            return "Tap one region or many. Search, then Continue into that combined book."
        case .director:
            return "Tap one market or many. Districts stay under each callout."
        case .districtManager:
            return "Tap one district or many. Those stores sit under each callout."
        case .om:
            return "Tap one OM or many. Assigned stores sit under each callout."
        case .store:
            return "Tap one store or many. The dashboard is that store book of business."
        case .backstage:
            return ""
        }
    }

    private var filteredDistricts: [(id: String, label: String)] {
        store.filterChoices(focus: .district, draft: DashboardFilters())
            .filter { matchesQuery($0.label) || matchesQuery($0.id) }
    }

    private var filteredOMs: [(id: String, label: String)] {
        store.filterChoices(focus: .om, draft: DashboardFilters())
            .filter { matchesQuery($0.label) || matchesQuery($0.id) }
    }

    private var filteredStores: [(id: String, label: String)] {
        store.filterChoices(focus: .store, draft: DashboardFilters())
            .filter { matchesQuery($0.label) || matchesQuery($0.id) }
    }

    private func matchesQuery(_ value: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return true }
        return value.localizedCaseInsensitiveContains(q)
    }
}

private struct FlowChips: View {
    let titles: [(id: String, label: String)]
    var onRemove: (String) -> Void

    var body: some View {
        FlexibleChipWrap(items: titles, onRemove: onRemove)
    }
}

private struct FlexibleChipWrap: View {
    let items: [(id: String, label: String)]
    var onRemove: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.id) { item in
                Button {
                    onRemove(item.id)
                } label: {
                    HStack(spacing: 6) {
                        Text(item.label)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(AppTheme.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppTheme.blue.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(item.label)")
            }
        }
    }
}
