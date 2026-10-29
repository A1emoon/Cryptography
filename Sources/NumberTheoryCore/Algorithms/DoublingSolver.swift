import Foundation

enum CalculationError: Error, LocalizedError, Equatable {
    case invalidInteger(String)
    case invalidModulus

    var errorDescription: String? {
        switch self {
        case .invalidInteger(let field):
            return "В поле «\(field)» введите целое число: цифры и, при необходимости, знак перед ними. Дроби, буквы и пробелы внутри числа недопустимы."
        case .invalidModulus:
            return "Модуль m должен быть положительным целым числом. По модулю 0 остаток не определён."
        }
    }
}

struct BinaryConversion: Sendable {
    struct Division: Identifiable, Sendable {
        let id: Int
        let value: Natural
        let bit: Int
    }
    let number: Natural
    let divisions: [Division]
    let bits: [Int] // Most significant first, including [0] for zero.
    var binary: String { bits.map(String.init).joined() }
    var ones: Int { bits.reduce(0, +) }

    init(number: Natural, checkCancellation: () throws -> Void = {}) throws {
        self.number = number
        var current = number
        var rows: [Division] = []
        while true {
            try checkCancellation()
            rows.append(Division(id: rows.count, value: current, bit: current.isOdd ? 1 : 0))
            if current <= .one { break }
            current = current.halved()
        }
        divisions = rows
        bits = rows.reversed().map(\.bit)
    }
}

enum ArithmeticOperation: Sendable, Equatable {
    case double(Natural, Natural)
    case add(Natural, Natural, Natural)
    case subtract(Natural, Natural, Natural)

    var expression: String {
        switch self {
        case .double(let a, let result): return "\(a) · 2 = \(result)"
        case .add(let a, let b, let result): return "\(a) + \(b) = \(result)"
        case .subtract(let a, let b, let result): return "\(a) − \(b) = \(result)"
        }
    }
}

struct CalculationColumn: Identifiable, Sendable {
    let id: Int
    let bit: Int
    let addition: Natural
    let operations: [ArithmeticOperation]
    let result: Natural
    var isInitial: Bool { id == 0 }
}

struct CalculationTable: Sendable {
    let multiplier: Natural
    let addend: Natural
    let modulus: Natural
    let columns: [CalculationColumn]
    var answer: Natural { columns.last?.result ?? .zero }
}

struct DoublingSolution: Sendable {
    let a: DecimalInteger
    let b: DecimalInteger
    let modulus: Natural
    let conversionA: BinaryConversion
    let conversionB: BinaryConversion
    let selectedA: Bool
    let selectionExplanation: String
    let preparation: CalculationTable?
    let table: CalculationTable?
    let signCorrection: ArithmeticOperation?
    let answer: Natural
    let specialExplanation: String?

    var selectedConversion: BinaryConversion { selectedA ? conversionA : conversionB }
    var originalAddend: Natural { selectedA ? b.magnitude : a.magnitude }
    var hasNegativeInput: Bool { a.isNegative || b.isNegative }
    var expression: String { "(\(a) · \(b)) mod \(modulus)" }
}

enum DoublingSolver {
    static func solve(a rawA: String, b rawB: String, modulus rawM: String,
                      checkCancellation: () throws -> Void = {}) throws -> DoublingSolution {
        try checkCancellation()
        guard let a = DecimalInteger(text: rawA) else { throw CalculationError.invalidInteger("a") }
        guard let b = DecimalInteger(text: rawB) else { throw CalculationError.invalidInteger("b") }
        guard let m = DecimalInteger(text: rawM) else { throw CalculationError.invalidInteger("m") }
        guard !m.isNegative, !m.magnitude.isZero else { throw CalculationError.invalidModulus }
        let modulus = m.magnitude
        let first = try BinaryConversion(number: a.magnitude, checkCancellation: checkCancellation)
        let second = try BinaryConversion(number: b.magnitude, checkCancellation: checkCancellation)
        let selection = choose(first, second)
        var preparation: CalculationTable?
        var table: CalculationTable?
        var signCorrection: ArithmeticOperation?
        var special: String?
        var answer = Natural.zero

        if a.magnitude.isZero || b.magnitude.isZero {
            special = "Один из множителей равен 0, поэтому произведение и его остаток равны 0. Двоичная запись нуля — 0."
        } else if modulus == .one {
            special = "Любое целое число делится на 1 без остатка. По модулю 1 ответ равен 0."
        } else {
            let chosen = selection.first ? first : second
            let originalAddend = selection.first ? b.magnitude : a.magnitude
            var reducedAddend = originalAddend
            if originalAddend >= modulus {
                let baseConversion = selection.first ? second : first
                let auxiliary = try calculate(conversion: baseConversion, addend: .one,
                                              modulus: modulus, checkCancellation: checkCancellation)
                preparation = auxiliary
                reducedAddend = auxiliary.answer
            }
            let main = try calculate(conversion: chosen, addend: reducedAddend,
                                     modulus: modulus, checkCancellation: checkCancellation)
            table = main
            answer = main.answer
            if a.isNegative != b.isNegative, !answer.isZero {
                let corrected = modulus - answer
                signCorrection = .subtract(modulus, answer, corrected)
                answer = corrected
            }
        }
        try checkCancellation()
        return DoublingSolution(a: a, b: b, modulus: modulus, conversionA: first,
            conversionB: second, selectedA: selection.first, selectionExplanation: selection.reason,
            preparation: preparation, table: table, signCorrection: signCorrection,
            answer: answer, specialExplanation: special)
    }

    private static func choose(_ a: BinaryConversion, _ b: BinaryConversion) -> (first: Bool, reason: String) {
        if a.number == .one || b.number == .one {
            return (a.number != .one || b.number == .one,
                    "Один множитель равен 1. Разбираем двоичную запись другого числа и прибавляем 1 или 0: так получаем его остаток этим алгоритмом.")
        }
        if a.ones != b.ones {
            let first = a.ones < b.ones
            return (first, "Выбираем \(first ? a.number : b.number): в двоичной записи \(min(a.ones, b.ones)) единиц вместо \(max(a.ones, b.ones)). Это уменьшает число сложений не с нулём.")
        }
        if a.bits.count != b.bits.count {
            return (a.bits.count < b.bits.count,
                    "Количество единиц одинаково. Выбираем более короткую двоичную запись, чтобы выполнить меньше удвоений.")
        }
        return (true, "Количество единиц и длины записей одинаковы. Выбираем первый множитель.")
    }

    /// With 0 <= addend < modulus, each phase needs at most one subtraction.
    /// After each column, accumulator == processedBinaryPrefix * addend (mod modulus).
    private static func calculate(conversion: BinaryConversion, addend: Natural, modulus: Natural,
                                  checkCancellation: () throws -> Void) throws -> CalculationTable {
        precondition(addend < modulus && modulus > .one)
        var accumulator = Natural.zero
        var columns: [CalculationColumn] = []
        for (index, bit) in conversion.bits.enumerated() {
            try checkCancellation()
            let addition = bit == 1 ? addend : .zero
            var operations: [ArithmeticOperation] = []
            if index == 0 {
                accumulator = addition
            } else {
                let doubled = accumulator + accumulator
                operations.append(.double(accumulator, doubled))
                accumulator = doubled
                if accumulator >= modulus {
                    let remainder = accumulator - modulus
                    operations.append(.subtract(accumulator, modulus, remainder))
                    accumulator = remainder
                }
                let sum = accumulator + addition
                operations.append(.add(accumulator, addition, sum))
                accumulator = sum
                if accumulator >= modulus {
                    let remainder = accumulator - modulus
                    operations.append(.subtract(accumulator, modulus, remainder))
                    accumulator = remainder
                }
            }
            columns.append(CalculationColumn(id: index, bit: bit, addition: addition,
                                             operations: operations, result: accumulator))
        }
        return CalculationTable(multiplier: conversion.number, addend: addend,
                                modulus: modulus, columns: columns)
    }
}
