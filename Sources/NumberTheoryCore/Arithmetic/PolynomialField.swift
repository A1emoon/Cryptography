import Foundation

struct FieldDivisionStep: Identifiable, Sendable {
    let id: Int
    let before: Polynomial
    let factor: Natural
    let shift: Int
    let multiple: Polynomial
    let difference: [DecimalInteger]
    let result: Polynomial
}
struct FieldDivision: Sendable {
    let dividend: Polynomial
    let divisor: Polynomial
    let quotient: Polynomial
    let remainder: Polynomial
    let steps: [FieldDivisionStep]
}
struct FieldNormalization: Sendable {
    let before: Polynomial
    let inverse: Natural
    let result: Polynomial
}
struct FieldGCD: Sendable {
    let a: Polynomial
    let b: Polynomial
    let initialA: FieldNormalization
    let initialB: FieldNormalization
    let divisions: [FieldDivision]
    let normalizations: [FieldNormalization]
    let result: Polynomial
}
struct FieldPowerStep: Identifiable, Sendable {
    let id: Int
    let exponent: Natural
    let leftExponent: Natural
    let rightExponent: Natural
    let left: Polynomial
    let right: Polynomial
    let division: FieldDivision
    var result: Polynomial { division.remainder }
}
struct FieldPower: Sendable {
    let base: Polynomial
    let exponent: Natural
    let modulus: Polynomial
    let preparation: FieldDivision
    let steps: [FieldPowerStep]
    let result: Polynomial
}

/// Only constructed after an exact prime check. The coefficients remain arbitrary precision.
struct PolynomialField {
    let p: Natural
    let nativePrime: UInt64
    static let one = Polynomial([.one])
    static let x = Polynomial([.zero, .one])
    func residue(_ a: Natural, check: () throws -> Void) throws -> Natural {
        try a.divided(by: p, check: check).remainder
    }
    func inverse(_ a: Natural) -> Natural {
        precondition(!a.isZero && a < p)
        return Natural(Prime64.power(UInt64(a.description)!, nativePrime - 2, nativePrime))
    }
    func subtract(_ a: Polynomial, _ b: Polynomial, check: () throws -> Void = {}) throws -> Polynomial {
        Polynomial(try (0..<max(a.coefficients.count, b.coefficients.count)).map {
            try check(); return try (DecimalInteger(a[$0]) - DecimalInteger(b[$0])).residue(p, check: check)
        })
    }
    func scale(_ a: Polynomial, by c: Natural, check: () throws -> Void = {}) throws -> Polynomial {
        Polynomial(try a.coefficients.map { try check(); return try residue($0 * c, check: check) })
    }
    func monic(_ a: Polynomial, check: () throws -> Void = {}) throws -> FieldNormalization {
        let factor = a.isZero ? .one : inverse(a.leading)
        return FieldNormalization(before: a, inverse: factor, result: try scale(a, by: factor, check: check))
    }
    func divide(_ a: Polynomial, by b: Polynomial, check: () throws -> Void = {}) throws -> FieldDivision {
        precondition(!b.isZero)
        var r = a
        var q = Array(repeating: Natural.zero, count: max(0, a.degree - b.degree + 1))
        var steps: [FieldDivisionStep] = []
        let inv = inverse(b.leading)
        while !r.isZero && r.degree >= b.degree {
            try check()
            let shift = r.degree - b.degree
            let factor = try residue(r.leading * inv, check: check)
            q[shift] = try residue(q[shift] + factor, check: check)
            let multiple = try scale(b.shifted(shift), by: factor, check: check)
            let difference = (0..<r.coefficients.count).map { DecimalInteger(r[$0]) - DecimalInteger(multiple[$0]) }
            let next = Polynomial(try difference.map { try $0.residue(p, check: check) })
            steps.append(FieldDivisionStep(id: steps.count, before: r, factor: factor,
                shift: shift, multiple: multiple, difference: difference, result: next))
            r = next
        }
        return FieldDivision(dividend: a, divisor: b, quotient: Polynomial(q), remainder: r, steps: steps)
    }
    func gcd(_ a: Polynomial, _ b: Polynomial, check: () throws -> Void = {}) throws -> FieldGCD {
        let na = try monic(a, check: check), nb = try monic(b, check: check)
        var u = na.result, v = nb.result
        var divisions: [FieldDivision] = [], normalizations: [FieldNormalization] = []
        while !v.isZero {
            try check()
            let division = try divide(u, by: v, check: check)
            let normalization = try monic(division.remainder, check: check)
            divisions.append(division); normalizations.append(normalization)
            u = v; v = normalization.result
        }
        return FieldGCD(a: a, b: b, initialA: na, initialB: nb, divisions: divisions,
            normalizations: normalizations, result: u)
    }
    /// Recursive binary chain: exponent 6 gives 1, 2, 3, 6, matching the lecture's x³ then x⁶.
    func power(_ base: Polynomial, _ exponent: Natural, modulo m: Polynomial,
               check: () throws -> Void = {}) throws -> FieldPower {
        precondition(m.degree >= 1 && m.leading == .one)
        let preparation = try divide(base, by: m, check: check)
        let reducedBase = preparation.remainder
        var steps: [FieldPowerStep] = []
        func product(_ left: Polynomial, _ right: Polynomial, _ le: Natural, _ re: Natural) throws -> Polynomial {
            try check()
            let raw = try PolynomialSolver.convolution(left, right, p: p, check: check)
            let division = try divide(raw, by: m, check: check)
            steps.append(FieldPowerStep(id: steps.count, exponent: le + re, leftExponent: le,
                rightExponent: re, left: left, right: right, division: division))
            return division.remainder
        }
        func recurse(_ e: Natural) throws -> Polynomial {
            try check()
            if e.isZero { return Self.one }
            if e == .one { return reducedBase }
            let half = e.halved()
            let h = try recurse(half)
            let square = try product(h, h, half, half)
            return e.isOdd ? try product(square, reducedBase, half + half, .one) : square
        }
        let result = try recurse(exponent)
        return FieldPower(base: base, exponent: exponent, modulus: m, preparation: preparation, steps: steps, result: result)
    }
    func evaluate(_ f: Polynomial, at x: Natural, check: () throws -> Void = {}) throws -> Natural {
        var r = Natural.zero
        for c in f.coefficients.reversed() { try check(); r = try residue(r * x + c, check: check) }
        return r
    }
}
