import SwiftUI

struct NotebookBinaryConversion: View {
    let conversion: BinaryConversion
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(conversion.divisions) { step in
                        VStack(spacing: 6) {
                            MathText(text: step.value.description)
                            MathText(text: String(step.bit))
                        }
                        if step.id < conversion.divisions.count - 1 {
                            VStack(spacing: 0) { Text(">>").font(.caption); Text("→").font(.title3) }
                        }
                    }
                }.fixedSize().padding(.vertical, 6)
            }
            MathLine("\(conversion.number) = \(conversion.binary)₂")
        }
    }
}
struct NotebookIntegerTable: View {
    let table: CalculationTable
    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    Color.clear.frame(width: 38, height: 40)
                    ForEach(table.columns) { column in cell(column.addition.description) }
                }
                GridRow {
                    cell("2")
                    ForEach(table.columns) { column in
                        VStack(alignment: .trailing, spacing: 5) {
                            if column.operations.isEmpty { MathText(text: column.result.description) }
                            ForEach(column.operations.indices, id: \.self) { i in
                                switch column.operations[i] {
                                case .double(_, let result): MathText(text: result.description)
                                case .subtract(_, let m, let result):
                                    MathText(text: "− " + m.description)
                                    Divider()
                                    MathText(text: result.description)
                                case .add(_, let b, let result):
                                    if !b.isZero {
                                        MathText(text: "+ " + b.description)
                                        Divider()
                                        MathText(text: result.description)
                                    }
                                }
                            }
                        }.fixedSize().padding(12)
                            .overlay(alignment: .leading) { Rectangle().fill(AppStyle.line).frame(width: 1) }
                    }
                }.overlay(alignment: .top) { Rectangle().fill(AppStyle.line).frame(height: 1) }
            }.fixedSize().padding(.vertical, 4)
        }.accessibilityIdentifier("notebookIntegerTable")
    }
    private func cell(_ text: String) -> some View { MathText(text: text).fixedSize().padding(12) }
}
