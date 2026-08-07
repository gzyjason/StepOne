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
                    store.screen = .changeName
                }
                secondaryButton(store.S["changeEmail"]) {
                    store.emailStage = .intro
                    store.emailCode = ""
                    store.emailNew = ""
                    store.resendSeconds = 0
                    store.screen = .changeEmail
                }
            }
            .padding(.top, 4)
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
                Button {
                    store.pwStage = .intro
                    store.pwNew = ""
                    store.pwConfirm = ""
                    store.pwCode = ""
                    store.pwError = false
                    store.resendSeconds = 0
                    store.screen = .password
                } label: {
                    SettingsRow(title: store.S["updatePassword"], theme: theme) { Chevron(theme: theme) }
                }
                .buttonStyle(RowPressStyle())

                Separator(theme: theme)

                Button { store.logOut() } label: {
                    SettingsRow(title: "Log out", theme: theme) {
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
                    Text("Danger zone".uppercased())
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
                    Button { store.alertOpen = true } label: {
                        HStack {
                            Text("Delete account")
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

                    Text("Deleting your account permanently removes your profile and all of Your Journey.")
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
            case .code: codeForm
            }
        }
        .padding(.horizontal, 4)
    }

    private var registerForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Register an account to never lose your progress:")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .lineSpacing(4)
                .padding(.horizontal, 6)

            VStack(alignment: .leading, spacing: 6) {
                GlassField(placeholder: "Email address", text: $store.rgEmail, theme: theme, keyboard: .emailAddress)
                FieldError(message: store.rgErrEmail, theme: theme)
            }

            VStack(alignment: .leading, spacing: 6) {
                GlassField(placeholder: "Password", text: $store.rgPw, theme: theme, secure: true)
                FieldError(message: store.rgErrPw, theme: theme)
                Text("8 or more characters, numbers, and at least one letter")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.hint)
                    .padding(.horizontal, 6)
            }

            VStack(alignment: .leading, spacing: 6) {
                GlassField(placeholder: "Confirm password", text: $store.rgPw2, theme: theme, secure: true)
                FieldError(message: store.rgErrPw2, theme: theme)
            }

            PrimaryButton(title: "Register", theme: theme, busy: store.busy == .rgRegister) {
                store.rgRegister()
            }
            .padding(.top, 4)

            linkButton("Log in to existing account") {
                store.rgStage = .login
                store.rgLoginError = false
                store.rgLoginEmptyEmail = false
                store.rgLoginEmptyPw = false
            }
        }
    }

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Log in to your account:")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 6)

            VStack(alignment: .leading, spacing: 6) {
                GlassField(placeholder: "Email address", text: $store.rgLoginEmail, theme: theme, keyboard: .emailAddress)
                FieldError(message: store.rgLoginEmptyEmail ? "Enter your email address" : "", theme: theme)
            }

            VStack(alignment: .leading, spacing: 6) {
                GlassField(placeholder: "Password", text: $store.rgLoginPw, theme: theme, secure: true)
                FieldError(message: loginPasswordError, theme: theme)
            }

            PrimaryButton(title: "Log in", theme: theme, busy: store.busy == .rgLogin) {
                store.rgLogin()
            }
            .padding(.top, 4)

            linkButton("Register a new account") {
                store.rgStage = .form
                store.rgErrCode = ""
                store.rgLoginError = false
            }

            demoHint("demo account alex@example.com / stepone123")
        }
    }

    private var codeForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("A verification code has been sent to \(codeTarget).")
                .font(.system(size: 14.5))
                .foregroundStyle(theme.textSecondary)
                .lineSpacing(3)
                .padding(.horizontal, 6)

            VStack(alignment: .leading, spacing: 6) {
                GlassField(placeholder: "Verification code", text: $store.rgCode, theme: theme, keyboard: .numberPad, tracking: 2)
                FieldError(message: store.rgErrCode, theme: theme)
            }

            PrimaryButton(title: store.S["confirm"], theme: theme, busy: store.busy == .rgVerify) {
                store.rgVerify()
            }
            .padding(.top, 4)

            Button {
                store.rgStage = .form
                store.rgErrCode = ""
            } label: {
                Text("Edit email address")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(PressStyle(scale: 1))

            demoHint("demo code 123456")
        }
    }

    /// The two password-side failures are mutually exclusive — `rgLogin()`
    /// clears one before setting the other — so they share a single reserved row.
    private var loginPasswordError: String {
        if store.rgLoginEmptyPw { return "Enter your password" }
        return store.rgLoginError ? "email or password is incorrect" : ""
    }

    private var codeTarget: String {
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

    private func demoHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(theme.hint)
            .frame(maxWidth: .infinity)
            .padding(.top, -8)
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
                        store.nightOverride = !store.isNight
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
                Button { store.stepNotif.toggle() } label: {
                    SettingsRow(title: store.S["stepReminder"], theme: theme) {
                        StepSwitch(isOn: store.stepNotif)
                    }
                }
                .buttonStyle(RowPressStyle())
                Separator(theme: theme)
                Button { store.promoNotif.toggle() } label: {
                    SettingsRow(title: store.S["promo"], theme: theme) {
                        StepSwitch(isOn: store.promoNotif)
                    }
                }
                .buttonStyle(RowPressStyle())
            }
            .glassCard(theme)
        }
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
            PrimaryButton(title: store.S["confirm"], theme: theme, height: 52, radius: 16) {
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
            case .intro:
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

                PrimaryButton(title: store.S["sendVerify"], theme: theme, height: 52, radius: 16) {
                    store.emailStage = .code
                    store.emailCode = ""
                    store.startResend()
                }

            case .code:
                Text(store.S("codeSent", "e", store.displayEmail))
                    .font(.system(size: 14.5))
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 6)

                GlassField(placeholder: store.S["code"], text: $store.emailCode, theme: theme, keyboard: .numberPad, height: 54)

                PrimaryButton(title: store.S["confirm"], theme: theme, height: 52, radius: 16) {
                    store.emailStage = .newValue
                }

                ResendButton(store: store)

            case .newValue:
                Text(store.S["newEmailPrompt"])
                    .font(.system(size: 14.5))
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 6)

                GlassField(placeholder: store.S["newEmail"], text: $store.emailNew, theme: theme, keyboard: .emailAddress, height: 54)

                PrimaryButton(title: store.S["confirm"], theme: theme, height: 52, radius: 16) {
                    let trimmed = store.emailNew.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { store.email = trimmed }
                    store.screen = .account
                    store.emailStage = .intro
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
            switch store.pwStage {
            case .intro:
                Text(store.S["pwIntro"])
                    .font(.system(size: 14.5))
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 6)

                PrimaryButton(title: store.S["sendVerify"], theme: theme, height: 52, radius: 16) {
                    store.pwStage = .code
                    store.pwCode = ""
                    store.pwNew = ""
                    store.pwConfirm = ""
                    store.pwError = false
                    store.startResend()
                }

            case .code:
                Text(store.S["codeSentPw"])
                    .font(.system(size: 14.5))
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 6)

                GlassField(placeholder: store.S["code"], text: $store.pwCode, theme: theme, keyboard: .numberPad, height: 54)

                PrimaryButton(title: store.S["confirm"], theme: theme, height: 52, radius: 16) {
                    store.pwStage = .newValue
                    store.pwError = false
                }

                ResendButton(store: store)

            case .newValue:
                Text(store.S["pwNewPrompt"])
                    .font(.system(size: 14.5))
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(3)
                    .padding(.horizontal, 6)

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

                    FieldError(message: store.pwError ? store.S["pwMismatch"] : "", theme: theme)
                }

                PrimaryButton(title: store.S["confirm"], theme: theme, height: 52, radius: 16) {
                    store.confirmPassword()
                }
            }
        }
    }
}

private struct ResendButton: View {
    @Bindable var store: StepOneStore

    var body: some View {
        let theme = store.theme
        Button {
            if store.resendSeconds == 0 { store.startResend() }
        } label: {
            Text(store.resendLabel)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .glass(theme, shape: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .opacity(store.resendSeconds == 0 ? 1 : 0.4)
        }
        .buttonStyle(PressStyle(scale: 0.98))
        .disabled(store.resendSeconds > 0)
    }
}
