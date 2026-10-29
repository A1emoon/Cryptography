import XCTest
@testable import NumberTheoryCore

final class ModularSolverTests: XCTestCase {
    private func gcd(_ a: Int, _ b: Int) -> Int {
        var x = abs(a), y = abs(b)
        while y != 0 { (x, y) = (y, x % y) }
        return x
    }
    private func verifyFrames(_ s: ModularSolution, file: StaticString = #filePath, line: UInt = #line) throws {
        for frame in s.frames {
            for row in frame.rows {
                if let beta = row.beta {
                    XCTAssertEqual(row.alpha * DecimalInteger(s.a) + beta * DecimalInteger(s.modulus), DecimalInteger(row.value), file: file, line: line)
                } else {
                    XCTAssertEqual(try (row.alpha * DecimalInteger(s.a)).residue(s.modulus), try row.value.divided(by: s.modulus).remainder, file: file, line: line)
                }
            }
            if let remaining = frame.remaining {
                XCTAssertEqual(frame.rows[2].value + remaining, s.target, file: file, line: line)
            }
            if frame.id > 0 {
                let before = s.frames[frame.id - 1]
                switch frame.action {
                case .subtract:
                    XCTAssertTrue(before.rows.prefix(2).allSatisfy { $0.value.isOdd || $0.value.isZero }, "Halving must come first", file: file, line: line)
                case .accumulate:
                    XCTAssertEqual(s.method, .direct, file: file, line: line)
                    XCTAssertNotEqual(before.action, .accumulate, file: file, line: line)
                    XCTAssertEqual(Array(before.rows.prefix(2)), Array(frame.rows.prefix(2)), file: file, line: line)
                    let source = before.rows.prefix(2)
                        .filter { !$0.value.isZero && $0.value <= before.remaining! }
                        .max { $0.value < $1.value }!
                    let addition = frame.rows[2].value - before.rows[2].value
                    let division = try addition.divided(by: source.value)
                    XCTAssertEqual(division.remainder, .zero, file: file, line: line)
                    XCTAssertFalse(division.quotient.isZero, file: file, line: line)
                    if source.value > Natural(2) {
                        XCTAssertEqual(division.quotient, .one, "Add a single copy of a general row", file: file, line: line)
                    } else {
                        XCTAssertEqual(division.quotient, try before.remaining!.divided(by: source.value).quotient, file: file, line: line)
                    }
                    XCTAssertEqual(frame.rows[2].alpha, before.rows[2].alpha + source.alpha * DecimalInteger(division.quotient), file: file, line: line)
                case .halve:
                    let changed = zip(before.rows, frame.rows).filter { $0 != $1 }
                    XCTAssertEqual(changed.count, 1, file: file, line: line)
                    for (old, new) in changed {
                        XCTAssertFalse(old.value.isZero, file: file, line: line)
                        XCTAssertFalse(old.value.isOdd, file: file, line: line)
                        XCTAssertFalse(old.alpha.isOdd, file: file, line: line)
                        XCTAssertEqual(new.value, old.value.halved(), file: file, line: line)
                        XCTAssertEqual(new.alpha, old.alpha.halved(), file: file, line: line)
                        if let beta = old.beta {
                            XCTAssertFalse(beta.isOdd, file: file, line: line)
                            XCTAssertEqual(new.beta, beta.halved(), file: file, line: line)
                        }
                    }
                case .adjust:
                    XCTAssertEqual(s.frames[frame.id + 1].action, .halve, file: file, line: line)
                case .initial: XCTFail("Only the first frame is initial", file: file, line: line)
                }
            }
            if let rest = frame.remaining, !rest.isZero, frame.id + 1 < s.frames.count,
               [.initial, .halve, .subtract].contains(frame.action),
               frame.rows.prefix(2).contains(where: { !$0.value.isZero && $0.value <= rest }) {
                XCTAssertEqual(s.frames[frame.id + 1].action, .accumulate,
                               "Capture a suitable row before further transformations", file: file, line: line)
            }
        }
        for stage in s.lifts {
            XCTAssertEqual(stage.baseResidue, try s.a.divided(by: stage.modulus).remainder, file: file, line: line)
            XCTAssertEqual(try (stage.baseResidue * stage.previous).divided(by: stage.modulus).remainder, stage.residue, file: file, line: line)
            XCTAssertEqual(try (s.a * stage.result).divided(by: stage.modulus).remainder, .one, file: file, line: line)
            XCTAssertEqual(stage.result, stage.previous + stage.addition, file: file, line: line)
            XCTAssertTrue(stage.addition.isZero || stage.addition == stage.modulus.halved(), file: file, line: line)
        }
    }

    func testClassExamplesAllApplicableMethods() throws {
        for (a, m, expected) in [(129,257,2), (3,7,5), (113,512,145), (7,16,7)] {
            for method in [ModularMethod.automatic, .binary, .lifting, .powerMatrix] {
                if (method == .lifting || method == .powerMatrix) && Natural(UInt64(m)).powerOfTwoExponent == nil { continue }
                let s = try ModularSolver.solve(a: String(a), modulus: String(m), method: method)
                XCTAssertEqual(s.result?.description, String(expected))
                try verifyFrames(s)
            }
        }
        for (n, a, m, expected) in [(153,179,283,72), (5,7,13,10), (73,97,357,67)] {
            for method in [ModularMethod.direct, .binary] {
                let s = try ModularSolver.solve(a: String(a), modulus: String(m), numerator: String(n), method: method)
                // Use the congruence independently of handwritten homework answers.
                XCTAssertEqual((Int(s.result!.description)! * a) % m, n % m)
                XCTAssertEqual(s.result?.description, String(expected))
                try verifyFrames(s)
            }
        }
    }

    func testNegativeRepresentativesAndPriority() throws {
        let s = try ModularSolver.solve(a: "3", modulus: "7", method: .binary)
        XCTAssertTrue(s.frames.contains { $0.action == .adjust && $0.rows.contains { $0.alpha.isNegative && !$0.alpha.isOdd } })
        try verifyFrames(s)
        let power = try ModularSolver.solve(a: "113", modulus: "512", method: .powerMatrix)
        XCTAssertTrue(power.frames.contains { $0.rows[0].alpha.description == "−480" })
        XCTAssertEqual(power.frames.filter { $0.action == .halve }.count, 9)
        try verifyFrames(power)
        let direct = try ModularSolver.solve(a: "179", modulus: "283", numerator: "153", method: .direct)
        let firstAccumulate = direct.frames.firstIndex { $0.action == .accumulate }!
        XCTAssertEqual(firstAccumulate, 2)
        XCTAssertEqual(direct.frames[firstAccumulate].rows[2].value, Natural(104))
        XCTAssertEqual(direct.frames[firstAccumulate].remaining, Natural(49))
        try verifyFrames(direct)
    }

    func testDirectDivisionCapturesClassRowsImmediately() throws {
        let s = try ModularSolver.solve(a: "179", modulus: "283", numerator: "153", method: .direct)
        XCTAssertEqual(s.frames[0].rows.map(\.value), [Natural(283), Natural(179), .zero])
        XCTAssertEqual(s.frames[0].remaining, Natural(153))
        XCTAssertEqual(s.frames[1].rows.map(\.value), [Natural(104), Natural(179), .zero])
        XCTAssertEqual(s.frames[1].rows.map(\.alpha.description), ["−1", "1", "0"])
        XCTAssertEqual(s.frames[1].remaining, Natural(153))
        let captures = Array(s.frames.filter { $0.action == .accumulate }.prefix(3))
        XCTAssertEqual(captures.map { $0.rows[2].value.description }, ["104", "130", "143"])
        XCTAssertEqual(captures.map { $0.rows[2].alpha.description }, ["−1", "−72", "34"])
        XCTAssertEqual(captures.map { $0.remaining!.description }, ["49", "23", "10"])
        XCTAssertEqual(s.frames.last?.remaining, .zero)
        XCTAssertEqual(s.result, Natural(72))
        try verifyFrames(s)
    }

    func testDirectDivisionLargeFactorsOnlyForOneOrTwo() throws {
        for (a, factor, remainder) in [("1", "99", "0"), ("2", "49", "1")] {
            let s = try ModularSolver.solve(a: a, modulus: "101", numerator: "99", method: .direct)
            XCTAssertEqual(s.frames[1].operation, "M₃,₂(\(factor))")
            XCTAssertEqual(s.frames[1].remaining?.description, remainder)
            XCTAssertEqual(s.frames.last?.remaining, .zero)
            try verifyFrames(s)
        }
        // A small nonterminal row must not cause one addition per target unit.
        let modulus = "1" + String(repeating: "0", count: 99) + "1"
        let target = String(repeating: "9", count: 100)
        let large = try ModularSolver.solve(a: "3", modulus: modulus, numerator: target, method: .direct)
        XCTAssertLessThan(large.frames.count, 2000)
        XCTAssertEqual(try (Natural(3) * large.result!).divided(by: large.modulus).remainder, large.target)
        try verifyFrames(large)
    }

    func testExhaustiveSmallInputsAndAllMethods() throws {
        for m in 2...45 {
            for a in -45...45 {
                let residue = (a % m + m) % m
                let expected = (0..<m).first { (residue * $0) % m == 1 }
                let methods: [ModularMethod] = Natural(UInt64(m)).powerOfTwoExponent != nil ? [.binary, .powerMatrix, .lifting] : [.binary]
                for method in methods {
                    let s = try ModularSolver.solve(a: String(a), modulus: String(m), method: method)
                    XCTAssertEqual(s.result?.description, expected.map(String.init), "\(a), \(m), \(method)")
                    XCTAssertEqual(s.gcdTrace.gcd.description, String(gcd(a, m)))
                    try verifyFrames(s)
                }
                for n in [-47, 0, 1, 19, 63] {
                    let s = try ModularSolver.solve(a: String(a), modulus: String(m), numerator: String(n), method: .direct)
                    let target = (n % m + m) % m
                    XCTAssertEqual(s.result?.description, expected.map { String(($0 * target) % m) })
                    try verifyFrames(s)
                }
            }
        }
    }

    func testZeroNonCoprimeAndInvalidMethods() throws {
        for method in [ModularMethod.binary, .lifting, .powerMatrix] {
            let s = try ModularSolver.solve(a: "0", modulus: "16", method: method)
            XCTAssertNil(s.result)
            XCTAssertEqual(s.gcdTrace.gcd, Natural(16))
        }
        let multiple = try ModularSolver.solve(a: "6", modulus: "15", numerator: "9", method: .direct)
        XCTAssertNil(multiple.result)
        XCTAssertTrue(multiple.conclusion.last!.contains("3 классов"))
        let impossible = try ModularSolver.solve(a: "6", modulus: "15", numerator: "8", method: .direct)
        XCTAssertTrue(impossible.conclusion.last!.contains("решений не имеет"))
        for m in ["0", "1", "-7", "bad"] { XCTAssertThrowsError(try ModularSolver.solve(a: "3", modulus: m)) }
        XCTAssertThrowsError(try ModularSolver.solve(a: "bad", modulus: "7"))
        XCTAssertThrowsError(try ModularSolver.solve(a: "3", modulus: "7", numerator: "bad"))
        XCTAssertThrowsError(try ModularSolver.solve(a: "3", modulus: "7", method: .lifting))
        XCTAssertThrowsError(try ModularSolver.solve(a: "3", modulus: "7", method: .powerMatrix))
        XCTAssertThrowsError(try ModularSolver.solve(a: "3", modulus: "7", method: .direct))
    }

    func testIndependentPythonFixtures() throws {
        struct Fixture: Decodable { let a: String; let m: String; let n: String; let inverse: String?; let result: String? }
        let url = Bundle.module.url(forResource: "modular-references", withExtension: "json")!
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
        for f in fixtures {
            let inv = try ModularSolver.solve(a: f.a, modulus: f.m)
            XCTAssertEqual(inv.result?.description, f.inverse)
            let direct = try ModularSolver.solve(a: f.a, modulus: f.m, numerator: f.n, method: .direct)
            XCTAssertEqual(direct.result?.description, f.result)
            // Full invariant checks on medium fixtures; enormous products would
            // duplicate work thousands of times for the 1001-digit modulus.
            if f.m.count < 80 { try verifyFrames(inv); try verifyFrames(direct) }
        }
    }

    func testInverseThenMultiplyForSignedNumerator() throws {
        for method in [ModularMethod.binary, .lifting, .powerMatrix] {
            let s = try ModularSolver.solve(a: "-113", modulus: "512", numerator: "-1001", method: method)
            XCTAssertEqual(s.result, Natural(UInt64((1001 * 145) % 512)))
            XCTAssertNotNil(s.multiplication)
            try verifyFrames(s)
        }
    }

    func testCancellationDuringWork() throws {
        for method in [ModularMethod.binary, .lifting, .powerMatrix, .direct] {
            var count = 0
            XCTAssertThrowsError(try ModularSolver.solve(a: "113", modulus: "512", numerator: "153", method: method) {
                count += 1
                if count == 12 { throw CancellationError() }
            }) { XCTAssertTrue($0 is CancellationError) }
        }
    }
}
