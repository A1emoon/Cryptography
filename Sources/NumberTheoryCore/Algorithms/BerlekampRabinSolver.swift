import Foundation

enum RabinError: LocalizedError {
    case prime, range, invariant
    var errorDescription: String? {
        switch self {
        case .prime: "q должно быть простым числом не меньше 2. Для составного модуля этот алгоритм неприменим."
        case .range: "Точная проверка простоты поддерживает q ≤ 18446744073709551615. Коэффициенты могут иметь произвольную длину."
        case .invariant: "Не удалось подтвердить разложение или корни. Результат не выведен."
        }
    }
}
struct RabinSplit: Identifiable, Sendable {
    let id: Int
    let factorID: Int
    let factor: Polynomial
    let delta: Natural
    let power: FieldPower
    let testPolynomial: Polynomial
    let gcd: FieldGCD
    let cofactor: FieldDivision?
    let childIDs: [Int]
    var didSplit: Bool { cofactor != nil }
}
struct RabinLinearRoot: Identifiable, Sendable {
    let id: Int
    let factor: Polynomial
    let root: Natural
}
struct RabinHornerStep: Identifiable, Sendable {
    let id: Int
    let before: Natural
    let coefficient: Natural
    let product: Natural
    let sum: Natural
    let result: Natural
}
struct RabinVerification: Identifiable, Sendable {
    let id: Int
    let root: Natural
    let steps: [RabinHornerStep]
    var value: Natural { steps.last?.result ?? .zero }
}
enum RabinOutcome: Sendable, Equatable { case finite, noRoots, allResidues, binaryField }
struct RabinSolution: Sendable {
    let raw: [DecimalInteger]
    let input: Polynomial
    let normalization: FieldNormalization
    let q: Natural
    let zeroMultiplicity: Int
    let residual: Polynomial
    let power: FieldPower?
    let initialGCD: FieldGCD?
    let splits: [RabinSplit]
    let linearRoots: [RabinLinearRoot]
    let roots: [Natural]
    let verification: [RabinVerification]
    let outcome: RabinOutcome
    let binaryValues: [Natural]
}
enum BerlekampRabinSolver {
    static func solve(coefficients: String, q rawQ: String,
                      check: () throws -> Void = {}) throws -> RabinSolution {
        try check()
        guard let parsed = DecimalInteger(text: rawQ), !parsed.isNegative, parsed.magnitude > .one else { throw RabinError.prime }
        guard let nativeQ = UInt64(parsed.magnitude.description) else { throw RabinError.range }
        guard try Prime64.isPrime(nativeQ, check: check) else { throw RabinError.prime }
        let q = parsed.magnitude, field = PolynomialField(p: parsed.magnitude, nativePrime: nativeQ)
        let raw = try PolynomialSolver.parse(coefficients, name: "f")
        let input = Polynomial(try raw.reversed().map { try check(); return try $0.residue(q, check: check) })
        let normalization = try field.monic(input, check: check)
        var residual = normalization.result, zeroMultiplicity = 0
        var initialPower: FieldPower?, initialGCD: FieldGCD?
        var splits: [RabinSplit] = [], linearRoots: [RabinLinearRoot] = [], roots: [Natural] = [], binaryValues: [Natural] = []
        func finish(_ outcome: RabinOutcome) throws -> RabinSolution {
            roots.sort()
            let verification = try roots.enumerated().map { index, root -> RabinVerification in
                var value = Natural.zero, steps: [RabinHornerStep] = []
                for c in input.coefficients.reversed() {
                    try check()
                    let product = value * root, sum = product + c
                    let next = try field.residue(sum, check: check)
                    steps.append(RabinHornerStep(id: steps.count, before: value, coefficient: c,
                        product: product, sum: sum, result: next))
                    value = next
                }
                guard value.isZero else { throw RabinError.invariant }
                return RabinVerification(id: index, root: root, steps: steps)
            }
            return RabinSolution(raw: raw, input: input, normalization: normalization, q: q,
                zeroMultiplicity: zeroMultiplicity, residual: residual, power: initialPower, initialGCD: initialGCD,
                splits: splits, linearRoots: linearRoots, roots: roots, verification: verification, outcome: outcome, binaryValues: binaryValues)
        }
        if input.isZero { return try finish(.allResidues) }
        if input.degree == 0 { return try finish(.noRoots) }
        if nativeQ == 2 {
            for r in [Natural.zero, .one] {
                let value = try field.evaluate(input, at: r, check: check)
                binaryValues.append(value)
                if value.isZero { roots.append(r) }
            }
            return try finish(.binaryField)
        }
        while residual.degree > 0 && residual[0].isZero {
            try check(); zeroMultiplicity += 1
            residual = Polynomial(Array(residual.coefficients.dropFirst()))
        }
        if zeroMultiplicity > 0 { roots.append(.zero) }
        if residual.degree == 0 { return try finish(.finite) }
        let power = try field.power(PolynomialField.x, q - .one, modulo: residual, check: check)
        initialPower = power
        let test = try field.subtract(power.result, PolynomialField.one, check: check)
        let gcd = try field.gcd(residual, test, check: check)
        initialGCD = gcd
        var nextID = 2
        var pending: [(Int, Polynomial)] = gcd.result.degree > 0 ? [(1, gcd.result)] : []
        while !pending.isEmpty {
            try check()
            let (id, factor) = pending.removeFirst()
            if factor.degree == 1 {
                let root = factor[0].isZero ? .zero : q - factor[0]
                guard !roots.contains(root) else { throw RabinError.invariant }
                roots.append(root); linearRoots.append(RabinLinearRoot(id: id, factor: factor, root: root))
                continue
            }
            var delta = Natural.zero, didSplit = false
            while delta < q {
                try check()
                let base = Polynomial([delta, .one])
                let power = try field.power(base, (q - .one).halved(), modulo: factor, check: check)
                let test = try field.subtract(power.result, PolynomialField.one, check: check)
                let h = try field.gcd(factor, test, check: check)
                let isProper = h.result.degree > 0 && h.result.degree < factor.degree
                let division = isProper ? try field.divide(factor, by: h.result, check: check) : nil
                if let division, !division.remainder.isZero { throw RabinError.invariant }
                let childIDs = isProper ? [nextID, nextID + 1] : []
                splits.append(RabinSplit(id: splits.count, factorID: id, factor: factor, delta: delta,
                    power: power, testPolynomial: test, gcd: h, cofactor: division, childIDs: childIDs))
                if let division {
                    pending.append((nextID, h.result)); pending.append((nextID + 1, division.quotient))
                    nextID += 2; didSplit = true; break
                }
                // Both h=1 and h=g are unsuccessful: advance the shift.
                delta = delta + .one
            }
            guard didSplit else { throw RabinError.invariant }
        }
        guard roots.count == gcd.result.degree + (zeroMultiplicity > 0 ? 1 : 0) else { throw RabinError.invariant }
        return try finish(roots.isEmpty ? .noRoots : .finite)
    }
}
