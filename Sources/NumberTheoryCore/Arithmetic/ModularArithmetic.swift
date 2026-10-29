import Foundation

extension Natural {
    /// Exact binary product with arbitrary-precision additions.
    static func * (lhs: Self, rhs: Self) -> Self {
        // The limb representation stays encapsulated; binary multiplication is also
        // used by the teaching algorithms, and has no fixed-width overflow.
        var a = lhs
        var b = rhs
        var result = Self.zero
        while !b.isZero {
            if b.isOdd { result = result + a }
            b = b.halved()
            if !b.isZero { a = a + a }
        }
        return result
    }

    func divided(by divisor: Self, check: () throws -> Void = {}) throws -> (quotient: Self, remainder: Self) {
        precondition(!divisor.isZero)
        var multiples: [(Self, Self)] = []
        var value = divisor
        var power = Self.one
        while value <= self {
            try check()
            multiples.append((value, power))
            value = value + value
            power = power + power
        }
        var remainder = self
        var quotient = Self.zero
        for (value, power) in multiples.reversed() {
            try check()
            if value <= remainder {
                remainder = remainder - value
                quotient = quotient + power
            }
        }
        return (quotient, remainder)
    }

    var powerOfTwoExponent: Int? {
        guard !isZero else { return nil }
        var n = self
        var count = 0
        while !n.isOdd { n = n.halved(); count += 1 }
        return n == .one ? count : nil
    }
}

extension DecimalInteger {
    static let zero = Self(magnitude: .zero, isNegative: false)
    static let one = Self(magnitude: .one, isNegative: false)
    init(_ magnitude: Natural) { self.init(magnitude: magnitude, isNegative: false) }
    var isOdd: Bool { magnitude.isOdd }
    var negated: Self { Self(magnitude: magnitude, isNegative: !isNegative) }
    var parenthesized: String { isNegative ? "(\(self))" : description }
    func halved() -> Self {
        precondition(!isOdd)
        return Self(magnitude: magnitude.halved(), isNegative: isNegative)
    }
    static func + (a: Self, b: Self) -> Self {
        if a.isNegative == b.isNegative {
            return Self(magnitude: a.magnitude + b.magnitude, isNegative: a.isNegative)
        }
        if a.magnitude >= b.magnitude {
            return Self(magnitude: a.magnitude - b.magnitude, isNegative: a.isNegative)
        }
        return Self(magnitude: b.magnitude - a.magnitude, isNegative: b.isNegative)
    }
    static func - (a: Self, b: Self) -> Self { a + b.negated }
    static func * (a: Self, b: Self) -> Self {
        Self(magnitude: a.magnitude * b.magnitude, isNegative: a.isNegative != b.isNegative)
    }
    func residue(_ modulus: Natural, check: () throws -> Void = {}) throws -> Natural {
        let r = try magnitude.divided(by: modulus, check: check).remainder
        return isNegative && !r.isZero ? modulus - r : r
    }
}
