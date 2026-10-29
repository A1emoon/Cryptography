import SwiftUI

struct CipollaExplanation {
    let title: String
    let text: String
    var formulas: [[StudentMathAtom]] = []
    var terms: [MathTerm] = []
}
enum CipollaWork {
    case normalization(CipollaSolution)
    case symbol(LegendreTrace)
    case conversion(BinaryConversion)
    case product(CipollaProduct, DecimalInteger, String)
    case scalar(CipollaScalar)
}
struct CipollaLine: Identifiable {
    let id: String
    let atoms: [StudentMathAtom]
    let explanation: CipollaExplanation
    var works: [Int: CipollaWork] = [:]
}
enum CipollaPresentation {
    static func answer(_ s: CipollaSolution) -> String {
        if s.roots.isEmpty { return "Решений нет" }
        if s.roots.count == 1 { return "x ≡ \(s.roots[0]) (mod \(s.p))" }
        return "x₁ ≡ \(s.roots[0]), x₂ ≡ \(s.roots[1]) (mod \(s.p))"
    }
    static func rootsReason(_ s: CipollaSolution) -> CipollaExplanation {
        let text: String
        if s.roots.isEmpty { text = "Символ Лежандра равен −1, поэтому a — квадратичный невычет. По этому простому модулю решений нет." }
        else if s.a.isZero { text = "По простому модулю квадрат равен нулю только у нулевого остатка. Запись x ≡ 0 включает все целые числа, кратные p." }
        else if s.p == Natural(2) { text = "По модулю 2 квадрат совпадает с самим остатком: x² ≡ x. Поэтому существует один класс решений — остаток a по 2." }
        else {
            let t = s.combinations.last?.result.real ?? s.chosenDelta ?? s.roots[0]
            text = "Получен корень \(t). Противоположный ему остаток тоже является корнем: \(s.p) − \(t) = \(s.p - t). У ненулевого квадратичного вычета по нечётному простому модулю ровно два различных корня. В ответе они упорядочены по возрастанию. Каждая запись сравнения задаёт целый класс остатков."
        }
        return CipollaExplanation(title: "Почему такой ответ", text: text, terms: [.root, .residueClass, .quadraticResidue])
    }
    static func lines(_ s: CipollaSolution) -> [CipollaLine] {
        let p = s.p.description
        var rows: [CipollaLine] = [CipollaLine(id: "task", atoms: [.text("x² ≡ \(s.input) (mod \(p))")],
            explanation: CipollaExplanation(title: "Что требуется найти", text: "Ищем все целые x, квадрат которых сравним с a = \(s.input) по простому модулю p = \(p). В ответе достаточно указать наименьшие неотрицательные представители классов остатков.", terms: [.congruence, .root, .prime]))]
        rows.append(CipollaLine(id: "prime", atoms: [.text("\(p) ∈ ℙ")], explanation: CipollaExplanation(title: "Условие на модуль", text: "Модуль \(p) проверен на простоту. Остатки по простому модулю образуют конечное поле. ℙ обозначает множество простых чисел. При p = 2 используем отдельный случай, без формулы для нечётного p.", terms: [.prime, .finiteField])))
        if s.input != DecimalInteger(s.a) {
            rows.append(CipollaLine(id: "normalize", atoms: [.text("\(s.input)"), .text("≡"), .text("\(s.a) (mod \(p))")],
                explanation: CipollaExplanation(title: "Почему заменяем a", text: "Замена числа его остатком не меняет сравнение. Для отрицательного a выбираем неотрицательный остаток: если остаток модуля числа ненулевой, вычитаем его из p.", terms: [.remainder, .congruence]), works: [0: .normalization(s)]))
        }
        if let symbol = s.symbol {
            rows.append(CipollaLine(id: "legendre", atoms: [.symbol(s.a.description, p), .text("="), .text(String(symbol.value))],
                explanation: CipollaExplanation(title: "Проверка разрешимости", text: symbol.value == 1 ? "Символ Лежандра равен 1: a — ненулевой квадратичный вычет, существуют два корня. Вычисление символа по закону квадратичной взаимности открывается у самого символа." : "Символ Лежандра равен −1: a — квадратичный невычет. Корней нет, дальнейший подбор δ не требуется.", terms: [.legendre, .quadraticResidue, .reciprocity]), works: [0: .symbol(symbol)]))
        }
        if let raw = s.deltaInput, let delta = s.chosenDelta, raw != DecimalInteger(delta) {
            rows.append(CipollaLine(id: "delta_normalize", atoms: [.text("δ = \(raw) ≡ \(delta) (mod \(p))")], explanation: CipollaExplanation(title: "Приведение заданного δ", text: "Вручную заданное δ заменяем его неотрицательным остатком по p. Квадрат и символ Лежандра по p от этого не меняются.", terms: [.remainder, .legendre])))
        }
        for c in s.candidates {
            let result = c.symbol.value
            let decision = result == -1 ? "Получили −1: разность является квадратичным невычетом. Выбираем это δ для построения расширения поля." : result == 0 ? "Разность кратна p, поэтому δ уже является корнем. Расширение поля не требуется." : "Получили 1: разность — ненулевой квадратичный вычет. Такое δ не подходит; при автоматическом подборе переходим к следующему."
            let source = s.deltaInput == nil ? "Перебираем δ = 0, 1, 2… по порядку. " : "Это δ задано вручную. "
            rows.append(CipollaLine(id: "candidate_\(c.id)", atoms: [.text("δ = \(c.delta):"), .symbol("\(c.delta)² − \(s.a)", p), .text("="), .symbol(c.difference.description, p), .text("="), .text(String(result))],
                explanation: CipollaExplanation(title: result == -1 ? "Почему выбираем δ = \(c.delta)" : "Проверка δ = \(c.delta)", text: source + decision,
                    formulas: [[.text("\(c.delta)² − \(s.a) = \(c.square) − \(s.a) = \(c.difference)")]], terms: [.legendre, .quadraticResidue, .extensionField]), works: [3: .symbol(c.symbol)]))
        }
        if let d = s.omegaSquare, let e = s.exponent, let conversion = s.conversion, let first = s.powers.first {
            let basis = "(\(first.result.expression))"
            rows.append(CipollaLine(id: "omega", atoms: [.text("ω² ≡ \(s.chosenDelta!)² − \(s.a) ≡ \(d) (mod \(p))")],
                explanation: CipollaExplanation(title: "Откуда ω² = \(d)", text: "Вводим элемент ω с условием ω² = δ² − a. Для выбранного δ это квадратичный невычет, поэтому ω принадлежит квадратичному расширению поля. Отрицательный представитель \(d) допустим: он даёт тот же остаток и упрощает вычисления.", terms: [.extensionField, .quadraticResidue, .remainder])))
            rows.append(CipollaLine(id: "exponent", atoms: [.text("x₁,₂ ≡ ±"), .fractionPower(basis, "\(p) + 1", "2"), .text("≡"), .text("±" + CipollaNotation.power(basis, e) + " (mod \(p))")],
                explanation: CipollaExplanation(title: "Почему показатель \(e)", text: "В Чиполле берём (p+1)/2. В расширении поля ωᵖ = −ω, поэтому (δ+ω)ᵖ = δ−ω. Норма δ+ω равна a, значит квадрат результата этой степени равен a. Так как a — квадратичный вычет, результат степени принадлежит исходному полю: коэффициент при ω равен нулю.", formulas: [[.fraction("\(p) + 1", "2"), .text("= \(e)")], [.power("(δ + ω)", "p + 1"), .text("= (δ + ω)(δ − ω) = δ² − ω² = a")]], terms: [.extensionField, .conjugate, .quadraticResidue])))
            let selected = s.powers.reversed().filter(\.selected)
            rows.append(CipollaLine(id: "binary", atoms: [.text(e.description), .text("="), .text(conversion.binary + "₂"), .text("=")] + selected.enumerated().map { .text(($0.offset == 0 ? "" : "+ ") + $0.element.exponent.description) }, explanation: CipollaExplanation(title: "Какие степени нужны", text: "Переводим показатель в двоичную систему. Единицы указывают, какие последовательные квадраты нужно перемножить. При умножении степеней одного основания показатели складываются. Полный перевод делением пополам открывается у двоичной записи.", terms: [.binary, .degree]), works: [2: .conversion(conversion)]))
            for power in s.powers {
                guard let product = power.product else { continue }
                rows.append(CipollaLine(id: "power_\(power.id)", atoms: [.power(basis, power.exponent.description), .text("≡"), .text("(\(product.left.expression))²"), .text("≡"), .text(product.result.expression + " (mod \(p))")], explanation: CipollaExplanation(title: "Степень \(power.exponent)", text: "Возводим предыдущий результат в квадрат: показатель удваивается. Раскрываем квадрат суммы, заменяем ω² на \(d) и приводим оба коэффициента по \(p). Вспомогательные произведения доступны по ↗ у квадрата.", formulas: [[.text("(u + vω)² = u² + 2uvω + v²ω²")]], terms: [.degree, .extensionField, .coefficient]), works: [2: .product(product, d, "power_\(power.id)")]))
            }
            rows.append(CipollaLine(id: "selected", atoms: [.power(basis, e.description), .text("=")] + selected.enumerated().map { .power(($0.offset == 0 ? "" : "· ") + basis, $0.element.exponent.description) }, explanation: CipollaExplanation(title: "Разложение показателя", text: "Берём только степени с единицами в двоичной записи \(e). Соседние выбранные степени перемножаем попарно, как на доске, затем соединяем полученные группы. Все произведения вычисляются в том же расширении поля.", terms: [.binary, .degree, .extensionField])))
            for c in s.combinations {
                guard let product = c.product else { continue }
                rows.append(CipollaLine(id: "combination_\(c.id)", atoms: [.power(basis, c.accumulatedExponent.description), .text("≡"), .text("(\(product.left.expression))(\(product.right.expression))"), .text("≡"), .text(product.result.expression + " (mod \(p))")], explanation: CipollaExplanation(title: "Соединяем выбранные степени", text: "Сумма показателей этих двух групп равна \(c.accumulatedExponent). Раскрываем скобки, заменяем ω² на \(d), собираем свободные члены отдельно от коэффициента при ω. Результаты произведений и удвоение–сложение открываются по ↗.", formulas: [[.text("(u + vω)(r + sω) = ur + vsd + (us + vr)ω")]], terms: [.extensionField, .coefficient, .degree]), works: [2: .product(product, d, "combination_\(c.id)")]))
            }
            if let final = s.combinations.last {
                rows.append(CipollaLine(id: "final", atoms: [.power(basis, e.description), .text("≡"), .text("\(final.result.real) + 0ω"), .text("≡"), .text("\(final.result.real) (mod \(p))")], explanation: CipollaExplanation(title: "Почему исчез ω", text: "Для квадратичного вычета a степень с показателем (p+1)/2 лежит в исходном поле. Здесь вычисление подтвердило это: коэффициент при ω равен 0. Свободный коэффициент \(final.result.real) — один из корней.", terms: [.extensionField, .coefficient, .root])))
            }
        } else if s.outcome == .zero {
            rows.append(CipollaLine(id: "zero", atoms: [.text("x² ≡ 0"), .text("⇔"), .text("x ≡ 0 (mod \(p))")], explanation: rootsReason(s)))
        } else if s.outcome == .binaryPrime {
            rows.append(CipollaLine(id: "two", atoms: [.text("x² ≡ x ≡ \(s.a) (mod 2)")], explanation: rootsReason(s)))
        } else if s.outcome == .candidateRoot {
            rows.append(CipollaLine(id: "candidate_root", atoms: [.text("\(s.chosenDelta!)² ≡ \(s.a) (mod \(p))"), .text("⇒"), .text("x ≡ ±\(s.chosenDelta!) (mod \(p))")], explanation: rootsReason(s)))
        }
        if s.roots.count == 2 {
            let t = s.combinations.last?.result.real ?? s.chosenDelta ?? s.roots[0]
            rows.append(CipollaLine(id: "opposite", atoms: [.text("−\(t) ≡ \(p) − \(t) = \(s.p - t) (mod \(p))")], explanation: rootsReason(s)))
        }
        for v in s.verification {
            rows.append(CipollaLine(id: "check_\(v.id)", atoms: [.text("\(v.root)²"), .text("="), .text("\(v.square)"), .text("="), .text("\(p) · \(v.quotient) + \(v.remainder)"), .text("≡ \(s.a) (mod \(p))")], explanation: CipollaExplanation(title: "Проверка подстановкой", text: "Возводим найденный корень в квадрат и делим на \(p) с остатком. Получили \(s.a), то есть исходное подкоренное число по модулю \(p). Проверка выполняется независимо от вычисления в расширении.", terms: [.root, .remainder, .congruence])))
        }
        return rows
    }
}
