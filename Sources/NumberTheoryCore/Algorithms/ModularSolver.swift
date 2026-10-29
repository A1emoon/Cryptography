import Foundation

enum ModularMethod: String, CaseIterable, Sendable, Identifiable {
    case automatic, binary, lifting, powerMatrix, direct
    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: "Автоматически"
        case .binary: "Расширенный бинарный Евклид"
        case .lifting: "По степеням двойки"
        case .powerMatrix: "Матрица для модуля 2ᵏ"
        case .direct: "Третья строка матрицы"
        }
    }
    var detail: String {
        switch self {
        case .automatic: "Подходящий метод по виду модуля."
        case .binary: "Нечётный модуль: два столбца; чётный: полные коэффициенты. Для дроби затем умножаем на числитель."
        case .lifting: "Последовательно: mod 2, mod 4, mod 8… Только для степени двойки."
        case .powerMatrix: "Вспомогательные строки, представляющие ноль. Только для степени двойки."
        case .direct: "Накапливаем числитель и ответ в третьей строке, без отдельного вычисления обратного."
        }
    }
}

enum ModularError: Error, LocalizedError {
    case modulus, powerRequired, inverseOnly
    var errorDescription: String? {
        switch self {
        case .modulus: "Модуль m должен быть целым числом больше 1."
        case .powerRequired: "Этот метод применим только к модулю 2ᵏ. Выберите другой метод или измените модуль."
        case .inverseOnly: "Третья строка используется для деления по модулю."
        }
    }
}

struct ModularRow: Sendable, Equatable {
    var value: Natural
    var alpha: DecimalInteger
    var beta: DecimalInteger? = nil
    var cells: [String] { [value.description, alpha.description] + (beta.map { [$0.description] } ?? []) }
}

enum ModularAction: String, Sendable {
    case initial, adjust, halve, subtract, accumulate
}
struct ModularFrame: Identifiable, Sendable {
    let id: Int
    let operation: String
    let explanation: String
    let arithmetic: [String]
    let rows: [ModularRow]
    let action: ModularAction
    let remaining: Natural?
}
struct GCDTrace: Sendable {
    let gcd: Natural
    let lines: [String]
}
struct LiftStage: Identifiable, Sendable {
    let id: Int
    let modulus: Natural
    let previous: Natural
    let baseResidue: Natural
    let product: Natural
    let residue: Natural
    let addition: Natural
    let result: Natural
    let verification: [String]
}
struct ModularSolution: Sendable {
    let input: DecimalInteger
    let numerator: DecimalInteger?
    let modulus: Natural
    let a: Natural
    let target: Natural
    let method: ModularMethod
    let gcdTrace: GCDTrace
    let preparation: [String]
    let frames: [ModularFrame]
    let lifts: [LiftStage]
    let inverse: Natural?
    let result: Natural?
    let multiplication: DoublingSolution?
    let conclusion: [String]
    var isDivision: Bool { numerator != nil }
    var usesExactRows: Bool { !modulus.isOdd || method == .powerMatrix }
}

enum ModularSolver {
    static func solve(a rawA: String, modulus rawM: String, numerator rawN: String? = nil,
                      method requested: ModularMethod = .automatic,
                      check: () throws -> Void = {}) throws -> ModularSolution {
        try check()
        guard let input = DecimalInteger(text: rawA) else { throw CalculationError.invalidInteger(rawN == nil ? "a" : "v") }
        guard let parsedM = DecimalInteger(text: rawM), !parsedM.isNegative, parsedM.magnitude > .one else { throw ModularError.modulus }
        let m = parsedM.magnitude
        var numerator: DecimalInteger?
        if let rawN {
            guard let value = DecimalInteger(text: rawN) else { throw CalculationError.invalidInteger("u") }
            numerator = value
        }
        let a = try input.residue(m, check: check)
        let target = try numerator?.residue(m, check: check) ?? .one
        let exponent = m.powerOfTwoExponent
        let method: ModularMethod = requested == .automatic ? (rawN != nil ? .direct : (exponent != nil ? .powerMatrix : .binary)) : requested
        if method == .lifting || method == .powerMatrix {
            guard exponent != nil else { throw ModularError.powerRequired }
        }
        if method == .direct && numerator == nil { throw ModularError.inverseOnly }
        var preparation: [String] = []
        func reduction(_ value: DecimalInteger) throws -> [String] {
            let d = try BinaryDivisionSolver.solve(a: value.description, b: m.description, checkCancellation: check)
            var lines = ["Находим остаток \(value) по модулю \(m):"]
            for step in d.steps {
                lines.append("\(step.chosen.power) · \(m) = \(step.chosen.multiple);  \(step.before.number) − \(step.chosen.multiple) = \(step.after)")
            }
            if d.needsRemainderCorrection {
                lines.append("\(m) − \(d.magnitudeRemainder) = \(d.remainder)")
            }
            lines.append(d.identity)
            lines.append("\(value) ≡ \(d.remainder) (mod \(m))")
            return lines
        }
        if input != DecimalInteger(a) { preparation += try reduction(input) }
        if let numerator, numerator != DecimalInteger(target) { preparation += try reduction(numerator) }
        let gcd = try binaryGCD(a, m, check: check)
        var frames: [ModularFrame] = []
        var lifts: [LiftStage] = []
        var inverse: Natural?
        var result: Natural?
        var multiplication: DoublingSolution?
        var conclusion: [String] = []
        if gcd.gcd != .one {
            conclusion.append("НОД(\(a), \(m)) = \(gcd.gcd) ≠ 1")
            conclusion.append("Обратного элемента не существует.")
            if numerator != nil {
                let remainder = try target.divided(by: gcd.gcd, check: check).remainder
                conclusion.append(remainder.isZero
                    ? "Сравнение имеет \(gcd.gcd) классов решений, но дробь через обратный элемент не определена."
                    : "Числитель не делится на НОД: сравнение решений не имеет.")
            }
        } else {
            switch method {
            case .lifting:
                var x = Natural.one
                var current = Natural(2)
                let firstR = try a.divided(by: current, check: check).remainder
                lifts.append(LiftStage(id: 0, modulus: current, previous: .one, baseResidue: firstR, product: a,
                    residue: firstR, addition: .zero, result: x, verification: []))
                for index in 1..<(exponent ?? 1) {
                    try check()
                    let next = current + current
                    let product = a * x
                    let r = try product.divided(by: next, check: check).remainder
                    let add = r == .one ? Natural.zero : current
                    let after = x + add
                    var verification: [String] = []
                    if !add.isZero {
                        let corrected = a * after
                        let division = try corrected.divided(by: next, check: check)
                        verification.append("\(a) · \(after) = \(corrected) = \(next) · \(division.quotient) + \(division.remainder)")
                    }
                    lifts.append(LiftStage(id: index, modulus: next, previous: x, baseResidue: try a.divided(by: next, check: check).remainder, product: product,
                        residue: r, addition: add, result: after, verification: verification))
                    current = next
                    x = after
                }
                inverse = x
            case .powerMatrix:
                let trace = try powerMatrix(a, m, check: check)
                frames = trace.frames
                inverse = try trace.coefficient.residue(m, check: check)
                conclusion.append("\(trace.coefficient) ≡ \(inverse!) (mod \(m))")
            case .binary, .automatic, .direct:
                let trace = try binaryMatrix(a, m, target: method == .direct ? target : nil, check: check)
                frames = trace.frames
                let residue = try trace.coefficient.residue(m, check: check)
                conclusion.append("\(trace.coefficient) ≡ \(residue) (mod \(m))")
                if method == .direct { result = residue } else { inverse = residue }
            }
            if let inverse {
                conclusion.append("\(a)⁻¹ ≡ \(inverse) (mod \(m))")
                if numerator != nil {
                    multiplication = try DoublingSolver.solve(a: target.description, b: inverse.description, modulus: m.description,
                                                             checkCancellation: check)
                    result = multiplication?.answer
                } else { result = inverse }
            }
            if let result {
                let product = a * result
                let division = try product.divided(by: m, check: check)
                conclusion.append("\(a) · \(result) = \(product) = \(m) · \(division.quotient) + \(division.remainder)")
                conclusion.append("\(a) · \(result) ≡ \(target) (mod \(m))")
            }
        }
        try check()
        return ModularSolution(input: input, numerator: numerator, modulus: m, a: a, target: target,
            method: method, gcdTrace: gcd, preparation: preparation, frames: frames, lifts: lifts,
            inverse: inverse, result: result, multiplication: multiplication, conclusion: conclusion)
    }

    /// Stein's gcd. Every available halving precedes subtraction; the common
    /// factor is tracked explicitly. Zero terminates rather than being halved.
    static func binaryGCD(_ a: Natural, _ b: Natural, check: () throws -> Void) throws -> GCDTrace {
        var u = a, v = b, factor = Natural.one
        var lines = ["НОД(\(u), \(v))"]
        while !u.isZero && !v.isZero && u != v {
            try check()
            if !u.isOdd && !v.isOdd {
                let x = u.halved(), y = v.halved()
                lines.append("НОД(\(u), \(v)) = 2 · НОД(\(x), \(y))")
                u = x; v = y; factor = factor + factor
            } else if !u.isOdd {
                lines.append("\(u) : 2 = \(u.halved()); НОД(\(u), \(v)) = НОД(\(u.halved()), \(v))")
                u = u.halved()
            } else if !v.isOdd {
                lines.append("\(v) : 2 = \(v.halved()); НОД(\(u), \(v)) = НОД(\(u), \(v.halved()))")
                v = v.halved()
            } else if u > v {
                lines.append("\(u) − \(v) = \(u - v); НОД(\(u), \(v)) = НОД(\(u - v), \(v))")
                u = u - v
            } else {
                lines.append("\(v) − \(u) = \(v - u); НОД(\(u), \(v)) = НОД(\(u), \(v - u))")
                v = v - u
            }
        }
        let result = factor * (u.isZero ? v : u)
        lines.append("НОД(\(a), \(b)) = \(factor) · \(u.isZero ? v : u) = \(result)")
        return GCDTrace(gcd: result, lines: lines)
    }

    private struct MatrixResult {
        let frames: [ModularFrame]
        let coefficient: DecimalInteger
    }
    private static func rowLabel(_ i: Int) -> String { ["₁", "₂", "₃"][i] }

    private static func binaryMatrix(_ a: Natural, _ m: Natural, target: Natural?,
                                     check: () throws -> Void) throws -> MatrixResult {
        let exact = !m.isOdd
        // The fraction template starts with the modulus; inversion with a.
        let aRow = ModularRow(value: a, alpha: .one, beta: exact ? .zero : nil)
        let mRow = ModularRow(value: m, alpha: .zero, beta: exact ? .one : nil)
        var rows = target == nil ? [aRow, mRow] : [mRow, aRow, ModularRow(value: .zero, alpha: .zero, beta: exact ? .zero : nil)]
        var frames: [ModularFrame] = []
        var remaining = target
        func record(_ action: ModularAction, _ operation: String, _ note: String, _ arithmetic: [String] = []) {
            frames.append(ModularFrame(id: frames.count, operation: operation, explanation: note,
                arithmetic: arithmetic, rows: rows, action: action, remaining: remaining))
        }
        record(.initial, "Исходная матрица", exact ? "Каждая строка: число = α·\(a) + β·\(m)." : "Каждая строка: число ≡ α·\(a) (mod \(m)).")
        while true {
            try check()
            if let remaining, remaining.isZero { return MatrixResult(frames: frames, coefficient: rows[2].alpha) }
            if target == nil, let unit = rows.prefix(2).first(where: { $0.value == .one }) {
                return MatrixResult(frames: frames, coefficient: unit.alpha)
            }
            // Test each new working matrix before transforming it again. Once
            // captured, continue reducing the working rows rather than batching
            // arbitrary multiples of the same row into the accumulator.
            if let rest = remaining, frames.last?.action != .accumulate {
                let candidates = (0..<2).filter { !rows[$0].value.isZero && rows[$0].value <= rest }
                if let index = candidates.max(by: { rows[$0].value < rows[$1].value }) {
                    let source = rows[index]
                    // Only rows with left entry 1 or 2 allow a general factor.
                    let factor = source.value <= Natural(2)
                        ? try rest.divided(by: source.value, check: check).quotient : .one
                    let before = rows[2]
                    rows[2].value = before.value + source.value * factor
                    rows[2].alpha = before.alpha + source.alpha * DecimalInteger(factor)
                    if exact { rows[2].beta = before.beta! + source.beta! * DecimalInteger(factor) }
                    remaining = rest - source.value * factor
                    let arithmetic = zip(before.cells, zip(source.cells, rows[2].cells)).map { old, pair in
                        factor == .one ? "\(old) + (\(pair.0)) = \(pair.1)"
                            : "\(old) + \(factor) · (\(pair.0)) = \(pair.1)"
                    } + ["\(target!) − \(rows[2].value) = \(remaining!)"]
                    record(.accumulate, "M₃,\(rowLabel(index))(\(factor))",
                           factor == .one
                           ? "Рабочая строка подходит под условие: сразу прибавляем её к третьей. Обновляем условие, затем продолжаем преобразования рабочих строк."
                           : "Слева в рабочей строке 1 или 2: разрешено умножить её на нужное целое число и добавить к третьей. Обновляем условие.",
                           arithmetic)
                    continue
                }
            }
            // Capturing a suitable row is done first in direct division. Among
            // working-row transformations, halving still precedes subtraction.
            if let index = (0..<2).first(where: { !rows[$0].value.isZero && !rows[$0].value.isOdd }) {
                let original = rows[index]
                if exact {
                    if original.alpha.isOdd || original.beta!.isOdd {
                        let plus = original.alpha + DecimalInteger(m)
                        let minus = original.alpha - DecimalInteger(m)
                        let usePlus = plus.magnitude <= minus.magnitude
                        rows[index].alpha = usePlus ? plus : minus
                        rows[index].beta = usePlus ? original.beta! - DecimalInteger(a) : original.beta! + DecimalInteger(a)
                        record(.adjust, "R\(rowLabel(index)) + (0 | \(usePlus ? m.description : "−\(m)") | \(usePlus ? "−\(a)" : a.description))",
                               "Добавляем представление нуля; обе координаты должны стать чётными.",
                               ["α: \(original.alpha) \(usePlus ? "+" : "−") \(m) = \(rows[index].alpha)",
                                "β: \(original.beta!) \(usePlus ? "−" : "+") \(a) = \(rows[index].beta!)"])
                    }
                } else if original.alpha.isOdd {
                    let residue = try original.alpha.residue(m, check: check)
                    let even = residue.isOdd ? DecimalInteger(residue) - DecimalInteger(m) : DecimalInteger(residue)
                    rows[index].alpha = even
                    record(.adjust, "Выбираем чётный представитель", "Отрицательный коэффициент допустим. Сначала приводим его к чётному представителю, затем делим строку.",
                           ["\(original.alpha) + \((even - original.alpha).parenthesized) = \(even)",
                            "\(original.alpha) ≡ \(even) (mod \(m))"])
                }
                let before = rows[index]
                rows[index].value = before.value.halved()
                rows[index].alpha = before.alpha.halved()
                rows[index].beta = before.beta?.halved()
                record(.halve, "M\(rowLabel(index))(½)", "Деление пополам имеет приоритет.",
                       zip(before.cells, rows[index].cells).map { "\($0) : 2 = \($1)" })
                continue
            }
            let i = rows[0].value >= rows[1].value ? 0 : 1
            let j = 1 - i
            let before = rows[i]
            rows[i].value = before.value - rows[j].value
            rows[i].alpha = before.alpha - rows[j].alpha
            if exact { rows[i].beta = before.beta! - rows[j].beta! }
            record(.subtract, "M\(rowLabel(i)),\(rowLabel(j))(−1)", "Обе рабочие строки нечётные: вычитаем меньшую из большей.",
                   zip(before.cells, zip(rows[j].cells, rows[i].cells)).map { "\($0) − (\($1.0)) = \($1.1)" })
        }
    }

    private static func powerMatrix(_ a: Natural, _ m: Natural, check: () throws -> Void) throws -> MatrixResult {
        var rows = [ModularRow(value: m, alpha: .zero, beta: .one),
                    ModularRow(value: .zero, alpha: DecimalInteger(m), beta: DecimalInteger(a).negated),
                    ModularRow(value: .zero, alpha: DecimalInteger(m).negated, beta: DecimalInteger(a))]
        var frames: [ModularFrame] = []
        func record(_ action: ModularAction, _ operation: String, _ explanation: String, _ arithmetic: [String] = []) {
            frames.append(ModularFrame(id: frames.count, operation: operation, explanation: explanation,
                arithmetic: arithmetic, rows: rows, action: action, remaining: nil))
        }
        record(.initial, "Исходная матрица", "Каждая строка: число = α·\(a) + β·\(m). Вторая и третья строки представляют ноль.",
               ["0 = \(m) · \(a) − \(a) · \(m)"])
        while rows[0].value != .one {
            try check()
            if rows[0].alpha.isOdd || rows[0].beta!.isOdd {
                let plus = rows[0].alpha + rows[1].alpha
                let minus = rows[0].alpha + rows[2].alpha
                let j = plus.magnitude <= minus.magnitude ? 1 : 2
                let before = rows[0]
                rows[0].alpha = before.alpha + rows[j].alpha
                rows[0].beta = before.beta! + rows[j].beta!
                record(.adjust, "M₁,\(rowLabel(j))(1)", "Добавляем нулевую строку, чтобы оба коэффициента делились на 2. Из двух вариантов выбираем меньший модуль α.",
                       ["\(before.alpha) + (\(rows[j].alpha)) = \(rows[0].alpha)",
                        "\(before.beta!) + (\(rows[j].beta!)) = \(rows[0].beta!)"])
            }
            let before = rows[0]
            rows[0].value = before.value.halved()
            rows[0].alpha = before.alpha.halved()
            rows[0].beta = before.beta!.halved()
            record(.halve, "M₁(½)", "Сразу делим рабочую строку пополам.", zip(before.cells, rows[0].cells).map { "\($0) : 2 = \($1)" })
        }
        return MatrixResult(frames: frames, coefficient: rows[0].alpha)
    }
}
