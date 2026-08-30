import SwiftUI
import UIKit

/// A numeric text field that selects all of its text as soon as it becomes
/// focused, so tapping in immediately lets you overwrite the value (e.g. a
/// placeholder "0") instead of appending to it.
struct SelectAllTextField: UIViewRepresentable {
    @Binding var value: Double
    var placeholder: String = "0"

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.keyboardType = .decimalPad
        textField.textAlignment = .right
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        if !textField.isFirstResponder {
            textField.text = value == 0 ? "" : Self.format(value)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private static func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(value)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SelectAllTextField

        init(_ parent: SelectAllTextField) {
            self.parent = parent
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            textField.selectAll(nil)
        }

        @objc func textChanged(_ textField: UITextField) {
            parent.value = Double(textField.text ?? "") ?? 0
        }
    }
}
