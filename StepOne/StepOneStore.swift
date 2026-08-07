//
//  StepOneStore.swift
//  StepOne
//
//  App state and behaviour, ported from the design's Component class.
//

import SwiftUI

// MARK: - Navigation

enum Screen: Equatable {
    case home, settings, account, preferences, language, notifications, help
    case tripTypes, discarded, journey
    case changeName, changeEmail, password
}

enum VerifyStage: Equatable { case intro, code, newValue }
enum RegisterStage: Equatable { case form, code, login }

struct DiscardRef: Equatable, Hashable {
    let category: String
    let index: Int
}

struct SessionStash {
    var name: String
    var email: String
    var password: String
    var meters: Int
    var discarded: [DiscardRef]
    var done: Int
    var journeyBase: Int
}

/// Which long-running action is spinning. Mirrors the design's `obBusy`.
enum BusyAction: String, Equatable {
    case register, verify, login, resend
    case rgRegister, rgVerify, rgLogin
    case logout, delete
}

// MARK: - Store

@Observable
final class StepOneStore {
    let content = StepOneContent.shared

    // Content selection
    var lang = "en"
    var category = "physical"
    var chosen = ["creativity", "physical", "housework"]
    var index = 0

    // Card interaction
    var drag: CGSize = .zero
    var isDragging = false
    var isAnimating = false
    var isFading = false
    var suppressAnimation = false

    // Progress
    var meters = 0
    var done = 0
    var journeyBaseOverride: Int?
    var discarded: [DiscardRef] = []
    var reward: String?
    var toast: String?
    var hintSeen = false

    // Appearance & preferences
    var nightOverride: Bool?
    var unit: DistanceUnit = .meters
    var stepNotif = true
    var promoNotif = false

    // Account
    var name: String?
    var email: String?
    var registered: Bool?
    var accountPassword = ""
    var sessionStash: SessionStash?

    // Navigation & chrome
    var screen: Screen = .home
    var menuOpen = false
    var alertOpen = false
    var dangerOpen = false
    var busy: BusyAction?

    // Journey disclosure
    var openMilestones: Set<String> = []
    var openPhases: [Int: Bool] = [:]

    // Trip-type reordering
    var dragCategory: String?
    var dragOffset: CGFloat = 0

    // Change name / email / password
    var nameDraft: String?
    var nameDiscardOpen = false
    var emailStage: VerifyStage = .intro
    var emailCode = ""
    var emailNew = ""
    var pwStage: VerifyStage = .intro
    var pwCode = ""
    var pwNew = ""
    var pwConfirm = ""
    var pwError = false
    var resendSeconds = 0

    // In-app registration (shown on Account when signed out)
    var rgStage: RegisterStage = .form
    var rgEmail = ""
    var rgPw = ""
    var rgPw2 = ""
    var rgCode = ""
    var rgErrEmail = ""
    var rgErrPw = ""
    var rgErrPw2 = ""
    var rgErrCode = ""
    var rgLoginEmail = ""
    var rgLoginPw = ""
    var rgLoginError = false
    var rgLoginEmptyEmail = false
    var rgLoginEmptyPw = false

    var onboarding = OnboardingState()

    private var slideTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var rewardTask: Task<Void, Never>?
    private var resendTask: Task<Void, Never>?
    private var busyTask: Task<Void, Never>?

    let slot: CGFloat = 340

    // MARK: Derived

    var isNight: Bool { nightOverride ?? false }
    var theme: StepOneTheme { .of(night: isNight) }
    var S: Strings { Strings(lang: lang, content: content) }
    var isRegistered: Bool { registered ?? true }

    var displayName: String { name ?? "Alex" }
    var displayEmail: String { email ?? "alex@example.com" }

    var trips: [TripSpec] { content.trips(lang: lang, category: category) }

    func trips(for category: String) -> [TripSpec] {
        content.trips(lang: lang, category: category)
    }

    func wrapped(_ i: Int) -> Int {
        let n = trips.count
        guard n > 0 else { return 0 }
        return ((i % n) + n) % n
    }

    var journeyTotalMeters: Int { (journeyBaseOverride ?? content.journeyBase) + meters }

    var greetingLine: String {
        S.greeting(part: DayPart.current(), name: displayName)
    }

    // MARK: Card gestures

    var cardAnimation: Animation { .timingCurve(0.32, 0.72, 0.28, 1, duration: 0.46) }

    func slide(_ direction: Int) {
        guard !isAnimating, !isDragging else { return }
        isAnimating = true
        hintSeen = true
        withAnimation(cardAnimation) {
            drag = CGSize(width: -CGFloat(direction) * slot, height: 0)
        }
        slideTask?.cancel()
        slideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(470))
            guard !Task.isCancelled, let self else { return }
            self.index = self.wrapped(self.index + direction)
            self.snapBack()
            self.isAnimating = false
        }
    }

    func completeTrip() {
        guard !isAnimating, !isDragging else { return }
        let trip = trips[safe: wrapped(index)]
        let gain = trip?.meters ?? 0
        isAnimating = true
        isFading = true
        hintSeen = true
        reward = "+" + unit.format(gain)

        withAnimation(cardAnimation) { drag = CGSize(width: 0, height: -950) }

        rewardTask?.cancel()
        rewardTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1150))
            guard !Task.isCancelled else { return }
            self?.reward = nil
        }

        slideTask?.cancel()
        slideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(440))
            guard !Task.isCancelled, let self else { return }
            self.meters += gain
            self.done += 1
            self.index = self.wrapped(self.index + 1)
            self.snapBack()
            self.isFading = false
            self.isAnimating = false
            self.showToast(self.S("traveled", "d", self.unit.format(self.meters)))
        }
    }

    func discardTrip() {
        guard !isAnimating, !isDragging else { return }
        isAnimating = true
        isFading = true
        hintSeen = true

        withAnimation(cardAnimation) { drag = CGSize(width: 0, height: 950) }

        slideTask?.cancel()
        slideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(440))
            guard !Task.isCancelled, let self else { return }
            let ref = DiscardRef(category: self.category, index: self.wrapped(self.index))
            if !self.discarded.contains(ref) { self.discarded.append(ref) }
            self.index = self.wrapped(self.index + 1)
            self.snapBack()
            self.isFading = false
            self.isAnimating = false
            self.showToast(self.S["discardedToast"])
        }
    }

    /// Resets the card offset without animating, the way the design's
    /// `instant` flag suppresses the transition for one frame.
    private func snapBack() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { drag = .zero }
    }

    func showToast(_ message: String, seconds: Double = 2.4) {
        toastTask?.cancel()
        withAnimation(.easeOut(duration: 0.3)) { toast = message }
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { self?.toast = nil }
        }
    }

    func setCategory(_ id: String) {
        guard id != category else { return }
        category = id
        index = 0
        drag = .zero
        isAnimating = false
        isFading = false
    }

    // MARK: Trip types

    func toggleType(_ id: String) {
        var next = chosen
        if let i = next.firstIndex(of: id) {
            next.remove(at: i)
        } else {
            guard next.count < 3 else { return }
            next.append(id)
        }
        chosen = next
        if !next.contains(category) { category = next.first ?? category }
        index = 0
        drag = .zero
    }

    func moveChosen(from source: IndexSet, to destination: Int) {
        chosen.move(fromOffsets: source, toOffset: destination)
    }

    func restoreDiscarded(at offset: Int) {
        guard discarded.indices.contains(offset) else { return }
        discarded.remove(at: offset)
        showToast(S["restoredToast"], seconds: 2)
    }

    // MARK: Journey disclosure

    func toggleMilestone(_ key: String) {
        if openMilestones.contains(key) { openMilestones.remove(key) } else { openMilestones.insert(key) }
    }

    func isPhaseOpen(_ phaseIndex: Int, defaultOpen: Bool) -> Bool {
        openPhases[phaseIndex] ?? defaultOpen
    }

    func togglePhase(_ phaseIndex: Int, current: Bool) {
        openPhases[phaseIndex] = !current
    }

    // MARK: Resend countdown

    func startResend() {
        resendTask?.cancel()
        resendSeconds = 60
        resendTask = Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                if self.resendSeconds <= 1 { self.resendSeconds = 0; return }
                self.resendSeconds -= 1
            }
        }
    }

    var resendLabel: String {
        resendSeconds > 0 ? S("resendIn", "s", "\(resendSeconds)") : S["resend"]
    }

    // MARK: Change name

    func nameBack() {
        let current = displayName
        if (nameDraft ?? current) != current {
            nameDiscardOpen = true
        } else {
            screen = .account
        }
    }

    func confirmName() {
        let draft = (nameDraft ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !draft.isEmpty { name = draft }
        screen = .account
        nameDiscardOpen = false
    }

    // MARK: Change password

    func confirmPassword() {
        if !pwNew.isEmpty && pwNew == pwConfirm {
            screen = .account
            pwStage = .intro
            accountPassword = pwNew
        } else {
            pwError = true
        }
    }

    // MARK: Busy helper

    /// Runs `work` after a short delay while showing a spinner, mirroring the
    /// design's simulated network calls.
    func runBusy(_ action: BusyAction, milliseconds: Int = 950, _ work: @escaping () -> Void) {
        guard busy == nil else { return }
        busy = action
        busyTask?.cancel()
        busyTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(milliseconds))
            guard !Task.isCancelled, let self else { return }
            self.busy = nil
            work()
        }
    }

    // MARK: Validation (shared by onboarding and in-app registration)

    static func isValidEmail(_ value: String) -> Bool {
        value.range(of: #"^[^\s@]+@[^\s@]+\.[a-z]{2,}$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func isValidPassword(_ value: String) -> Bool {
        value.count >= 8
            && value.rangeOfCharacter(from: .decimalDigits) != nil
            && value.rangeOfCharacter(from: .letters) != nil
    }

    // MARK: In-app registration

    func rgRegister() {
        guard busy == nil else { return }
        let em = rgEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailOk = Self.isValidEmail(em)
        let pwOk = Self.isValidPassword(rgPw)
        let matchOk = !rgPw2.isEmpty && rgPw2 == rgPw

        rgErrEmail = emailOk ? "" : "Enter a valid email address"
        rgErrPw = pwOk ? "" : "Use 8 or more characters with a number and a letter"
        rgErrPw2 = matchOk ? "" : "Passwords do not match"

        guard emailOk, pwOk, matchOk else { return }
        runBusy(.rgRegister, milliseconds: 1100) { [weak self] in
            guard let self else { return }
            self.rgStage = .code
            self.rgCode = ""
            self.rgErrCode = ""
            self.startResend()
        }
    }

    func rgVerify() {
        guard busy == nil else { return }
        runBusy(.rgVerify) { [weak self] in
            guard let self else { return }
            if self.rgCode.trimmingCharacters(in: .whitespaces) == "123456" {
                self.resendTask?.cancel()
                self.registered = true
                self.email = self.rgEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                self.accountPassword = self.rgPw
                self.journeyBaseOverride = self.content.journeyBase
                self.rgStage = .form
                self.rgPw = ""
                self.rgPw2 = ""
                self.rgCode = ""
                self.resendSeconds = 0
            } else {
                self.rgErrCode = "That code is not correct"
            }
        }
    }

    func rgLogin() {
        guard busy == nil else { return }
        let em = rgLoginEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !em.isEmpty, !rgLoginPw.isEmpty else {
            rgLoginEmptyEmail = em.isEmpty
            rgLoginEmptyPw = rgLoginPw.isEmpty
            rgLoginError = false
            return
        }
        rgLoginEmptyEmail = false
        rgLoginEmptyPw = false

        runBusy(.rgLogin, milliseconds: 1100) { [weak self] in
            guard let self else { return }
            let entered = em.lowercased()
            if let stash = self.sessionStash,
               entered == stash.email.lowercased(), self.rgLoginPw == stash.password {
                self.registered = true
                self.name = stash.name
                self.email = stash.email
                self.accountPassword = stash.password
                self.meters = stash.meters
                self.discarded = stash.discarded
                self.done = stash.done
                self.journeyBaseOverride = stash.journeyBase
                self.sessionStash = nil
                self.rgStage = .form
                self.rgLoginPw = ""
            } else if entered == "alex@example.com", self.rgLoginPw == "stepone123" {
                self.registered = true
                self.name = "Alex"
                self.email = "alex@example.com"
                self.accountPassword = "stepone123"
                self.journeyBaseOverride = self.content.journeyBase
                self.sessionStash = nil
                self.rgStage = .form
                self.rgLoginPw = ""
            } else {
                self.rgLoginError = true
            }
        }
    }

    // MARK: Account actions

    func logOut() {
        guard busy == nil else { return }
        runBusy(.logout) { [weak self] in
            guard let self else { return }
            self.resendTask?.cancel()
            self.sessionStash = SessionStash(
                name: self.displayName,
                email: self.displayEmail,
                password: self.accountPassword.isEmpty ? "stepone123" : self.accountPassword,
                meters: self.meters,
                discarded: self.discarded,
                done: self.done,
                journeyBase: self.journeyBaseOverride ?? self.content.journeyBase
            )
            self.registered = false
            self.name = "friend"
            self.email = nil
            self.accountPassword = ""
            self.meters = 0
            self.discarded = []
            self.done = 0
            self.journeyBaseOverride = 0
            self.openMilestones = []
            self.openPhases = [:]
            self.resendSeconds = 0
            self.rgStage = .login
            self.rgLoginEmail = ""
            self.rgLoginPw = ""
            self.rgLoginError = false
            self.rgLoginEmptyEmail = false
            self.rgLoginEmptyPw = false
        }
    }

    func deleteAccount() {
        guard busy == nil else { return }
        runBusy(.delete, milliseconds: 1100) { [weak self] in
            guard let self else { return }
            self.resendTask?.cancel()
            self.alertOpen = false
            self.registered = false
            self.name = "friend"
            self.email = nil
            self.meters = 0
            self.discarded = []
            self.done = 0
            self.journeyBaseOverride = 0
            self.accountPassword = ""
            self.sessionStash = nil
            self.openMilestones = []
            self.openPhases = [:]
            self.resendSeconds = 0
            self.rgStage = .form
            self.rgEmail = ""
            self.rgPw = ""
            self.rgPw2 = ""
            self.rgCode = ""
            self.rgErrEmail = ""
            self.rgErrPw = ""
            self.rgErrPw2 = ""
            self.rgErrCode = ""
            self.rgLoginEmail = ""
            self.rgLoginPw = ""
            self.rgLoginError = false
            self.screen = .settings
        }
    }

    // MARK: Onboarding completion

    func finishOnboarding(name overrideName: String? = nil, email overrideEmail: String? = nil, registered isRegistered: Bool?) {
        onboarding.cancel()
        resendTask?.cancel()

        let picked = onboarding.types.isEmpty ? chosen : onboarding.types
        let nextCategory = picked.contains(category) ? category : (picked.first ?? category)

        onboarding.done = true
        onboarding.maskVisible = false
        onboarding.checkVisible = false
        resendSeconds = 0

        if let isRegistered { registered = isRegistered }
        if isRegistered == true, !onboarding.password.isEmpty { accountPassword = onboarding.password }

        let trimmedName = onboarding.name.trimmingCharacters(in: .whitespacesAndNewlines)
        name = overrideName ?? (trimmedName.isEmpty ? "friend" : trimmedName)

        let trimmedEmail = onboarding.email.trimmingCharacters(in: .whitespacesAndNewlines)
        email = overrideEmail ?? (trimmedEmail.isEmpty ? email : trimmedEmail)

        chosen = picked
        category = nextCategory
        index = 0
        drag = .zero
        meters += onboarding.earnedMeters
        screen = .home
        menuOpen = false
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
