import SwiftUI

enum RabinFormat {
    static func polynomial(_ p: Polynomial) -> String { p.formula.replacingOccurrences(of: "α", with: "x") }
    static func power(_ base: String, _ n: Natural) -> String {
        let digits = Array("⁰¹²³⁴⁵⁶⁷⁸⁹")
        return base + n.description.compactMap { $0.wholeNumberValue.map { String(digits[$0]) } }.joined()
    }
    static func index(_ n: String) -> String {
        let digits = Array("₀₁₂₃₄₅₆₇₈₉")
        return n.compactMap { $0.wholeNumberValue.map { String(digits[$0]) } }.joined()
    }
    static func g(_ id: Int) -> String { "g" + index(String(id)) }
    static func signed(_ descending: [DecimalInteger]) -> String {
        let ascending = Array(descending.reversed())
        let terms = ascending.indices.reversed().compactMap { i -> (Bool, String)? in
            let c = ascending[i]
            guard !c.magnitude.isZero else { return nil }
            let x = i == 0 ? "" : i == 1 ? "x" : power("x", Natural(UInt64(i)))
            let term = i == 0 || c.magnitude != .one ? c.magnitude.description + x : x
            return (c.isNegative, term)
        }
        return terms.enumerated().map { i, term in
            (i == 0 ? (term.0 ? "−" : "") : (term.0 ? " − " : " + ")) + term.1
        }.joined().isEmpty ? "0" : terms.enumerated().map { i, term in
            (i == 0 ? (term.0 ? "−" : "") : (term.0 ? " − " : " + ")) + term.1
        }.joined()
    }
    static func answer(_ s: RabinSolution) -> String {
        if s.outcome == .allResidues { return "ℤ" + index(s.q.description) }
        if s.roots.isEmpty { return "∅" }
        let values = s.roots.map { "[\($0)]" + index(s.q.description) }
        return values.count == 1 ? values[0] : "{ " + values.joined(separator: ", ") + " }"
    }
}
struct RabinExplanation {
    let title: String
    let text: String
    var equations: [String] = []
    var terms: [RabinTerm] = []
}
enum RabinWork {
    case input(RabinSolution)
    case normalization(FieldNormalization)
    case power(FieldPower)
    case fermat(FieldPower, FieldNormalization)
    case product(FieldPower, FieldPowerStep)
    case gcd(FieldGCD)
    case division(FieldDivision)
    case verification(RabinVerification)
}
struct RabinLine: Identifiable {
    let id: String
    let atoms: [StudentMathAtom]
    let explanation: RabinExplanation
    var work: RabinWork? = nil
    var workIndices: Set<Int> = [0]
    var workOverrides: [Int: RabinWork] = [:]
    init(_ id: String, _ pieces: [String], _ explanation: RabinExplanation, work: RabinWork? = nil, indices: Set<Int> = [0]) {
        self.id = id; atoms = pieces.map { .text($0) }; self.explanation = explanation; self.work = work; workIndices = indices
    }
    init(_ id: String, atoms: [StudentMathAtom], explanation: RabinExplanation, work: RabinWork? = nil, indices: Set<Int> = [0]) {
        self.id = id; self.atoms = atoms; self.explanation = explanation; self.work = work; workIndices = indices
    }
}
enum RabinPresentation {
    static func lines(_ s: RabinSolution) -> [RabinLine] {
        let f = RabinFormat.polynomial
        let q = s.q.description
        let changed = s.normalization.before != s.normalization.result
        let name = changed || s.zeroMultiplicity > 0 ? "F" : "f"
        var lines: [RabinLine] = []
        lines.append(RabinLine("task", ["f(x) =", RabinFormat.signed(s.raw), "≡ 0 (mod \(q))"],
            RabinExplanation(title: "Что требуется найти", text: "Нужны все классы остатков x, для которых многочлен f(x) обращается в ноль по простому модулю q. Коэффициенты можно сразу заменить их остатками: множество корней не меняется.", terms: [.polynomial, .root, .remainder]), work: .input(s), indices: [1]))
        if s.raw != s.input.coefficients.reversed().map(DecimalInteger.init) {
            lines.append(RabinLine("coefficients", ["f(x) ≡", f(s.input), "(mod \(q))"],
                RabinExplanation(title: "Приведение коэффициентов", text: "Каждый коэффициент заменяем неотрицательным остатком по q. Нулевые старшие коэффициенты убираем. Это не меняет ни одного значения f(x) по модулю q.", terms: [.remainder, .leading]), work: .input(s), indices: [1]))
        }
        lines.append(RabinLine("field", ["\(q) ∈ ℙ;", "f(0) ≡ \(s.input[0]) (mod \(q))"],
            RabinExplanation(title: "Первые проверки", text: "q должно быть простым числом, чтобы коэффициенты образовывали поле и деление на ненулевой коэффициент было возможно. Значение f(0) равно свободному члену. Нулевой корень проверяем отдельно: многочлен Ферма содержит только ненулевые корни.", terms: [.prime, .finiteField, .root, .fermat])))
        if s.outcome == .allResidues {
            lines.append(RabinLine("all", ["f(x) ≡ 0", "∀x ∈ ℤ" + RabinFormat.index(q)],
                RabinExplanation(title: "Тождественный ноль", text: "После приведения все коэффициенты равны нулю. Поэтому подстановка любого остатка даёт ноль. В ответе записываем всё поле, не перечисляя его элементы.", terms: [.polynomial, .finiteField])))
            return lines
        }
        if s.outcome == .binaryField {
            for i in s.binaryValues.indices {
                lines.append(RabinLine("binary_\(i)", ["f(\(i)) ≡ \(s.binaryValues[i]) (mod 2)"],
                    RabinExplanation(title: "Поле из двух элементов", text: "По модулю 2 существуют только два остатка: 0 и 1. Проверяем оба непосредственно. Формула с показателем (q−1)/2 для нечётного поля здесь не применяется.", terms: [.finiteField, .root])))
            }
            return lines
        }
        if s.input.degree == 0 {
            lines.append(RabinLine("constant", ["\(s.input[0]) ≢ 0 (mod \(q))", "Z(f) = ∅"],
                RabinExplanation(title: "Ненулевая константа", text: "У ненулевого постоянного многочлена нет корней: значение не зависит от x и не равно нулю по q.", terms: [.polynomial, .root])))
            return lines
        }
        if changed {
            lines.append(RabinLine("normalize", ["f(x) ≡ 0", "⇔", f(s.normalization.result) + " ≡ 0 (mod \(q))"],
                RabinExplanation(title: "Старший коэффициент 1", text: "Умножаем многочлен на обратный элемент к старшему коэффициенту. Этот элемент ненулевой, поэтому равносильность сравнения сохраняется.", terms: [.monic, .inverse, .leading]), work: .normalization(s.normalization), indices: [2]))
        }
        if s.zeroMultiplicity > 0 {
            lines.append(RabinLine("zero", ["x₀ ≡ 0 (mod \(q))", "f(x) ≡", "\(s.input.leading == .one ? "" : s.input.leading.description + " · ")" + RabinFormat.power("x", Natural(UInt64(s.zeroMultiplicity))) + "(\(f(s.residual)))"],
                RabinExplanation(title: "Не потерять нулевой корень", text: "Свободный член равен нулю. Выносим все множители x, запоминаем корень 0 и дальше ищем ненулевые корни оставшегося многочлена. Кратность не добавляет новых классов решений.", terms: [.root, .factor, .multiplicity])))
        }
        if name == "F", s.residual.degree > 0 {
            lines.append(RabinLine("residual", ["F(x) =", f(s.residual)],
                RabinExplanation(title: "Оставшаяся задача", text: "F — нормированный многочлен после удаления возможного множителя x. У него остались те же ненулевые корни, что у исходного f.", terms: [.monic, .factor, .root])))
        }
        if let power = s.power, let gcd = s.initialGCD {
            lines.append(RabinLine("gcd", ["g₁ =", "(\(name), " + RabinFormat.power("x", power.exponent) + " − 1)", "=", "(\(name), \(f(gcd.initialB.result)))", "=", f(gcd.result)],
                RabinExplanation(title: "Почему ищем НОД", text: "НОД содержит общие корни двух многочленов. У \(RabinFormat.power("x", s.q - .one)) − 1 ровно все ненулевые элементы поля и нет повторных корней. Поэтому g₁ сохраняет все ненулевые корни f, каждый один раз. Находим НОД алгоритмом Евклида; деление уголком вынесено в отдельное окно.", terms: [.gcd, .fermat, .euclid, .multiplicity]), work: .gcd(gcd), indices: [1,3]))
            lines[lines.count - 1].workOverrides[1] = .fermat(power, gcd.initialB)
            if gcd.result.degree == 0 {
                lines.append(RabinLine("no_nonzero", ["g₁ = 1", "⇒", s.zeroMultiplicity > 0 ? "Z(f) = {0}" : "Z(f) = ∅"],
                    RabinExplanation(title: "Что означает НОД 1", text: "Общих линейных множителей нет: ненулевых корней у исходного многочлена нет. Если ранее найден нулевой корень, он остаётся в ответе.", terms: [.gcd, .factor, .root])))
            }
        }
        if !s.splits.isEmpty {
            lines.append(RabinLine("split_exponent", atoms: [.text("s ="), .fraction("\(q) − 1", "2"), .text("= \((s.q - .one).halved())")],
                explanation: RabinExplanation(title: "Почему половина q − 1", text: "В нечётном поле половина показателя q − 1 позволяет различать ненулевые квадратичные вычеты и невычеты: результат равен 1 или −1. Сдвиг x + δ меняет распределение корней между этими группами. НОД с многочленом (x + δ) в степени s минус 1 выбирает группу со значением 1.", terms: [.quadraticResidue, .degree, .finiteField])))
        }
        for split in s.splits {
            let g = RabinFormat.g(split.factorID), base = split.delta.isZero ? "x" : "(x + \(split.delta))"
            lines.append(RabinLine("split_gcd_\(split.id)", ["δ = \(split.delta):", "h =", "(\(g), " + RabinFormat.power(base, split.power.exponent) + " − 1)", "=", "(\(g), \(f(split.testPolynomial)))", "=", f(split.gcd.result)],
                RabinExplanation(title: split.didSplit ? "Получен собственный множитель" : "Почему меняем δ", text: split.didSplit
                    ? "Степень h положительна и меньше степени текущего g. Это нетривиальное разделение. Делим g на h и продолжаем для обеих частей, чтобы не потерять ни одного корня."
                    : "НОД равен 1 или всему текущему g. В обоих случаях задача не разделилась. Увеличиваем δ и пробуем снова — условие h ≠ 1 само по себе недостаточно.", terms: [.gcd, .factor, .degree]), work: .gcd(split.gcd), indices: [2,4]))
            lines[lines.count - 1].workOverrides[2] = .power(split.power)
            if let division = split.cofactor {
                lines.append(RabinLine("split_factor_\(split.id)", ["\(g) =", "(\(f(split.gcd.result)))(\(f(division.quotient)))", ";", "\(RabinFormat.g(split.childIDs[0])) = \(f(split.gcd.result))", ";", "\(RabinFormat.g(split.childIDs[1])) = \(f(division.quotient))"],
                    RabinExplanation(title: "Обе ветви разложения", text: "Вторая часть — точное частное g/h. Остаток деления равен нулю. Ищем корни обеих частей; в конце получатся линейные множители.", terms: [.factor, .remainder, .root]), work: .division(division), indices: [1]))
            }
        }
        for linear in s.linearRoots {
            lines.append(RabinLine("root_\(linear.id)", [f(linear.factor) + " ≡ 0", "⇒", "x ≡ −\(linear.factor[0]) ≡ \(linear.root) (mod \(q))"],
                RabinExplanation(title: "Из линейного множителя — корень", text: "У нормированного линейного множителя x + c корень равен −c. Приводим его к остатку от 0 до q−1. Каждый корень означает весь класс r + kq, а не только одно целое число.", terms: [.monic, .root, .remainder])))
        }
        for v in s.verification {
            lines.append(RabinLine("check_\(v.id)", ["f(\(v.root))", "≡ \(v.steps.last?.sum ?? .zero)", "≡ 0 (mod \(q))"],
                RabinExplanation(title: "Проверка подстановкой", text: "Подставляем найденный корень именно в исходный многочлен, до нормирования и удаления множителей x. Схема Горнера позволяет выполнить проверку отдельной цепочкой; промежуточные остатки не меняют итог по q.", terms: [.horner, .root, .remainder]), work: .verification(v), indices: [0]))
        }
        return lines
    }
}
