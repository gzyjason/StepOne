//
//  SettingsScreens.swift
//  StepOne
//
//  Settings and everything reachable from it: account (with the signed-out
//  register/login flow), preferences, language, notifications, help, and the
//  change name / email / password journeys.
//

import SwiftUI

/// Shared chrome for every pushed screen: ambient wash, header, scroll body.
private struct SettingsPage<Content: View>: View {
    let theme: StepOneTheme
    let backLabel: String
    let title: String
    var subtitle: String?
    var blobs: [AmbientBackground.Blob] = AmbientBackground.Blob.topLeft
    let onBack: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            theme.screenBg.ignoresSafeArea()
            AmbientBackground(theme: theme, spots: blobs)
            VStack(spacing: 0) {
                ScreenHeader(backLabel: backLabel, title: title, subtitle: subtitle, theme: theme, onBack: onBack)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        content()
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 44)
                }
            }
        }
    }
}

// MARK: - Settings

struct SettingsScreen: View {
    @Bindable var store: StepOneStore
    private var theme: StepOneTheme { store.theme }

    var body: some View {
        SettingsPage(
            theme: theme,
            backLabel: store.S["home"],
            title: store.S["settings"],
            blobs: AmbientBackground.Blob.settings,
            onBack: { store.screen = .home }
        ) {
            VStack(spacing: 0) {
                Button { store.screen = .account } label: {
                    SettingsRow(title: store.S["account"], systemIcon: "person", theme: theme) {
                        Chevron(theme: theme)
                    }
                }
                .buttonStyle(RowPressStyle())
            }
            .glassCard(theme)

            VStack(spacing: 0) {
                Button { store.screen = .preferences } label: {
                    SettingsRow(title: store.S["preferences"], systemIcon: "slider.horizontal.3", theme: theme) {
                        Chevron(theme: theme)
                    }
                }
                .buttonStyle(RowPressStyle())
                Separator(theme: theme, inset: 47)
                Button { store.screen = .notifications } label: {
                    SettingsRow(title: store.S["notifications"], systemIcon: "bell", theme: theme) {
                        Chevron(theme: theme)
                    }
                }
                .buttonStyle(RowPressStyle())
                Separator(theme: theme, inset: 47)
                Button { store.screen = .language } label: {
                    SettingsRow(
                        title: store.S["language"],
                        systemIcon: "globe",
                        detail: currentLanguageName,
                        theme: theme
                    ) { Chevron(theme: theme) }
                }
                .buttonStyle(RowPressStyle())
            }
            .glassCard(theme)

            VStack(spacing: 0) {
                Button { store.screen = .help } label: {
                    SettingsRow(title: store.S["help"], systemIcon: "questionmark.circle", theme: theme) {
                        Chevron(theme: theme)
                    }
                }
                .buttonStyle(RowPressStyle())
            }
            .glassCard(theme)
        }
    }

    private var currentLanguageName: String {
        store.content.languages.first { $0.id == store.lang }?.native ?? "English"
    }
}

// MARK: - Account

struct AccountScreen: View {
    @Bindable var store: StepOneStore
    private var theme: StepOneTheme { store.theme }

    var body: some View {
        SettingsPage(
            theme: theme,
            backLabel: store.S["settings"],
            title: store.S["account"],
            blobs: AmbientBackground.Blob.topRight,
            onBack: { store.screen = .settings }
        ) {
            if store.isRegistered {
                profileSection
                securitySection
                dangerSection
            } else {
                RegistrationPanel(store: store)
            }
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel(text: store.S["profile"], theme: theme)
            VStack(spacing: 0) {
                SettingsRow(title: store.S["name"], detail: store.displayName, theme: theme) { EmptyView() }
                Separator(theme: theme)
                SettingsRow(title: store.S["email"], detail: store.displayEmail, theme: theme) { EmptyView() }
            }
            .glassCard(theme)

            HStack(spacing: 10) {
                secondaryButton(store.S["changeName"]) {
                    store.nameDraft = store.displayName
                    store.nameDiscardOpen = false
                    store.nameError = ""
                    store.screen = .changeName
                }
                // Changing the address means reauthenticating with a password
                // and mailing a link — neither of which an Apple account has.
                if store.usesPassword {
                    secondaryButton(store.S["changeEmail"]) {
                        store.emailStage = .form
                        store.emailNew = ""
                        store.emailPassword = ""
                        store.emailErrNew = ""
                        store.emailErrPassword = ""
                        store.resendSeconds = 0
                        store.screen = .changeEmail
                    }
                }
            }
            .padding(.top, 4)

            if !store.usesPassword {
                Text(store.S["ssoEmail"])
                    .font(.system(size: 12))
                    .foregroundStyle(theme.hint)
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
            }
        }
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .glass(theme, shape: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressStyle(scale: 0.97))
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel(text: store.S["security"], theme: theme)
            VStack(spacing: 0) {
                // An Apple account has no password of ours to update.
                if store.usesPassword {
                    Button {
                        store.pwCurrent = ""
                        store.pwNew = ""
                        store.pwConfirm = ""
                        store.pwErrCurrent = ""
                        store.pwErrNew = ""
                        store.pwErrConfirm = ""
                        store.screen = .password
                    } label: {
                        SettingsRow(title: store.S["updatePassword"], theme: theme) { Chevron(theme: theme) }
                    }
                    .buttonStyle(RowPressStyle())

                    Separator(theme: theme)
                }

                Button { store.logOut() } label: {
                    SettingsRow(title: store.S["authLogout"], theme: theme) {
                        if store.busy == .logout { Spinner(color: theme.textPrimary, size: 16) }
                    }
                    .opacity(store.busy == .logout ? 0.35 : 1)
                }
                .buttonStyle(RowPressStyle())
                .disabled(store.busy != nil)
            }
            .glassCard(theme)
        }
    }

    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                withAnimation(.easeOut(duration: 0.24)) { store.dangerOpen.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text(store.S["dangerZone"].uppercased())
                        .font(.system(size: 12.5, weight: .semibold))
                        .kerning(0.6)
                        .foregroundStyle(theme.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.chevron)
                        .rotationEffect(.degrees(store.dangerOpen ? 90 : 0))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle(scale: 1))

            if store.dangerOpen {
                VStack(alignment: .leading, spacing: 7) {
                    // Firebase refuses to delete on a stale login, so proof of
                    // identity is collected first — a password, or a fresh
                    // Apple authorisation whose code also revokes the token.
                    if store.usesPassword {
                        GlassField(
                            placeholder: store.S["currentPw"],
                            text: $store.deletePassword,
                            theme: theme,
                            secure: true
                        )
                        FieldError(message: store.deleteError, theme: theme)

                        Button { store.alertOpen = true } label: {
                            HStack {
                                Text(store.S["deleteAccount"])
                                    .font(.system(size: 15.5, weight: .medium))
                                    .foregroundStyle(theme.destructive)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(RowPressStyle())
                        .glassCard(theme)
                    } else {
                        Text(store.reauthPrompt)
                            .font(.system(size: 12.5))
                            .foregroundStyle(theme.textSecondary)
                            .lineSpacing(2)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 2)

                        // Whichever provider made the account is the only one
                        // that can prove identity for it.
                        if store.usesApple {
                            AppleReauthButton(store: store)
                        } else {
                            GoogleReauthButton(store: store)
                        }
                        FieldError(message: store.deleteError, theme: theme)
                    }

                    Text(store.S["deleteAccountBody"])
                        .font(.system(size: 12))
                        .foregroundStyle(theme.hint)
                        .lineSpacing(2)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Registration (signed out)

private struct RegistrationPanel: View {
    @Bindable var store: StepOneStore
    private var theme: StepOneTheme { store.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch store.rgStage {
            case .form: registerForm
            case .login: loginForm
            case .verify: verifyPanel
            }
        }
        .padding(.horizontal, 4)
        // The background poll flips this once the link is opened, which swaps
        // this whole panel out for the signed-in account view.
        .onChange(of: store.auth.isSignedIn) { _, signedIn in
            if signedIn, store.rgStage == .verify { store.completeRegistration() }
        }
    }

    private var registerForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(store.S["authRegisterTitle"])
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .lineSpacing(4)
                .padding(.horizontal, 6)

            VStack(alignment: .leading, spacing: 6) {
                GlassField(placeholder: store.S["authEmail"], text: $store.rgEmail, theme: theme, keyboard: .emailAddress)
                FieldError(message: store.rgErrEmail, theme: theme)
            }

            VStack(alignment: .leading, spacing: 6) {
                GlassField(placeholder: store.S["authPassword"], text: $store.rgPw, theme: theme, secure: true)
                FieldError(message: store.rgErrPw, theme: theme)
                Text(store.S["authPasswordHint"])
                    .font(.system(size: 12))
                    .foregroundStyle(theme.hint)
                    .padding(.horizontal, 6)
            }

            VStack(alignment: .leading, spacing: 6) {
                GlassField(placeholder: store.S["confirmPw"], text: $store.rgPw2, theme: theme, secure: true)
                FieldError(message: store.rgErrPw2, theme: theme)
            }

            FieldError(message: store.rgErrGeneral, theme: theme)

            PrimaryButton(title: store.S["authRegister"], theme: theme, busy: store.busy == .rgRegister) {
                store.rgRegister()
            }
            .padding(.top, 4)

            OrDivider(theme: theme, label: store.S["orDivider"])

            AppleSignInButton(store: store)
            GoogleAuthButton(store: store)
            FieldError(message: store.federatedError, theme: theme)

            linkButton(store.S["obLoginExisting"]) {
                store.rgStage = .login
                store.rgLoginError = ""
                store.rgLoginEmptyEmail = false
                store.rgLoginEmptyPw = false
            }
        }
    }

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(store.S["authLoginTitle"])
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 6)

            VStack(alignment: .leading, spacing: 6) {
                GlassField(placeholder: store.S["authEmail"], text: $store.rgLoginEmail, theme: theme, keyboard: .emailAddress)
                FieldError(message: store.rgLoginEmptyEmail ? store.S["errEnterEmail"] : "", theme: theme)
            }

            VStack(alignment: .leading, spacing: 6) {
                GlassField(placeholder: store.S["authPassword"], text: $store.rgLoginPw, theme: theme, secure: true)
                FieldError(message: loginPasswordError, theme: theme)
            }

            PrimaryButton(title: store.S["authLogin"], theme: theme, busy: store.busy == .rgLogin) {
                store.rgLogin()
            }
            .padding(.top, 4)

            OrDivider(theme: theme, label: store.S["orDivider"])

            AppleSignInButton(store: store)
            GoogleAuthButton(store: store)
            FieldError(message: store.federatedError, theme: theme)

            linkButton(store.S["authRegisterNew"]) {
                store.rgStage = .form
                store.rgErrGeneral = ""
                store.rgLoginError = ""
            }
        }
    }

    private var verifyPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(store.S("authLinkSentPanel", "e", verifyTarget))
                .font(.system(size: 14.5))
                .foregroundStyle(theme.textSecondary)
                .lineSpacing(3)
                .padding(.horizontal, 6)

            FieldError(message: store.rgErrVerify, theme: theme)

            PrimaryButton(title: store.S["authOpenedLink"], theme: theme, busy: store.busy == .rgVerify) {
                store.rgCheckVerification()
            }
            .padding(.top, 4)

            ResendButton(store: store, action: .resend)

            Button {
                store.rgStage = .form
                store.rgErrVerify = ""
            } label: {
                Text(store.S["authEditEmail"])
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(PressStyle(scale: 1))
        }
    }

    /// The two password-side failures are mutually exclusive — `rgLogin()`
    /// clears one before setting the other — so they share a single reserved row.
    private var loginPasswordError: String {
        if store.rgLoginEmptyPw { return store.S["errEnterPassword"] }
        return store.rgLoginError
    }

    private var verifyTarget: String {
        let trimmed = store.rgEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "your email address" : trimmed
    }

    private func linkButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
        }
        .buttonStyle(PressStyle(scale: 1))
    }
}

// MARK: - Preferences

struct PreferencesScreen: View {
    @Bindable var store: StepOneStore
    private var theme: StepOneTheme { store.theme }

    var body: some View {
        SettingsPage(
            theme: theme,
            backLabel: store.S["settings"],
            title: store.S["preferences"],
            blobs: AmbientBackground.Blob.topRight,
            onBack: { store.screen = .settings }
        ) {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        store.toggleNight()
                    }
                } label: {
                    SettingsRow(title: store.S["nightMode"], systemIcon: "moon", theme: theme) {
                        StepSwitch(isOn: store.isNight)
                    }
                }
                .buttonStyle(RowPressStyle())

                Separator(theme: theme, inset: 47)

                SettingsRow(title: store.S["units"], systemIcon: "chart.line.uptrend.xyaxis", theme: theme) {
                    unitPicker
                }
            }
            .glassCard(theme)
        }
    }

    private var unitPicker: some View {
        ZStack(alignment: store.unit == .feet ? .leading : .trailing) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.segBg)
                .frame(width: 108, height: 32)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.segThumb)
                .frame(width: 52, height: 28)
                .shadow(color: .black.opacity(0.16), radius: 2, x: 0, y: 1)
                .padding(2)
            HStack(spacing: 0) {
                unitOption("ft", value: .feet)
                unitOption("m", value: .meters)
            }
            .frame(width: 108, height: 32)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: store.unit)
    }

    private func unitOption(_ title: String, value: DistanceUnit) -> some View {
        Button { store.unit = value } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle(scale: 1))
    }
}

// MARK: - Language

struct LanguageScreen: View {
    @Bindable var store: StepOneStore
    private var theme: StepOneTheme { store.theme }

    var body: some View {
        SettingsPage(
            theme: theme,
            backLabel: store.S["settings"],
            title: store.S["language"],
            blobs: AmbientBackground.Blob.bottomLeft,
            onBack: { store.screen = .settings }
        ) {
            VStack(spacing: 0) {
                ForEach(Array(store.content.languages.enumerated()), id: \.element.id) { i, language in
                    if i > 0 { Separator(theme: theme) }
                    Button {
                        store.lang = language.id
                        store.index = 0
                    } label: {
                        HStack(spacing: 12) {
                            Text(language.native)
                                .font(.system(size: 15.5))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(theme.accentCheck)
                                .opacity(store.lang == language.id ? 1 : 0)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(RowPressStyle())
                }
            }
            .glassCard(theme)

            Text(store.S["aiTranslated"])
                .font(.system(size: 12))
                .foregroundStyle(theme.hint)
                .lineSpacing(2)
                .padding(.horizontal, 16)
                .padding(.top, -12)
        }
    }
}

// MARK: - Notifications

struct NotificationsScreen: View {
    @Bindable var store: StepOneStore
    private var theme: StepOneTheme { store.theme }

    var body: some View {
        SettingsPage(
            theme: theme,
            backLabel: store.S["settings"],
            title: store.S["notifications"],
            blobs: AmbientBackground.Blob.topLeft,
            onBack: { store.screen = .settings }
        ) {
            VStack(spacing: 0) {
                ForEach(Array(ReminderSlot.allCases.enumerated()), id: \.element) { index, slot in
                    if index > 0 { Separator(theme: theme) }
                    Button {
                        store.activeReminder = slot
                        store.screen = .reminder
                    } label: {
                        SettingsRow(
                            title: store.S[slot.titleKey],
                            detail: store.reminderDetail(slot),
                            theme: theme
                        ) { Chevron(theme: theme) }
                    }
                    .buttonStyle(RowPressStyle())
                }
            }
            .glassCard(theme)

            Text(store.S["remindersHint"])
                .font(.system(size: 12))
                .foregroundStyle(theme.hint)
                .lineSpacing(2)
                .padding(.horizontal, 16)
                .padding(.top, -12)

            if store.notificationsDenied { deniedNotice }
        }
        // The system is the source of truth, so what is on screen is whatever
        // is genuinely scheduled — including from an earlier launch.
        .task { await store.refreshReminders() }
    }

    /// Nothing the app can do from here: only iOS can grant this back.
    private var deniedNotice: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.S["notifDenied"])
                .font(.system(size: 13))
                .foregroundStyle(theme.textSecondary)
                .lineSpacing(2)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(store.S["openSettings"])
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(PressStyle(scale: 1))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(theme)
    }
}

// MARK: - Reminder detail

struct ReminderDetailScreen: View {
    @Bindable var store: StepOneStore
    private var theme: StepOneTheme { store.theme }
    private var slot: ReminderSlot { store.activeReminder }

    var body: some View {
        SettingsPage(
            theme: theme,
            backLabel: store.S["notifications"],
            title: store.S[slot.titleKey],
            blobs: AmbientBackground.Blob.topLeft,
            onBack: { store.screen = .notifications }
        ) {
            VStack(spacing: 0) {
                Button { store.toggleReminder(slot) } label: {
                    SettingsRow(title: store.S["reminder"], theme: theme) {
                        StepSwitch(isOn: store.reminder(slot).isOn)
                    }
                }
                .buttonStyle(RowPressStyle())
            }
            .glassCard(theme)

            // The picker is only meaningful once there is something to time,
            // so it arrives with the switch rather than sitting there greyed.
            if store.reminder(slot).isOn {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { store.reminder(slot).time },
                        set: { store.setReminderTime(slot, to: $0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .glassCard(theme)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if store.notificationsDenied {
                Text(store.S["notifDenied"])
                    .font(.system(size: 12.5))
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(2)
                    .padding(.horizontal, 16)
            }
        }
        .animation(.easeOut(duration: 0.28), value: store.reminder(slot).isOn)
    }
}

// MARK: - Help

struct HelpScreen: View {
    @Bindable var store: StepOneStore
    private var theme: StepOneTheme { store.theme }

    var body: some View {
        SettingsPage(
            theme: theme,
            backLabel: store.S["settings"],
            title: store.S["help"],
            blobs: AmbientBackground.Blob.bottomRight,
            onBack: { store.screen = .settings }
        ) {
            VStack(spacing: 0) {
                SettingsRow(title: store.S["faq"], theme: theme) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.chevron)
                }
                Separator(theme: theme)
                SettingsRow(title: store.S["tos"], theme: theme) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.chevron)
                }
                Separator(theme: theme)
                SettingsRow(
                    title: store.S["appInfo"],
                    detail: "StepOne · \(store.S["version"]) \(store.content.version)",
                    theme: theme
                ) { EmptyView() }
            }
            .glassCard(theme)
        }
    }
}

// MARK: - Change name

struct ChangeNameScreen: View {
    @Bindable var store: StepOneStore
    private var theme: StepOneTheme { store.theme }

    var body: some View {
        SettingsPage(
            theme: theme,
            backLabel: store.S["account"],
            title: store.S["changeName"],
            onBack: { store.nameBack() }
        ) {
            SectionLabel(text: store.S["name"], theme: theme)
            GlassField(
                placeholder: store.S["newName"],
                text: Binding(
                    get: { store.nameDraft ?? store.displayName },
                    set: { store.nameDraft = $0 }
                ),
                theme: theme,
                height: 54
            )
            FieldError(message: store.nameError, theme: theme)
            PrimaryButton(
                title: store.S["confirm"],
                theme: theme,
                busy: store.busy == .changeName,
                height: 52,
                radius: 16
            ) {
                store.confirmName()
            }
        }
    }
}

// MARK: - Change email

struct ChangeEmailScreen: View {
    @Bindable var store: StepOneStore
    private var theme: StepOneTheme { store.theme }

    var body: some View {
        SettingsPage(
            theme: theme,
            backLabel: store.S["account"],
            title: store.S["changeEmail"],
            onBack: { store.screen = .account }
        ) {
            switch store.emailStage {
            case .form:
                Text(store.S["emailIntro"])
                    .font(.system(size: 14.5))
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 6)

                HStack {
                    Text(store.displayEmail)
                        .font(.system(size: 16))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .frame(height: 54)
                .glass(theme, shape: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    GlassField(
                        placeholder: store.S["newEmail"],
                        text: $store.emailNew,
                        theme: theme,
                        keyboard: .emailAddress,
                        height: 54
                    )
                    FieldError(message: store.emailErrNew, theme: theme)
                }

                VStack(alignment: .leading, spacing: 6) {
                    GlassField(
                        placeholder: store.S["currentPw"],
                        text: $store.emailPassword,
                        theme: theme,
                        secure: true,
                        height: 54
                    )
                    FieldError(message: store.emailErrPassword, theme: theme)
                }

                PrimaryButton(
                    title: store.S["sendVerify"],
                    theme: theme,
                    busy: store.busy == .changeEmail,
                    height: 52,
                    radius: 16
                ) {
                    store.sendEmailChange()
                }

            case .sent:
                Text(store.S("emailLinkSent", "e", store.emailNew.trimmingCharacters(in: .whitespacesAndNewlines)))
                    .font(.system(size: 14.5))
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 6)

                // No resend here on purpose: re-sending would mean
                // reauthenticating again, and the password has been cleared.
                // Going back and refilling the form is the honest path.
                PrimaryButton(title: store.S["done"], theme: theme, height: 52, radius: 16) {
                    store.screen = .account
                    store.emailStage = .form
                }
            }
        }
    }
}

// MARK: - Update password

struct PasswordScreen: View {
    @Bindable var store: StepOneStore
    private var theme: StepOneTheme { store.theme }

    var body: some View {
        SettingsPage(
            theme: theme,
            backLabel: store.S["account"],
            title: store.S["updatePassword"],
            onBack: { store.screen = .account }
        ) {
            Text(store.S["pwIntro"])
                .font(.system(size: 14.5))
                .foregroundStyle(theme.textSecondary)
                .lineSpacing(3)
                .padding(.horizontal, 6)

            VStack(alignment: .leading, spacing: 6) {
                GlassField(
                    placeholder: store.S["currentPw"],
                    text: $store.pwCurrent,
                    theme: theme,
                    secure: true,
                    height: 54
                )
                FieldError(message: store.pwErrCurrent, theme: theme)
            }

            VStack(alignment: .leading, spacing: 6) {
                VStack(spacing: 0) {
                    SecureField(store.S["newPw"], text: $store.pwNew)
                        .font(.system(size: 16))
                        .foregroundStyle(theme.textPrimary)
                        .padding(.horizontal, 18)
                        .frame(height: 54)
                    Separator(theme: theme, inset: 18)
                    SecureField(store.S["confirmPw"], text: $store.pwConfirm)
                        .font(.system(size: 16))
                        .foregroundStyle(theme.textPrimary)
                        .padding(.horizontal, 18)
                        .frame(height: 54)
                }
                .glass(theme, shape: RoundedRectangle(cornerRadius: 20, style: .continuous))

                FieldError(message: store.pwErrNew, theme: theme)
                FieldError(message: store.pwErrConfirm, theme: theme)
            }

            PrimaryButton(
                title: store.S["confirm"],
                theme: theme,
                busy: store.busy == .changePassword,
                height: 52,
                radius: 16
            ) {
                store.confirmPassword()
            }
        }
    }
}

private struct ResendButton: View {
    @Bindable var store: StepOneStore
    /// Which slot the spinner belongs to, so two resend buttons on different
    /// screens never both light up.
    let action: BusyAction

    var body: some View {
        let theme = store.theme
        Button {
            store.resendVerification(action)
        } label: {
            ZStack {
                Text(store.resendLabel)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .opacity(store.busy == action ? 0 : 1)
                if store.busy == action { Spinner(color: theme.accent, size: 16) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .glass(theme, shape: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(store.resendSeconds == 0 ? 1 : 0.4)
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .disabled(store.resendSeconds > 0)
    }
}
