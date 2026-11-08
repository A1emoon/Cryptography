import XCTest
@testable import NumberTheoryCore

final class NewAlgorithmsTests: XCTestCase {
    func testLectureCubicCorrectionsAndAllRoots() throws {
        let s = try TonelliShanksSolver.solve(a: "13", p: "163", degree: 3)
        XCTAssertEqual(s.roots, [19,20,124]); XCTAssertEqual(s.s,4); XCTAssertEqual(s.r,2)
        XCTAssertEqual(s.nonResidue,2); XCTAssertEqual(s.epsilon,104); XCTAssertEqual(s.c,20)
        XCTAssertEqual(s.corrections.map(\.before),[6,58])
        XCTAssertEqual(s.corrections.map(\.after),[58,1])
        XCTAssertEqual(s.corrections.map(\.choice),[1,1])
        XCTAssertEqual(s.corrections.map(\.factor.exponent),[6,54])
        XCTAssertEqual(s.seedRoot,124)
        XCTAssertEqual(try TonelliShanksSolver.solve(a:"15",p:"17").roots,[7,10])
        XCTAssertEqual(try TonelliShanksSolver.solve(a:"2",p:"41").roots,[17,24])
        XCTAssertEqual(try TonelliShanksSolver.solve(a:"13",p:"29").roots,[10,19])
    }
    func testAllSmallSquareAndCubeCongruences() throws {
        for p in UInt64(2)...73 where try Prime64.isPrime(p) {
            for n in [2,3] {
                for a in UInt64(0)..<p {
                    let s=try TonelliShanksSolver.solve(a:String(a),p:String(p),degree:n)
                    let expected=try (UInt64(0)..<p).filter { try Mod64.power($0,UInt64(n),p)==a }
                    XCTAssertEqual(s.roots,expected,"a=\(a) p=\(p) n=\(n)")
                    XCTAssertEqual(s.verification.map(\.result),Array(repeating:a,count:expected.count))
                    for c in s.corrections {
                        XCTAssertTrue(c.cAfter > c.cBefore)
                        XCTAssertEqual(c.after,Mod64.multiply(c.before,c.factor.result,p))
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
