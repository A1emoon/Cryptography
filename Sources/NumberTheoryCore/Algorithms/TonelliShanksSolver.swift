import Foundation

struct RootCorrection: Identifiable, Sendable {
    let id: Int
    let before: UInt64
    let orderExponent: Int
    let orderPowers: [RecordedPower]
    let top: RecordedPower
    let choice: Int
    let factor: RecordedPower
    let after: UInt64
    let cBefore: UInt64
    let cAfter: UInt64
}
struct TonelliSolution: Sendable {
    let input: DecimalInteger
    let a: UInt64
    let p: UInt64
    let degree: Int
    let criterion: RecordedPower?
    let s: Int
    let r: UInt64
    let k: UInt64
    let nonResidue: UInt64?
    let epsilon: UInt64?
    let c: UInt64
    let seedRoot: UInt64?
    let steps: [NumberStep]
    let corrections: [RootCorrection]
    let roots: [UInt64]
    let verification: [RecordedPower]
}
/// The course's n-adic order-reduction construction, for n=2 and n=3.
/// Unlike a brute-force root search, only n-th roots of unity are compared in each reduction.
enum TonelliShanksSolver {
    static func solve(a rawA: String, p rawP: String, degree n: Int = 2, check: () throws -> Void = {}) throws -> TonelliSolution {
        guard n == 2 || n == 3 else { throw NumberTheoryError.degree }
        let input = try Mod64.integer(rawA, name: "a"), p = try Mod64.modulus(rawP, prime: true, check: check)
        let a = try Mod64.residue(input, p, check: check), degree = UInt64(n)
        var steps: [NumberStep] = [], corrections: [RootCorrection] = []
        var criterion: RecordedPower?, s = 0, r = p - 1, k: UInt64 = 1
        var b: UInt64?, epsilon: UInt64?, c: UInt64 = 0, seed: UInt64?
        func finish(_ values: [UInt64]) throws -> TonelliSolution {
            let roots = Array(Set(values)).sorted()
            let checks = try roots.enumerated().map { try RecordedPower.calculate($0.element, degree, p, id: "root_\($0.offset)", check: check) }
            guard checks.allSatisfy({ $0.result == a }) else { throw NumberTheoryError.invariant }
            return TonelliSolution(input: input, a: a, p: p, degree: n, criterion: criterion, s: s, r: r, k: k, nonResidue: b, epsilon: epsilon, c: c, seedRoot: seed, steps: steps, corrections: corrections, roots: roots, verification: checks)
        }
        if a == 0 { seed = 0; return try finish([0]) }
        if p == degree || p == 2 {
            seed = a
            steps.append(NumberStep(id: "frobenius", equations: ["x\(n == 2 ? "²" : "³") ≡ x (mod \(p))"], explanation: "В характеристике p верно xᵖ = x для каждого остатка. Здесь сравнение сразу даёт x = a.", theorem: "fermat"))
            return try finish([a])
        }
        if (p - 1) % degree != 0 {
            // Invert n in the group exponent p-1, using exact signed Euclid even at the UInt64 boundary.
            let inverse = try ModularSolver.solve(a: String(n), modulus: String(p - 1), method: .binary, check: check)
            guard let e = inverse.inverse, let native = UInt64(e.description) else { throw NumberTheoryError.invariant }
            let power = try RecordedPower.calculate(a, native, p, id: "unique", check: check)
            seed = power.result
            steps.append(NumberStep(id: "unique", equations: ["НОД(\(n), \(p - 1)) = 1", "\(n) · \(native) ≡ 1 (mod \(p - 1))", "x ≡ \(power.expression) ≡ \(power.result) (mod \(p))"], explanation: "Степень n взаимно проста с p − 1. Возведение в n-ю степень переставляет ненулевые остатки поля, поэтому корень единственный. Находим показатель, обратный к n по p − 1.", theorem: "power-coprime", powers: [power]))
            return try finish([power.result])
        }
        let test = try RecordedPower.calculate(a, (p - 1) / degree, p, id: "criterion", check: check)
        criterion = test
        steps.append(NumberStep(id: "criterion", equations: ["\(test.expression) ≡ \(test.result) (mod \(p))"], explanation: "По простому модулю ненулевое a является n-м степенным вычетом ровно тогда, когда a^((p−1)/n) = 1. При отрицательном результате корней нет.", theorem: "residue-criterion", powers: [test]))
        if test.result != 1 { return try finish([]) }
        while r % degree == 0 { try check(); r /= degree; s += 1 }
        steps.append(NumberStep(id: "decomposition", equations: ["\(p) − 1 = \(NumberNotation.power(String(n), UInt64(s))) · \(r)", "s = \(s), r = \(r), НОД(\(n), \(r)) = 1"], explanation: "Выделяем из p − 1 всю степень n. Остаток r не делится на n. Это разложение задаёт размер n-первичной части мультипликативной группы.", theorem: "tonelli"))
        while (k * r + 1) % degree != 0 { k += 1 }
        let initial = try RecordedPower.calculate(a, k * r, p, id: "initial", check: check)
        var alpha = initial.result
        steps.append(NumberStep(id: "initial", equations: ["k = \(k), (\(k) · \(r) + 1) / \(n) = \((k * r + 1) / degree)", "a₀ = \(initial.expression) ≡ \(alpha) (mod \(p))"], explanation: "Выбираем наименьшее k от 1 до n−1, при котором kr+1 делится на n. Это нужно для последнего извлечения корня. Порядок a₀ — степень n, не превышающая n^(s−1). Для кубического сравнения r может давать остаток 1 или 2 по 3: выбор k обрабатывает оба случая.", theorem: "tonelli", powers: [initial]))
        if alpha != 1 {
            var candidate: UInt64 = 2
            while candidate < p {
                try check()
                let trial = try RecordedPower.calculate(candidate, (p - 1) / degree, p, id: "nonresidue_\(candidate)", check: check)
                steps.append(NumberStep(id: "nonresidue_\(candidate)", equations: ["\(trial.expression) ≡ \(trial.result) (mod \(p))"], explanation: trial.result == 1 ? "Этот кандидат является n-м степенным вычетом. Проверяем следующий." : "Нашли n-й степенной невычет b. Его r-я степень имеет полный порядок nˢ, а степень (p−1)/n — порядок n.", theorem: "tonelli-nonresidue", powers: [trial]))
                if trial.result != 1 { b = candidate; epsilon = trial.result; break }; candidate += 1
            }
            guard let b, let epsilon else { throw NumberTheoryError.invariant }
            while alpha != 1 {
                try check()
                var j = 0, x = alpha, powers: [RecordedPower] = []
                var exponent: UInt64 = 1
                while x != 1 {
                    j += 1; exponent *= degree
                    let power = try RecordedPower.calculate(alpha, exponent, p, id: "order_\(j)", check: check)
                    powers.append(power); x = power.result
                    guard j < s else { throw NumberTheoryError.invariant }
                }
                guard j > 0 else { throw NumberTheoryError.invariant }
                let top = try RecordedPower.calculate(alpha, exponent / degree, p, id: "top", check: check)
                var choice = 1
                while choice < n {
                    let ePower = try Mod64.power(epsilon, UInt64(choice), p, check: check)
                    if Mod64.multiply(top.result, ePower, p) == 1 { break }; choice += 1
                }
                guard choice < n else { throw NumberTheoryError.invariant }
                var nPower: UInt64 = 1
                for _ in 0..<(s - j) { nPower *= degree }
                let factorExponent = UInt64(choice) * r * nPower
                let factor = try RecordedPower.calculate(b, factorExponent, p, id: "correction", check: check)
                let before = alpha, cBefore = c
                alpha = Mod64.multiply(alpha, factor.result, p); c += factorExponent / degree
                corrections.append(RootCorrection(id: corrections.count, before: before, orderExponent: j, orderPowers: powers, top: top, choice: choice, factor: factor, after: alpha, cBefore: cBefore, cAfter: c))
                guard try Mod64.power(alpha, exponent / degree, p, check: check) == 1 else { throw NumberTheoryError.invariant }
            }
        }
        let aPower = try RecordedPower.calculate(a, (k * r + 1) / degree, p, id: "a_root", check: check)
        let correction = try RecordedPower.calculate(b ?? 1, c, p, id: "b_root", check: check)
        seed = Mod64.multiply(aPower.result, correction.result, p)
        steps.append(NumberStep(id: "extract", equations: ["a^(kr) · b^(\(n) · \(c)) ≡ 1 (mod \(p))", "x₀ ≡ \(aPower.expression) · \(correction.expression) ≡ \(seed!) (mod \(p))"], explanation: "Домножаем равенство на a и извлекаем n-ю степень. Показатель kr+1 делится на n, показатель при b равен nc. Получаем x₀ = a^((kr+1)/n)bᶜ.", theorem: "tonelli", powers: [aPower, correction], products: [RecordedProduct(id: "root_product", a: aPower.result, b: correction.result, modulus: p)]))
        // Even when a^(kr)=1, the other roots must still be generated.
        if epsilon == nil {
            var candidate: UInt64 = 2
            while candidate < p {
                try check()
                let power = try RecordedPower.calculate(candidate, (p - 1) / degree, p, id: "unity", check: check)
                if power.result != 1 {
                    b = candidate; epsilon = power.result
                    steps.append(NumberStep(id: "unity", equations: ["ε = \(power.expression) ≡ \(power.result) (mod \(p))"], explanation: "Для перечисления всех корней нужен элемент ε порядка n. Ищем n-й степенной невычет, даже если поправки к первому корню не понадобились.", theorem: "unity-roots", powers: [power])); break
                }; candidate += 1
            }
        }
        guard let epsilon, let root = seed else { throw NumberTheoryError.invariant }
        var values: [UInt64] = [], current = root
        for _ in 0..<n { values.append(current); current = Mod64.multiply(current, epsilon, p) }
        guard Set(values).count == n else { throw NumberTheoryError.invariant }
        return try finish(values)
    }
}
