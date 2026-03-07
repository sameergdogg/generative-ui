import SwiftUI

struct ComponentRenderer: View {
    let component: UIComponent

    var body: some View {
        Group {
            switch component.data {
            case .summaryCard(let data):
                SummaryCardView(data: data)
            case .transactionTable(let data):
                TransactionTableView(data: data)
            case .barChart(let data):
                BarChartView(data: data)
            case .metricGrid(let data):
                MetricGridView(data: data)
            }
        }
    }
}
