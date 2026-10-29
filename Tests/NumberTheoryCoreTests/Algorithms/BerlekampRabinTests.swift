import XCTest
@testable import NumberTheoryCore

final class BerlekampRabinTests: XCTestCase {
    private func solve(_ f: String = "1,3,2,1", _ q: String = "7") throws -> RabinSolution {
        try BerlekampRabinSolver.solve(coefficients: f, q: q)
    }
    private func verify(_ s: RabinSolution) throws {
        let field = PolynomialField(p: s.q, nativePrime: UInt64(s.q.description)!)
        let gcds = s.initialGCD.map { [$0] } ?? []
        for trace in gcds + s.splits.map(\.gcd) {
            XCTAssertEqual(trace.result.leading, .one)
            XCTAssertTrue(try field.divide(trace.a, by: trace.result).remainder.isZero)
            XCTAssertTrue(try field.divide(trace.b, by: trace.result).remainder.isZero)
            for d in trace.divisions { try verifyDivision(d, field) }
        }
        let powers = s.power.map { [$0] } ?? []
        for power in powers + s.splits.map(\.power) {
            for step in power.steps {
                try verifyDivision(step.division, field)
                XCTAssertEqual(step.division.dividend, try PolynomialSolver.convolution(step.left, step.right, p: s.q))
                XCTAssertLessThan(step.result.degree, power.modulus.degree)
            }
        }
        for split in s.splits where split.didSplit {
            XCTAssertGreaterThan(split.gcd.result.degree, 0)
            XCTAssertLessThan(split.gcd.result.degree, split.factor.degree)
            try verifyDivision(try XCTUnwrap(split.cofactor), field)
        }
        for v in s.verification { XCTAssertTrue(v.value.isZero) }
    }
    private func verifyDivision(_ d: FieldDivision, _ field: PolynomialField) throws {
        let product = try PolynomialSolver.convolution(d.quotient, d.divisor, p: field.p)
        let sum = Polynomial(try (0..<max(product.coefficients.count, d.remainder.coefficients.count)).map {
            try (product[$0] + d.remainder[$0]).divided(by: field.p).remainder
        })
        XCTAssertEqual(sum, d.dividend)
        XCTAssertTrue(d.remainder.isZero || d.remainder.degree < d.divisor.degree)
    }
    func testLectureEightExactExample() throws {
        let s = try solve()
        XCTAssertEqual(s.roots, [.one])
        XCTAssertTrue(s.splits.isEmpty)
        let power = try XCTUnwrap(s.power)
        XCTAssertEqual(power.steps.map(\.exponent.description), ["2", "3", "6"])
        XCTAssertEqual(power.steps[1].result.coefficients, [Natural(6), Natural(5), Natural(4)])
        XCTAssertEqual(power.result.coefficients, [Natural(2), Natural(4), Natural(2)])
        let gcd = try XCTUnwrap(s.initialGCD)
        XCTAssertEqual(gcd.b.coefficients, [.one, Natural(4), Natural(2)])
        XCTAssertEqual(gcd.initialB.result.coefficients, [Natural(4), Natural(2), .one])
        XCTAssertEqual(gcd.result.coefficients, [Natural(6), .one])
        XCTAssertEqual(gcd.divisions[0].quotient.coefficients, [.one, .one])
        XCTAssertEqual(gcd.divisions[0].remainder.coefficients, [Natural(4), Natural(3)])
        XCTAssertEqual(gcd.normalizations[0].inverse, Natural(5))
        XCTAssertEqual(gcd.divisions[1].quotient.coefficients, [Natural(3), .one])
        XCTAssertTrue(gcd.divisions[1].remainder.isZero)
        try verify(s)
    }
    func testBothKindsOfUnsuccessfulShiftsAndRecursion() throws {
        let s = try solve("1,0,4", "5")
        XCTAssertEqual(s.roots.map(\.description), ["1", "4"])
        XCTAssertEqual(s.splits.map(\.delta.description), ["0", "1", "2"])
        XCTAssertEqual(s.splits.map(\.didSplit), [false, false, true])
        XCTAssertEqual(s.splits[0].gcd.result, s.initialGCD?.result)
        XCTAssertEqual(s.splits[1].gcd.result, PolynomialField.one)
        try verify(s)
        let all = try solve("1,0,0,0,0,0,-1,0", "7")
        XCTAssertEqual(all.roots.map(\.description), (0..<7).map(String.init))
        XCTAssertGreaterThan(all.splits.filter(\.didSplit).count, 1)
        try verify(all)
        XCTAssertEqual(try solve("1,0,1", "5").roots.map(\.description), ["2", "3"])
    }
    func testIndependentSmallRootEnumeration() throws {
        var seed: UInt64 = 73687
        for q in [2,3,5,7,11,13] {
            for degree in 0...4 {
                for _ in 0..<12 {
                    let coefficients = (0...degree).map { _ -> Int in
                        seed = seed &* 6364136223846793005 &+ 1
                        return Int(seed % UInt64(q * 4)) - q * 2
                    }
                    let s = try solve(coefficients.map(String.init).joined(separator: ","), String(q))
                    let expected = (0..<q).filter { x in
                        coefficients.reduce(0) { (($0 * x + $1) % q + q) % q } == 0
                    }.map(String.init)
                    if s.input.isZero { if case .allResidues = s.outcome {} else { XCTFail("zero polynomial") } }
                    else { XCTAssertEqual(s.roots.map(\.description), expected, "\(coefficients) mod \(q)"); try verify(s) }
                }
            }
        }
    }
    func testRepeatedZeroConstantNonMonicAndLongCoefficients() throws {
        let repeated = try solve("1,-2,1,0,0,0")
        XCTAssertEqual(repeated.zeroMultiplicity, 3)
        XCTAssertEqual(repeated.roots.map(\.description), ["0", "1"])
        XCTAssertEqual(repeated.linearRoots.count, 1)
        XCTAssertEqual(try solve("2,6,4,2").roots, [.one])
        XCTAssertEqual(try solve("1,0,0").roots, [.zero])
        XCTAssertTrue(try solve("5").roots.isEmpty)
        XCTAssertTrue(try solve("1,0,1").roots.isEmpty)
        if case .allResidues = try solve("7,0,-14").outcome {} else { XCTFail() }
        XCTAssertEqual(try solve("1,1,0", "2").roots, [.zero, .one])
        let huge = Natural(decimal: "1" + String(repeating: "0", count: 180))! * Natural(7) + .one
        XCTAssertEqual(try solve("\(huge),3,2,1").roots, [.one])
        XCTAssertEqual(try solve("2,-4", "18446744073709551557").roots, [Natural(2)])
        try verify(repeated)
    }
    func testInvalidInputsAndCancellation() throws {
        for q in ["0", "1", "-7", "9", "561", "bad", "18446744073709551616"] {
            XCTAssertThrowsError(try solve("1,2,3", q))
        }
        for f in ["", "1,,2", "1,x,2"] { XCTAssertThrowsError(try solve(f)) }
        var count = 0
        XCTAssertThrowsError(try BerlekampRabinSolver.solve(coefficients: "1,0,0,0,0,0,-1,0", q: "7") {
            count += 1; if count == 200 { throw CancellationError() }
        }) { XCTAssertTrue($0 is CancellationError) }
    }
}
