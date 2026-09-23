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
                placeholder: placeholder,
                text: $text,
                keyboardType: .decimalPad,
                font: .systemFont(ofSize: fontSize, weight: .semibold)
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

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.keyboardType = keyboardType
        textField.textAlignment = textAlignment
        textField.font = font
        textField.delegate = context.coordinator
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

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func textChanged(_ textField: UITextField) {
            text.wrappedValue = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
        }
    }
}
