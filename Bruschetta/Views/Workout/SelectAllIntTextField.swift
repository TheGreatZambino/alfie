import SwiftUI
import UIKit

/// An integer text field that selects all of its text as soon as it becomes
/// focused, so tapping in immediately lets you overwrite the value instead of
/// appending to it. Used for rep counts alongside `SelectAllTextField` for weight.
struct SelectAllIntTextField: UIViewRepresentable {
    @Binding var value: Int
    var placeholder: String = "0"

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.keyboardType = .numberPad
        textField.textAlignment = .center
        textField.placeholder = placeholder
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        if !textField.isFirstResponder {
            textField.text = value == 0 ? "" : String(value)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SelectAllIntTextField

        init(_ parent: SelectAllIntTextField) {
            self.parent = parent
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            textField.selectAll(nil)
        }

        @objc func textChanged(_ textField: UITextField) {
            parent.value = Int(textField.text ?? "") ?? 0
        }
    }
}
