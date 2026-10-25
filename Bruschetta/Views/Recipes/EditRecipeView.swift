import SwiftUI
import SwiftData

struct EditRecipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe?

    @State private var name = ""
    @State private var summary = ""
    @State private var servings = 2
    @State private var prepMinutes = 0
    @State private var ingredients = ""
    @State private var steps = ""
    @State private var imageData: Data?
    @State private var pickerSource: ImagePicker.Source?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    RecipeImage(data: imageData, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .listRowInsets(EdgeInsets())
                    Button("Choose from library", systemImage: "photo") { pickerSource = .photoLibrary }
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("Take photo", systemImage: "camera") { pickerSource = .camera }
                    }
                    if imageData != nil {
                        Button("Remove photo", systemImage: "trash", role: .destructive) { imageData = nil }
                    }
                }
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Short description", text: $summary)
                    Stepper("Servings: \(servings)", value: $servings, in: 1...50)
                    Stepper("Time: \(prepMinutes == 0 ? "—" : Recipe.formatDuration(minutes: prepMinutes))", value: $prepMinutes, in: 0...600, step: 5)
                }
                Section("Ingredients (one per line)") {
                    TextEditor(text: $ingredients).frame(minHeight: 120)
                }
                Section("Steps (one per line)") {
                    TextEditor(text: $steps).frame(minHeight: 160)
                }
            }
            .navigationTitle(recipe == nil ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(item: Binding(get: { pickerSource.map(SourceBox.init) }, set: { pickerSource = $0?.source })) { box in
                ImagePicker(source: box.source) { image in
                    imageData = Self.downscaledJPEG(image)
                }
            }
            .onAppear(perform: load)
        }
    }

    private struct SourceBox: Identifiable {
        let source: ImagePicker.Source
        var id: Int { source == .camera ? 0 : 1 }
    }

    private func load() {
        guard !loaded, let recipe else { return }
        loaded = true
        name = recipe.name
        summary = recipe.summary
        servings = recipe.servings
        prepMinutes = recipe.prepMinutes
        ingredients = recipe.ingredientsText
        steps = recipe.stepsText
        imageData = recipe.imageData
    }

    private func save() {
        let target = recipe ?? Recipe(name: "")
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.summary = summary
        target.servings = servings
        target.prepMinutes = prepMinutes
        target.ingredientsText = ingredients
        target.stepsText = steps
        target.imageData = imageData
        if recipe == nil { modelContext.insert(target) }
        try? modelContext.save()
        dismiss()
    }

    private static func downscaledJPEG(_ image: UIImage, maxDimension: CGFloat = 1400) -> Data? {
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
