import Foundation

/// Platform-independent mathematical writing shared by iPhone and Apple Watch.
enum TonelliLectureAtom: Sendable {
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

    func line(_ id: String, prefix: [TonelliLectureAtom] = [], explanation: String, references: [String] = ["tonelli"]) -> TonelliLectureLine {
        TonelliLectureLine(id: id, atoms: prefix + atoms, explanation: explanation, references: references,
            works: Dictionary(uniqueKeysWithValues: works.map { ($0.key + prefix.count, $0.value) }))
    }
}
/// Only multiplication tables are auxiliary. Every equality and power evaluation is written.
private struct TonelliVisibleArithmetic {
    let modulus: UInt64
    private var written: Set<TonelliPowerKey> = []
    init(modulus: UInt64) { self.modulus = modulus }
    func signed(_ value: UInt64) -> String { value > modulus/2 ? "−\(modulus-value)" : String(value) }
    func integer(_ value: UInt64) -> DecimalInteger {
        value > modulus/2 ? DecimalInteger(magnitude: Natural(modulus-value), isNegative: true) : DecimalInteger(Natural(value))
    }
    func factor(_ value: UInt64) -> String { value > modulus/2 ? "(\(signed(value)))" : signed(value) }
    func rawProduct(_ a: UInt64, _ b: UInt64) -> String { (integer(a)*integer(b)).description }

    mutating func power(_ power: RecordedPower, id: String, label suppliedLabel: String? = nil) -> TonelliCalculation {
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
                if nextExponent != 2 || label != String(power.base) || power.base > modulus/2 {
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
        rows.append(initialCalculation.line("tonelliInitial", explanation: "Вычисляем a^r, сохраняя исходное основание a. Уже встречавшиеся степени подставляются из написанных выше равенств."))
        for (index, test) in s.orderTests.enumerated() {
            let originalPower = RecordedPower(id: "original_order_\(index)", base: s.a, exponent: s.r*test.exponent, modulus: s.p, result: test.result)
            let calculation = prepare(originalPower, id: "tonelliOrder_\(index)")
            rows.append(calculation.line("tonelliOrder_\(index)", prefix: [.rich("(" + pow(a, s.r) + ")^{\(test.exponent)}"), .text("=")], explanation: "Проверяем следующую n-ю степень a^r. Показатели перемножаются: \(s.r)·\(test.exponent)=\(originalPower.exponent). До последнего равенства результат отличен от 1, что обосновывает минимальность порядка."))
        }
        if let last = s.orderTests.last {
            let group = "(" + pow(a, s.r) + ")"
            rows.append(TonelliLectureLine(id: "tonelliK", atoms: [.rich(group + "^{\(n)·k}"), .text("="), .rich(group + "^{\(last.exponent)}"), .text("≡ 1; \(n)k = \(last.exponent) ⇒ k ="), .fraction(String(last.exponent),String(n)), .text("= \(s.k)")], explanation: "Все проверки порядка написаны выше. В записи (a^r)^(n·k)=1 получаем k как порядок, делённый на n; здесь k=\(s.k)."))
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
                    // For B² its full square is already in the prelude; preserve the named line as well.
                    if calculation.prelude.isEmpty || !calculation.alreadyWritten {
                    rows.append(calculation.line("tonelliB_\(power.exponent)", explanation: "Вычисляем степени B. Получаем все кубические корни из единицы: 1, B, B²."))
                    }
                }
            }
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
            if stage.value != 1 && s.degree == 3 { atoms.append(.text("= \(unity(stage.value))")) }
            rows.append(TonelliLectureLine(id: "tonelliDescentValue_\(stage.id)", atoms: atoms, explanation: "После понижения степени вычисляем внутреннее выражение. Из Y^n=1 не следует Y=1; результат сравниваем с 1, B и его степенями.", references: ["unity-roots", "tonelli"], works: works))
            if stage.choice != 0 {
                let b = String(s.nonResidue!), E = (s.p-1)/n
                let correction = stage.choice == 1 ? "B" : "B^{\(stage.choice)}"
                let substitution = stage.choice == 1 ? pow(b, E) : "(" + pow(b, E) + ")^{\(stage.choice)}"
                let expandedExponent = before == 0 ? "\(stage.choice)·\(E)" : "\(before)+\(stage.choice)·\(E)"
                rows.append(TonelliLectureLine(id: "tonelliCorrection_\(stage.id)", atoms: [.rich(product(A, before)+" · "+correction), .rich("≡ \(unity(stage.value)) · \(correction) = 1")], explanation: "Домножаем на подходящий корень из единицы: для квадрата (−1)·(−1)=1, для куба B·B²=B³=1."))
                rows.append(TonelliLectureLine(id: "tonelliIdentity_\(stage.id)", atoms: [.rich(product(A, before)+" · "+correction), .text("="), .rich(product(A, before)+" · "+substitution), .text("="), .rich(pow(a,A)+" · \(b)^{\(expandedExponent)}"), .text("="), .rich(product(A,after)), .text("≡ 1")], explanation: "Последовательно подставляем B, раскрываем степень степени и складываем показатели. Все преобразования записаны через равенства на основном листе."))
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
}
