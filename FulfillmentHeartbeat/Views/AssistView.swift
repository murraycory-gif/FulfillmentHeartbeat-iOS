import SwiftUI

struct HeartbeatAssistSheet: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [HeartbeatAssist.Message] = []
    @State private var draft = ""
    @State private var thinking = false
    @FocusState private var fieldFocused: Bool

    private var prompts: [String] { HeartbeatAssist.prompts(for: router.current) }

    private var assistWindow: String? {
        if let section = router.current.section {
            return store.dataWindow(for: section)
        }
        return store.sharedDataWindow()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HubBanner(
                    icon: "waveform.path.ecg",
                    title: "Heartbeat Assist",
                    accessory: "\(router.current.title)  ·  \(store.filters.summary)",
                    trailing: assistWindow,
                    clipped: false
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
                transcript
                promptBank
                composer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.blue)
                }
            }
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if messages.isEmpty && !thinking {
                        Text(intro)
                            .font(.title3)
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
                .padding(.horizontal, 28)
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
                .padding(.horizontal, 4)
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 320), spacing: 10)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(prompts, id: \.self) { prompt in
                        Button {
                            ask(prompt)
                        } label: {
                            Text(prompt)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppTheme.blue)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(thinking)
                    }
                }
            }
            .frame(maxHeight: 168)
        }
        .padding(.horizontal, 24)
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
            if mine { Spacer(minLength: 48) }
            Text(message.text)
                .font(.title3)
                .foregroundStyle(mine ? Color.white : AppTheme.text)
                .textSelection(.enabled)
                .padding(18)
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
            if !mine { Spacer(minLength: 48) }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask Heartbeat Assist…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.title3)
                .lineLimit(1...5)
                .focused($fieldFocused)
                .onSubmit { ask(draft) }
            Button {
                ask(draft)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(canSend ? AppTheme.blue : AppTheme.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
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
        case .upload:
            return "You're on Upload. I'll tell you which KPI files are missing and how to load the master."
        case .checklist:
            return "Assist is for the scorecards. Open a KPI page to ask about the live numbers."
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
