import SwiftUI
import SwiftData

struct RecipesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @State private var showNew = false
    @State private var showImport = false
    @State private var recipeToDelete: Recipe?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            if recipes.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 34))
                        .foregroundStyle(Color.food)
                    Text("No recipes yet")
                        .font(.rowTitle)
                        .foregroundStyle(Color.ink)
                    Text("Add your own with a photo, ingredients and steps.")
                        .font(.rowDetail)
                        .foregroundStyle(Color.inkSecondary)
                        .multilineTextAlignment(.center)
                    Button("Import from a link") { showImport = true }
                        .buttonStyle(.borderedProminent)
                        .tint(.food)
                    Button("Add sample recipes") { addSamples() }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(recipes) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipe: recipe)
                        } label: {
                            RecipeCard(recipe: recipe)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) { recipeToDelete = recipe }
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(Color.paper)
        .safeAreaInset(edge: .bottom) { AdSlot() }
        .navigationTitle("Recipes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("New recipe", systemImage: "square.and.pencil") { showNew = true }
                    Button("Import from link", systemImage: "link") { showImport = true }
                } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showNew) { EditRecipeView(recipe: nil) }
        .sheet(isPresented: $showImport) { ImportRecipeView() }
        .confirmationDialog("Delete this recipe?", isPresented: Binding(get: { recipeToDelete != nil }, set: { if !$0 { recipeToDelete = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let recipe = recipeToDelete {
                    modelContext.delete(recipe)
                    try? modelContext.save()
                }
                recipeToDelete = nil
            }
        } message: {
            Text("This removes the recipe from Alfie Track. Items already on your shopping list stay.")
        }
    }

    private func addSamples() {
        for s in Recipe.samples {
            modelContext.insert(Recipe(name: s.name, summary: s.summary, servings: s.servings,
                                       prepMinutes: s.prep, ingredientsText: s.ingredients, stepsText: s.steps))
        }
        try? modelContext.save()
    }
}

private struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RecipeImage(data: recipe.imageData, height: 110)
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.name)
                    .font(.rowTitle)
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(recipe.ingredients.count) ingredients" + (recipe.prepMinutes > 0 ? " · \(Recipe.formatDuration(minutes: recipe.prepMinutes))" : ""))
                    .font(.rowDetail)
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.cardBorder, lineWidth: 1))
    }
}

struct RecipeImage: View {
    let data: Data?
    var height: CGFloat = 110

    var body: some View {
        // Fixed-size container + overlay so a large image can never drive the layout size.
        Color.foodTint
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                if let image = RecipeImage.displayImage(from: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "fork.knife").font(.system(size: 28)).foregroundStyle(Color.food)
                }
            }
            .clipped()
    }

    /// Decodes at a bounded size so oversized photos don't exhaust the render pipeline.
    static func displayImage(from data: Data?, maxDimension: CGFloat = 1000) -> UIImage? {
        guard let data, let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
