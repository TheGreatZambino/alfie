import SwiftUI
import SwiftData

struct ImportRecipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var link = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://…", text: $link)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button("Paste from clipboard", systemImage: "doc.on.clipboard") {
                        if let text = UIPasteboard.general.string { link = text }
                    }
                } header: {
                    Text("Import from a link")
                } footer: {
                    Text("Paste the link to a recipe from a website, like Tasty, AllRecipes, or a food blog. In a recipe app, tap Share, then Copy Link.")
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(Color.training) }
                }

                Section {
                    Button {
                        Task { await runImport() }
                    } label: {
                        HStack {
                            Text("Import recipe")
                            if isLoading { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(isLoading || link.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Import Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func runImport() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let (imported, imageData) = try await RecipeImportService.importRecipe(from: link)
            let recipe = Recipe(
                name: imported.name,
                summary: imported.summary,
                servings: imported.servings,
                prepMinutes: imported.prepMinutes,
                ingredientsText: imported.ingredients.joined(separator: "\n"),
                stepsText: imported.steps.joined(separator: "\n"),
                imageData: RecipeImage.displayImage(from: imageData, maxDimension: 1000)?.jpegData(compressionQuality: 0.8)
            )
            modelContext.insert(recipe)
            try? modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
