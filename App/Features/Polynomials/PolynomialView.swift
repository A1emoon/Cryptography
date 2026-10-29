import SwiftUI

struct PolynomialView: View {
    @StateObject private var model = PolynomialModel()
    @AppStorage("solutionStyle.polynomial") private var solutionStyle: SolutionStyle = .detailed
    @State private var explanations = true
    @State private var showInfo = false
    @State private var showAnswer = false
    @State private var didLoad = false
    @FocusState private var focused: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                SolutionStylePicker(selection: $solutionStyle)
                if let error = model.error {
                    Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red)
                        .padding(22).accessibilityIdentifier("inputError")
                }
                if model.isCalculating {
                    HStack {
                        ProgressView(); Text("Вычисляем многочлены…")
                        Spacer(); Button("Отмена") { model.invalidate() }
                    }.font(.callout).padding(22)
                }
                if let s = model.solution {
                    HStack {
                        Button("Ответ и проверка") { focused = nil; showAnswer = true }
                            .accessibilityIdentifier("polynomialShowAnswer")
                        Spacer()
                        if solutionStyle == .detailed { Toggle("Пояснения", isOn: $explanations).font(.caption).fixedSize() }
                    }.padding(22)
                    Group {
                        if solutionStyle == .notebook { NotebookPolynomialView(solution: s) }
                        else { solutionView(s) }
                    }.id(model.calculationID)
                }
            }
        }
        .background(AppStyle.background)
        .navigationTitle("Многочлены").navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Готово") { focused = nil } }
        }
        .sheet(isPresented: $showInfo) { PolynomialInfoView() }
        .sheet(isPresented: $showAnswer) {
            if let s = model.solution {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            answer(s)
                            Text("Проверка раскрытием скобок").font(.headline)
                            MathLine("A · B ≡ \(s.verificationProduct.formula) (mod \(s.p))")
                            ForEach(s.verificationSteps) { step in
                                ScrollView(.horizontal) { PolynomialStepView(step: step, p: s.p).padding(.vertical, 4) }
                            }
                            MathLine("R = \(s.result.vector())")
                            if !s.result.isZero { MathLine("deg R = \(s.result.degree) < \(s.m.polynomial.degree) = deg M") }
                            else { Text("Остаток — нулевой многочлен.") }
                        }.padding(22)
                    }.navigationTitle("Ответ и проверка").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) {
                            Button("К решению") { showAnswer = false }.accessibilityIdentifier("closePolynomialAnswer")
                        } }
                }
            }
        }
        .task { if !didLoad { didLoad = true; model.solve() } }
        .onDisappear { model.invalidate() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Удвоение–сложение\nдля многочленов").font(.largeTitle.weight(.bold)).tracking(-1)
            Text("Сдвигаем, приводим по модулю, складываем")
                .font(.subheadline).foregroundStyle(.secondary)
            Button { focused = nil; showInfo = true } label: { Label("Об алгоритме", systemImage: "info.circle") }
                .accessibilityIdentifier("algorithmInfo")
            TaskFormulaView(formula: "R(α) = A(α) · B(α) mod (M(α), p)",
                definitions: "A, B — множители; M — многочлен-модуль; p — модуль коэффициентов. У M старший коэффициент 1, степень не меньше 1; p ≥ 2.")
            Text("Коэффициенты от старшей степени к свободному члену. Например: 1, 0, 2 → α² + 2. Нули внутри не пропускаем.")
                .font(.footnote).foregroundStyle(.secondary)
            input("A", name: "Первый множитель", text: $model.a)
            input("B", name: "Второй множитель", text: $model.b)
            input("M", name: "Многочлен-модуль", text: $model.m)
            input("p", name: "Модуль коэффициентов", text: $model.p)
            Button { focused = nil; model.solve() } label: {
                Text("Решить").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 7)
            }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.isCalculating)
                .accessibilityIdentifier("solve")
        }.padding(22)
    }
    private func input(_ key: String, name: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("\(key) · \(name)").font(.caption).foregroundStyle(.secondary)
            TextField(key, text: text, axis: .vertical).font(.title3).monospacedDigit().lineLimit(1...4)
                .keyboardType(.numbersAndPunctuation).textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($focused, equals: key).accessibilityIdentifier("input_\(key)")
            if key != "p", let raw = try? PolynomialSolver.parse(text.wrappedValue, name: key) {
                Text(signedFormula(raw)).font(.system(.callout, design: .serif)).foregroundStyle(AppStyle.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(AppStyle.paper, in: RoundedRectangle(cornerRadius: 14))
    }
    private func signedFormula(_ raw: [DecimalInteger]) -> String {
        var text = ""
        for (i, c) in raw.enumerated() where !c.magnitude.isZero {
            let exponent = raw.count - i - 1
            let term = exponent == 0 ? c.magnitude.description
                : (c.magnitude == .one ? "" : c.magnitude.description) + Polynomial.power(exponent)
            text += text.isEmpty ? (c.isNegative ? "−" : "") : (c.isNegative ? " − " : " + ")
            text += term
        }
        return text.isEmpty ? "0" : text
    }
    private func solutionView(_ s: PolynomialSolution) -> some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            Text("Задача").font(.caption).foregroundStyle(.secondary)
            MathLine(s.expression)
            Text("Ход решения").font(.title2.weight(.semibold))
            SectionHeading(number: "01", title: "Коэффициенты и выбор множителя")
            ForEach([s.a, s.b, s.m], id: \.name) { input in
                VStack(alignment: .leading, spacing: 7) {
                    MathLine("\(input.name) = \(input.vector)")
                    ForEach(input.reductions.indices, id: \.self) { i in MathLine(input.reductions[i]) }
                    MathLine("\(input.name)(α) = \(input.polynomial.formula)")
                    MathLine("\(input.name) = \(input.polynomial.vector(width: max(s.m.polynomial.coefficients.count, input.polynomial.coefficients.count)))")
                }
            }
            Text(s.selection).font(.callout).accessibilityIdentifier("polynomialSelection")
            if explanations { note("Вес Хэмминга — число ненулевых коэффициентов после приведения по p. При равном весе меньшая степень даёт меньше сдвигов. В таблице сохраняем и нулевые коэффициенты.") }
            if !s.preparation.isEmpty {
                SectionHeading(number: "02", title: "Приводим \(s.baseName) по M")
                ForEach(s.preparation) { step in
                    ScrollView(.horizontal) { PolynomialStepView(step: step, p: s.p).padding(.vertical, 4) }
                }
            }
            SectionHeading(number: "03", title: "Верхняя строка таблицы")
            MathLine("B̃ = \(s.base.vector())")
            if explanations { note("Коэффициенты aᵢ берём из \(s.multiplierName). B̃ — \(s.baseName) после приведения по M; каждый элемент верхней строки равен aᵢ·B̃ по модулю \(s.p).") }
            ForEach(s.columns) { column in
                ScrollView(.horizontal) { PolynomialStepView(step: column.scaling, p: s.p).padding(.vertical, 4) }
            }
            SectionHeading(number: "04", title: "Таблица удвоения–сложения")
            if explanations { note("Первая ячейка — начальное значение. Далее умножаем предыдущий результат на α, сокращаем старший член вычитанием кратного M и прибавляем верхнюю ячейку. Все коэффициенты приводим по \(s.p).") }
            PolynomialTableView(solution: s)
            answer(s)
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(AppStyle.paper, in: UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))
    }
    private func answer(_ s: PolynomialSolution) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ответ").font(.caption).foregroundStyle(AppStyle.accent)
            MathLine(s.result.formula).accessibilityIdentifier("polynomialAnswer")
                .accessibilityLabel(s.result.formula)
            MathLine(s.result.vector())
            Text("По модулю M(α) = \(s.m.polynomial.formula), коэффициенты по mod \(s.p.description)")
                .font(.footnote).foregroundStyle(.secondary)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(AppStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
    private func note(_ text: String) -> some View { Text(text).font(.footnote).foregroundStyle(.secondary) }
}
