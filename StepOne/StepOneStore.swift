//
//  StepOneStore.swift
//  StepOne
//
//  App state and behaviour, ported from the design's Component class.
//

import AuthenticationServices
import SwiftUI

// MARK: - Navigation

enum Screen: Equatable {
    case home, settings, account, preferences, language, notifications, help
    case tripTypes, discarded, journey
    case changeName, changeEmail, password
}

/// Firebase confirms an email change by link, so the flow is one form and then
/// a "we have sent it" panel — there is no code to key in.
enum VerifyStage: Equatable { case form, sent }
enum RegisterStage: Equatable { case form, verify, login }

struct DiscardRef: Equatable, Hashable {
    let category: String
    let index: Int
}

/// Progress is local to the device — none of it lives in Firebase yet — so
/// logging out parks it here and logging back into the same address picks it
/// up again. No password: Firebase owns credentials now.
struct SessionStash {
    var name: String
    var email: String
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
    case changeEmail, changePassword, changeName
    case apple
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

    /// Display order per category, as indices into the content list. Empty
    /// means "as authored"; completing a trip rewrites the entry.
    var tripOrder: [String: [Int]] = [:]

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

    // Account. Identity is mirrored from `auth` — Firebase is the source of
    // truth — while everything below it stays on the device.
    var name: String?
    var email: String?
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

    // Change name / email / password. Both changes are credentialed, so each
    // form carries the current password for Firebase's reauthentication.
    var nameDraft: String?
    var nameDiscardOpen = false
    var nameError = ""
    var emailStage: VerifyStage = .form
    var emailNew = ""
    var emailPassword = ""
    var emailErrNew = ""
    var emailErrPassword = ""
    var pwCurrent = ""
    var pwNew = ""
    var pwConfirm = ""
    var pwErrCurrent = ""
    var pwErrNew = ""
    var pwErrConfirm = ""
    var resendSeconds = 0

    // Delete account. Also credentialed, so the danger zone collects the
    // password before the confirmation alert opens.
    var deletePassword = ""
    var deleteError = ""

    // In-app registration (shown on Account when signed out)
    var rgStage: RegisterStage = .form
    var rgEmail = ""
    var rgPw = ""
    var rgPw2 = ""
    var rgErrEmail = ""
    var rgErrPw = ""
    var rgErrPw2 = ""
    var rgErrGeneral = ""
    var rgErrVerify = ""
    var rgLoginEmail = ""
    var rgLoginPw = ""
    var rgLoginError = ""
    var rgLoginEmptyEmail = false
    var rgLoginEmptyPw = false
    /// Shared by every Sign in with Apple button — only one is ever on screen.
    var appleError = ""

    var onboarding = OnboardingState()

    /// Firebase Authentication. Owned here rather than injected into the view
    /// tree so the store can mirror identity the moment it changes.
    let auth: AuthSession

    init(auth: AuthSession = AuthSession()) {
        self.auth = auth
        auth.onChange = { [weak self] state in self?.applyAuthState(state) }
        auth.start()
    }

    private var slideTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var rewardTask: Task<Void, Never>?
    private var resendTask: Task<Void, Never>?
    private var busyTask: Task<Void, Never>?

    let slot: CGFloat = 340

    /// How many other trips must sit between the new current trip and the one
    /// just completed, on each side of the circular list.
    let completedGap = 5

    // MARK: Derived

    var isNight: Bool { nightOverride ?? false }
    var theme: StepOneTheme { .of(night: isNight) }
    var S: Strings { Strings(lang: lang, content: content) }
    /// Registered means Firebase has a *verified* account signed in. An
    /// account that exists but has not confirmed its address still reads as
    /// signed out, so Account keeps offering the registration panel.
    var isRegistered: Bool { auth.isSignedIn }

    /// Apple-only accounts have no password to change and no address we
    /// control, so the screens that assume one are hidden for them.
    var usesPassword: Bool { auth.user?.usesPassword ?? false }

    var displayName: String { name ?? "friend" }
    var displayEmail: String { email ?? "" }

    /// Mirrors Firebase's copy of the profile into the fields the screens
    /// already read. Progress is deliberately untouched — logging in and out
    /// is handled where the stash rules live.
    private func applyAuthState(_ state: AuthSession.State) {
        switch state {
        case .loading, .signedOut:
            break
        case .awaitingVerification(let user), .signedIn(let user):
            if let displayName = user.displayName, !displayName.isEmpty {
                name = displayName
            }
            email = user.email
        }
    }

    var trips: [TripSpec] { trips(for: category) }

    func trips(for category: String) -> [TripSpec] {
        let source = content.trips(lang: lang, category: category)
        return order(for: category).compactMap { source[safe: $0] }
    }

    /// The order of the trips still in play for a category: content indices
    /// with anything discarded left out, fitted to the active language's trip
    /// count — the translations are not all the same length, so stored
    /// positions past the end are dropped and any new ones appended.
    func order(for category: String) -> [Int] {
        let count = content.trips(lang: lang, category: category).count
        let dropped = discardedIndices(for: category)
        var result = (tripOrder[category] ?? []).filter { $0 < count && !dropped.contains($0) }
        let seen = Set(result)
        result.append(contentsOf: (0..<count).filter { !seen.contains($0) && !dropped.contains($0) })
        return result
    }

    private func discardedIndices(for category: String) -> Set<Int> {
        Set(discarded.lazy.filter { $0.category == category }.map(\.index))
    }

    /// Discarded refs point into the content list, so they survive reordering.
    func trip(for ref: DiscardRef) -> TripSpec? {
        content.trips(lang: lang, category: ref.category)[safe: ref.index]
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
            self.relocateCompleted(at: self.wrapped(self.index))
            self.snapBack()
            self.isFading = false
            self.isAnimating = false
            self.showToast(self.S("traveled", "d", self.unit.format(self.meters)))
        }
    }

    /// Moves the trip at `position` to a random spot elsewhere in the list
    /// instead of dropping it: the rest is rotated so the next trip becomes the
    /// current one, and the completed trip is reinserted with at least
    /// `completedGap` other trips between it and the new current trip on both
    /// sides of the circle. Lists too short for that gap get the farthest spot
    /// available.
    private func relocateCompleted(at position: Int) {
        var remaining = order(for: category)
        let count = remaining.count
        guard count > 1, remaining.indices.contains(position) else {
            index = wrapped(index + 1)
            return
        }

        let moved = remaining.remove(at: position)
        // Rotate so the trip that followed the completed one leads the list.
        let start = position % remaining.count
        var next = Array(remaining[start...] + remaining[..<start])

        // Offset 0 is the new current trip, so the completed one lands in
        // 1...count-1; the gap narrows that to lower...upper.
        let lower = min(completedGap + 1, count - 1)
        let upper = max(count - completedGap - 1, 1)
        let offset = lower <= upper ? Int.random(in: lower...upper) : max(1, count / 2)

        next.insert(moved, at: offset)
        tripOrder[category] = next
        index = 0
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
            let position = self.wrapped(self.index)
            let contentIndex = self.order(for: self.category)[safe: position] ?? position
            let ref = DiscardRef(category: self.category, index: contentIndex)
            if !self.discarded.contains(ref) { self.discarded.append(ref) }
            // The trip has left the deck, so the one after it now sits at
            // `position` — or the deck wraps, or it has run out entirely.
            self.index = self.wrapped(position)
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
        nameDiscardOpen = false
        guard !draft.isEmpty else {
            nameError = "Enter a name"
            return
        }
        nameError = ""

        runAuth(.changeName) { [weak self] in
            guard let self else { return }
            // Signed out, the name is just the local greeting from onboarding
            // and there is no Firebase profile to push it to.
            guard self.isRegistered else {
                self.name = draft
                self.screen = .account
                return
            }
            guard await self.auth.changeName(to: draft) else {
                self.nameError = self.auth.errorMessage ?? ""
                return
            }
            self.name = draft
            self.screen = .account
        }
    }

    // MARK: Change email

    /// Firebase sends the confirmation link to the *new* address and only
    /// swaps it over once that link is opened, so this ends on a "sent" panel
    /// rather than on a changed address.
    func sendEmailChange() {
        let newEmail = emailNew.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailOk = Self.isValidEmail(newEmail)

        emailErrNew = emailOk ? "" : "Enter a valid email address"
        emailErrPassword = emailPassword.isEmpty ? "Enter your current password" : ""
        guard emailOk, !emailPassword.isEmpty else { return }

        runAuth(.changeEmail) { [weak self] in
            guard let self else { return }
            let sent = await self.auth.changeEmail(
                to: newEmail,
                currentPassword: self.emailPassword
            )
            guard sent else {
                switch self.auth.error {
                case .invalidCredentials, .requiresRecentLogin:
                    self.emailErrPassword = self.auth.errorMessage ?? ""
                default:
                    self.emailErrNew = self.auth.errorMessage ?? ""
                }
                return
            }
            self.emailPassword = ""
            self.emailStage = .sent
        }
    }

    // MARK: Change password

    func confirmPassword() {
        let newOk = Self.isValidPassword(pwNew)
        let matchOk = !pwConfirm.isEmpty && pwConfirm == pwNew

        pwErrCurrent = pwCurrent.isEmpty ? "Enter your current password" : ""
        pwErrNew = newOk ? "" : "Use 8 or more characters with a number and a letter"
        pwErrConfirm = matchOk ? "" : S["pwMismatch"]
        guard !pwCurrent.isEmpty, newOk, matchOk else { return }

        runAuth(.changePassword) { [weak self] in
            guard let self else { return }
            let changed = await self.auth.changePassword(current: self.pwCurrent, to: self.pwNew)
            guard changed else {
                switch self.auth.error {
                case .invalidCredentials, .requiresRecentLogin:
                    self.pwErrCurrent = self.auth.errorMessage ?? ""
                default:
                    self.pwErrNew = self.auth.errorMessage ?? ""
                }
                return
            }
            self.pwCurrent = ""
            self.pwNew = ""
            self.pwConfirm = ""
            self.screen = .account
            self.showToast("Password updated")
        }
    }

    // MARK: Busy helper

    /// Runs one auth call with the spinner up. The spinner clears when the
    /// call actually returns, rather than after the design's fixed delay.
    func runAuth(_ action: BusyAction, _ work: @escaping () async -> Void) {
        guard busy == nil else { return }
        busy = action
        busyTask?.cancel()
        busyTask = Task { [weak self] in
            await work()
            self?.busy = nil
        }
    }

    /// Shared by every screen that can ask for the verification email again.
    func resendVerification(_ action: BusyAction) {
        guard resendSeconds == 0 else { return }
        runAuth(action) { [weak self] in
            guard let self else { return }
            if await self.auth.resendVerification() { self.startResend() }
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
        let em = rgEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailOk = Self.isValidEmail(em)
        let pwOk = Self.isValidPassword(rgPw)
        let matchOk = !rgPw2.isEmpty && rgPw2 == rgPw

        rgErrEmail = emailOk ? "" : "Enter a valid email address"
        rgErrPw = pwOk ? "" : "Use 8 or more characters with a number and a letter"
        rgErrPw2 = matchOk ? "" : "Passwords do not match"
        rgErrGeneral = ""

        guard emailOk, pwOk, matchOk else { return }
        runAuth(.rgRegister) { [weak self] in
            guard let self else { return }
            let created = await self.auth.register(
                email: em,
                password: self.rgPw,
                name: self.name
            )
            guard created else {
                self.placeRegisterError()
                return
            }
            self.beginVerificationWait()
        }
    }

    /// Manual "I have confirmed it" check, for when the background watch has
    /// timed out or the app was backgrounded.
    func rgCheckVerification() {
        runAuth(.rgVerify) { [weak self] in
            guard let self else { return }
            if await self.auth.checkVerification() {
                self.completeRegistration()
            } else {
                self.rgErrVerify = self.auth.errorMessage
                    ?? "Not confirmed yet — open the link in your email"
            }
        }
    }

    /// Settles the app once the address is confirmed. Called both by the
    /// manual check and by the background watch finishing on its own.
    func completeRegistration() {
        resendTask?.cancel()
        resendSeconds = 0
        journeyBaseOverride = content.journeyBase
        rgStage = .form
        rgPw = ""
        rgPw2 = ""
        rgErrVerify = ""
        rgErrGeneral = ""
    }

    func rgLogin() {
        let em = rgLoginEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !em.isEmpty, !rgLoginPw.isEmpty else {
            rgLoginEmptyEmail = em.isEmpty
            rgLoginEmptyPw = rgLoginPw.isEmpty
            rgLoginError = ""
            return
        }
        rgLoginEmptyEmail = false
        rgLoginEmptyPw = false
        rgLoginError = ""

        runAuth(.rgLogin) { [weak self] in
            guard let self else { return }
            guard await self.auth.logIn(email: em, password: self.rgLoginPw) else {
                self.rgLoginError = self.auth.errorMessage ?? ""
                return
            }
            self.rgLoginPw = ""

            // The account exists but has never confirmed its address, so it
            // lands on the same waiting panel a fresh sign-up does.
            guard !self.auth.needsVerification else {
                self.rgEmail = em
                self.beginVerificationWait()
                return
            }
            self.restoreProgress(for: self.auth.user?.email)
            self.rgStage = .form
        }
    }

    // MARK: Sign in with Apple

    /// Apple hands back an authorisation; this turns it into a Firebase
    /// session. `onSignedIn` lets onboarding move on once it lands.
    func completeAppleSignIn(
        _ result: Result<ASAuthorization, Error>,
        onSignedIn: @escaping () -> Void = {}
    ) {
        switch result {
        case .failure(let failure):
            // Backing out is a decision, not a failure — say nothing.
            guard (failure as? ASAuthorizationError)?.code != .canceled else { return }
            appleError = "Could not sign in with Apple. Try again"

        case .success(let authorization):
            guard let tokens = authorization.appleTokens else {
                appleError = AuthError.appleTokenMissing.message
                return
            }
            appleError = ""
            runAuth(.apple) { [weak self] in
                guard let self else { return }
                let ok = await self.auth.signInWithApple(
                    idToken: tokens.idToken,
                    fullName: tokens.fullName
                )
                guard ok else {
                    self.appleError = self.auth.errorMessage ?? ""
                    return
                }
                self.restoreProgress(for: self.auth.user?.email)
                self.rgStage = .form
                onSignedIn()
            }
        }
    }

    /// Deleting an Apple account needs a fresh authorisation rather than a
    /// password, and the code it carries is what revokes the Apple token.
    func completeAppleDelete(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let failure):
            guard (failure as? ASAuthorizationError)?.code != .canceled else { return }
            deleteError = "Could not confirm with Apple. Try again"

        case .success(let authorization):
            guard let tokens = authorization.appleTokens else {
                deleteError = AuthError.appleTokenMissing.message
                return
            }
            deleteError = ""
            runAuth(.delete) { [weak self] in
                guard let self else { return }
                let deleted = await self.auth.deleteAccountWithApple(
                    idToken: tokens.idToken,
                    authorizationCode: tokens.authorizationCode
                )
                self.alertOpen = false
                guard deleted else {
                    self.deleteError = self.auth.errorMessage ?? ""
                    return
                }
                self.finishAccountDeletion()
            }
        }
    }

    /// Moves to the waiting panel, starts the resend cooldown and begins
    /// polling so the screen advances the moment the link is opened.
    private func beginVerificationWait() {
        rgStage = .verify
        rgErrVerify = ""
        rgPw = ""
        rgPw2 = ""
        startResend()
        auth.watchForVerification()
    }

    /// Puts an auth failure on the field it belongs to, so a rejected sign-up
    /// reads the way a validation error does.
    private func placeRegisterError() {
        let message = auth.errorMessage ?? ""
        switch auth.error {
        case .invalidEmail, .emailAlreadyInUse:
            rgErrEmail = message
        case .weakPassword:
            rgErrPw = message
        default:
            rgErrGeneral = message
        }
    }

    /// Local progress belongs to whoever was last signed in on this device, so
    /// it only comes back for the same address.
    private func restoreProgress(for email: String?) {
        guard let email, let stash = sessionStash,
              stash.email.caseInsensitiveCompare(email) == .orderedSame else {
            journeyBaseOverride = content.journeyBase
            return
        }
        name = stash.name
        meters = stash.meters
        discarded = stash.discarded
        done = stash.done
        journeyBaseOverride = stash.journeyBase
        sessionStash = nil
    }

    // MARK: Account actions

    func logOut() {
        runAuth(.logout) { [weak self] in
            guard let self else { return }
            // Read the identity off before signing out — `displayEmail` is a
            // mirror of the session and empties as soon as it clears.
            let stash = SessionStash(
                name: self.displayName,
                email: self.displayEmail,
                meters: self.meters,
                discarded: self.discarded,
                done: self.done,
                journeyBase: self.journeyBaseOverride ?? self.content.journeyBase
            )
            guard self.auth.logOut() else { return }

            self.resendTask?.cancel()
            self.auth.stopWatchingForVerification()
            self.sessionStash = stash
            self.clearAccountState()
            self.rgStage = .login
            self.rgLoginEmail = ""
            self.rgLoginPw = ""
            self.rgLoginError = ""
            self.rgLoginEmptyEmail = false
            self.rgLoginEmptyPw = false
        }
    }

    /// Deletes the Firebase account. Reauthentication is required, so the
    /// danger zone collects the password before the alert opens.
    func deleteAccount() {
        guard !deletePassword.isEmpty else {
            alertOpen = false
            deleteError = "Enter your password to confirm"
            return
        }
        runAuth(.delete) { [weak self] in
            guard let self else { return }
            let deleted = await self.auth.deleteAccount(currentPassword: self.deletePassword)
            self.alertOpen = false
            guard deleted else {
                self.deleteError = self.auth.errorMessage ?? ""
                return
            }
            self.finishAccountDeletion()
        }
    }

    /// Shared by both delete paths so the password and Apple routes cannot
    /// drift apart in what they tear down.
    private func finishAccountDeletion() {
        resendTask?.cancel()
        auth.stopWatchingForVerification()
        sessionStash = nil
        clearAccountState()
        rgStage = .form
        rgEmail = ""
        rgLoginEmail = ""
        rgLoginPw = ""
        rgLoginError = ""
        screen = .settings
    }

    /// Everything that belongs to the signed-in account, reset in one place so
    /// log out and delete cannot drift apart.
    private func clearAccountState() {
        name = "friend"
        email = nil
        meters = 0
        discarded = []
        done = 0
        journeyBaseOverride = 0
        openMilestones = []
        openPhases = [:]
        resendSeconds = 0
        deletePassword = ""
        deleteError = ""
        emailStage = .form
        emailNew = ""
        emailPassword = ""
        emailErrNew = ""
        emailErrPassword = ""
        pwCurrent = ""
        pwNew = ""
        pwConfirm = ""
        pwErrCurrent = ""
        pwErrNew = ""
        pwErrConfirm = ""
        rgPw = ""
        rgPw2 = ""
        rgErrEmail = ""
        rgErrPw = ""
        rgErrPw2 = ""
        rgErrGeneral = ""
        rgErrVerify = ""
        appleError = ""
    }

    // MARK: Onboarding completion

    /// Registration state is no longer passed in — `isRegistered` reads it
    /// straight off the Firebase session, so skipping and completing sign-up
    /// both land here unchanged.
    func finishOnboarding(name overrideName: String? = nil, email overrideEmail: String? = nil) {
        onboarding.cancel()
        resendTask?.cancel()
        auth.stopWatchingForVerification()

        let picked = onboarding.types.isEmpty ? chosen : onboarding.types
        let nextCategory = picked.contains(category) ? category : (picked.first ?? category)

        onboarding.done = true
        onboarding.maskVisible = false
        onboarding.checkVisible = false
        resendSeconds = 0

        // Firebase's copy wins when there is one: it survives reinstalls, and
        // a returning log-in carries the name the account was made with.
        let trimmedName = onboarding.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let firebaseName = auth.user?.displayName.flatMap { $0.isEmpty ? nil : $0 }
        name = overrideName ?? firebaseName ?? (trimmedName.isEmpty ? "friend" : trimmedName)

        let trimmedEmail = onboarding.email.trimmingCharacters(in: .whitespacesAndNewlines)
        email = overrideEmail ?? auth.user?.email ?? (trimmedEmail.isEmpty ? email : trimmedEmail)

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
