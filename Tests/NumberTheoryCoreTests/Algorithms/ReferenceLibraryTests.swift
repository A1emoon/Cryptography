import XCTest
@testable import NumberTheoryCore

final class ReferenceLibraryTests: XCTestCase {
    func testCourseSelectionMatchesTheUsersThirtySixItems() throws {
        let library = CourseLibrary.shared
        XCTAssertNil(library.error)
        let required = library.courseEntries(.theorem)
        let expected = ["egyptian-algebraic","binary-division-step","binary-division-algebraic","egyptian-bit","binary-division-bit","naive-modular-bit","doubling-bit","order-monotonic","order-prime-power","order-growth","order-crt","finite-field-cyclic","primitive-count","primitive-lift","two-power-bound","five-order","five-signs","maximal-order","residue-log-criterion","residue-criterion","parity-product","jacobi-two","jacobi-minus-one","extension-is-field","binomial-prime","frobenius-conjugate","cipolla","unity-roots","tonelli-residue-order","tonelli-nonresidue","root-gcd","rabin-probability","two-square-obstruction","two-square-neighbours","two-square-lift","two-square-four"]
        XCTAssertEqual(required.map(\.id), expected)
        XCTAssertEqual(required.compactMap(\.courseOrder), Array(1...36))
        XCTAssertEqual(library.courseEntries(.definition).count, 26)
        XCTAssertEqual(library.entries.filter { $0.kind == .theorem && $0.tier == .additional }.count, 15)
        // General mathematical background is deliberately excluded from the course selection.
        for id in ["prime","group","lagrange","bezout","doubling-correct"] { XCTAssertEqual(library[id]?.tier, .support) }
        for e in required {
            XCTAssertFalse(e.sourceMarker?.isEmpty ?? true, e.id)
            XCTAssertGreaterThanOrEqual(e.proof.count, 3, e.id)
            XCTAssertGreaterThan(e.proof.reduce(0) { $0 + $1.text.count }, 400, e.id)
            XCTAssertTrue(e.sources.contains { $0.file == "N1" }, e.id)
            XCTAssertTrue(e.sources.contains { $0.file.hasPrefix("L") }, e.id)
        }
    }
    func testCatalogIntegrityAndSourcePages() throws {
        let library = CourseLibrary.shared
        XCTAssertNil(library.error)
        XCTAssertEqual(Set(library.entries.map(\.id)).count, library.entries.count)
        XCTAssertEqual(library.sources.count, 43)
        XCTAssertEqual(Set(library.sources.map(\.id)).count, library.sources.count)
        XCTAssertEqual(library.sources.filter { $0.path.hasSuffix(".pdf") }.reduce(0) { $0 + $1.pages }, 220)
        XCTAssertEqual(library.source("N1")?.pages, 142)
        XCTAssertFalse(library.source("N1")?.notice?.isEmpty ?? true)
        for entry in library.entries {
            XCTAssertFalse(entry.body.isEmpty, entry.id)
            XCTAssertFalse(entry.sources.isEmpty, entry.id)
            for source in entry.sources {
                let file = try XCTUnwrap(library.source(source.file), entry.id)
                XCTAssertTrue((1...file.pages).contains(source.page), entry.id)
            }
            for id in entry.related { XCTAssertNotNil(library[id], entry.id + "→" + id) }
            if entry.kind == .theorem { XCTAssertFalse(entry.proof.isEmpty, entry.id) }
        }
    }
    func testEveryTheoremHasItsOwnCopyableMathematicalProof() throws {
        let library = CourseLibrary.shared
        XCTAssertNil(library.error)
        XCTAssertEqual(library.version, 3)
        let theorems = library.entries.filter { $0.kind == .theorem }
        XCTAssertEqual(theorems.count, 87)
        for entry in theorems {
            let sheet = try XCTUnwrap(entry.writtenProof, entry.id)
            XCTAssertFalse(sheet.given.isEmpty, entry.id)
            XCTAssertFalse(sheet.claim.isEmpty, entry.id)
            XCTAssertGreaterThanOrEqual(sheet.lines.count, 4, entry.id)
            for row in sheet.given + sheet.claim + sheet.lines {
                XCTAssertFalse(row.isEmpty, entry.id)
                XCTAssertTrue(row.allSatisfy { !$0.a.isEmpty }, entry.id)
            }
            // The detailed explanation remains available independently of the written proof.
            XCTAssertFalse(entry.proof.isEmpty, entry.id)
        }
    }
    func testProofsPreserveTheLecturersNotation() throws {
        let library = CourseLibrary.shared
        func writing(_ id: String) throws -> String {
            let entry = try XCTUnwrap(library[id])
            let proof = try XCTUnwrap(entry.writtenProof)
            return (proof.given + proof.claim + proof.lines).flatMap { $0 }.map(\.a).joined(separator: " ")
        }
        for entry in library.entries where entry.kind == .theorem {
            let text = try writing(entry.id)
            for alias in ["gcd(","НОД(","НОК(","ker ψ","im ψ","N(z)","v_{2}("] {
                XCTAssertFalse(text.contains(alias), entry.id + ": " + alias)
            }
        }
        XCTAssertTrue(try writing("order-crt").contains("М("))
        XCTAssertTrue(try writing("order-crt").contains("q_j^{k_j}"))
        XCTAssertTrue(try writing("extension-is-field").contains("GF(q^{2})"))
        XCTAssertTrue(try writing("extension-is-field").contains("ω^{2}=r"))
        XCTAssertTrue(try writing("binomial-prime").contains("C_q^t"))
        XCTAssertTrue(try writing("residue-log-criterion").contains("ind_g"))
        XCTAssertTrue(try writing("tonelli-residue-order").contains("n^{s′}r′"))
        XCTAssertTrue(try writing("rabin-probability").contains("g(t)"))
        XCTAssertTrue(try writing("two-square-lift").contains("2^{m+3}"))
        XCTAssertTrue(try writing("two-square-four").contains("x_{1}=x_{0}+2b"))
    }
    func testLectureRootRelationsAtTwoPowerModuli() {
        // Exhaustive independent check of the m+2/m+3 exponents in lecture 9.
        for m in 1...5 {
            let modulus = 1 << (m+2), next = 2*modulus, shift = 1 << (m+1)
            for a in stride(from:1,to:modulus,by:2) {
                let roots = (0..<modulus).filter { ($0*$0)%modulus == a }
                guard let x0 = roots.first else { continue }
                let expected = Set([x0, (modulus-x0)%modulus, (x0+shift)%modulus, (modulus-x0+shift)%modulus])
                XCTAssertEqual(Set(roots), expected, "m=\(m), a=\(a)")
                XCTAssertEqual(expected.count, 4)
                for x in roots {
                    let first = (x*x)%next == a
                    let y = x+shift
                    let second = (y*y)%next == a
                    XCTAssertNotEqual(first, second, "m=\(m), a=\(a), x=\(x)")
                }
            }
        }
    }
    func testSearchPreservesCoursePriorityAndHelperLinks() {
        let l = CourseLibrary.shared
        XCTAssertEqual(l.search("",kind:.theorem).first?.id,"egyptian-algebraic")
        let results = l.search("порядок",kind:.theorem)
        XCTAssertTrue(results.contains { $0.isRequired })
        XCTAssertEqual(results.map { $0.tier.rank }, results.map { $0.tier.rank }.sorted())
        XCTAssertTrue(l.search("Тонелли",kind:.theorem).contains { $0.id == "tonelli" })
        XCTAssertTrue(l.search("Тонелли",kind:.theorem).contains { $0.id == "tonelli-nonresidue" })
        XCTAssertTrue(l.search("№32",kind:.theorem).contains { $0.id == "rabin-probability" })
        XCTAssertEqual(CourseLibrary.normalized("СОПРЯЖЁННЫЙ"), CourseLibrary.normalized("сопряженный"))
        XCTAssertTrue(l.search("не существующее слово 987654321",kind:.definition).isEmpty)
    }
    func testRabinProbabilityBoundWithTheRequiredLinearCheck() throws {
        // Independent finite enumeration checks the plus sign and the zero-shift cases.
        for q: UInt64 in [3,5,7,11,13,17,19] {
            let exponent=(q-1)/2
            for x in UInt64(1)..<q {
                for y in (x+1)..<q {
                    var success=0
                    for delta in UInt64(0)..<q {
                        let a=(x+delta)%q,b=(y+delta)%q
                        if a==0 || b==0 { success+=1;continue }
                        if try Mod64.power(a,exponent,q) != Mod64.power(b,exponent,q) { success+=1 }
                    }
                    XCTAssertGreaterThanOrEqual(2*success,Int(q+3),"q=\(q), roots=\(x),\(y)")
                }
            }
        }
    }
    func testExactFiniteBitCostSumsAndBoundaryCorrections() {
        for m in 2...100 {
            let lower=m+(1..<m).reduce(0) { $0+m+$1-1 }
            let upper=m+(1..<m).reduce(0) { $0+2*m+4*$1-3 }
            XCTAssertEqual(2*lower,3*m*m-3*m+2)
            XCTAssertEqual(upper,4*m*m-6*m+3)
            XCTAssertGreaterThanOrEqual(lower,m*m)
            XCTAssertLessThan(upper,4*m*m)
        }
        for k in 14...70 {
            for n in k...(2*k) {
                let count=n-k+1, alpha=Double(n)/Double(k)
                let lower=n+k+(0..<count).reduce(0) { $0+3*(n-$1)+k }
                let upper=lower+count*k
                let coefficient=1.5*alpha*alpha+alpha-2.5
                XCTAssertGreaterThan(Double(lower),coefficient*Double(k*k)-1e-8)
                XCTAssertLessThan(Double(upper),(coefficient+alpha)*Double(k*k)+1e-8)
            }
        }
    }
    func testRequiredDefinitionsUseIndependentLectureTranscriptions() throws {
        let library = CourseLibrary.shared
        for entry in library.courseEntries(.definition) {
            let definition = try XCTUnwrap(entry.verbatimDefinition, entry.id)
            XCTAssertFalse(definition.blocks.isEmpty, entry.id)
            XCTAssertFalse(definition.sources.isEmpty, entry.id)
            for location in definition.sources {
                let source = try XCTUnwrap(library.source(location.file))
                XCTAssertTrue((1...source.pages).contains(location.page), entry.id)
            }
            for block in definition.blocks {
                XCTAssertTrue(["text", "formula", "cases", "system", "set"].contains(block.kind), entry.id)
                if block.kind == "text" { XCTAssertFalse(block.text.isEmpty, entry.id) }
                if block.kind == "formula" { XCTAssertFalse(block.atoms.isEmpty, entry.id) }
                if block.kind == "cases" || block.kind == "system" {
                    XCTAssertFalse(block.rows.isEmpty, entry.id)
                    XCTAssertEqual(block.bracket, block.kind == "system" ? "brace" : "square", entry.id)
                }
            }
        }
        let legendre = try XCTUnwrap(library["legendre"]?.verbatimDefinition?.blocks.first)
        XCTAssertEqual(legendre.rows.count, 3)
        XCTAssertEqual(legendre.rows[1].condition.first?.a, "a ∈ R(2, ℤ_q), q ∣ a")
        XCTAssertEqual(legendre.bracket, "square")
        let carmichael = try XCTUnwrap(library["carmichael"]?.verbatimDefinition?.blocks.first)
        XCTAssertEqual(carmichael.rows.count, 2)
        XCTAssertTrue(carmichael.rows[1].condition.contains { $0.a.contains("c₀+2") })
        XCTAssertFalse(library["two-component-log"]!.verbatimDefinition!.blocks.contains { $0.kind == "system" })
        let field = try XCTUnwrap(library["extension-field"]?.verbatimDefinition?.blocks.first { $0.kind == "set" })
        XCTAssertEqual(field.rows.count, 2)
        XCTAssertEqual(field.rows[0].value.first?.a, "ω² = r ∉ R(2, ℤ_q)")
        XCTAssertFalse(library["conjugate"]!.verbatimDefinition!.blocks.flatMap(\.atoms).contains { $0.a.contains("N(z)") })
        // Supplemental prose is still searchable, but does not replace the copied source passage.
        XCTAssertTrue(library.search("нулевым свободным", kind: .definition).contains { $0.id == "polynomial-even" })
    }
    func testSourceExcerptsAreGroupedAndCannotSilentlyOpenWholeDocuments() {
        let locations = [ReferenceLocation(file: "L7", page: 3), ReferenceLocation(file: "N1", page: 94), ReferenceLocation(file: "L7", page: 1), ReferenceLocation(file: "L7", page: 3)]
        let excerpts = ReferenceSourceSelection.excerpts(locations)
        XCTAssertEqual(excerpts.map(\.file), ["L7", "N1"])
        XCTAssertEqual(excerpts.first?.pages, [1, 3])
        XCTAssertEqual(excerpts.first?.indices(pageCount: 10), [0, 2])
        XCTAssertEqual(ReferenceSourceSelection(file: "L7", pages: nil).indices(pageCount: 3), [0, 1, 2])
        for invalid in [[], [0], [-1], [1, 11]] {
            XCTAssertNil(ReferenceSourceSelection(file: "L7", pages: invalid).indices(pageCount: 10))
        }
        XCTAssertNil(ReferenceSourceSelection(file: "L7", pages: nil).indices(pageCount: 0))
    }

}
