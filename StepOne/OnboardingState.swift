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
    var position = 1
    var dragY: CGFloat = 0
    var isDragging = false
    var flying: Int?
    var entering = true
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
    var code = ""
    var codeError = ""

    // Login
    var loginEmail = ""
    var loginPassword = ""
    var loginError = false
    var loginEmptyEmail = false
    var loginEmptyPassword = false
    var loginOrigin: OnboardingStep = .welcome

    private var sequence: Task<Void, Never>?

    var cards: [OnboardingCard] {
        remaining.isEmpty && step != .demo ? StepOneContent.shared.onboardingCards : remaining
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
        position = 1
        dragY = 0
        flying = nil
        entering = true
        step = .demo
        phase = 0
        withAnimation(.timingCurve(0.32, 0.72, 0.28, 1, duration: 0.85)) {
            greetingDocked = true
        }
        run([
            (80, { [weak self] in
                withAnimation(.timingCurve(0.32, 0.72, 0.28, 1, duration: 0.72)) { self?.entering = false }
                withAnimation(.easeInOut(duration: 0.9)) { self?.phase = 1 }
            }),
        ])
    }

    func swipeDemo(up: Bool) {
        guard flying == nil, let card = cards[safe: position] else { return }
        flying = up ? -1 : 1
        isDragging = false
        withAnimation(.easeOut(duration: 0.36)) { dragY = up ? -950 : 950 }

        let earned = up ? card.m : 0
        run([
            (360, { [weak self] in
                guard let self else { return }
                var ids = self.remaining
                if ids.indices.contains(self.position) { ids.remove(at: self.position) }
                self.remaining = ids
                self.position = min(self.position, max(0, ids.count - 1))
                self.dragY = 0
                self.flying = nil
                self.earnedMeters += earned
                if ids.isEmpty { self.finishDemo() }
            }),
        ])
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
        loginError = false
        withAnimation(.easeOut(duration: 0.24)) {
            step = .login
            phase = 1
        }
    }

    func loginBack() {
        loginError = false
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
        codeError = ""
        withAnimation(.easeOut(duration: 0.24)) {
            step = .register
            phase = 1
        }
    }

    func toVerify() {
        code = ""
        codeError = ""
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
    var greetingOpacity: Double { ((step == .greet && phase >= 1) || step == .demo) ? 1 : 0 }

    func greetingLine(part: DayPart) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return "Good \(part.englishWord), \(trimmed.isEmpty ? "friend" : trimmed)"
    }
}
