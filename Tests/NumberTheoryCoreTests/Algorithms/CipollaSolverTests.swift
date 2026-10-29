import XCTest
@testable import NumberTheoryCore

final class CipollaSolverTests: XCTestCase {
    private func solve(_ a: String = "29", _ p: String = "109", _ delta: String = "") throws -> CipollaSolution {
        try CipollaSolver.solve(a: a, p: p, delta: delta)
    }
    private func verify(_ s: CipollaSolution) throws {
        for v in s.verification { XCTAssertEqual(v.remainder, s.a) }
        let products = s.powers.compactMap(\.product) + s.combinations.compactMap(\.product)
        for product in products {
            for scalar in product.scalars {
                XCTAssertEqual(try scalar.product.residue(s.p), scalar.result)
                if let table = scalar.doubling { XCTAssertEqual(table.answer, scalar.result) }
            }
            XCTAssertEqual(try product.realTerms.reduce(.zero, +).divided(by: s.p).remainder, product.result.real)
            XCTAssertEqual(try product.imaginaryTerms.reduce(.zero, +).divided(by: s.p).remainder, product.result.imaginary)
            let u = product.left, v = product.right, d = s.omegaSquare!
            XCTAssertEqual(try (DecimalInteger(u.real * v.real) + DecimalInteger(u.imaginary * v.imaginary) * d).residue(s.p), product.result.real)
            XCTAssertEqual(try (u.real * v.imaginary + u.imaginary * v.real).divided(by: s.p).remainder, product.result.imaginary)
        }
    }
    func testClassExampleCompleted() throws {
        let s = try solve()
        XCTAssertEqual(s.symbol?.value, 1)
        XCTAssertEqual(s.candidates.map(\.delta.description), ["0", "1", "2", "3", "4"])
        XCTAssertEqual(s.candidates.map(\.difference.description), ["−29", "−28", "−25", "−20", "−13"])
        XCTAssertEqual(s.candidates.map(\.symbol.value), [1, 1, 1, 1, -1])
        XCTAssertEqual(s.omegaSquare?.description, "−13")
        XCTAssertEqual(s.exponent?.description, "55")
        XCTAssertEqual(s.conversion?.binary, "110111")
        XCTAssertEqual(s.powers.map(\.result.expression), ["4 + ω", "3 + 8ω", "49 + 48ω", "26 + 17ω", "80 + 12ω", "59 + 67ω"])
        XCTAssertEqual(s.powers.reversed().filter(\.selected).map(\.exponent.description), ["32", "16", "4", "2", "1"])
        XCTAssertEqual(s.combinations.map(\.result.expression), ["59 + 67ω", "45 + 73ω", "60 + 100ω", "14 + 51ω", "47"])
        XCTAssertEqual(s.combinations.map(\.accumulatedExponent.description), ["32", "48", "6", "54", "55"])
        XCTAssertEqual(s.roots.map(\.description), ["47", "62"])
        XCTAssertEqual(s.verification.map(\.square.description), ["2209", "3844"])
        try verify(s)
    }
    func testLegendreAgainstEulerCriterion() throws {
        for p: UInt64 in [3, 5, 7, 11, 13, 17, 29, 41, 109, 257] {
            for a in -Int(p)...Int(p) {
                let normalized = UInt64((a % Int(p) + Int(p)) % Int(p))
                var residue: UInt64 = 1
                for _ in 0..<((p - 1) / 2) { residue = residue * normalized % p }
                let expected = normalized == 0 ? 0 : residue == 1 ? 1 : -1
                XCTAssertEqual(try LegendreSolver.solve(DecimalInteger(text: String(a))!, modulus: Natural(p)).value, expected, "(\(a) / \(p))")
            }
        }
    }
    func testLegendreExponentDerivations() throws {
        let example = try solve()
        let reciprocity = try XCTUnwrap(example.symbol?.stages.first { $0.exponentDerivation != nil })
        XCTAssertEqual(reciprocity.factorExponent, Natural(756))
        XCTAssertEqual(reciprocity.exponentDerivation?.numeratorExpression, "108 · 28")
        XCTAssertEqual(reciprocity.exponentDerivation?.denominator, Natural(4))
        let traces = [try XCTUnwrap(example.symbol)] + example.candidates.map(\.symbol)
            + [try LegendreSolver.solve(DecimalInteger(text: "-128")!, modulus: Natural(109))]
        for trace in traces {
            for stage in trace.stages {
                if let derivation = stage.exponentDerivation {
                    let division = try derivation.numeratorValue.divided(by: derivation.denominator)
                    XCTAssertEqual(division.remainder, .zero)
                    XCTAssertEqual(division.quotient, stage.factorExponent)
                } else { XCTAssertNil(stage.factorExponent) }
            }
        }
    }
    func testAllSmallRootsAgainstEnumeration() throws {
        for p in 2...97 where (2..<p).allSatisfy({ p % $0 != 0 }) {
            for a in -3...(p + 3) {
                let s = try solve(String(a), String(p))
                let value = (a % p + p) % p
                let expected = (0..<p).filter { $0 * $0 % p == value }.map { String($0) }
                XCTAssertEqual(s.roots.map(\.description), expected, "a=\(a), p=\(p)")
                try verify(s)
            }
        }
    }
    func testSpecialCasesManualDeltaAndLongInput() throws {
        XCTAssertEqual(try solve("0").roots, [.zero])
        XCTAssertEqual(try solve("-218").roots, [.zero])
        XCTAssertEqual(try solve("-1", "2").roots, [.one])
        XCTAssertEqual(try solve("109", "2").roots, [.one])
        XCTAssertTrue(try solve("2", "3").roots.isEmpty)
        let shortcut = try solve("1", "13")
        XCTAssertEqual(shortcut.roots.map(\.description), ["1", "12"])
        XCTAssertTrue(shortcut.powers.isEmpty)
        XCTAssertEqual(shortcut.candidates.last?.symbol.value, 0)
        for d in ["4", "113", "-105"] {
            let manual = try solve("29", "109", d)
            XCTAssertEqual(manual.chosenDelta, Natural(4))
            XCTAssertEqual(manual.roots.map(\.description), ["47", "62"])
            XCTAssertEqual(manual.candidates.count, 1)
        }
        XCTAssertThrowsError(try solve("29", "109", "2"))
        let huge = Natural(decimal: "1" + String(repeating: "0", count: 200))! * Natural(109) + Natural(29)
        XCTAssertEqual(try solve(huge.description).roots.map(\.description), ["47", "62"])
        // A 64-bit prime exercises exact modular products past ordinary UInt64 multiplication.
        let largestPrime = try solve("4", "18446744073709551557")
        XCTAssertEqual(largestPrime.roots.map(\.description), ["2", "18446744073709551555"])
        try verify(largestPrime)
    }
    func testPrimalityAndInvalidInput() throws {
        for p: UInt64 in [0, 1, 4, 15, 341, 561, 1105, 1729, 3215031751, 341550071728321, 3825123056546413051, UInt64.max] {
            XCTAssertFalse(try Prime64.isPrime(p), "\(p)")
        }
        for p: UInt64 in [2, 3, 5, 109, 257, 4294967291, 18446744073709551557] { XCTAssertTrue(try Prime64.isPrime(p)) }
        for p in ["0", "1", "-3", "15", "bad", "18446744073709551616"] { XCTAssertThrowsError(try solve("29", p)) }
        XCTAssertThrowsError(try solve("bad"))
        XCTAssertThrowsError(try solve("29", "109", "bad"))
    }
    func testCancellationInsideArithmetic() throws {
        var count = 0
        XCTAssertThrowsError(try CipollaSolver.solve(a: "29", p: "109") {
            count += 1
            if count == 200 { throw CancellationError() }
        }) { XCTAssertTrue($0 is CancellationError) }
    }
}
