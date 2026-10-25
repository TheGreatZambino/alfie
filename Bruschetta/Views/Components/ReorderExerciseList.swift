import SwiftUI

struct ReorderRowItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
}

/// Condensed one-line-per-exercise list with system drag handles, used while reordering
/// movements in a workout or template.
struct ReorderExerciseList: View {
    let items: [ReorderRowItem]
    let onMove: (IndexSet, Int) -> Void

    var body: some View {
        List {
            ForEach(items) { item in
                HStack {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                    Spacer()
                    Text(item.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .onMove(perform: onMove)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.paper)
        .environment(\.editMode, .constant(.active))
    }
}
