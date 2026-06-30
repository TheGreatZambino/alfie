import SwiftUI

struct CurrencyTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 2) {
            Text("$")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
        }
    }
}
