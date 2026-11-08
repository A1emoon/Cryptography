import Foundation

struct OrderSolution: Sendable {
    let input: DecimalInteger
    let a: UInt64
    let modulus: UInt64
    let gcd: UInt64
    let factorization: FactorizationTrace
    let lambda: UInt64
    let steps: [NumberStep]
    let localOrders: [UInt64]
    let order: UInt64?
}
enum OrderSolver {
    static func solve(a rawA: String, modulus rawM: String, factors: String = "", check: () throws -> Void = {}) throws -> OrderSolution {
        let input = try Mod64.integer(rawA, name: "a"), m = try Mod64.modulus(rawM, check: check)
        let a = try Mod64.residue(input, m, check: check), gcd = Mod64.gcd(a, m)
        let factorization = try FactorizationSolver.solve(m, manual: factors, check: check)
        let lambda = FactorizationSolver.carmichael(factorization.factors)
        guard gcd == 1 else {
            return OrderSolution(input: input, a: a, modulus: m, gcd: gcd, factorization: factorization, lambda: lambda, steps: [], localOrders: [], order: nil)
        }
        var steps: [NumberStep] = [], locals: [UInt64] = []
        for factor in factorization.factors {
            let p = factor.prime
            var order = p - 1
            let orderFactors = try FactorizationSolver.solve(order, check: check)
            steps.append(NumberStep(id: "bound_\(p)", equations: ["λ(\(p)) = φ(\(p)) = \(order)", "P\(p)(\(a % p)) ∣ \(order)"], explanation: "По простому модулю порядок делит p − 1. Убираем из кандидата простой множитель только тогда, когда уменьшенная степень всё ещё даёт 1.", theorem: "order-divisibility"))
            for divisor in orderFactors.factors {
                while order % divisor.prime == 0 {
                    try check()
                    let trial = order / divisor.prime
                    let power = try RecordedPower.calculate(a % p, trial, p, id: "trial", check: check)
                    let accepted = power.result == 1
                    steps.append(NumberStep(id: "trial_\(p)_\(order)_\(divisor.prime)", equations: ["\(power.expression) ≡ \(power.result) (mod \(p))", accepted ? "P\(p)(\(a % p)) ∣ \(trial)" : "P\(p)(\(a % p)) ∤ \(trial)"], explanation: accepted ? "Степень с показателем \(trial) равна 1: делим текущий кандидат \(order) на \(divisor.prime)." : "Результат не равен 1: этот простой множитель убрать нельзя. Проверяем следующий простой делитель кандидата.", theorem: "order-test", powers: [power]))
                    if !accepted { break }; order = trial
                }
            }
            var q = p
            steps.append(NumberStep(id: "prime_order_\(p)", equations: ["P\(p)(\(a % p)) = \(order)"], explanation: "Все простые делители оставшегося кандидата проверены. Ни один больше нельзя удалить: найден наименьший положительный показатель.", theorem: "order-test"))
            if factor.exponent >= 2 {
                for exponent in 2...factor.exponent {
                    try check(); q *= p
                    let power = try RecordedPower.calculate(a % q, order, q, id: "lift", check: check)
                    let old = order
                    if power.result != 1 { order *= p }
                    steps.append(NumberStep(id: "lift_\(p)_\(exponent)", equations: ["\(power.expression) ≡ \(power.result) (mod \(q))", "P\(q)(\(a % q)) = " + (power.result == 1 ? String(old) : "\(p) · \(old) = \(order)")], explanation: "При переходе от pᵏ к pᵏ⁺¹ порядок либо сохраняется, либо умножается на p. Вычисленная степень отличает эти два случая. Для p = 2 применяется та же проверка; правило о неизбежном дальнейшем росте для нечётных p на 2 не переносим.", theorem: "order-prime-power", powers: [power]))
                }
            }
            locals.append(order)
        }
        let result = locals.reduce(1, Mod64.lcm)
        let verification = try RecordedPower.calculate(a, result, m, id: "verification", check: check)
        guard verification.result == 1, lambda % result == 0 else { throw NumberTheoryError.invariant }
        steps.append(NumberStep(id: "lcm", equations: ["P\(m)(\(a)) = НОК(" + locals.map(String.init).joined(separator: ", ") + ") = \(result)"], explanation: "Простые степени в разложении модуля попарно взаимно просты. По китайской теореме об остатках степень равна 1 по m ровно тогда, когда она равна 1 по каждой простой степени. Наименьший общий показатель — НОК локальных порядков.", theorem: "order-crt"))
        steps.append(NumberStep(id: "verification", equations: ["\(verification.expression) ≡ 1 (mod \(m))"], explanation: "Независимо проверяем итоговую степень по исходному модулю. Минимальность уже следует из локальных порядков и НОК.", theorem: "order-crt", powers: [verification]))
        return OrderSolution(input: input, a: a, modulus: m, gcd: gcd, factorization: factorization, lambda: lambda, steps: steps, localOrders: locals, order: result)
    }
}
