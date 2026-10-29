import Foundation
import XCTest
@testable import NumberTheoryCore

final class DoublingSolverTests: XCTestCase {
    func testClassExample() throws {
        let result = try solve(78, 96, 273)
        XCTAssertEqual(result.answer.description, "117")
        XCTAssertEqual(result.conversionA.binary, "1001110")
        XCTAssertEqual(result.conversionA.divisions.map { $0.value.description }, ["78", "39", "19", "9", "4", "2", "1"])
        XCTAssertEqual(result.conversionA.divisions.map(\.bit), [0, 1, 1, 1, 0, 0, 1])
        XCTAssertEqual(result.conversionB.binary, "1100000")
        XCTAssertFalse(result.selectedA)
        XCTAssertEqual(result.table?.columns.map { $0.result.description }, ["78", "234", "195", "117", "234", "195", "117"])
    }

    func testOneUsesOtherNumberEvenWithMoreSetBits() throws {
        for (a, b) in [(1000, 1), (1, 1000), (-1000, 1), (1, -1000)] {
            let result = try solve(a, b, 273)
            XCTAssertEqual(result.selectedConversion.number.description, "1000")
            XCTAssertEqual(result.table?.columns.count, 10)
            XCTAssertNil(result.preparation)
            XCTAssertEqual(result.answer.description, a < 0 || b < 0 ? "92" : "181")
        }
    }

    func testZeroModulusOneAndInvalidInput() throws {
        XCTAssertEqual(try solve(0, -555, 13).answer, .zero)
        XCTAssertEqual(try solve(-99, 82, 1).answer, .zero)
        XCTAssertEqual(try solve(0, 1, 7).conversionA.binary, "0")
        for m in ["0", "-3", "−3"] {
            XCTAssertThrowsError(try DoublingSolver.solve(a: "1", b: "2", modulus: m)) {
                XCTAssertEqual($0 as? CalculationError, .invalidModulus)
            }
        }
        for invalid in ["", "-", "1.5", "1e3", "1 000", "１２", "0xFF", "++1", "1\n2"] {
            XCTAssertThrowsError(try DoublingSolver.solve(a: invalid, b: "1", modulus: "7"))
        }
        XCTAssertEqual(try DoublingSolver.solve(a: " −00078 ", b: "+96", modulus: "273").answer.description, "156")
        XCTAssertEqual(DecimalInteger(text: "-0")?.description, "0")
    }

    func testPreparationPreservesOriginalConversions() throws {
        let result = try solve(8, 1000, 13)
        XCTAssertTrue(result.selectedA)
        XCTAssertEqual(result.conversionB.number.description, "1000")
        XCTAssertEqual(result.preparation?.multiplier.description, "1000")
        XCTAssertEqual(result.preparation?.answer.description, "12")
        XCTAssertEqual(result.table?.addend.description, "12")
        XCTAssertEqual(result.answer.description, "5")
    }

    func testSubtractAtEqualityAndOperationOrdering() throws {
        let result = try solve(3, 2, 3)
        // Selected 2: its addend 3 is first reduced by a complete auxiliary table.
        let auxiliary = try XCTUnwrap(result.preparation)
        XCTAssertEqual(auxiliary.columns.last?.operations, [
            .double(Natural(1), Natural(2)),
            .add(Natural(2), Natural(1), Natural(3)),
            .subtract(Natural(3), Natural(3), .zero)
        ])
        XCTAssertEqual(result.answer, .zero)
        let doubleEquality = try solve(4, 1, 4)
        XCTAssertEqual(doubleEquality.table?.columns.last?.operations, [
            .double(Natural(2), Natural(4)),
            .subtract(Natural(4), Natural(4), .zero),
            .add(.zero, .zero, .zero)
        ])
    }

    func testSelectionTieBreaks() throws {
        XCTAssertTrue(try solve(3, 5, 97).selectedA) // Same popcount; 11 is shorter.
        XCTAssertTrue(try solve(5, 6, 97).selectedA) // Same length/popcount; first.
        XCTAssertFalse(try solve(7, 8, 97).selectedA) // Popcount has priority.
    }

    func testExhaustiveSmallIntegersAndTableInvariants() throws {
        for a in -20...20 {
            for b in -20...20 {
                for m in 1...17 {
                    let result = try solve(a, b, m)
                    XCTAssertEqual(result.answer.description, String(((a * b) % m + m) % m), "\(a), \(b), \(m)")
                    for table in [result.preparation, result.table].compactMap({ $0 }) {
                        try check(table)
                    }
                }
            }
        }
    }

    func testIndependentPythonReferences() throws {
        struct Fixture: Decodable { let a: String; let b: String; let m: String; let answer: String }
        let url = try XCTUnwrap(Bundle.module.url(forResource: "python-references", withExtension: "json"))
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
        XCTAssertGreaterThan(fixtures.count, 100)
        for fixture in fixtures {
            let result = try DoublingSolver.solve(a: fixture.a, b: fixture.b, modulus: fixture.m)
            XCTAssertEqual(result.answer.description, fixture.answer, "Python reference failed: \(fixture.a), \(fixture.b), \(fixture.m)")
        }
    }

    func testCancellation() throws {
        var calls = 0
        XCTAssertThrowsError(try DoublingSolver.solve(a: String(repeating: "9", count: 1000), b: "1", modulus: "273") {
            calls += 1
            if calls == 7 { throw CancellationError() }
        }) { XCTAssertTrue($0 is CancellationError) }
        XCTAssertEqual(calls, 7)
    }

    func testNaturalArithmeticAndCarryBorrow() throws {
        for a in UInt64(0)...128 {
            XCTAssertEqual(Natural(a).halved().description, String(a / 2))
            for b in UInt64(0)...128 {
                XCTAssertEqual((Natural(a) + Natural(b)).description, String(a + b))
                XCTAssertEqual(Natural(a) < Natural(b), a < b)
                if a >= b { XCTAssertEqual((Natural(a) - Natural(b)).description, String(a - b)) }
            }
        }
        let huge = try XCTUnwrap(Natural(decimal: "1000000000000000000000000000000000000"))
        let previous = try XCTUnwrap(Natural(decimal: "999999999999999999999999999999999999"))
        XCTAssertEqual(huge - .one, previous)
        XCTAssertEqual(previous + .one, huge)
        XCTAssertEqual(huge.halved().description, "500000000000000000000000000000000000")
        XCTAssertEqual(Natural(UInt64.max).description, String(UInt64.max))
        XCTAssertEqual(Natural(decimal: "000000000000000000000"), .zero)
    }

    private func solve(_ a: Int, _ b: Int, _ m: Int) throws -> DoublingSolution {
        try DoublingSolver.solve(a: String(a), b: String(b), modulus: String(m))
    }

    private func check(_ table: CalculationTable) throws {
        let m = try XCTUnwrap(Int(table.modulus.description))
        let addend = try XCTUnwrap(Int(table.addend.description))
        var prefix = 0
        var prior = 0
        for column in table.columns {
            prefix = prefix * 2 + column.bit
            let result = try XCTUnwrap(Int(column.result.description))
            XCTAssertEqual(result, (prefix * addend) % m)
            XCTAssertTrue((0..<m).contains(result))
            if !column.isInitial {
                var current = Natural(UInt64(prior))
                for operation in column.operations {
                    switch operation {
                    case .double(let input, let output):
                        XCTAssertEqual(input, current); XCTAssertEqual(output, input + input); current = output
                    case .add(let input, let value, let output):
                        XCTAssertEqual(input, current); XCTAssertEqual(output, input + value); current = output
                    case .subtract(let input, let value, let output):
                        XCTAssertEqual(input, current); XCTAssertGreaterThanOrEqual(input, value)
                        XCTAssertEqual(output, input - value); current = output
                    }
                }
                XCTAssertEqual(current, column.result)
            }
            prior = result
        }
    }
}
