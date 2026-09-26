import SwiftUI

/// One Assist layout for iPhone, iPad, and Mac. Width is the only difference.
struct HeartbeatAssistSheet: View {
    @EnvironmentObject private var store: HeartbeatStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var turns: [AssistTurn] = []
    @State private var draft = ""
    @State private var chips: [String] = []
    @State private var expandedMore: Set<UUID> = []
    @State private var expandedRanked: Set<UUID> = []
    @FocusState private var fieldFocused: Bool

    private var stackFacts: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scopeBar
                transcript
                chipColumn
                composer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.blue)
                }
            }
            .navigationTitle("Heartbeat Assist")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { reloadChips() }
        .onChange(of: store.filters) { _, _ in
            reloadChips()
        }
    }

    private var scopeBar: some View {
        AssistColumn {
            VStack(alignment: .leading, spacing: 2) {
                Text(AssistScope.label(store.filters, roster: store.stores))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let window = currentWindow, !window.isEmpty {
                    Text(window)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
        }
        .background(AppTheme.card)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.cardBorder).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var currentWindow: String? {
        if let section = router.current.section {
            return store.dataWindow(for: section)
        }
        return store.sharedDataWindow()
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                AssistColumn {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(turns) { turn in
                            userBubble(turn.question)
                            answerStack(turn, proxy: proxy)
                                .id(turn.id)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .background(AppTheme.bg)
            .onChange(of: turns.count) { _, _ in
                if let last = turns.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var chipColumn: some View {
        AssistColumn {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Button {
                        ask(chip)
                    } label: {
                        Text(chip)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.blue)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(chip)
                }
            }
            .padding(.vertical, chips.isEmpty ? 0 : 10)
        }
        .background(AppTheme.card)
    }

    private var composer: some View {
        AssistColumn {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask Heartbeat Assist…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .lineLimit(1...5)
                    .focused($fieldFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onSubmit { ask(draft) }
                Button {
                    ask(draft)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(canSend ? AppTheme.blue : AppTheme.textTertiary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
            .padding(.vertical, 12)
        }
        .background(AppTheme.card)
        .overlay(alignment: .top) {
            Rectangle().fill(AppTheme.cardBorder).frame(height: 1)
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 48)
            Text(text)
                .font(.body)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .accessibilityLabel("You asked: \(text)")
    }

    private func answerStack(_ turn: AssistTurn, proxy: ScrollViewProxy) -> some View {
        let answer = turn.answer
        let showAll = expandedMore.contains(turn.id) || answer.issues.count <= 3
        let visible = showAll ? answer.issues : Array(answer.issues.prefix(3))
        return VStack(alignment: .leading, spacing: 12) {
            if let banner = answer.staleBanner {
                Text(banner)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.warnSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            if let title = answer.noticeTitle {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let body = answer.noticeBody {
                Text(body)
                    .font(.body)
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let action = answer.noticeAction {
                actionButton(action)
            }
            if let header = answer.headerTitle {
                headerBlock(header, lines: answer.headerLines, proxy: proxy)
            }
            ForEach(visible) { issue in
                problemCard(issue)
                    .id(issue.id)
                if !issue.checks.isEmpty {
                    resolutionCard(issue)
                }
            }
            if answer.issues.count > 3 {
                disclosureButton(
                    title: expandedMore.contains(turn.id)
                        ? "Hide extra issues"
                        : "More issues (\(answer.issues.count - 3))",
                    systemImage: expandedMore.contains(turn.id) ? "chevron.up" : "chevron.down"
                ) {
                    if expandedMore.contains(turn.id) {
                        expandedMore.remove(turn.id)
                    } else {
                        expandedMore.insert(turn.id)
                    }
                }
            }
            if !answer.healthyFacts.isEmpty {
                factRow(answer.healthyFacts)
            }
            if !answer.rankedLines.isEmpty {
                disclosureButton(
                    title: "How this was ranked",
                    systemImage: expandedRanked.contains(turn.id) ? "chevron.up" : "chevron.down"
                ) {
                    if expandedRanked.contains(turn.id) {
                        expandedRanked.remove(turn.id)
                    } else {
                        expandedRanked.insert(turn.id)
                    }
                }
                if expandedRanked.contains(turn.id) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(answer.rankedLines, id: \.self) { line in
                            Text(line)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if let empty = answer.emptyNote {
                Text(empty)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func headerBlock(_ title: String, lines: [AssistHeaderLine], proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.text)
            ForEach(lines) { line in
                Button {
                    withAnimation { proxy.scrollTo(line.issueID, anchor: .top) }
                } label: {
                    Text(line.text)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.blue)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(line.text)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        }
    }

    private func problemCard(_ issue: AssistIssue) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                perform(issue.footerAction)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("#\(issue.rank)  \(issue.title)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        statusPill(issue)
                    }
                    Text(issue.headline)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(issue.numberLabel)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(issue.numberValue)
                            .font(.title.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    factRow(issue.facts)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(issue.accessibilityLabel)
            .accessibilityAddTraits(.isButton)
            Text(issue.scope)
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                perform(issue.footerAction)
            } label: {
                Text(issue.footer)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(issue.footerAction.accessibilityLabel)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        }
    }

    private func resolutionCard(_ issue: AssistIssue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Resolution")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            ForEach(Array(issue.checks.enumerated()), id: \.element.id) { index, check in
                actionButton(check, number: index + 1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.blue.opacity(0.18), lineWidth: 1)
        }
    }

    private func actionButton(_ action: AssistAction, number: Int? = nil) -> some View {
        Button {
            perform(action)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(number.map { "\($0). \(action.question)" } ?? action.question)
                    .font(.body)
                    .foregroundStyle(AppTheme.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !action.owner.isEmpty {
                    Text("Owner: \(action.owner)")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(action.buttonTitle)
                    .font(.body)
                    .foregroundStyle(AppTheme.blue)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.accessibilityLabel)
    }

    private func disclosureButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(AppTheme.blue)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func statusPill(_ issue: AssistIssue) -> some View {
        HStack(spacing: 4) {
            Image(systemName: issue.statusSymbol)
            Text(issue.statusText)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(AppTheme.healthInk(issue.statusHealth))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.healthWash(issue.statusHealth), in: Capsule())
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func factRow(_ facts: [AssistFact]) -> some View {
        if facts.isEmpty {
            EmptyView()
        } else if stackFacts {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(facts) { fact in
                    factCell(fact)
                }
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
                ForEach(facts) { fact in
                    factCell(fact)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func factCell(_ fact: AssistFact) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(fact.label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(fact.value)
                .font(.body)
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func ask(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let snapshot = AssistSnapshot.live(store, section: router.current.section)
        let answer = AssistComposer.answer(question: text, snapshot: snapshot)
        turns.append(AssistTurn(question: text, answer: answer))
        chips = answer.chips
        draft = ""
    }

    private func reloadChips() {
        let snapshot = AssistSnapshot.live(store, section: router.current.section)
        chips = AssistComposer.chips(for: snapshot)
    }

    private func perform(_ action: AssistAction) {
        dismiss()
        if action.clearsFilters {
            store.clearFilters()
        } else if let filters = action.filters {
            store.commitFilters(filters)
        }
        router.open(action.destination)
    }
}

private struct AssistTurn: Identifiable {
    let id = UUID()
    var question: String
    var answer: AssistAnswer
}

private struct AssistColumn<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 16)
            .frame(maxWidth: 712)
            .frame(maxWidth: .infinity)
    }
}
