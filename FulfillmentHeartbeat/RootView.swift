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
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var quipIndex = 0

    private static let quips = [
        "Counting the bananas…",
        "Herding the avocados…",
        "Checking the ice cream aisle…",
        "Weighing the grapes…",
        "Finding the last rotisserie chicken…",
        "Scanning the frozen pizza…",
        "Bagging the kale — carefully…",
        "Chasing a runaway lime…",
        "Restocking the oat milk…",
        "Asking produce for a second opinion…",
        "Warming up the baguettes…",
        "Corralling the rotisserie tickets…",
        "Putting the pickles back in the jar…",
        "Slicing the deli line a little thinner…",
        "Making sure the blueberries stay in the box…"
    ]

    var body: some View {
        let phone = HubLayout.isPhone(sizeClass)
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            VStack(spacing: phone ? 18 : 24) {
                FulfillmentWordmark(height: phone ? 52 : 68)
                BeatingHeartbeatMark(
                    height: phone ? 92 : 118,
                    showsTrace: true,
                    showsWordmark: false,
                    forceTrace: true
                )
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(AppTheme.blue)
                    Text(Self.quips[quipIndex % Self.quips.count])
                        .font(.system(size: phone ? 16 : 18, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Fulfillment")
        .onAppear {
            quipIndex = Int.random(in: 0..<Self.quips.count)
        }
        .onReceive(Timer.publish(every: 2.2, on: .main, in: .common).autoconnect()) { _ in
            quipIndex += 1
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