import SwiftUI

struct ModularView: View {
    @StateObject private var model: ModularModel
    @AppStorage("solutionStyle.inverse") private var solutionStyle: SolutionStyle = .detailed
    @State private var explanations = true
    @State private var showInfo = false
    @State private var showAnswer = false
    @FocusState private var focused: String?
    init(isDivision: Bool) {
        _model = StateObject(wrappedValue: ModularModel(isDivision: isDivision))
        _solutionStyle = AppStorage(wrappedValue: .detailed, isDivision ? "solutionStyle.modularDivision" : "solutionStyle.inverse")
    }
    private var title: String { model.isDivision ? "Деление по модулю" : "Обратное по модулю" }

    var body: some View {
        Group {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header
                    SolutionStylePicker(selection: $solutionStyle)
                    if let error = model.error {
                        Label(error, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.red)
                            .padding(22).accessibilityIdentifier("inputError")
                    }
                    if model.isCalculating {
                        HStack { ProgressView(); Text("Вычисляем все преобразования…").font(.callout) }.padding(22)
                    }
                    if let solution = model.solution {
                        HStack {
                            Button("Ответ и проверка") { focused = nil; showAnswer = true }
                                .accessibilityIdentifier("jumpToModularAnswer")
                            Spacer()
                            if solutionStyle == .detailed { Toggle("Пояснения", isOn: $explanations).font(.caption).fixedSize() }
                        }.padding(22)
                        Group {
                            if solutionStyle == .notebook { NotebookModularView(solution: solution) }
                            else { solutionView(solution) }
                        }.id(model.calculationID)
                    } else if !model.isCalculating && model.error == nil {
                        Text("Нажмите «Решить», чтобы получить все шаги для текущих значений.")
                            .font(.footnote).foregroundStyle(.secondary).padding(22)
                    }
                }
            }
            .background(AppStyle.background)
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppStyle.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer(); Button("Готово") { focused = nil }
                }
            }
            .sheet(isPresented: $showInfo) { ModularInfoView(isDivision: model.isDivision) }
            .sheet(isPresented: $showAnswer) {
                if let solution = model.solution {
                    NavigationStack {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                answerCard(solution)
                                Text("Проверка").font(.headline)
                                conclusionView(solution)
                            }.padding(22)
                        }
                        .background(AppStyle.background)
                        .navigationTitle("Ответ").navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("К решению") { showAnswer = false }.accessibilityIdentifier("closeModularAnswer")
                            }
                        }
                    }.presentationDetents([.large]).presentationDragIndicator(.visible)
                }
            }
            .task { if model.solution == nil && !model.isCalculating { model.solve() } }
            .onDisappear { model.invalidate() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title).font(.largeTitle.weight(.bold)).tracking(-1)
            Text(model.isDivision ? "Дробь в кольце вычетов" : "Находим число, обратное к a")
                .font(.subheadline).foregroundStyle(.secondary)
            Button { focused = nil; showInfo = true } label: {
                Label("Об алгоритмах", systemImage: "info.circle")
            }.accessibilityIdentifier("algorithmInfo")
            TaskFormulaView(formula: model.isDivision ? "(u / v) mod m = x;  v · x ≡ u (mod m)" : "a⁻¹ mod m = x;  a · x ≡ 1 (mod m)",
                definitions: model.isDivision
                    ? "u — числитель, v — знаменатель, m — модуль, x — ответ. Требуется НОД(v, m) = 1 и m > 1."
                    : "a — обращаемое число, m — модуль, x — обратное число. Требуется НОД(a, m) = 1 и m > 1.")
                .accessibilityIdentifier("modularFormula")
            if model.isDivision { input("u", name: "Числитель", text: $model.numerator) }
            HStack(alignment: .top, spacing: 10) {
                input(model.isDivision ? "v" : "a", name: model.isDivision ? "Знаменатель" : "Число", text: $model.a)
                input("m", name: "Модуль", text: $model.modulus)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Способ решения").font(.caption).foregroundStyle(.secondary)
                Picker("Способ решения", selection: $model.method) {
                    ForEach(ModularMethod.allCases.filter { model.isDivision || $0 != .direct }) { method in
                        Text(method.title).tag(method).accessibilityIdentifier("method_\(method.rawValue)")
                    }
                }.pickerStyle(.menu).accessibilityIdentifier("modularMethod")
                Text(model.method.detail).font(.footnote).foregroundStyle(.secondary)
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(AppStyle.paper, in: RoundedRectangle(cornerRadius: 14))
            HStack {
                Menu("Примеры с пары") {
                    if model.isDivision {
                        Button("153 / 179 mod 283") { model.example(a: "179", m: "283", n: "153") }
                        Button("5 / 7 mod 13") { model.example(a: "7", m: "13", n: "5") }
                    } else {
                        Button("113⁻¹ mod 512") { model.example(a: "113", m: "512") }
                        Button("129⁻¹ mod 257") { model.example(a: "129", m: "257") }
                        Button("3⁻¹ mod 7") { model.example(a: "3", m: "7") }
                        Button("7⁻¹ mod 16") { model.example(a: "7", m: "16") }
                    }
                }.font(.subheadline)
                Spacer()
            }
            Button { focused = nil; model.solve() } label: {
                Text("Решить").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 7)
            }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.isCalculating)
                .accessibilityIdentifier("solve")
        }.padding(22)
    }

    private func input(_ key: String, name: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("\(key) · \(name)").font(.caption).foregroundStyle(.secondary)
            TextField(key, text: text, axis: .vertical).font(.title3.weight(.medium)).monospacedDigit().lineLimit(1...3)
                .keyboardType(.numbersAndPunctuation).textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($focused, equals: key).accessibilityLabel("\(name) \(key)").accessibilityIdentifier("input_\(key)")
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(AppStyle.paper, in: RoundedRectangle(cornerRadius: 14))
    }

    private func solutionView(_ s: ModularSolution) -> some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            Text("Задача").font(.caption).foregroundStyle(.secondary)
            MathLine(s.isDivision ? "(\(s.numerator!) / \(s.input)) mod \(s.modulus)" : "\(s.input.parenthesized)⁻¹ mod \(s.modulus)")
            Text("Ход решения").font(.title2.weight(.semibold))
            Text(s.method.title).font(.subheadline).foregroundStyle(AppStyle.accent)
            ForEach(s.preparation.indices, id: \.self) { i in MathLine(s.preparation[i]) }
            SectionHeading(number: "01", title: "Проверяем существование")
            if explanations {
                Text("Сначала проверяем взаимную простоту бинарным алгоритмом. Деление пополам выполняем раньше вычитания.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(s.gcdTrace.lines.indices, id: \.self) { i in MathLine(s.gcdTrace.lines[i]) }
            if !s.frames.isEmpty {
                SectionHeading(number: "02", title: s.method == .direct ? "Собираем числитель" : "Преобразования матрицы")
                Text(s.usesExactRows ? "Столбцы: число | α | β" : "Столбцы: число | α").font(.footnote).foregroundStyle(.secondary)
                if s.method == .powerMatrix, let exponent = s.modulus.powerOfTwoExponent {
                    MathLine("m = \(s.modulus) = \(PowerNotation.two(exponent))")
                    Text("Нулевые строки 2 и 3 неизменны. После исходной матрицы записываем только первую строку; обозначения преобразований ссылаются на исходные номера строк.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(s.frames) { frame in
                    ModularFrameView(frame: frame, explanations: explanations, usesPowerMatrix: s.method == .powerMatrix)
                    Divider()
                }
            }
            if !s.lifts.isEmpty {
                SectionHeading(number: "02", title: "Поднимаем модуль")
                ForEach(s.lifts) { stage in
                    liftView(stage, a: s.a)
                    Divider()
                }
            }
            if let multiplication = s.multiplication {
                MathLine("\(s.a)⁻¹ ≡ \(s.inverse!) (mod \(s.modulus))")
                ModularMultiplicationView(solution: multiplication)
            }
            Text(s.result == nil ? "Почему ответа нет" : "Проверка и ответ").font(.title3.weight(.semibold))
            conclusionView(s)
            answerCard(s)

        }
        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
        .background(AppStyle.paper, in: UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))
    }

    private func conclusionView(_ s: ModularSolution) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(s.conclusion.indices, id: \.self) { i in
                if s.conclusion[i].hasPrefix("Обратного") || s.conclusion[i].hasPrefix("Сравнение") || s.conclusion[i].hasPrefix("Числитель") {
                    Text(s.conclusion[i]).font(.callout).fixedSize(horizontal: false, vertical: true)
                } else { MathLine(s.conclusion[i]) }
            }
        }
    }

    private func answerCard(_ s: ModularSolution) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ответ").font(.caption).foregroundStyle(AppStyle.accent)
                Text(s.result?.description ?? "Обратного элемента нет")
                    .font(.system(.title, design: .serif)).textSelection(.enabled)
                    .accessibilityIdentifier("modularAnswer")
                if let result = s.result {
                    MathLine("x ≡ \(result) (mod \(s.modulus))")
                    Text("Наименьший неотрицательный представитель.").font(.footnote).foregroundStyle(.secondary)
                } else if s.isDivision {
                    Text("Дробь через обратный элемент не определена.").font(.footnote)
                }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(AppStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                .id("modularAnswerAnchor")
    }

    private func liftView(_ stage: LiftStage, a: Natural) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Шаг \(stage.id + 1) · mod \(stage.modulus)").font(.headline).foregroundStyle(AppStyle.accent)
            MathLine("\(a) · \(stage.previous) = \(stage.product) ≡ \(stage.residue) (mod \(stage.modulus))")
            if !stage.addition.isZero {
                MathLine("x = \(stage.previous) + \(stage.addition) = \(stage.result)")
            } else { MathLine("x = \(stage.result)") }
            ForEach(stage.verification.indices, id: \.self) { i in MathLine(stage.verification[i]) }
            MathLine("\(a)⁻¹ ≡ \(stage.result) (mod \(stage.modulus))")
            if explanations {
                Text(stage.addition.isZero ? "Произведение уже даёт остаток 1: сохраняем ответ." : "Добавляем предыдущий модуль: это исправляет следующий двоичный разряд обратного числа.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }.accessibilityIdentifier("liftStage_\(stage.id)")
    }
}
