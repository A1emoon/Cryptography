import SwiftUI

struct CipollaExplanationView: View {
    let explanation: CipollaExplanation
    var body: some View {
        StudentDetailSheet(title: explanation.title, large: true) {
            MathExplainedText(text: explanation.text)
            ForEach(explanation.formulas.indices, id: \.self) { StudentFormulaView(atoms: explanation.formulas[$0]) }
            MathTermLinks(terms: explanation.terms, identifierPrefix: "cipollaTerm_")
        }
    }
}
struct CipollaCalculationView: View {
    let work: CipollaWork
    let p: Natural
    private var title: String {
        switch work {
        case .normalization: "Приведение по модулю"
        case .symbol: "Вычисление символа"
        case .conversion: "Перевод показателя в двоичную систему"
        case .product: "Умножение в расширении поля"
        case .scalar(let s): s.doubling == nil ? "Приведение произведения" : "Удвоение–сложение"
        }
    }
    var body: some View {
        StudentDetailSheet(title: title, large: true) {
            switch work {
            case .normalization(let s):
                MathLine("\(s.input.magnitude) = \(s.inputQuotient) · \(s.p) + \(s.inputMagnitudeRemainder)")
                if s.input.isNegative && !s.inputMagnitudeRemainder.isZero { MathLine("−\(s.inputMagnitudeRemainder) ≡ \(s.p) − \(s.inputMagnitudeRemainder) = \(s.a) (mod \(s.p))") }
                MathLine("\(s.input) ≡ \(s.a) (mod \(s.p))")
            case .symbol(let trace):
                LegendreTraceView(trace: trace)
                MathTermLinks(terms: [.legendre, .jacobi, .reciprocity, .euler], identifierPrefix: "cipollaSymbolTerm_")
            case .conversion(let conversion): NotebookBinaryConversion(conversion: conversion)
            case .product(let product, let d, let context):
                CipollaProductCalculation(product: product, d: d, p: p, context: context)
            case .scalar(let scalar): CipollaScalarCalculation(work: scalar, p: p)
            }
        }
    }
}
private struct CipollaProductCalculation: View {
    let product: CipollaProduct
    let d: DecimalInteger
    let p: Natural
    let context: String
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StudentFormulaView(atoms: [.text("(\(product.left.expression))(\(product.right.expression))"), .text("(mod \(p)), ω² ≡ \(d)")])
            CipollaStudentLine(line: CipollaLine(id: "expand_" + context, atoms: [.text("="), .text("\(product.left.real) · \(product.right.real) + \(product.left.imaginary) · \(product.right.imaginary)ω²"), .text("+ (\(product.left.real) · \(product.right.imaginary) + \(product.left.imaginary) · \(product.right.real))ω")],
                explanation: CipollaExplanation(title: "Раскрытие скобок", text: "Умножаем каждый член первой скобки на каждый член второй. Вместо ω² подставляем \(d). Свободные члены и коэффициенты при ω считаем отдельно по \(p). Для квадрата суммы два смешанных произведения совпадают, поэтому заменяются на 2uv.", terms: [.extensionField, .coefficient])), p: p)
            ForEach(product.scalars) { scalar in
                CipollaStudentLine(line: CipollaLine(id: "scalar_\(context)_\(scalar.id)", atoms: [.text(scalar.expression), .text("≡"), .text("\(scalar.result) (mod \(p))")],
                    explanation: CipollaExplanation(title: "Вспомогательное произведение", text: "Вычисляем это произведение по \(p). Большие произведения считаем удвоением–сложением, выбирая множитель с меньшим количеством единиц в двоичной записи. Короткие произведения приводим непосредственно. Знак отрицательного представителя учитывается перед выбором неотрицательного остатка.", terms: [.binary, .remainder]), works: [0: .scalar(scalar)]), p: p)
            }
            CipollaStudentLine(line: CipollaLine(id: "collect_" + context,
                atoms: [.text("≡"), .text("(" + product.realTerms.map(\.description).joined(separator: " + ") + ") + (" + product.imaginaryTerms.map(\.description).joined(separator: " + ") + ")ω"), .text("≡"), .text(product.result.expression + " (mod \(p))")], explanation: CipollaExplanation(title: "Собираем результат", text: "Складываем найденные свободные члены, отдельно складываем коэффициенты при ω. Обе суммы приводим по \(p). Если коэффициент при ω стал нулём, остаётся только свободный член.", terms: [.coefficient, .remainder])), p: p)
        }
    }
}
private struct CipollaScalarCalculation: View {
    let work: CipollaScalar
    let p: Natural
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            MathLine("\(work.expression) mod \(p)")
            if let s = work.doubling {
                NotebookBinaryConversion(conversion: s.conversionA)
                if s.a.magnitude != s.b.magnitude { NotebookBinaryConversion(conversion: s.conversionB) }
                MathExplainedText(text: s.selectionExplanation)
                if let preparation = s.preparation { NotebookIntegerTable(table: preparation) }
                if let table = s.table { NotebookIntegerTable(table: table) }
                if let correction = s.signCorrection { MathLine(correction.expression) }
            } else {
                MathLine("\(work.expression) = \(work.product)")
                MathLine("\(work.product.magnitude) = \(work.quotient) · \(p) + \(work.magnitudeRemainder)")
                if work.product.isNegative && !work.magnitudeRemainder.isZero { MathLine("−\(work.magnitudeRemainder) ≡ \(p) − \(work.magnitudeRemainder) = \(work.result) (mod \(p))") }
            }
            MathLine("\(work.expression) ≡ \(work.result) (mod \(p))")
                .accessibilityElement(children: .ignore).accessibilityIdentifier("cipollaScalarResult").accessibilityLabel(work.result.description)
        }
    }
}
