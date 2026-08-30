import SwiftUI
import UIKit

struct ReceiptCaptureView: View {
    @Binding var imageData: Data?

    @State private var showSourceOptions = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showFullScreen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Receipt")
                .font(.headline)

            if let imageData, let uiImage = UIImage(data: imageData) {
                HStack(spacing: 12) {
                    Button {
                        showFullScreen = true
                    } label: {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 6) {
                        Button("Retake Photo") { showSourceOptions = true }
                            .font(.subheadline)
                        Button("Remove Photo", role: .destructive) {
                            self.imageData = nil
                        }
                        .font(.subheadline)
                    }

                    Spacer()
                }
            } else {
                Button {
                    showSourceOptions = true
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Add Receipt Photo")
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .confirmationDialog("Add Receipt Photo", isPresented: $showSourceOptions, titleVisibility: .hidden) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            Button("Choose from Library") { showPhotoLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(source: .camera) { image in
                imageData = image.jpegData(compressionQuality: 0.7)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoLibrary) {
            ImagePicker(source: .photoLibrary) { image in
                imageData = image.jpegData(compressionQuality: 0.7)
            }
        }
        .sheet(isPresented: $showFullScreen) {
            if let imageData, let uiImage = UIImage(data: imageData) {
                ReceiptFullScreenView(image: uiImage)
            }
        }
    }
}

private struct ReceiptFullScreenView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
