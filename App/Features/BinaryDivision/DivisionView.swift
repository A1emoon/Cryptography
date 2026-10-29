import SwiftUI

struct DivisionView: View {
    @StateObject private var model = DivisionModel()
    @AppStorage("solutionStyle.division") private var solutionStyle: SolutionStyle = .detailed
    @State private var showAlgorithm = false
    @State private var explanations = true
    @State private var didLoad = false
    @FocusState private var focused: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heading
                inputs
                SolutionStylePicker(selection: $solutionStyle)
                if let error = model.error {
                    Label(error, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.red)
                        .padding(20).accessibilityIdentifier("inputError")
                }
                if model.isCalculating {
                    HStack {
                        ProgressView()
                        Text("Вычисляем все шаги…").font(.callout)
                        Spacer()
                        Button("Отмена") { model.invalidate() }
                    }.padding(20)
                }
                if let solution = model.solution {
                    Group {
                        if solutionStyle == .notebook { NotebookDivisionView(solution: solution) }
                        else { solutionSheet(solution) }
                    }.id(model.calculationID)
                } else if !model.isCalculating && model.error == nil {
                    Text("Введите делимое и ненулевой делитель. Найдём частное и остаток.")
                        .font(.callout).foregroundStyle(.secondary).padding(20)
                }
            }
        }
        .background(AppStyle.background)
        .navigationTitle("Двоичное деление")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppStyle.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") { focused = nil }
            }
        }
        .sheet(isPresented: $showAlgorithm) { DivisionInfoView() }
        .task { if !didLoad { didLoad = true; model.solve() } }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Двоичное деление\nуголком").font(.largeTitle.weight(.bold)).tracking(-1)
                .fixedSize(horizontal: false, vertical: true)
            Text("Частное как сумма степеней двойки").font(.subheadline).foregroundStyle(.secondary)
            Button { focused = nil; showAlgorithm = true } label: {
                Label("Об алгоритме", systemImage: "info.circle").font(.subheadline.weight(.medium)).frame(minHeight: 44)
            }
            .accessibilityIdentifier("algorithmInfo")
            TaskFormulaView(formula: "a = b · q + r", definitions: "a — делимое, b — делитель\nq — целое частное, r — остаток\n0 ≤ r < |b|,  b ≠ 0")
                .accessibilityIdentifier("divisionFormula")
        }
        .padding(20)
    }

    private var inputs: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                input("a", name: "Делимое", text: $model.a)
                input("b", name: "Делитель", text: $model.b)
            }
            Button { focused = nil; model.solve() } label: {
                Text("Решить").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).disabled(model.isCalculating)
            .accessibilityIdentifier("solve")
        }.padding(.horizontal, 20).padding(.bottom, 24)
    }

    private func input(_ letter: String, name: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("\(letter) · \(name)").font(.caption).foregroundStyle(.secondary)
            TextField(letter, text: text, axis: .vertical)
                .font(.title3.weight(.medium)).monospacedDigit().lineLimit(1...3)
                .keyboardType(.numbersAndPunctuation).textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($focused, equals: letter)
                .accessibilityLabel("\(name) \(letter)").accessibilityIdentifier("input_\(letter)")
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(AppStyle.paper, in: RoundedRectangle(cornerRadius: 14))
    }

    private func solutionSheet(_ solution: BinaryDivisionSolution) -> some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Задача").font(.caption).foregroundStyle(.secondary)
                MathLine("\(solution.a) = \(solution.b.isNegative ? "(\(solution.b))" : solution.b.description) · q + r")
            }
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Ход решения").font(.title3.weight(.semibold))
                    Spacer(minLength: 12)
                    Toggle("Пояснения", isOn: $explanations).font(.caption).fixedSize()
                }
                VStack(alignment: .leading) {
                    Text("Ход решения").font(.title3.weight(.semibold))
                    Toggle("Пояснения", isOn: $explanations).font(.caption).fixedSize()
                }
            }
            if solution.hasNegativeInput {
                Text("Сначала делим модули чисел. После этого восстановим знаки так, чтобы остаток был неотрицательным.")
                    .font(.callout).foregroundStyle(.secondary)
                MathLine("|\(solution.a)| = \(solution.a.magnitude),  |\(solution.b)| = \(solution.b.magnitude)")
            }
            SectionHeading(number: "01", title: "Двоичные длины")
            BinaryLengthView(info: solution.dividendLength)
            BinaryLengthView(info: solution.divisorLength)
            if explanations {
                note("l₂(n) — количество разрядов положительного числа n в двоичной записи. Определяем его по двум соседним степеням двойки.")
            }

            if !solution.steps.isEmpty {
                SectionHeading(number: "02", title: "Удвоения делителя")
                DivisorChainView(shifts: solution.shifts, dividend: solution.a.magnitude, boundSymbol: solution.a.isNegative ? "|a|" : "a")
                if explanations { note("Над стрелкой — показатель степени двойки. Последнее значение превысило делимое: дальше удваивать не нужно.") }
                SectionHeading(number: "03", title: "Вычитаем и собираем частное")
                ForEach(solution.steps) { step in
                    stepView(step, solution: solution)
                    Divider()
                }
            } else {
                MathLine("\(solution.a.magnitude) < \(solution.b.magnitude)")
                note("Делимое меньше делителя. Частное для модулей чисел равно 0, а остаток равен делимому.")
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(number: solution.steps.isEmpty ? "02" : "04", title: "Частное и остаток")
                MathLine("\(solution.magnitudeRemainder) < \(solution.b.magnitude)")
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        FloorFractionView(numerator: solution.magnitudeRemainder.description, denominator: solution.b.magnitude.description)
                        MathText(text: "= 0")
                    }.padding(.vertical, 6)
                }
                if !solution.steps.isEmpty {
                    MathLine("\(solution.hasNegativeInput ? "q₀" : "q") = \(powerSum(solution.steps))")
                    MathLine("\(solution.hasNegativeInput ? "q₀" : "q") = \(solution.steps.map { $0.chosen.power.description }.joined(separator: " + ")) = \(solution.magnitudeQuotient)")
                } else {
                    MathLine("\(solution.hasNegativeInput ? "q₀" : "q") = 0")
                }
                MathLine("\(solution.hasNegativeInput ? "r₀" : "r") = \(solution.magnitudeRemainder)")
            }

            if solution.hasNegativeInput { signCorrection(solution) }
            answer(solution)
        }
        .padding(20).padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppStyle.paper, in: UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))
    }

    private func stepView(_ step: DivisionStep, solution: BinaryDivisionSolution) -> some View {
        let b = solution.b.magnitude.description
        let power = PowerNotation.two(step.chosen.id)
        let sum = powerSum(Array(solution.steps.prefix(step.id + 1)))
        return VStack(alignment: .leading, spacing: 10) {
            Text("Шаг \(step.id + 1)").font(.headline).foregroundStyle(AppStyle.accent)
            BinaryLengthView(info: step.before)
            MathLine("l = \(step.before.length) − \(solution.divisorLength.length) = \(step.lengthDifference)")
            if step.lengthDifference > 0 {
                MathLine("l − 1 = \(step.lengthDifference) − 1 = \(step.lengthDifference - 1)")
            }
            if step.trial.id != step.chosen.id {
                MathLine("\(PowerNotation.two(step.trial.id)) · \(b) = \(step.trial.multiple) > \(step.before.number)")
            }
            MathLine("\(power) · \(b) = \(step.chosen.multiple) ≤ \(step.before.number)")
            MathLine("\(PowerNotation.two(step.chosen.id + 1)) · \(b) = \(step.nextMultiple) > \(step.before.number)")
                .foregroundStyle(.secondary)
            if explanations { note("Выбрана наибольшая степень, при которой сдвинутый делитель ещё помещается в текущее делимое.") }
            MathLine("\(step.before.number) − \(step.chosen.multiple) = \(step.after)")
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        FloorFractionView(numerator: solution.a.magnitude.description, denominator: b)
                        MathText(text: "=")
                        FloorFractionView(numerator: "\(step.before.number) − \(power) · \(b)", denominator: b)
                        MathText(text: "+ " + sum)
                    }
                    HStack(spacing: 8) {
                        MathText(text: "=")
                        FloorFractionView(numerator: step.after.description, denominator: b)
                        MathText(text: "+ " + sum)
                    }
                }.fixedSize().padding(.vertical, 8)
            }
        }
        .accessibilityIdentifier("divisionStep_\(step.id)")
    }

    private func powerSum(_ steps: [DivisionStep]) -> String {
        steps.map { PowerNotation.two($0.chosen.id) }.joined(separator: " + ")
    }

    private func signCorrection(_ solution: BinaryDivisionSolution) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Учитываем знаки").font(.headline)
            if solution.needsRemainderCorrection {
                note("Делимое отрицательное, остаток ненулевой. Увеличиваем модуль частного на 1 и вычитаем прежний остаток из модуля делителя.")
                MathLine("|q| = \(solution.magnitudeQuotient) + 1 = \(solution.quotient.magnitude)")
                MathLine("r = \(solution.b.magnitude) − \(solution.magnitudeRemainder) = \(solution.remainder)")
            } else {
                note("Поправка остатка не нужна. Знаки делимого и делителя определяют знак частного.")
            }
            MathLine("q = \(solution.quotient),  r = \(solution.remainder)")
        }
    }

    private func answer(_ solution: BinaryDivisionSolution) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ответ").font(.caption).foregroundStyle(AppStyle.accent)
            MathLine(solution.identity).accessibilityIdentifier("divisionIdentity")
            Text("q = \(solution.quotient.description)").font(.system(.title2, design: .serif))
                .textSelection(.enabled).accessibilityIdentifier("divisionQuotient")
            Text("r = \(solution.remainder.description)").font(.system(.title2, design: .serif))
                .textSelection(.enabled).accessibilityIdentifier("divisionRemainder")
            MathLine("0 ≤ \(solution.remainder) < \(solution.b.magnitude)").foregroundStyle(.secondary)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(AppStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}
