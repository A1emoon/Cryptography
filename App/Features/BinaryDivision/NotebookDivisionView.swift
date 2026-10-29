import SwiftUI

struct NotebookDivisionView: View {
    let solution: BinaryDivisionSolution
    private var s: BinaryDivisionSolution { solution }
    var body: some View {
        NotebookPaper {
            MathLine("\(s.a) : \(s.b)")
            if s.dividendLength.number.isZero {
                MathLine("0 = \(s.b) · 0 + 0")
            } else {
                MathLine("l₂(\(s.dividendLength.number)) = \(s.dividendLength.length);  \(PowerNotation.two(s.dividendLength.length - 1)) ≤ \(s.dividendLength.number) < \(PowerNotation.two(s.dividendLength.length))")
                MathLine("l₂(\(s.divisorLength.number)) = \(s.divisorLength.length)")
                if let first = s.steps.first {
                    MathLine("l = \(first.before.length) − \(s.divisorLength.length) = \(first.lengthDifference)")
                    if first.lengthDifference > 0 { MathLine("l − 1 = \(first.lengthDifference - 1)") }
                    chain
                    ScrollView(.horizontal) {
                        NotebookFlow {
                            HStack {
                                FloorFractionView(numerator: s.a.magnitude.description, denominator: s.b.magnitude.description)
                                MathText(text: "=")
                            }.fixedSize()
                            ForEach(s.steps) { step in
                                if step.chosen.id != 0 {
                                    HStack(spacing: 8) {
                                        FloorFractionView(numerator: subtraction(step), denominator: s.b.magnitude.description)
                                        MathText(text: "+ " + sum(through: step.id) + " =")
                                    }.fixedSize()
                                }
                                HStack(spacing: 8) {
                                    FloorFractionView(numerator: step.after.description, denominator: s.b.magnitude.description)
                                    MathText(text: "+ " + (step.id == s.steps.count - 1 ? step.quotientAfter.description : sum(through: step.id)) + (step.id == s.steps.count - 1 ? "" : " ="))
                                }.fixedSize()
                            }
                        }.frame(minWidth: 300, alignment: .leading).padding(.vertical, 8)
                    }
                } else { MathLine("\(s.a.magnitude) < \(s.b.magnitude)") }
                if s.needsRemainderCorrection {
                    MathLine("\(s.b.magnitude) − \(s.magnitudeRemainder) = \(s.remainder)")
                    MathLine("q = \(s.quotient)")
                }
            }
            NotebookAnswer(text: s.identity)
        }
    }
    private func subtraction(_ step: DivisionStep) -> String {
        step.id == 0 ? "\(step.before.number) − \(PowerNotation.two(step.chosen.id)) · \(s.b.magnitude)"
            : "\(step.before.number) − \(step.chosen.multiple)"
    }
    private func sum(through index: Int) -> String {
        s.steps.prefix(index + 1).map { PowerNotation.two($0.chosen.id) }.joined(separator: " + ")
    }
    private var chain: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(s.shifts.filter { $0.multiple <= s.a.magnitude }) { shift in
                    if shift.id > 0 {
                        VStack(spacing: 0) {
                            Text(String(shift.id)).font(.caption2)
                            Text("<<").font(.caption)
                            Text("→").font(.title3)
                        }
                    }
                    MathText(text: shift.multiple.description)
                }
                MathText(text: "≤ \(s.a.magnitude)")
            }.fixedSize().padding(.vertical, 6)
        }
    }
}
