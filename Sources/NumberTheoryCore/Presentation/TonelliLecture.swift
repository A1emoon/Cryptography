import Foundation

/// Platform-independent mathematical writing shared by iPhone and Apple Watch.
enum TonelliLectureAtom: Sendable {
    case congruence(UInt64, unequal: Bool = false)
    case text(String), rich(String), power(String, String), fraction(String, String), fractionPower(String, String, String), symbol(String, String)
}
enum TonelliLectureWork: Sendable {
    // Only work on the side may open a sheet. Main proof operations have no hidden payload.
    case product(String, String, String)
}

struct TonelliLectureLine: Identifiable, Sendable {
    let id: String
    let atoms: [TonelliLectureAtom]
    let explanation: String
    var equations: [String] = []
    var references: [String] = ["tonelli"]
    var works: [Int: TonelliLectureWork] = [:]
}

private struct TonelliPowerKey: Hashable {
    let base: UInt64
    let exponent: UInt64
    let label: String
}
private struct TonelliCalculation {
    var prelude: [TonelliLectureLine] = []
    var atoms: [TonelliLectureAtom] = []
    var works: [Int: TonelliLectureWork] = [:]
    var alreadyWritten = false

    func line(_ id: String, prefix: [TonelliLectureAtom] = [], suffix: [TonelliLectureAtom] = [], explanation: String, references: [String] = ["tonelli"]) -> TonelliLectureLine {
        TonelliLectureLine(id: id, atoms: prefix + atoms + suffix, explanation: explanation, references: references,
            works: Dictionary(uniqueKeysWithValues: works.map { ($0.key + prefix.count, $0.value) }))
    }
}
/// Only multiplication tables are auxiliary. Every equality and power evaluation is written.
private struct TonelliVisibleArithmetic {
    let modulus: UInt64
    private var written: Set<TonelliPowerKey> = []
    private var nonnegative = false
    init(modulus: UInt64) { self.modulus = modulus }
    func signed(_ value: UInt64) -> String { !nonnegative && value > modulus/2 ? "−\(modulus-value)" : String(value) }
    func integer(_ value: UInt64) -> DecimalInteger {
        !nonnegative && value > modulus/2 ? DecimalInteger(magnitude: Natural(modulus-value), isNegative: true) : DecimalInteger(Natural(value))
    }
    func factor(_ value: UInt64) -> String { !nonnegative && value > modulus/2 ? "(\(signed(value)))" : signed(value) }
    func rawProduct(_ a: UInt64, _ b: UInt64) -> String { (integer(a)*integer(b)).description }

    mutating func power(_ power: RecordedPower, id: String, label: String? = nil, nonnegative: Bool = false) -> TonelliCalculation {
        let previousMode=self.nonnegative
        self.nonnegative=nonnegative
        defer { self.nonnegative=previousMode }
        var calculation = expandedPower(power,id:id,label:label)
        if calculation.prelude.last?.id == id+"_square_\(power.exponent)", let square=calculation.prelude.popLast() {
            calculation.atoms=square.atoms; calculation.works=square.works; calculation.alreadyWritten=false
        }
        return calculation
    }
    private mutating func expandedPower(_ power: RecordedPower, id: String, label suppliedLabel: String? = nil) -> TonelliCalculation {
        let label = suppliedLabel ?? String(power.base)
        let key = TonelliPowerKey(base: power.base, exponent: power.exponent, label: label)
        var calculation = TonelliCalculation()
        if written.contains(key) || power.exponent <= 1 {
            calculation.alreadyWritten = true
            calculation.atoms = [.power(label, String(power.exponent)), .text("≡ \(signed(power.result))")]
            written.insert(key)
            return calculation
        }
        var values: [UInt64:UInt64] = [1: power.base % modulus]
        var exponent: UInt64 = 1, previous = power.base % modulus
        while exponent <= power.exponent/2 {
            let nextExponent = exponent*2, nextValue = Mod64.multiply(previous, previous, modulus)
            values[nextExponent] = nextValue
            let squareKey = TonelliPowerKey(base: power.base, exponent: nextExponent, label: label)
            if !written.contains(squareKey) {
                var atoms: [TonelliLectureAtom] = [.power(label, String(nextExponent))]
                var index = 0
                if nextExponent != 2 || label != String(power.base) || (!nonnegative && power.base > modulus/2) {
                    atoms += [.text("≡"), .power(factor(previous), "2")]; index = 2
                }
                let raw = rawProduct(previous, previous)
                atoms += [.text("= \(raw)")]
                if raw != signed(nextValue) { atoms += [.text("≡ \(signed(nextValue))")] }
                calculation.prelude.append(TonelliLectureLine(id: id+"_square_\(nextExponent)", atoms: atoms,
                    explanation: "Квадрат предыдущей степени удваивает показатель. Все равенства и остатки записаны здесь; ↗ открывает только таблицу умножения \(signed(previous))·\(signed(previous)).",
                    works: [index: .product(signed(previous), signed(previous), String(modulus))]))
                written.insert(squareKey)
            }
            exponent = nextExponent; previous = nextValue
        }
        if power.exponent.nonzeroBitCount == 1 {
            calculation.alreadyWritten = true
            calculation.atoms = [.power(label, String(power.exponent)), .text("≡ \(signed(power.result))")]
            return calculation
        }
        var selected: [UInt64] = [], bit: UInt64 = 1, rest = power.exponent
        while rest > 0 {
            if rest & 1 == 1 { selected.append(bit) }
            rest >>= 1
            if rest > 0 { bit *= 2 }
        }
        calculation.atoms = [.power(label, String(power.exponent)), .text("="),
            .rich(selected.map { $0 == 1 ? label : "\(label)^{\($0)}" }.joined(separator: " · ")), .text("≡")]
        var accumulator = values[selected[0]]!
        for i in 1..<selected.count {
            let next = values[selected[i]]!
            let position = calculation.atoms.count
            calculation.atoms.append(.text("\(factor(accumulator)) · \(factor(next))"))
            calculation.works[position] = .product(signed(accumulator), signed(next), String(modulus))
            if i+1 < selected.count {
                calculation.atoms.append(.text(" · " + selected[(i+1)...].map { factor(values[$0]!) }.joined(separator: " · ")))
            }
            if nonnegative && i+1 == selected.count { calculation.atoms.append(.text("= \(rawProduct(accumulator,next))")) }
            calculation.atoms.append(.text("≡"))
            accumulator = Mod64.multiply(accumulator, next, modulus)
        }
        calculation.atoms.append(.text(signed(power.result)))
        written.insert(key)
        return calculation
    }

    /// Reciprocity is part of the student's written proof, never an auxiliary sheet.
    func symbol(_ trace: LegendreTrace) -> [TonelliLectureAtom] {
        func term(_ stage: LegendreStage, fractional: Bool) -> [TonelliLectureAtom] {
            if let terminal = stage.terminal { return [.text(String(terminal))] }
            var atoms: [TonelliLectureAtom] = stage.sign == -1 ? [.text("−")] : []
            if fractional, let d = stage.exponentDerivation {
                atoms.append(.fractionPower("(−1)", d.numeratorExpression, d.denominator.description))
            } else if let e = stage.factorExponent { atoms.append(.power("(−1)", e.description)) }
            if let a = stage.numerator, let b = stage.denominator { atoms.append(.symbol(a.description, b.description)) }
            return atoms
        }
        var atoms: [TonelliLectureAtom] = []
        for stage in trace.stages {
            if !atoms.isEmpty { atoms.append(.text("=")) }
            atoms += term(stage, fractional: true)
            if stage.exponentDerivation != nil {
                atoms.append(.text("=")); atoms += term(stage, fractional: false)
            }
        }
        return atoms
    }
}

enum TonelliLecture {
    static func lines(_ s: TonelliSolution) -> [TonelliLectureLine] {
        let rows=rawLines(s)+(s.degree == 3 ? cubicConclusions(s) : [])
        return rows.map { withModuli($0,defaultModulus:s.p) }
    }

    /// Convert every modular comparison, including comparisons embedded in rich
    /// expressions, to a typed sign. Exact equalities retain their original =.
    private static func withModuli(_ line: TonelliLectureLine, defaultModulus: UInt64) -> TonelliLectureLine {
        let explicitPattern = #"\(mod\s+(\d+)\)"#
        let explicitRegex = try! NSRegularExpression(pattern:explicitPattern)
        let rawText=line.atoms.compactMap { atom -> String? in
            switch atom { case .text(let text),.rich(let text):text; default:nil }
        }.joined(separator:" ")
        let matches=explicitRegex.matches(in:rawText,range:NSRange(rawText.startIndex...,in:rawText))
        let explicit=matches.compactMap { match -> UInt64? in
            guard let range=Range(match.range(at:1),in:rawText) else { return nil }
            return UInt64(rawText[range])
        }
        // The inverse-exponent step in the unique-root branch uses p−1, not p.
        let modulus=explicit.first ?? defaultModulus
        var atoms:[TonelliLectureAtom]=[], works:[Int:TonelliLectureWork]=[:]
        for (oldIndex,atom) in line.atoms.enumerated() {
            let start=atoms.count
            let source:String
            let rich:Bool
            switch atom {
            case .text(let text):source=text;rich=false
            case .rich(let text):source=text;rich=true
            default:
                atoms.append(atom)
                if let work=line.works[oldIndex] { works[start]=work }
                continue
            }
            let text=source.replacingOccurrences(of:#"\s*\(mod\s+\d+\)"#,with:"",options:.regularExpression)
            var fragment=""
            func appendFragment() {
                let value=fragment.trimmingCharacters(in:.whitespacesAndNewlines)
                if !value.isEmpty { atoms.append(rich ? .rich(value) : .text(value)) }
                fragment=""
            }
            for character in text {
                if character == "≡" || character == "≢" {
                    appendFragment();atoms.append(.congruence(modulus,unequal:character == "≢"))
                } else { fragment.append(character) }
            }
            appendFragment()
            if let work=line.works[oldIndex] {
                // Splitting a preceding equation must not move a multiplication
                // link to the modular sign or to a different calculation.
                let destination=(start..<atoms.count).first { i in
                    if case .congruence = atoms[i] { return false }; return true
                }
                if let destination { works[destination]=work }
            }
        }
        return TonelliLectureLine(id:line.id,atoms:atoms,explanation:line.explanation,equations:line.equations,references:line.references,works:works)
    }
    private static func rawLines(_ s: TonelliSolution) -> [TonelliLectureLine] {
        if s.degree == 2, s.initial != nil, !s.roots.isEmpty { return quadraticLines(s) }
        let a = String(s.a), p = String(s.p), n = UInt64(s.degree)
        var arithmetic = TonelliVisibleArithmetic(modulus: s.p)
        func signed(_ value: UInt64) -> String { arithmetic.signed(value) }
        func factor(_ value: UInt64) -> String { arithmetic.factor(value) }
        func pow(_ base: String, _ exponent: UInt64) -> String { exponent == 1 ? base : "\(base)^{\(exponent)}" }
        func product(_ A: UInt64, _ C: UInt64) -> String {
            pow(a, A) + (C == 0 ? "" : " · " + pow(String(s.nonResidue ?? 1), C))
        }
        func unity(_ value: UInt64) -> String {
            if value == 1 { return "1" }
            if s.degree == 2 { return "−1" }
            return value == s.B ? "B" : "B²"
        }
        var rows = [TonelliLectureLine(id: "tonelliCondition", atoms: [.power("x", String(n)), .text("≡ \(s.input) (mod \(p))")], explanation: "Решаем сравнение по простому модулю p. Степень n равна 2 или 3. Все основные преобразования написаны последовательно; отдельно открываются только таблицы умножения.", references: ["prime", "power-residue"])]
        func prepare(_ power: RecordedPower, id: String, label: String? = nil) -> TonelliCalculation {
            let calculation = arithmetic.power(power, id: id, label: label)
            rows += calculation.prelude
            return calculation
        }
        func write(_ power: RecordedPower, id: String, label: String? = nil) {
            let calculation = prepare(power, id: id, label: label)
            if !calculation.alreadyWritten {
                rows.append(calculation.line(id, explanation: "Разлагаем показатель в сумму степеней двойки и подставляем уже вычисленные степени. Вся цепочка равенств находится на листе; по ↗ доступна только таблица для соответствующего произведения."))
            }
        }
        if s.input != DecimalInteger(Natural(s.a)) {
            rows.append(TonelliLectureLine(id: "tonelliReduce", atoms: [.text("\(s.input) ≡ \(a) (mod \(p))")], explanation: "Заменяем правую часть остатком по p. Вспомогательное нахождение остатка можно раскрыть как удвоение–сложение с единицей.", references: ["congruence"], works: [0: .product(s.input.description, "1", p)]))
        }
        if s.a == 0 {
            rows.append(TonelliLectureLine(id: "tonelliZero", atoms: [.power("x", String(n)), .text("≡ 0 ⇔ x ≡ 0 (mod \(p))")], explanation: "В поле нет делителей нуля, поэтому нулевая степень получается только у нуля.", references: ["prime"]))
            return rows
        }
        if let criterion = s.criterion {
            if let symbol = s.quadraticCriterion {
                rows.append(TonelliLectureLine(id: "tonelliCriterion", atoms: arithmetic.symbol(symbol), explanation: "Проверяем разрешимость символом Лежандра. Взаимность, выделение двоек и вычисление знаков полностью записаны в цепочке равенств.", references: ["legendre", "reciprocity", "residue-criterion"]))
            } else {
                rows.append(TonelliLectureLine(id: "tonelliCriterionExponent", atoms: [.fractionPower(a, "\(p)−1", String(n)), .text("="), .power(a, String(criterion.exponent))], explanation: "Подставляем p и вычисляем показатель критерия: (\(p)−1)/\(n)=\(criterion.exponent). Дальше последовательно вычисляем эту степень.", references: ["residue-criterion"]))
                let calculation = prepare(criterion, id: "tonelliCriterion")
                rows.append(calculation.line("tonelliCriterion", prefix: [.fractionPower(a, "\(p)−1", String(n)), .text("=")], explanation: "Подставляем последовательные квадраты и выполняем произведения. Вся проверка критерия видна без открытия окон; по ↗ открываются только таблицы умножения."))
            }
        }
        if s.roots.isEmpty {
            rows.append(TonelliLectureLine(id: "tonelliMissing", atoms: [.text("x ∈ ∅ (mod \(p))")], explanation: "Критерий степенного вычета не выполнен.", references: ["residue-criterion"]))
            return rows
        }
        guard s.s > 0, let initial = s.initial else {
            for step in s.steps {
                for (index, equation) in step.equations.enumerated() {
                    if index == step.equations.count-1, let power = step.powers.first {
                        let calculation = prepare(power, id: "tonelliUniquePower")
                        rows.append(calculation.line("tonelli_\(step.id)_\(index)", prefix: [.text("x ≡")], explanation: step.explanation))
                    } else {
                        rows.append(TonelliLectureLine(id: "tonelli_\(step.id)_\(index)", atoms: [.text(equation)], explanation: step.explanation, references: step.theorem.map { [$0] } ?? []))
                    }
                }
            }
            return rows
        }
        rows.append(TonelliLectureLine(id: "tonelliDecomposition", atoms: [.text("\(p)−1 = \(s.p-1) ="), .power(String(n), String(s.s)), .text("· \(s.r); s = \(s.s), r = \(s.r)")], explanation: "Выделяем всю степень n в p−1. Остаток r не делится на n; сохраняем обозначения конспекта."))
        let initialCalculation = prepare(initial, id: "tonelliInitial")
        if !initialCalculation.alreadyWritten || initial.exponent <= 1 {
            rows.append(initialCalculation.line("tonelliInitial", explanation: "Вычисляем a^r, сохраняя исходное основание a. Уже встречавшиеся степени подставляются из написанных выше равенств."))
        }
        let orderBound=(s.p-1)/s.r/3
        var orderCandidates:[String]=[], orderCandidate:UInt64=1
        while true {
            orderCandidates.append(String(orderCandidate))
            if orderCandidate == orderBound { break }; orderCandidate *= 3
        }
        let orderName="P_{\(p)}("+pow(a,s.r)+")"
        rows.append(TonelliLectureLine(id:"tonelliCubicOrderBound",atoms:[.rich(orderName+" ∣ 3^{\(s.s-1)} = \(orderBound); "+orderName+" ∈ {"+orderCandidates.joined(separator:", ")+"}")],explanation:"Поскольку a — кубический вычет, порядок a^r делит 3^(s−1). Поэтому возможны только перечисленные степени тройки.",references:["tonelli-residue-order"]))
        for (index, test) in s.orderTests.enumerated() {
            let originalPower = RecordedPower(id: "original_order_\(index)", base: s.a, exponent: s.r*test.exponent, modulus: s.p, result: test.result)
            let calculation = prepare(originalPower, id: "tonelliOrder_\(index)")
            if s.r == 1 && calculation.alreadyWritten { continue }
            let prefix: [TonelliLectureAtom] = s.r == 1 ? [] : [.rich("(" + pow(a, s.r) + ")^{\(test.exponent)}"), .text("=")]
            rows.append(calculation.line("tonelliOrder_\(index)", prefix: prefix, suffix: test.result == 1 ? [] : [.text("≢ 1")], explanation: "Проверяем следующую n-ю степень a^r. Показатели перемножаются: \(s.r)·\(test.exponent)=\(originalPower.exponent). До последнего равенства результат отличен от 1, что обосновывает минимальность порядка."))
        }
        if s.initialOrder > 1 {
            let order=s.initialOrder, smaller=s.orderTests.dropLast().last
            let lowerValue=smaller?.result ?? initial.result
            rows.append(TonelliLectureLine(id:"tonelliCubicOrderProof",atoms:[.power(a,String(s.r*order)),.text("≡ 1;"),.power(a,String(s.r*(order/3))),.text("≡ \(signed(lowerValue)) ≢ 1 ⇒"),.rich(orderName+" = \(order)")],explanation:"Порядок делит указанную степень тройки. Если степень с показателем, уменьшенным втрое, не равна 1, все меньшие допустимые порядки исключены. Поэтому это точный порядок, а не только единичный показатель.",references:["order-divisibility","tonelli-residue-order"]))
            rows.append(TonelliLectureLine(id:"tonelliK",atoms:[.rich("3k = "+orderName+" = \(order) ⇒ k ="),.fraction(String(order),"3"),.text("= \(s.k)")],explanation:"Здесь 3k обозначает уже доказанный порядок a^r. Сначала установлена его минимальность; только затем делим найденный порядок на 3."))
        } else {
            rows.append(TonelliLectureLine(id:"tonelliCubicOrderProof",atoms:[.rich(pow(a,s.r)+" ≡ 1 ⇒ "+orderName+" = 1")],explanation:"Исходный элемент уже равен 1, поэтому уменьшать его порядок не требуется."))
        }
        for (index, trial) in s.nonResidueTrials.enumerated() where trial.result == 1 {
            if s.degree == 2, s.quadraticTrials.indices.contains(index) {
                rows.append(TonelliLectureLine(id: "tonelliTrial_\(trial.base)", atoms: [.text("b = \(trial.base):")] + arithmetic.symbol(s.quadraticTrials[index]), explanation: "Кандидат является квадратным вычетом и не подходит для b. Все преобразования символа написаны в этой строке.", references: ["legendre", "reciprocity"]))
            } else {
                let calculation = prepare(trial, id: "tonelliTrial_\(trial.base)")
                rows.append(calculation.line("tonelliTrial_\(trial.base)", prefix: [.text("b = \(trial.base):"), .fractionPower(String(trial.base), "\(p)−1", String(n)), .text("=")], explanation: "Степень равна 1, поэтому кандидат является n-м вычетом. Проверяем следующее число."))
            }
        }
        if let b = s.nonResidue, let B = s.B, let trial = s.nonResidueTrials.last {
            if s.degree == 2, let symbol = s.quadraticTrials.last {
                rows.append(TonelliLectureLine(id: "tonelliNonResidue", atoms: [.text("b = \(b):")] + arithmetic.symbol(symbol), explanation: "Найден квадратный невычет. Его степень (p−1)/2 равна −1; используем её для исправления знака.", references: ["legendre", "tonelli-nonresidue"]))
            }
            let calculation = prepare(trial, id: "tonelliBPower")
            rows.append(calculation.line("tonelliB", prefix: [.text("b = \(b); B ≡"), .fractionPower(String(b), "\(p)−1", String(n)), .text("=")], explanation: "Вычисляем B по последовательным квадратам и произведениям, а не скрываем степень за ссылкой. B и отрицательный представитель обозначают один остаток.", references: ["tonelli-nonresidue", "unity-roots"]))
            if s.degree == 3 {
                for power in s.unityPowers {
                    let calculation = prepare(power, id: "tonelliB_\(power.exponent)", label: "B")
                    // The full square is merged into the named B² line; reuse cached values when needed.
                    if calculation.prelude.isEmpty || !calculation.alreadyWritten {
                    rows.append(calculation.line("tonelliB_\(power.exponent)", explanation: "Вычисляем степени B. Получаем все кубические корни из единицы: 1, B, B²."))
                    }
                }
            }
            rows.append(TonelliLectureLine(id:"tonelliUnityOrder",atoms:[.rich("B³ ≡ 1; B ≢ 1 ⇒ P_{\(p)}(B) = 3")],explanation:"B — нетривиальный кубический корень единицы. Поэтому его порядок равен 3, а 1,B,B² различны.",references:["unity-roots"]))
            _ = B
        }
        for stage in s.descents {
            let A = stage.aPower.exponent, before = stage.bPower.exponent, after = stage.bExponentAfter
            if before != 0 {
                write(stage.aPower, id: "tonelliDescentA_\(stage.id)")
                write(stage.bPower, id: "tonelliDescentB_\(stage.id)")
            }
            var atoms: [TonelliLectureAtom]
            var works: [Int: TonelliLectureWork] = [:]
            if before == 0 {
                let calculation = prepare(stage.aPower, id: "tonelliDescentA_\(stage.id)")
                atoms = calculation.atoms; works = calculation.works
            } else {
                atoms = [.rich(product(A, before)), .text("≡"), .text("\(factor(stage.aPower.result)) · \(factor(stage.bPower.result))"), .text("≡ \(signed(stage.value))")]
                works[2] = .product(signed(stage.aPower.result), signed(stage.bPower.result), p)
            }
            if stage.value != 1 && s.degree == 3 { atoms.append(.text("≡ \(unity(stage.value))")) }
            rows.append(TonelliLectureLine(id: "tonelliDescentValue_\(stage.id)", atoms: atoms, explanation: "После понижения степени вычисляем внутреннее выражение. Из Y^n=1 не следует Y=1; результат сравниваем с 1, B и его степенями.", references: ["unity-roots", "tonelli"], works: works))
            if stage.choice != 0 {
                let b = String(s.nonResidue!), E = (s.p-1)/n
                let correction = stage.choice == 1 ? "B" : "B^{\(stage.choice)}"
                let substitution = stage.choice == 1 ? pow(b, E) : "(" + pow(b, E) + ")^{\(stage.choice)}"
                let expandedExponent = before == 0 ? "\(stage.choice)·\(E)" : "\(before)+\(stage.choice)·\(E)"
                rows.append(TonelliLectureLine(id: "tonelliCorrection_\(stage.id)", atoms: [.rich(product(A, before)+" · "+correction), .rich("≡ \(unity(stage.value)) · \(correction)"), .text("="), .power("B","3"), .text("≡ 1")], explanation: "Домножаем на подходящий корень из единицы: для квадрата (−1)·(−1)=1, для куба B·B²=B³=1."))
                rows.append(TonelliLectureLine(id: "tonelliIdentity_\(stage.id)", atoms: [.rich(product(A, before)+" · "+correction), .text("≡"), .rich(product(A, before)+" · "+substitution), .text("="), .rich(pow(a,A)+" · \(b)^{\(expandedExponent)}"), .text("="), .rich(product(A,after)), .text("≡ 1")], explanation: "Последовательно подставляем B, раскрываем степень степени и складываем показатели. Все преобразования записаны через равенства на основном листе."))
            }
            if stage.level > 0 {
                let divided = a+"^{\(A)/\(n)}" + (after == 0 ? "" : " · \(s.nonResidue!)^{\(after)/\(n)}")
                rows.append(TonelliLectureLine(id: "tonelliRegroup_\(stage.id)", atoms: [.rich(product(A,after)), .text("="), .rich("("+divided+")^{\(n)}"), .text("="), .rich("("+product(A/n,after/n)+")^{\(n)}"), .text("≡ 1")], explanation: "Выносим общую n-ю степень и явно делим оба показателя на n. Затем внутреннее выражение снова вычисляем; оно не обязано быть единицей."))
            }
        }
        guard let aRoot = s.rootAPower, let bRoot = s.rootBPower, let seed = s.seedRoot else { return rows }
        let q = s.rootMultiplier, C = s.identityBExponent
        let fullB = (Natural(C)*Natural(q)).description
        let identity = pow(a,q*s.r) + (C == 0 ? "" : " · \(s.nonResidue!)^{\(fullB)}")
        if q != 1 {
            rows.append(TonelliLectureLine(id: "tonelliSquareIdentity", atoms: [.rich("("+product(s.r,C)+")²"), .text("="), .rich(identity), .text("≡ 1")], explanation: "При r≡1 mod3 возводим равенство в квадрат: теперь 2r+1 кратно 3. Показатели умножаются на 2."))
        }
        let raised = pow(a,q*s.r+1) + (C == 0 ? "" : " · \(s.nonResidue!)^{\(fullB)}")
        rows.append(TonelliLectureLine(id: "tonelliMultiplyByA", atoms: [.rich(identity+" · "+a), .text("="), .rich(raised), .text("≡"), .power("x",String(n))], explanation: "Домножаем равенство на a=x^n. Показатель при a увеличивается на единицу; теперь оба показателя кратны n."))
        let rootExpression = pow(a,aRoot.exponent) + (bRoot.exponent == 0 ? "" : " · "+pow(String(s.nonResidue!),bRoot.exponent))
        let dividedRoot = a+"^{\(q*s.r+1)/\(n)}" + (C == 0 ? "" : " · \(s.nonResidue!)^{\(fullB)/\(n)}")
        rows.append(TonelliLectureLine(id: "tonelliExtractPower", atoms: [.rich(raised), .text("="), .rich("("+dividedRoot+")^{\(n)}"), .text("="), .rich("("+rootExpression+")^{\(n)}"), .text("≡"), .power("x",String(n))], explanation: "Выносим общую n-ю степень и вычисляем показатели внутри скобок. Выражение в скобках даёт один корень; остальные перечисляем отдельно."))
        write(aRoot,id:"tonelliRootAPower")
        if bRoot.exponent != 0 { write(bRoot,id:"tonelliRootBPower") }
        var rootAtoms: [TonelliLectureAtom] = [.text("x₁ ≡"), .rich(rootExpression), .text("≡")]
        var rootWorks: [Int:TonelliLectureWork] = [:]
        if bRoot.exponent != 0 {
            rootAtoms.append(.text("\(factor(aRoot.result)) · \(factor(bRoot.result))"))
            rootWorks[3] = .product(signed(aRoot.result),signed(bRoot.result),p)
            let raw = arithmetic.rawProduct(aRoot.result,bRoot.result)
            rootAtoms.append(.text("= \(raw)"))
            if raw != signed(seed) { rootAtoms.append(.text("≡ \(signed(seed))")) }
        } else { rootAtoms.append(.text(signed(seed))) }
        if seed > s.p/2 { rootAtoms.append(.text("≡ \(seed)")) }
        rows.append(TonelliLectureLine(id:"tonelliExtract",atoms:rootAtoms,explanation:"Подставляем уже вычисленные степени и умножаем. Вся цепочка, включая отрицательный представитель и неотрицательный остаток, находится на листе.",works:rootWorks))
        if s.degree == 2 {
            let other = s.orderedRoots[1]
            rows.append(TonelliLectureLine(id:"tonelliRoot_2",atoms:[.text("x₂ ≡ −x₁ ≡ −(\(signed(seed))) ≡ \(signed(other))")]+(other > s.p/2 ? [.text("≡ \(other)")] : [])+[.text("(mod \(p))")],explanation:"Два ненулевых квадратных корня противоположны друг другу.",references:["unity-roots"]))
        } else if let B = s.B {
            for index in 1..<3 {
                let f = index == 1 ? B : Mod64.multiply(B,B,s.p), value = s.orderedRoots[index]
                var atoms: [TonelliLectureAtom] = [.text("x\(index == 1 ? "₂" : "₃") ≡ x₁ ·"), .power("B",String(index)), .text("≡"), .text("\(factor(seed)) · \(factor(f))"), .text("= \(arithmetic.rawProduct(seed,f))"), .text("≡ \(signed(value))")]
                if value > s.p/2 { atoms.append(.text("≡ \(value)")) }
                atoms.append(.text("(mod \(p))"))
                rows.append(TonelliLectureLine(id:"tonelliRoot_\(index+1)",atoms:atoms,explanation:"Умножаем первый корень на B или B². Получаем все три различных корня; произведения и остатки видны в основной записи.",references:["unity-roots"],works:[3:.product(signed(seed),signed(f),p)]))
            }
        }
        return rows
    }

    private static func cubicConclusions(_ s: TonelliSolution) -> [TonelliLectureLine] {
        guard !s.roots.isEmpty else { return [] }
        let a=String(s.a), p=String(s.p)
        var rows:[TonelliLectureLine]=[]
        if s.roots.count == 3 {
            rows.append(TonelliLectureLine(id:"tonelliCubicRootFamily",atoms:[.rich("(x₁ B^{i})^{3} = x₁^{3} · (B³)^{i} ≡ \(a), i ∈ {0,1,2}")],explanation:"Умножение первого корня на B или B² сохраняет его куб, поскольку B³≡1. Поэтому x₁B и x₁B² также являются корнями.",references:["unity-roots"]))
            rows.append(TonelliLectureLine(id:"tonelliCubicDistinctRoots",atoms:[.rich("x₁ ≢ 0; P_{\(p)}(B)=3 ⇒ |{x₁,x₁B,x₁B²}|=3")],explanation:"Первый корень ненулевой, а 1,B,B² различны. Умножение на ненулевой элемент поля сохраняет различность, поэтому найдены три различных корня.",references:["unity-roots"]))
        }
        for (i,proof) in s.cubicVerifications.enumerated() {
            let root=String(proof.root), square=(Natural(proof.root)*Natural(proof.root)).description
            rows.append(TonelliLectureLine(id:"tonelliCubicVerification_\(i)_square",atoms:[.power(root,"2"),.text("="),.text("\(root) · \(root)"),.text("= \(square)")],explanation:"Сначала вычисляем квадрат корня как произведение двух одинаковых множителей. Значение записано на основном листе; ↗ открывает только таблицу удвоения–сложения.",works:[2:.product(root,root,p)]))
            rows.append(TonelliLectureLine(id:"tonelliCubicVerification_\(i)",atoms:[.power(root,"3"),.text("="),.rich("\(root)^{2} · \(root)"),.text("="),.text("\(square) · \(root)"),.text("= \(proof.exactCube) = \(p) · \(proof.quotient) + \(proof.remainder) ≡ \(a)")],explanation:"Куб — это квадрат, умноженный на исходное число. Подставляем вычисленный выше квадрат, выполняем произведение и проверяем остаток. Весь ход возведения остаётся на листе, по ↗ доступна таблица для второго умножения.",works:[4:.product(square,root,p)]))
        }
        if s.roots.count == 3 {
            let set="{"+s.roots.map(String.init).joined(separator:", ")+"}"
            rows.append(TonelliLectureLine(id:"tonelliCubicCompleteness",atoms:[.rich("deg(x³−\(a))=3 ⇒ |{x ∈ ℤ_{\(p)} : x³ ≡ \(a)}| ≤ 3 ⇒ {x ∈ ℤ_{\(p)} : x³ ≡ \(a)} = "+set)],explanation:"Ненулевой многочлен степени 3 над полем имеет не более трёх корней. Мы уже получили три различных корня и проверили каждый, поэтому список решений полон.",references:["polynomial-root-bound","unity-roots"]))
        }
        return rows
    }

    private static func quadraticLines(_ s: TonelliSolution) -> [TonelliLectureLine] {
        guard let initial=s.initial, let aRoot=s.rootAPower, let bRoot=s.rootBPower, let seed=s.seedRoot else { return [] }
        let a=String(s.a), p=String(s.p), b=String(s.nonResidue ?? 1)
        var arithmetic=TonelliVisibleArithmetic(modulus:s.p)
        var rows=[TonelliLectureLine(id:"tonelliCondition",atoms:[.power("x","2"),.text("≡ \(s.input) (mod \(p))")],explanation:"Решаем квадратное сравнение по простому модулю.")]
        func power(_ base: String,_ exponent: UInt64) -> String { exponent == 1 ? base : "\(base)^{\(exponent)}" }
        func expression(_ exponent: UInt64) -> String { power(a,s.r)+(exponent == 0 ? "" : " · "+power(b,exponent)) }
        func order(_ element: String) -> String { "P_{\(p)}(\(element))" }
        func candidates(_ bound: UInt64) -> String {
            var values:[String]=[], value:UInt64=1
            while true { values.append(String(value)); if value == bound { break }; value *= 2 }
            return "{"+values.joined(separator:", ")+"}"
        }
        func label(_ index: Int) -> String { "c"+String(index+1).unicodeScalars.map{String(UnicodeScalar(0x2080+$0.value-48)!)}.joined() }
        func prepare(_ value: RecordedPower, id: String, label: String? = nil, nonnegative: Bool = false) -> TonelliCalculation {
            let calculation=arithmetic.power(value,id:id,label:label,nonnegative:nonnegative); rows += calculation.prelude; return calculation
        }
        func write(_ value: RecordedPower, id: String, nonnegative: Bool = false) {
            let calculation=prepare(value,id:id,nonnegative:nonnegative)
            if !calculation.alreadyWritten { rows.append(calculation.line(id,explanation:"Вычисляем степень по уже записанным квадратам. Отдельно открывается только таблица умножения.")) }
        }
        if s.input != DecimalInteger(Natural(s.a)) {
            rows.append(TonelliLectureLine(id:"tonelliReduce",atoms:[.text("\(s.input) ≡ \(a) (mod \(p))")],explanation:"Приводим правую часть по модулю.",references:["congruence"],works:[0:.product(s.input.description,"1",p)]))
        }
        if let symbol=s.quadraticCriterion {
            rows.append(TonelliLectureLine(id:"tonelliCriterion",atoms:arithmetic.symbol(symbol),explanation:"Символ Лежандра равен 1, поэтому сравнение разрешимо и имеет два ненулевых корня.",references:["legendre","reciprocity","residue-criterion"]))
        }
        rows.append(TonelliLectureLine(id:"tonelliDecomposition",atoms:[.text("\(p)−1 = \(s.p-1) ="),.power("2",String(s.s)),.text("· \(s.r); s = \(s.s), r = \(s.r)")],explanation:"Выделяем всю степень двойки; r нечётно."))
        if s.r != 1 { write(initial,id:"tonelliInitial") }
        let initialExpr=power(a,s.r), bound=UInt64(1) << (s.s-1)
        rows.append(TonelliLectureLine(id:"tonelliOrderBound",atoms:[.rich(order(initialExpr)+" ∣ 2^{\(s.s-1)} = \(bound); "+order(initialExpr)+" ∈ "+candidates(bound))],explanation:"Для квадратичного вычета порядок a^r делит 2^(s−1). При r=1 исходный элемент уже равен a; дополнительная степень не нужна.",references:["tonelli-residue-order"]))
        if initial.result != 1 {
            rows.append(TonelliLectureLine(id:"tonelliOrderNotOne",atoms:[.rich(initialExpr+" ≢ 1 ⇒ "+order(initialExpr)+" ≠ 1")],explanation:"Сам элемент не равен единице, поэтому его порядок больше 1."))
        }
        for (i,test) in s.orderTests.enumerated() {
            let original=RecordedPower(id:"original_order_\(i)",base:s.a,exponent:s.r*test.exponent,modulus:s.p,result:test.result)
            let calculation=prepare(original,id:"tonelliOrder_\(i)")
            if s.r == 1 && calculation.alreadyWritten { continue }
            let prefix:[TonelliLectureAtom]=s.r == 1 ? [] : [.rich("("+initialExpr+")^{\(test.exponent)}"),.text("=")]
            rows.append(calculation.line("tonelliOrder_\(i)",prefix:prefix,explanation:"Проверяем возможные порядки по возрастанию. Первая единичная степень даёт точный порядок."))
        }
        rows.append(TonelliLectureLine(id:"tonelliInitialOrder",atoms:[.rich(order(initialExpr)+" = \(s.initialOrder)")],explanation:"Все меньшие допустимые показатели исключены. Найден фактический порядок элемента, с которого начинаются корректировки.",references:["order-divisibility"]))
        if let bInitial=s.nonResidueInitial {
            for (i,_) in s.nonResidueTrials.enumerated() {
                rows.append(TonelliLectureLine(id:"tonelliTrial_\(s.nonResidueTrials[i].base)",atoms:[.text("b = \(s.nonResidueTrials[i].base):")]+arithmetic.symbol(s.quadraticTrials[i]),explanation:s.nonResidueTrials[i].result == 1 ? "Квадратичный вычет не подходит для корректировки; проверяем следующее число." : "Символ равен −1: найден квадратичный невычет.",references:["legendre","tonelli-nonresidue"]))
            }
            if s.r != 1 { write(bInitial,id:"tonelliNonResidueInitial",nonnegative:true) }
            let bExpr=power(b,s.r), numericLabel=s.r == 1 ? b : "("+NumberNotation.power(b,s.r)+")"
            var previous=bInitial.result
            for (i,test) in s.nonResidueOrderTests.enumerated() {
                // Register the power once; use the source's nonnegative representatives
                // for the explicit b^r order proof (3²=9, 3⁴=81≡13, ...).
                _ = arithmetic.power(test,id:"tonelliNonResidueOrder_\(i)",label:numericLabel)
                let negativeOne=previous == s.p-1
                let operand=negativeOne ? "−1" : String(previous)
                let raw=negativeOne ? "1" : (Natural(previous)*Natural(previous)).description
                var atoms:[TonelliLectureAtom]=[.power(numericLabel,String(test.exponent))]
                var workIndex=0
                if i != 0 || s.r != 1 {
                    atoms += [.text("≡"),.power(negativeOne ? "(−1)" : operand,"2")]; workIndex=2
                }
                atoms.append(.text("= \(raw)"))
                if raw != String(test.result) { atoms.append(.text("≡ \(test.result)")) }
                if test.result == s.p-1 { atoms.append(.text("≡ −1")) }
                rows.append(TonelliLectureLine(id:"tonelliNonResidueOrder_\(i)",atoms:atoms,explanation:"Последовательно возводим b^r в квадрат. Для невычета его порядок содержит полную степень двойки 2^s.",references:["tonelli-nonresidue"],works:[workIndex:.product(operand,operand,p)]))
                previous=test.result
            }
            rows.append(TonelliLectureLine(id:"tonelliNonResidueOrder",atoms:[.rich(order(bExpr)+" = 2^{\(s.s)} = \(UInt64(1) << s.s)")],explanation:"Последняя степень даёт 1, предыдущая — −1, поэтому найден точный порядок b^r. Это не утверждает, что b всегда первообразный корень по p при r≠1.",references:["tonelli-nonresidue"]))
        }
        for stage in s.quadraticCorrections {
            let half=stage.orderBefore/2, E=(s.p-1)/2, c=label(stage.id)
            let oldExponent=stage.bExponentBefore*half, newExponent=stage.bExponentAfter*half
            let aHalf=power(a,s.r*half)
            let oldPowered=aHalf+(oldExponent == 0 ? "" : " · "+power(b,oldExponent))
            let newPowered=aHalf+" · "+power(b,newExponent)
            var atoms:[TonelliLectureAtom]=[]
            if stage.id > 0 { atoms += [.rich(power(label(stage.id-1),half)+" · "+power(b,E)),.text("=")] }
            atoms.append(.rich(oldPowered+" · "+power(b,E)))
            if oldExponent != 0 {
                atoms += [.text("="),.rich(aHalf+" · \(b)^{\(oldExponent)+\(E)}"),.text("="),.rich(newPowered)]
            }
            atoms.append(.text("≡ (−1)·(−1) = 1"))
            rows.append(TonelliLectureLine(id:"tonelliCorrection_\(stage.id)",atoms:atoms,explanation:"Порядок текущего элемента равен \(stage.orderBefore), поэтому его степень \(half) равна −1. У невычета b степень (p−1)/2 также равна −1. Перемножаем сравнения.",references:["tonelli","tonelli-nonresidue"]))
            if half > 1 {
                rows.append(TonelliLectureLine(id:"tonelliRegroup_\(stage.id)",atoms:[.rich(newPowered),.text("="),.rich("("+expression(stage.bExponentAfter)+")^{\(half)}"),.text("≡ 1")],explanation:"Выносим общую степень \(half) сразу целиком. Порядок исправленного элемента делит \(half); промежуточные единичные уровни пропускаем."))
                let factor=stage.totalFactor
                write(factor,id:"tonelliCorrectedFactor_\(stage.id)",nonnegative:true)
                let left=arithmetic.integer(initial.result), raw=(left*DecimalInteger(Natural(factor.result))).description
                var valueAtoms:[TonelliLectureAtom]=[.rich(c+" ≡ "+expression(stage.bExponentAfter)),.text("≡"),.text("\(arithmetic.factor(initial.result)) · \(factor.result)"),.text("= \(raw)")]
                if raw != arithmetic.signed(stage.valueAfter) { valueAtoms.append(.text("≡ \(arithmetic.signed(stage.valueAfter))")) }
                rows.append(TonelliLectureLine(id:"tonelliCorrected_\(stage.id)",atoms:valueAtoms,explanation:"Вычисляем исправленный элемент, чтобы определить его фактический порядок.",works:[2:.product(left.description,String(factor.result),p)]))
            } else {
                rows.append(TonelliLectureLine(id:"tonelliCorrected_\(stage.id)",atoms:[.rich(c+" ≡ "+expression(stage.bExponentAfter)+" ≡ 1")],explanation:"После последней корректировки получена единица; дальнейшего уменьшения порядка не требуется."))
            }
            if stage.valueAfter != 1 && stage.valueAfter != s.p-1 {
                rows.append(TonelliLectureLine(id:"tonelliCorrectedBound_\(stage.id)",atoms:[.rich(order(c)+" ∣ \(half); "+order(c)+" ∈ "+candidates(half))],explanation:"Из вынесенной степени следует граница порядка. Находим фактическое значение, а не принимаем границу за точный порядок."))
                for (i,test) in stage.orderTests.enumerated() {
                    let calculation=prepare(test,id:"tonelliCorrectedOrder_\(stage.id)_\(i)",label:c)
                    rows.append(calculation.line("tonelliCorrectedOrder_\(stage.id)_\(i)",explanation:"Последовательными квадратами исправленного элемента находим первую единичную степень."))
                }
            }
            let reduction=stage.valueAfter == 1 || stage.valueAfter == s.p-1 ? " = "+order(arithmetic.signed(stage.valueAfter)) : ""
            rows.append(TonelliLectureLine(id:"tonelliCorrectedOrder_\(stage.id)",atoms:[.rich(order(c)+reduction+" = \(stage.orderAfter)")],explanation:"Найден точный порядок исправленного элемента. Следующую корректировку выбираем по этому порядку, поэтому возможен скачок, например 8→2.",references:["order-divisibility","tonelli"]))
        }
        let identity=expression(s.identityBExponent), raised=power(a,s.r+1)+(s.identityBExponent == 0 ? "" : " · "+power(b,s.identityBExponent))
        let rootExpr=power(a,aRoot.exponent)+(bRoot.exponent == 0 ? "" : " · "+power(b,bRoot.exponent))
        rows.append(TonelliLectureLine(id:"tonelliMultiplyByA",atoms:[.rich(identity+" · "+a),.text("="),.rich(raised),.text("≡ "+a)],explanation:"Порядок достиг 1. Домножаем последнее сравнение на a и переходим к извлечению квадратного корня."))
        rows.append(TonelliLectureLine(id:"tonelliExtractPower",atoms:[.rich(raised),.text("="),.rich("("+rootExpr+")²"),.text("≡ "+a)],explanation:"r нечётно, а показатель при b чётен. Выделяем полный квадрат."))
        rows.append(TonelliLectureLine(id:"tonelliRoots",atoms:[.rich("x_{1,2} ≡ ±("+rootExpr+") (mod \(p))")],explanation:"Получаем два противоположных корня из выделенного квадрата.",references:["unity-roots"]))
        write(aRoot,id:"tonelliRootAPower")
        if bRoot.exponent != 0 { write(bRoot,id:"tonelliRootBPower",nonnegative:true) }
        var rootAtoms:[TonelliLectureAtom]=[.rich("x₁ ≡ "+rootExpr),.text("≡")], rootWorks:[Int:TonelliLectureWork]=[:]
        if bRoot.exponent != 0 {
            let raw=(Natural(aRoot.result)*Natural(bRoot.result)).description
            rootAtoms += [.text("\(aRoot.result) · \(bRoot.result)"),.text("= \(raw)")]
            rootWorks[2] = .product(String(aRoot.result),String(bRoot.result),p)
            if raw != String(seed) { rootAtoms.append(.text("≡ \(seed)")) }
        } else { rootAtoms.append(.text(String(seed))) }
        rows.append(TonelliLectureLine(id:"tonelliExtract",atoms:rootAtoms,explanation:"Подставляем степени и вычисляем первый неотрицательный корень.",works:rootWorks))
        rows.append(TonelliLectureLine(id:"tonelliRoot_2",atoms:[.text("x₂ ≡ −x₁ ≡ −\(seed) ≡ \(s.p-seed) (mod \(p))")],explanation:"Второй корень противоположен первому."))
        for (i,verification) in s.verification.enumerated() {
            let raw=(Natural(verification.base)*Natural(verification.base)).description
            rows.append(TonelliLectureLine(id:"tonelliVerification_\(i)",atoms:[.power(String(verification.base),"2"),.text("="),.text("\(verification.base) · \(verification.base)"),.text("= \(raw) ≡ \(a) (mod \(p))")],explanation:"Раскрываем квадрат как произведение одинаковых множителей, вычисляем его и сравниваем остаток с исходной правой частью. Таблица умножения открывается по ↗ у произведения.",works:[2:.product(String(verification.base),String(verification.base),p)]))
        }
        return rows
    }
}
