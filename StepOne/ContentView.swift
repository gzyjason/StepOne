//
//  ContentView.swift
//  StepOne
//
//  Created by Jason Gao on 7/9/26.
//
//  Root router. Home sits at the base and every other screen slides in from
//  the right over it, matching the design's translateX layering.
//

import SwiftUI

struct ContentView: View {
    @State private var store = StepOneStore()

    /// The device's setting. Read here rather than in the store because only
    /// a view can see it — and read *above* the override below, so what lands
    /// here is the system value and not the app's own answer fed back.
    @Environment(\.colorScheme) private var systemScheme

    private var theme: StepOneTheme { store.theme }

    var body: some View {
        ZStack {
            theme.screenBg.ignoresSafeArea()

            HomeScreen(store: store)

            // Settings stack — Settings is the parent of the next four.
            slideIn(isPresented: store.screen != .home && isSettingsFamily) {
                SettingsScreen(store: store)
            }
            slideIn(isPresented: store.screen == .account || isAccountChild) {
                AccountScreen(store: store)
            }
            slideIn(isPresented: store.screen == .preferences) {
                PreferencesScreen(store: store)
            }
            slideIn(isPresented: store.screen == .notifications) {
                NotificationsScreen(store: store)
            }
            slideIn(isPresented: store.screen == .help) {
                HelpScreen(store: store)
            }
            slideIn(isPresented: store.screen == .language) {
                LanguageScreen(store: store)
            }

            // Account children
            slideIn(isPresented: store.screen == .changeName) {
                ChangeNameScreen(store: store)
            }
            slideIn(isPresented: store.screen == .changeEmail) {
                ChangeEmailScreen(store: store)
            }
            slideIn(isPresented: store.screen == .password) {
                PasswordScreen(store: store)
            }

            // Reached from the Home menu / Your Journey button
            slideIn(isPresented: store.screen == .tripTypes) {
                TripTypesScreen(store: store)
            }
            slideIn(isPresented: store.screen == .discarded) {
                DiscardedScreen(store: store)
            }
            slideIn(isPresented: store.screen == .journey) {
                JourneyScreen(store: store)
            }

            alerts

            if !store.onboarding.done {
                OnboardingScreen(store: store)
                    .transition(.opacity)
                    .zIndex(60)
            }
        }
        .environment(\.stepTheme, theme)
        .environment(\.colorScheme, store.isNight ? .dark : .light)
        .animation(.easeInOut(duration: 0.4), value: store.isNight)
        .onChange(of: systemScheme, initial: true) { _, scheme in
            store.systemIsNight = scheme == .dark
        }
        .animation(.easeOut(duration: 0.45), value: store.onboarding.done)
    }

    /// Settings and the screens that sit on top of it all keep Settings
    /// mounted underneath, so going back reveals it already in place.
    private var isSettingsFamily: Bool {
        switch store.screen {
        case .settings, .account, .preferences, .notifications, .help, .language,
             .changeName, .changeEmail, .password:
            return true
        default:
            return false
        }
    }

    private var isAccountChild: Bool {
        switch store.screen {
        case .changeName, .changeEmail, .password: return true
        default: return false
        }
    }

    @ViewBuilder
    private func slideIn<Content: View>(isPresented: Bool, @ViewBuilder content: () -> Content) -> some View {
        content()
            .offset(x: isPresented ? 0 : UIScreen.main.bounds.width * 1.03)
            .animation(.timingCurve(0.32, 0.72, 0.28, 1, duration: 0.42), value: isPresented)
            .allowsHitTesting(isPresented)
    }

    private var alerts: some View {
        ZStack {
            // Unsaved-name confirmation
            AlertOverlay(isPresented: store.nameDiscardOpen) {
                store.nameDiscardOpen = false
            } content: {
                StepAlert(
                    title: store.S["discardTitle"],
                    message: store.S["discardBody"],
                    cancelTitle: store.S["keepEditing"],
                    confirmTitle: store.S["discard"],
                    theme: theme,
                    onCancel: { store.nameDiscardOpen = false },
                    onConfirm: {
                        store.nameDiscardOpen = false
                        store.screen = .account
                    }
                )
            }
            .zIndex(42)

            // Delete account
            AlertOverlay(isPresented: store.alertOpen) {
                if store.busy == nil { store.alertOpen = false }
            } content: {
                StepAlert(
                    title: "Delete your account?",
                    message: "This permanently deletes your Firebase account, your name and all of Your Journey. This cannot be undone.",
                    cancelTitle: store.S["cancel"],
                    confirmTitle: "Delete",
                    theme: theme,
                    confirmBusy: store.busy == .delete,
                    onCancel: { if store.busy == nil { store.alertOpen = false } },
                    onConfirm: { store.deleteAccount() }
                )
            }
            .zIndex(40)
        }
    }
}

#Preview {
    ContentView()
}
