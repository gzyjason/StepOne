//
//  AppleNonce.swift
//  StepOne
//
//  The replay guard for Sign in with Apple. Apple signs a *hash* of the nonce
//  into the identity token; Firebase is handed the raw value and checks the
//  two match. Because they travel by different routes, an intercepted token
//  cannot be replayed on its own.
//

import CryptoKit
import Foundation

enum AppleNonce {
    /// `hashed` goes on the Apple request. `raw` is held until the identity
    /// token comes back, then handed to Firebase alongside it.
    static func make(length: Int = 32) -> (raw: String, hashed: String) {
        let raw = randomString(length: length)
        return (raw, sha256(raw))
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func randomString(length: Int) -> String {
        // 64 characters, so bytes of 64 and over are redrawn rather than
        // folded — folding would make the low characters twice as likely.
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        while result.count < length {
            var byte: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
            guard status == errSecSuccess else {
                // Only fails if the system RNG is unavailable, which would
                // make the whole exchange unsafe. Stopping beats quietly
                // falling back to a weaker source.
                fatalError("Could not generate a secure nonce (SecRandomCopyBytes: \(status))")
            }
            if byte < charset.count { result.append(charset[Int(byte)]) }
        }
        return result
    }
}
