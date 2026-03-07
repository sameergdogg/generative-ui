import SwiftUI

struct SummaryCardView: View {
    let data: SummaryCardData

    var body: some View {
        VStack(spacing: 6) {
            if let title = data.title {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let value = data.value {
                Text(value)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
            }
            if let subtitle = data.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
