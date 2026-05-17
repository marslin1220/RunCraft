import ComposableArchitecture
import RunCraftModels
import SQLiteData
import SwiftUI

struct TemplateLibrarySheet: View {
    let store: StoreOf<Workshop>
    @Environment(\.dismiss) private var dismiss
    @FetchAll(WorkoutTemplate.order { $0.updatedAt.desc() }) var templates: [WorkoutTemplate]

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    EmptyLibraryPrompt()
                } else {
                    List {
                        ForEach(templates) { template in
                            TemplateRow(template: template)
                                .listRowBackground(Color(hex: "#1A1B2E"))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    store.send(.templateSelected(template))
                                }
                        }
                        .onDelete { indexSet in
                            for i in indexSet {
                                store.send(.deleteTemplate(templates[i].id))
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
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

private struct TemplateRow: View {
    let template: WorkoutTemplate

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
                .fill(Color.electricLime.opacity(0.15))
                .overlay(
                    Image(systemName: "figure.run")
                        .foregroundStyle(Color.electricLime)
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
                    Text("·")
                    Text(template.updatedAt, format: .relative(presentation: .named))
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

private struct EmptyLibraryPrompt: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No saved workouts")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text("Build a workout in the editor and tap Save to add it here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
