//
//  AuthError.swift
//  StepOne
//
//  Firebase's NSErrors narrowed to the outcomes the forms actually branch on,
//  carrying the copy those forms already use.
//

import FirebaseAuth
import Foundation

enum AuthError: Error, Equatable {
    case invalidEmail
    case emailAlreadyInUse
    case weakPassword
    /// Wrong password, unknown address, or a malformed credential. Projects
    /// with email enumeration protection on — the default for new ones —
    /// deliberately collapse all three into one code, so the app must not try
    /// to tell them apart either.
    case invalidCredentials
    case userDisabled
    /// Email/password sign-in is switched off for the Firebase project.
    case emailSignInDisabled
    /// The change needs a fresher login than the cached token provides.
    case requiresRecentLogin
    case sessionExpired
    case notSignedIn
    /// No `GoogleService-Info.plist`, so `FirebaseApp.configure()` never ran.
    case notConfigured
    case verificationTimedOut
    case expiredActionCode
    case tooManyRequests
    case network
    case unknown(code: Int, description: String)

    /// Copy for the field-level error rows. Sentence case without a full stop,
    /// matching the strings already hard-coded in the register and log-in
    /// forms.
    var message: String {
        switch self {
        case .invalidEmail:
            return "Enter a valid email address"
        case .emailAlreadyInUse:
            return "That email address is already registered"
        case .weakPassword:
            return "Use 8 or more characters with a number and a letter"
        case .invalidCredentials:
            return "email or password is incorrect"
        case .userDisabled:
            return "This account has been disabled"
        case .emailSignInDisabled:
            return "Email sign-in is not enabled for this project"
        case .requiresRecentLogin:
            return "Log in again to confirm this change"
        case .sessionExpired:
            return "Your session has expired. Log in again"
        case .notSignedIn:
            return "You are not logged in"
        case .notConfigured:
            return "Sign-in is not set up yet"
        case .verificationTimedOut:
            return "Still waiting for your email to be verified"
        case .expiredActionCode:
            return "That link has expired. Request a new one"
        case .tooManyRequests:
            return "Too many attempts. Try again in a few minutes"
        case .network:
            return "No connection. Check your network and try again"
        case .unknown:
            return "Something went wrong. Try again"
        }
    }

    /// Whether retrying the identical request could plausibly succeed. Useful
    /// for deciding between a field error and a retry affordance.
    var isTransient: Bool {
        switch self {
        case .network, .tooManyRequests, .verificationTimedOut, .unknown:
            return true
        default:
            return false
        }
    }

    init(_ error: Error) {
        if let mapped = error as? AuthError {
            self = mapped
            return
        }

        let nsError = error as NSError
        guard nsError.domain == AuthErrors.domain,
              let code = AuthErrorCode(rawValue: nsError.code) else {
            self = .unknown(code: nsError.code, description: nsError.localizedDescription)
            return
        }

        switch code {
        case .invalidEmail, .invalidRecipientEmail, .missingEmail:
            self = .invalidEmail
        case .emailAlreadyInUse, .credentialAlreadyInUse, .accountExistsWithDifferentCredential:
            self = .emailAlreadyInUse
        case .weakPassword:
            self = .weakPassword
        case .wrongPassword, .userNotFound, .invalidCredential, .userMismatch:
            self = .invalidCredentials
        case .userDisabled:
            self = .userDisabled
        case .operationNotAllowed:
            self = .emailSignInDisabled
        case .requiresRecentLogin:
            self = .requiresRecentLogin
        case .userTokenExpired, .invalidUserToken, .sessionExpired:
            self = .sessionExpired
        case .expiredActionCode, .invalidActionCode:
            self = .expiredActionCode
        case .tooManyRequests, .quotaExceeded:
            self = .tooManyRequests
        case .networkError:
            self = .network
        default:
            self = .unknown(code: nsError.code, description: nsError.localizedDescription)
        }
    }
}
