import SwiftUI

struct StudyReason {
    let title:String
    let text:String
    var equations:[String]=[]
    var references:[String]=[]
}
struct StudyReasonView: View {
    let reason:StudyReason
    var body:some View {
        StudentDetailSheet(title:reason.title,large:true){
            MathExplainedText(text:reason.text)
            ForEach(reason.equations.indices,id:\.self){StudentFormulaView(atoms:[.rich(reason.equations[$0])])}
            ReferenceLinks(ids:reason.references,prefix:"stepReference_")
        }
    }
}
indirect enum StudyWork {
    case power(RecordedPower)
    case symbol(LegendreTrace)
    case notation(String, [String])
    case product(String,String,String)
    case conversion(BinaryConversion)
    case factorization(FactorizationTrace)
    case equations(String,[String])
    case polynomialProduct(String,String,String,String)
    case polynomialDivision(FieldDivision,Natural)
}
private enum StudyWindow:Identifiable {
    case reason,work(StudyWork)
    var id:String {switch self{case .reason:"reason";case .work:"work"}}
}
struct StudyLine:View {
    let id:String
    let atoms:[StudentMathAtom]
    let reason:StudyReason
    var works:[Int:StudyWork]=[:]
    var singleRow = false
    @State private var window:StudyWindow?
    var body:some View {
        StudentMathLine(atoms:atoms,workIndices:Set(works.keys),identifier:id,onWork:{if let w=works[$0]{window = .work(w)}},onReason:{window = .reason},singleRow:singleRow)
            .sheet(item:$window){switch $0{case .reason:StudyReasonView(reason:reason);case .work(let work):StudyWorkView(work:work)}}
    }
}
struct StudyAnnotated<Content:View>:View {
    let id:String
    let reason:StudyReason
    @ViewBuilder let content:()->Content
    @State private var show=false
    var body:some View {
        HStack(alignment:.top,spacing:7){
            content().frame(maxWidth:.infinity,alignment:.leading)
            Button{show=true}label:{Image(systemName:"questionmark.circle").font(.system(size:15)).frame(width:32,height:38)}
                .buttonStyle(.plain).foregroundStyle(AppStyle.accent).accessibilityLabel("Пояснить эту запись").accessibilityIdentifier(id+"_reason")
        }.accessibilityElement(children:.contain).accessibilityIdentifier(id)
            .sheet(isPresented:$show){StudyReasonView(reason:reason)}
    }
}
struct StudyWorkView:View {
    let work:StudyWork
    private var title:String {
        switch work{
        case .power:"Вспомогательное вычисление степени"
        case .symbol:"Вычисление символа"
        case .notation(let title,_):title
        case .product:"Удвоение–сложение"
        case .conversion:"Перевод в двоичную систему"
        case .factorization:"Разложение модуля"
        case .equations(let title,_):title
        case .polynomialProduct:"Удвоение–сложение для многочленов"
        case .polynomialDivision:"Деление многочленов уголком"
        }
    }
    var body:some View {
        StudentDetailSheet(title:title,large:true){
            switch work{
            case .power(let p):StudyPowerCalculation(power:p)
            case .symbol(let s):LegendreTraceView(trace:s)
            case .notation(_,let equations):
                ForEach(equations.indices,id:\.self) { i in StudentFormulaView(atoms:[.rich(equations[i])]) }
            case .product(let a,let b,let m):StudyIntegerProduct(a:a,b:b,m:m)
            case .conversion(let c):NotebookBinaryConversion(conversion:c)
            case .factorization(let f):
                MathLine("\(f.number) = \(f.expression)")
                ForEach(f.divisions.indices,id:\.self){MathLine(f.divisions[$0])}
                MathExplainedText(text:"Каждый найденный множитель проверен на простоту; их произведение в точности равно исходному модулю. Для больших составных чисел используется отменяемое разложение Полларда; деления выше проверяют готовое разложение независимо от способа его поиска.")
            case .equations(_,let equations):ForEach(equations.indices,id:\.self){MathLine(equations[$0])}
            case .polynomialProduct(let a,let b,let m,let p):StudyPolynomialProduct(a:a,b:b,m:m,p:p)
            case .polynomialDivision(let d,let p):RabinLongDivisionView(division:d,q:p)
            }
        }
    }
}
private struct PowerWorkStep:Identifiable {
    let id:Int
    let exponent:UInt64
    let a:UInt64
    let b:UInt64
    let result:UInt64
}
private struct StudyPowerCalculation:View {
    let power:RecordedPower
    @State private var conversion:BinaryConversion?
    @State private var steps:[PowerWorkStep]=[]
    @State private var error:String?
    var body:some View {
        VStack(alignment:.leading,spacing:14){
            MathLine("\(power.expression) mod \(power.modulus)")
            if let conversion{NotebookBinaryConversion(conversion:conversion)}
            if let error{Text(error).foregroundStyle(.red)}
            if power.exponent==0{MathLine("a⁰ ≡ 1 (mod \(power.modulus))")}
            ForEach(steps){s in
                StudyLine(id:"powerProduct_\(s.id)",atoms:[.power(String(power.base),String(s.exponent)),.text("≡"),.text("\(s.a) · \(s.b)"),.text("≡"),.text("\(s.result) (mod \(power.modulus))")],reason:StudyReason(title:"Бинарная цепочка",text:"Для чётного показателя возводим найденную половинную степень в квадрат. Для нечётного — после квадрата умножаем ещё на основание. Каждое произведение по ↗ раскрывается таблицей удвоения–сложения.",references:["doubling-correct"]),works:[2:.product(String(s.a),String(s.b),String(power.modulus))])
            }
            MathLine("\(power.expression) ≡ \(power.result) (mod \(power.modulus))")
                .accessibilityElement(children:.ignore).accessibilityIdentifier("powerResult").accessibilityLabel(String(power.result))
        }.task {
            do {
                conversion=try BinaryConversion(number:Natural(power.exponent))
                var result:[PowerWorkStep]=[]
                func calculate(_ e:UInt64)throws->UInt64{
                    try Task.checkCancellation()
                    if e==0{return 1 % power.modulus};if e==1{return power.base % power.modulus}
                    let h=try calculate(e/2),square=Mod64.multiply(h,h,power.modulus)
                    result.append(PowerWorkStep(id:result.count,exponent:(e/2)*2,a:h,b:h,result:square))
                    if e&1==0{return square}
                    let next=Mod64.multiply(square,power.base % power.modulus,power.modulus)
                    result.append(PowerWorkStep(id:result.count,exponent:e,a:square,b:power.base % power.modulus,result:next));return next
                }
                guard try calculate(power.exponent)==power.result else{throw NumberTheoryError.invariant};steps=result
            }catch{self.error=error.localizedDescription}
        }
    }
}
private struct StudyIntegerProduct:View {
    let a:String,b:String,m:String
    @State private var solution:DoublingSolution?
    @State private var error:String?
    var body:some View {
        VStack(alignment:.leading,spacing:18){
            if let s=solution{
                MathLine(s.expression)
                NotebookBinaryConversion(conversion:s.conversionA)
                if s.a.magnitude != s.b.magnitude{NotebookBinaryConversion(conversion:s.conversionB)}
                MathExplainedText(text:s.selectionExplanation)
                if let t=s.preparation{NotebookIntegerTable(table:t)}
                if let t=s.table{NotebookIntegerTable(table:t)}
                if let c=s.signCorrection{MathLine(c.expression)}
                MathLine("\(s.expression) = \(s.answer)").accessibilityElement(children:.ignore).accessibilityIdentifier("productResult").accessibilityLabel(s.answer.description)
            }else if let error{Text(error).foregroundStyle(.red)}else{ProgressView("Вычисляем…")}
        }.task {
            let task=Task.detached{try DoublingSolver.solve(a:a,b:b,modulus:m,checkCancellation:{try Task.checkCancellation()})}
            do{solution=try await withTaskCancellationHandler(operation:{try await task.value},onCancel:{task.cancel()})}catch{if !(error is CancellationError){self.error=error.localizedDescription}}
        }
    }
}
private struct StudyPolynomialProduct:View {
    let a:String,b:String,m:String,p:String
    @State private var solution:PolynomialSolution?
    @State private var error:String?
    var body:some View {
        VStack(alignment:.leading,spacing:18){
            if let solution{NotebookPolynomialView(solution:solution)}
            else if let error{Text(error).foregroundStyle(.red)}else{ProgressView("Вычисляем…")}
        }.task {
            let task=Task.detached{try PolynomialSolver.solve(a:a,b:b,m:m,p:p,check:{try Task.checkCancellation()})}
            do{solution=try await withTaskCancellationHandler(operation:{try await task.value},onCancel:{task.cancel()})}catch{if !(error is CancellationError){self.error=error.localizedDescription}}
        }
    }
}
