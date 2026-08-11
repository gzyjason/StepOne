//
//  AuthUser.swift
//  StepOne
//
//  A value snapshot of the signed-in account. Everything above the auth layer
//  works with this rather than FirebaseAuth's `User`, which is a live reference
//  whose properties change underneath you on the next reload.
//

import Foundation

struct AuthUser: Equatable, Identifiable, Sendable {
    /// The Firebase `uid`. Stable across email changes, so this — never the
    /// address — is what any per-user records should be keyed on.
    let id: String
    let email: String?
    let displayName: String?
    let isEmailVerified: Bool
    /// Firebase's provider identifiers — "password", "apple.com", and so on.
    let providerIDs: [String]

    /// Only a password account goes through email verification. A federated
    /// provider has already vouched for the address it hands over, and there
    /// is no inbox for us to send a link to in the private-relay case.
    var usesPassword: Bool { providerIDs.contains("password") }
    var usesApple: Bool { providerIDs.contains("apple.com") }
    var usesGoogle: Bool { providerIDs.contains("google.com") }
}
