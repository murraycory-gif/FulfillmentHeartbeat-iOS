import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: HeartbeatStore

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            if store.isReady {
                if PulseLaunch.shouldMountRoleGate(needsRolePick: store.needsRolePick),
                   !PulseLaunch.shouldMountHubUnderRoleGate() {
                    RoleGateView()
                        .zIndex(20)
                        .transition(.opacity)
                } else {
                    MainHubView()
                        .transition(.opacity)
                        .overlay {
                            if PulseLaunch.shouldMountRoleGate(needsRolePick: store.needsRolePick),
                               PulseLaunch.shouldMountHubUnderRoleGate() {
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
        .onAppear {
            store.dismissBlockedRoleGate()
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
        .overlay(alignment: .top) {
            if store.isReady, !store.needsRolePick, let text = store.newDataBanner {
                NewDataUploadBanner(text: text)
                    .padding(.top, 8)
                    .padding(.horizontal, 12)
                    .zIndex(40)
            }
        }
        .sheet(isPresented: $store.offerPushPrePrompt) {
            PushPrePromptSheet()
                .environmentObject(store)
                .presentationDetents([.medium])
        }
    }
}

private struct NewDataUploadBanner: View {
    @EnvironmentObject private var store: HeartbeatStore
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityIdentifier("new-data-banner")
            .onAppear { store.armNewDataBannerDismiss() }
            .onChange(of: text) { _, _ in store.armNewDataBannerDismiss() }
    }
}

private struct PushPrePromptSheet: View {
    @EnvironmentObject private var store: HeartbeatStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Lock-screen alerts")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.text)
            Text("Heartbeat can send one alert when a new pack is uploaded. The time matches the Updated line on each page. This question is asked once.")
                .font(.body)
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                store.acceptPushPrePrompt()
            } label: {
                Text("Allow alerts")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.blue)
            Button {
                store.declinePushPrePrompt()
            } label: {
                Text("Not now")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.bg)
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
                    } else if PulseLaunch.shouldShowGroceryLoadQuips() {
                        LaunchLoadingQuip(progress: store.importProgress)
                    } else {
                        Text(PulseLaunch.seatLoadTitle)
                            .font(.system(size: phone ? 16 : 18, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(LaunchSplashAccessibility(isLoading: !launchFailed))
    }

    private var launchFailed: Bool {
        store.errorMessage != nil && !store.isImporting
    }
}

/// VoiceOver hears "Loading Heartbeat" once. Quips stay out of the accessibility tree.
private struct LaunchSplashAccessibility: ViewModifier {
    var isLoading: Bool

    func body(content: Content) -> some View {
        if isLoading {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(PulseLaunch.seatLoadTitle)
        } else {
            content.accessibilityLabel("Fulfillment")
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