import ComposableArchitecture
import DesignSystem
import RunCraftModels
import SQLiteData
import SwiftUI

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
            .background(Color.black)
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
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
        .background(Color.black)
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
            List {
                ForEach(templates) { t in
                    WorkoutListRow(template: t, sourceIcon: nil)
                        .listRowBackground(Color.brand.surface)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.send(.workoutTapped(t, .yours))
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Templates segment

private struct TemplatesSegment: View {
    let store: StoreOf<Workshop>

    var body: some View {
        List {
            ForEach(WorkoutPresets.all) { preset in
                WorkoutListRow(template: preset, sourceIcon: "sparkles")
                    .listRowBackground(Color.brand.surface)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.send(.workoutTapped(preset, .template))
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - List row

private struct WorkoutListRow: View {
    let template: WorkoutTemplate
    let sourceIcon: String?

    private var totalSteps: Int {
        template.blocks.reduce(0) { acc, block in
            switch block {
            case .step: acc + 1
            case .repeatGroup(let g): acc + g.steps.count * g.iterations
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(sourceIcon != nil ? Color.brand.accent.opacity(0.2) : Color.white.opacity(0.08))
                .overlay(
                    Image(systemName: sourceIcon ?? "figure.run")
                        .foregroundStyle(sourceIcon != nil ? Color.brand.accent : .white)
                )
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name).font(.subheadline.bold()).foregroundStyle(.white)
                Text("\(template.blocks.count) blocks · \(totalSteps) steps")
                    .font(.caption)
                    .foregroundStyle(Color.brand.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Color.brand.textSecondary)
        }
        .padding(.vertical, 4)
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
                .foregroundStyle(.white)
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
