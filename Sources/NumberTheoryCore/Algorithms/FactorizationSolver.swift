import Foundation

struct PrimeFactor: Identifiable, Sendable, Equatable {
    let prime: UInt64
    let exponent: Int
    var id: UInt64 { prime }
    var value: UInt64 { (0..<exponent).reduce(1) { value, _ in value * prime } }
    var expression: String { exponent == 1 ? String(prime) : NumberNotation.power(String(prime), UInt64(exponent)) }
}
struct FactorizationTrace: Sendable {
    let number: UInt64
    let factors: [PrimeFactor]
    let divisions: [String]
    let manual: Bool
    var expression: String { factors.isEmpty ? "1" : factors.map(\.expression).joined(separator: " · ") }
}
enum FactorizationSolver {
    static func solve(_ number: UInt64, manual: String = "", check: () throws -> Void = {}) throws -> FactorizationTrace {
        precondition(number > 0)
        var primes: [UInt64] = []
        let hasManual = !manual.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasManual {
            let parts = manual.replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "·", with: "*").replacingOccurrences(of: ",", with: "*").split(separator: "*", omittingEmptySubsequences: false)
            var product: UInt64 = 1
            for part in parts {
                try check()
                let pair = part.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "^", omittingEmptySubsequences: false)
                guard (1...2).contains(pair.count), let p = UInt64(pair[0].trimmingCharacters(in: .whitespaces)), try Prime64.isPrime(p, check: check) else { throw NumberTheoryError.factors }
                let e = pair.count == 1 ? 1 : Int(pair[1].trimmingCharacters(in: .whitespaces)) ?? 0
                guard (1...64).contains(e) else { throw NumberTheoryError.factors }
                for _ in 0..<e {
                    let next = product.multipliedReportingOverflow(by: p)
                    guard !next.overflow, next.partialValue <= number else { throw NumberTheoryError.factors }
                    product = next.partialValue; primes.append(p)
                }
            }
            guard product == number else { throw NumberTheoryError.factors }
        } else {
            func split(_ n: UInt64) throws {
                try check()
                if n == 1 { return }
                if try Prime64.isPrime(n, check: check) { primes.append(n); return }
                for p: UInt64 in [2,3,5,7,11,13,17,19,23,29,31,37] {
                    if n % p == 0 { primes.append(p); try split(n / p); return }
                }
                // Brent's batched Pollard rho. Deterministic restarts, cancellable even on a hard semiprime.
                var seed: UInt64 = 1
                while true {
                    try check()
                    let c = seed % (n - 1) + 1
                    var y = Mod64.add(c % n, 1, n), r: UInt64 = 1, g: UInt64 = 1
                    var x: UInt64 = 0, saved = y
                    func f(_ x: UInt64) -> UInt64 { Mod64.add(Mod64.multiply(x, x, n), c % n, n) }
                    while g == 1 && r <= 1 << 21 {
                        x = y
                        for _ in 0..<r { try check(); y = f(y) }
                        var k: UInt64 = 0
                        while k < r && g == 1 {
                            saved = y
                            var q: UInt64 = 1
                            for _ in 0..<min(64, r - k) {
                                try check(); y = f(y)
                                q = Mod64.multiply(q, x > y ? x - y : y - x, n)
                            }
                            g = Mod64.gcd(q, n); k += 64
                        }
                        r <<= 1
                    }
                    if g == n {
                        repeat { try check(); saved = f(saved); g = Mod64.gcd(x > saved ? x - saved : saved - x, n) } while g == 1
                    }
                    if g > 1 && g < n { try split(g); try split(n / g); return }
                    seed += 1
                }
            }
            try split(number)
        }
        let factors = Dictionary(grouping: primes, by: { $0 }).map { PrimeFactor(prime: $0.key, exponent: $0.value.count) }.sorted { $0.prime < $1.prime }
        var left = number, divisions: [String] = []
        for factor in factors {
            for _ in 0..<factor.exponent {
                try check(); divisions.append("\(left) = \(factor.prime) · \(left / factor.prime)"); left /= factor.prime
            }
        }
        guard left == 1 else { throw NumberTheoryError.invariant }
        return FactorizationTrace(number: number, factors: factors, divisions: divisions, manual: hasManual)
    }
    static func carmichael(_ factors: [PrimeFactor]) -> UInt64 {
        factors.reduce(1) { result, f in
            let local = f.prime == 2 && f.exponent >= 3 ? f.value / 4 : f.value / f.prime * (f.prime - 1)
            return Mod64.lcm(result, local)
        }
    }
}
