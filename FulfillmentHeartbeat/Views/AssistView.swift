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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HubBanner(
                    icon: "waveform.path.ecg",
                    title: "Heartbeat Assist",
                    accessory: "\(router.current.title)  ·  \(store.filters.summary)",
                    clipped: false
                )
                transcript
                promptBank
                composer
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold))
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
                        Text("Ask about districts, stores, shoppers, and what is driving the number on this page. Answers use the live filter.")
                            .font(.body)
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
                .padding(20)
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
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 4)
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 240), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(prompts, id: \.self) { prompt in
                        Button {
                            ask(prompt)
                        } label: {
                            Text(prompt)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.blue)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(thinking)
                    }
                }
            }
            .frame(maxHeight: router.current == .dashboard || router.current == .checklist ? 168 : 112)
        }
        .padding(.horizontal, 16)
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
                .font(.body)
                .foregroundStyle(mine ? Color.white : AppTheme.text)
                .textSelection(.enabled)
                .padding(14)
                .frame(maxWidth: 760, alignment: .leading)
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
                .font(.body)
                .lineLimit(1...4)
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
        .padding(.horizontal, 16)
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
