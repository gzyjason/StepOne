//
//  JourneyScreens.swift
//  StepOne
//
//  Your Journey (total distance, recent milestone, milestone phases),
//  Trip Types (selection + reordering) and Discarded Trips.
//

import SwiftUI

// MARK: - Your Journey

struct JourneyScreen: View {
    @Bindable var store: StepOneStore
    private var theme: StepOneTheme { store.theme }

    private var totalMeters: Int { store.journeyTotalMeters }

    /// Index of the highest milestone reached, or nil if none yet.
    private var lastReached: Int? {
        var result: Int?
        for (i, milestone) in store.content.milestones.enumerated()
        where milestone.meters <= Double(totalMeters) {
            result = i
        }
        return result
    }

    var body: some View {
        ZStack {
            theme.screenBg.ignoresSafeArea()
            AmbientBackground(theme: theme, spots: AmbientBackground.Blob.journey)

            VStack(spacing: 0) {
                HStack {
                    Button { store.screen = .home } label: {
                        HStack(spacing: 1) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                            Text(store.S["home"])
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundStyle(theme.textPrimary)
                        .padding(.leading, 6)
                        .padding(.trailing, 12)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PressStyle(scale: 1))
                    Spacer()
                }
                .padding(.top, 64)
                .padding(.horizontal, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        totalHeader
                        if let lastReached { recentSection(store.content.milestones[lastReached]) }
                        milestoneSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 44)
                }
            }
        }
    }

    private var totalHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store.S["totalLabel"].uppercased())
                .font(.system(size: 12.5, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(theme.textSecondary)
            Text(store.unit.formatTotal(totalMeters))
                .font(.system(size: 56, weight: .heavy))
                .kerning(-2)
                .foregroundStyle(theme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
        .padding(.bottom, 24)
    }

    private func recentSection(_ milestone: Milestone) -> some View {
        let isOpen = store.openMilestones.contains("recent")
        return VStack(alignment: .leading, spacing: 8) {
            Text(store.S["recent"].uppercased())
                .font(.system(size: 12.5, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(theme.textSecondary)
                .padding(.leading, 8)

            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeOut(duration: 0.22)) { store.toggleMilestone("recent") }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(theme.accentCheck).frame(width: 34, height: 34)
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(milestone.name)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(theme.textPrimary)
                            Text(milestone.dist)
                                .font(.system(size: 13))
                                .foregroundStyle(theme.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Chevron(theme: theme)
                            .rotationEffect(.degrees(isOpen ? 90 : 0))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(RowPressStyle())

                if isOpen {
                    Text(milestone.desc)
                        .font(.system(size: 13.5))
                        .foregroundStyle(theme.textSecondary)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 64)
                        .padding(.trailing, 18)
                        .padding(.bottom, 16)
                }
            }
            .glassCard(theme)
        }
        .padding(.bottom, 26)
    }

    private var milestoneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.S["milestonesLabel"].uppercased())
                .font(.system(size: 12.5, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(theme.textSecondary)
                .padding(.leading, 8)

            VStack(spacing: 12) {
                ForEach(Array(StepOneContent.phases.enumerated()), id: \.offset) { phaseIndex, phase in
                    phaseCard(phaseIndex: phaseIndex, name: phase.name, range: phase.range)
                }
            }
        }
    }

    private func phaseCard(phaseIndex: Int, name: String, range: Range<Int>) -> some View {
        let milestones = Array(store.content.milestones[range])
        let doneCount = milestones.filter { $0.meters <= Double(totalMeters) }.count
        let containsCurrent = lastReached.map { range.contains($0) } ?? false
        let isOpen = store.isPhaseOpen(phaseIndex, defaultOpen: containsCurrent)

        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.22)) {
                    store.togglePhase(phaseIndex, current: isOpen)
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(theme.textPrimary)
                        Text("\(doneCount) / \(milestones.count)")
                            .font(.system(size: 12.5))
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                    if doneCount == milestones.count {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(theme.accentCheck)
                    }
                    Chevron(theme: theme)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .contentShape(Rectangle())
            }
            .buttonStyle(RowPressStyle())

            if isOpen {
                Rectangle().fill(theme.sepThin).frame(height: 0.5)
                ForEach(Array(milestones.enumerated()), id: \.offset) { i, milestone in
                    if i > 0 { Separator(theme: theme, inset: 0) }
                    milestoneRow(milestone, locked: milestone.meters > Double(totalMeters))
                }
            }
        }
        .glassCard(theme)
    }

    private func milestoneRow(_ milestone: Milestone, locked: Bool) -> some View {
        let key = String(milestone.km)
        let isOpen = store.openMilestones.contains(key)
        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.22)) { store.toggleMilestone(key) }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(milestone.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(locked ? theme.textSecondary : theme.textPrimary)
                        Text(milestone.dist)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                    if !locked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(theme.accentCheck)
                    }
                    Chevron(theme: theme, size: 15)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(RowPressStyle())

            if isOpen {
                Text(milestone.desc)
                    .font(.system(size: 13.5))
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 15)
            }
        }
        .opacity(locked ? 0.5 : 1)
    }
}

// MARK: - Trip Types

struct TripTypesScreen: View {
    @Bindable var store: StepOneStore
    @State private var editMode: EditMode = .active
    private var theme: StepOneTheme { store.theme }

    private let allTypes = ["creativity", "physical", "housework", "hygiene", "study", "hobby", "social"]

    var body: some View {
        ZStack {
            theme.screenBg.ignoresSafeArea()
            AmbientBackground(theme: theme, spots: AmbientBackground.Blob.topRight)

            VStack(spacing: 0) {
                ScreenHeader(
                    backLabel: store.S["home"],
                    title: store.S["menuTrips"],
                    subtitle: store.S["chooseHint"],
                    theme: theme,
                    onBack: { store.screen = .home }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        selectedSection
                        allTypesSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 44)
                }
            }
        }
    }

    /// The chosen types, in the order they appear on Home. Drag to reorder.
    private var selectedSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel(text: store.S["onHome"], theme: theme)

            List {
                ForEach(Array(store.chosen.enumerated()), id: \.element) { i, id in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(theme.tabHighlight).frame(width: 22, height: 22)
                            Text("\(i + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(theme.textPrimary)
                        }
                        CategoryIcon(category: id, color: theme.icon, size: 20)
                        Text(store.S.categoryName(id))
                            .font(.system(size: 15.5))
                            .foregroundStyle(theme.textPrimary)
                        Spacer(minLength: 0)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(theme.sepThin)
                    .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14))
                    .frame(height: 54)
                }
                .onMove { source, destination in
                    store.moveChosen(from: source, to: destination)
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, $editMode)
            .frame(height: CGFloat(store.chosen.count) * 54)
            .glassCard(theme)
        }
    }

    private var allTypesSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(store.S["allTypes"].uppercased())
                    .font(.system(size: 12.5, weight: .semibold))
                    .kerning(0.6)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Text(store.S("selCount", "n", "\(store.chosen.count)"))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(allTypes.enumerated()), id: \.element) { i, id in
                    if i > 0 { Separator(theme: theme, inset: 0) }
                    let selected = store.chosen.contains(id)
                    Button { store.toggleType(id) } label: {
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
                        .opacity(!selected && store.chosen.count >= 3 ? 0.4 : 1)
                    }
                    .buttonStyle(RowPressStyle())
                }
            }
            .glassCard(theme)
        }
    }
}

// MARK: - Discarded Trips

struct DiscardedScreen: View {
    @Bindable var store: StepOneStore
    private var theme: StepOneTheme { store.theme }

    var body: some View {
        ZStack {
            theme.screenBg.ignoresSafeArea()
            AmbientBackground(theme: theme, spots: AmbientBackground.Blob.bottomLeft)

            VStack(spacing: 0) {
                ScreenHeader(
                    backLabel: store.S["home"],
                    title: store.S["menuDiscarded"],
                    theme: theme,
                    onBack: { store.screen = .home }
                )

                ScrollView {
                    if store.discarded.isEmpty {
                        Text(store.S["discEmpty"])
                            .font(.system(size: 14.5))
                            .foregroundStyle(theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 80)
                            .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(store.discarded.enumerated()), id: \.element) { i, ref in
                                if i > 0 { Separator(theme: theme, inset: 0) }
                                row(ref, at: i)
                            }
                        }
                        .glassCard(theme)
                        .padding(.horizontal, 18)
                    }
                }
            }
        }
    }

    private func row(_ ref: DiscardRef, at offset: Int) -> some View {
        let trip = store.trips(for: ref.category)[safe: ref.index]
        return HStack(spacing: 12) {
            CategoryIcon(category: ref.category, color: theme.icon, size: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(trip?.title ?? "")
                    .font(.system(size: 15.5))
                    .foregroundStyle(theme.textPrimary)
                Text(store.S.categoryName(ref.category))
                    .font(.system(size: 12.5))
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: 0)
            Button { store.restoreDiscarded(at: offset) } label: {
                Text(store.S["restore"])
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(theme.tabHighlight, in: Capsule())
            }
            .buttonStyle(PressStyle(scale: 0.95))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 58)
    }
}
