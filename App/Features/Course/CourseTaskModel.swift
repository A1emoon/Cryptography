import SwiftUI

enum CourseTask: String, CaseIterable, Sendable, Identifiable {
    case inverse, order, tonelli, doubling, division, modularDivision, polynomial
    var id: String { rawValue }
    var title: String {
        switch self {
        case .inverse: "Обращение по модулю"
        case .order: "Мультипликативный порядок"
        case .tonelli: "Тонелли–Шенкс"
        case .doubling: "Удвоение–сложение"
        case .division: "Двоичное деление уголком"
        case .modularDivision: "Деление по модулю"
        case .polynomial: "Многочлены: удвоение–сложение"
        }
    }
    var formula: String {
        switch self {
        case .inverse: "a⁻¹ mod m; A(α)⁻¹ mod (M(α), p)"
        case .order: "Pₘ(a) = min{t ≥ 1 : aᵗ ≡ 1}"
        case .tonelli: "x² ≡ a или x³ ≡ a (mod p)"
        case .doubling: "r = (a · b) mod m"
        case .division: "a = b · q + r"
        case .modularDivision: "x = (u / v) mod m"
        case .polynomial: "R = A(α)B(α) mod (M(α), p)"
        }
    }
    var subtitle: String {
        switch self {
        case .inverse: "Числа и многочлены · нечётный модуль по умолчанию"
        case .order: "Составной модуль · разложение и НОК"
        case .tonelli: "Квадратные и кубические корни по простому модулю"
        case .doubling: "Двоичные цифры и вычисления в таблице"
        case .division: "Частное как сумма степеней двойки"
        case .modularDivision: "Через обратное или третью строку"
        case .polynomial: "Векторы, сдвиги и остатки"
        }
    }
    var example: String {
        switch self {
        case .inverse: "129⁻¹ mod 257 = 2"
        case .order: "P₁₀₀₀(23) = 100"
        case .tonelli: "x³ ≡ 13 (mod 163) → 19, 20, 124"
        case .doubling: "(78 · 96) mod 273 = 117"
        case .division: "1530 = 41 · 37 + 13"
        case .modularDivision: "(153 / 179) mod 283 = 72"
        case .polynomial: "mod (α⁴ + 2α + 2, 5) → 3α³ + α²"
        }
    }
    var symbol: String {
        switch self {
        case .inverse: "arrow.triangle.2.circlepath"
        case .order: "repeat"
        case .tonelli: "x.squareroot"
        case .doubling: "multiply"
        case .division: "divide"
        case .modularDivision: "divide.circle"
        case .polynomial: "function"
        }
    }
    var referenceIDs: [String] {
        switch self {
        case .inverse: ["inverse-exists","binary-invariant","polynomial-binary","polynomial-inverse-exists","inverse-lift"]
        case .order: ["order-divisibility","order-test","order-prime-power","order-growth","order-crt"]
        case .tonelli: ["residue-criterion","power-coprime","tonelli","unity-roots"]
        case .doubling: ["doubling-correct","doubling-count"]
        case .division: ["binary-division-step","euclidean-division"]
        case .modularDivision: ["inverse-exists","binary-invariant"]
        case .polynomial: ["polynomial-horner","polynomial-division"]
        }
    }
    var initial: CourseInputs {
        var i=CourseInputs()
        switch self {
        case .inverse: i.a="129";i.m="257"
        case .order: i.a="23";i.m="1000"
        case .tonelli: i.a="13";i.p="163";i.degree=3
        case .doubling: i.a="78";i.b="96";i.m="273"
        case .division: i.a="1530";i.b="41"
        case .modularDivision: i.a="179";i.u="153";i.m="283"
        case .polynomial: i.a="1,2,1";i.b="2,0,1,3";i.m="1,0,0,2,2";i.p="5"
        }
        return i
    }
    func solve(_ i: CourseInputs, check: () throws -> Void) throws -> CourseResult {
        switch self {
        case .doubling: return .doubling(try DoublingSolver.solve(a:i.a,b:i.b,modulus:i.m,checkCancellation:check))
        case .division: return .division(try BinaryDivisionSolver.solve(a:i.a,b:i.b,checkCancellation:check))
        case .inverse:
            if i.polynomials { return .polynomialInverse(try PolynomialInverseSolver.solve(a:i.polyA,m:i.polyM,p:i.p,method:i.polyMethod,check:check)) }
            return .modular(try ModularSolver.solve(a:i.a,modulus:i.m,method:i.method,check:check))
        case .modularDivision: return .modular(try ModularSolver.solve(a:i.a,modulus:i.m,numerator:i.u,method:i.method,check:check))
        case .polynomial: return .polynomial(try PolynomialSolver.solve(a:i.a,b:i.b,m:i.m,p:i.p,check:check))
        case .order: return .order(try OrderSolver.solve(a:i.a,modulus:i.m,factors:i.factors,check:check))
        case .tonelli: return .tonelli(try TonelliShanksSolver.solve(a:i.a,p:i.p,degree:i.degree,check:check))
        }
    }
}
struct CourseInputs: Sendable {
    var a="", b="", m="", p="7", u=""
    var polyA="1,0,4,2",polyM="1,0,2,0,3"
    var polynomials=false, degree=3, factors=""
    var method=ModularMethod.automatic
    var polyMethod=PolynomialInverseMethod.binary
}
enum CourseResult: Sendable {
    case doubling(DoublingSolution),division(BinaryDivisionSolution),modular(ModularSolution),polynomial(PolynomialSolution)
    case polynomialInverse(PolynomialInverseSolution),order(OrderSolution),tonelli(TonelliSolution)
    var answer: String {
        switch self {
        case .doubling(let s): s.answer.description
        case .division(let s): s.identity
        case .modular(let s): s.result?.description ?? "Не определено"
        case .polynomial(let s): s.result.formula
        case .polynomialInverse(let s): s.inverse?.formula ?? "Обратного нет"
        case .order(let s): s.order.map(String.init) ?? "Порядка нет"
        case .tonelli(let s): s.roots.isEmpty ? "Решений нет" : s.roots.map(String.init).joined(separator:", ")
        }
    }
}
@MainActor final class CourseTaskModel: ObservableObject {
    let kind: CourseTask
    @Published private(set) var inputs: CourseInputs
    @Published private(set) var result: CourseResult?
    @Published private(set) var error: String?
    @Published private(set) var calculating=false
    @Published private(set) var generation=UUID()
    private var worker: Task<CourseResult,Error>?
    init(_ kind: CourseTask, inputs: CourseInputs? = nil) { self.kind=kind;self.inputs=inputs ?? kind.initial }
    func solve(_ inputs: CourseInputs? = nil) {
        cancel();if let inputs {self.inputs=inputs};result=nil;error=nil;calculating=true
        let id=generation,i=self.inputs,kind=self.kind
        let task=Task.detached(priority:.userInitiated) {try kind.solve(i,check:{try Task.checkCancellation()})}
        worker=task
        Task { [weak self] in
            do {let value=try await task.value;guard let self,self.generation==id else{return};self.result=value;self.calculating=false;self.worker=nil}
            catch {guard let self,self.generation==id else{return};if !(error is CancellationError){self.error=error.localizedDescription};self.calculating=false;self.worker=nil}
        }
    }
    func cancel(){worker?.cancel();worker=nil;generation=UUID();calculating=false}
}


/// One set of lecture examples for the phone and watch input panels.
struct TonelliLectureExample: Identifiable {
    let a: String
    let p: String
    let degree: Int
    var id: String { "\(degree)_\(a)_\(p)" }
    var title: String { "x\(degree == 2 ? "²" : "³") ≡ \(a) (mod \(p))" }
    var inputs: CourseInputs {
        var value = CourseTask.tonelli.initial
        value.a = a; value.p = p; value.degree = degree
        return value
    }
    static let all = [
        Self(a:"15",p:"17",degree:2), Self(a:"5",p:"41",degree:2), Self(a:"6",p:"97",degree:2),
        Self(a:"3",p:"73",degree:3), Self(a:"13",p:"163",degree:3),
        Self(a:"17",p:"163",degree:3), Self(a:"267",p:"487",degree:3), Self(a:"26",p:"487",degree:3)
    ]
}
