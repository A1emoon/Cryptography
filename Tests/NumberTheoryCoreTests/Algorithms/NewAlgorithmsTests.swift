import XCTest
@testable import NumberTheoryCore

final class NewAlgorithmsTests: XCTestCase {
    func testLectureCubicCorrectionsAndAllRoots() throws {
        let s = try TonelliShanksSolver.solve(a: "13", p: "163", degree: 3)
        XCTAssertEqual(s.roots, [19,20,124]); XCTAssertEqual(s.s,4); XCTAssertEqual(s.r,2)
        XCTAssertEqual(s.nonResidue,2); XCTAssertEqual(s.B,104); XCTAssertEqual(s.k,9)
        XCTAssertEqual(s.descents.map(\.aPower.exponent),[18,6,2])
        XCTAssertEqual(s.descents.map(\.bPower.exponent),[0,18,6])
        XCTAssertEqual(s.descents.map(\.value),[58,1,58])
        XCTAssertEqual(s.descents.map(\.choice),[1,0,1])
        XCTAssertEqual(s.descents.map(\.bExponentAfter),[54,18,60])
        XCTAssertEqual(s.identityBExponent,60); XCTAssertEqual(s.rootBPower?.exponent,20)
        XCTAssertEqual(s.seedRoot,124)
        XCTAssertEqual(try TonelliShanksSolver.solve(a:"15",p:"17").roots,[7,10])
        XCTAssertEqual(try TonelliShanksSolver.solve(a:"2",p:"41").roots,[17,24])
        XCTAssertEqual(try TonelliShanksSolver.solve(a:"13",p:"29").roots,[10,19])
    }
    func testAllSevenPhotographedExamplesAndTheirIdentities() throws {
        let samples:[(String,String,Int,[UInt64],UInt64,UInt64,UInt64)] = [
            ("5","41",2,[13,28],30,15,28), ("6","97",2,[43,54],72,36,54),
            ("3","73",3,[25,54,67],48,16,25), ("13","163",3,[19,20,124],60,20,124),
            ("17","163",3,[7,76,80],48,16,7), ("267","487",3,[12,126,349],378,126,126),
            ("26","487",3,[10,105,372],210,70,105)
        ]
        for (a,p,n,roots,C,rootC,seed) in samples {
            let value=try TonelliShanksSolver.solve(a:a,p:p,degree:n)
            XCTAssertEqual(value.roots,roots)
            XCTAssertEqual(value.identityBExponent,C)
            XCTAssertEqual(value.rootBPower?.exponent,rootC)
            XCTAssertEqual(value.seedRoot,seed)
            let lines=TonelliLecture.lines(value)
            XCTAssertTrue(lines.contains{$0.id == (n == 3 ? "tonelliB" : "tonelliNonResidueOrder")})
            XCTAssertTrue(lines.contains{$0.id == "tonelliMultiplyByA"})
            XCTAssertTrue(lines.contains{$0.id == "tonelliExtractPower"})
            XCTAssertEqual(Set(lines.map(\.id)).count,lines.count)
            let identity=Mod64.multiply(try Mod64.power(value.a,value.r,value.p),try Mod64.power(value.nonResidue!,C,value.p),value.p)
            XCTAssertEqual(identity,1)
        }
        let s=try TonelliShanksSolver.solve(a:"26",p:"487",degree:3)
        XCTAssertEqual(s.descents.map(\.aPower.exponent),[54,18,6,2])
        XCTAssertEqual(s.descents.map(\.bExponentAfter),[324,432,144,210])
        let r1=try TonelliShanksSolver.solve(a:"8",p:"37",degree:3)
        XCTAssertEqual(r1.rootMultiplier,2)
        XCTAssertTrue(TonelliLecture.lines(r1).contains{$0.id == "tonelliSquareIdentity"})
        let q=try TonelliShanksSolver.solve(a:"5",p:"41",degree:2)
        XCTAssertEqual(q.quadraticCriterion?.value,1)
        XCTAssertEqual(q.quadraticTrials.map(\.value),[1,-1])
        XCTAssertEqual(q.k,2)
    }

    func testTonelliWrittenProofNeedsNoAuxiliaryWindow() throws {
        func text(_ line:TonelliLectureLine)->String {
            line.atoms.map { atom in
                switch atom {
                case .text(let s), .rich(let s): s
                case .power(let a,let b): a+"^{"+b+"}"
                case .fraction(let a,let b): "("+a+")/("+b+")"
                case .fractionPower(let a,let b,let c): a+"^{("+b+")/("+c+")}"
                case .congruence(_,let unequal):unequal ? "≢" : "≡"
                case .symbol(let a,let b): "("+a+"/"+b+")"
                }
            }.joined(separator:" ")
        }
        let cubic=TonelliLecture.lines(try TonelliShanksSolver.solve(a:"17",p:"163",degree:3))
        for exponent in [2,4,8,16,32] {
            XCTAssertNotNil(cubic.first{$0.id == "tonelliCriterion_square_\(exponent)"},"Successive squares must be on the main page")
        }
        let criterion=text(try XCTUnwrap(cubic.first{$0.id == "tonelliCriterion"}))
        for fragment in ["17^{54}","17^{2}","17^{4}","17^{16}","17^{32}","−37","65","36","1"] { XCTAssertTrue(criterion.contains(fragment),fragment) }
        let identity=text(try XCTUnwrap(cubic.first{$0.id == "tonelliIdentity_0"}))
        for fragment in ["B^{2}","2^{54}","2·54","2^{108}"] { XCTAssertTrue(identity.contains(fragment),fragment) }
        XCTAssertTrue(cubic.contains{$0.id.hasPrefix("tonelliOrder_")})
        let square=TonelliLecture.lines(try TonelliShanksSolver.solve(a:"5",p:"41",degree:2))
        let symbol=text(try XCTUnwrap(square.first{$0.id == "tonelliCriterion"}))
        for fragment in ["(5/41)","(41/5)","(1/5)","40 · 4","40"] { XCTAssertTrue(symbol.contains(fragment),fragment) }
        XCTAssertTrue(try XCTUnwrap(square.first{$0.id == "tonelliCriterion"}).works.isEmpty,"Reciprocity must not be hidden in a sheet")
        for line in cubic+square {
            for work in line.works.values {
                // The type intentionally permits only the multiplication done on the side.
                switch work { case .product(let a,let b,let p):
                    XCTAssertNotNil(DecimalInteger(text:a));XCTAssertNotNil(DecimalInteger(text:b));XCTAssertNotNil(UInt64(p))
                }
            }
        }
    }

    func testTonelliSquareIsWrittenOnceWithItsFullCalculation() throws {
        let s=try TonelliShanksSolver.solve(a:"15",p:"17")
        let lines=TonelliLecture.lines(s)
        let first=try XCTUnwrap(lines.first{$0.id == "tonelliOrder_0"})
        XCTAssertNil(lines.first{$0.id == "tonelliOrder_0_square_2"})
        XCTAssertEqual(first.atoms.count,4)
        if case .power("15","2")=first.atoms[0] {} else { XCTFail("Start with 15², without (15)²=15²") }
        if case .congruence(17,unequal:false)=first.atoms[1] {} else { XCTFail("Write the modulus above modular equality") }
        if case .power("(−2)","2")=first.atoms[2] {} else { XCTFail("Preserve substitution of −2") }
        if case .text("= 4")=first.atoms[3] {} else { XCTFail("Preserve the computed square") }
        if case .product("−2","−2","17")=first.works[2] {} else { XCTFail("Multiplication link must follow the merged square") }
        XCTAssertEqual(Set(lines.map(\.id)).count,lines.count)
        XCTAssertEqual(s.roots,[7,10])
        for (a,p,n) in [("5","41",2),("13","163",3),("17","163",3),("26","487",3)] {
            let written=TonelliLecture.lines(try TonelliShanksSolver.solve(a:a,p:p,degree:n))
            // Previously calculated a^r is reused from the criterion, without a copy.
            if n == 3 { XCTAssertFalse(written.contains{$0.id == "tonelliInitial"}) }
            XCTAssertTrue(written.contains{$0.id == "tonelliExtract"})
            for row in written where row.id.hasPrefix("tonelliOrder_") && !row.id.contains("_square_") {
                let exponent=row.id
                XCTAssertFalse(written.contains{$0.id.hasPrefix(exponent+"_square_") && $0.id == exponent+"_square_2"})
            }
        }
    }

    func testQuadraticShanksMatchesTheLecturerCorrectionOrder() throws {
        let value=try TonelliShanksSolver.solve(a:"15",p:"17")
        XCTAssertEqual(value.initialOrder,8)
        XCTAssertEqual(value.nonResidue,3)
        XCTAssertEqual(value.nonResidueOrderTests.map(\.result),[9,13,16,1])
        XCTAssertEqual(value.quadraticCorrections.map(\.orderBefore),[8,2])
        XCTAssertEqual(value.quadraticCorrections.map(\.orderAfter),[2,1])
        XCTAssertEqual(value.quadraticCorrections.map(\.bExponentAfter),[2,10])
        XCTAssertEqual(value.quadraticCorrections.map(\.valueAfter),[16,1])
        XCTAssertEqual(value.rootBPower?.exponent,5)
        XCTAssertEqual(value.seedRoot,7);XCTAssertEqual(value.roots,[7,10])
        let lines=TonelliLecture.lines(value)
        func text(_ row:TonelliLectureLine)->String {
            row.atoms.map { atom in
                switch atom {
                case .rich(let s),.text(let s):s
                case .power(let a,let e):a+"^{"+e+"}"
                case .fraction(let a,let b):a+"/"+b
                case .fractionPower(let a,let b,let c):a+"^{("+b+")/"+c+"}"
                case .congruence(_,let unequal):unequal ? "≢" : "≡"
                case .symbol(let a,let b):"("+a+"/"+b+")"
                }
            }.joined(separator:" ")
        }
        let rows=Dictionary(uniqueKeysWithValues:lines.map{($0.id,text($0))})
        XCTAssertTrue(rows["tonelliInitialOrder"]!.contains("P_{17}(15) = 8"))
        XCTAssertTrue(rows["tonelliNonResidueOrder"]!.contains("P_{17}(3) = 2^{4} = 16"))
        XCTAssertTrue(rows["tonelliRegroup_0"]!.contains("(15 · 3^{2})^{4}"))
        XCTAssertTrue(rows["tonelliCorrected_0"]!.contains("c₁ ≡ 15 · 3^{2}"))
        XCTAssertTrue(rows["tonelliCorrected_0"]!.contains("= −18 ≡ −1"))
        XCTAssertTrue(rows["tonelliCorrectedOrder_0"]!.contains("P_{17}(c₁) = P_{17}(−1) = 2"))
        XCTAssertTrue(rows["tonelliCorrected_1"]!.contains("c₂ ≡ 15 · 3^{10} ≡ 1"))
        XCTAssertTrue(rows["tonelliCorrectedOrder_1"]!.contains("P_{17}(c₂) = P_{17}(1) = 1"))
        XCTAssertFalse(lines.contains{$0.id == "tonelliK" || $0.id == "tonelliB" || $0.id.hasPrefix("tonelliDescentValue_")})
        XCTAssertEqual(lines.filter{$0.id.hasPrefix("tonelliCorrection_")}.count,2)
        XCTAssertTrue(rows["tonelliExtractPower"]!.contains("(15 · 3^{5})²"))
        XCTAssertTrue(rows["tonelliExtract"]!.contains("= 75 ≡ 7"))
        XCTAssertTrue(rows["tonelliRootBPower"]!.contains("3 · 13 = 39 ≡ 5"))
        XCTAssertTrue(rows["tonelliVerification_0"]!.contains("7^{2} = 7 · 7 = 49 ≡ 15"))
        XCTAssertTrue(rows["tonelliVerification_1"]!.contains("10^{2} = 10 · 10 = 100 ≡ 15"))
        let general=try TonelliShanksSolver.solve(a:"6",p:"97")
        XCTAssertEqual(general.r,3)
        XCTAssertTrue(TonelliLecture.lines(general).contains{$0.id == "tonelliInitial"})
        XCTAssertEqual(general.nonResidueInitial?.exponent,3)
        let noCorrection=try TonelliShanksSolver.solve(a:"1",p:"17")
        XCTAssertTrue(noCorrection.quadraticCorrections.isEmpty)
        XCTAssertEqual(noCorrection.roots,[1,16])
        let largeP:UInt64=18446744069414584321, knownRoot:UInt64=123456789
        let residue=Mod64.multiply(knownRoot,knownRoot,largeP)
        let large=try TonelliShanksSolver.solve(a:String(residue),p:String(largeP))
        XCTAssertEqual(large.roots,[knownRoot,largeP-knownRoot])
        for stage in large.quadraticCorrections {
            XCTAssertEqual(Mod64.multiply(large.initial!.result,stage.totalFactor.result,largeP),stage.valueAfter)
            XCTAssertLessThan(stage.orderAfter,stage.orderBefore)
            XCTAssertFalse(stage.bExponentAfter.multipliedReportingOverflow(by:stage.orderBefore/2).overflow)
        }
        let largeLines=TonelliLecture.lines(large)
        XCTAssertEqual(Set(largeLines.map(\.id)).count,largeLines.count)

    }

    func testShanksLabelsEveryModularComparisonWithTheCorrectModulus() throws {
        for (a,p,n) in [("15","17",2),("13","163",3),("5","41",2),("5","17",2),("0","17",2),("1","2",2)] {
            let rows=TonelliLecture.lines(try TonelliShanksSolver.solve(a:a,p:p,degree:n))
            var comparisons=0
            for row in rows {
                for atom in row.atoms {
                    switch atom {
                    case .congruence(let modulus,_):XCTAssertEqual(modulus,UInt64(p));comparisons+=1
                    case .text(let text),.rich(let text):
                        XCTAssertFalse(text.contains("≡") || text.contains("≢"),row.id)
                        XCTAssertFalse(text.contains("(mod"),row.id)
                    default:break
                    }
                }
                for i in row.works.keys {
                    XCTAssertTrue(row.atoms.indices.contains(i))
                    if case .congruence=row.atoms[i] { XCTFail("A product link must stay on its expression") }
                }
            }
            XCTAssertGreaterThan(comparisons,0)
        }
        let unique=TonelliLecture.lines(try TonelliShanksSolver.solve(a:"2",p:"5",degree:3))
        let inverse=try XCTUnwrap(unique.first{$0.id == "tonelli_unique_1"})
        XCTAssertTrue(inverse.atoms.contains{if case .congruence(4,unequal:false)=$0 {return true};return false})
        let root=try XCTUnwrap(unique.first{$0.id == "tonelli_unique_2"})
        XCTAssertTrue(root.atoms.contains{if case .congruence(5,unequal:false)=$0 {return true};return false})
        let first=try XCTUnwrap(TonelliLecture.lines(try TonelliShanksSolver.solve(a:"15",p:"17")).first{$0.id == "tonelliCorrected_0"})
        XCTAssertEqual(first.atoms.filter{if case .congruence(17,unequal:false)=$0 {return true};return false}.count,3)
        let productIndex=try XCTUnwrap(first.works.first?.key)
        if case .text("(−2) · 9")=first.atoms[productIndex] {} else {XCTFail("Retain the link to (−2)·9 after splitting c₁≡15·3²")}
    }

    func testCubicShanksProvesTheOrderAndAllThreeRoots() throws {
        let value=try TonelliShanksSolver.solve(a:"13",p:"163",degree:3)
        XCTAssertEqual(value.orderTests.map(\.result),[53,58,1])
        XCTAssertEqual(value.initialOrder,27);XCTAssertEqual(value.k,9)
        let rows=TonelliLecture.lines(value)
        func text(_ row:TonelliLectureLine)->String {
            row.atoms.map { atom in
                switch atom {
                case .text(let t),.rich(let t):t
                case .congruence(_,let unequal):unequal ? "≢" : "≡"
                case .power(let a,let e):a+"^{"+e+"}"
                case .fraction(let a,let b):a+"/"+b
                case .fractionPower(let a,let b,let c):a+"^{("+b+")/"+c+"}"
                case .symbol(let a,let b):"("+a+"/"+b+")"
                }
            }.joined(separator:" ")
        }
        let map=Dictionary(uniqueKeysWithValues:rows.map{($0.id,text($0))})
        XCTAssertTrue(map["tonelliCubicOrderBound"]!.contains("{1, 3, 9, 27}"))
        XCTAssertTrue(map["tonelliOrder_0"]!.contains("≢ 1"))
        XCTAssertTrue(map["tonelliOrder_1"]!.contains("≢ 1"))
        XCTAssertTrue(map["tonelliCubicOrderProof"]!.contains("13^{18} ≡ 58 ≢ 1"))
        XCTAssertTrue(map["tonelliCubicOrderProof"]!.contains("P_{163}(13^{2}) = 27"))
        XCTAssertTrue(map["tonelliK"]!.contains("3k = P_{163}(13^{2}) = 27"))
        XCTAssertLessThan(rows.firstIndex{$0.id == "tonelliCubicOrderProof"}!,rows.firstIndex{$0.id == "tonelliK"}!)
        XCTAssertTrue(map["tonelliDescentValue_2"]!.contains("≡ B²"))
        XCTAssertTrue(map["tonelliCorrection_2"]!.contains("B^{3} ≡ 1"))
        XCTAssertTrue(map["tonelliUnityOrder"]!.contains("P_{163}(B) = 3"))
        for (i,expected) in ["6859 = 163 · 42 + 13","8000 = 163 · 49 + 13","1906624 = 163 · 11697 + 13"].enumerated() {
            XCTAssertTrue(map["tonelliCubicVerification_\(i)"]!.contains(expected))
        }
        XCTAssertTrue(map["tonelliCubicCompleteness"]!.contains("{19, 20, 124}"))
        for proof in value.cubicVerifications {
            XCTAssertEqual(proof.exactCube,Natural(value.p)*proof.quotient+proof.remainder)
            XCTAssertEqual(proof.remainder,Natural(value.a))
        }
        let ids=Set(CourseLibrary.shared.entries.map(\.id))
        XCTAssertTrue(rows.flatMap(\.references).allSatisfy{ids.contains($0)})
    }

    func testShanksRootVerificationShowsBothMultiplications() throws {
        let cubic=try TonelliShanksSolver.solve(a:"13",p:"163",degree:3)
        let rows=TonelliLecture.lines(cubic)
        for (i,proof) in cubic.cubicVerifications.enumerated() {
            let square=try XCTUnwrap(rows.first{$0.id == "tonelliCubicVerification_\(i)_square"})
            let cube=try XCTUnwrap(rows.first{$0.id == "tonelliCubicVerification_\(i)"})
            XCTAssertLessThan(rows.firstIndex{$0.id == square.id}!,rows.firstIndex{$0.id == cube.id}!)
            for (line,expectedA,expectedB,expectedResult) in [(square,String(proof.root),String(proof.root),Mod64.multiply(proof.root,proof.root,cubic.p)),(cube,(Natural(proof.root)*Natural(proof.root)).description,String(proof.root),cubic.a)] {
                XCTAssertEqual(line.works.count,1)
                let item=try XCTUnwrap(line.works.first)
                guard case .product(let a,let b,let p)=item.value else { return XCTFail("Expected an auxiliary multiplication") }
                XCTAssertEqual(a,expectedA);XCTAssertEqual(b,expectedB);XCTAssertEqual(p,"163")
                guard case .text(let expression)=line.atoms[item.key] else { return XCTFail("Link must follow the visible product") }
                XCTAssertEqual(expression,a+" · "+b)
                XCTAssertEqual(try DoublingSolver.solve(a:a,b:b,modulus:p).answer,Natural(expectedResult))
            }
        }
        let square=try TonelliShanksSolver.solve(a:"15",p:"17",degree:2)
        for (i,root) in square.roots.enumerated() {
            let line=try XCTUnwrap(TonelliLecture.lines(square).first{$0.id == "tonelliVerification_\(i)"})
            XCTAssertTrue(line.atoms.contains{if case .text("\(root) · \(root)")=$0 {return true};return false})
            XCTAssertFalse(line.works.isEmpty)
        }
    }

    func testAllSmallSquareAndCubeCongruences() throws {
        for p in UInt64(2)...73 where try Prime64.isPrime(p) {
            for n in [2,3] {
                for a in UInt64(0)..<p {
                    let s=try TonelliShanksSolver.solve(a:String(a),p:String(p),degree:n)
                    let expected=try (UInt64(0)..<p).filter { try Mod64.power($0,UInt64(n),p)==a }
                    XCTAssertEqual(s.roots,expected,"a=\(a) p=\(p) n=\(n)")
                    XCTAssertEqual(s.verification.map(\.result),Array(repeating:a,count:expected.count))
                    if n == 2, let initial=s.initial, !s.roots.isEmpty {
                        var value=initial.result, C:UInt64=0, order=s.initialOrder
                        for stage in s.quadraticCorrections {
                            XCTAssertEqual(stage.valueBefore,value)
                            XCTAssertEqual(stage.orderBefore,order)
                            XCTAssertEqual(stage.bExponentBefore,C)
                            XCTAssertEqual(stage.increment,(p-1)/order)
                            XCTAssertEqual(stage.bExponentAfter,C+stage.increment)
                            XCTAssertEqual(stage.valueAfter,Mod64.multiply(value,stage.factor.result,p))
                            XCTAssertEqual(stage.valueAfter,Mod64.multiply(initial.result,stage.totalFactor.result,p))
                            XCTAssertEqual(try Mod64.power(stage.valueAfter,stage.orderAfter,p),1)
                            if stage.orderAfter > 1 { XCTAssertNotEqual(try Mod64.power(stage.valueAfter,stage.orderAfter/2,p),1) }
                            XCTAssertLessThan(stage.orderAfter,order)
                            XCTAssertEqual((order/2) % stage.orderAfter,0)
                            value=stage.valueAfter;C=stage.bExponentAfter;order=stage.orderAfter
                        }
                        XCTAssertEqual(value,1);XCTAssertEqual(C,s.identityBExponent)
                    }
                    for stage in s.descents {
                        XCTAssertEqual(try Mod64.power(stage.value,UInt64(n),p),1)
                        XCTAssertEqual(Mod64.multiply(stage.value,stage.correction.result,p),1)
                        XCTAssertEqual(Mod64.multiply(stage.aPower.result,try Mod64.power(s.nonResidue!,stage.bExponentAfter,p),p),1)
                        if stage.level > 0 {
                            XCTAssertEqual(stage.aPower.exponent % UInt64(n),0)
                            XCTAssertEqual(stage.bExponentAfter % UInt64(n),0)
                        }
                    }
                    if let initial=s.initial,let last=s.orderTests.last {
                        XCTAssertEqual(last.exponent,UInt64(n)*s.k)
                        XCTAssertEqual(last.result,1)
                        XCTAssertNotEqual(try Mod64.power(initial.result,last.exponent/UInt64(n),p),1)
                    }
                }
            }
        }
    }
    func testRootInputsRangeAndCancellation() throws {
        XCTAssertEqual(try TonelliShanksSolver.solve(a:"-150",p:"163",degree:3).roots,[19,20,124])
        XCTAssertEqual(try TonelliShanksSolver.solve(a:"0",p:"2",degree:3).roots,[0])
        XCTAssertEqual(try TonelliShanksSolver.solve(a:"1",p:"3",degree:3).roots,[1])
        XCTAssertEqual(try TonelliShanksSolver.solve(a:"1",p:"18446744073709551557",degree:3).roots,[1])
        XCTAssertEqual(try TonelliShanksSolver.solve(a:"4",p:"18446744073709551557",degree:2).roots,[2,18446744073709551555])
        XCTAssertEqual(try TonelliShanksSolver.solve(a:"8",p:"18446744073709551557",degree:3).roots,[2])
        XCTAssertThrowsError(try TonelliShanksSolver.solve(a:"1",p:"15"))
        XCTAssertThrowsError(try TonelliShanksSolver.solve(a:"1",p:"18446744073709551616"))
        XCTAssertThrowsError(try TonelliShanksSolver.solve(a:"1",p:"7",degree:4))
        XCTAssertThrowsError(try TonelliShanksSolver.solve(a:"13",p:"163",degree:3,check:{throw CancellationError()}))
    }
    func testLectureDescentWithFormalExponentAboveUInt64() throws {
        let s=try TonelliShanksSolver.solve(a:"125",p:"18446744073709550791",degree:3)
        XCTAssertEqual(s.rootMultiplier,2)
        XCTAssertEqual(s.identityBExponent,12297829382473033860)
        XCTAssertEqual((Natural(s.identityBExponent)*Natural(2)).description,"24595658764946067720")
        XCTAssertTrue(s.roots.contains(5))
        XCTAssertEqual(s.verification.map(\.result),[125,125,125])
        XCTAssertTrue(TonelliLecture.lines(s).contains{$0.id == "tonelliExtractPower"})
        XCTAssertEqual(try TonelliShanksSolver.solve(a:"29",p:"109",degree:2).roots,[47,62])
    }

    func testFactorizationAndManualValidation() throws {
        for n: UInt64 in [1,2,4,81,1000,8125,1000000016000000063,UInt64.max] {
            let s=try FactorizationSolver.solve(n)
            XCTAssertEqual(s.factors.reduce(UInt64(1)){$0*$1.value},n)
            XCTAssertTrue(try s.factors.allSatisfy{try Prime64.isPrime($0.prime)})
        }
        XCTAssertEqual(try FactorizationSolver.solve(1000,manual:"2^3 * 5^3").factors,[PrimeFactor(prime:2,exponent:3),PrimeFactor(prime:5,exponent:3)])
        for raw in ["4*250","2^2*5^3","2^3*5^3*","2^65","2^0"] { XCTAssertThrowsError(try FactorizationSolver.solve(1000,manual:raw)) }
        XCTAssertThrowsError(try FactorizationSolver.solve(1000000016000000063,check:{throw CancellationError()}))
    }
    func testLectureOrdersAndAllSmallUnits() throws {
        XCTAssertEqual(try OrderSolver.solve(a:"23",modulus:"1000").order,100)
        XCTAssertEqual(try OrderSolver.solve(a:"37",modulus:"8125").order,1500)
        XCTAssertEqual(try OrderSolver.solve(a:"7",modulus:"23").order,22)
        for m in UInt64(2)...100 {
            for a in UInt64(0)..<m {
                let s=try OrderSolver.solve(a:String(a),modulus:String(m))
                if Mod64.gcd(a,m) != 1 { XCTAssertNil(s.order);continue }
                var power: UInt64 = 1, e: UInt64 = 0
                repeat { power=Mod64.multiply(power,a,m);e+=1 } while power != 1
                XCTAssertEqual(s.order,e,"\(a) mod \(m)")
                XCTAssertEqual(s.lambda % e,0)
            }
        }
    }
    func testOrderLectureNotationAndPhotographedLifts() throws {
        func text(_ line: OrderLectureLine) -> String {
            line.atoms.map { atom in
                switch atom {
                case .rich(let s): s
                case .congruence(let m,let unequal): "\(unequal ? "≢" : "≡")[\(m)]"
                case .fraction(let n,let d): "(\(n))/(\(d))"
                }
            }.joined(separator:" ")
        }
        let a=try OrderSolver.solve(a:"23",modulus:"1000")
        XCTAssertEqual(a.primes.map(\.prime),[2,5])
        XCTAssertEqual(a.primes[1].divisors,[1,2,4])
        XCTAssertEqual(a.primes[1].tests.map(\.exponent),[2])
        XCTAssertEqual(a.primes[1].lifts.map(\.order),[20,100])
        XCTAssertNotNil(a.primes[1].lifts[0].test)
        XCTAssertNil(a.primes[1].lifts[1].test)
        let rows=Dictionary(uniqueKeysWithValues:a.writing.map{($0.id,text($0))})
        XCTAssertTrue(rows["orderPrime_2"]!.contains("[23 ≡[2] 1]"))
        XCTAssertTrue(rows["orderDivisors_5"]!.contains("L(5) = φ(5) = 4; d(4) = {1, 2, 4}"))
        XCTAssertTrue(rows["orderLiftCandidates_25"]!.contains("P_{25}(−2) ∈ {4, 20}"))
        XCTAssertTrue(rows["orderLiftResult_125"]!.contains("5 · 20 = 100"))
        XCTAssertTrue(rows["orderLCM"]!.contains("НОК(P_{8}(23), P_{125}(23)) = НОК(2, 100)"))
        XCTAssertFalse(rows.values.contains{ $0.contains("λ") || $0.contains("(mod") })
        let b=try OrderSolver.solve(a:"37",modulus:"8125")
        XCTAssertEqual(b.localOrders,[500,12])
        XCTAssertEqual(b.primes[1].tests.map(\.exponent),[2,3,4,6])
        let written=b.writing.map(text).joined(separator:"\n")
        XCTAssertTrue(written.contains("11^{2} = 121 ≡[13] 4"))
        XCTAssertTrue(written.contains("12^{2} = 144 ≡[25] −6"))
        XCTAssertTrue(written.contains("P_{625}(37) = 5 · 100 = 500"))
        XCTAssertTrue(written.contains("(6000)/(4) = 1500"))
        let detail=try XCTUnwrap(a.writing.first{$0.id == "orderLiftCandidates_25"}?.detail)
        XCTAssertEqual(detail.title,"Почему {4, 20}?")
        func detailText(_ d: OrderLectureDetail) -> String {
            d.blocks.map { block in
                switch block {
                case .text(let text): text
                case .formula(let atoms): text(OrderLectureLine(id:"detail",atoms:atoms,explanation:""))
                }
            }.joined(separator:"\n")
        }
        XCTAssertTrue(detailText(detail).contains("4 = P_{5}(23) ∣ P_{25}(23)"))
        XCTAssertTrue(detailText(detail).contains("{d ∈ d(20) : 4 ∣ d} = {4, 20}"))
        let growth=try XCTUnwrap(a.writing.first{$0.id == "orderLiftResult_125"}?.detail)
        XCTAssertEqual(growth.title,"Почему умножаем на 5?")
        XCTAssertTrue(detailText(growth).contains("P_{25}(23) = 20 = 5 · 4 = 5P_{5}(23)"))
        XCTAssertEqual(growth.references,["order-growth"])
        XCTAssertTrue(rows["orderLCM"]!.contains("НОД(2, 100)"))
        XCTAssertFalse(rows.values.contains{$0.contains("Д(") && !$0.contains("НОД(")})
        XCTAssertFalse(rows.values.contains{$0.contains("М(")})
        XCTAssertTrue(detailText(detail).contains("d(20) = {1, 2, 4, 5, 10, 20}"))
        XCTAssertFalse(detailText(detail).contains("Д("))
        XCTAssertTrue(text(try XCTUnwrap(try OrderSolver.solve(a:"6",modulus:"15").writing.first{$0.id == "orderGCD"})).contains("НОД(6, 15)"))

        XCTAssertEqual(a.writing.filter{$0.detail != nil}.count,2)
        XCTAssertFalse(a.writing.contains{$0.id.hasPrefix("orderLiftBasis_") || $0.id.hasPrefix("orderGrowthBasis_") || $0.id.hasPrefix("orderLCMGCD_") || $0.id == "orderUnit" || $0.id == "orderSplit"})
        XCTAssertNil(b.writing.first{$0.id == "orderLiftResult_625"}?.detail)
        // A stationary lift can occur before growth starts (Wieferich-type behavior).
        let stationary=try OrderSolver.solve(a:"8",modulus:"243")
        XCTAssertEqual(stationary.primes[0].lifts.map(\.order),[2,6,18,54])
        XCTAssertEqual(stationary.primes[0].lifts.map{$0.test != nil},[true,true,false,false])
        let additional=try XCTUnwrap(stationary.writing.first{$0.id == "orderLiftCandidates_27"}?.detail)
        XCTAssertTrue(detailText(additional).contains("{2, 6, 18}"))
        XCTAssertTrue(detailText(additional).contains("P_{27}(8) ∈ {P_{9}(8), 3P_{9}(8)} = {2, 6}"))
        let ids=Set(CourseLibrary.shared.entries.map(\.id))
        XCTAssertTrue(a.writing.compactMap(\.detail).flatMap(\.references).allSatisfy{ids.contains($0)})
        for sample in [("23","128"),("−37","8125"),("2","1155"),("1","30"),("6","15")] {
            let value=try OrderSolver.solve(a:sample.0,modulus:sample.1)
            XCTAssertEqual(Set(value.writing.map(\.id)).count,value.writing.count)
            if let e=value.order { XCTAssertEqual(try Mod64.power(value.a,e,value.modulus),1) }
        }
        XCTAssertThrowsError(try OrderSolver.solve(a:"23",modulus:"1000",check:{throw CancellationError()}))
    }
    func testPolynomialInverseExamplesAndInvariants() throws {
        let sample=try PolynomialInverseSolver.solve(a:"1,0,4,2",m:"1,0,2,0,3",p:"7")
        XCTAssertEqual(sample.inverse?.vector(),"(5, 5, 2, 1)")
        let short=try PolynomialInverseSolver.solve(a:"1,2",m:"1,0,1",p:"3")
        XCTAssertEqual(short.inverse?.vector(),"(1, 1)")
        for method in PolynomialInverseMethod.allCases {
            for p:UInt64 in [2,3,5] {
                let f=PolynomialField(p:Natural(p),nativePrime:p)
                for constant in UInt64(0)..<p {
                    let m=Polynomial([Natural(constant),.zero,.one])
                    for a0 in UInt64(0)..<p {
                        for a1 in UInt64(0)..<p {
                            let s=try PolynomialInverseSolver.solve(a:"\(a1),\(a0)",m:"1,0,\(constant)",p:String(p),method:method)
                            let gcd=try f.gcd(s.a,m).result
                            XCTAssertEqual(s.gcd,gcd)
                            XCTAssertEqual(s.inverse != nil,gcd == .init([.one]))
                            for frame in s.frames {
                                for row in frame.rows {
                                    let product=try PolynomialSolver.convolution(row.coefficient,s.a,p:Natural(p),check:{})
                                    XCTAssertEqual(try f.divide(product,by:m).remainder,try f.divide(row.value,by:m).remainder)
                                }
                            }
                            if let v=s.verification { XCTAssertEqual(v.remainder,.init([.one])) }
                        }
                    }
                }
            }
        }
        XCTAssertThrowsError(try PolynomialInverseSolver.solve(a:"1",m:"1,1",p:"4"))
        XCTAssertThrowsError(try PolynomialInverseSolver.solve(a:"1",m:"1",p:"3"))
    }
}
