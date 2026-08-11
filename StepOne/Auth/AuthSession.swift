//
//  AuthSession.swift
//  StepOne
//
//  The observable face of AuthService: one state enum for the screens to
//  switch on, one spinner flag, one error string. Keeps do/catch out of the
//  views the way StepOneStore keeps timing out of them.
//

import Foundation
import Observation

@Observable
final class AuthSession {
    enum State: Equatable {
        /// Before the first callback from Firebase. Launching straight into a
        /// signed-out screen here would flash for anyone already logged in.
        case loading
        case signedOut
        /// Signed in, but Firebase has not seen the address confirmed yet.
        case awaitingVerification(AuthUser)
        case signedIn(AuthUser)
    }

    private(set) var state: State = .loading
    private(set) var isWorking = false
    /// The typed failure from the last call, so callers can route it to the
    /// field it belongs to instead of matching on message text. Cleared at the
    /// start of every call, so a stale failure never outlives the attempt that
    /// produced it.
    private(set) var error: AuthError?

    var errorMessage: String? { error?.message }

    /// Fired on every transition. Lets an owner that is not a view — the store
    /// — mirror identity without polling or observation tracking.
    var onChange: ((State) -> Void)?

    private let service: AuthServicing
    private var observation: AuthStateObservation?
    private var verificationWatch: Task<Void, Never>?

    init(service: AuthServicing = FirebaseAuthService()) {
        self.service = service
    }

    // MARK: Lifecycle

    /// Attaches the Firebase state listener. Call once, from the root view's
    /// `.task` or `.onAppear`.
    func start() {
        guard observation == nil else { return }
        observation = service.observeAuthState { [weak self] user in
            self?.apply(user)
        }
    }

    /// Detaches the listener and stops any verification polling.
    func stop() {
        observation?.stop()
        observation = nil
        verificationWatch?.cancel()
        verificationWatch = nil
    }

    // MARK: Derived

    var user: AuthUser? {
        switch state {
        case .signedIn(let user), .awaitingVerification(let user): return user
        case .loading, .signedOut: return nil
        }
    }

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    var needsVerification: Bool {
        if case .awaitingVerification = state { return true }
        return false
    }

    // MARK: Sign up / in / out

    /// Creates the account and sends the verification email. On success the
    /// state lands on `.awaitingVerification`.
    @discardableResult
    func register(email: String, password: String, name: String?) async -> Bool {
        await perform {
            let user = try await self.service.signUp(
                email: email,
                password: password,
                displayName: name
            )
            self.apply(user)
        }
    }

    @discardableResult
    func logIn(email: String, password: String) async -> Bool {
        await perform {
            let user = try await self.service.signIn(email: email, password: password)
            self.apply(user)
        }
    }

    @discardableResult
    func logOut() -> Bool {
        error = nil
        verificationWatch?.cancel()
        do {
            try service.signOut()
            // The listener will also report this, but setting it here keeps
            // the transition synchronous with the button press.
            setState(.signedOut)
            return true
        } catch {
            self.error = AuthError(error)
            return false
        }
    }

    // MARK: Email verification

    @discardableResult
    func resendVerification() async -> Bool {
        await perform { try await self.service.sendEmailVerification() }
    }

    /// One-shot check, for a "Check again" button. Returns true only once the
    /// address is actually confirmed.
    @discardableResult
    func checkVerification() async -> Bool {
        let succeeded = await perform {
            let user = try await self.service.refreshUser()
            self.apply(user)
        }
        return succeeded && isSignedIn
    }

    /// Polls in the background so the screen advances on its own when the link
    /// is clicked. Safe to call repeatedly — the previous watch is replaced.
    func watchForVerification() {
        verificationWatch?.cancel()
        verificationWatch = Task { [weak self] in
            guard let self else { return }
            do {
                let user = try await self.service.waitForEmailVerification()
                self.apply(user)
            } catch is CancellationError {
                // Left the screen; nothing to report.
            } catch AuthError.verificationTimedOut {
                // Expected — they simply have not got to the email yet. The
                // "Check again" button is the way back in, so staying quiet
                // beats interrupting with an error.
            } catch {
                self.error = AuthError(error)
            }
        }
    }

    func stopWatchingForVerification() {
        verificationWatch?.cancel()
        verificationWatch = nil
    }

    // MARK: Account changes

    /// Always report success neutrally: with email enumeration protection on,
    /// this succeeds for addresses that have no account.
    @discardableResult
    func sendPasswordReset(email: String) async -> Bool {
        await perform { try await self.service.sendPasswordReset(email: email) }
    }

    @discardableResult
    func changePassword(current: String, to newPassword: String) async -> Bool {
        await perform {
            try await self.service.updatePassword(current: current, to: newPassword)
        }
    }

    /// Sends a confirmation link to the new address; the account keeps the old
    /// one until that link is clicked.
    @discardableResult
    func changeEmail(to newEmail: String, currentPassword: String) async -> Bool {
        await perform {
            try await self.service.sendEmailChange(
                to: newEmail,
                currentPassword: currentPassword
            )
        }
    }

    @discardableResult
    func changeName(to name: String) async -> Bool {
        await perform {
            let user = try await self.service.updateDisplayName(name)
            self.apply(user)
        }
    }

    @discardableResult
    func deleteAccount(currentPassword: String) async -> Bool {
        await perform {
            try await self.service.deleteAccount(currentPassword: currentPassword)
            self.setState(.signedOut)
        }
    }

    // MARK: Plumbing

    private func apply(_ user: AuthUser?) {
        guard let user else {
            setState(.signedOut)
            return
        }
        setState(user.isEmailVerified ? .signedIn(user) : .awaitingVerification(user))
    }

    private func setState(_ next: State) {
        guard next != state else { return }
        state = next
        onChange?(next)
    }

    /// Runs one auth call with the spinner up, funnelling failures into
    /// `error`. Returns whether it succeeded, so callers can branch without
    /// reading the failure back out.
    @discardableResult
    private func perform(_ work: () async throws -> Void) async -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        error = nil
        defer { isWorking = false }

        do {
            try await work()
            return true
        } catch is CancellationError {
            return false
        } catch {
            self.error = AuthError(error)
            return false
        }
    }
}
