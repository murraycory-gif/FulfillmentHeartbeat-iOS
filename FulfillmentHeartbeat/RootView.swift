import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @State private var minTimeElapsed = false

    private var showSplash: Bool {
        !minTimeElapsed || !store.isReady
    }

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            if showSplash {
                LaunchSplashView(isLoading: !store.isReady)
                    .zIndex(2)
            } else {
                MainHubView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(.light)
        .tint(AppTheme.blue)
        .background(AppTheme.bg.ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                minTimeElapsed = true
            }
        }
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
        .animation(.easeInOut(duration: 0.28), value: showSplash)
    }
}

struct LaunchSplashView: View {
    var isLoading: Bool

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            VStack(spacing: 22) {
                BeatingHeartbeatMark(height: 88, showsTrace: true)

                VStack(spacing: 4) {
                    Text("Fulfillment")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                    Text("Heartbeat")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(AppTheme.blue)
                }

                if isLoading {
                    ProgressView()
                        .tint(AppTheme.blue)
                        .padding(.top, 6)
                    Text("Loading market pulse…")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
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