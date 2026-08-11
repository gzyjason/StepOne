//
//  StepOneApp.swift
//  StepOne
//
//  Created by Jason Gao on 7/9/26.
//

import FirebaseCore
import SwiftUI

@main
struct StepOneApp: App {
    init() {
        // No `GoogleService-Info.plist` is checked in, and `configure()` traps
        // without one. Guarding it means the app still runs on the demo flows
        // until the real plist is dropped into the StepOne folder, at which
        // point Firebase switches itself on.
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            // The session is owned by StepOneStore, which builds and starts it
            // — by which point `configure()` above has already run.
            ContentView()
        }
    }
}
