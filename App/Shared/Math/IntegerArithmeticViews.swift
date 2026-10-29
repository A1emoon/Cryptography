import SwiftUI

struct BinaryConversionView: View {
    let conversion: BinaryConversion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 8) {
                    ForEach(conversion.divisions) { step in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(spacing: 7) {
                                Text(step.value.description).font(AppStyle.math)
                                Text(String(step.bit)).font(.system(.subheadline, design: .serif))
                                    .foregroundStyle(AppStyle.accent)
                            }
                            .monospacedDigit().fixedSize()
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(step.value.description), остаток от деления на 2: \(step.bit)")
                            if step.id < conversion.divisions.count - 1 {
                                Text("→").font(.subheadline).foregroundStyle(.secondary).padding(.top, 2)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }
                .padding(.bottom, 6)
            }
            .scrollIndicators(.visible)
            MathLine("\(conversion.number)₁₀ = \(conversion.binary)₂")
            Text("Единиц: \(conversion.ones)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct AlgorithmTableView: View {
    let table: CalculationTable
    @ScaledMetric(relativeTo: .body) private var rowHeight = 33.0
    @ScaledMetric(relativeTo: .body) private var cellPadding = 12.0
    private let operationRows = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text("Разряды слева направо")
                Spacer(minLength: 8)
                Image(systemName: "arrow.left.and.right")
                    .accessibilityLabel("Прокрутите таблицу горизонтально")
            }
            .font(.caption2).foregroundStyle(.secondary)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 0) {
                    factorColumn
                    ForEach(table.columns) { column in
                        calculationColumn(column)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .scrollIndicators(.visible)
            .background(AppStyle.paper)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppStyle.line, lineWidth: 1))
            .accessibilityIdentifier("algorithmTable")
        }
    }

    private var factorColumn: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: rowHeight + 2 * cellPadding)
                .background(AppStyle.soft)
                .overlay(alignment: .bottom) { Rectangle().fill(AppStyle.line).frame(height: 1) }
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                Color.clear.frame(height: rowHeight * Double(operationRows))
                Text("2").font(AppStyle.math).frame(height: rowHeight)
                    .accessibilityLabel("Множитель удвоения: 2")
                    .accessibilityIdentifier("doublingFactor")
            }
            .padding(.vertical, cellPadding)
        }
        .frame(width: 42)
        .background(AppStyle.soft)
        .overlay(alignment: .trailing) { Rectangle().fill(AppStyle.line).frame(width: 1) }
    }

    private func calculationColumn(_ column: CalculationColumn) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(column.addition.description)
                .font(AppStyle.math).monospacedDigit().fixedSize()
                .frame(maxWidth: .infinity).frame(height: rowHeight)
                .padding(cellPadding)
                .background(AppStyle.soft)
                .overlay(alignment: .bottom) { Rectangle().fill(AppStyle.line).frame(height: 1) }
                .accessibilityLabel("Разряд \(column.id + 1): \(column.bit). Прибавляем \(column.addition.description)")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<operationRows, id: \.self) { row in
                    Group {
                        if row < column.operations.count {
                            Text(column.operations[row].expression).font(AppStyle.math)
                        } else if column.isInitial && row == 0 {
                            Text("Начальное значение").font(.caption2).foregroundStyle(.secondary)
                        } else {
                            Text(" ").font(AppStyle.math).accessibilityHidden(true)
                        }
                    }
                    .monospacedDigit().fixedSize().frame(height: rowHeight, alignment: .leading)
                }
                Text(column.result.description)
                    .font(AppStyle.math.weight(.semibold)).monospacedDigit().fixedSize()
                    .foregroundStyle(AppStyle.accent)
                    .frame(height: rowHeight, alignment: .leading)
                    .overlay(alignment: .top) { Rectangle().fill(AppStyle.line).frame(height: 1) }
                    .accessibilityLabel("Остаток: \(column.result.description)")
            }
            .padding(cellPadding)
        }
        .fixedSize(horizontal: true, vertical: false)
        .overlay(alignment: .trailing) { Rectangle().fill(AppStyle.line).frame(width: 1) }
    }
}
