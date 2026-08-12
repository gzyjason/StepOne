//
//  OnboardingScreen.swift
//  StepOne
//
//  First run: quote, welcome, name, greeting, three demo trips, the reward
//  explainer, trip-type picking, then register / verify / log in.
//

import SwiftUI

struct OnboardingScreen: View {
    @Bindable var store: StepOneStore

    @State private var demoAxis: DragAxis?

    private var ob: OnboardingState { store.onboarding }
    private var theme: StepOneTheme { store.theme }
    private let allTypes = ["creativity", "physical", "housework", "hygiene", "study", "hobby", "social"]

    var body: some View {
        ZStack {
            theme.screenBg.ignoresSafeArea()
            AmbientBackground(theme: theme, spots: AmbientBackground.Blob.home)

            quote
            welcome
            demoStack
            rewardExplainer
            namePrompt
            greeting
            primer
            typePicker
            registerForm
            verifyForm
            loginForm
            confirmationMask
        }
        .onAppear { if ob.step == .quote && ob.phase == 0 { ob.startIntro() } }
    }

    // MARK: Quote

    private var quote: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(store.S["obQuote"])
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineSpacing(6)
                Text(store.S["obQuoteAuthor"])
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 22)
            }
            .padding(.horizontal, 44)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Every other language is machine-translated from the English
            // copy, so the first screen says so once and then stays quiet.
            if store.lang != "en" {
                Text(store.S["aiTranslated"])
                    .font(.system(size: 12))
                    .foregroundStyle(theme.hint)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 44)
                    .padding(.bottom, 34)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .opacity(ob.quoteOpacity)
        .allowsHitTesting(false)
    }

    // MARK: Welcome

    private var welcome: some View {
        ZStack {
            Text(store.S["obWelcome"])
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .lineSpacing(8)
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(ob.welcomeOpacity)
                .allowsHitTesting(false)

            VStack(spacing: 4) {
                Spacer()
                PrimaryButton(title: store.S["obStart"], theme: theme) {
                    ob.startFromWelcome()
                }
                Button { ob.toLogin(from: .welcome) } label: {
                    Text(store.S["obLoginExisting"])
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                        .frame(height: 46)
                }
                .buttonStyle(PressStyle(scale: 1))
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 54)
            .opacity(ob.ctaOpacity)
            .allowsHitTesting(ob.ctaOpacity == 1)
        }
    }

    // MARK: Demo trips

    /// Three bands of guidance: complete at the top, discard at the bottom and
    /// — sitting right on the card so proximity ties them together — the
    /// sideways arrows on the card's own edges.
    private var demoStack: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2
            let cardY = geo.size.height / 2
            let cardTop = cardY - TripCardView.size.height / 2
            let cardEdge = TripCardView.size.width / 2
            let downArrowY = geo.size.height - Self.arrowInset

            ZStack {
                ForEach([-1, 0, 1], id: \.self) { slot in
                    demoCard(slot: slot, centerX: centerX, centerY: cardY)
                }

                Group {
                    tutorialArrow("arrow.up", size: Self.leadArrow)
                        .position(x: centerX, y: Self.arrowInset)
                    tutorialLabel(store.S["obSwipeUp"])
                        .position(x: centerX, y: Self.arrowInset + Self.arrowToLabel)

                    sidewaysGuide(centerX: centerX, cardEdge: cardEdge, y: cardTop - Self.sideRowLift)

                    tutorialLabel(store.S["obSwipeDown"])
                        .position(x: centerX, y: downArrowY - Self.arrowToLabel)
                    tutorialArrow("arrow.down", size: Self.leadArrow)
                        .position(x: centerX, y: downArrowY)
                }
                .opacity(ob.hintOpacity)
                .allowsHitTesting(false)
            }
        }
        .allowsHitTesting(ob.step == .demo)
        .opacity(ob.step == .demo ? 1 : 0)
    }

    // Tutorial metrics. The card sits dead centre and the two lead arrows are
    // mirrored about it, so the opposite gestures read as a matched pair.
    private static let leadArrow: CGFloat = 38
    private static let sideArrow: CGFloat = 22
    /// Lead-arrow centre, measured from the top edge and from the bottom edge.
    private static let arrowInset: CGFloat = 40
    /// Centre-to-centre between a lead arrow and the label it belongs to.
    private static let arrowToLabel: CGFloat = 37
    private static let sideRowLift: CGFloat = 34

    /// Left and right arrows sit on the card's own edges, so the gesture they
    /// describe is unmistakable. They dim once the deck is down to one card
    /// and there is nothing left to switch to.
    private func sidewaysGuide(centerX: CGFloat, cardEdge: CGFloat, y: CGFloat) -> some View {
        ZStack {
            tutorialArrow("arrow.left", size: Self.sideArrow)
                .position(x: centerX - cardEdge, y: y)
            tutorialArrow("arrow.right", size: Self.sideArrow)
                .position(x: centerX + cardEdge, y: y)
            tutorialLabel(store.S["obSwipeSide"])
                .frame(maxWidth: TripCardView.size.width - 76)
                .position(x: centerX, y: y)
        }
        .opacity(ob.canCycle ? 1 : 0.3)
        .animation(.easeOut(duration: 0.3), value: ob.canCycle)
    }

    private func tutorialArrow(_ symbol: String, size: CGFloat) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(theme.icon)
    }

    private func tutorialLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(theme.textSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
    }

    @ViewBuilder
    private func demoCard(slot: Int, centerX: CGFloat, centerY: CGFloat) -> some View {
        let cards = ob.cards
        // On the last card the neighbouring slots would only be copies of it,
        // which would promise a switch that no longer exists.
        if !cards.isEmpty, slot == 0 || cards.count > 1 {
            let card = cards[ob.wrapped(ob.position + slot)]
            let isTop = slot == 0
            // The opening card still rises from below — there is no deck
            // behind it yet to come from. Every later one arrives from the
            // right, retracing the sideways cycle, and rides the same `u` so
            // it picks up that cycle's scale and tilt on the way in.
            let entryDrop: CGFloat = (ob.entering && ob.firstDeal && isTop) ? 660 : 0
            let entryShift: CGFloat = (ob.entering && !ob.firstDeal && isTop) ? store.slot : 0
            let u = CGFloat(slot) + (ob.dragX + entryShift) / store.slot
            let offsetY = (isTop ? ob.dragY : 0) + entryDrop

            let body = TripCardView(
                title: card.title,
                desc: card.desc,
                emoji: card.emoji,
                metersLabel: "+" + store.unit.format(card.m),
                theme: theme,
                tint: ob.dragY < 0
                    ? Color(r: 48, g: 209, b: 88)
                    : Color(r: 255, g: 69, b: 58),
                tintOpacity: isTop ? min(abs(ob.dragY) / 280, 0.32) : 0
            )
            .scaleEffect(1 - min(abs(u), 1.4) * 0.06)
            .rotationEffect(.degrees(u * 7))
            .position(x: centerX + u * store.slot, y: centerY + offsetY)
            .opacity(cardOpacity(isTop: isTop))
            .zIndex(isTop ? 3 : 1)

            if isTop {
                body.gesture(demoGesture)
            } else {
                body.onTapGesture { ob.slideDemo(slot, slot: store.slot) }
            }
        }
    }

    private func cardOpacity(isTop: Bool) -> Double {
        if ob.firstDeal && !isTop { return 0 }
        if ob.flying != nil && isTop { return 0 }
        return 1
    }

    /// Axis-locked like the home deck: sideways switches trips, up completes,
    /// down discards.
    private var demoGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard ob.flying == nil, !ob.sliding else { return }
                if demoAxis == nil {
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard hypot(dx, dy) >= 6 else { return }
                    demoAxis = abs(dx) >= abs(dy) ? .horizontal : .vertical
                    ob.isDragging = true
                }
                switch demoAxis {
                case .horizontal:
                    // A single card has nowhere to go, so it stays put.
                    ob.dragX = ob.canCycle ? value.translation.width : 0
                    ob.dragY = 0
                case .vertical:
                    ob.dragX = 0
                    ob.dragY = value.translation.height
                case .none:
                    break
                }
            }
            .onEnded { _ in
                guard ob.flying == nil, !ob.sliding else { return }
                let axis = demoAxis
                demoAxis = nil
                ob.isDragging = false
                let dx = ob.dragX
                let dy = ob.dragY

                if axis == .horizontal, abs(dx) > 90 {
                    ob.slideDemo(dx < 0 ? 1 : -1, slot: store.slot)
                } else if axis == .vertical, dy < -110 {
                    ob.swipeDemo(up: true)
                } else if axis == .vertical, dy > 110 {
                    ob.swipeDemo(up: false)
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        ob.dragX = 0
                        ob.dragY = 0
                    }
                }
            }
    }

    // MARK: Reward explainer

    private var rewardExplainer: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text(store.S["obReward1"])
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .lineSpacing(8)
                .opacity(ob.reward1Opacity)
            Text(store.S["obReward2"])
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .lineSpacing(8)
                .opacity(ob.reward2Opacity)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    // MARK: Name

    private var namePrompt: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(store.S["obNamePrompt"])
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(theme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                TextField(store.S["obNamePlaceholder"], text: Bindable(ob).name)
                    .font(.system(size: 21))
                    .foregroundStyle(theme.textPrimary)
                    .frame(height: 46)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(ob.nameError ? theme.destructive : theme.sepThin)
                            .frame(height: 1.5)
                    }
                    .onSubmit { ob.confirmName() }
                    .submitLabel(.done)

                FieldError(
                    message: ob.nameError ? store.S["obNameRequired"] : "",
                    theme: theme,
                    inset: 0
                )
            }

            Button { ob.confirmName() } label: {
                Text(store.S["confirm"])
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 30)
                    .frame(height: 48)
                    .background(theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(PressStyle(scale: 0.97))
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(ob.step == .name ? 1 : 0)
        .allowsHitTesting(ob.step == .name)
        .onChange(of: ob.name) { _, _ in ob.nameError = false }
    }

    // MARK: Greeting (centred, then docks to the top for the demo)

    private var greeting: some View {
        GeometryReader { geo in
            Text(ob.greetingLine(store.S, part: DayPart.current()))
                .font(.system(size: ob.greetingDocked ? 22 : 30, weight: .bold))
                .foregroundStyle(theme.textPrimary)
                .lineSpacing(5)
                .padding(.trailing, 76)
                .frame(width: geo.size.width, alignment: .leading)
                .padding(.leading, ob.greetingDocked ? 20 : 40)
                .position(
                    x: geo.size.width / 2,
                    y: ob.greetingDocked ? 88 : geo.size.height / 2
                )
                .opacity(ob.greetingOpacity)
        }
        .allowsHitTesting(false)
    }

    // MARK: Primer (what the app asks of you, then what comes next)

    private var primer: some View {
        ZStack {
            primerLine(store.S["obPrimer1"], opacity: ob.primer1Opacity)
            primerLine(store.S["obPrimer2"], opacity: ob.primer2Opacity)
        }
        .allowsHitTesting(false)
    }

    /// The reward explainer's type and measures, so the run of statement
    /// screens reads as one voice.
    private func primerLine(_ text: String, opacity: Double) -> some View {
        Text(text)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(theme.textPrimary)
            .lineSpacing(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(opacity)
    }

    // MARK: Trip types

    private var typePicker: some View {
        VStack(spacing: 0) {
            Text(store.S["obTypesPrompt"])
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 80)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(store.S["obTypesHint"])
                    .font(.system(size: 13.5))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Text(store.S("selCount", "n", "\(ob.types.count)"))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, 26)
            .padding(.top, 18)
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(allTypes.enumerated()), id: \.element) { i, id in
                        if i > 0 { Separator(theme: theme, inset: 0) }
                        let selected = ob.types.contains(id)
                        Button { ob.toggleType(id) } label: {
                            HStack(spacing: 12) {
                                CategoryIcon(category: id, color: theme.icon, size: 20)
                                Text(store.S.categoryName(id))
                                    .font(.system(size: 15.5))
                                    .foregroundStyle(theme.textPrimary)
                                Spacer(minLength: 0)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(theme.accentCheck)
                                    .opacity(selected ? 1 : 0)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .contentShape(Rectangle())
                            .opacity(!selected && ob.types.count >= 3 ? 0.4 : 1)
                        }
                        .buttonStyle(RowPressStyle())
                    }
                }
                .glassCard(theme)
            }
            .padding(.horizontal, 18)

            PrimaryButton(
                title: store.S["confirm"],
                theme: theme,
                enabled: !ob.types.isEmpty
            ) { ob.confirmTypes() }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 46)
        }
        .opacity(ob.step == .types ? 1 : 0)
        .allowsHitTesting(ob.step == .types)
    }

    // MARK: Register

    private var registerForm: some View {
        VStack(spacing: 0) {
            Text(store.S["authRegisterTitle"])
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 78)
                .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        GlassField(placeholder: store.S["authEmail"], text: Bindable(ob).email, theme: theme, keyboard: .emailAddress)
                        FieldError(message: ob.errEmail, theme: theme)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        GlassField(placeholder: store.S["authPassword"], text: Bindable(ob).password, theme: theme, secure: true)
                        FieldError(message: ob.errPassword, theme: theme)
                        Text(store.S["authPasswordHint"])
                            .font(.system(size: 12))
                            .foregroundStyle(theme.hint)
                            .padding(.horizontal, 6)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        GlassField(placeholder: store.S["confirmPw"], text: Bindable(ob).passwordConfirm, theme: theme, secure: true)
                        FieldError(message: ob.errPasswordConfirm, theme: theme)
                    }

                    FieldError(message: ob.errGeneral, theme: theme)

                    PrimaryButton(title: store.S["authRegister"], theme: theme, busy: store.busy == .register) {
                        register()
                    }
                    .padding(.top, 4)

                    OrDivider(theme: theme, label: store.S["orDivider"])

                    AppleSignInButton(store: store) { store.finishOnboarding() }
                    GoogleAuthButton(store: store) { store.finishOnboarding() }
                    FieldError(message: store.federatedError, theme: theme)

                    Button { ob.toLogin(from: .register) } label: {
                        Text(store.S["obLoginExisting"])
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(theme.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    }
                    .buttonStyle(PressStyle(scale: 1))

                    Button { store.finishOnboarding(name: "friend") } label: {
                        Text(store.S["authSkip"])
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(theme.hint)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .buttonStyle(PressStyle(scale: 1))
                    .padding(.top, -8)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 32)
            }
        }
        .opacity(ob.step == .register ? 1 : 0)
        .allowsHitTesting(ob.step == .register)
    }

    private func register() {
        let email = ob.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailOk = StepOneStore.isValidEmail(email)
        let pwOk = StepOneStore.isValidPassword(ob.password)
        let matchOk = !ob.passwordConfirm.isEmpty && ob.passwordConfirm == ob.password

        ob.errEmail = emailOk ? "" : store.S["errEmailInvalid"]
        ob.errPassword = pwOk ? "" : store.S["errWeakPassword"]
        ob.errPasswordConfirm = matchOk ? "" : store.S["errPasswordsDiffer"]
        ob.errGeneral = ""

        guard emailOk, pwOk, matchOk else { return }
        store.runAuth(.register) {
            let name = ob.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let created = await store.auth.register(
                email: email,
                password: ob.password,
                name: name.isEmpty ? nil : name
            )
            guard created else {
                // Route the failure to the field it came from, so it reads the
                // way the local validation above does.
                let message = store.authMessage
                switch store.auth.error {
                case .invalidEmail, .emailAlreadyInUse: ob.errEmail = message
                case .weakPassword: ob.errPassword = message
                default: ob.errGeneral = message
                }
                return
            }
            ob.toVerify()
            store.startResend()
            store.auth.watchForVerification()
        }
    }

    // MARK: Verify

    private var verifyForm: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Button { ob.verifyBack() } label: {
                    HStack(spacing: 1) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text(store.S["authBack"])
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundStyle(theme.textPrimary)
                    .padding(.leading, 6)
                    .padding(.trailing, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PressStyle(scale: 1))

                Text(store.S["authVerifyTitle"])
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 64)
            .padding(.horizontal, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(store.S("authLinkSentScreen", "e", verifyTarget))
                        .font(.system(size: 14.5))
                        .foregroundStyle(theme.textSecondary)
                        .lineSpacing(3)
                        .padding(.horizontal, 6)

                    FieldError(message: ob.verifyError, theme: theme)

                    PrimaryButton(title: store.S["authOpenedLink"], theme: theme, busy: store.busy == .verify) {
                        verify()
                    }

                    Button {
                        store.resendVerification(.resend)
                    } label: {
                        ZStack {
                            Text(store.resendSeconds > 0
                                ? store.S("authResendLinkIn", "s", "\(store.resendSeconds)")
                                : store.S["authResendLink"])
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(theme.accent)
                                .opacity(store.busy == .resend ? 0 : 1)
                            if store.busy == .resend { Spinner(color: theme.accent, size: 14) }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .opacity(store.resendSeconds == 0 ? 1 : 0.4)
                    }
                    .buttonStyle(PressStyle(scale: 1))
                    .disabled(store.resendSeconds > 0)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 32)
            }
        }
        .opacity(ob.step == .verify ? 1 : 0)
        .allowsHitTesting(ob.step == .verify)
        // The background poll flips this the moment the link is opened, so
        // coming back from the mail app lands straight on Home.
        .onChange(of: store.auth.isSignedIn) { _, signedIn in
            if signedIn, ob.step == .verify { store.finishOnboarding() }
        }
    }

    private var verifyTarget: String {
        let trimmed = ob.email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "your email address" : trimmed
    }

    private func verify() {
        store.runAuth(.verify) {
            if await store.auth.checkVerification() {
                store.finishOnboarding()
            } else {
                // No error means the link simply has not been opened yet.
                ob.verifyError = store.authMessage.isEmpty
                    ? store.S["errNotVerifiedYet"]
                    : store.authMessage
            }
        }
    }

    // MARK: Login

    private var loginForm: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Button { ob.loginBack() } label: {
                    HStack(spacing: 1) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text(store.S["authBack"])
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundStyle(theme.textPrimary)
                    .padding(.leading, 6)
                    .padding(.trailing, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PressStyle(scale: 1))

                Text(store.S["authLogin"])
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 64)
            .padding(.horizontal, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        GlassField(placeholder: store.S["authEmail"], text: Bindable(ob).loginEmail, theme: theme, keyboard: .emailAddress)
                        FieldError(message: ob.loginEmptyEmail ? store.S["errEnterEmail"] : "", theme: theme)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        GlassField(placeholder: store.S["authPassword"], text: Bindable(ob).loginPassword, theme: theme, secure: true)
                        FieldError(message: loginPasswordError, theme: theme)
                    }

                    PrimaryButton(title: store.S["authLogin"], theme: theme, busy: store.busy == .login) {
                        login()
                    }
                    .padding(.top, 4)

                    OrDivider(theme: theme, label: store.S["orDivider"])

                    AppleSignInButton(store: store) { store.finishOnboarding() }
                    GoogleAuthButton(store: store) { store.finishOnboarding() }
                    FieldError(message: store.federatedError, theme: theme)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 32)
            }
        }
        .opacity(ob.step == .login ? 1 : 0)
        .allowsHitTesting(ob.step == .login)
    }

    /// The two password-side failures are mutually exclusive — `login()` clears
    /// one before setting the other — so they share a single reserved row.
    private var loginPasswordError: String {
        if ob.loginEmptyPassword { return store.S["errEnterPassword"] }
        return ob.loginError
    }

    private func login() {
        let email = ob.loginEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !ob.loginPassword.isEmpty else {
            ob.loginEmptyEmail = email.isEmpty
            ob.loginEmptyPassword = ob.loginPassword.isEmpty
            ob.loginError = ""
            return
        }
        ob.loginEmptyEmail = false
        ob.loginEmptyPassword = false
        ob.loginError = ""

        store.runAuth(.login) {
            guard await store.auth.logIn(email: email, password: ob.loginPassword) else {
                ob.loginError = store.authMessage
                return
            }
            // An account that was made but never confirmed picks up on the
            // same waiting screen a new sign-up uses.
            guard !store.auth.needsVerification else {
                ob.email = email
                ob.toVerify()
                store.startResend()
                store.auth.watchForVerification()
                return
            }
            store.finishOnboarding()
        }
    }

    // MARK: Confirmation mask

    /// Full-screen glass wash with a checkmark that draws itself, shown
    /// between onboarding steps.
    private var confirmationMask: some View {
        ZStack {
            ZStack {
                CheckmarkShape()
                    .trim(from: 0, to: ob.checkVisible ? 1 : 0)
                    .stroke(theme.accentCheck, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 56, height: 56)

                if !ob.checkVisible {
                    Spinner(color: theme.accentCheck, size: 44)
                }
            }
            .frame(width: 104, height: 104)
            .glassCapsule(theme)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .background(theme.glassTint)
        .ignoresSafeArea()
        .opacity(ob.maskVisible ? 1 : 0)
        .allowsHitTesting(ob.maskVisible)
    }
}

/// The design's checkmark path, on a 24×24 grid.
struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 24
        var path = Path()
        path.move(to: CGPoint(x: 4.5 * s, y: 12.5 * s))
        path.addLine(to: CGPoint(x: 9.5 * s, y: 17.5 * s))
        path.addLine(to: CGPoint(x: 19.5 * s, y: 6.5 * s))
        return path
    }
}
