import SwiftUI

struct CourseSolutionView:View {
    let result:CourseResult
    var body:some View {
        switch result {
        case .doubling(let s):CourseDoublingSolution(s:s)
        case .division(let s):CourseDivisionSolution(s:s)
        case .modular(let s):CourseModularSolution(s:s)
        case .polynomial(let s):CoursePolynomialSolution(s:s)
        case .polynomialInverse(let s):CoursePolynomialInverseSolution(s:s)
        case .order(let s):CourseOrderSolution(s:s)
        case .tonelli(let s):CourseTonelliSolution(s:s)
        }
    }
}
private struct CourseDoublingSolution:View {
    let s:DoublingSolution
    var body:some View {
        StudyLine(id:"doublingCondition",atoms:[.text(s.expression)],reason:StudyReason(title:"Условие",text:"Вычисляем остаток произведения a и b по положительному модулю m. Знаки обрабатываем после вычисления произведения модулей чисел.",references:["doubling-correct"]))
        StudyAnnotated(id:"conversionA",reason:StudyReason(title:"Двоичные цифры",text:"Делим на два со сдвигом вправо. Под каждым числом записываем его младший бит; читаем биты справа налево.",references:["binary"])) {NotebookBinaryConversion(conversion:s.conversionA)}
        StudyAnnotated(id:"conversionB",reason:StudyReason(title:"Выбор множителя",text:s.selectionExplanation,references:["doubling-count"])) {NotebookBinaryConversion(conversion:s.conversionB)}
        StudyLine(id:"doublingSelection",atoms:[.text("w₂(\(s.a.magnitude)) = \(s.conversionA.ones),"),.text("w₂(\(s.b.magnitude)) = \(s.conversionB.ones)"),.text("⇒"),.text("A = \(s.selectedConversion.number), B = \(s.originalAddend)")],reason:StudyReason(title:"Меньше ненулевых сложений",text:s.selectionExplanation,references:["doubling-count"]))
        if let table=s.preparation {StudyLine(id:"doublingPreparation",atoms:[.text("B = \(s.originalAddend) ≡ \(table.answer) (mod \(s.modulus))")],reason:StudyReason(title:"Подготовка слагаемого",text:"Базовое слагаемое приводим по модулю до основной таблицы. Само нахождение остатка выполняем в другом месте; ↗ раскрывает удвоение–сложение с единицей.",references:["doubling-correct"]),works:[0:.product(s.originalAddend.description,"1",s.modulus.description)])}
        if let table=s.table {StudyAnnotated(id:"doublingTable",reason:StudyReason(title:"Таблица удвоения–сложения",text:"Верхняя строка: B либо 0 согласно битам выбранного множителя, от старшего к младшему. Нижняя строка: удвоить предыдущий остаток, привести, прибавить верхнюю ячейку, привести. В первом столбце сверху пусто, снизу 2. Все вычитания и сложения записаны в ячейках.",references:["doubling-correct"])) {NotebookIntegerTable(table:table)}}
        if let correction=s.signCorrection {StudyLine(id:"doublingSign",atoms:[.text(correction.expression)],reason:StudyReason(title:"Знак произведения",text:"Отрицательный результат приводим к представителю от 0 до m−1. Нулевой остаток остаётся нулём.",references:["remainder"]))}
    }
}
private struct CourseDivisionSolution:View {
    let s:BinaryDivisionSolution
    private func sum(_ i:Int)->String{s.steps.prefix(i+1).map{PowerNotation.two($0.chosen.id)}.joined(separator:" + ")}
    var body:some View {
        StudyLine(id:"divisionCondition",atoms:[.text("\(s.a) = \(s.b) · q + r,"),.text("0 ≤ r < \(s.b.magnitude)")],reason:StudyReason(title:"Деление с остатком",text:"a — делимое, b — ненулевой делитель, q — целое частное, r — неотрицательный остаток. Сначала делим модули чисел; затем корректируем знаки.",references:["euclidean-division"]))
        if !s.dividendLength.number.isZero {
            StudyLine(id:"divisionLengths",atoms:[.text("l₂(\(s.dividendLength.number)) = \(s.dividendLength.length),"),.text("l₂(\(s.divisorLength.number)) = \(s.divisorLength.length)")],reason:StudyReason(title:"Двоичные длины",text:"Для положительного N длина l₂(N) определяется неравенствами 2^(l₂(N)−1) ≤ N < 2^l₂(N). Разность длин даёт два возможных сдвига: l и l−1.",equations:["\(PowerNotation.two(s.dividendLength.length-1)) ≤ \(s.dividendLength.number) < \(PowerNotation.two(s.dividendLength.length))","\(PowerNotation.two(s.divisorLength.length-1)) ≤ \(s.divisorLength.number) < \(PowerNotation.two(s.divisorLength.length))"],references:["binary-length","binary-division-step"]))
            if let first=s.steps.first {
                StudyLine(id:"divisionDifference",atoms:[.text("l = \(first.before.length) − \(s.divisorLength.length) = \(first.lengthDifference)"),.text(first.lengthDifference>0 ? "; l−1 = \(first.lengthDifference-1)":"")],reason:StudyReason(title:"Выбор сдвига",text:"Берём l — разность двоичных длин. Если делитель, сдвинутый на l битов, не помещается в остаток, используем l−1.",references:["binary-division-step"]))
                StudyAnnotated(id:"divisionShifts",reason:StudyReason(title:"Сдвиги влево",text:"Каждая стрелка << сдвигает делитель влево на один бит. Над стрелкой — накопленный сдвиг. Останавливаемся на последнем числе, не превосходящем делимое.",references:["binary-division-step"])) {
                    ScrollView(.horizontal){HStack(spacing:9){ForEach(s.shifts.filter{$0.multiple<=s.a.magnitude}){shift in
                        if shift.id>0 {VStack(spacing:1){Text(String(shift.id)).font(.caption2);Text("<<").font(.caption);MathText(text:"→")}}
                        MathText(text:shift.multiple.description)
                    }}.fixedSize().padding(.vertical,8)}
                }
                StudyLine(id:"divisionStart",atoms:[.floorFraction(s.a.magnitude.description,s.b.magnitude.description)],reason:StudyReason(title:"Целая часть",text:"Квадратные скобки обозначают целую часть частного. Вычитаем подходящую степень двойки, умноженную на делитель; ту же степень добавляем к частному.",references:["binary-division-step"]))
                ForEach(s.steps){step in
                    StudyLine(id:"divisionStep_\(step.id)",atoms:[.text("="),.floorFraction("\(step.before.number) − \(PowerNotation.two(step.chosen.id)) · \(s.b.magnitude)",s.b.magnitude.description),.text("+ \(sum(step.id))"),.text("="),.floorFraction(step.after.description,s.b.magnitude.description),.text("+ \(sum(step.id))")],reason:StudyReason(title:"Вычитание сдвинутого делителя",text:"Для текущего остатка разность длин l = \(step.before.length)−\(s.divisorLength.length) = \(step.lengthDifference). Выбран сдвиг \(step.chosen.id). После вычитания остаётся \(step.after). Когда остаток меньше делителя, целая часть оставшейся дроби равна 0.",references:["binary-division-step"]))
                }
            }
            if let last=s.steps.last {
                StudyLine(id:"divisionQuotient",atoms:[.text("= 0 + \(sum(last.id))"),.text("="),.text(s.magnitudeQuotient.description)],reason:StudyReason(title:"Завершение деления",text:"Остаток меньше делителя, поэтому целая часть последней дроби равна нулю. Складываем выбранные степени двойки и получаем частное для модулей входных чисел.",references:["binary-division-step"]))
            }
            if s.needsRemainderCorrection {StudyLine(id:"divisionSign",atoms:[.text("r = \(s.b.magnitude) − \(s.magnitudeRemainder) = \(s.remainder);"),.text("q = \(s.quotient)")],reason:StudyReason(title:"Отрицательное делимое",text:"Евклидов остаток должен быть неотрицательным. При отрицательном делимом и ненулевом остатке меняем r на |b|−r и увеличиваем модуль частного на 1; знак частного определяется знаками a и b.",references:["euclidean-division"]))}
        }
    }
}
private struct CourseModularSolution:View {
    let s:ModularSolution
    var body:some View {
        StudyLine(id:"modularCondition",atoms:s.isDivision ? [.text("\(s.input) · x ≡ \(s.numerator!) (mod \(s.modulus))")] : [.text("\(s.input) · x ≡ 1 (mod \(s.modulus))")],reason:StudyReason(title:s.isDivision ? "Деление по модулю":"Обращение по модулю",text:s.isDivision ? "Ищем x для знаменателя v, числителя u и модуля m: vx ≡ u. Если знаменатель обратим, решение единственно по m. Прямой метод собирает числитель в третьей строке.":"Ищем обратный элемент к a по m. Он существует ровно при НОД(a,m)=1.",references:["inverse-exists"]))
        if s.input != DecimalInteger(s.a) {StudyLine(id:"modularReduce",atoms:[.text("\(s.input) ≡ \(s.a) (mod \(s.modulus))")],reason:StudyReason(title:"Представитель остатка",text:"Заменяем исходное число равным ему по модулю представителем. Само нахождение остатка раскрывается отдельно.",references:["congruence"]),works:[0:.product(s.input.description,"1",s.modulus.description)])}
        if let n=s.numerator,n != DecimalInteger(s.target) {MathLine("\(n) ≡ \(s.target) (mod \(s.modulus))")}
        if s.result == nil {
            StudyLine(id:"modularNoInverse",atoms:[.text("НОД(\(s.a), \(s.modulus)) = \(s.gcdTrace.gcd) ≠ 1")],reason:StudyReason(title:"Обратного нет",text:s.conclusion.joined(separator:"\n"),equations:s.gcdTrace.lines,references:["inverse-exists"]))
        }else{
            #if os(watchOS)
            HStack(alignment: .center, spacing: 10) {
                ForEach(s.frames) { f in
                    StudyAnnotated(id: "modularFrame_\(f.id)", reason: StudyReason(title: "Преобразование строк", text: f.explanation, equations: f.arithmetic, references: ["binary-invariant"])) {
                        HStack(spacing: 10) {
                            if f.action != .initial {
                                VStack(spacing: 2) {
                                    if f.action == .adjust && !s.usesExactRows { MathText(text: s.modulus.description) }
                                    else { TransformationLabel(operation: f.operation).fixedSize().frame(minHeight: 54) }
                                    MathText(text: f.action == .adjust && !s.usesExactRows ? "≡" : "∼")
                                }
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                NotebookMatrix(rows: s.method == .powerMatrix && f.action != .initial ? Array(f.rows.prefix(1)) : f.rows, powers: s.method == .powerMatrix)
                                if let remaining = f.remaining { MathText(text: "≤ \(remaining)").padding(.vertical, 4) }
                            }
                        }.fixedSize().padding(.vertical, 10)
                    }.fixedSize()
                }
            }.courseMathRow().accessibilityIdentifier("modularMatrixChain")
            #else
            ForEach(s.frames){f in
                StudyAnnotated(id:"modularFrame_\(f.id)",reason:StudyReason(title:"Преобразование строк",text:f.explanation,equations:f.arithmetic,references:["binary-invariant"])) {
                    ScrollView(.horizontal){
                        HStack(alignment:.center,spacing:10){
                            if f.action != .initial {
                                VStack(spacing:2){
                                    if f.action == .adjust && !s.usesExactRows {MathText(text:s.modulus.description)}
                                    else{TransformationLabel(operation:f.operation).frame(width:110,height:54)}
                                    MathText(text:f.action == .adjust && !s.usesExactRows ? "≡":"∼")
                                }.frame(width:110)
                            }
                            VStack(alignment:.leading,spacing:5){
                                NotebookMatrix(rows:s.method == .powerMatrix && f.action != .initial ? Array(f.rows.prefix(1)):f.rows,powers:s.method == .powerMatrix)
                                if let remaining=f.remaining{MathText(text:"≤ \(remaining)").padding(.vertical,4)}
                            }
                        }.fixedSize().padding(.vertical,10)
                    }
                }
            }
            #endif
            ForEach(s.lifts){l in
                StudyLine(id:"modularLift_\(l.id)",atoms:[.text("\(s.a) · \(l.previous) ≡ \(l.residue) (mod \(l.modulus))"),.text("⇒"),.text("\(s.a)⁻¹ ≡ \(l.previous) + \(l.addition) ≡ \(l.result) (mod \(l.modulus))")],reason:StudyReason(title:"Подъём обратного",text:"Увеличиваем степень двойки в модуле. При необходимости прибавляем половину нового модуля к предыдущему обратному; это исправляет ровно старший бит остатка.",equations:l.verification,references:["inverse-lift"]),works:[0:.product(s.a.description,l.previous.description,l.modulus.description)])
            }
            if let inverse=s.inverse {StudyLine(id:"modularInverse",atoms:[.text("\(s.a)⁻¹ ≡ \(inverse) (mod \(s.modulus))")],reason:StudyReason(title:"Коэффициент при a",text:"В строке с единицей левый коэффициент при a и есть обратный элемент. Отрицательный коэффициент приводим по модулю.",references:["binary-invariant"]))}
            if s.multiplication != nil,let inverse=s.inverse,let result=s.result {
                StudyLine(id:"modularProduct",atoms:[.text("x ≡"),.text("\(s.target) · \(inverse)"),.text("≡"),.text("\(result) (mod \(s.modulus))")],reason:StudyReason(title:"Умножение на обратный",text:"Умножаем числитель на обратный знаменатель. Подробная таблица открывается по ↗.",references:["inverse-exists"]),works:[1:.product(s.target.description,inverse.description,s.modulus.description)])
            }
        }
    }
}
private struct CoursePolynomialSolution:View {
    let s:PolynomialSolution
    var body:some View {
        StudyLine(id:"polynomialCondition",atoms:[.text("R(α) ≡ A(α) · B(α)"),.text("(mod (M(α), \(s.p)))")],reason:StudyReason(title:"Произведение многочленов",text:"A и B — множители; M — многочлен-модуль со старшим коэффициентом 1; p — модуль коэффициентов. Векторы записаны от старшего коэффициента к свободному члену.",references:["polynomial","polynomial-modulus","polynomial-horner"]))
        ForEach([s.a,s.b,s.m],id:\.name){input in
            StudyLine(id:"polynomialInput_\(input.name)",atoms:[.text("\(input.name) = \(input.polynomial.formula)"),.text("="),.text(input.polynomial.vector())],reason:StudyReason(title:"Коэффициенты многочлена",text:"Коэффициенты приводим по p. Нули сохраняют пропущенные степени.",equations:input.reductions,references:["coefficient"]))
        }
        StudyLine(id:"polynomialSelection",atoms:[.text("w(A) = \(s.a.polynomial.weight), w(B) = \(s.b.polynomial.weight)"),.text("⇒"),.text("\(s.multiplierName) · \(s.baseName)")],reason:StudyReason(title:"Выбор множителя",text:s.selection,references:["horner"]))
        if !s.preparation.isEmpty {StudyLine(id:"polynomialPrepare",atoms:[.text("\(s.baseName) ≡ \(s.base.vector()) (mod M, \(s.p))")],reason:StudyReason(title:"Приведение базового многочлена",text:"Вычитаем подходящие сдвиги M, пока степень не станет меньше deg M. Согласуем старший коэффициент; коэффициенты считаем по p.",references:["polynomial-division"]),works:[0:.equations("Приведение многочлена",s.preparation.flatMap{[$0.rawVector,$0.reducedVector]})])}
        StudyAnnotated(id:"polynomialTable",reason:StudyReason(title:"Схема Горнера",text:"В верхней строке aᵢB. Снизу умножаем предыдущий остаток на α, приводим по M, складываем с верхней ячейкой и снова приводим. Умножение на α — сдвиг вектора с добавлением нуля справа. Коэффициенты считаем по p.",references:["polynomial-horner"])) {NotebookPolynomialTable(solution:s)}
    }
}
private struct CoursePolynomialInverseSolution:View {
    let s:PolynomialInverseSolution
    var body:some View {
        StudyLine(id:"polynomialInverseCondition",atoms:[.text("A = \(s.a.vector()),"),.text("M = \(s.m.vector()), p = \(s.p);"),.text("A · X ≡ 1 (mod M, p)")],reason:StudyReason(title:"Обращение многочлена",text:"Ищем многочлен X, произведение которого с A даёт остаток 1 при делении на M над полем коэффициентов по простому p. Модуль нормирован умножением на обратный старший коэффициент; это не меняет сравнение.",references:["polynomial-inverse-exists"]))
        if s.preparation.dividend != s.preparation.remainder {StudyLine(id:"polyInversePreparation",atoms:[.text("A ≡ \(s.preparation.remainder.vector()) (mod M, \(s.p))")],reason:StudyReason(title:"Начальный остаток",text:"Сначала приводим A по M.",references:["polynomial-division"]),works:[0:.polynomialDivision(s.preparation,s.p)])}
        #if os(watchOS)
        HStack(alignment: .center, spacing: 10) {
            ForEach(s.frames) { f in
                StudyAnnotated(id: "polyInverseFrame_\(f.id)", reason: StudyReason(title: "Преобразование строк многочленов", text: f.explanation, references: ["polynomial-binary"])) {
                    HStack(spacing: 10) {
                        if !f.operation.isEmpty {
                            VStack(spacing: 2) {
                                TransformationLabel(operation: f.operation).fixedSize().frame(minHeight: 54)
                                MathText(text: "∼")
                            }
                        }
                        Grid(alignment: .trailing, horizontalSpacing: 18, verticalSpacing: 12) {
                            ForEach(f.rows.indices, id: \.self) { i in
                                GridRow { MathText(text: f.rows[i].value.vector()); Divider().frame(height: 28); MathText(text: f.rows[i].coefficient.vector()) }
                            }
                        }.fixedSize().padding(16)
                            .overlay(alignment: .leading) { MatrixBracket(right: false).stroke(lineWidth: 1.3).frame(width: 8) }
                            .overlay(alignment: .trailing) { MatrixBracket(right: true).stroke(lineWidth: 1.3).frame(width: 8) }
                    }.fixedSize().padding(.vertical, 5)
                }.fixedSize()
            }
        }.courseMathRow().accessibilityIdentifier("polynomialMatrixChain")
        #else
        ForEach(s.frames){f in
            StudyAnnotated(id:"polyInverseFrame_\(f.id)",reason:StudyReason(title:"Преобразование строк многочленов",text:f.explanation,references:["polynomial-binary"])) {
                VStack(alignment:.leading,spacing:8){
                    if !f.operation.isEmpty {TransformationLabel(operation:f.operation).frame(width:180,height:54).padding(.vertical,4)}
                    ScrollView(.horizontal){Grid(alignment:.trailing,horizontalSpacing:18,verticalSpacing:12){ForEach(f.rows.indices,id:\.self){i in GridRow{MathText(text:f.rows[i].value.vector());Divider().frame(height:28);MathText(text:f.rows[i].coefficient.vector())}}}.fixedSize().padding(16).overlay(alignment:.leading){MatrixBracket(right:false).stroke(lineWidth:1.3).frame(width:8)}.overlay(alignment:.trailing){MatrixBracket(right:true).stroke(lineWidth:1.3).frame(width:8)}.padding(.vertical,5)}
                }
            }
        }
        #endif
        if let inverse=s.inverse {
            StudyLine(id:"polyInverseResult",atoms:[.text("A⁻¹ ≡ \(inverse.vector()) (mod M, \(s.p))")],reason:StudyReason(title:"Нормировка последней строки",text:"В последней строке слева ненулевая константа d. Делим правый коэффициент на d в поле по p и приводим по M. Получаем коэффициент при A в равенстве 1.",references:["polynomial-inverse-exists"]))
            StudyLine(id:"polyInverseCheck",atoms:[.text("\(s.a.vector()) · \(inverse.vector())"),.text("≡"),.text("1 (mod M, \(s.p))")],reason:StudyReason(title:"Проверка",text:"Произведение исходного многочлена и найденного обратного должно иметь остаток 1.",references:["polynomial-inverse"]),works:[0:.polynomialProduct(s.a.vector(),inverse.vector(),s.m.vector(),s.p.description)])
        }else{StudyLine(id:"polyInverseMissing",atoms:[.text("НОД(A, M) = \(s.gcd.formula) ≠ 1")],reason:StudyReason(title:"Обратного нет",text:"Неконстантный общий делитель не позволяет получить 1 как линейную комбинацию A и M.",references:["polynomial-inverse-exists"]))}
    }
}
private struct CourseOrderSolution:View {
    let s:OrderSolution
    var body:some View {
        StudyLine(id:"orderCondition",atoms:[.text("P\(RabinFormat.index(String(s.modulus)))(\(s.input)) = ?")],reason:StudyReason(title:"Мультипликативный порядок",text:"Ищем наименьший положительный показатель t, для которого aᵗ ≡ 1 по m. Порядок определён только для взаимно простых a и m.",references:["order"]))
        StudyLine(id:"orderGCD",atoms:[.text("НОД(\(s.a), \(s.modulus)) = \(s.gcd)")],reason:StudyReason(title:"Проверка существования",text:s.gcd==1 ? "Число обратимо по модулю, поэтому порядок существует.":"Общий делитель больше 1. Ни одна положительная степень a не может быть равна 1 по этому модулю.",references:["order-divisibility"]))
        if s.order != nil {
            StudyLine(id:"orderFactorization",atoms:[.text("\(s.modulus) = \(s.factorization.expression)")],reason:StudyReason(title:"Разложение модуля",text:"Считаем локальные порядки по простым степеням и объединяем их через НОК. Факторизация выполняется автоматически; её деления открываются отдельно.",references:["order-crt"]),works:[0:.factorization(s.factorization)])
            ForEach(s.steps){CourseNumberStep(step:$0,prefix:"order")}
        }
    }
}
struct CourseNumberStep:View {
    let step:NumberStep
    let prefix:String
    private func display(_ text:String)->String {
        guard prefix=="order",let regex=try? NSRegularExpression(pattern:"P([0-9]+)\\(") else{return text}
        var value=text
        for m in regex.matches(in:text,range:NSRange(text.startIndex...,in:text)).reversed(){if let range=Range(m.range(at:1),in:value),let n=UInt64(value[range]){value.replaceSubrange(range,with:RabinFormat.index(String(n)))}}
        return value
    }
    var body:some View {
        ForEach(step.equations.indices,id:\.self){i in
            let equation=step.equations[i]
            let match=step.powers.first{equation.contains($0.expression)}
            if let match,let range=equation.range(of:match.expression){
                StudyLine(id:"\(prefix)_\(step.id)_\(i)",atoms:[.text(display(String(equation[..<range.lowerBound]))),.power(String(match.base),String(match.exponent)),.text(display(String(equation[range.upperBound...])))],reason:StudyReason(title:"Почему эта строка верна",text:step.explanation,references:step.theorem.map{[$0]} ?? []),works:[1:.power(match)])
            }else{
                StudyLine(id:"\(prefix)_\(step.id)_\(i)",atoms:[.text(display(equation))],reason:StudyReason(title:"Почему эта строка верна",text:step.explanation,references:step.theorem.map{[$0]} ?? []))
            }
        }
    }
}
