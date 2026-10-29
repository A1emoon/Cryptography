import SwiftUI

struct CalculatorView: View {
    @StateObject private var model = CalculatorModel()
    @AppStorage("solutionStyle.doubling") private var solutionStyle: SolutionStyle = .detailed
    @State private var showAlgorithm = false
    @State private var showExplanations = true
    @State private var didLoad = false
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case a, b, modulus }

    var body: some View {
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heading
                    TaskFormulaView(formula: "r = (a · b) mod m", definitions: "a и b — множители\nm — положительный модуль\nr — остаток, который нужно найти")
                        .padding(.horizontal, 20).padding(.bottom, 20)
                        .accessibilityIdentifier("doublingFormula")
                    inputs
                    SolutionStylePicker(selection: $solutionStyle)
                    if let error = model.error {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.callout).foregroundStyle(.red)
                            .padding(.horizontal, 22).padding(.bottom, 20)
                            .accessibilityIdentifier("inputError")
                    }
                    if model.isCalculating {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Вычисляем все шаги…").font(.callout)
                            Spacer(minLength: 0)
                            Button("Отмена") { model.invalidate() }
                        }
                        .padding(22)
                    }
                    if let solution = model.solution {
                        Group {
                            if solutionStyle == .notebook { NotebookDoublingView(solution: solution) }
                            else { solutionSheet(solution) }
                        }.id(model.calculationID)
                    } else if !model.isCalculating && model.error == nil {
                        Text("Введите два целых множителя и положительный модуль. Решение появится здесь.")
                            .font(.callout).foregroundStyle(.secondary)
                            .padding(22)
                    }
                }
            }
            .background(AppStyle.background)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 1)
                    .background(AppStyle.background, ignoresSafeAreaEdges: .top)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Удвоение–сложение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppStyle.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showAlgorithm) { AlgorithmInfoView() }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") { focusedField = nil }
                }
            }
            .onChange(of: model.a) { model.invalidate() }
            .onChange(of: model.b) { model.invalidate() }
            .onChange(of: model.modulus) { model.invalidate() }
            .task {
                if !didLoad { didLoad = true; model.solve() }
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ТЕОРИЯ ЧИСЕЛ")
                    .font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
                Spacer()
                Text("Калькулятор").font(.caption)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .foregroundStyle(AppStyle.accent)
                    .background(AppStyle.accent.opacity(0.08), in: Capsule())
            }
            Text("Удвоение\nи сложение")
                .font(.largeTitle.weight(.bold)).tracking(-1)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Произведение по модулю")
                .font(.subheadline).foregroundStyle(.secondary)
                .padding(.top, -8)
            Button { focusedField = nil; showAlgorithm = true } label: {
                Label("Об алгоритме", systemImage: "info.circle")
                    .font(.subheadline.weight(.medium)).frame(minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier("algorithmInfo")
            .padding(.top, -12)
        }
        .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 12)
    }

    private var inputs: some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 9) {
                    input("a", text: $model.a, field: .a)
                    input("b", text: $model.b, field: .b)
                    input("m", text: $model.modulus, field: .modulus)
                }
                VStack(spacing: 9) {
                    input("a", text: $model.a, field: .a)
                    input("b", text: $model.b, field: .b)
                    input("m", text: $model.modulus, field: .modulus)
                }
            }
            Button {
                focusedField = nil
                model.solve()
            } label: {
                Text("Решить").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(model.isCalculating)
            .accessibilityIdentifier("solve")
        }
        .padding(.horizontal, 20).padding(.bottom, 24)
    }

    private func input(_ label: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(.subheadline, design: .serif).italic()).foregroundStyle(.secondary)
            TextField(label, text: text, axis: .vertical)
                .font(.title3.weight(.medium)).monospacedDigit()
                .lineLimit(1...3)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($focusedField, equals: field)
                .accessibilityLabel(label == "m" ? "Модуль m" : "Множитель \(label)")
                .accessibilityIdentifier("input_\(label)")
        }
        .padding(12).frame(minWidth: 70, maxWidth: .infinity, alignment: .leading)
        .background(AppStyle.paper, in: RoundedRectangle(cornerRadius: 14))
    }

    private func solutionSheet(_ solution: DoublingSolution) -> some View {
        VStack(alignment: .leading, spacing: 25) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Задача").font(.caption).foregroundStyle(.secondary)
                MathLine("\(solution.expression) = r")
            }
            .padding(.horizontal, 20)
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Ход решения").font(.title3.weight(.semibold))
                    Spacer(minLength: 12)
                    explanationToggle
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ход решения").font(.title3.weight(.semibold))
                    explanationToggle
                }
            }
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 15) {
                SectionHeading(number: "01", title: "Двоичная запись")
                if solution.hasNegativeInput {
                    Text("Сначала вычисляем произведение модулей чисел. Знак учтём после основной таблицы.")
                        .font(.callout).foregroundStyle(.secondary)
                    MathLine("|\(solution.a)| = \(solution.a.magnitude),   |\(solution.b)| = \(solution.b.magnitude)")
                }
                BinaryConversionView(conversion: solution.conversionA)
                Divider()
                BinaryConversionView(conversion: solution.conversionB)
                if showExplanations {
                    explanation("Делим на 2 нацело. Под каждым числом записываем остаток. Читаем остатки справа налево.")
                }
            }
            .padding(.horizontal, 20)

            if let special = solution.specialExplanation {
                Text(special).font(.body).padding(.horizontal, 20)
            } else {
                VStack(alignment: .leading, spacing: 13) {
                    SectionHeading(number: "02", title: "Выбор множителя")
                    MathLine("\(solution.selectedConversion.binary)₂")
                        .foregroundStyle(AppStyle.accent)
                    Text(solution.selectionExplanation).font(.callout).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)

                if let preparation = solution.preparation {
                    VStack(alignment: .leading, spacing: 13) {
                        SectionHeading(number: "03", title: "Подготовка прибавляемого числа")
                        Text("Прибавляемое число \(solution.originalAddend.description) достигло модуля. Найдём его остаток тем же алгоритмом, прибавляя 1 или 0. Исходные двоичные записи сохраняем.")
                            .font(.callout).foregroundStyle(.secondary)
                        MathLine("(\(preparation.multiplier) · 1) mod \(preparation.modulus)")
                        AlgorithmTableView(table: preparation)
                        MathLine("\(solution.originalAddend) ≡ \(preparation.answer) (mod \(solution.modulus))")
                        Text("В основной таблице прибавляем \(preparation.answer.description) вместо \(solution.originalAddend.description). Остаток произведения от этого не меняется.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                }

                if let table = solution.table {
                    VStack(alignment: .leading, spacing: 13) {
                        SectionHeading(number: solution.preparation == nil ? "03" : "04", title: "Удвоение–сложение")
                        AlgorithmTableView(table: table)
                        if showExplanations {
                            explanation("Сначала удваиваем остаток и при необходимости вычитаем модуль. Затем прибавляем число из верхней ячейки и при необходимости снова вычитаем модуль. Все действия — в столбик.")
                        }
                    }
                    .padding(.horizontal, 20)
                }

                if solution.hasNegativeInput {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(number: solution.preparation == nil ? "04" : "05", title: "Учитываем знак")
                        if let correction = solution.signCorrection {
                            Text("Произведение отрицательное. Из модуля вычитаем ненулевой остаток произведения модулей чисел, чтобы получить неотрицательный ответ.")
                                .font(.callout).foregroundStyle(.secondary)
                            MathLine(correction.expression)
                        } else {
                            Text(solution.a.isNegative == solution.b.isNegative
                                 ? "Два отрицательных множителя дают положительное произведение. Остаток уже найден."
                                 : "Произведение делится на модуль без остатка. После учёта знака остаток остаётся нулевым.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Ответ").font(.caption).foregroundStyle(AppStyle.accent)
                Text(solution.answer.description)
                    .font(.system(.title, design: .serif)).monospacedDigit()
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("answer")
                Text(solution.expression + " = " + solution.answer.description)
                    .font(.system(.callout, design: .serif)).monospacedDigit()
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(AppStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppStyle.paper, in: UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))
    }

    private var explanationToggle: some View {
        Toggle("Пояснения", isOn: $showExplanations)
            .font(.caption).fixedSize().tint(AppStyle.accent)
            .accessibilityIdentifier("explanations")
    }

    private func explanation(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

