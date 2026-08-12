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
            // Notifications stays mounted under its detail page, so going
            // back reveals it already in place.
            slideIn(isPresented: store.screen == .notifications || store.screen == .reminder) {
                NotificationsScreen(store: store)
            }
            slideIn(isPresented: store.screen == .reminder) {
                ReminderDetailScreen(store: store)
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
        case .settings, .account, .preferences, .notifications, .reminder, .help, .language,
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

    /// Where a screen waits when it is not presented: just past the right
    /// edge. The distance matters — the slide has a fixed duration, so a
    /// wrong width would change how fast the panel appears to travel.
    ///
    /// `UIScreen.main` is deprecated; the replacement is the screen belonging
    /// to the scene actually on display, which is also correct on iPad where
    /// there may be more than one.
    private var offscreenX: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        // Only reachable before a scene has connected, where any value wide
        // enough to sit off-screen will do.
        return (scene?.screen.bounds.width ?? 1024) * 1.03
    }

    @ViewBuilder
    private func slideIn<Content: View>(isPresented: Bool, @ViewBuilder content: () -> Content) -> some View {
        content()
            .offset(x: isPresented ? 0 : offscreenX)
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
                    title: store.S["deleteTitle"],
                    message: store.S["deleteBody"],
                    cancelTitle: store.S["cancel"],
                    confirmTitle: store.S["deleteConfirm"],
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
