//
//  StepOneApp.swift
//  StepOne
//
//  Created by Jason Gao on 7/9/26.
//

import FirebaseCore
import GoogleSignIn
import SwiftUI

@main
struct StepOneApp: App {
    init() {
        // `configure()` traps when the plist is missing. It is checked in, so
        // this normally always runs — the guard is for a checkout that has
        // deliberately dropped it, which then degrades to `.notConfigured`
        // errors rather than crashing on launch.
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            // The session is owned by StepOneStore, which builds and starts it
            // — by which point `configure()` above has already run.
            ContentView()
                // Google returns through the reversed-client-ID scheme
                // registered in Config/Info.plist.
                .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
        }
    }
}
