import Foundation

/// Coefficients in ascending degree order, reduced modulo the coefficient modulus.
struct Polynomial: Equatable, Sendable {
    private(set) var coefficients: [Natural]
    init(_ coefficients: [Natural]) {
        self.coefficients = coefficients
        while self.coefficients.last == .zero { self.coefficients.removeLast() }
    }
    static let zero = Polynomial([])
    var isZero: Bool { coefficients.isEmpty }
    var degree: Int { coefficients.count - 1 }
    var weight: Int { coefficients.filter { !$0.isZero }.count }
    var leading: Natural { coefficients.last ?? .zero }
    subscript(_ index: Int) -> Natural { index < coefficients.count ? coefficients[index] : .zero }
    func shifted(_ count: Int = 1) -> Self {
        isZero ? self : Self(Array(repeating: .zero, count: count) + coefficients)
    }
    func vector(width: Int = 0) -> String {
        Self.vector((0..<max(1, max(width, coefficients.count))).map { DecimalInteger(self[$0]) })
    }
    static func vector(_ ascending: [DecimalInteger]) -> String {
        ascending.isEmpty ? "(0)" : "(" + ascending.reversed().map(\.description).joined(separator: ", ") + ")"
    }
    static func power(_ degree: Int) -> String {
        if degree == 0 { return "1" }
        if degree == 1 { return "α" }
        let digits = Array("⁰¹²³⁴⁵⁶⁷⁸⁹")
        return "α" + String(degree).compactMap { $0.wholeNumberValue.map { String(digits[$0]) } }.joined()
    }
    var formula: String {
        let terms = coefficients.indices.reversed().compactMap { i -> String? in
            let c = coefficients[i]
            guard !c.isZero else { return nil }
            if i == 0 { return c.description }
            return (c == .one ? "" : c.description) + Self.power(i)
        }
        return terms.isEmpty ? "0" : terms.joined(separator: " + ")
    }
}

enum PolynomialError: LocalizedError {
    case coefficients(String), modulus, polynomialModulus, monic
    var errorDescription: String? {
        switch self {
        case .coefficients(let name): "\(name): введите целые коэффициенты через запятую или пробел, от старшей степени к свободному члену. Нулевые коэффициенты внутри вектора обязательны."
        case .modulus: "Модуль коэффициентов p должен быть целым числом не меньше 2."
        case .polynomialModulus: "После приведения коэффициентов M должен иметь степень не меньше 1."
        case .monic: "Для этого алгоритма старший коэффициент M после приведения по p должен быть равен 1, как в конспекте."
        }
    }
}

struct PolynomialInput: Sendable {
    let name: String
    let raw: [DecimalInteger] // descending, including entered leading zeros
    let polynomial: Polynomial
    let reductions: [String]
    var vector: String { "(" + raw.map(\.description).joined(separator: ", ") + ")" }
}

enum PolynomialAction: Sendable { case scale, shift, subtract, add }
struct PolynomialStep: Identifiable, Sendable {
    let id: Int
    let action: PolynomialAction
    let before: Polynomial
    let operand: Polynomial?
    let factor: Natural
    let shift: Int
    let raw: [DecimalInteger] // ascending, not trimmed, before coefficient reduction
    let result: Polynomial
    var width: Int { max(1, raw.count) }
    var rawVector: String { Polynomial.vector(raw) }
    var reducedVector: String { result.vector(width: width) }
    var needsCoefficientReduction: Bool {
        raw.enumerated().contains { $0.element != DecimalInteger(result[$0.offset]) }
    }
    var title: String {
        switch action {
        case .scale: "Умножаем коэффициенты на \(factor)"
        case .shift: "Сдвиг: умножаем на α"
        case .subtract: "Вычитаем \(factor)·\(shift == 0 ? "M" : "\(Polynomial.power(shift))·M")"
        case .add: "Прибавляем верхнюю ячейку"
        }
    }
}
struct PolynomialColumn: Identifiable, Sendable {
    let id: Int
    let exponent: Int
    let coefficient: Natural
    let addition: Polynomial
    let scaling: PolynomialStep
    let steps: [PolynomialStep]
    let result: Polynomial
}
struct PolynomialSolution: Sendable {
    let a: PolynomialInput
    let b: PolynomialInput
    let m: PolynomialInput
    let p: Natural
    let multiplierName: String
    let multiplier: Polynomial
    let baseName: String
    let base: Polynomial
    let preparation: [PolynomialStep]
    let selection: String
    let columns: [PolynomialColumn]
    let result: Polynomial
    let verificationProduct: Polynomial
    let verificationSteps: [PolynomialStep]
    var expression: String { "(\(a.polynomial.formula)) · (\(b.polynomial.formula)) mod (\(m.polynomial.formula), \(p))" }
}

enum PolynomialSolver {
    static func parse(_ text: String, name: String) throws -> [DecimalInteger] {
        var text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.first == "(" && text.last == ")" { text = String(text.dropFirst().dropLast()) }
        guard !text.isEmpty else { throw PolynomialError.coefficients(name) }
        let parts: [String]
        if text.contains(",") || text.contains(";") {
            parts = text.replacingOccurrences(of: ";", with: ",").components(separatedBy: ",")
        } else {
            parts = text.split(whereSeparator: \.isWhitespace).map(String.init)
        }
        let values = parts.compactMap { DecimalInteger(text: $0) }
        guard !values.isEmpty, values.count == parts.count else { throw PolynomialError.coefficients(name) }
        return values
    }

    static func solve(a: String, b: String, m: String, p rawP: String,
                      check: () throws -> Void = {}) throws -> PolynomialSolution {
        try check()
        guard let parsedP = DecimalInteger(text: rawP), !parsedP.isNegative, parsedP.magnitude > .one else {
            throw PolynomialError.modulus
        }
        let p = parsedP.magnitude
        func input(_ text: String, _ name: String) throws -> PolynomialInput {
            let raw = try parse(text, name: name)
            var residues: [Natural] = []
            var reductions: [String] = []
            for c in raw {
                try check()
                let division = try c.magnitude.divided(by: p, check: check)
                let r = c.isNegative && !division.remainder.isZero ? p - division.remainder : division.remainder
                residues.append(r)
                if c != DecimalInteger(r) {
                    reductions.append("\(c.magnitude) = \(division.quotient) · \(p) + \(division.remainder)")
                    if c.isNegative && !division.remainder.isZero {
                        reductions.append("\(p) − \(division.remainder) = \(r)")
                    }
                    reductions.append("\(c) ≡ \(r) (mod \(p))")
                }
            }
            return PolynomialInput(name: name, raw: raw, polynomial: Polynomial(residues.reversed()), reductions: reductions)
        }
        let a = try input(a, "A"), b = try input(b, "B"), m = try input(m, "M")
        guard m.polynomial.degree >= 1 else { throw PolynomialError.polynomialModulus }
        guard m.polynomial.leading == .one else { throw PolynomialError.monic }
        // Least Hamming weight; ties use smaller degree, then retain A.
        let chooseA = a.polynomial.weight < b.polynomial.weight ||
            (a.polynomial.weight == b.polynomial.weight && a.polynomial.degree <= b.polynomial.degree)
        let multiplierInput = chooseA ? a : b, baseInput = chooseA ? b : a
        let multiplier = multiplierInput.polynomial
        let reduction = try reduce(baseInput.polynomial, by: m.polynomial, p: p, check: check)
        let base = reduction.result
        let selection = "w(A) = \(a.polynomial.weight), w(B) = \(b.polynomial.weight). Коэффициенты берём из \(multiplierInput.name): меньше ненулевых коэффициентов; при равенстве — меньшая степень, затем A."
        var columns: [PolynomialColumn] = []
        var result = Polynomial.zero
        for exponent in stride(from: max(0, multiplier.degree), through: 0, by: -1) {
            try check()
            let coefficient = multiplier[exponent]
            let scaling = try scale(base, by: coefficient, p: p, id: exponent, check: check)
            var steps: [PolynomialStep] = []
            if columns.isEmpty {
                result = scaling.result
            } else {
                let shifted = result.shifted()
                steps.append(PolynomialStep(id: 0, action: .shift, before: result, operand: nil,
                    factor: .one, shift: 1, raw: shifted.coefficients.map(DecimalInteger.init), result: shifted))
                let reduced = try reduce(shifted, by: m.polynomial, p: p, check: check)
                for s in reduced.steps { steps.append(reindex(s, steps.count)) }
                let before = reduced.result
                let raw = (0..<max(before.coefficients.count, scaling.result.coefficients.count)).map {
                    DecimalInteger(before[$0] + scaling.result[$0])
                }
                result = try normalized(raw, p: p, check: check)
                steps.append(PolynomialStep(id: steps.count, action: .add, before: before, operand: scaling.result,
                    factor: .one, shift: 0, raw: raw, result: result))
            }
            columns.append(PolynomialColumn(id: columns.count, exponent: exponent, coefficient: coefficient,
                addition: scaling.result, scaling: scaling, steps: steps, result: result))
        }
        let product = try convolution(a.polynomial, b.polynomial, p: p, check: check)
        let verification = try reduce(product, by: m.polynomial, p: p, check: check)
        assert(verification.result == result)
        try check()
        return PolynomialSolution(a: a, b: b, m: m, p: p, multiplierName: multiplierInput.name,
            multiplier: multiplier, baseName: baseInput.name, base: base, preparation: reduction.steps,
            selection: selection, columns: columns, result: result,
            verificationProduct: product, verificationSteps: verification.steps)
    }

    private static func normalized(_ raw: [DecimalInteger], p: Natural, check: () throws -> Void) throws -> Polynomial {
        Polynomial(try raw.map { try check(); return try $0.residue(p, check: check) })
    }
    private static func scale(_ value: Polynomial, by factor: Natural, p: Natural, id: Int,
                              check: () throws -> Void) throws -> PolynomialStep {
        let raw = try value.coefficients.map { c in try check(); return DecimalInteger(c * factor) }
        return PolynomialStep(id: id, action: .scale, before: value, operand: nil, factor: factor,
            shift: 0, raw: raw, result: try normalized(raw, p: p, check: check))
    }
    private static func reindex(_ s: PolynomialStep, _ id: Int) -> PolynomialStep {
        PolynomialStep(id: id, action: s.action, before: s.before, operand: s.operand,
                       factor: s.factor, shift: s.shift, raw: s.raw, result: s.result)
    }
    static func reduce(_ value: Polynomial, by m: Polynomial, p: Natural,
                       check: () throws -> Void = {}) throws -> (result: Polynomial, steps: [PolynomialStep]) {
        precondition(m.degree >= 1 && m.leading == .one)
        var value = value
        var steps: [PolynomialStep] = []
        while value.degree >= m.degree {
            try check()
            let shift = value.degree - m.degree, factor = value.leading
            let multiple = try scale(m.shifted(shift), by: factor, p: p, id: 0, check: check).result
            let raw = (0..<value.coefficients.count).map { DecimalInteger(value[$0]) - DecimalInteger(multiple[$0]) }
            let result = try normalized(raw, p: p, check: check)
            steps.append(PolynomialStep(id: steps.count, action: .subtract, before: value, operand: multiple,
                factor: factor, shift: shift, raw: raw, result: result))
            value = result
        }
        return (value, steps)
    }
    /// Independent multiplication for checking the Horner table.
    static func convolution(_ a: Polynomial, _ b: Polynomial, p: Natural,
                            check: () throws -> Void = {}) throws -> Polynomial {
        if a.isZero || b.isZero { return .zero }
        var raw = Array(repeating: DecimalInteger.zero, count: a.degree + b.degree + 1)
        for i in a.coefficients.indices {
            for j in b.coefficients.indices {
                try check()
                raw[i + j] = raw[i + j] + DecimalInteger(a[i] * b[j])
            }
        }
        return try normalized(raw, p: p, check: check)
    }
}
