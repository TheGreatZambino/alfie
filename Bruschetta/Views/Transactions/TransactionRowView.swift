import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: transaction.category?.colorHex ?? "#9E9E9E"))
                    .frame(width: 40, height: 40)
                Image(systemName: transaction.category?.icon ?? "questionmark")
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.category?.name ?? "Uncategorized")
                    .font(.body)
                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.amount, format: .currency(code: "USD"))
                    .font(.body.weight(.medium))
                Text(transaction.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
