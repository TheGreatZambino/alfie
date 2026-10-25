import SwiftUI
import UIKit

struct CurrencyTextField: View {
    let placeholder: String
    @Binding var text: String
    var fontSize: CGFloat = 17

    var body: some View {
        HStack(spacing: 2) {
            Text("$")
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            SelectAllOnFocusTextField(
                placeholder: "0.00",
                text: $text,
                keyboardType: .numberPad,
                font: .systemFont(ofSize: fontSize, weight: .semibold),
                centsEntry: true
            )
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SelectAllOnFocusTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textAlignment: NSTextAlignment = .natural
    var font: UIFont = .preferredFont(forTextStyle: .body)
    /// Digits fill in from the right as cents ("1" → 0.01, "15" → 0.15), so no decimal point is typed.
    var centsEntry = false

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.keyboardType = keyboardType
        textField.textAlignment = textAlignment
        textField.font = font
        textField.delegate = context.coordinator
        context.coordinator.centsEntry = centsEntry
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textChanged(_:)),
            for: .editingChanged
        )
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.placeholder = placeholder
        uiView.font = font
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        let text: Binding<String>
        var centsEntry = false

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func textChanged(_ textField: UITextField) {
            if centsEntry {
                let digits = (textField.text ?? "").filter(\.isNumber).prefix(9)
                let cents = Int(digits) ?? 0
                let formatted = String(format: "%d.%02d", cents / 100, cents % 100)
                textField.text = formatted
                text.wrappedValue = formatted
                return
            }
            text.wrappedValue = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if centsEntry, (textField.text ?? "").isEmpty {
                textField.text = "0.00"
                text.wrappedValue = "0.00"
            }
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
        }
    }
}
