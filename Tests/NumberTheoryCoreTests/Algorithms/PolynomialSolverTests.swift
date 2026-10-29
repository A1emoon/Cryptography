import XCTest
@testable import NumberTheoryCore

final class PolynomialSolverTests: XCTestCase {
    private func solve(_ a: String, _ b: String, _ m: String = "1, 0, 0, 2, 2", _ p: String = "5") throws -> PolynomialSolution {
        try PolynomialSolver.solve(a: a, b: b, m: m, p: p)
    }
    private func verify(_ s: PolynomialSolution, file: StaticString = #filePath, line: UInt = #line) throws {
        var prefix = Polynomial.zero
        let steps = s.preparation + s.columns.flatMap { [$0.scaling] + $0.steps } + s.verificationSteps
        for step in steps {
            let result = Polynomial(try step.raw.map { try $0.residue(s.p) })
            XCTAssertEqual(result, step.result, file: file, line: line)
            if step.action == .subtract {
                XCTAssertLessThan(step.result.degree, step.before.degree, file: file, line: line)
                for i in step.raw.indices {
                    XCTAssertEqual(step.raw[i], DecimalInteger(step.before[i]) - DecimalInteger(step.operand![i]), file: file, line: line)
                }
            }
        }
        for column in s.columns {
            XCTAssertLessThan(column.result.degree, s.m.polynomial.degree, file: file, line: line)
            prefix = Polynomial([column.coefficient] + prefix.coefficients)
            let product = try PolynomialSolver.convolution(prefix, s.base, p: s.p)
            XCTAssertEqual(try PolynomialSolver.reduce(product, by: s.m.polynomial, p: s.p).result, column.result, file: file, line: line)
            if column.id > 0 {
                XCTAssertEqual(column.steps.first?.action, .shift, file: file, line: line)
                XCTAssertEqual(column.steps.last?.action, .add, file: file, line: line)
            }
        }
        XCTAssertEqual(s.columns.last?.result, s.result, file: file, line: line)
    }
    func testClassExampleExactTable() throws {
        let s = try solve("1, 2, 1", "2, 0, 1, 3")
        XCTAssertEqual(s.multiplierName, "A")
        XCTAssertEqual(s.a.polynomial.weight, 3)
        XCTAssertEqual(s.b.polynomial.weight, 3)
        XCTAssertEqual(s.columns.map { $0.addition.vector() }, ["(2, 0, 1, 3)", "(4, 0, 2, 1)", "(2, 0, 1, 3)"])
        XCTAssertEqual(s.columns.map { $0.result.vector() }, ["(2, 0, 1, 3)", "(4, 1, 1, 2)", "(3, 1, 0, 0)"])
        XCTAssertEqual(s.columns[1].steps.map(\.action), [.shift, .subtract, .add])
        XCTAssertEqual(s.columns[1].steps[0].result.vector(), "(2, 0, 1, 3, 0)")
        XCTAssertEqual(s.columns[1].steps[1].operand?.vector(), "(2, 0, 0, 4, 4)")
        XCTAssertEqual(s.columns[1].steps[1].rawVector, "(0, 0, 1, −1, −4)")
        XCTAssertEqual(s.columns[1].steps[1].result.vector(), "(1, 4, 1)")
        XCTAssertEqual(s.columns[2].steps[1].operand?.vector(), "(4, 0, 0, 3, 3)")
        XCTAssertEqual(s.result.formula, "3α³ + α²")
        try verify(s)
    }
    func testSelectionZerosConstantsAndPreparation() throws {
        let swapped = try solve("2, 0, 1, 3", "1, 2, 1")
        XCTAssertEqual(swapped.multiplierName, "B")
        XCTAssertEqual(swapped.result.vector(), "(3, 1, 0, 0)")
        let sparse = try solve("1, 0, 1, 1", "1, 0, 0, 0, 1")
        XCTAssertEqual(sparse.multiplierName, "B")
        XCTAssertEqual(sparse.columns.count, 5)
        XCTAssertEqual(sparse.columns.filter { $0.coefficient.isZero }.count, 3)
        for s in [swapped, sparse, try solve("0", "2, 0, 1, 3"), try solve("1", "2, 3, 4, 0, 2, 1"),
                  try solve("0, 0, 3", "2"), try solve("1, 0", "1, 0", "1, 0", "6")] { try verify(s) }
        let remainder = try solve("1", "2, 3, 4, 0, 2, 1")
        XCTAssertEqual(remainder.preparation.count, 2)
        XCTAssertTrue(remainder.columns[0].steps.isEmpty)
        XCTAssertEqual(try solve("0", "0").result.formula, "0")
    }
    func testSignedLargeCoefficientsAndParsing() throws {
        let s = try solve("(−4; 7; -9)", "2 0 1 3", "1, 0, 0, -3, 7")
        XCTAssertEqual(s.result.formula, "3α³ + α²")
        XCTAssertFalse(s.a.reductions.isEmpty)
        XCTAssertEqual(try solve(String(repeating: "9", count: 200) + "1", "1").result.vector(), "(1)")
        for bad in ["", "()", "1,,2", "1,", "1.5", "α²+1", "(1,2", "1 2,3"] {
            XCTAssertThrowsError(try solve(bad, "1"), bad)
        }
        for p in ["0", "1", "-5", "bad"] { XCTAssertThrowsError(try solve("1", "1", "1,1", p)) }
        for m in ["0", "1", "5,1", "2,0,1"] { XCTAssertThrowsError(try solve("1", "1", m)) }
        // Composite coefficient modulus is valid for a monic polynomial.
        try verify(solve("-1, 7", "3, 0, 2", "1, 2, 3", "6"))
        try verify(s)
    }
    // Independent small-integer convolution and monic long division.
    private func reference(_ a: [Int], _ b: [Int], _ m: [Int], _ p: Int) -> [Int] {
        func mod(_ x: Int) -> Int { (x % p + p) % p }
        var r = Array(repeating: 0, count: a.count + b.count - 1)
        for i in a.indices { for j in b.indices { r[i + j] = mod(r[i + j] + a[i] * b[j]) } }
        while r.last == 0 { r.removeLast() }
        while r.count >= m.count {
            let factor = r.last!, offset = r.count - m.count
            for i in m.indices { r[offset + i] = mod(r[offset + i] - factor * m[i]) }
            while r.last == 0 { r.removeLast() }
        }
        return r
    }
    func testIndependentSmallPolynomialEnumeration() throws {
        func vector(_ a: [Int]) -> String { a.reversed().map(String.init).joined(separator: ",") }
        for p in 2...7 {
            for seed in 0..<120 {
                let a = [seed % p - 2, (seed / 3) % p, (seed / 7) % p]
                let b = [(seed / 2) % p, (seed / 5) % p - 1, (seed / 11) % p, seed % 3]
                let m = [seed % p, (seed / 4) % p, 1]
                let s = try solve(vector(a), vector(b), vector(m), String(p))
                let expected = reference(a, b, m, p).map { Natural(UInt64($0)) }
                XCTAssertEqual(s.result, Polynomial(expected), "p=\(p), seed=\(seed)")
                try verify(s)
            }
        }
    }
    func testCancellation() throws {
        var count = 0
        XCTAssertThrowsError(try PolynomialSolver.solve(a: "1,2,1", b: "2,0,1,3", m: "1,0,0,2,2", p: "5") {
            count += 1
            if count == 20 { throw CancellationError() }
        }) { XCTAssertTrue($0 is CancellationError) }
    }
}
