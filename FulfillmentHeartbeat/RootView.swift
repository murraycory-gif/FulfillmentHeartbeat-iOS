import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: HeartbeatStore

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            if store.isReady && !store.isImporting {
                MainHubView()
                    .transition(.opacity)
                    .overlay {
                        if store.needsRolePick {
                            RoleGateView()
                                .transition(.opacity)
                        }
                    }
            } else {
                LaunchSplashView()
            }
        }
        .preferredColorScheme(.light)
        .tint(AppTheme.blue)
        .background(AppTheme.bg.ignoresSafeArea())
        .onOpenURL { url in
            store.receiveExternalFile(url: url)
        }
        .sheet(isPresented: Binding(
            get: { store.pendingExternalName != nil },
            set: { if !$0 { store.dismissPending() } }
        )) {
            PendingImportSheet()
                .environmentObject(store)
        }
        .animation(.easeOut(duration: 0.18), value: store.isReady)
        .animation(.easeOut(duration: 0.18), value: store.needsRolePick)
    }
}

struct LaunchSplashView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let phone = HubLayout.isPhone(sizeClass)
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            VStack(spacing: phone ? 18 : 24) {
                BeatingHeartbeatMark(
                    height: phone ? 78 : 96,
                    showsTrace: true,
                    showsWordmark: false
                )
                FulfillmentWordmark(height: phone ? 46 : 58)
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(AppTheme.blue)
                    Text(statusLine)
                        .font(.system(size: phone ? 14 : 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Fulfillment")
        .accessibilityValue(statusLine)
    }

    private var statusLine: String {
        if let label = store.importLabel, store.isImporting {
            let loaded = store.importProgress.loaded
            let expected = max(store.importProgress.expected, 1)
            return "Loading the data · \(label) · \(loaded) of \(expected)"
        }
        if store.isImporting {
            let loaded = store.importProgress.loaded
            let expected = max(store.importProgress.expected, 1)
            return "Loading the data · \(loaded) of \(expected)"
        }
        return "Loading the data"
    }
}

struct PendingImportSheet: View {
    @EnvironmentObject private var store: HeartbeatStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let name = store.pendingExternalName {
                    Section("File") {
                        Text(name)
                            .font(.headline)
                    }
                }
                Section("Import into") {
                    ForEach(MetricSection.uploadOrder) { section in
                        Button {
                            store.importPending(into: section)
                            dismiss()
                        } label: {
                            Label(section.title, systemImage: section.symbol)
                        }
                    }
                }
            }
            .navigationTitle("Import workbook")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.dismissPending()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(HeartbeatStore())
}