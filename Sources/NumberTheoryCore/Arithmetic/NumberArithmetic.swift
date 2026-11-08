import Foundation

enum NumberTheoryError: LocalizedError {
    case integer(String), modulus, range, prime, factors, degree, invariant
    var errorDescription: String? {
        switch self {
        case .integer(let name): "\(name): введите целое число."
        case .modulus: "Модуль должен быть целым числом больше 1."
        case .range: "Для точной факторизации и проверки простоты модуль должен быть не больше 18446744073709551615 (2⁶⁴ − 1). Число a может иметь любую длину."
        case .prime: "Для этого алгоритма нужен простой модуль p."
        case .factors: "Разложение не подтверждено: нужны простые множители, произведение которых в точности равно модулю. Например: 2^3 * 5^3."
        case .degree: "Поддерживаются квадратные и кубические сравнения (степень 2 или 3)."
        case .invariant: "Внутренняя проверка вычисления не пройдена."
        }
    }
}
/// All operands are canonical residues; full-width products avoid overflow near 2^64.
enum Mod64 {
    static func multiply(_ a: UInt64, _ b: UInt64, _ m: UInt64) -> UInt64 {
        m.dividingFullWidth(a.multipliedFullWidth(by: b)).remainder
    }
    static func add(_ a: UInt64, _ b: UInt64, _ m: UInt64) -> UInt64 { a >= m - b ? a - (m - b) : a + b }
    static func power(_ base: UInt64, _ exponent: UInt64, _ m: UInt64, check: () throws -> Void = {}) throws -> UInt64 {
        var a = base % m, e = exponent, r = UInt64(1) % m
        while e > 0 {
            try check()
            if e & 1 == 1 { r = multiply(r, a, m) }
            e >>= 1
            if e > 0 { a = multiply(a, a, m) }
        }
        return r
    }
    static func gcd(_ a: UInt64, _ b: UInt64) -> UInt64 {
        var a = a, b = b
        while b != 0 { (a, b) = (b, a % b) }
        return a
    }
    static func lcm(_ a: UInt64, _ b: UInt64) -> UInt64 { a / gcd(a, b) * b }
    static func integer(_ text: String, name: String) throws -> DecimalInteger {
        guard let value = DecimalInteger(text: text) else { throw NumberTheoryError.integer(name) }; return value
    }
    static func modulus(_ text: String, prime: Bool = false, check: () throws -> Void = {}) throws -> UInt64 {
        let value = try integer(text, name: prime ? "p" : "m")
        guard !value.isNegative, value.magnitude > .one else { throw NumberTheoryError.modulus }
        guard let native = UInt64(value.magnitude.description) else { throw NumberTheoryError.range }
        if prime { guard try Prime64.isPrime(native, check: check) else { throw NumberTheoryError.prime } }
        return native
    }
    static func residue(_ a: DecimalInteger, _ m: UInt64, check: () throws -> Void = {}) throws -> UInt64 {
        UInt64(try a.residue(Natural(m), check: check).description)!
    }
}
enum NumberNotation {
    static func power(_ base: String, _ e: UInt64) -> String {
        let superscripts = Array("⁰¹²³⁴⁵⁶⁷⁸⁹")
        return base + String(e).compactMap { $0.wholeNumberValue.map { String(superscripts[$0]) } }.joined()
    }
}
struct RecordedPower: Identifiable, Sendable {
    let id: String
    let base: UInt64
    let exponent: UInt64
    let modulus: UInt64
    let result: UInt64
    static func calculate(_ a: UInt64, _ e: UInt64, _ m: UInt64, id: String = "power", check: () throws -> Void = {}) throws -> Self {
        Self(id: id, base: a, exponent: e, modulus: m, result: try Mod64.power(a, e, m, check: check))
    }
    var expression: String { NumberNotation.power(String(base), exponent) }
}
struct RecordedProduct: Identifiable, Sendable {
    let id: String
    let a: UInt64
    let b: UInt64
    let modulus: UInt64
    var result: UInt64 { Mod64.multiply(a, b, modulus) }
}
struct NumberStep: Identifiable, Sendable {
    let id: String
    let equations: [String]
    let explanation: String
    var theorem: String? = nil
    var powers: [RecordedPower] = []
    var products: [RecordedProduct] = []
}
