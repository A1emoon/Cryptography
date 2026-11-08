import SwiftUI

struct ModularMatrixView: View {
    let rows: [ModularRow]
    var usesPowersOfTwo = false

    private func valueText(_ row: ModularRow) -> String {
        guard usesPowersOfTwo, let exponent = row.value.powerOfTwoExponent else { return row.value.description }
        return PowerNotation.two(exponent)
    }
    private func alphaText(_ row: ModularRow) -> String {
        // In the source, the initial zero rows and the first run of equal
        // value/alpha powers are symbolic. Other coefficients stay decimal.
        guard usesPowersOfTwo,
              row.value.isZero || row.alpha == DecimalInteger(row.value),
              row.alpha.magnitude > .one,
              let exponent = row.alpha.magnitude.powerOfTwoExponent else { return row.alpha.description }
        return (row.alpha.isNegative ? "−" : "") + PowerNotation.two(exponent)
    }
    private func cell(_ text: String) -> some View {
        MathText(text: text).fixedSize().padding(.vertical, 6)
    }
    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .trailing, horizontalSpacing: 20, verticalSpacing: 14) {
                ForEach(rows.indices, id: \.self) { index in
                    GridRow {
                        cell(valueText(rows[index]))
                            .foregroundStyle(AppStyle.accent)
                        cell(alphaText(rows[index]))
                        if let beta = rows[index].beta { cell(beta.description) }
                    }
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
            .background(alignment: .leading) {
                // Divider follows the first column's intrinsic width, including large integers.
                HStack(spacing: 0) {
                    VStack {
                        ForEach(rows.indices, id: \.self) { index in
                            cell(valueText(rows[index]))
                        }
                    }.hidden().padding(.leading, 24)
                    Rectangle().fill(AppStyle.line).frame(width: 1).padding(.leading, 10)
                    Spacer(minLength: 0)
                }
            }
            .overlay(alignment: .leading) { MatrixBracket(right: false).stroke(lineWidth: 1.5).frame(width: 10) }
            .overlay(alignment: .trailing) { MatrixBracket(right: true).stroke(lineWidth: 1.5).frame(width: 10) }
            .fixedSize()
            .padding(.vertical, 4)
        }
        .scrollIndicators(.visible)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rows.enumerated().map { index, row in
            let cells = [valueText(row), alphaText(row)] + (row.beta.map { [$0.description] } ?? [])
            return "Строка \(index + 1): \(cells.joined(separator: ", "))"
        }.joined(separator: ". "))
    }
}

struct ModularFrameView: View {
    let frame: ModularFrame
    let explanations: Bool
    var usesPowerMatrix = false
    private var visibleRows: [ModularRow] {
        usesPowerMatrix && frame.action != .initial ? Array(frame.rows.prefix(1)) : frame.rows
    }
    private var arithmetic: [String] {
        var lines = frame.arithmetic
        if usesPowerMatrix, frame.action == .halve,
           let exponent = frame.rows.first?.value.powerOfTwoExponent, !lines.isEmpty {
            lines[0] = "\(PowerNotation.two(exponent + 1)) : 2 = \(PowerNotation.two(exponent))"
        }
        return lines
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text(String(format: "%02d", frame.id)).font(.caption.monospaced()).foregroundStyle(.secondary)
                    .padding(.top, 12)
                    .accessibilityIdentifier("modularFrame_\(frame.id)")
                TransformationLabel(operation: frame.operation)
                    .accessibilityIdentifier("modularOperation_\(frame.id)")
                Spacer(minLength: 0)
            }
            if frame.action != .initial {
                Image(systemName: "arrow.down").foregroundStyle(AppStyle.accent).accessibilityHidden(true)
            }
            ModularMatrixView(rows: visibleRows, usesPowersOfTwo: usesPowerMatrix)
                .accessibilityIdentifier("modularMatrix_\(frame.id)")
            if let remaining = frame.remaining {
                MathLine("≤ \(remaining)")
                    .accessibilityLabel("Условие для рабочей строки: меньше или равно \(remaining)")
                    .accessibilityIdentifier("modularCondition_\(frame.id)")
            }
            ForEach(arithmetic.indices, id: \.self) { i in MathLine(arithmetic[i]) }
            if explanations {
                Text(frame.explanation).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
    }
}

/// Lay out subscripts as real content so their descent contributes to height.
/// Unicode subscript glyphs in a tightly measured Text can otherwise be clipped.
struct TransformationLabel: View {
    let operation: String
    @ScaledMetric(relativeTo: .title3) private var indexDrop = 12.0
    @ScaledMetric(relativeTo: .title3) private var verticalInset = 6.0

    var body: some View {
        Group {
            if operation.first == "M", let opening = operation.firstIndex(of: "(") {
                #if os(watchOS)
                operationText(opening: opening)
                #else
                ScrollView(.horizontal) { operationText(opening: opening) }.scrollIndicators(.visible)
                #endif
            } else {
                MathText(text: operation).fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, verticalInset)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(operation)
    }

    private func operationText(opening: String.Index) -> some View {
        HStack(alignment: .top, spacing: 1) {
            Text("M").font(.system(.title3, design: .serif).weight(.semibold))
            Text(indices(before: opening)).font(.system(.caption, design: .serif)).padding(.top, indexDrop)
            Text(String(operation[opening...])).font(.system(.title3, design: .serif))
        }.fixedSize().padding(.vertical, verticalInset)
    }

    private func indices(before opening: String.Index) -> String {
        let subscriptDigits = Array("₀₁₂₃₄₅₆₇₈₉")
        return operation[operation.index(after: operation.startIndex)..<opening].map { character in
            if character == "ᵢ" { return "i" }
            if character == "ⱼ" { return "j" }
            return subscriptDigits.firstIndex(of: character).map(String.init) ?? String(character)
        }.joined()
    }
}

struct ModularMultiplicationView: View {
    let solution: DoublingSolution
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Умножаем на числитель").font(.title3.weight(.semibold))
            MathLine(solution.expression)
            BinaryConversionView(conversion: solution.conversionA)
            BinaryConversionView(conversion: solution.conversionB)
            Text(solution.selectionExplanation).font(.footnote).foregroundStyle(.secondary)
            if let special = solution.specialExplanation { Text(special).font(.footnote) }
            if let preparation = solution.preparation { AlgorithmTableView(table: preparation) }
            if let table = solution.table { AlgorithmTableView(table: table) }
            MathLine("\(solution.expression) = \(solution.answer)")
        }
    }
}
