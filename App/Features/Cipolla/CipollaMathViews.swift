import SwiftUI

enum CipollaNotation {
    static func power(_ base: String, _ exponent: Natural) -> String {
        let digits = Array("⁰¹²³⁴⁵⁶⁷⁸⁹")
        return base + exponent.description.compactMap { $0.wholeNumberValue.map { String(digits[$0]) } }.joined()
    }
}
/// Keep the symbolic fraction in the exponent; its value belongs in the explanation.
struct LegendreTraceView: View {
    let trace: LegendreTrace
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(trace.stages) { stage in
                CipollaStudentLine(line: CipollaLine(id: "symbol_stage_\(stage.id)", atoms: atoms(stage),
                    explanation: explanation(stage)), p: trace.modulus)
            }
        }
    }
    private func atoms(_ s: LegendreStage) -> [StudentMathAtom] {
        var result: [StudentMathAtom] = s.id == 0 ? [] : [.text("=")]
        if let terminal = s.terminal { return result + [.text(String(terminal))] }
        if s.sign == -1 { result.append(.text("−")) }
        if let d = s.exponentDerivation { result.append(.fractionPower("(−1)", d.numeratorExpression, d.denominator.description)) }
        else if let e = s.factorExponent { result.append(.power("(−1)", e.description)) }
        if let n = s.numerator, let d = s.denominator { result.append(.symbol(n.description, d.description)) }
        return result
    }
    private func explanation(_ stage: LegendreStage) -> CipollaExplanation {
        var formulas = stage.identities.map { [StudentMathAtom.text($0)] }
        var text = stage.note
        if let d = stage.exponentDerivation, let e = stage.factorExponent {
            formulas += [[.fraction(d.symbolicNumerator, d.denominator.description), .text("="), .fraction(d.numeratorExpression, d.denominator.description), .text("= \(e)")], [.power("(−1)", e.description), .text(e.isOdd ? "= −1" : "= 1")]]
            text += " Показатель \(e) — \(e.isOdd ? "нечётный: знак меняется" : "чётный: знак сохраняется")."
        }
        if stage.id == 0 {
            text += " Это символ, а не дробь для деления. Начальный знаменатель — нечётное простое число. В промежуточных шагах могут возникнуть составные знаменатели: там используется символ Якоби. Для него действуют те же законы преобразования, поэтому значение исходного символа Лежандра сохраняется."
        }
        return CipollaExplanation(title: stage.factorExponent.map { "Откуда степень \($0)" } ?? "Преобразование символа", text: text, formulas: formulas, terms: [.legendre, .jacobi, .reciprocity])
    }
}
