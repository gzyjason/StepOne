//
//  AuthService.swift
//  StepOne
//
//  The Firebase Authentication boundary: account creation, log in, email
//  verification and the credentialed account changes behind Settings. Nothing
//  above this file imports FirebaseAuth.
//

import FirebaseAuth
import FirebaseCore
import Foundation

/// How to prove the session is fresh enough for a destructive change.
/// Firebase refuses these on a stale login, and the proof differs by how the
/// account was made.
enum ReauthMethod {
    case password(String)
    /// `authorizationCode` is what lets Firebase revoke the Apple token on
    /// delete — App Review requires that of anything offering Apple sign-in.
    case apple(idToken: String, rawNonce: String, authorizationCode: String?)
}

// MARK: - Contract

protocol AuthServicing {
    /// False until a `GoogleService-Info.plist` is in the bundle and
    /// `FirebaseApp.configure()` has run. Every call below fails with
    /// `.notConfigured` while this is false rather than trapping.
    var isAvailable: Bool { get }

    /// The cached account, read synchronously. `isEmailVerified` here is only
    /// as fresh as the last `refreshUser()`.
    var currentUser: AuthUser? { get }

    func signUp(email: String, password: String, displayName: String?) async throws -> AuthUser
    func signIn(email: String, password: String) async throws -> AuthUser
    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> AuthUser
    func signOut() throws

    func sendEmailVerification() async throws
    func refreshUser() async throws -> AuthUser
    func waitForEmailVerification(pollEvery: Duration, timeout: Duration) async throws -> AuthUser

    func sendPasswordReset(email: String) async throws
    func updatePassword(current: String, to newPassword: String) async throws
    func sendEmailChange(to newEmail: String, currentPassword: String) async throws
    func updateDisplayName(_ name: String) async throws -> AuthUser
    func deleteAccount(reauthenticatingWith method: ReauthMethod) async throws

    @discardableResult
    func observeAuthState(_ onChange: @escaping @MainActor (AuthUser?) -> Void) -> AuthStateObservation
}

extension AuthServicing {
    /// Five minutes at three-second intervals: long enough to leave the app,
    /// open the mail client and come back, short enough that an abandoned
    /// screen stops polling on its own.
    ///
    /// Deliberately a distinct no-argument overload rather than the same
    /// signature with defaults — that would redeclare the requirement, and any
    /// conformer relying on it would call straight back into itself.
    func waitForEmailVerification() async throws -> AuthUser {
        try await waitForEmailVerification(pollEvery: .seconds(3), timeout: .seconds(300))
    }
}

/// Token for a state listener. Held for as long as the callbacks are wanted;
/// `stop()` detaches. Deliberately not a `deinit`-based cancel, so tearing it
/// down never has to hop actors.
final class AuthStateObservation {
    private var onStop: (() -> Void)?

    init(onStop: @escaping () -> Void) {
        self.onStop = onStop
    }

    func stop() {
        onStop?()
        onStop = nil
    }
}

// MARK: - Firebase implementation

final class FirebaseAuthService: AuthServicing {
    /// Where the emailed links send people once the action is done. `nil` uses
    /// the project's default Firebase-hosted page, which is the only option
    /// that needs no extra setup; a custom URL must also be listed under
    /// Authentication → Settings → Authorized domains.
    private let continueURL: URL?

    init(continueURL: URL? = nil) {
        self.continueURL = continueURL
    }

    /// Resolved per call rather than stored. `Auth.auth()` calls `fatalError`
    /// when the default app is missing, so a stored property would trap at
    /// whatever moment its owner happened to be built.
    private var auth: Auth { Auth.auth() }

    var isAvailable: Bool { FirebaseApp.app() != nil }

    var currentUser: AuthUser? {
        guard isAvailable else { return nil }
        return auth.currentUser.map { AuthUser($0) }
    }

    // MARK: Sign up / in / out

    /// Creates the account, applies `displayName` if given, and sends the
    /// verification email in one go. The returned user is signed in but not
    /// yet verified — Firebase does not gate sign-in on verification, so that
    /// check belongs to the caller.
    func signUp(email: String, password: String, displayName: String?) async throws -> AuthUser {
        let auth = try requireAuth()
        return try await mapping {
            let result = try await auth.createUser(
                withEmail: email.normalizedEmail,
                password: password
            )
            if let displayName, !displayName.isEmpty {
                let change = result.user.createProfileChangeRequest()
                change.displayName = displayName
                try await change.commitChanges()
            }
            try await result.user.sendEmailVerification(with: actionCodeSettings)
            return AuthUser(result.user)
        }
    }

    /// Signs in regardless of verification state, so an unverified account can
    /// still reach the "resend the email" screen. Branch on
    /// `AuthUser.isEmailVerified` at the call site.
    func signIn(email: String, password: String) async throws -> AuthUser {
        let auth = try requireAuth()
        return try await mapping {
            let result = try await auth.signIn(
                withEmail: email.normalizedEmail,
                password: password
            )
            return AuthUser(result.user)
        }
    }

    /// Signs in with the identity token Apple just issued. `rawNonce` must be
    /// the value whose hash went out on the request, or Firebase rejects it.
    func signInWithApple(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents?
    ) async throws -> AuthUser {
        let auth = try requireAuth()
        return try await mapping {
            let credential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: rawNonce,
                fullName: fullName
            )
            let result = try await auth.signIn(with: credential)

            // Apple sends the name on the very first authorisation only, so if
            // it arrived and the profile is still blank this is the one chance
            // to keep it. Revoking and re-authorising is the user's only way
            // back to this moment.
            if (result.user.displayName ?? "").isEmpty, let fullName {
                let formatted = PersonNameComponentsFormatter.localizedString(
                    from: fullName,
                    style: .default
                )
                if !formatted.isEmpty {
                    let change = result.user.createProfileChangeRequest()
                    change.displayName = formatted
                    try await change.commitChanges()
                }
            }
            return AuthUser(result.user)
        }
    }

    func signOut() throws {
        let auth = try requireAuth()
        do {
            try auth.signOut()
        } catch {
            throw AuthError(error)
        }
    }

    // MARK: Email verification

    func sendEmailVerification() async throws {
        let user = try requireUser()
        try await mapping {
            try await user.sendEmailVerification(with: actionCodeSettings)
        }
    }

    /// Pulls the account record down again. `isEmailVerified` only ever
    /// changes locally as a result of this call — clicking the link updates
    /// Firebase's copy, not the device's.
    @discardableResult
    func refreshUser() async throws -> AuthUser {
        let user = try requireUser()
        try await mapping { try await user.reload() }

        if user.isEmailVerified {
            // Security rules and any backend of your own read `email_verified`
            // off the ID token, and `reload()` leaves the token alone. Force
            // one refresh so the freshly set flag is actually in it.
            try await mapping { _ = try await user.getIDToken(forcingRefresh: true) }
        }
        return AuthUser(user)
    }

    /// Polls until the link in the email has been clicked. Throws
    /// `.verificationTimedOut` if it never is, and propagates cancellation
    /// untouched so leaving the screen stops the polling.
    func waitForEmailVerification(
        pollEvery interval: Duration,
        timeout: Duration
    ) async throws -> AuthUser {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while true {
            let user = try await refreshUser()
            if user.isEmailVerified { return user }
            guard ContinuousClock.now < deadline else { throw AuthError.verificationTimedOut }
            try await Task.sleep(for: interval)
        }
    }

    // MARK: Credentialed changes

    /// Succeeds even for addresses with no account when email enumeration
    /// protection is on, so the screen must show the same neutral "check your
    /// inbox" message either way.
    func sendPasswordReset(email: String) async throws {
        let auth = try requireAuth()
        try await mapping {
            try await auth.sendPasswordReset(
                withEmail: email.normalizedEmail,
                actionCodeSettings: actionCodeSettings
            )
        }
    }

    func updatePassword(current currentPassword: String, to newPassword: String) async throws {
        let user = try requireUser()
        try await mapping {
            try await reauthenticate(user, password: currentPassword)
            try await user.updatePassword(to: newPassword)
        }
    }

    /// Sends a confirmation link to the *new* address. The account's email
    /// only changes once that link is clicked, so the caller should keep
    /// showing the old address until a `refreshUser()` reports otherwise.
    func sendEmailChange(to newEmail: String, currentPassword: String) async throws {
        let user = try requireUser()
        try await mapping {
            try await reauthenticate(user, password: currentPassword)
            try await user.sendEmailVerification(
                beforeUpdatingEmail: newEmail.normalizedEmail,
                actionCodeSettings: actionCodeSettings
            )
        }
    }

    @discardableResult
    func updateDisplayName(_ name: String) async throws -> AuthUser {
        let user = try requireUser()
        try await mapping {
            let change = user.createProfileChangeRequest()
            change.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            try await change.commitChanges()
        }
        return AuthUser(user)
    }

    /// Deletes the Firebase account only. Anything you later store keyed on
    /// the `uid` has to be removed alongside this.
    func deleteAccount(reauthenticatingWith method: ReauthMethod) async throws {
        let user = try requireUser()
        try await mapping {
            switch method {
            case .password(let password):
                try await reauthenticate(user, password: password)

            case .apple(let idToken, let rawNonce, let authorizationCode):
                let credential = OAuthProvider.appleCredential(
                    withIDToken: idToken,
                    rawNonce: rawNonce,
                    fullName: nil
                )
                _ = try await user.reauthenticate(with: credential)
                if let authorizationCode {
                    // Hands the Apple ID back — without it the app keeps
                    // showing under the user's "Sign in with Apple" settings
                    // long after the account is gone.
                    //
                    // Best effort on purpose: Firebase can only revoke once
                    // the Apple provider is fully configured (Services ID and
                    // key), and a failure there must not leave someone unable
                    // to delete an account they have asked to be rid of.
                    try? await auth.revokeToken(withAuthorizationCode: authorizationCode)
                }
            }
            try await user.delete()
        }
    }

    // MARK: State observation

    @discardableResult
    func observeAuthState(
        _ onChange: @escaping @MainActor (AuthUser?) -> Void
    ) -> AuthStateObservation {
        guard isAvailable else {
            // Report signed-out once so callers waiting on a first callback
            // are not left hanging on an unconfigured project.
            MainActor.assumeIsolated { onChange(nil) }
            return AuthStateObservation {}
        }

        let auth = self.auth
        let handle = auth.addStateDidChangeListener { _, user in
            let snapshot = user.map { AuthUser($0) }
            // Firebase delivers these on the main thread, which is what makes
            // this safe — and synchronous, so there is no signed-out flicker
            // between launch and the first callback.
            MainActor.assumeIsolated { onChange(snapshot) }
        }
        return AuthStateObservation { auth.removeStateDidChangeListener(handle) }
    }

    // MARK: Plumbing

    private var actionCodeSettings: ActionCodeSettings? {
        guard let continueURL else { return nil }
        let settings = ActionCodeSettings()
        settings.url = continueURL
        // Handling the code in-app needs Universal Links; Dynamic Links, the
        // old route, has been shut down. Letting the web page handle it keeps
        // this working with no further setup.
        settings.handleCodeInApp = false
        return settings
    }

    private func requireAuth() throws -> Auth {
        guard isAvailable else { throw AuthError.notConfigured }
        return auth
    }

    private func requireUser() throws -> User {
        guard let user = try requireAuth().currentUser else { throw AuthError.notSignedIn }
        return user
    }

    private func reauthenticate(_ user: User, password: String) async throws {
        guard let email = user.email else { throw AuthError.notSignedIn }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        _ = try await user.reauthenticate(with: credential)
    }

    /// Runs `work`, rewriting whatever Firebase throws as an `AuthError`.
    /// Cancellation passes through untouched so a torn-down task is never
    /// mistaken for a failed request.
    private func mapping<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AuthError(error)
        }
    }
}

// MARK: - Bridging

private extension AuthUser {
    init(_ user: User) {
        self.init(
            id: user.uid,
            email: user.email,
            displayName: user.displayName,
            isEmailVerified: user.isEmailVerified,
            providerIDs: user.providerData.map(\.providerID)
        )
    }
}

private extension String {
    /// Firebase rejects addresses carrying stray whitespace and the forms let
    /// it through, so normalise once at the boundary instead of in each screen.
    var normalizedEmail: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
