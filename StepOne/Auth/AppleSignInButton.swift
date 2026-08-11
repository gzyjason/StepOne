//
//  AppleSignInButton.swift
//  StepOne
//
//  The one place that touches AuthenticationServices. Everything below it
//  deals in plain strings, so the auth layer never imports UI frameworks.
//

import AuthenticationServices
import SwiftUI

struct AppleSignInButton: View {
    @Bindable var store: StepOneStore
    /// Called once Firebase has accepted the identity token.
    var onSignedIn: () -> Void = {}

    private var theme: StepOneTheme { store.theme }

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
            request.nonce = store.auth.appleRequestNonce()
        } onCompletion: { result in
            store.completeAppleSignIn(result, onSignedIn: onSignedIn)
        }
        // Apple's own button, so the styling stays within their guidelines;
        // only the metrics are matched to PrimaryButton.
        .signInWithAppleButtonStyle(store.isNight ? .white : .black)
        .frame(height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .opacity(store.busy == .apple ? 0.5 : 1)
        .allowsHitTesting(store.busy == nil)
        .overlay {
            if store.busy == .apple { Spinner(color: theme.accent, size: 20) }
        }
    }
}

/// Re-authorisation used to confirm a delete on an Apple account. Firebase
/// will not delete on a stale login, and the Apple token has to be revoked.
struct AppleReauthButton: View {
    @Bindable var store: StepOneStore

    var body: some View {
        SignInWithAppleButton(.continue) { request in
            request.requestedScopes = []
            request.nonce = store.auth.appleRequestNonce()
        } onCompletion: { result in
            store.completeAppleDelete(result)
        }
        .signInWithAppleButtonStyle(store.isNight ? .white : .black)
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(store.busy == .delete ? 0.5 : 1)
        .allowsHitTesting(store.busy == nil)
    }
}

extension ASAuthorization {
    /// The identity token and authorization code, as the strings the auth
    /// layer wants. Nil when Apple hands back something unexpected.
    var appleTokens: (idToken: String, authorizationCode: String?, fullName: PersonNameComponents?)? {
        guard let credential = credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else { return nil }

        let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        return (idToken, code, credential.fullName)
    }
}
