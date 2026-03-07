import SwiftUI

struct TransactionTableView: View {
    let data: TransactionTableData

    var body: some View {
        if let columns = data.columns, let rows = data.rows {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    ForEach(columns, id: \.self) { col in
                        Text(col)
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                    }
                }
                .background(Color(.systemGray5))

                Divider()

                // Rows
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 4)
                        }
                    }
                    .background(index % 2 == 0 ? Color.clear : Color(.systemGray6).opacity(0.5))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
}
