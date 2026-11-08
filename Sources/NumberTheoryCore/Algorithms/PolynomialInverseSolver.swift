import Foundation

enum PolynomialInverseMethod: String, CaseIterable, Sendable {
    case binary, leading
    var title: String { self == .binary ? "По младшему члену, с делением на α" : "По старшему члену" }
}
struct PolynomialInverseRow: Sendable {
    let value: Polynomial
    let coefficient: Polynomial
}
struct PolynomialInverseFrame: Identifiable, Sendable {
    let id: Int
    let operation: String
    let explanation: String
    let rows: [PolynomialInverseRow]
}
struct PolynomialInverseSolution: Sendable {
    let rawA: [DecimalInteger]
    let rawM: [DecimalInteger]
    let a: Polynomial
    let m: Polynomial
    let p: Natural
    let method: PolynomialInverseMethod
    let preparation: FieldDivision
    let frames: [PolynomialInverseFrame]
    let gcd: Polynomial
    let inverse: Polynomial?
    let verification: FieldDivision?
}
enum PolynomialInverseSolver {
    static func solve(a rawA: String, m rawM: String, p rawP: String, method requested: PolynomialInverseMethod = .binary,
                      check: () throws -> Void = {}) throws -> PolynomialInverseSolution {
        let native = try Mod64.modulus(rawP, prime: true, check: check), p = Natural(native)
        let field = PolynomialField(p: p, nativePrime: native)
        let aValues = try PolynomialSolver.parse(rawA, name: "A"), mValues = try PolynomialSolver.parse(rawM, name: "M")
        let a = Polynomial(try aValues.reversed().map { try check(); return try $0.residue(p, check: check) })
        let mRaw = Polynomial(try mValues.reversed().map { try check(); return try $0.residue(p, check: check) })
        guard mRaw.degree >= 1 else { throw PolynomialError.polynomialModulus }
        let m = try field.monic(mRaw, check: check).result
        let preparation = try field.divide(a, by: m, check: check)
        let method: PolynomialInverseMethod = m[0].isZero ? .leading : requested
        var rows = [PolynomialInverseRow(value: preparation.remainder, coefficient: .init([.one])), PolynomialInverseRow(value: m, coefficient: .zero)]
        var frames: [PolynomialInverseFrame] = []
        func record(_ operation: String, _ text: String) {
            frames.append(PolynomialInverseFrame(id: frames.count, operation: operation, explanation: text, rows: rows))
        }
        func reduce(_ c: Polynomial) throws -> Polynomial { try field.divide(c, by: m, check: check).remainder }
        record("", "Начальные строки: A ≡ 1·A, M ≡ 0·A по модулю M и p. В каждой строке сохраняем значение ≡ коэффициент·A. Модуль нормирован; умножение M на ненулевую константу не меняет идеал и остатки.")
        while !rows[0].value.isZero && !rows[1].value.isZero && rows[0].value.degree > 0 && rows[1].value.degree > 0 {
            try check()
            // A zero constant term is handled before any subtraction, as required by the course.
            if !m[0].isZero, let index = rows.indices.first(where: { rows[$0].value[0].isZero }) {
                let old = rows[index], c = old.coefficient
                let multiplier = try field.residue(c[0] * field.inverse(m[0]), check: check)
                let adjusted = try field.subtract(c, try field.scale(m, by: multiplier, check: check), check: check)
                guard adjusted[0].isZero else { throw NumberTheoryError.invariant }
                rows[index] = PolynomialInverseRow(value: Polynomial(Array(old.value.coefficients.dropFirst())), coefficient: Polynomial(Array(adjusted.coefficients.dropFirst())))
                record("M\(index == 0 ? "₁" : "₂")(α⁻¹)", c[0].isZero ? "Свободный член слева равен 0: сначала делим строку на α. Свободный член коэффициента тоже нулевой, поэтому деление точное с обеих сторон." : "Свободный член слева равен 0. Чтобы разделить коэффициент на α, сначала вычитаем yM, где y = c(0)/M(0) = \(multiplier) по p. Полученный свободный член равен 0; деление на α сохраняет сравнение. M(0) ≠ 0, значит α обратим по модулю M.")
                continue
            }
            let index = rows[0].value.degree >= rows[1].value.degree ? 0 : 1
            let other = 1 - index, u = rows[index], v = rows[other]
            let leading = method == .leading
            let shift = leading ? u.value.degree - v.value.degree : 0
            let x = leading ? u.value.leading : u.value[0], y = leading ? v.value.leading : v.value[0]
            guard !y.isZero else { throw NumberTheoryError.invariant }
            let factor = try field.residue(x * field.inverse(y), check: check)
            let multiple = try field.scale(v.value.shifted(shift), by: factor, check: check)
            let coefficientMultiple = try field.scale(v.coefficient.shifted(shift), by: factor, check: check)
            rows[index] = PolynomialInverseRow(value: try field.subtract(u.value, multiple, check: check), coefficient: try reduce(field.subtract(u.coefficient, coefficientMultiple, check: check)))
            let operand = factor.description + (shift == 0 ? "" : "·" + Polynomial.power(shift))
            record("M\(index == 0 ? "₁,₂" : "₂,₁")(−\(operand))", leading ? "Согласуем старшие коэффициенты и вычитаем один кратный сдвиг второй строки. Степень выбранного левого многочлена уменьшается. Коэффициенты считаем по p; правый столбец можно дополнительно приводить по M." : "Свободные члены ненулевые. Берём y = u(0)/v(0) по p и вычитаем y раз другую строку из строки не меньшей степени. Свободный член становится нулём; следующим действием будет приоритетное деление на α. Это полиномиальный аналог бинарного Евклида.")
        }
        let row = rows.first(where: { !$0.value.isZero && $0.value.degree == 0 })
        let inverse: Polynomial?
        let gcd: Polynomial
        let verification: FieldDivision?
        if let row {
            let scale = field.inverse(row.value.leading)
            inverse = try reduce(field.scale(row.coefficient, by: scale, check: check))
            gcd = .init([.one])
            if row.value.leading != .one, let index = rows.firstIndex(where: { !$0.value.isZero && $0.value.degree == 0 }) {
                rows[index] = PolynomialInverseRow(value: .init([.one]), coefficient: inverse!)
                record("M\(index == 0 ? "₁" : "₂")(\(scale))", "Нормируем константу: \(row.value.leading)⁻¹ ≡ \(scale) по \(p). Умножаем оба столбца этой строки на \(scale), а коэффициент при A приводим по M. Получаем строку (1 | A⁻¹).")
            }
            let product = try PolynomialSolver.convolution(a, inverse!, p: p, check: check)
            verification = try field.divide(product, by: m, check: check)
            guard verification!.remainder == .init([.one]) else { throw NumberTheoryError.invariant }
        } else {
            gcd = try field.monic(rows.first(where: { !$0.value.isZero })?.value ?? m, check: check).result
            inverse = nil; verification = nil
        }
        return PolynomialInverseSolution(rawA: aValues, rawM: mValues, a: a, m: m, p: p, method: method, preparation: preparation, frames: frames, gcd: gcd, inverse: inverse, verification: verification)
    }
}
