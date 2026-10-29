import Foundation

enum CipollaError: LocalizedError {
    case primeRequired, primeRange, deltaResidue, invariant
    var errorDescription: String? {
        switch self {
        case .primeRequired: "Алгоритм Чиполлы требует простого модуля p. Введите простое число не меньше 2."
        case .primeRange: "В этом задании точная проверка простоты поддерживает p ≤ 18446744073709551615. Число a может иметь любую длину."
        case .deltaResidue: "Для выбранного δ число δ² − a является ненулевым квадратичным вычетом. Выберите другое δ или оставьте поле пустым для автоматического подбора."
        case .invariant: "Не удалось подтвердить результат вычисления. Проверьте исходные данные."
        }
    }
}

/// Exact primality on the entire UInt64 range. Seven deterministic witnesses.
enum Prime64 {
    private static func product(_ a: UInt64, _ b: UInt64, _ m: UInt64) -> UInt64 {
        m.dividingFullWidth(a.multipliedFullWidth(by: b)).remainder
    }
    static func power(_ a: UInt64, _ exponent: UInt64, _ m: UInt64) -> UInt64 {
        var a = a % m, n = exponent, r: UInt64 = 1
        while n > 0 {
            if n & 1 == 1 { r = product(r, a, m) }
            n >>= 1
            if n > 0 { a = product(a, a, m) }
        }
        return r
    }
    static func isPrime(_ n: UInt64, check: () throws -> Void = {}) throws -> Bool {
        if n < 2 { return false }
        for q: UInt64 in [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37] {
            if n == q { return true }
            if n % q == 0 { return false }
        }
        var d = n - 1, s = 0
        while d & 1 == 0 { d >>= 1; s += 1 }
        for base: UInt64 in [2, 325, 9375, 28178, 450775, 9780504, 1795265022] {
            try check()
            if base % n == 0 { continue }
            var x = power(base, d, n)
            if x == 1 || x == n - 1 { continue }
            var passed = false
            for _ in 1..<s {
                try check()
                x = product(x, x, n)
                if x == n - 1 { passed = true; break }
            }
            if !passed { return false }
        }
        return true
    }
}

struct LegendreExponentDerivation: Sendable {
    let rule: String
    let symbolicNumerator: String
    let numeratorExpression: String
    let numeratorValue: Natural
    let denominator: Natural
}
struct LegendreStage: Identifiable, Sendable {
    let id: Int
    let sign: Int
    let factorExponent: Natural?
    let exponentDerivation: LegendreExponentDerivation?
    let numerator: DecimalInteger?
    let denominator: Natural?
    let terminal: Int?
    let note: String
    let identities: [String]
}
struct LegendreTrace: Sendable {
    let input: DecimalInteger
    let modulus: Natural
    let stages: [LegendreStage]
    let value: Int
}

/// Quadratic reciprocity, including Jacobi symbols at composite intermediate denominators.
enum LegendreSolver {
    static func solve(_ input: DecimalInteger, modulus: Natural,
                      check: () throws -> Void = {}) throws -> LegendreTrace {
        precondition(modulus > .one && modulus.isOdd)
        var stages: [LegendreStage] = []
        var a = input.magnitude, n = modulus, sign = 1
        func record(_ factor: Natural? = nil, _ numerator: DecimalInteger? = nil,
                    _ denominator: Natural? = nil, terminal: Int? = nil,
                    derivation: LegendreExponentDerivation? = nil, identities: [String] = [], note: String) {
            stages.append(LegendreStage(id: stages.count, sign: sign, factorExponent: factor,
                exponentDerivation: derivation, numerator: numerator, denominator: denominator,
                terminal: terminal, note: note, identities: identities))
        }
        record(nil, input, n, note: "Исходный символ Лежандра.")
        if input.isNegative {
            let exponent = (n - .one).halved()
            record(exponent, DecimalInteger(a), n,
                derivation: LegendreExponentDerivation(rule: "Символ для −1", symbolicNumerator: "n − 1",
                    numeratorExpression: "\(n) − 1", numeratorValue: n - .one, denominator: Natural(2)),
                note: "Выносим −1 из числителя. Символ (−1 / n) определяется чётностью показателя (n − 1)/2.")
            if exponent.isOdd { sign = -sign }
        }
        while true {
            try check()
            if a >= n {
                let previous = a
                let division = try a.divided(by: n, check: check)
                a = division.remainder
                record(nil, DecimalInteger(a), n,
                    identities: ["\(previous) = \(division.quotient) · \(n) + \(a)"],
                    note: "Значение символа не меняется при замене числителя его остатком по знаменателю.")
            }
            if a.isZero {
                let value = n == .one ? sign : 0
                record(terminal: value, note: value == 0 ? "Числитель кратен знаменателю." : "Символ со знаменателем 1 равен 1.")
                return LegendreTrace(input: input, modulus: modulus, stages: stages, value: value)
            }
            if a == .one || n == .one {
                record(terminal: sign, note: "Символ с числителем 1 равен 1; учитываем накопленный знак.")
                return LegendreTrace(input: input, modulus: modulus, stages: stages, value: sign)
            }
            let beforeHalving = a
            var twos = Natural.zero
            while !a.isOdd { try check(); a = a.halved(); twos = twos + .one }
            if !twos.isZero {
                let exponent = try ((n * n - .one).divided(by: Natural(8), check: check).quotient) * twos
                record(exponent, DecimalInteger(a), n,
                    derivation: LegendreExponentDerivation(rule: "Символ для двойки", symbolicNumerator: "k · (n² − 1)",
                        numeratorExpression: twos == .one ? "\(n)² − 1" : "\(twos) · (\(n)² − 1)",
                        numeratorValue: twos * (n * n - .one), denominator: Natural(8)),
                    identities: ["\(beforeHalving) = 2^\(twos) · \(a)", "k = \(twos), n = \(n)"],
                    note: "Сначала выделяем все множители 2. Для каждого из них (2 / n) = (−1)^((n² − 1)/8), поэтому показатель умножается на количество двоек k.")
                if exponent.isOdd { sign = -sign }
                continue
            }
            let exponent = (a - .one).halved() * (n - .one).halved()
            record(exponent, DecimalInteger(n), a,
                derivation: LegendreExponentDerivation(rule: "Закон квадратичной взаимности", symbolicNumerator: "(u − 1) · (v − 1)",
                    numeratorExpression: "\(n - .one) · \(a - .one)",
                    numeratorValue: (n - .one) * (a - .one), denominator: Natural(4)),
                identities: ["u = \(n), v = \(a)"],
                note: "Меняем числитель и знаменатель местами. Закон квадратичной взаимности добавляет множитель (−1) с показателем (u − 1)(v − 1)/4. Для составных промежуточных знаменателей действует тот же закон для символа Якоби.")
            if exponent.isOdd { sign = -sign }
            (a, n) = (n, a)
        }
    }
}

struct CipollaCandidate: Identifiable, Sendable {
    let id: Int
    let delta: Natural
    let square: Natural
    let difference: DecimalInteger
    let symbol: LegendreTrace
}
struct QuadraticElement: Equatable, Sendable {
    let real: Natural
    let imaginary: Natural
    static let one = Self(real: .one, imaginary: .zero)
    var expression: String {
        if imaginary.isZero { return real.description }
        let term = imaginary == .one ? "ω" : "\(imaginary)ω"
        return real.isZero ? term : "\(real) + \(term)"
    }
}
struct CipollaScalar: Identifiable, Sendable {
    let id: Int
    let expression: String
    let product: DecimalInteger
    let result: Natural
    let quotient: Natural
    let magnitudeRemainder: Natural
    let doubling: DoublingSolution?
}
struct CipollaProduct: Sendable {
    let left: QuadraticElement
    let right: QuadraticElement
    let isSquare: Bool
    let scalars: [CipollaScalar]
    let realTerms: [Natural]
    let imaginaryTerms: [Natural]
    let result: QuadraticElement
}
struct CipollaPower: Identifiable, Sendable {
    let id: Int
    let exponent: Natural
    let result: QuadraticElement
    let product: CipollaProduct?
    let selected: Bool
}
struct CipollaCombination: Identifiable, Sendable {
    let id: Int
    let factorExponent: Natural
    let accumulatedExponent: Natural
    let result: QuadraticElement
    let product: CipollaProduct?
}
enum CipollaOutcome: Sendable { case extensionField, nonResidue, zero, binaryPrime, candidateRoot }
struct CipollaVerification: Identifiable, Sendable {
    let id: Int
    let root: Natural
    let square: Natural
    let quotient: Natural
    let remainder: Natural
}
struct CipollaSolution: Sendable {
    let input: DecimalInteger
    let a: Natural
    let p: Natural
    let inputQuotient: Natural
    let inputMagnitudeRemainder: Natural
    let symbol: LegendreTrace?
    let candidates: [CipollaCandidate]
    let chosenDelta: Natural?
    let deltaInput: DecimalInteger?
    let omegaSquare: DecimalInteger?
    let exponent: Natural?
    let conversion: BinaryConversion?
    let powers: [CipollaPower]
    let combinations: [CipollaCombination]
    let roots: [Natural]
    let verification: [CipollaVerification]
    let outcome: CipollaOutcome
}

enum CipollaSolver {
    static func solve(a rawA: String, p rawP: String, delta rawDelta: String = "",
                      check: () throws -> Void = {}) throws -> CipollaSolution {
        try check()
        guard let input = DecimalInteger(text: rawA) else { throw CalculationError.invalidInteger("a") }
        guard let parsedP = DecimalInteger(text: rawP), !parsedP.isNegative, parsedP.magnitude > .one else { throw CipollaError.primeRequired }
        guard let nativeP = UInt64(parsedP.magnitude.description) else { throw CipollaError.primeRange }
        guard try Prime64.isPrime(nativeP, check: check) else { throw CipollaError.primeRequired }
        let p = parsedP.magnitude
        let deltaInput: DecimalInteger?
        if rawDelta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { deltaInput = nil }
        else {
            guard let value = DecimalInteger(text: rawDelta) else { throw CalculationError.invalidInteger("δ") }
            deltaInput = value
        }
        let inputDivision = try input.magnitude.divided(by: p, check: check)
        let a = try input.residue(p, check: check)
        var symbol: LegendreTrace?
        var candidates: [CipollaCandidate] = []
        var chosen: Natural?
        var omega: DecimalInteger?
        var exponent: Natural?
        var conversion: BinaryConversion?
        var powers: [CipollaPower] = []
        var combinations: [CipollaCombination] = []
        func finish(_ root: Natural?, _ outcome: CipollaOutcome) throws -> CipollaSolution {
            var roots: [Natural] = []
            if let root {
                roots = [root]
                let second = root.isZero ? root : p - root
                if second != root { roots.append(second) }
                roots.sort()
            }
            let verification = try roots.enumerated().map { index, x in
                try check()
                let square = x * x
                let division = try square.divided(by: p, check: check)
                guard division.remainder == a else { throw CipollaError.invariant }
                return CipollaVerification(id: index, root: x, square: square, quotient: division.quotient, remainder: division.remainder)
            }
            return CipollaSolution(input: input, a: a, p: p, inputQuotient: inputDivision.quotient,
                inputMagnitudeRemainder: inputDivision.remainder, symbol: symbol, candidates: candidates,
                chosenDelta: chosen, deltaInput: deltaInput, omegaSquare: omega, exponent: exponent, conversion: conversion,
                powers: powers, combinations: combinations, roots: roots, verification: verification, outcome: outcome)
        }
        if p == Natural(2) { return try finish(a, .binaryPrime) }
        if a.isZero { return try finish(.zero, .zero) }
        let initialSymbol = try LegendreSolver.solve(DecimalInteger(a), modulus: p, check: check)
        symbol = initialSymbol
        if initialSymbol.value == -1 { return try finish(nil, .nonResidue) }
        guard initialSymbol.value == 1 else { throw CipollaError.invariant }
        var delta = try deltaInput?.residue(p, check: check) ?? .zero
        while delta < p {
            try check()
            let square = delta * delta
            let difference = DecimalInteger(square) - DecimalInteger(a)
            let trial = try LegendreSolver.solve(difference, modulus: p, check: check)
            candidates.append(CipollaCandidate(id: candidates.count, delta: delta, square: square, difference: difference, symbol: trial))
            if trial.value == 0 { chosen = delta; return try finish(delta, .candidateRoot) }
            if trial.value == -1 { chosen = delta; break }
            if deltaInput != nil { throw CipollaError.deltaResidue }
            delta = delta + .one
        }
        guard let chosen else { throw CipollaError.invariant }
        let residue = try (DecimalInteger(chosen * chosen) - DecimalInteger(a)).residue(p, check: check)
        let signedD = residue > p.halved() ? DecimalInteger(magnitude: p - residue, isNegative: true) : DecimalInteger(residue)
        omega = signedD
        let e = (p + .one).halved()
        exponent = e
        let bits = try BinaryConversion(number: e, checkCancellation: check)
        conversion = bits
        var current = QuadraticElement(real: chosen, imaginary: .one)
        var power = Natural.one
        powers.append(CipollaPower(id: 0, exponent: power, result: current, product: nil, selected: bits.bits.last == 1))
        for i in 1..<bits.bits.count {
            try check()
            let trace = try multiply(current, current, d: signedD, modulus: p, square: true, check: check)
            power = power + power; current = trace.result
            powers.append(CipollaPower(id: i, exponent: power, result: current, product: trace,
                                      selected: bits.bits[bits.bits.count - 1 - i] == 1))
        }
        // Pair adjacent selected powers, matching the grouping on the board:
        // (32·16)(4·2)(1), then (48·6)(1), then 54·1.
        var factors = powers.reversed().filter(\.selected).map { ($0.exponent, $0.result) }
        if let first = factors.first {
            combinations.append(CipollaCombination(id: 0, factorExponent: first.0,
                accumulatedExponent: first.0, result: first.1, product: nil))
        }
        while factors.count > 1 {
            var next: [(Natural, QuadraticElement)] = []
            var index = 0
            while index < factors.count {
                try check()
                if index + 1 == factors.count { next.append(factors[index]); break }
                let left = factors[index], right = factors[index + 1]
                let product = try multiply(left.1, right.1, d: signedD, modulus: p, square: false, check: check)
                let combinedExponent = left.0 + right.0
                combinations.append(CipollaCombination(id: combinations.count, factorExponent: right.0,
                    accumulatedExponent: combinedExponent, result: product.result, product: product))
                next.append((combinedExponent, product.result))
                index += 2
            }
            factors = next
        }
        guard let result = factors.first?.1 else { throw CipollaError.invariant }
        guard result.imaginary.isZero else { throw CipollaError.invariant }
        return try finish(result.real, .extensionField)
    }

    static func multiply(_ left: QuadraticElement, _ right: QuadraticElement, d: DecimalInteger,
                         modulus p: Natural, square: Bool,
                         check: () throws -> Void = {}) throws -> CipollaProduct {
        var scalars: [CipollaScalar] = []
        func scalar(_ x: DecimalInteger, _ y: DecimalInteger) throws -> Natural {
            try check()
            let product = x * y
            let division = try product.magnitude.divided(by: p, check: check)
            let r = try product.residue(p, check: check)
            let doubling = x.magnitude > Natural(2) && y.magnitude > Natural(2) && product.magnitude >= p
                ? try DoublingSolver.solve(a: x.description, b: y.description, modulus: p.description, checkCancellation: check) : nil
            scalars.append(CipollaScalar(id: scalars.count, expression: x == y ? "\(x.parenthesized)²" : "\(x.parenthesized) · \(y.parenthesized)",
                product: product, result: r, quotient: division.quotient, magnitudeRemainder: division.remainder, doubling: doubling))
            return r
        }
        let ac = try scalar(DecimalInteger(left.real), DecimalInteger(right.real))
        let imaginaryTerms: [Natural]
        if square {
            let twice = try scalar(DecimalInteger(Natural(2)), DecimalInteger(left.real))
            let cross = try scalar(DecimalInteger(twice), DecimalInteger(left.imaginary))
            imaginaryTerms = [cross]
        } else {
            imaginaryTerms = [try scalar(DecimalInteger(left.real), DecimalInteger(right.imaginary)),
                              try scalar(DecimalInteger(left.imaginary), DecimalInteger(right.real))]
        }
        let bd = try scalar(DecimalInteger(left.imaginary), DecimalInteger(right.imaginary))
        let weighted = try scalar(DecimalInteger(bd), d)
        let real = try (ac + weighted).divided(by: p, check: check).remainder
        let imag = try imaginaryTerms.reduce(.zero, +).divided(by: p, check: check).remainder
        return CipollaProduct(left: left, right: right, isSquare: square, scalars: scalars,
            realTerms: [ac, weighted], imaginaryTerms: imaginaryTerms,
            result: QuadraticElement(real: real, imaginary: imag))
    }
}
