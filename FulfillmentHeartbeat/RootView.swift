import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: HeartbeatStore

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            if store.isReady {
                if store.needsRolePick, !PulseLaunch.shouldMountHubUnderRoleGate() {
                    RoleGateView()
                        .zIndex(20)
                        .transition(.opacity)
                } else {
                    MainHubView()
                        .transition(.opacity)
                        .overlay {
                            if store.needsRolePick, PulseLaunch.shouldMountHubUnderRoleGate() {
                                RoleGateView()
                                    .zIndex(20)
                                    .transition(.opacity)
                            }
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
        .animation(nil, value: store.needsRolePick)
        .overlay(alignment: .top) {
            if PulseLaunch.shouldShowHubFillBanner(
                needsRolePick: store.needsRolePick,
                warehouseHydrating: store.warehouseHydrating
            ) {
                WarehouseFillBanner()
                    .padding(.top, 6)
                    .zIndex(30)
            }
        }
    }
}

struct LaunchSplashView: View {
    @EnvironmentObject private var store: HeartbeatStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var quipIndex = 0

    private static let quips = PulseLaunch.aisleQuips

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
                    if let error = store.errorMessage, !store.isImporting {
                        Text(error)
                            .font(.system(size: phone ? 16 : 18, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                        Button("Try again") {
                            store.retryLaunch()
                        }
                        .font(.system(size: phone ? 16 : 17, weight: .semibold))
                        .foregroundStyle(AppTheme.blue)
                        .padding(.top, 4)
                    } else {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(AppTheme.blue)
                        Text(PulseLaunch.displayLoadStatus(store.importProgress.label, tick: quipIndex))
                            .font(.system(size: phone ? 16 : 18, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                        if store.importProgress.expected > 0 {
                            ProgressView(
                                value: store.importProgress.fraction,
                                total: 1
                            )
                            .tint(AppTheme.blue)
                            .frame(maxWidth: phone ? 220 : 280)
                            Text("\(store.importProgress.loaded) of \(store.importProgress.expected)")
                                .font(.system(size: phone ? 13 : 14, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
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

private struct WarehouseFillBanner: View {
    @EnvironmentObject private var store: HeartbeatStore

    var body: some View {
        VStack(spacing: 6) {
            Text(store.aisleFillCaption)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            ProgressView(value: store.importProgress.fraction, total: 1)
                .tint(AppTheme.blue)
                .frame(maxWidth: 280)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.card.opacity(0.96), in: Capsule())
        .allowsHitTesting(false)
    }
}

#Preview {
    RootView()
        .environmentObject(HeartbeatStore())
}