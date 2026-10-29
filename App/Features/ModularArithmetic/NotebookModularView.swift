import SwiftUI

struct NotebookModularView: View {
    let solution: ModularSolution
    private var s: ModularSolution { solution }
    var body: some View {
        NotebookPaper {
            MathLine(s.isDivision ? "(\(s.numerator!) / \(s.input)) mod \(s.modulus)" : "\(s.input)⁻¹ mod \(s.modulus)")
            if s.input != DecimalInteger(s.a) { MathLine("\(s.input) ≡ \(s.a) (mod \(s.modulus))") }
            if let n = s.numerator, n != DecimalInteger(s.target) { MathLine("\(n) ≡ \(s.target) (mod \(s.modulus))") }
            if s.result == nil {
                MathLine("НОД(\(s.a), \(s.modulus)) = \(s.gcdTrace.gcd) ≠ 1")
                Text(s.isDivision ? "Дробь через обратный элемент не определена." : "Обратного элемента нет.")
                if s.isDivision, let last = s.conclusion.last { Text(last) }
            } else {
                if !s.frames.isEmpty {
                    ScrollView(.horizontal) {
                        NotebookFlow(spacing: 14) {
                            ForEach(s.frames) { frame in
                                HStack(alignment: .center, spacing: 10) {
                                    if frame.action != .initial {
                                        if frame.action == .adjust && !s.usesExactRows {
                                            VStack(spacing: 0) {
                                                Text(s.modulus.description).font(.system(.caption, design: .serif))
                                                MathText(text: "≡")
                                            }
                                        } else {
                                            VStack(spacing: 0) {
                                                MathText(text: frame.operation).fixedSize().padding(.vertical, 8)
                                                MathText(text: "∼")
                                            }
                                        }
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        NotebookMatrix(rows: s.method == .powerMatrix && frame.action != .initial
                                                       ? Array(frame.rows.prefix(1)) : frame.rows,
                                                       powers: s.method == .powerMatrix)
                                        if let remaining = frame.remaining {
                                            MathText(text: "≤ \(remaining)").fixedSize().padding(.vertical, 5)
                                        }
                                    }
                                }.fixedSize().accessibilityIdentifier("notebookMatrix_\(frame.id)")
                            }
                        }.padding(.vertical, 10)
                    }
                }
                ForEach(s.lifts) { stage in
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            NotebookCongruence(left: s.a.description, right: stage.baseResidue.description, modulus: stage.modulus)
                            MathText(text: ",")
                            NotebookCongruence(left: "\(stage.baseResidue) · \(stage.previous)", right: stage.residue.description, modulus: stage.modulus)
                            MathText(text: "⇒")
                            NotebookCongruence(left: "\(s.a)⁻¹", right: stage.addition.isZero
                                ? stage.result.description : "\(stage.previous) + \(stage.addition) = \(stage.result)", modulus: stage.modulus)
                        }.fixedSize().padding(.vertical, 8)
                    }.accessibilityIdentifier("notebookLift_\(stage.id)")
                }
                if let inverse = s.inverse, s.lifts.isEmpty { MathLine("\(s.a)⁻¹ ≡ \(inverse) (mod \(s.modulus))") }
                if let multiplication = s.multiplication {
                    MathLine("(\(s.target) · \(s.inverse!)) mod \(s.modulus)")
                    NotebookDoublingWork(solution: multiplication)
                }
                if let result = s.result { NotebookAnswer(text: result.description) }
            }
        }
    }
}
private struct NotebookCongruence: View {
    let left: String
    let right: String
    let modulus: Natural
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 5) {
            MathText(text: left)
            VStack(spacing: 0) {
                Text(modulus.description).font(.system(.caption, design: .serif))
                MathText(text: "≡")
            }
            MathText(text: right)
        }.fixedSize()
    }
}
private struct NotebookMatrix: View {
    let rows: [ModularRow]
    let powers: Bool
    var body: some View {
        Grid(alignment: .trailing, horizontalSpacing: 16, verticalSpacing: 12) {
            ForEach(rows.indices, id: \.self) { i in
                GridRow {
                    math(value(rows[i])).padding(.trailing, 12)
                    math(alpha(rows[i]))
                    if let beta = rows[i].beta { math(beta.description) }
                }
            }
        }.fixedSize().padding(.horizontal, 18).padding(.vertical, 8)
            .background(alignment: .leading) {
                HStack(spacing: 0) {
                    VStack(spacing: 12) { ForEach(rows.indices, id: \.self) { i in math(value(rows[i])) } }
                        .hidden().padding(.leading, 18).padding(.trailing, 6)
                    Rectangle().fill(AppStyle.line).frame(width: 1).padding(.vertical, 8)
                    Spacer(minLength: 0)
                }
            }
            .overlay(alignment: .leading) { MatrixBracket(right: false).stroke(lineWidth: 1.3).frame(width: 8) }
            .overlay(alignment: .trailing) { MatrixBracket(right: true).stroke(lineWidth: 1.3).frame(width: 8) }
    }
    private func math(_ s: String) -> some View { MathText(text: s).fixedSize().padding(.vertical, 4) }
    private func value(_ r: ModularRow) -> String {
        powers ? r.value.powerOfTwoExponent.map(PowerNotation.two) ?? r.value.description : r.value.description
    }
    private func alpha(_ r: ModularRow) -> String {
        if powers, r.value.isZero || r.alpha == DecimalInteger(r.value), r.alpha.magnitude > .one,
           let power = r.alpha.magnitude.powerOfTwoExponent {
            return (r.alpha.isNegative ? "−" : "") + PowerNotation.two(power)
        }
        return r.alpha.description
    }
}
