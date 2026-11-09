import Foundation

enum OrderLectureAtom: Sendable, Equatable {
    case rich(String), congruence(UInt64, unequal: Bool = false), fraction(String,String)
}
enum OrderExplanationBlock: Sendable {
    case text(String), formula([OrderLectureAtom])
}
struct OrderLectureDetail: Sendable {
    let title: String
    let blocks: [OrderExplanationBlock]
    let references: [String]
}
struct OrderLectureLine: Identifiable, Sendable {
    let id: String
    let atoms: [OrderLectureAtom]
    let explanation: String
    var references: [String] = ["order"]
    // Only off-page arithmetic tables; all powers and order arguments stay visible.
    var products: [Int: RecordedProduct] = [:]
    var detail: OrderLectureDetail? = nil
}
private struct OrderWrittenPowers {
    let base: UInt64
    let label: String
    let modulus: UInt64
    var values: [UInt64: UInt64] = [:]
    var rows: [OrderLectureLine] = []
    func signed(_ n: UInt64) -> String { n > modulus/2 ? "−\(modulus-n)" : String(n) }
    func factor(_ n: UInt64) -> String { n > modulus/2 ? "(\(signed(n)))" : signed(n) }
    func integer(_ n: UInt64) -> DecimalInteger { DecimalInteger(magnitude:Natural(n > modulus/2 ? modulus-n : n),isNegative:n > modulus/2) }
    mutating func write(_ exponent: UInt64, id: String, check: () throws -> Void) throws -> UInt64 {
        try check()
        if let value=values[exponent] { return value }
        if exponent == 1 { values[1]=base; return base }
        // Prefer already-written powers (e.g. a^6=(a^3)^2), as in the lecture.
        let leftExponent = exponent % 2 == 0 ? exponent/2 : exponent-1
        let rightExponent = exponent % 2 == 0 ? leftExponent : 1
        let left=try write(leftExponent,id:id,check:check), right=try write(rightExponent,id:id,check:check)
        let value=Mod64.multiply(left,right,modulus)
        var atoms: [OrderLectureAtom] = [.rich("\(label)^{\(exponent)}")]
        let raw = exponent == 2 && !label.hasPrefix("(") ? (Natural(base)*Natural(base)).description : (integer(left)*integer(right)).description
        if exponent != 2 {
            atoms += [.congruence(modulus), .rich(exponent % 2 == 0 ? "\(factor(left))²" : "\(factor(left)) · \(factor(right))")]
        }
        let productIndex=atoms.count-1
        atoms.append(.rich("= \(raw)"))
        if raw != signed(value) { atoms += [.congruence(modulus),.rich(signed(value))] }
        if value != 1 { atoms += [.congruence(modulus,unequal:true),.rich("1")] }
        let product=RecordedProduct(id:id+"_\(exponent)",a:left,b:right,modulus:modulus)
        rows.append(OrderLectureLine(id:id+"_power_\(exponent)",atoms:atoms,explanation:"Подставляем ранее найденные степени и приводим результат по модулю. Если степень не равна 1, этот показатель не является порядком. Отдельно открывается только таблица умножения.",references:["order-test"],products:[productIndex:product]))
        values[exponent]=value
        return value
    }
}
enum OrderLecture {
    static func lines(input: DecimalInteger, a: UInt64, modulus m: UInt64, gcd: UInt64, factorization: FactorizationTrace, primes: [OrderPrimeTrace], locals: [UInt64], result: UInt64?, check: () throws -> Void) throws -> [OrderLectureLine] {
        let original=input.description
        func P(_ q: UInt64,_ b: String? = nil) -> String { "P_{\(q)}(\(b ?? original))" }
        func signed(_ n: UInt64,_ q: UInt64) -> String { n > q/2 ? "−\(q-n)" : String(n) }
        var rows=[OrderLectureLine(id:"orderCondition",atoms:[.rich(P(m)+" = ?")],explanation:"Ищем наименьший положительный показатель степени, дающий 1 по модулю m.")]
        guard let result else {
            rows.append(OrderLectureLine(id:"orderGCD",atoms:[.rich("НОД(\(original), \(m)) = \(gcd) ≠ 1 ⇒ ∄ \(P(m))")],explanation:"Мультипликативный порядок существует только для взаимно простых числа и модуля."))
            return rows
        }
        rows.append(OrderLectureLine(id:"orderFactorization",atoms:[.rich("\(m) = \(factorization.expression)")],explanation:"Раскладываем модуль на простые степени, находим локальные порядки, затем берём их наименьшее общее кратное.",references:["order-crt"]))
        func reduction(_ q: UInt64,_ representative: String) -> [OrderLectureAtom] {
            [.rich(P(q)+" = [\(original)"),.congruence(q),.rich(representative+"] = "+P(q,representative))]
        }
        for prime in primes {
            let p=prime.prime, residue=a % p, label=String(residue)
            if p == 2 {
                rows.append(OrderLectureLine(id:"orderPrime_2",atoms:reduction(2,"1") + [.rich("= 1")],explanation:"Единственный обратимый класс по модулю 2 — единица."))
            } else {
                rows.append(OrderLectureLine(id:"orderPrime_\(p)",atoms:reduction(p,label),explanation:"Порядок зависит только от класса вычетов числа."))
                rows.append(OrderLectureLine(id:"orderDivisors_\(p)",atoms:[.rich("L(\(p)) = φ(\(p)) = \(p-1); d(\(p-1)) = {\(prime.divisors.map(String.init).joined(separator:", "))}")],explanation:"По простому модулю показатель делит L(p)=φ(p)=p−1. d(p−1) здесь обозначает множество положительных делителей; проверяем их по возрастанию. Показатель 1 исключается сразу, если остаток не равен 1.",references:["order-divisibility"]))
                var arithmetic=OrderWrittenPowers(base:residue,label:label,modulus:p)
                for test in prime.tests { _ = try arithmetic.write(test.exponent,id:"orderPrime_\(p)",check:check) }
                rows += arithmetic.rows
                rows.append(OrderLectureLine(id:"orderPrimeResult_\(p)",atoms:[.rich(P(p)+" = "+P(p,label)+" = \(prime.order)")],explanation:"Это первый показатель из множества делителей, дающий 1. Если все собственные делители исключены, остаётся p−1 по малой теореме Ферма.",references:["order-test"]))
            }
            var explainedGrowth = false
            for lift in prime.lifts {
                let q=lift.modulus, r=a % q, representative=signed(r,q)
                if let test=lift.test {
                    if r == 1 || r == q-1 {
                        rows.append(OrderLectureLine(id:"orderLiftResult_\(q)",atoms:reduction(q,representative)+[.rich("= \(lift.order)")],explanation:r == 1 ? "Порядок единицы равен 1." : "По модулю больше 2 порядок −1 равен 2."))
                    } else {
                        rows.append(OrderLectureLine(id:"orderLiftCandidates_\(q)",atoms:reduction(q,representative)+[.rich("∈ {\(lift.previous), \(lift.previous*p)}")],explanation:"При переходе от pᵏ к pᵏ⁺¹ порядок сохраняется либо умножается на p. Вычисляем старую степень по новому модулю.",references:["order-prime-power"],detail:try candidatesDetail(original:original,prime:prime,lift:lift,check:check)))
                        let baseLabel=r > q/2 ? "(\(representative))" : representative
                        var arithmetic=OrderWrittenPowers(base:r,label:baseLabel,modulus:q)
                        if test.exponent == 1 {
                            rows.append(OrderLectureLine(id:"orderLift_\(q)_power_1",atoms:[.rich(baseLabel),.congruence(q,unequal:true),.rich("1")],explanation:"Предыдущий порядок равен 1; приведённое число отличается от единицы."))
                        } else { _ = try arithmetic.write(test.exponent,id:"orderLift_\(q)",check:check); rows += arithmetic.rows }
                        rows.append(OrderLectureLine(id:"orderLiftResult_\(q)",atoms:[.rich("⇒ "+P(q)+" = \(lift.order)")],explanation:test.result == 1 ? "Старая степень даёт 1: порядок сохранился." : "Старая степень не даёт 1: порядок умножается на p.",references:["order-prime-power"]))
                    }
                } else {
                    rows.append(OrderLectureLine(id:"orderLiftResult_\(q)",atoms:[.rich("⇒ "+P(q)+" = \(p) · \(lift.previous) = \(lift.order)")],explanation:"Для нечётного p начавшийся рост порядка продолжается: при каждом следующем увеличении степени модуля порядок умножается на p. Для p=2 этот вывод автоматически не используется.",references:["order-growth"],detail:explainedGrowth ? nil : growthDetail(original:original,p:p,lift:lift)))
                    explainedGrowth = true
                }
            }
        }
        if locals.count == 1 {
            rows.append(OrderLectureLine(id:"orderLCM",atoms:[.rich(P(m)+" = \(result)")],explanation:"Исходный модуль является простой степенью; его локальный порядок уже найден."))
        } else {
            let terms=zip(factorization.factors,locals).map { P($0.0.value) }.joined(separator:", ")
            let values=locals.map(String.init).joined(separator:", ")
            var atoms: [OrderLectureAtom] = [.rich(P(m)+" = НОК(\(terms)) = НОК(\(values))")]
            var folds: [OrderLectureAtom] = []
            // Fold pairwise to avoid overflowing a product of many 64-bit local orders.
            var accumulator=locals[0]
            for (index, next) in locals.dropFirst().enumerated() {
                let d=Mod64.gcd(accumulator,next), product=Natural(accumulator)*Natural(next)
                if locals.count > 2 { folds = [.rich("НОК(\(accumulator), \(next)) =")] }
                let calculation: [OrderLectureAtom] = [.rich("="),.fraction("\(accumulator) · \(next)","НОД(\(accumulator), \(next))"),.rich("="),.fraction(product.description,String(d))]
                accumulator=Mod64.lcm(accumulator,next)
                if locals.count == 2 { atoms += calculation + [.rich("= \(accumulator)")] }
                else {
                    folds += Array(calculation.dropFirst()) + [.rich("= \(accumulator)")]
                    rows.append(OrderLectureLine(id:"orderLCMFold_\(index)",atoms:folds,explanation:"Вычисляем НОК двух текущих чисел через их НОД; затем используем результат со следующим локальным порядком.",references:["order-crt"]))
                }
            }
            if locals.count > 2 { atoms.append(.rich("= \(result)")) }
            rows.append(OrderLectureLine(id:"orderLCM",atoms:atoms,explanation:"НОК — наименьшее общее кратное, НОД — наибольший общий делитель. По взаимно простым простым степеням итоговый порядок равен М локальных порядков. При нескольких множителях вычисляем НОК последовательно слева направо.",references:["order-crt"]))
        }
        return rows
    }

    private static func candidatesDetail(original: String, prime: OrderPrimeTrace, lift: OrderLift, check: () throws -> Void) throws -> OrderLectureDetail {
        let p=prime.prime, q=lift.modulus, previous=lift.previous, next=previous*p, phi=q-q/p
        func P(_ modulus: UInt64) -> String { "P_{\(modulus)}(\(original))" }
        func set(_ values: [UInt64]) -> String { "{"+values.map(String.init).joined(separator:", ")+"}" }
        var divisors: [UInt64]=[], multiplier: UInt64=1
        while true {
            for d in prime.divisors { try check(); divisors.append(d*multiplier) }
            if multiplier == q/p { break }
            multiplier *= p
        }
        divisors.sort()
        let admissible=divisors.filter{$0 % previous == 0}
        var blocks: [OrderExplanationBlock] = [
            .text("Уже найден порядок \(P(q/p)) = \(previous). Степень, равная 1 по модулю \(q), равна 1 и по его делителю \(q/p). Поэтому новый порядок кратен \(previous):"),
            .formula([.rich("\(previous) = \(P(q/p)) ∣ \(P(q))")]),
            .text("По теореме Эйлера новый порядок одновременно делит φ(\(q)) = \(phi):"),
            .formula([.rich("\(P(q)) ∣ φ(\(q)) = \(q)−\(q/p) = \(phi)")]),
            .text("Из делителей \(phi) оставляем только кратные \(previous):"),
            .formula([.rich("d(\(phi)) = \(set(divisors))")]),
            .formula([.rich("{d ∈ d(\(phi)) : \(previous) ∣ d} = \(set(admissible))")])
        ]
        if admissible.count > 2 {
            blocks += [.text("Условия делимости оставляют больше двух кандидатов. По теореме о порядке по примарному модулю на соседней простой степени порядок сохраняется либо умножается на простое \(p):"),
                       .formula([.rich("\(P(q)) ∈ {\(P(q/p)), \(p)\(P(q/p))} = {\(previous), \(next)}")])]
        }
        blocks.append(.text("Таким образом, возможны только \(previous) и \(next). Достаточно проверить степень \(previous): если она даёт 1, порядок равен \(previous); иначе остаётся \(next). Эта проверка записана в основном решении."))
        return OrderLectureDetail(title:"Почему {\(previous), \(next)}?",blocks:blocks,references:["order-prime-power","euler-theorem","order-divisibility"])
    }
    private static func growthDetail(original: String, p: UInt64, lift: OrderLift) -> OrderLectureDetail {
        let q=lift.modulus, previous=lift.previous
        func P(_ modulus: UInt64) -> String { "P_{\(modulus)}(\(original))" }
        return OrderLectureDetail(title:"Почему умножаем на \(p)?",blocks:[
            .text("При предыдущем переходе от модуля \(q/p/p) к \(q/p) порядок уже вырос в \(p) раз:"),
            .formula([.rich("\(P(q/p)) = \(previous) = \(p) · \(previous/p) = \(p)\(P(q/p/p))")]),
            .text("Число \(p) — нечётное простое. По теореме о росте порядка по соседним примарным модулям начавшийся рост продолжается: при каждом следующем увеличении степени модуля порядок снова умножается на \(p). Оба условия теоремы здесь выполнены."),
            .formula([.rich("\(P(q)) = \(p)\(P(q/p)) = \(p) · \(previous) = \(lift.order)")]),
            .text("Поэтому следующие порядки можно получать умножением на \(p), без повторного вычисления больших степеней. Для простого 2 это правило автоматически не применяем.")
        ],references:["order-growth"])
    }
}
