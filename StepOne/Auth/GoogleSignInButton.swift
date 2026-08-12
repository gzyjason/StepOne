//
//  GoogleSignInButton.swift
//  StepOne
//
//  The one place that touches the GoogleSignIn SDK. It hands the auth layer
//  two strings and nothing else, the way AppleSignInButton does.
//
//  The button is built here rather than using GoogleSignInSwift's, which
//  fixes its own height, corner radius, font and left-aligned layout and so
//  cannot be made to sit with PrimaryButton. Google's brand requirements are
//  what actually matter and they are met: the official mark, unmodified and
//  loaded from the SDK's own bundle, one of the approved wordings, and the
//  documented light/dark colour pairs.
//

import FirebaseCore
import GoogleSignIn
import SwiftUI
import UIKit

struct GoogleAuthButton: View {
    @Bindable var store: StepOneStore
    /// Nil uses Google's approved "Sign in with Google", translated.
    var title: String?
    var height: CGFloat = 54
    var radius: CGFloat = 18
    /// Called once Firebase has accepted the Google credential.
    var onSignedIn: () -> Void = {}

    var body: some View {
        GoogleButtonSurface(
            title: title ?? store.S["googleSignIn"],
            height: height,
            radius: radius,
            night: store.isNight,
            busy: store.busy == .google
        ) {
            store.startGoogleSignIn(onSignedIn: onSignedIn)
        }
        .disabled(store.busy != nil)
    }
}

/// Re-authorisation used to confirm a delete on a Google account, since
/// Firebase will not delete on a stale login.
struct GoogleReauthButton: View {
    @Bindable var store: StepOneStore

    var body: some View {
        GoogleButtonSurface(
            title: store.S["googleContinue"],
            height: 52,
            radius: 16,
            night: store.isNight,
            busy: store.busy == .delete
        ) {
            store.startGoogleDelete()
        }
        .disabled(store.busy != nil)
    }
}

// MARK: - Presentation

/// Matches PrimaryButton's metrics, font and press behaviour so the three
/// buttons read as one stack.
private struct GoogleButtonSurface: View {
    let title: String
    let height: CGFloat
    let radius: CGFloat
    let night: Bool
    let busy: Bool
    let action: () -> Void

    // Google's documented button colours.
    private var background: Color { night ? Color(red: 0.075, green: 0.075, blue: 0.078) : .white }
    private var foreground: Color { night ? Color(red: 0.89, green: 0.89, blue: 0.89) : Color(red: 0.12, green: 0.12, blue: 0.12) }
    private var border: Color { night ? Color(red: 0.56, green: 0.57, blue: 0.56) : Color(red: 0.45, green: 0.47, blue: 0.46) }

    var body: some View {
        Button(action: { if !busy { action() } }) {
            ZStack {
                HStack(spacing: 10) {
                    GoogleMark(size: 20)
                    Text(title)
                        // Same ramp PrimaryButton uses, so the three labels
                        // sit at one size.
                        .font(.system(size: height >= 54 ? 17 : 16, weight: .semibold))
                        .foregroundStyle(foreground)
                }
                .opacity(busy ? 0 : 1)

                if busy { Spinner(color: foreground, size: 20) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(background, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(border, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PressStyle(scale: 0.98))
    }
}

/// The official Google mark, taken from the SDK's own resource bundle so it
/// is never a redrawn approximation and never drifts from the SDK.
private struct GoogleMark: View {
    let size: CGFloat

    var body: some View {
        if let logo = GoogleSignInFlow.logo {
            Image(uiImage: logo)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            // Rather than substitute a lookalike, show nothing — the approved
            // wording still carries the button.
            Color.clear.frame(width: 0, height: size)
        }
    }
}

// MARK: - SDK bridge

enum GoogleSignInFlow {
    /// Resolved once. The SDK ships `google.png` inside its resource bundle;
    /// SPM, CocoaPods and framework builds each nest it differently, so both
    /// documented locations are tried.
    static let logo: UIImage? = {
        let name = "GoogleSignIn_GoogleSignIn"
        if let path = Bundle.main.path(forResource: name, ofType: "bundle"),
           let bundle = Bundle(path: path),
           let image = UIImage(named: "google", in: bundle, compatibleWith: nil) {
            return image
        }
        let classBundle = Bundle(for: GIDSignIn.self)
        if let path = classBundle.path(forResource: name, ofType: "bundle"),
           let bundle = Bundle(path: path),
           let image = UIImage(named: "google", in: bundle, compatibleWith: nil) {
            return image
        }
        return UIImage(named: "google", in: classBundle, compatibleWith: nil)
    }()

    /// Presents Google's sheet and returns the two tokens Firebase needs.
    @MainActor
    static func signIn() async throws -> (idToken: String, accessToken: String) {
        // Firebase's own options carry the OAuth client ID, so there is no
        // second copy of it to keep in step.
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.notConfigured
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = presentingViewController() else {
            throw AuthError.googleTokenMissing
        }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.googleTokenMissing
        }
        return (idToken, result.user.accessToken.tokenString)
    }

    /// Hands the Google account back, so a deleted user stops seeing StepOne
    /// in their third-party app list. Best effort, like Apple's revocation.
    @MainActor
    static func disconnect() async {
        _ = try? await GIDSignIn.sharedInstance.disconnect()
    }

    /// True when the user backed out rather than something failing.
    static func isCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == kGIDSignInErrorDomain
            && nsError.code == GIDSignInError.canceled.rawValue
    }

    @MainActor
    private static func presentingViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard let root = scene?.keyWindow?.rootViewController else { return nil }

        // Google presents modally, so it has to be given whatever is already
        // on top rather than the root itself.
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
