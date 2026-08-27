import SwiftUI

struct HeartbeatAssistSheet: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [HeartbeatAssist.Message] = []
    @State private var draft = ""
    @State private var thinking = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HubBanner(
                    icon: "waveform.path.ecg",
                    title: "Heartbeat Assist",
                    accessory: "\(router.current.title)  ·  \(store.filters.summary)",
                    clipped: false
                )
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            Text("Ask about at risk, watch, who is causing it, and what to fix. Answers use the live filter on this page.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                            chipRow
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
        .onAppear {
            if messages.isEmpty {
                ask("", userVisible: false)
            }
        }
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HeartbeatAssist.prompts(for: router.current), id: \.self) { prompt in
                    Button(prompt) {
                        draft = prompt
                        ask(prompt, userVisible: true)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.blueSoft, in: Capsule(style: .continuous))
                }
            }
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
                .frame(maxWidth: 720, alignment: .leading)
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
        HStack(spacing: 10) {
            TextField("Ask Heartbeat Assist…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1...4)
                .focused($fieldFocused)
                .onSubmit { ask(draft, userVisible: true) }
            Button {
                ask(draft, userVisible: true)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppTheme.textTertiary : AppTheme.blue)
            }
            .buttonStyle(.plain)
            .disabled(thinking || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    private func ask(_ raw: String, userVisible: Bool) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if userVisible {
            guard !text.isEmpty, !thinking else { return }
            messages.append(.init(role: .user, text: text))
            draft = ""
        }
        thinking = true
        let dest = router.current
        Task { @MainActor in
            let reply = HeartbeatAssist.answer(text, dest: dest, store: store)
            messages.append(.init(role: .assist, text: reply))
            thinking = false
        }
    }
}
