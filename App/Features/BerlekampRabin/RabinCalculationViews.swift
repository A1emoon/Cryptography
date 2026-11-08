import SwiftUI

struct RabinExplanationView: View {
    let explanation: RabinExplanation
    var body: some View {
        StudentDetailSheet(title: explanation.title, large: true) {
            RabinExplainedText(text: explanation.text)
            ForEach(explanation.equations.indices, id: \.self) { MathLine(explanation.equations[$0]) }
            RabinTermLinks(terms: explanation.terms)
        }
    }
}
struct RabinCalculationView: View {
    let work: RabinWork
    let q: Natural
    private var title: String {
        switch work {
        case .input: "Коэффициенты исходного многочлена"
        case .normalization: "Приведение к старшему коэффициенту 1"
        case .power, .fermat: "Вспомогательное вычисление степени"
        case .product: "Удвоение–сложение для многочленов"
        case .gcd: "НОД: деление уголком"
        case .division: "Деление многочленов уголком"
        case .verification: "Проверка подстановкой"
        }
    }
    var body: some View {
        StudentDetailSheet(title: title, large: true) { content }
    }
    @ViewBuilder private var content: some View {
        switch work {
        case .input(let s):
            RabinExplainedText(text: "Коэффициенты вводятся от старшей степени к свободному члену. Приведение каждого коэффициента по q сохраняет все корни сравнения.")
            MathLine("f = (" + s.raw.map(\.description).joined(separator: ", ") + ")")
            ForEach(s.raw.indices, id: \.self) { i in
                let coefficient = s.raw[i], residue = s.input[s.raw.count - 1 - i]
                if coefficient != DecimalInteger(residue) {
                    MathLine("\(coefficient) ≡ \(residue) (mod \(q))")
                }
            }
            MathLine("f(x) ≡ " + RabinFormat.polynomial(s.input) + " (mod \(q))")
            RabinTermLinks(terms: [.polynomial, .leading, .remainder])
        case .normalization(let normalization):
            RabinNormalizationView(normalization: normalization, q: q)
        case .power(let power): RabinPowerCalculation(power: power, q: q)
        case .fermat(let power, let normalization):
            RabinPowerCalculation(power: power, q: q)
            Divider()
            MathLine(RabinFormat.power("x", power.exponent) + " − 1 ≡ " + RabinFormat.polynomial(normalization.before))
            RabinNormalizationView(normalization: normalization, q: q)
        case .product(let power, let step):
            MathLine(RabinFormat.power("(\(RabinFormat.polynomial(power.base)))", step.exponent)
                + " ≡ (\(RabinFormat.polynomial(step.left)))(\(RabinFormat.polynomial(step.right)))")
            RabinPolynomialProduct(power: power, step: step, q: q)
        case .gcd(let gcd):
            RabinExplainedText(text: "Находим НОД алгоритмом Евклида. В каждом делении остаток имеет меньшую степень. Ненулевой остаток разрешено нормировать: умножение на обратный элемент к старшему коэффициенту не меняет общие делители.")
            RabinTermLinks(terms: [.gcd, .euclid, .monic])
            if gcd.initialA.before != gcd.initialA.result { RabinNormalizationView(normalization: gcd.initialA, q: q) }
            if gcd.initialB.before != gcd.initialB.result { RabinNormalizationView(normalization: gcd.initialB, q: q) }
            ForEach(gcd.divisions.indices, id: \.self) { i in
                RabinLongDivisionView(division: gcd.divisions[i], q: q)
                let normalization = gcd.normalizations[i]
                if !normalization.before.isZero && normalization.before != normalization.result {
                    RabinNormalizationView(normalization: normalization, q: q)
                }
                Divider()
            }
            MathLine("НОД = " + RabinFormat.polynomial(gcd.result))
                .accessibilityElement(children: .ignore).accessibilityIdentifier("rabinGCDResult")
                .accessibilityLabel(RabinFormat.polynomial(gcd.result))
        case .division(let division): RabinLongDivisionView(division: division, q: q)
        case .verification(let v):
            RabinExplainedText(text: "Подставляем корень в исходный многочлен по схеме Горнера. После каждого умножения и сложения берём остаток; в конце должен получиться ноль.")
            RabinTermLinks(terms: [.horner, .root, .remainder])
            ForEach(v.steps) { step in
                MathLine("\(step.before) · \(v.root) + \(step.coefficient) = \(step.sum) ≡ \(step.result) (mod \(q))")
            }
            MathLine("f(\(v.root)) ≡ \(v.value) (mod \(q))")
        }
    }
}
struct RabinNormalizationView: View {
    let normalization: FieldNormalization
    let q: Natural
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if normalization.before.isZero { MathLine("0") }
            else if normalization.before == normalization.result {
                MathLine(RabinFormat.polynomial(normalization.result))
                RabinExplainedText(text: "Многочлен уже нормирован: старший коэффициент равен 1.")
            } else {
                RabinExplainedText(text: "Умножаем на обратный элемент к старшему коэффициенту. Любой ненулевой множитель-константа обратим в поле, поэтому корни и НОД от такого преобразования не меняются.")
                MathLine("\(normalization.before.leading) · \(normalization.inverse) ≡ 1 (mod \(q))")
                MathLine("\(normalization.inverse)(\(RabinFormat.polynomial(normalization.before))) ≡ \(RabinFormat.polynomial(normalization.result)) (mod \(q))")
                RabinTermLinks(terms: [.monic, .inverse, .gcd])
            }
        }
    }
}
struct RabinLongDivisionView: View {
    let division: FieldDivision
    let q: Natural
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .trailing, spacing: 8) {
                        MathText(text: RabinFormat.polynomial(division.dividend)).padding(.bottom, 4)
                        ForEach(division.steps) { step in
                            MathText(text: "− (" + RabinFormat.polynomial(step.multiple) + ")")
                            Rectangle().frame(height: 1)
                            let raw = RabinFormat.signed(Array(step.difference.reversed()))
                            MathText(text: raw)
                            if step.difference.enumerated().contains(where: { $0.element != DecimalInteger(step.result[$0.offset]) }) {
                                MathText(text: "≡ " + RabinFormat.polynomial(step.result))
                            }
                        }
                    }.fixedSize()
                    Rectangle().frame(width: 1, height: 85)
                    VStack(alignment: .leading, spacing: 9) {
                        MathText(text: RabinFormat.polynomial(division.divisor))
                        Rectangle().frame(height: 1)
                        MathText(text: RabinFormat.polynomial(division.quotient))
                    }.fixedSize()
                }.padding(.vertical, 8)
            }.accessibilityIdentifier("rabinLongDivision")
            MathLine("\(RabinFormat.polynomial(division.dividend)) = (\(RabinFormat.polynomial(division.divisor)))(\(RabinFormat.polynomial(division.quotient))) + (\(RabinFormat.polynomial(division.remainder)))  (mod \(q))")
        }
    }
}
struct RabinPowerCalculation: View {
    let power: FieldPower
    let q: Natural
    @State private var selected: FieldPowerStep?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RabinExplainedText(text: "Степень вычисляется бинарно. Находим меньшую степень, возводим её остаток в квадрат и, если показатель нечётный, умножаем ещё на основание. Каждый результат приводится по многочлену-модулю и по q. Любое умножение открывается отдельно.")
            if let conversion = try? BinaryConversion(number: power.exponent) { NotebookBinaryConversion(conversion: conversion) }
            if !power.preparation.steps.isEmpty { RabinLongDivisionView(division: power.preparation, q: q) }
            ForEach(power.steps) { step in
                HStack(spacing: 8) {
                    MathLine(RabinFormat.power("(\(RabinFormat.polynomial(power.base)))", step.exponent) + " ≡ " + RabinFormat.polynomial(step.result))
                    Button { selected = step } label: {
                        Image(systemName: "arrow.up.right.square").frame(width: 38, height: 38)
                    }.buttonStyle(.plain).foregroundStyle(AppStyle.accent)
                        .accessibilityLabel("Умножение для степени \(step.exponent.description)")
                        .accessibilityIdentifier("rabinPowerProduct_\(step.id)")
                }
            }
            MathLine(RabinFormat.power("(\(RabinFormat.polynomial(power.base)))", power.exponent) + " ≡ " + RabinFormat.polynomial(power.result) + " (mod (\(RabinFormat.polynomial(power.modulus))), \(q))")
                .accessibilityIdentifier("rabinPowerResult")
            RabinTermLinks(terms: [.degree, .remainder, .polynomial])
        }.sheet(item: $selected) { step in RabinCalculationView(work: .product(power, step), q: q) }
    }
}
struct RabinPolynomialProduct: View {
    let power: FieldPower
    let step: FieldPowerStep
    let q: Natural
    @State private var table: PolynomialSolution?
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let table {
                NotebookPolynomialView(solution: table, variable: "x")
                CourseDisclosureGroup("Как получены верхние ячейки") {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(table.columns) { column in
                            ScrollView(.horizontal) { PolynomialStepView(step: column.scaling, p: q) }
                        }
                    }.padding(.vertical, 12)
                }.font(.callout)
                RabinExplainedText(text: "В таблице (1, 0) означает умножение на x: добавляем нулевой коэффициент справа. После сдвига вычитаем подходящий множитель многочлена-модуля, затем прибавляем верхнюю ячейку. Коэффициенты берём по q.")
                RabinTermLinks(terms: [.polynomial, .remainder, .factor])
            } else if let error { Text(error).foregroundStyle(.red) }
            else { ProgressView("Строим таблицу вычисления…") }
        }.task {
            let a = step.left.vector(), b = step.right.vector(), m = power.modulus.vector(), p = q.description
            let worker = Task.detached(priority: .userInitiated) {
                try PolynomialSolver.solve(a: a, b: b, m: m, p: p, check: { try Task.checkCancellation() })
            }
            await withTaskCancellationHandler {
                do { let value = try await worker.value; try Task.checkCancellation(); table = value }
                catch is CancellationError {} catch { self.error = error.localizedDescription }
            } onCancel: { worker.cancel() }
        }
    }
}
