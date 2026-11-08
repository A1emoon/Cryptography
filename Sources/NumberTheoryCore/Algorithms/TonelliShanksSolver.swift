import Foundation

/// At each stage a^A b^C is an n-th root of unity. Multiplying by B^j makes it 1;
/// only then may its exponents be divided by n, leaving another n-th root of unity.
struct TonelliDescent: Identifiable, Sendable {
    let id: Int
    let level: Int
    let aPower: RecordedPower
    let bPower: RecordedPower
    let value: UInt64
    let choice: Int
    let correction: RecordedPower
    let bExponentAfter: UInt64
}
struct TonelliSolution: Sendable {
    let input: DecimalInteger
    let a: UInt64
    let p: UInt64
    let degree: Int
    var criterion: RecordedPower?
    var quadraticCriterion: LegendreTrace?
    var s = 0
    var r: UInt64 = 0
    /// The notes write (a^r)^(n*k)=1; k is the order divided by n, not an inverse of r.
    var k: UInt64 = 0
    var orderExponent = 0
    var initial: RecordedPower?
    var orderTests: [RecordedPower] = []
    var nonResidue: UInt64?
    var nonResidueTrials: [RecordedPower] = []
    var quadraticTrials: [LegendreTrace] = []
    var B: UInt64?
    var unityPowers: [RecordedPower] = []
    var descents: [TonelliDescent] = []
    var identityBExponent: UInt64 = 0
    var rootMultiplier: UInt64 = 1
    var rootAPower: RecordedPower?
    var rootBPower: RecordedPower?
    var seedRoot: UInt64?
    var orderedRoots: [UInt64] = []
    var roots: [UInt64] = []
    var verification: [RecordedPower] = []
    var steps: [NumberStep] = []
}

/// The handwritten lecture construction, using a^r, B and successive outer n-th powers.
/// All computations stay exact; roots are verified independently against the original residue.
enum TonelliShanksSolver {
    static func solve(a rawA: String, p rawP: String, degree n: Int = 2, check: () throws -> Void = {}) throws -> TonelliSolution {
        guard n == 2 || n == 3 else { throw NumberTheoryError.degree }
        let input = try Mod64.integer(rawA, name: "a")
        let p = try Mod64.modulus(rawP, prime: true, check: check)
        let a = try Mod64.residue(input, p, check: check), degree = UInt64(n)
        var result = TonelliSolution(input: input, a: a, p: p, degree: n)
        func finish(_ values: [UInt64]) throws -> TonelliSolution {
            result.orderedRoots = values
            result.roots = Array(Set(values)).sorted()
            result.verification = try result.roots.enumerated().map {
                try RecordedPower.calculate($0.element, degree, p, id: "root_\($0.offset)", check: check)
            }
            guard result.verification.allSatisfy({ $0.result == a }) else { throw NumberTheoryError.invariant }
            return result
        }
        if a == 0 { result.seedRoot = 0; return try finish([0]) }
        if p == degree || p == 2 {
            result.seedRoot = a
            result.steps = [NumberStep(id: "frobenius", equations: ["x\(n == 2 ? "²" : "³") ≡ x (mod \(p))", "x ≡ \(a) (mod \(p))"], explanation: "В характеристике p верно xᵖ=x. Здесь исходное сравнение имеет единственный корень a.", theorem: "fermat")]
            return try finish([a])
        }
        if (p - 1) % degree != 0 {
            let inverse = try ModularSolver.solve(a: String(n), modulus: String(p - 1), method: .binary, check: check)
            guard let e = inverse.inverse, let exponent = UInt64(e.description) else { throw NumberTheoryError.invariant }
            let power = try RecordedPower.calculate(a, exponent, p, id: "unique", check: check)
            result.seedRoot = power.result
            result.steps = [NumberStep(id: "unique", equations: ["НОД(\(n), \(p - 1)) = 1", "\(n) · \(exponent) ≡ 1 (mod \(p - 1))", "x ≡ \(power.expression) ≡ \(power.result) (mod \(p))"], explanation: "Возведение в n-ю степень переставляет ненулевые остатки, поскольку НОД(n,p−1)=1. Поэтому единственный корень получается возведением a в степень, обратную к n по p−1.", theorem: "power-coprime", powers: [power])]
            return try finish([power.result])
        }
        let criterion = try RecordedPower.calculate(a, (p - 1) / degree, p, id: "criterion", check: check)
        result.criterion = criterion
        if n == 2 {
            let symbol = try LegendreSolver.solve(DecimalInteger(Natural(a)), modulus: Natural(p), check: check)
            guard (symbol.value == 1) == (criterion.result == 1) else { throw NumberTheoryError.invariant }
            result.quadraticCriterion = symbol
        }
        guard criterion.result == 1 else { return try finish([]) }
        var r = p - 1, s = 0
        while r % degree == 0 { try check(); r /= degree; s += 1 }
        result.r = r; result.s = s
        let initial = try RecordedPower.calculate(a, r, p, id: "initial", check: check)
        result.initial = initial
        var order: UInt64 = 1, value = initial.result
        while value != 1 {
            try check()
            order *= degree
            let test = try RecordedPower.calculate(initial.result, order, p, id: "order_\(result.orderTests.count)", check: check)
            result.orderTests.append(test); value = test.result
            result.orderExponent += 1
            guard result.orderExponent < s else { throw NumberTheoryError.invariant }
        }
        result.k = result.orderExponent == 0 ? 0 : order / degree
        // A primitive n-th root of unity is also required to enumerate all cubic roots.
        if result.orderExponent > 0 || n == 3 {
            var candidate: UInt64 = 2
            while candidate < p {
                try check()
                let trial = try RecordedPower.calculate(candidate, (p - 1) / degree, p, id: "trial_\(candidate)", check: check)
                result.nonResidueTrials.append(trial)
                if n == 2 { result.quadraticTrials.append(try LegendreSolver.solve(DecimalInteger(Natural(candidate)), modulus: Natural(p), check: check)) }
                if trial.result != 1 { result.nonResidue = candidate; result.B = trial.result; break }
                candidate += 1
            }
            guard let B = result.B else { throw NumberTheoryError.invariant }
            result.unityPowers = try (2...n).map { try RecordedPower.calculate(B, UInt64($0), p, id: "B_\($0)", check: check) }
            guard result.unityPowers.last?.result == 1, B != 1 else { throw NumberTheoryError.invariant }
        }
        var A = r * max(1, order / degree), C: UInt64 = 0
        if result.orderExponent > 0 {
            guard let b = result.nonResidue, let B = result.B else { throw NumberTheoryError.invariant }
            let E = (p - 1) / degree
            for level in stride(from: result.orderExponent - 1, through: 0, by: -1) {
                try check()
                let aPower = try RecordedPower.calculate(a, A, p, id: "descent_a_\(level)", check: check)
                let bPower = try RecordedPower.calculate(b, C, p, id: "descent_b_\(level)", check: check)
                let z = Mod64.multiply(aPower.result, bPower.result, p)
                guard try Mod64.power(z, degree, p, check: check) == 1 else { throw NumberTheoryError.invariant }
                var j = 0
                while j < n {
                    let unit = try Mod64.power(B, UInt64(j), p, check: check)
                    if Mod64.multiply(z, unit, p) == 1 { break }
                    j += 1
                }
                guard j < n else { throw NumberTheoryError.invariant }
                let correction = try RecordedPower.calculate(b, UInt64(j) * E, p, id: "descent_factor_\(level)", check: check)
                // C < E before each correction, so C+jE <= p-1 even at the UInt64 boundary.
                let (nextC, overflow) = C.addingReportingOverflow(correction.exponent)
                guard !overflow, nextC <= p - 1, Mod64.multiply(z, correction.result, p) == 1 else { throw NumberTheoryError.invariant }
                result.descents.append(TonelliDescent(id: result.descents.count, level: level, aPower: aPower, bPower: bPower, value: z, choice: j, correction: correction, bExponentAfter: nextC))
                C = nextC
                if level > 0 {
                    guard A % degree == 0, C % degree == 0 else { throw NumberTheoryError.invariant }
                    A /= degree; C /= degree
                }
            }
        }
        guard A == r, C % degree == 0 else { throw NumberTheoryError.invariant }
        result.identityBExponent = C
        // For cubic comparisons with r=1 mod 3, square the identity first. This is
        // distinct from the lecture's k and is shown as an explicit equation.
        let multiplier: UInt64 = (r + 1) % degree == 0 ? 1 : 2
        result.rootMultiplier = multiplier
        let aExponent = (multiplier * r + 1) / degree
        // Divide before multiplying: the formal exponent multiplier*C may exceed UInt64.
        let bExponent = multiplier * (C / degree)
        let aPower = try RecordedPower.calculate(a, aExponent, p, id: "a_root", check: check)
        let bPower = try RecordedPower.calculate(result.nonResidue ?? 1, bExponent, p, id: "b_root", check: check)
        result.rootAPower = aPower; result.rootBPower = bPower
        let seed = Mod64.multiply(aPower.result, bPower.result, p)
        result.seedRoot = seed
        if n == 2 { return try finish([seed, p - seed]) }
        guard let B = result.B else { throw NumberTheoryError.invariant }
        let second = Mod64.multiply(seed, B, p)
        return try finish([seed, second, Mod64.multiply(second, B, p)])
    }
}
