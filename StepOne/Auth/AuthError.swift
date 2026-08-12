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
    /// The address already has an account made by a different route, so the
    /// user needs to be pointed at the one they actually signed up with.
    case accountExistsWithDifferentProvider
    /// Apple returned an authorization with no identity token in it.
    case appleTokenMissing
    /// Google completed but handed back no ID token.
    case googleTokenMissing
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

    /// Key into StepOneContent's string table. The error stays a plain value
    /// and knows nothing about language; the store resolves it, since that is
    /// where the active language lives.
    var key: String {
        switch self {
        case .invalidEmail:
            return "errEmailInvalid"
        // Neither of the next two names the provider on purpose. Firebase does
        // not say which one owns the address, and with email enumeration
        // protection on there is no way to ask — "registered with Google"
        // would be a guess, wrong for a password or Apple account.
        case .emailAlreadyInUse:
            return "errEmailInUse"
        case .accountExistsWithDifferentProvider:
            return "errOtherProvider"
        case .appleTokenMissing:
            return "errAppleToken"
        case .googleTokenMissing:
            return "errGoogleToken"
        case .weakPassword:
            return "errWeakPassword"
        case .invalidCredentials:
            return "errCredentials"
        case .userDisabled:
            return "errUserDisabled"
        case .emailSignInDisabled:
            return "errEmailSignInOff"
        case .requiresRecentLogin:
            return "errRecentLogin"
        case .sessionExpired:
            return "errSessionExpired"
        case .notSignedIn:
            return "errNotSignedIn"
        case .notConfigured:
            return "errNotConfigured"
        case .verificationTimedOut:
            return "errVerifyTimeout"
        case .expiredActionCode:
            return "errActionCode"
        case .tooManyRequests:
            return "errTooMany"
        case .network:
            return "errNetwork"
        case .unknown:
            return "errUnknown"
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
        case .emailAlreadyInUse, .credentialAlreadyInUse:
            self = .emailAlreadyInUse
        case .accountExistsWithDifferentCredential:
            self = .accountExistsWithDifferentProvider
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
