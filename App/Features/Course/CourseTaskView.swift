import SwiftUI

struct CourseTaskView:View {
    @StateObject private var model:CourseTaskModel
    @State private var input=false
    @State private var help=false
    @State private var didLoad=false
    init(kind:CourseTask, inputs:CourseInputs? = nil){_model=StateObject(wrappedValue:CourseTaskModel(kind,inputs:inputs))}
    var body:some View {
        ScrollView {
            if let result=model.result {
                VStack(alignment:.leading,spacing:14){
                    CourseSolutionView(result:result)
                    StudyAnnotated(id:"courseAnswer",reason:StudyReason(title:"Как читать ответ",text:answerExplanation(result),references:model.kind.referenceIDs)){
                        MathLine("Ответ: "+answerText(result)).accessibilityElement(children:.ignore)
                            .accessibilityIdentifier("answer_"+model.kind.id).accessibilityLabel(result.answer)
                    }
                }.padding(AppStyle.contentPadding).frame(maxWidth:.infinity,alignment:.leading)
                    .accessibilityElement(children:.contain).accessibilityIdentifier("studentSolution").id(model.generation)
            }else if model.calculating{
                VStack(spacing:16){ProgressView("Вычисляем…");Button("Отмена"){model.cancel()}.accessibilityIdentifier("cancelCalculation")}.padding(40)
            }else if let error=model.error{
                VStack(alignment:.leading,spacing:18){Label(error,systemImage:"exclamationmark.circle").foregroundStyle(.red).accessibilityIdentifier("inputError");Button("Изменить условие"){input=true}}.padding(AppStyle.contentPadding)
            }else{Button("Задать условие"){input=true}.padding(30)}
        }.courseSolutionAppearance().navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar { CoursePageTools(firstTitle: "Изменить условие", firstIcon: "square.and.pencil", firstID: "courseInput", firstAction: { input = true }, secondTitle: "Об алгоритме", secondIcon: "book.closed", secondID: "courseHelp", secondAction: { help = true }) }
            .sheet(isPresented:$input){CourseInputView(model:model)}
            .sheet(isPresented:$help){CourseHelpView(kind:model.kind)}
            .task{if !didLoad{didLoad=true;model.solve()}}.onDisappear{if model.calculating {model.cancel()}}
    }
    private func answerText(_ r:CourseResult)->String {
        switch r{
        case .tonelli(let s):s.roots.isEmpty ? "Решений нет" : "x ∈ {"+s.roots.map(String.init).joined(separator:", ")+"} (mod \(s.p))"
        case .polynomial(let s):s.result.formula
        case .polynomialInverse(let s):s.inverse.map{"A⁻¹ ≡ "+$0.formula+" (mod (M, \(s.p)))"} ?? "Обратного многочлена нет"
        case .order(let s):s.order.map{"P"+RabinFormat.index(String(s.modulus))+"(\(s.a)) = \($0)"} ?? "Мультипликативный порядок не существует"
        default:r.answer
        }
    }
    private func answerExplanation(_ r:CourseResult)->String {
        switch r{
        case .tonelli(let s):s.roots.isEmpty ? "Критерий степенного вычета не выполнен. Решений нет." : "В ответе перечислены все различные неотрицательные представители корней по \(s.p). Каждому представителю соответствует целый класс остатков. Корни проверены независимым возведением в степень."
        case .order(let s):s.order == nil ? "При НОД(a,m) ≠ 1 никакая положительная степень a не может равняться 1 по m: общий делитель делил бы 1." : "Порядок — наименьший положительный показатель, а не просто любой показатель с результатом 1. Минимальность обоснована проверками по простым делителям и НОК локальных порядков."
        case .polynomialInverse(let s):s.inverse == nil ? "НОД(A,M) не равен 1. Обратного класса многочлена нет." : "Ответ — единственный представитель обратного класса степени меньше степени M. Проверка умножением даёт остаток 1."
        case .modular(let s):s.result == nil ? "Обращаемое число не взаимно просто с модулем. Дробь через обратный элемент не определена; существование решений линейного сравнения проверяется отдельно." : "Выбран наименьший неотрицательный остаток. Сравнение задаёт все целые числа, отличающиеся от него на кратное модуля."
        case .division:"Используем евклидов остаток: 0 ≤ r < |b|. Записанное равенство восстанавливает исходное делимое для любых знаков входов."
        default:"Это остаток исходного произведения. Промежуточные приведения по модулю не меняют его класс. Все вычисления сохранены в записи и вспомогательных окнах."
        }
    }
}
#if !os(watchOS)
private struct CourseInputView:View {
    @ObservedObject var model:CourseTaskModel
    @State private var i=CourseInputs()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused:String?
    var kind:CourseTask{model.kind}
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20){
                    Text(kind.title).font(.title2.weight(.semibold))
                    TaskFormulaView(formula:kind.formula,definitions:definitions)
                    if kind == .inverse {
                        Picker("Объект",selection:$i.polynomials){Text("Числа").tag(false);Text("Многочлены").tag(true)}
                            .pickerStyle(.segmented).accessibilityIdentifier("inverseDomain")
                    }
                    if kind == .tonelli {
                        Picker("Степень",selection:$i.degree){Text("x²").tag(2);Text("x³").tag(3)}.pickerStyle(.segmented).accessibilityIdentifier("rootDegree")
                    }
                    fields
                    Menu("Примеры из конспектов"){examples}.accessibilityIdentifier("courseExamples")
                    DisclosureGroup("Дополнительные параметры"){
                        VStack(alignment:.leading,spacing:16){
                            if kind == .order {
                                field("Разложение m · необязательно",key:"factors",value:$i.factors,placeholder:"Автоматически; например 2^3 * 5^3")
                                Text("Ручное разложение проверяется: все множители должны быть простыми, произведение — равным m.").font(.footnote).foregroundStyle(.secondary)
                            }else if kind == .inverse && i.polynomials{
                                Picker("Способ преобразования",selection:$i.polyMethod){ForEach(PolynomialInverseMethod.allCases,id:\.self){Text($0.title).tag($0)}}
                                Text("При M(0)=0 используется метод по старшему члену: деление на α по модулю такого M недопустимо.").font(.footnote).foregroundStyle(.secondary)
                            }else if kind == .inverse || kind == .modularDivision{
                                Picker("Метод",selection:$i.method){ForEach(ModularMethod.allCases.filter{kind == .modularDivision || $0 != .direct}){Text($0.title).tag($0)}}
                                MathExplainedText(text:i.method.detail)
                            }else{MathExplainedText(text:"Знаки чисел и нулевые значения учитываются автоматически. Все промежуточные вычисления доступны по ссылкам в решении.")}
                        }.padding(.vertical,12)
                    }
                    if kind == .order || kind == .tonelli || (kind == .inverse && i.polynomials){
                        Text("Точная проверка простоты и факторизация: модуль не больше 2⁶⁴ − 1. Входное число a и коэффициенты могут иметь произвольную длину. Долгий расчёт можно отменить.").font(.footnote).foregroundStyle(.secondary)
                    }
                    Button{focused=nil;model.solve(i);dismiss()}label:{Text("Решить").font(.headline).frame(maxWidth:.infinity).padding(.vertical,8)}.buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("courseSolve")
                }.padding(AppStyle.contentPadding)
            }.background(AppStyle.background).navigationTitle("Условие").navigationBarTitleDisplayMode(.inline)
                .toolbar{ToolbarItem(placement:.cancellationAction){Button("Отмена"){dismiss()}.accessibilityIdentifier("closeCourseInput")};ToolbarItemGroup(placement:.keyboard){Spacer();Button("Готово"){focused=nil}}}
        }.presentationDetents([.large]).keyboardType(.numbersAndPunctuation).textInputAutocapitalization(.never).autocorrectionDisabled()
            .onAppear{i=model.inputs}
    }
    private var definitions:String{
        switch kind{
        case .inverse:i.polynomials ? "A — обращаемый многочлен, M — многочлен-модуль, p — простой модуль коэффициентов. Векторы вводятся от старшего коэффициента к свободному." : "a — обращаемое число, m — модуль. Для нечётного m используется бинарный метод; остальные методы сохранены."
        case .order:"a — элемент, m — модуль. Требуется НОД(a,m)=1. Разложение m на простые степени определяется автоматически."
        case .tonelli:"a — подкоренное число, p — простой модуль. Ищем все корни выбранной степени."
        case .doubling:"a,b — множители; m — положительный модуль."
        case .division:"a — делимое, b — ненулевой делитель; q — частное, r — неотрицательный остаток."
        case .modularDivision:"u — числитель, v — знаменатель, m — модуль."
        case .polynomial:"A,B — множители, M — нормированный многочлен-модуль, p — модуль коэффициентов. Коэффициенты вводятся от старшего к свободному."
        }
    }
    @ViewBuilder private var fields:some View{
        if kind == .inverse && i.polynomials{
            field("A(α) · Коэффициенты",key:"polyA",value:$i.polyA)
            field("M(α) · Коэффициенты модуля",key:"polyM",value:$i.polyM)
            field("p · Простой модуль коэффициентов",key:"p",value:$i.p)
            if let a=try? PolynomialSolver.parse(i.polyA,name:"A"){MathLine("A = "+RabinFormat.signed(a).replacingOccurrences(of:"x",with:"α"))}
        }else{
            if kind == .modularDivision{field("u · Числитель",key:"u",value:$i.u)}
            field(kind == .polynomial ? "A(α) · Коэффициенты" : kind == .modularDivision ? "v · Знаменатель" : "a",key:"a",value:$i.a)
            if kind == .doubling || kind == .division || kind == .polynomial{field(kind == .polynomial ? "B(α) · Коэффициенты" : "b",key:"b",value:$i.b)}
            if kind != .division && kind != .tonelli{field(kind == .polynomial ? "M(α) · Коэффициенты модуля" : "m · Модуль",key:"m",value:$i.m)}
            if kind == .tonelli || kind == .polynomial{field(kind == .tonelli ? "p · Простой модуль" : "p · Модуль коэффициентов",key:"p",value:$i.p)}
        }
    }
    private func field(_ title:String,key:String,value:Binding<String>,placeholder:String="")->some View{
        VStack(alignment:.leading,spacing:10){Text(title).font(.caption).foregroundStyle(.secondary);HStack{TextField(placeholder,text:value,axis:.vertical).lineLimit(1...5).monospacedDigit().focused($focused,equals:key).accessibilityIdentifier("input_"+key);Button{value.wrappedValue="";focused=key}label:{Image(systemName:"xmark.circle.fill").foregroundStyle(.tertiary).frame(width:28,height:28)}.buttonStyle(.plain).accessibilityLabel("Очистить "+title).accessibilityIdentifier("clear_"+key)}}.padding(16).background(AppStyle.paper,in:RoundedRectangle(cornerRadius:14))
    }
    @ViewBuilder private var examples:some View{
        Button("Основной пример"){i=kind.initial}
        if kind == .inverse{
            Button("Многочлен · практика 3"){i=kind.initial;i.polynomials=true}
            Button("113⁻¹ mod 512"){i=kind.initial;i.a="113";i.m="512"}
            Button("Нет обратного · 6 mod 15"){i=kind.initial;i.a="6";i.m="15"}
        }else if kind == .order{
            Button("Практика · P₈₁₂₅(37)"){i=kind.initial;i.a="37";i.m="8125"}
        }else if kind == .tonelli{
            ForEach(TonelliLectureExample.all) { example in
                Button(example.title) { i=example.inputs }.accessibilityIdentifier("tonelliExample_"+example.id)
            }
            Button("Нет корней · x³ ≡ 2 (mod 7)"){i=kind.initial;i.a="2";i.p="7";i.degree=3}
        }
    }
}
#endif
private struct CourseHelpView:View{
    let kind:CourseTask
    var body:some View{
        StudentDetailSheet(title:kind.title,large:true){
            MathLine(kind.formula)
            if kind == .tonelli { TonelliLectureHelp() }
            MathExplainedText(text:kind.subtitle+". Основной лист содержит математическую запись. ↗ открывает вычисление в другом месте; ? объясняет эту строку. Термины и ссылки на теоремы открывают справочник с формулами, доказательствами и исходными страницами. Карандаш меняет условие; отмена сохраняет прежнее решение.")
            ReferenceLinks(ids:kind.referenceIDs,prefix:"algorithmReference_")
        }
    }
}
