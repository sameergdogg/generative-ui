import SwiftUI
import Charts

struct BarChartView: View {
    let data: BarChartData

    var body: some View {
        if let bars = data.bars, !bars.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if let label = data.label {
                    Text(label)
                        .font(.subheadline.bold())
                }
                Chart(bars) { bar in
                    BarMark(
                        x: .value("Category", bar.name),
                        y: .value("Amount", bar.value)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 200)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
