import SwiftUI

struct NotebookPolynomialView: View {
    let solution: PolynomialSolution
    var variable = "α"
    private var s: PolynomialSolution { solution }
    var body: some View {
        NotebookPaper {
            MathLine(s.expression.replacingOccurrences(of: "α", with: variable))
            ForEach([s.a, s.b, s.m], id: \.name) { input in
                MathLine("\(input.name) = \(input.polynomial.vector(width: max(s.m.polynomial.coefficients.count, input.polynomial.coefficients.count)))")
            }
            if !s.preparation.isEmpty {
                MathLine("\(s.baseName) ≡ \(s.base.vector()) (mod M, \(s.p))")
            }
            NotebookPolynomialTable(solution:s)
            NotebookAnswer(text: s.result.formula.replacingOccurrences(of: "α", with: variable))
        }
    }
    private func math(_ text: String) -> some View { MathText(text: text).fixedSize().padding(.vertical, 3) }
}

struct NotebookPolynomialTable:View {
 @State private var scaling:PolynomialStep?
 let solution:PolynomialSolution
 private var s:PolynomialSolution{solution}
 var body:some View {
ScrollView(.horizontal) {
                Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        Color.clear.frame(width: 85, height: 45)
                        ForEach(s.columns) { column in
                            Button{scaling=column.scaling}label:{HStack(spacing:4){math(column.addition.vector());Image(systemName:"arrow.up.right.square").font(.system(size:10)).foregroundStyle(AppStyle.accent)}}.buttonStyle(.plain).accessibilityLabel("Вычислить верхнюю ячейку: \(column.coefficient) · \(s.base.vector())").accessibilityIdentifier("polynomialScale_\(column.id)").padding(12)
                        }
                    }
                    GridRow {
                        math("(1, 0)").padding(12)
                        ForEach(s.columns) { column in
                            VStack(alignment: .trailing, spacing: 8) {
                                if column.steps.isEmpty { math(column.result.vector()) }
                                ForEach(column.steps) { step in
                                    if step.action == .shift { math(step.result.vector()) }
                                    else if let operand = step.operand {
                                        math((step.action == .subtract ? "− " : "+ ") + operand.vector(width: step.width))
                                        Divider()
                                        if step.needsCoefficientReduction {math(step.rawVector)}
                                        math(step.result.vector())
                                    }
                                }
                            }.fixedSize().padding(12)
                                .overlay(alignment: .leading) { Rectangle().fill(AppStyle.line).frame(width: 1) }
                        }
                    }.overlay(alignment: .top) { Rectangle().fill(AppStyle.line).frame(height: 1) }
                }.fixedSize().padding(.vertical, 6)
            }.accessibilityIdentifier("notebookPolynomialTable")
            .sheet(item:$scaling){step in StudyWorkView(work:.equations("Подготовка верхней ячейки",["\(step.factor) · \(s.base.vector())",step.rawVector,"≡ \(step.reducedVector) (mod \(s.p))"]))}

}
 private func math(_ text:String)->some View{MathText(text:text).fixedSize().padding(.vertical,3)}
}
