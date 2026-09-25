import SwiftUI
import UIKit

/// Thin wrapper around `UIActivityViewController` for sharing/saving a set of already-written
/// files (e.g. a multi-file data export) — `ShareLink` doesn't offer a way to defer building its
/// items until the user taps a button, so this is presented from a `.sheet` instead.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
