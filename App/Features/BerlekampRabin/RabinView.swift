import SwiftUI

private enum RabinStepWindow: Identifiable {
    case reason
    case calculation(RabinWork)
    var id: String { switch self { case .reason: "reason"; case .calculation: "calculation" } }
}
private struct RabinStudentLine: View {
    let line: RabinLine
    let q: Natural
    @State private var window: RabinStepWindow?
    var body: some View {
        StudentMathLine(atoms: line.atoms, workIndices: line.work == nil ? [] : line.workIndices,
            identifier: "rabin_" + line.id,
            onWork: { index in if let work = line.workOverrides[index] ?? line.work { window = .calculation(work) } },
            onReason: { window = .reason })
            .sheet(item: $window) { window in
                switch window {
                case .reason: RabinExplanationView(explanation: line.explanation)
                case .calculation(let work): RabinCalculationView(work: work, q: q)
                }
            }
    }
}
struct RabinView: View {
    @StateObject private var model = RabinModel()
    @State private var showInput = false
    @State private var showHelp = false
    @State private var showAnswerReason = false
    @State private var didLoad = false
    var body: some View {
        ScrollView {
            if let s = model.solution {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(RabinPresentation.lines(s)) { line in RabinStudentLine(line: line, q: s.q) }
                    HStack(alignment: .top, spacing: 7) {
                        MathLine("Ответ: " + RabinFormat.answer(s))
                            .accessibilityElement(children: .ignore).accessibilityIdentifier("rabinAnswerValue")
                            .accessibilityLabel(RabinFormat.answer(s))
                        Button { showAnswerReason = true } label: {
                            Image(systemName: "questionmark.circle").font(.system(size: 15))
                                .frame(width: 32, height: 38)
                        }.buttonStyle(.plain).foregroundStyle(AppStyle.accent)
                            .accessibilityLabel("Как читать ответ").accessibilityIdentifier("rabinAnswerReason")
                    }
                }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .contain).accessibilityIdentifier("studentSolution")
                    .id(model.calculationID)
            } else if model.isCalculating {
                VStack(spacing: 16) { ProgressView("Вычисляем…"); Button("Отмена") { model.cancel() } }.padding(40)
            } else if let error = model.error {
                VStack(alignment: .leading, spacing: 18) {
                    Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red).accessibilityIdentifier("inputError")
                    Button("Изменить условие") { showInput = true }
                }.padding(22)
            } else {
                Button("Задать условие") { showInput = true }.padding(30)
            }
        }.background(AppStyle.paper)
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showInput = true } label: { Image(systemName: "square.and.pencil") }
                        .accessibilityLabel("Изменить условие").accessibilityIdentifier("rabinInput")
                    Button { showHelp = true } label: { Image(systemName: "book.closed") }
                        .accessibilityLabel("Об алгоритме и обозначениях").accessibilityIdentifier("rabinHelp")
                }
            }
            .sheet(isPresented: $showInput) { RabinInputView(model: model) }
            .sheet(isPresented: $showHelp) { RabinHelpView() }
            .sheet(isPresented: $showAnswerReason) {
                RabinExplanationView(explanation: RabinExplanation(title: "Как читать ответ", text: "[r]q обозначает класс всех целых чисел r + kq, где k — любое целое. Каждый различный корень записан один раз. ∅ означает отсутствие решений; ℤq — подходят все остатки по q.", terms: [.root, .multiplicity, .finiteField]))
            }
            .task { if !didLoad { didLoad = true; model.solve() } }
            .onDisappear { model.cancel() }
    }
}
private struct RabinInputView: View {
    @ObservedObject var model: RabinModel
    @State private var f = ""
    @State private var q = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TaskFormulaView(formula: "f(x) ≡ 0 (mod q)", definitions: "Найти все корни многочлена f по простому модулю q.")
                    RabinExplainedText(text: "Введите коэффициенты многочлена от старшей степени к свободному члену. Внутренние нули не пропускайте: 1, 0, 2 означает x² + 2.")
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Коэффициенты f").font(.caption).foregroundStyle(.secondary)
                        TextField("1, 3, 2, 1", text: $f, axis: .vertical).lineLimit(1...5).monospacedDigit()
                            .focused($focused).accessibilityIdentifier("input_f")
                        if let coefficients = try? PolynomialSolver.parse(f, name: "f") {
                            MathLine(RabinFormat.signed(coefficients)).foregroundStyle(AppStyle.accent)
                        }
                    }.padding(16).background(AppStyle.paper, in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Простой модуль q").font(.caption).foregroundStyle(.secondary)
                        TextField("7", text: $q).monospacedDigit().focused($focused).accessibilityIdentifier("input_q")
                    }.padding(16).background(AppStyle.paper, in: RoundedRectangle(cornerRadius: 14))
                    Text("Точная проверка простоты: q ≤ 2⁶⁴ − 1. Коэффициенты — целые числа любой длины. Для q = 2 проверяются оба остатка.").font(.footnote).foregroundStyle(.secondary)
                    Menu("Примеры") {
                        Button("С лекции · один корень") { f = "1,3,2,1"; q = "7" }
                        Button("Два корня и подбор δ") { f = "1,0,4"; q = "5" }
                        Button("Повторные и нулевой корни") { f = "1,-2,1,0,0,0"; q = "7" }
                        Button("Нет корней") { f = "1,0,1"; q = "7" }
                        Button("Нулевой многочлен") { f = "0"; q = "7" }
                    }
                    Button { focused = false; model.solve(coefficients: f, q: q); dismiss() } label: {
                        Text("Решить").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("rabinSolve")
                }.padding(22)
            }.background(AppStyle.background)
                .navigationTitle("Условие").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }.accessibilityIdentifier("closeRabinInput")
                }; ToolbarItemGroup(placement: .keyboard) {
                    Spacer(); Button("Готово") { focused = false }
                } }
        }.keyboardType(.numbersAndPunctuation).textInputAutocapitalization(.never).autocorrectionDisabled()
            .presentationDetents([.large])
            .onAppear { f = model.coefficients; q = model.q }
    }
}
private struct RabinHelpView: View {
    var body: some View {
        StudentDetailSheet(title: "Алгоритм Берлекэмпа–Рабина", large: true) {
            RabinExplainedText(text: "Находим все корни многочлена по простому модулю. Сначала проверяем нулевой корень. Остальные выделяем с помощью малой теоремы Ферма и НОД. Если НОД равен 1, ненулевых корней нет. Линейный множитель сразу даёт корень; многочлен большей степени разделяем сдвигами δ.")
            RabinExplainedText(text: "Для нечётного q используем половину показателя q − 1 и НОД с многочленом, указанным ниже. Нужен собственный множитель: степень больше нуля и меньше степени текущего многочлена. И при НОД 1, и при НОД, равном всему многочлену, пробуем следующее δ. Обрабатываем обе части разложения и проверяем каждый корень подстановкой в исходный f.")
            StudentFormulaView(atoms: [.text("s ="), .fraction("q − 1", "2")])
            StudentFormulaView(atoms: [.text("h = gcd(g,"), .fractionPower("(x + δ)", "q − 1", "2"), .text("− 1)")])
            Text("Как читать лист").font(.headline)
            RabinExplainedText(text: "На листе только запись решения. Значок ↗ у выражения открывает вспомогательный расчёт: степень, удвоение–сложение или деление уголком. Значок ? справа объясняет именно эту строку: почему выбрана формула и как получился результат. Синие слова в пояснениях открывают определения. После закрытия окна вы остаётесь на том же месте.")
            Text("Словарь").font(.headline)
            RabinTermLinks(terms: RabinTerm.allCases)
            Text("Границы метода").font(.headline)
            RabinExplainedText(text: "Здесь q — простое число, не степень простого числа. Точная проверка поддерживает q < 2⁶⁴, коэффициенты имеют произвольную длину. Последовательный перебор δ повторяет лекцию и даёт воспроизводимую запись; вероятностную оценку времени случайного алгоритма ему не приписываем. Расчёт можно отменить. Повторные корни в ответе записываются один раз, а у нулевого многочлена ответ — всё поле.")
            Link("Математическое описание: MIT, Finite field arithmetic, §3.10", destination: URL(string: "https://math.mit.edu/classes/18.783/2025/LectureNotes3.pdf")!)
        }
    }
}
