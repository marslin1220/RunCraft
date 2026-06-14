import ComposableArchitecture
import DesignSystem
import RunCraftModels
import SQLiteData
import SwiftUI
import VDOTEngine

public struct WorkshopView: View {
    @Bindable public var store: StoreOf<Workshop>

    public init(store: StoreOf<Workshop>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            VStack(spacing: 0) {
                segmentPicker
                content
            }
            .background(Color.brand.background)
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.newWorkoutTapped)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .foregroundStyle(Color.brand.accent)
                }
            }
        } destination: { pathStore in
            switch pathStore.case {
            case .editor(let editorStore):
                WorkoutEditorView(store: editorStore)
            }
        }
    }

    private var segmentPicker: some View {
        Picker("Segment", selection: $store.selectedSegment.sending(\.segmentSelected)) {
            ForEach(Workshop.Segment.allCases, id: \.self) { seg in
                Text(seg.label).tag(seg)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.brand.background)
    }

    @ViewBuilder
    private var content: some View {
        switch store.selectedSegment {
        case .yours:     YoursSegment(store: store)
        case .templates: TemplatesSegment(store: store)
        }
    }
}

// MARK: - Yours segment

private struct YoursSegment: View {
    let store: StoreOf<Workshop>
    @FetchAll(WorkoutTemplate.order { $0.updatedAt.desc() }) var templates: [WorkoutTemplate]

    var body: some View {
        if templates.isEmpty {
            EmptyYoursPrompt(
                onBrowseTemplates: { store.send(.browseTemplatesTapped) },
                onNew: { store.send(.newWorkoutTapped) }
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(templates) { t in
                        WorkoutCardRow(
                            template: t,
                            isPreset: false,
                            onTap: { store.send(.workoutTapped(t, .yours)) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Templates segment

private struct TemplatesSegment: View {
    let store: StoreOf<Workshop>

    /// Presets grouped by training-stimulus category, in `SessionType`
    /// declaration order — only categories with at least one preset appear.
    private var groups: [(category: SessionType, presets: [WorkoutTemplate])] {
        let grouped = Dictionary(grouping: WorkoutPresets.all, by: WorkoutPresets.category(for:))
        return SessionType.allCases.compactMap { category in
            grouped[category].map { (category: category, presets: $0) }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(groups, id: \.category) { group in
                    CategoryDivider(category: group.category)
                    ForEach(group.presets) { preset in
                        WorkoutCardRow(
                            template: preset,
                            isPreset: true,
                            onTap: { store.send(.workoutTapped(preset, .template)) }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}

// MARK: - Category divider

/// Section header grouping presets by `SessionType` — a coloured rail +
/// caption naming the training stimulus (e.g. "INTERVALS", "FARTLEK").
private struct CategoryDivider: View {
    let category: SessionType

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(hex: category.colorHex))
                .frame(width: 3, height: 16)
            Text(category.displayName.uppercased())
                .font(.caption.bold())
                .foregroundStyle(Color(hex: category.colorHex))
                .tracking(1.2)
            Spacer()
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(category.displayName)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - List row (Apple-Workout-style card)

private struct WorkoutCardRow: View {
    let template: WorkoutTemplate
    /// Built-in template uses a different palette + leading icon so the
    /// runner can spot "sample preset" vs "my workout" at a glance.
    let isPreset: Bool
    let onTap: () -> Void
    @Shared(.appStorage("paceUnit")) private var paceUnit: PaceUnit = .perKilometre

    private var subtitle: String {
        template.summary(unit: paceUnit)
    }

    var body: some View {
        WorkoutCard(
            palette: isPreset ? .lilac : .lime,
            symbolName: isPreset ? "sparkles" : "figure.run",
            title: template.name,
            subtitle: subtitle,
            trailing: .chevron,
            action: onTap
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isPreset ? "Template, " : "")\(template.name), \(subtitle)")
    }
}

// MARK: - Empty states

private struct EmptyYoursPrompt: View {
    let onBrowseTemplates: () -> Void
    let onNew: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 56))
                .foregroundStyle(Color.brand.accent.opacity(0.6))
            Text("No workouts yet")
                .font(.title3.bold())
                .foregroundStyle(Color.brand.textPrimary)
            Text("Start from a template or build one from scratch.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.brand.textSecondary)
                .padding(.horizontal, 40)

            VStack(spacing: 10) {
                Button(action: onBrowseTemplates) {
                    Text("Browse Templates")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.brand.accent)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
                Button(action: onNew) {
                    Text("+ New workout")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Color.brand.accent)
                        .overlay(Capsule().stroke(Color.brand.accent, lineWidth: 1.5))
                }
            }
            .padding(.horizontal, 40)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}


#Preview {
    WorkshopView(store: .init(initialState: Workshop.State()) { Workshop() })
}
