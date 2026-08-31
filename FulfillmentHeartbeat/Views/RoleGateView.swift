import SwiftUI

struct RoleGateView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @State private var role: HeartbeatRole?
    @State private var query = ""

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if let role {
                        scopeStep(role)
                    } else {
                        roleStep
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 32)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.light)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            BeatingHeartbeatMark(height: 56, showsTrace: true)
            Text("Who’s looking?")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.text)
            Text("Shown each time the app opens. Pick your seat, then the dashboard only includes that book of business.")
                .font(.title3)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var roleStep: some View {
        VStack(spacing: 12) {
            ForEach(HeartbeatRole.allCases) { item in
                Button {
                    if item == .backstage {
                        store.applyLaunchRole(.backstage)
                    } else {
                        query = ""
                        role = item
                    }
                } label: {
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: item.symbol)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.blue)
                            .frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                                .multilineTextAlignment(.leading)
                            Text(item.detail)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                            .fill(AppTheme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                            .stroke(AppTheme.blue.opacity(0.18), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func scopeStep(_ role: HeartbeatRole) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                self.role = nil
                query = ""
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(AppTheme.blue)
            }
            .buttonStyle(.plain)

            Text(scopeTitle(role))
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.text)
            Text(scopeDetail(role))
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            switch role {
            case .evp:
                ForEach(MarketRegion.allCases) { region in
                    Button {
                        store.applyLaunchRole(.evp, region: region.rawValue)
                    } label: {
                        scopeCard(
                            title: region.rawValue,
                            detail: region.gateDivisions.joined(separator: " · ")
                        )
                    }
                    .buttonStyle(.plain)
                }
            case .director:
                ForEach(MarketRegion.allCases) { region in
                    Text(region.rawValue)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                        .padding(.top, 8)
                    ForEach(region.gateDivisions, id: \.self) { division in
                        Button {
                            store.applyLaunchRole(.director, division: division)
                        } label: {
                            scopeCard(title: division, detail: region.rawValue)
                        }
                        .buttonStyle(.plain)
                    }
                }
            case .om:
                omStep
            case .districtManager:
                districtStep
            case .backstage:
                EmptyView()
            }
        }
    }

    private var districtStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Search districts", text: $query)
                .textFieldStyle(.roundedBorder)
            if filteredDistricts.isEmpty {
                Text("No districts in the loaded files yet. Upload the workbooks, then reopen the app.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.top, 8)
            } else {
                ForEach(filteredDistricts, id: \.self) { district in
                    Button {
                        store.applyLaunchRole(.districtManager, district: district)
                    } label: {
                        scopeCard(title: district, detail: "District")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var omStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Search operations managers", text: $query)
                .textFieldStyle(.roundedBorder)
            if filteredOMs.isEmpty {
                Text("No operations managers in the loaded files yet. Upload the workbooks, then reopen the app.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.top, 8)
            } else {
                ForEach(filteredOMs, id: \.self) { om in
                    Button {
                        store.applyLaunchRole(.om, om: om)
                    } label: {
                        scopeCard(title: om, detail: "Operations Manager")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func scopeCard(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    .multilineTextAlignment(.leading)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                .stroke(AppTheme.blue.opacity(0.16), lineWidth: 1.5)
        )
    }

    private func scopeTitle(_ role: HeartbeatRole) -> String {
        switch role {
        case .evp: return "Choose your region"
        case .director: return "Choose your market"
        case .districtManager: return "Choose your district"
        case .om: return "Choose your OM"
        case .backstage: return ""
        }
    }

    private func scopeDetail(_ role: HeartbeatRole) -> String {
        switch role {
        case .evp:
            return "Dashboard and scorecards stay inside that region. Markets sit under each callout."
        case .director:
            return "Only that division’s stores. Districts sit under each callout."
        case .districtManager:
            return "Only this district’s stores. Those stores sit under each callout."
        case .om:
            return "Only stores on this OM. Those stores sit under each callout."
        case .backstage:
            return ""
        }
    }

    private var filteredDistricts: [String] {
        let all = store.filterChoices(focus: .district, draft: DashboardFilters()).map(\.id)
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    private var filteredOMs: [String] {
        let all = store.filterChoices(focus: .om, draft: DashboardFilters()).map(\.id)
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(q) }
    }
}
