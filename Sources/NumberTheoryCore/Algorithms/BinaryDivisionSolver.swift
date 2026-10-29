import Foundation

enum DivisionError: Error, LocalizedError, Equatable {
    case zeroDivisor
    var errorDescription: String? { "Делитель b не может быть равен 0. Деление на ноль не определено." }
}

struct BinaryLength: Sendable {
    let number: Natural
    let length: Int
    let lowerPower: Natural
    let upperPower: Natural
}

struct DivisorShift: Sendable, Identifiable {
    let id: Int // Exponent c.
    let power: Natural
    let multiple: Natural
}

struct DivisionStep: Sendable, Identifiable {
    let id: Int
    let before: BinaryLength
    let lengthDifference: Int
    let trial: DivisorShift
    let chosen: DivisorShift
    let nextMultiple: Natural
    let after: Natural
    let quotientBefore: Natural
    let quotientAfter: Natural
}

struct BinaryDivisionSolution: Sendable {
    let a: DecimalInteger
    let b: DecimalInteger
    let dividendLength: BinaryLength
    let divisorLength: BinaryLength
    let shifts: [DivisorShift]
    let steps: [DivisionStep]
    let magnitudeQuotient: Natural
    let magnitudeRemainder: Natural
    let quotient: DecimalInteger
    let remainder: Natural
    var hasNegativeInput: Bool { a.isNegative || b.isNegative }
    var needsRemainderCorrection: Bool { a.isNegative && !magnitudeRemainder.isZero }
    var identity: String {
        let divisor = b.isNegative ? "(\(b))" : b.description
        let q = quotient.isNegative ? "(\(quotient))" : quotient.description
        return "\(a) = \(divisor) · \(q) + \(remainder)"
    }
}

/// Division by greedy subtraction of the largest shifted divisor.
/// The quotient is a sum of distinct powers of two, as in the class notes.
enum BinaryDivisionSolver {
    static func solve(a rawA: String, b rawB: String,
                      checkCancellation: () throws -> Void = {}) throws -> BinaryDivisionSolution {
        try checkCancellation()
        guard let a = DecimalInteger(text: rawA) else { throw CalculationError.invalidInteger("a") }
        guard let b = DecimalInteger(text: rawB) else { throw CalculationError.invalidInteger("b") }
        guard !b.magnitude.isZero else { throw DivisionError.zeroDivisor }
        let dividend = a.magnitude
        let divisor = b.magnitude

        // Includes the first power strictly above both inputs. No logarithms or rounding.
        var powers = [Natural.one]
        var power = Natural.one
        while power <= max(dividend, divisor) {
            try checkCancellation()
            power = power + power
            powers.append(power)
        }
        func length(of number: Natural) -> BinaryLength {
            guard !number.isZero else {
                return BinaryLength(number: number, length: 0, lowerPower: .zero, upperPower: .one)
            }
            var low = 0
            var high = powers.count - 1
            while low < high {
                let middle = low + (high - low) / 2
                if powers[middle] <= number { low = middle + 1 } else { high = middle }
            }
            return BinaryLength(number: number, length: low, lowerPower: powers[low - 1], upperPower: powers[low])
        }
        let dividendLength = length(of: dividend)
        let divisorLength = length(of: divisor)
        var shifts: [DivisorShift] = []
        var multiple = divisor
        var exponent = 0
        while true {
            try checkCancellation()
            shifts.append(DivisorShift(id: exponent, power: powers[exponent], multiple: multiple))
            if multiple > dividend { break }
            multiple = multiple + multiple
            exponent += 1
        }

        var remainder = dividend
        var quotient = Natural.zero
        var steps: [DivisionStep] = []
        while remainder >= divisor {
            try checkCancellation()
            let before = length(of: remainder)
            let difference = before.length - divisorLength.length
            let trial = shifts[difference]
            let chosen = trial.multiple <= remainder ? trial : shifts[difference - 1]
            let after = remainder - chosen.multiple
            let nextQuotient = quotient + chosen.power
            steps.append(DivisionStep(id: steps.count, before: before, lengthDifference: difference,
                trial: trial, chosen: chosen, nextMultiple: shifts[chosen.id + 1].multiple,
                after: after, quotientBefore: quotient, quotientAfter: nextQuotient))
            remainder = after
            quotient = nextQuotient
        }

        // Euclidean convention for all signs: a = b*q+r, 0 <= r < |b|.
        let correction = a.isNegative && !remainder.isZero
        let finalQ = correction ? quotient + .one : quotient
        let finalR = correction ? divisor - remainder : remainder
        try checkCancellation()
        return BinaryDivisionSolution(a: a, b: b, dividendLength: dividendLength, divisorLength: divisorLength,
            shifts: shifts, steps: steps, magnitudeQuotient: quotient, magnitudeRemainder: remainder,
            quotient: DecimalInteger(magnitude: finalQ, isNegative: a.isNegative != b.isNegative), remainder: finalR)
    }
}
