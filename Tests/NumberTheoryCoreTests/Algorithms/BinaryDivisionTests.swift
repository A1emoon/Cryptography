import Foundation
import XCTest
@testable import NumberTheoryCore

final class BinaryDivisionTests: XCTestCase {
    func testClassExampleAndCompleteTrace() throws {
        let result = try solve(1530, 41)
        XCTAssertEqual(result.identity, "1530 = 41 · 37 + 13")
        XCTAssertEqual(result.dividendLength.length, 11)
        XCTAssertEqual(result.divisorLength.length, 6)
        XCTAssertEqual(result.shifts.map { $0.multiple.description }, ["41", "82", "164", "328", "656", "1312", "2624"])
        XCTAssertEqual(result.steps.map { $0.chosen.id }, [5, 2, 0])
        XCTAssertEqual(result.steps.map { $0.before.number.description }, ["1530", "218", "54"])
        XCTAssertEqual(result.steps.map { $0.after.description }, ["218", "54", "13"])
        XCTAssertEqual(result.steps.map { $0.quotientAfter.description }, ["32", "36", "37"])
        XCTAssertEqual(result.magnitudeRemainder.description, "13")
    }

    func testLengthDifferenceMinusOneAndEquality() throws {
        let result = try solve(13, 7)
        let step = try XCTUnwrap(result.steps.first)
        XCTAssertEqual(step.lengthDifference, 1)
        XCTAssertEqual(step.trial.multiple.description, "14")
        XCTAssertEqual(step.chosen.id, 0)
        XCTAssertEqual(result.remainder.description, "6")
        let exact = try solve(16, 4)
        XCTAssertEqual(exact.dividendLength.lowerPower.description, "16")
        XCTAssertEqual(exact.dividendLength.upperPower.description, "32")
        XCTAssertEqual(exact.steps.map { $0.chosen.id }, [2])
        XCTAssertEqual(exact.remainder, .zero)
    }

    func testZeroSmallerDividendAndUnitDivisor() throws {
        XCTAssertEqual(try solve(0, 7).identity, "0 = 7 · 0 + 0")
        XCTAssertTrue(try solve(3, 7).steps.isEmpty)
        XCTAssertEqual(try solve(3, 7).remainder.description, "3")
        XCTAssertEqual(try solve(999, 1).quotient.description, "999")
        XCTAssertEqual(try solve(999, 1).remainder, .zero)
        XCTAssertEqual(try solve(0, -7).quotient.description, "0")
    }

    func testSignedEuclideanDivision() throws {
        for (a, b, q, r) in [(-1530, 41, -38, 28), (1530, -41, -37, 13),
                              (-1530, -41, 38, 28), (-82, 41, -2, 0), (-3, 7, -1, 4)] {
            let result = try solve(a, b)
            XCTAssertEqual(result.quotient.magnitude.description, String(abs(q)))
            XCTAssertEqual(result.quotient.isNegative, q < 0)
            XCTAssertEqual(result.remainder.description, String(r))
        }
    }

    func testExhaustiveIdentitiesAndGreedyInvariants() throws {
        for a in -70...70 {
            for b in -25...25 where b != 0 {
                let result = try solve(a, b)
                let qMagnitude = try XCTUnwrap(Int(result.quotient.magnitude.description))
                let q = result.quotient.isNegative ? -qMagnitude : qMagnitude
                let r = try XCTUnwrap(Int(result.remainder.description))
                XCTAssertEqual(a, b * q + r)
                XCTAssertTrue((0..<abs(b)).contains(r))
                var previousExponent = Int.max
                for step in result.steps {
                    let current = try XCTUnwrap(Int(step.before.number.description))
                    let multiple = try XCTUnwrap(Int(step.chosen.multiple.description))
                    let after = try XCTUnwrap(Int(step.after.description))
                    let accumulated = try XCTUnwrap(Int(step.quotientAfter.description))
                    XCTAssertLessThanOrEqual(multiple, current)
                    XCTAssertGreaterThan(multiple * 2, current)
                    XCTAssertEqual(after, current - multiple)
                    XCTAssertEqual(abs(a), accumulated * abs(b) + after)
                    XCTAssertTrue([step.lengthDifference, step.lengthDifference - 1].contains(step.chosen.id))
                    XCTAssertLessThan(step.chosen.id, previousExponent)
                    previousExponent = step.chosen.id
                }
            }
        }
    }

    func testIndependentLargeReferences() throws {
        struct Fixture: Decodable { let a: String; let b: String; let q: String; let r: String }
        let url = try XCTUnwrap(Bundle.module.url(forResource: "division-references", withExtension: "json"))
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
        XCTAssertGreaterThan(fixtures.count, 100)
        for fixture in fixtures {
            let result = try BinaryDivisionSolver.solve(a: fixture.a, b: fixture.b)
            XCTAssertEqual(result.quotient, DecimalInteger(text: fixture.q))
            XCTAssertEqual(result.remainder.description, fixture.r)
        }
    }

    func testInvalidInputsAndCancellation() throws {
        for zero in ["0", "-0", "+000"] {
            XCTAssertThrowsError(try BinaryDivisionSolver.solve(a: "1530", b: zero)) {
                XCTAssertEqual($0 as? DivisionError, .zeroDivisor)
            }
        }
        for invalid in ["", "1.5", "a", "1 530", "--41"] {
            XCTAssertThrowsError(try BinaryDivisionSolver.solve(a: invalid, b: "41"))
            XCTAssertThrowsError(try BinaryDivisionSolver.solve(a: "1530", b: invalid))
        }
        var calls = 0
        XCTAssertThrowsError(try BinaryDivisionSolver.solve(a: String(repeating: "9", count: 1000), b: "41") {
            calls += 1
            if calls == 5 { throw CancellationError() }
        }) { XCTAssertTrue($0 is CancellationError) }
        XCTAssertEqual(calls, 5)
    }

    private func solve(_ a: Int, _ b: Int) throws -> BinaryDivisionSolution {
        try BinaryDivisionSolver.solve(a: String(a), b: String(b))
    }
}
