import DesignSystem
import RunCraftModels
import SwiftUI

/// Explains a `SessionType`'s training purpose — presented from the info
/// button on `CategoryDivider` in the Workshop Templates segment.
struct SessionTypeInfoPopover: View {
    let category: SessionType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: category.symbolName)
                            .foregroundStyle(Color(hex: category.colorHex))
                        Text(category.displayName)
                            .font(.headline)
                    }
                    Text(category.purpose)
                }
                .padding()
            }
            .navigationTitle(category.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("Done", bundle: .module) }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
