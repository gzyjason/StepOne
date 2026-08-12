//
//  LocalStore.swift
//  StepOne
//
//  On-device persistence for the two things Firebase does not cover: whether
//  onboarding has already run on this device, and a guest's Trip progress,
//  which has no account to live in Firestore under.
//

import Foundation

enum LocalStore {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let onboardingDone = "onboardingDone"
        static let guestSnapshot = "guestSnapshot"
    }

    /// Set once onboarding finishes, however it finished — skipped into guest
    /// mode or completed with a signed-in account. Either way there is no
    /// reason to replay the intro on the next launch: a signed-in Firebase
    /// session already carries its own identity, and a guest's data is
    /// restored from `guestSnapshot` below.
    static var onboardingDone: Bool {
        get { defaults.bool(forKey: Key.onboardingDone) }
        set { defaults.set(newValue, forKey: Key.onboardingDone) }
    }

    /// `nil` once there is nothing local worth restoring — no guest has
    /// finished onboarding on this device yet, or their data has since been
    /// adopted by a signed-in account and Firestore took over as the source
    /// of truth.
    static var guestSnapshot: GuestSnapshot? {
        get {
            guard let data = defaults.data(forKey: Key.guestSnapshot) else { return nil }
            return try? JSONDecoder().decode(GuestSnapshot.self, from: data)
        }
        set {
            guard let newValue else {
                defaults.removeObject(forKey: Key.guestSnapshot)
                return
            }
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.guestSnapshot)
        }
    }
}

/// A guest's Trip progress, shaped like `RemoteProgress` plus the name a
/// signed-in account would otherwise carry on `AuthUser.displayName`.
struct GuestSnapshot: Codable, Equatable {
    var name: String?
    var meters: Int
    var done: Int
    var journeyBase: Int
    var chosen: [String]
    var discarded: [DiscardRef]
}
