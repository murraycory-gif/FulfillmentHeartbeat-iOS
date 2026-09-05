import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: HeartbeatStore

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            if store.isReady {
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
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            if HubLayout.isPhone(sizeClass) {
                VStack(spacing: 18) {
                    FulfillmentWordmark(height: 52)
                    BeatingHeartbeatMark(height: 72, showsTrace: true, showsWordmark: false)
                }
                .padding(.horizontal, 28)
            } else {
                BeatingHeartbeatMark(height: 92, showsTrace: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Fulfillment Heartbeat")
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