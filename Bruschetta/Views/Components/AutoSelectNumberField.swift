import SwiftUI
import UIKit

/// A decimal-entry text field that selects its entire current value the moment editing
/// begins, so typing a real value never requires manually clearing the placeholder number
/// that was already there (SwiftUI's `TextField` has no way to do this on its own).
struct AutoSelectNumberField: UIViewRepresentable {
    @Binding var value: Double
    var placeholder: String = ""
    var maximumFractionDigits: Int = 2

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.keyboardType = .decimalPad
        textField.placeholder = placeholder
        textField.delegate = context.coordinator
        textField.textAlignment = .natural
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        if !uiView.isFirstResponder {
            uiView.text = context.coordinator.formatted(value)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AutoSelectNumberField
        private let formatter: NumberFormatter

        init(parent: AutoSelectNumberField) {
            self.parent = parent
            formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = parent.maximumFractionDigits
        }

        func formatted(_ value: Double) -> String {
            formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            textField.text = formatted(parent.value)
        }

        @objc func textChanged(_ textField: UITextField) {
            let normalized = (textField.text ?? "").replacingOccurrences(of: ",", with: ".")
            parent.value = Double(normalized) ?? 0
        }
    }
}
