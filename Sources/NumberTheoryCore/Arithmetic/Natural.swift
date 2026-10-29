import Foundation

/// Nonnegative, arbitrary-precision integer. Little-endian base-10^9 limbs.
/// No floating-point arithmetic or fixed limit on the number of limbs.
struct Natural: Equatable, Comparable, Sendable, CustomStringConvertible {
    private static let radix: UInt64 = 1_000_000_000
    private var words: [UInt32]

    static let zero = Natural(0)
    static let one = Natural(1)

    init(_ value: UInt64) {
        var value = value
        var result: [UInt32] = []
        while value != 0 {
            result.append(UInt32(value % Self.radix))
            value /= Self.radix
        }
        words = result
    }

    init?(decimal: String) {
        let bytes = Array(decimal.utf8)
        guard !bytes.isEmpty, bytes.allSatisfy({ (48...57).contains($0) }) else { return nil }
        var result: [UInt32] = []
        var end = bytes.count
        while end > 0 {
            let start = max(0, end - 9)
            var word: UInt32 = 0
            for byte in bytes[start..<end] { word = word * 10 + UInt32(byte - 48) }
            result.append(word)
            end = start
        }
        self.init(words: result)
    }

    private init(words: [UInt32]) {
        self.words = words
        while self.words.last == 0 { self.words.removeLast() }
    }

    var isZero: Bool { words.isEmpty }
    var isOdd: Bool { (words.first ?? 0) % 2 == 1 }

    var description: String {
        guard let high = words.last else { return "0" }
        var result = String(high)
        for word in words.dropLast().reversed() {
            let digits = String(word)
            result += String(repeating: "0", count: 9 - digits.count) + digits
        }
        return result
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.words.count != rhs.words.count { return lhs.words.count < rhs.words.count }
        for (a, b) in zip(lhs.words.reversed(), rhs.words.reversed()) where a != b {
            return a < b
        }
        return false
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        var result: [UInt32] = []
        result.reserveCapacity(max(lhs.words.count, rhs.words.count) + 1)
        var carry: UInt64 = 0
        for index in 0..<max(lhs.words.count, rhs.words.count) {
            let a = index < lhs.words.count ? UInt64(lhs.words[index]) : 0
            let b = index < rhs.words.count ? UInt64(rhs.words[index]) : 0
            let sum = a + b + carry
            result.append(UInt32(sum % Self.radix))
            carry = sum / Self.radix
        }
        if carry != 0 { result.append(UInt32(carry)) }
        return Self(words: result)
    }

    /// Subtraction is used only after a comparison has established lhs >= rhs.
    static func - (lhs: Self, rhs: Self) -> Self {
        precondition(lhs >= rhs, "Natural subtraction must be nonnegative")
        var result: [UInt32] = []
        result.reserveCapacity(lhs.words.count)
        var borrow: Int64 = 0
        for index in lhs.words.indices {
            let b = index < rhs.words.count ? Int64(rhs.words[index]) : 0
            var difference = Int64(lhs.words[index]) - b - borrow
            borrow = difference < 0 ? 1 : 0
            if difference < 0 { difference += Int64(Self.radix) }
            result.append(UInt32(difference))
        }
        return Self(words: result)
    }

    func halved() -> Self {
        var result = Array(repeating: UInt32(0), count: words.count)
        var carry: UInt64 = 0
        for index in words.indices.reversed() {
            let value = carry * Self.radix + UInt64(words[index])
            result[index] = UInt32(value / 2)
            carry = value % 2
        }
        return Self(words: result)
    }
}

struct DecimalInteger: Sendable, Equatable, CustomStringConvertible {
    let magnitude: Natural
    let isNegative: Bool

    init(magnitude: Natural, isNegative: Bool) {
        self.magnitude = magnitude
        self.isNegative = isNegative && !magnitude.isZero
    }

    init?(text: String) {
        var normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let negative = normalized.first == "-" || normalized.first == "−"
        if negative || normalized.first == "+" { normalized.removeFirst() }
        guard let magnitude = Natural(decimal: normalized) else { return nil }
        self.magnitude = magnitude
        isNegative = negative && !magnitude.isZero
    }

    var description: String { (isNegative ? "−" : "") + magnitude.description }
}
