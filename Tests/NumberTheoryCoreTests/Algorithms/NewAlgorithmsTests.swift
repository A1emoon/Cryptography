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
            XCTAssertTrue(lines.contains{$0.id == "tonelliB"})
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

    func testAllSmallSquareAndCubeCongruences() throws {
        for p in UInt64(2)...73 where try Prime64.isPrime(p) {
            for n in [2,3] {
                for a in UInt64(0)..<p {
                    let s=try TonelliShanksSolver.solve(a:String(a),p:String(p),degree:n)
                    let expected=try (UInt64(0)..<p).filter { try Mod64.power($0,UInt64(n),p)==a }
                    XCTAssertEqual(s.roots,expected,"a=\(a) p=\(p) n=\(n)")
                    XCTAssertEqual(s.verification.map(\.result),Array(repeating:a,count:expected.count))
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
