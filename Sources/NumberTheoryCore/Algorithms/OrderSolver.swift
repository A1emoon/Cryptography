import Foundation

struct OrderPrimeTrace: Sendable {
    let prime: UInt64
    let divisors: [UInt64]
    let tests: [RecordedPower]
    let order: UInt64
    let lifts: [OrderLift]
}
struct OrderLift: Sendable {
    let modulus: UInt64
    let previous: UInt64
    let order: UInt64
    // nil means growth follows from the preceding nonstationary odd-prime lift.
    let test: RecordedPower?
}
struct OrderSolution: Sendable {
    let input: DecimalInteger
    let a: UInt64
    let modulus: UInt64
    let gcd: UInt64
    let factorization: FactorizationTrace
    let lambda: UInt64
    let primes: [OrderPrimeTrace]
    let localOrders: [UInt64]
    let order: UInt64?
    let writing: [OrderLectureLine]
}
enum OrderSolver {
    static func solve(a rawA: String, modulus rawM: String, factors: String = "", check: () throws -> Void = {}) throws -> OrderSolution {
        let input = try Mod64.integer(rawA, name: "a"), m = try Mod64.modulus(rawM, check: check)
        let a = try Mod64.residue(input, m, check: check), gcd = Mod64.gcd(a, m)
        let factorization = try FactorizationSolver.solve(m, manual: factors, check: check)
        let lambda = FactorizationSolver.carmichael(factorization.factors)
        var primes: [OrderPrimeTrace] = [], locals: [UInt64] = []
        if gcd == 1 {
            for factor in factorization.factors {
                try check()
                let p = factor.prime
                let phiFactors = try FactorizationSolver.solve(p-1, check: check)
                var divisors: [UInt64] = [1]
                for f in phiFactors.factors {
                    let old = divisors
                    var power: UInt64 = 1
                    for _ in 0..<f.exponent {
                        power *= f.prime
                        for d in old { try check(); divisors.append(d*power) }
                    }
                }
                divisors.sort()
                var order = a % p == 1 ? 1 : p-1
                var tests: [RecordedPower] = []
                if order > 1 {
                    for d in divisors where d > 1 && d < p-1 {
                        let test = try RecordedPower.calculate(a % p, d, p, id: "prime_\(p)_\(d)", check: check)
                        tests.append(test)
                        if test.result == 1 { order = d; break }
                    }
                }
                let primeOrder = order
                var q = p, growing = false, lifts: [OrderLift] = []
                if factor.exponent >= 2 {
                    for exponent in 2...factor.exponent {
                        try check(); q *= p
                        let old = order
                        let test: RecordedPower?
                        if growing && p != 2 {
                            test = nil; order *= p
                        } else {
                            test = try RecordedPower.calculate(a % q, old, q, id: "lift_\(p)_\(exponent)", check: check)
                            if test!.result != 1 { order *= p; growing = true }
                        }
                        lifts.append(OrderLift(modulus: q, previous: old, order: order, test: test))
                    }
                }
                primes.append(OrderPrimeTrace(prime: p, divisors: divisors, tests: tests, order: primeOrder, lifts: lifts))
                locals.append(order)
            }
        }
        let result: UInt64? = gcd == 1 ? locals.reduce(1, Mod64.lcm) : nil
        if let result {
            guard try Mod64.power(a,result,m,check:check) == 1, lambda % result == 0 else { throw NumberTheoryError.invariant }
        }
        let writing = try OrderLecture.lines(input:input, a:a, modulus:m, gcd:gcd, factorization:factorization, primes:primes, locals:locals, result:result, check:check)
        return OrderSolution(input:input,a:a,modulus:m,gcd:gcd,factorization:factorization,lambda:lambda,primes:primes,localOrders:locals,order:result,writing:writing)
    }
}
