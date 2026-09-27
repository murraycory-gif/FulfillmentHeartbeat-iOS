import Foundation
import SwiftUI

/// Launch-screen lines. Edit this array; every platform reads it.
enum LoadingQuips {
    /// While a load step is still running, move to the next line.
    static let rotationIntervalNanoseconds: UInt64 = 1_800_000_000
    /// Crossfade. Reduce Motion skips this and swaps immediately.
    static let crossfadeSeconds: Double = 0.3

    static let lines: [String] = [
        "Counting every banana in the building…",
        "Waking up the pickers. Someone bring coffee.",
        "Teaching the scanners to say please…",
        "Chasing a runaway shopping cart…",
        "Negotiating with the freezer aisle…",
        "Checking if PPH stands for Pizza Per Hour…",
        "Asking the radios nicely to stay charged…",
        "Finding the one store that forgot to clock in…",
        "Bribing the data with donuts…",
        "Stacking spreadsheets very carefully…",
        "Convincing substitutes they're just as good…",
        "Untangling the pick path. It had knots.",
        "Reminding the numbers to behave…",
        "Polishing the charts until they sparkle…",
        "Looking for the last item in aisle 12…",
        "Doing the math. Twice. Just in case.",
        "Herding orders into neat little lines…",
        "Loading the good news first…",
        "Almost there. The bags are packed.",
        "Putting the heart in Heartbeat…",
    ]

    /// Fisher–Yates permutation. Every line once, none repeated.
    static func shuffled<G: RandomNumberGenerator>(
        _ lines: [String] = lines,
        using generator: inout G
    ) -> [String] {
        var copy = lines
        guard copy.count > 1 else { return copy }
        for index in stride(from: copy.count - 1, through: 1, by: -1) {
            let swapIndex = Int.random(in: 0...index, using: &generator)
            if swapIndex != index {
                copy.swapAt(index, swapIndex)
            }
        }
        return copy
    }
}

/// One launch walks a shuffled deck. A line can show again only after every line has been used.
struct LoadingQuipDeck {
    private var order: [String]
    private var index = 0
    private let source: [String]

    init<G: RandomNumberGenerator>(lines: [String] = LoadingQuips.lines, using generator: inout G) {
        source = lines
        order = LoadingQuips.shuffled(lines, using: &generator)
    }

    init(lines: [String] = LoadingQuips.lines) {
        var generator = SystemRandomNumberGenerator()
        self.init(lines: lines, using: &generator)
    }

    mutating func next<G: RandomNumberGenerator>(using generator: inout G) -> String {
        if index >= order.count {
            order = LoadingQuips.shuffled(source, using: &generator)
            index = 0
        }
        guard index < order.count else { return "" }
        let line = order[index]
        index += 1
        return line
    }

    mutating func next() -> String {
        var generator = SystemRandomNumberGenerator()
        return next(using: &generator)
    }
}

/// The only launch-status view. iPhone, iPad, and Mac (Catalyst or native) share it.
struct LaunchLoadingQuip: View {
    @ObservedObject var progress: ImportProgress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var deck: LoadingQuipDeck
    @State private var line: String

    init(progress: ImportProgress) {
        _progress = ObservedObject(wrappedValue: progress)
        var deck = LoadingQuipDeck()
        let opening = deck.next()
        _deck = State(initialValue: deck)
        _line = State(initialValue: opening)
    }

    var body: some View {
        ZStack {
            Text(line)
                .font(.system(.body, design: .default).weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
                .id(line)
                .transition(reduceMotion ? .identity : .opacity)
        }
        .accessibilityHidden(true)
        .onChange(of: progress.loaded) { _, _ in
            advance()
        }
        .task(id: progress.loaded) {
            await rotateWhileStepRuns()
        }
    }

    private func advance() {
        var copy = deck
        let next = copy.next()
        deck = copy
        if reduceMotion {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { line = next }
        } else {
            withAnimation(.easeInOut(duration: LoadingQuips.crossfadeSeconds)) {
                line = next
            }
        }
    }

    private func rotateWhileStepRuns() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: LoadingQuips.rotationIntervalNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            advance()
        }
    }
}
