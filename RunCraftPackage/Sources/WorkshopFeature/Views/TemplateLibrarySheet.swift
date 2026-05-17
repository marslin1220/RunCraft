import ComposableArchitecture
import RunCraftModels
import SQLiteData
import SwiftUI

struct TemplateLibrarySheet: View {
    let store: StoreOf<Workshop>
    @Environment(\.dismiss) private var dismiss
    @FetchAll(WorkoutTemplate.order { $0.updatedAt.desc() }) var userTemplates: [WorkoutTemplate]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(WorkoutPresets.all) { preset in
                        TemplateRow(template: preset, isPreset: true)
                            .listRowBackground(Color(hex: "#1A1B2E"))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.send(.presetSelected(preset))
                            }
                    }
                } header: {
                    Label("Templates", systemImage: "books.vertical.fill")
                        .foregroundStyle(Color.electricLime)
                }

                Section {
                    if userTemplates.isEmpty {
                        Text("No saved workouts yet. Build one in the editor or start from a template above.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(userTemplates) { template in
                            TemplateRow(template: template, isPreset: false)
                                .listRowBackground(Color(hex: "#1A1B2E"))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.send(.templateSelected(template))
                                }
                        }
                        .onDelete { indexSet in
                            for i in indexSet {
                                store.send(.deleteTemplate(userTemplates[i].id))
                            }
                        }
                    }
                } header: {
                    Label("Your Workouts", systemImage: "person.fill")
                        .foregroundStyle(Color.electricLime)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.electricLime)
                }
            }
        }
    }
}

#Preview {
    TemplateLibrarySheet(
        store: .init(initialState: Workshop.State()) {
            Workshop()
        }
    )
}

private struct TemplateRow: View {
    let template: WorkoutTemplate
    let isPreset: Bool

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
                .fill(isPreset ? Color.electricLime.opacity(0.2) : Color.white.opacity(0.08))
                .overlay(
                    Image(systemName: isPreset ? "sparkles" : "figure.run")
                        .foregroundStyle(isPreset ? Color.electricLime : .white)
                )
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text("\(template.blocks.count) block\(template.blocks.count == 1 ? "" : "s")")
                    Text("·")
                    Text("\(totalSteps) step\(totalSteps == 1 ? "" : "s")")
                    if !isPreset {
                        Text("·")
                        Text(template.updatedAt, format: .relative(presentation: .named))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
