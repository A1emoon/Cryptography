import SwiftUI

/// Every tuple is written from highest degree to the constant coefficient.
struct PolynomialStepView: View {
    let step: PolynomialStep
    let p: Natural
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(step.title).font(.caption).foregroundStyle(.secondary)
            if step.action == .shift {
                math(step.before.vector() + " · (1, 0)")
                math("= " + step.result.vector())
            } else {
                math(step.before.vector(width: step.width))
                if let operand = step.operand {
                    math((step.action == .subtract ? "− " : "+ ") + operand.vector(width: step.width))
                } else {
                    math("× " + step.factor.description)
                }
                Rectangle().fill(AppStyle.line).frame(height: 1)
                math(step.raw.isEmpty ? "(0)" : step.rawVector)
                if step.needsCoefficientReduction {
                    math("≡ " + step.reducedVector).foregroundStyle(AppStyle.accent)
                    Text("Коэффициенты по mod \(p.description)").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }.fixedSize(horizontal: true, vertical: true)
    }
    private func math(_ text: String) -> some View {
        MathText(text: text).fixedSize().padding(.vertical, 3)
    }
}

struct PolynomialTableView: View {
    let solution: PolynomialSolution
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Коэффициенты слева направо · таблица прокручивается", systemImage: "arrow.left.and.right")
                .font(.caption2).foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        Color.clear.frame(width: 88, height: 70)
                            .background(AppStyle.soft).accessibilityHidden(true)
                        ForEach(solution.columns) { column in
                            VStack(alignment: .leading, spacing: 5) {
                                Text("a\(subscriptText(column.exponent)) = \(column.coefficient.description)").font(.caption).foregroundStyle(.secondary)
                                MathText(text: column.addition.vector()).fixedSize().padding(.vertical, 3)
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppStyle.soft)
                                .overlay(alignment: .trailing) { Rectangle().fill(AppStyle.line).frame(width: 1) }
                        }
                    }
                    GridRow {
                        VStack(spacing: 8) {
                            MathText(text: "(1, 0)")
                            Text("× α").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 18).frame(width: 88)
                            .accessibilityIdentifier("polynomialShiftFactor")
                        ForEach(solution.columns) { column in
                            VStack(alignment: .leading, spacing: 16) {
                                if column.steps.isEmpty {
                                    Text("Начальное значение").font(.caption).foregroundStyle(.secondary)
                                }
                                ForEach(column.steps) { step in PolynomialStepView(step: step, p: solution.p) }
                                Divider()
                                MathText(text: column.result.vector()).fixedSize().padding(.vertical, 4)
                                    .foregroundStyle(AppStyle.accent)
                                    .accessibilityIdentifier("polynomialColumnResult_\(column.id)")
                            }.padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .overlay(alignment: .leading) { Rectangle().fill(AppStyle.line).frame(width: 1) }
                        }
                    }.overlay(alignment: .top) { Rectangle().fill(AppStyle.line).frame(height: 1) }
                }.fixedSize()
            }
            .scrollIndicators(.visible)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppStyle.line, lineWidth: 1))
            .accessibilityIdentifier("polynomialTable")
        }
    }
    private func subscriptText(_ n: Int) -> String {
        let digits = Array("₀₁₂₃₄₅₆₇₈₉")
        return String(n).compactMap { $0.wholeNumberValue.map { String(digits[$0]) } }.joined()
    }
}
