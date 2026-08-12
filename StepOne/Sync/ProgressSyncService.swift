//
//  ProgressSyncService.swift
//  StepOne
//
//  The Firestore boundary for a signed-in user's Trip progress: distance,
//  completed count, chosen categories and discarded Trips. Nothing above
//  this file imports FirebaseFirestore.
//

import FirebaseCore
import FirebaseFirestore
import Foundation

/// What actually crosses the wire. Local-only UI state — drag offsets,
/// disclosure toggles, per-category trip ordering — never leaves the device;
/// this is exactly the set the privacy policy describes as synced.
struct RemoteProgress: Equatable {
    var meters: Int
    var done: Int
    var journeyBase: Int
    var chosen: [String]
    var discarded: [DiscardRef]
}

protocol ProgressSyncing {
    /// `nil` means there is nothing saved yet for this account, not a failure.
    func fetch(uid: String) async throws -> RemoteProgress?
    func save(_ progress: RemoteProgress, uid: String) async throws
    /// Called when the account itself is deleted, so progress never outlives
    /// the account it belongs to.
    func delete(uid: String) async throws
}

struct FirestoreProgressSync: ProgressSyncing {
    private static let collection = "userProgress"

    /// Resolved per call, the way `FirebaseAuthService` resolves `Auth.auth()`
    /// lazily. Firestore traps if called before `FirebaseApp.configure()` has
    /// run, and a checkout with no `GoogleService-Info.plist` never configures
    /// at all — so every entry point below checks `FirebaseApp.app()` first
    /// instead of touching this eagerly.
    private var db: Firestore { Firestore.firestore() }

    func fetch(uid: String) async throws -> RemoteProgress? {
        guard FirebaseApp.app() != nil else { return nil }
        let snapshot = try await db.collection(Self.collection).document(uid).getDocument()
        guard snapshot.exists, let data = snapshot.data() else { return nil }

        let discardedRaw = data["discarded"] as? [[String: Any]] ?? []
        let discarded = discardedRaw.compactMap { entry -> DiscardRef? in
            guard let category = entry["category"] as? String, let index = entry["index"] as? Int else {
                return nil
            }
            return DiscardRef(category: category, index: index)
        }

        return RemoteProgress(
            meters: data["meters"] as? Int ?? 0,
            done: data["done"] as? Int ?? 0,
            journeyBase: data["journeyBase"] as? Int ?? 0,
            chosen: data["chosen"] as? [String] ?? [],
            discarded: discarded
        )
    }

    func save(_ progress: RemoteProgress, uid: String) async throws {
        guard FirebaseApp.app() != nil else { return }
        let payload: [String: Any] = [
            "meters": progress.meters,
            "done": progress.done,
            "journeyBase": progress.journeyBase,
            "chosen": progress.chosen,
            "discarded": progress.discarded.map { ["category": $0.category, "index": $0.index] },
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        try await db.collection(Self.collection).document(uid).setData(payload)
    }

    func delete(uid: String) async throws {
        guard FirebaseApp.app() != nil else { return }
        try await db.collection(Self.collection).document(uid).delete()
    }
}
