import SwiftUI

struct MetricGridView: View {
    let data: MetricGridData

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        if let metrics = data.metrics, !metrics.isEmpty {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(metrics) { metric in
                    VStack(spacing: 4) {
                        Text(metric.value)
                            .font(.title3.bold())
                        Text(metric.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}
