//
//  OnboardingState.swift
//  StepOne
//
//  The onboarding state machine, ported from the design's ob* methods.
//  Timings below are the design's own, in milliseconds from the start of
//  each sequence.
//

import SwiftUI

enum OnboardingStep: Equatable {
    case quote, welcome, name, greet, demo, reward, types, register, verify, login
}

@Observable
final class OnboardingState {
    var step: OnboardingStep = .quote
    /// Sub-step within `step`; each screen fades its pieces in by phase.
    var phase = 0
    var done = false

    // Demo card stack
    var remaining: [OnboardingCard] = []
    var position = 0
    var dragX: CGFloat = 0
    var dragY: CGFloat = 0
    var isDragging = false
    var flying: Int?
    /// Set while a sideways cycle is animating, so drags are ignored until the
    /// deck has settled on the next card.
    var sliding = false
    var entering = true
    /// The opening deal hides the neighbours for a clean reveal. Later
    /// entries must not, or they would blink out and back on every swipe.
    var firstDeal = true
    var earnedMeters = 0

    // Glass confirmation mask
    var maskVisible = false
    var checkVisible = false

    // Collected answers
    var name = ""
    var nameError = false
    var types: [String] = []
    var greetingDocked = false

    // Registration
    var email = ""
    var password = ""
    var passwordConfirm = ""
    var errEmail = ""
    var errPassword = ""
    var errPasswordConfirm = ""
    /// Failures that belong to no single field — no connection, project not
    /// set up, too many attempts.
    var errGeneral = ""
    /// Shown on the waiting screen when a manual check comes back unconfirmed.
    var verifyError = ""

    // Login
    var loginEmail = ""
    var loginPassword = ""
    /// Carries Firebase's message rather than a flag: a disabled account and a
    /// wrong password are different things to say.
    var loginError = ""
    var loginEmptyEmail = false
    var loginEmptyPassword = false
    var loginOrigin: OnboardingStep = .welcome

    private var sequence: Task<Void, Never>?
    /// Kept apart from `sequence` so a sideways cycle cannot cancel the
    /// step sequence that is driving the rest of onboarding.
    private var slideTask: Task<Void, Never>?
    private var entryTask: Task<Void, Never>?

    var cards: [OnboardingCard] {
        remaining.isEmpty && step != .demo ? StepOneContent.shared.onboardingCards : remaining
    }

    /// The last card has nothing to cycle to, so sideways swipes stop there.
    var canCycle: Bool { cards.count > 1 }

    /// Wraps an index onto the deck so the neighbours either side of the top
    /// card keep coming round, the way the home deck does.
    func wrapped(_ index: Int) -> Int {
        let count = cards.count
        guard count > 0 else { return 0 }
        return ((index % count) + count) % count
    }

    func cancel() {
        sequence?.cancel()
        sequence = nil
    }

    /// Runs `steps` as (delay-from-now-in-ms, action) pairs.
    private func run(_ steps: [(Int, () -> Void)]) {
        cancel()
        sequence = Task { [weak self] in
            var elapsed = 0
            for (at, action) in steps {
                let wait = at - elapsed
                if wait > 0 {
                    try? await Task.sleep(for: .milliseconds(wait))
                    elapsed = at
                }
                guard !Task.isCancelled, self != nil else { return }
                action()
            }
        }
    }

    /// Glass mask + drawn checkmark, then the next screen's fade sequence.
    private func checkThen(_ steps: [(Int, () -> Void)]) {
        var combined: [(Int, () -> Void)] = [
            (40, { [weak self] in self?.maskVisible = true; self?.checkVisible = false }),
            (900, { [weak self] in withAnimation(.easeInOut(duration: 0.44)) { self?.checkVisible = true } }),
            (1800, { [weak self] in withAnimation(.easeOut(duration: 0.42)) { self?.maskVisible = false } }),
            (2320, { [weak self] in self?.checkVisible = false }),
        ]
        for (at, action) in steps {
            combined.append((1800 + at, action))
        }
        combined.sort { $0.0 < $1.0 }
        run(combined)
    }

    // MARK: Intro

    func startIntro() {
        run([
            (220, { [weak self] in self?.setPhase(1) }),
            (5800, { [weak self] in self?.setPhase(2) }),
            (6800, { [weak self] in self?.set(.welcome, phase: 1) }),
            (7700, { [weak self] in self?.setPhase(2) }),
        ])
    }

    private func set(_ next: OnboardingStep, phase value: Int) {
        withAnimation(.easeInOut(duration: 0.9)) {
            step = next
            phase = value
        }
    }

    private func setPhase(_ value: Int) {
        withAnimation(.easeInOut(duration: 0.9)) { phase = value }
    }

    // MARK: Welcome → name

    func startFromWelcome() {
        cancel()
        withAnimation(.easeOut(duration: 0.45)) {
            step = .name
            phase = 1
        }
    }

    func confirmName() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            nameError = true
            return
        }
        checkThen([
            (0, { [weak self] in
                withAnimation(.easeOut(duration: 0.45)) {
                    self?.step = .greet
                    self?.phase = 0
                    self?.greetingDocked = false
                }
            }),
            (700, { [weak self] in withAnimation(.easeInOut(duration: 0.9)) { self?.phase = 1 } }),
            (4200, { [weak self] in self?.startDemo() }),
        ])
    }

    // MARK: Demo trips

    func startDemo() {
        remaining = StepOneContent.shared.onboardingCards
        position = 0
        dragX = 0
        dragY = 0
        flying = nil
        sliding = false
        entering = true
        firstDeal = true
        phase = 0
        // The greeting rides the same curve on its way out, so the tutorial
        // arrives on a clear screen.
        withAnimation(.timingCurve(0.32, 0.72, 0.28, 1, duration: 0.85)) {
            step = .demo
            greetingDocked = true
        }
        run([
            (80, { [weak self] in
                withAnimation(.timingCurve(0.32, 0.72, 0.28, 1, duration: 0.72)) {
                    self?.entering = false
                    self?.firstDeal = false
                }
                withAnimation(.easeInOut(duration: 0.9)) { self?.phase = 1 }
            }),
        ])
    }

    /// Sends the deck one card sideways, then re-seats it without animating so
    /// the new top card is already in place — the home deck's `slide`.
    func slideDemo(_ direction: Int, slot: CGFloat) {
        guard flying == nil, !sliding, !isDragging, canCycle else { return }
        sliding = true
        withAnimation(.timingCurve(0.32, 0.72, 0.28, 1, duration: 0.42)) {
            dragX = -CGFloat(direction) * slot
        }
        slideTask?.cancel()
        slideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(430))
            guard !Task.isCancelled, let self else { return }
            self.position = self.wrapped(self.position + direction)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { self.dragX = 0 }
            self.sliding = false
        }
    }

    func swipeDemo(up: Bool) {
        guard flying == nil, !sliding, let card = cards[safe: wrapped(position)] else { return }
        flying = up ? -1 : 1
        isDragging = false
        withAnimation(.easeOut(duration: 0.36)) { dragY = up ? -950 : 950 }

        let earned = up ? card.m : 0
        run([
            (360, { [weak self] in
                guard let self else { return }
                let at = self.wrapped(self.position)
                var ids = self.remaining
                if ids.indices.contains(at) { ids.remove(at: at) }
                self.remaining = ids
                // The card that followed has shifted into `at`, so it becomes
                // the new top card — or the deck wraps back to the start.
                self.position = ids.isEmpty ? 0 : ((at % ids.count) + ids.count) % ids.count
                self.dragX = 0
                self.dragY = 0
                self.flying = nil
                self.earnedMeters += earned
                if ids.isEmpty {
                    self.finishDemo()
                } else {
                    self.beginEntry()
                }
            }),
        ])
    }

    /// Parks the new top card below the stage and lets it rise. The pause
    /// matters: set both values in one turn of the run loop and SwiftUI
    /// coalesces them, leaving the card to appear without travelling.
    private func beginEntry() {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { entering = true }

        entryTask?.cancel()
        entryTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(30))
            guard !Task.isCancelled, let self else { return }
            withAnimation(.timingCurve(0.32, 0.72, 0.28, 1, duration: 0.5)) {
                self.entering = false
            }
        }
    }

    private func finishDemo() {
        checkThen([
            (0, { [weak self] in self?.step = .reward; self?.phase = 0 }),
            (160, { [weak self] in withAnimation(.easeInOut(duration: 0.9)) { self?.phase = 1 } }),
            (3900, { [weak self] in withAnimation(.easeInOut(duration: 0.9)) { self?.phase = 2 } }),
            (8400, { [weak self] in withAnimation(.easeInOut(duration: 0.9)) { self?.phase = 3 } }),
            (9400, { [weak self] in
                withAnimation(.easeInOut(duration: 0.8)) { self?.step = .types; self?.phase = 1 }
            }),
        ])
    }

    // MARK: Types

    func toggleType(_ id: String) {
        if let i = types.firstIndex(of: id) {
            types.remove(at: i)
        } else {
            guard types.count < 3 else { return }
            types.append(id)
        }
    }

    func confirmTypes() {
        guard !types.isEmpty else { return }
        checkThen([
            (0, { [weak self] in
                withAnimation(.easeOut(duration: 0.24)) { self?.step = .register; self?.phase = 1 }
            }),
        ])
    }

    // MARK: Navigation between auth screens

    func toLogin(from origin: OnboardingStep) {
        loginOrigin = origin
        loginError = ""
        withAnimation(.easeOut(duration: 0.24)) {
            step = .login
            phase = 1
        }
    }

    func loginBack() {
        loginError = ""
        loginEmptyEmail = false
        loginEmptyPassword = false
        withAnimation(.easeOut(duration: 0.24)) {
            if loginOrigin == .register {
                step = .register
                phase = 1
            } else {
                step = .welcome
                phase = 2
            }
        }
    }

    func verifyBack() {
        verifyError = ""
        withAnimation(.easeOut(duration: 0.24)) {
            step = .register
            phase = 1
        }
    }

    func toVerify() {
        verifyError = ""
        errGeneral = ""
        withAnimation(.easeOut(duration: 0.24)) {
            step = .verify
            phase = 1
        }
    }

    // MARK: Presentation helpers

    var quoteOpacity: Double { (step == .quote && phase == 1) ? 1 : 0 }
    var welcomeOpacity: Double { (step == .welcome && phase >= 1) ? 1 : 0 }
    var ctaOpacity: Double { (step == .welcome && phase >= 2) ? 1 : 0 }
    var hintOpacity: Double { (step == .demo && phase >= 1) ? 1 : 0 }
    var reward1Opacity: Double { (step == .reward && phase >= 1 && phase < 3) ? 1 : 0 }
    var reward2Opacity: Double { (step == .reward && phase >= 2 && phase < 3) ? 1 : 0 }
    /// The greeting belongs to its own step only; the demo step is the
    /// tutorial and keeps the screen to itself.
    var greetingOpacity: Double { (step == .greet && phase >= 1) ? 1 : 0 }

    /// Uses the shared localised greeting rather than an English one of
    /// its own — onboarding now runs in the device's language.
    func greetingLine(_ S: Strings, part: DayPart) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return S.greeting(part: part, name: trimmed.isEmpty ? S["friend"] : trimmed)
    }
}
