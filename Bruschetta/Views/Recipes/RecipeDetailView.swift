import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe

    @State private var showEdit = false
    @State private var confirmDelete = false
    @State private var addedCount: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                RecipeImage(data: recipe.imageData, height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(recipe.name).font(.screenHeadline).foregroundStyle(Color.ink)
                    if !recipe.summary.isEmpty {
                        Text(recipe.summary).font(.subheadline).foregroundStyle(Color.inkSecondary)
                    }
                    HStack(spacing: 14) {
                        Label("Serves \(recipe.servings)", systemImage: "person.2")
                        if recipe.prepMinutes > 0 { Label(Recipe.formatDuration(minutes: recipe.prepMinutes), systemImage: "clock") }
                    }
                    .font(.rowDetail)
                    .foregroundStyle(Color.inkTertiary)
                }

                Button {
                    let n = Recipe.addIngredients(of: recipe, to: modelContext)
                    withAnimation { addedCount = n }
                } label: {
                    Label(addedLabel, systemImage: addedCount == nil ? "cart.badge.plus" : "checkmark")
                        .font(.rowTitle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.food)
                .disabled(recipe.ingredients.isEmpty)

                VStack(alignment: .leading, spacing: 10) {
                    Text("INGREDIENTS").sectionLabelStyle()
                    ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Circle().fill(Color.food).frame(width: 5, height: 5)
                            Text(line).foregroundStyle(Color.ink)
                        }
                    }
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: 14) {
                    Text("STEPS").sectionLabelStyle()
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.food)
                                .frame(width: 22)
                            Text(line).foregroundStyle(Color.ink)
                        }
                    }
                }
                .cardStyle()
            }
            .padding(20)
        }
        .background(Color.paper)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit", systemImage: "pencil") { showEdit = true }
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showEdit) { EditRecipeView(recipe: recipe) }
        .confirmationDialog("Delete this recipe?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                // Leave the screen first so it never renders a deleted model.
                dismiss()
                let context = modelContext, doomed = recipe
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    context.delete(doomed)
                    try? context.save()
                }
            }
        }
    }

    private var addedLabel: String {
        guard let n = addedCount else { return "Add ingredients to shopping list" }
        return n == 0 ? "Already on your list" : "Added \(n) to shopping list"
    }
}
