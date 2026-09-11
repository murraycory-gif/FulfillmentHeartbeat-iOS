import SwiftUI

struct HeartbeatAssistSheet: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var messages: [HeartbeatAssist.Message] = []
    @State private var draft = ""
    @State private var thinking = false
    @FocusState private var fieldFocused: Bool

    private var prompts: [String] { HeartbeatAssist.prompts(for: router.current) }
    private var phone: Bool { HubLayout.isPhone(sizeClass) }
    private var hit: CGFloat { PulseLaunch.phoneMinimumHitTarget() }

    private var assistWindow: String? {
        if let section = router.current.section {
            return store.dataWindow(for: section)
        }
        return store.sharedDataWindow()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                contextBar
                transcript
                promptBank
                composer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font((phone ? Font.body : Font.title3).weight(.semibold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(minWidth: hit, minHeight: hit)
                        .contentShape(Rectangle())
                }
            }
            .navigationTitle("Heartbeat Assist")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var contextBar: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(router.current.title)
                .font((phone ? Font.subheadline : Font.headline).weight(.bold))
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
            Text(store.filters.summary)
                .font(phone ? .caption : .subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
            Spacer(minLength: 8)
            if let assistWindow, !assistWindow.isEmpty {
                Text(assistWindow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, phone ? 16 : 20)
        .padding(.vertical, phone ? 8 : 10)
        .frame(minHeight: hit, alignment: .center)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.cardBorder)
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(router.current.title). \(store.filters.summary)")
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if messages.isEmpty && !thinking {
                        Text(intro)
                            .font(phone ? .body : .title3)
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                    ForEach(messages) { message in
                        bubble(message)
                            .id(message.id)
                    }
                    if thinking {
                        ProgressView()
                            .tint(AppTheme.blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, phone ? 16 : 28)
                .padding(.vertical, 16)
            }
            .background(AppTheme.bg)
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var promptBank: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(router.current == .dashboard ? "Ask anything across the heartbeat" : "Ask about this page")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.textSecondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(prompts, id: \.self) { prompt in
                        Button {
                            ask(prompt)
                        } label: {
                            Text(prompt)
                                .font((phone ? Font.body : Font.title3).weight(.semibold))
                                .foregroundStyle(AppTheme.blue)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 14)
                                .padding(.vertical, phone ? 10 : 12)
                                .frame(maxWidth: .infinity, minHeight: hit, alignment: .leading)
                                .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(thinking)
                        .accessibilityLabel(prompt)
                    }
                }
            }
            .frame(maxHeight: phone ? 220 : 240)
        }
        .padding(.horizontal, phone ? 16 : 24)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.cardBorder)
                .frame(height: 1)
        }
    }

    private func bubble(_ message: HeartbeatAssist.Message) -> some View {
        let mine = message.role == .user
        return HStack {
            if mine { Spacer(minLength: phone ? 28 : 48) }
            Text(message.text)
                .font(phone ? .body : .title3)
                .foregroundStyle(mine ? Color.white : AppTheme.text)
                .textSelection(.enabled)
                .padding(phone ? 14 : 18)
                .frame(maxWidth: 980, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(mine ? AppTheme.blue : Color.white)
                )
                .overlay {
                    if !mine {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.blue.opacity(0.22), lineWidth: 1.5)
                    }
                }
            if !mine { Spacer(minLength: phone ? 28 : 48) }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask Heartbeat Assist…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(phone ? .body : .title3)
                .lineLimit(1...5)
                .focused($fieldFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: hit)
                .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onSubmit { ask(draft) }
            Button {
                ask(draft)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: phone ? 34 : 36, weight: .semibold))
                    .foregroundStyle(canSend ? AppTheme.blue : AppTheme.textTertiary)
                    .frame(width: hit, height: hit)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, phone ? 16 : 24)
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.cardBorder)
                .frame(height: 1)
        }
    }

    private var canSend: Bool {
        !thinking && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var intro: String {
        let book = store.filters.summary
        switch router.current {
        case .dashboard:
            return "You're on the dashboard for \(book). I'll name the at-risk KPIs, worst districts, and the stores to work first."
        case .sales:
            return "You're on Sales for \(book). I'll rank divisions and stores by Sales $, orders, AOV, and HD vs DUG."
        case .lostRevenue:
            return "You're on Loss Revenue for \(book). I'll break dollars by district, store, and bucket (OOS, refunds, cancels, kill switch)."
        case .missingItems:
            return "You're on Missing Items for \(book). Goal is 5% or less. I'll rank districts, stores, and hottest departments."
        case .preSubOOS:
            return "You're on Pre-Sub OOS for \(book). Goal is 5% or less. I'll rank districts, stores, and hottest departments."
        case .fiveStar:
            return "You're on 5 Star for \(book). I'll use live Presub, OTT, Flash, COE, and OTH 5% — worst Presub first."
        case .pickPath:
            return "You're on Pick Path for \(book). I'll flag off-path stores, shoppers, and stale aisle maps / sequences."
        case .prepNotReady:
            return "You're on Prep Not Ready for \(book). Grocery owns this. I'll rank PNR hours and tell grocery what to stage."
        case .dynacap:
            return "You're on Dynacap for \(book). I'll call out stores under 60 pieces/hour and whether labor is hiding in the number."
        case .scheduleQuality:
            return "You're on Schedule Quality for \(book). I'll separate a fat map from no-shows."
        case .pph:
            return "You're on PPH for \(book). Goal 80. I'll name stores below 74 and the shoppers dragging the rate."
        case .labor:
            return "You're on Labor for \(book). I'll show over-target stores and whether it's call-offs or the map."
        case .pickerScorecard:
            return "You're on Picker ScoreCard for \(book). I'll name the LDAPS to floor-coach today."
        }
    }

    private func ask(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !thinking else { return }
        messages.append(.init(role: .user, text: text))
        draft = ""
        thinking = true
        let dest = router.current
        Task { @MainActor in
            let reply = HeartbeatAssist.answer(text, dest: dest, store: store)
            messages.append(.init(role: .assist, text: reply))
            thinking = false
        }
    }
}
