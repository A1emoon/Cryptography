import SwiftUI

private enum CipollaStepWindow: Identifiable {
    case reason
    case calculation(CipollaWork)
    var id: String { switch self { case .reason: "reason"; case .calculation: "calculation" } }
}
struct CipollaStudentLine: View {
    let line: CipollaLine
    let p: Natural
    @State private var window: CipollaStepWindow?
    var body: some View {
        StudentMathLine(atoms: line.atoms, workIndices: Set(line.works.keys), identifier: "cipolla_" + line.id,
            onWork: { if let work = line.works[$0] { window = .calculation(work) } }, onReason: { window = .reason })
            .sheet(item: $window) { window in
                switch window {
                case .reason: CipollaExplanationView(explanation: line.explanation)
                case .calculation(let work): CipollaCalculationView(work: work, p: p)
                }
            }
    }
}
struct CipollaView: View {
    @StateObject private var model = CipollaModel()
    @State private var showInput = false
    @State private var showHelp = false
    @State private var showAnswerReason = false
    @State private var didLoad = false
    var body: some View {
        ScrollView {
            if let s = model.solution {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(CipollaPresentation.lines(s)) { line in CipollaStudentLine(line: line, p: s.p) }
                    HStack(alignment: .top, spacing: 7) {
                        MathLine("Ответ: " + CipollaPresentation.answer(s))
                            .accessibilityElement(children: .ignore).accessibilityIdentifier("cipollaAnswer")
                            .accessibilityLabel(s.roots.isEmpty ? "Решений нет" : s.roots.map(\.description).joined(separator: ", "))
                        Button { showAnswerReason = true } label: {
                            Image(systemName: "questionmark.circle").font(.system(size: 15)).frame(width: 32, height: 38)
                        }.buttonStyle(.plain).foregroundStyle(AppStyle.accent)
                            .accessibilityLabel("Как получены корни").accessibilityIdentifier("cipollaAnswerReason")
                    }
                }.padding(AppStyle.contentPadding).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .contain).accessibilityIdentifier("studentSolution")
                    .id(model.calculationID)
            } else if model.isCalculating {
                VStack(spacing: 16) { ProgressView("Вычисляем…"); Button("Отмена") { model.cancel() } }.padding(40)
            } else if let error = model.error {
                VStack(alignment: .leading, spacing: 18) {
                    Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red).accessibilityIdentifier("inputError")
                    Button("Изменить условие") { showInput = true }
                }.padding(AppStyle.contentPadding)
            } else { Button("Задать условие") { showInput = true }.padding(30) }
        }.courseSolutionAppearance()
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar { CoursePageTools(firstTitle: "Изменить условие", firstIcon: "square.and.pencil", firstID: "cipollaInput", firstAction: { showInput = true }, secondTitle: "Об алгоритме", secondIcon: "book.closed", secondID: "cipollaHelp", secondAction: { showHelp = true }) }
            .sheet(isPresented: $showInput) { CipollaInputView(model: model) }
            .sheet(isPresented: $showHelp) { CipollaInfoView() }
            .sheet(isPresented: $showAnswerReason) {
                if let s = model.solution { CipollaExplanationView(explanation: CipollaPresentation.rootsReason(s)) }
            }
            .task { if !didLoad { didLoad = true; model.solve() } }
            .onDisappear { if model.isCalculating { model.cancel() } }
    }
}
#if !os(watchOS)
private struct CipollaInputView: View {
    @ObservedObject var model: CipollaModel
    @State private var a = ""
    @State private var p = ""
    @State private var delta = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TaskFormulaView(formula: "x² ≡ a (mod p)", definitions: "a — подкоренное число; p — простой модуль; x — искомый корень.")
                    field("a · Подкоренное число", id: "a", text: $a)
                    field("p · Простой модуль", id: "p", text: $p)
                    field("δ · Необязательно", id: "delta", text: $delta, placeholder: "Автоматически: 0, 1, 2…")
                    MathExplainedText(text: "Оставьте δ пустым для подбора по порядку, как на доске. При ручном выборе разность δ² − a должна быть квадратичным невычетом либо нулём по p.")
                    Text("Точная проверка простоты: p ≤ 2⁶⁴ − 1. Значения a и δ — целые числа любой длины.").font(.footnote).foregroundStyle(.secondary)
                    Menu("Примеры") {
                        Button("С пары · 29 mod 109") { a = "29"; p = "109"; delta = "" }
                        Button("Два корня · 10 mod 13") { a = "10"; p = "13"; delta = "" }
                        Button("Нет корней · 2 mod 3") { a = "2"; p = "3"; delta = "" }
                        Button("Нулевой корень") { a = "0"; p = "109"; delta = "" }
                    }
                    Button {
                        focused = nil; model.a = a; model.p = p; model.delta = delta; model.solve(); dismiss()
                    } label: { Text("Решить").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8) }
                        .buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("cipollaSolve")
                }.padding(AppStyle.contentPadding)
            }.background(AppStyle.background)
                .navigationTitle("Условие").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() }.accessibilityIdentifier("closeCipollaInput") }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Готово") { focused = nil } }
                }
        }.keyboardType(.numbersAndPunctuation).textInputAutocapitalization(.never).autocorrectionDisabled()
            .presentationDetents([.large]).onAppear { a = model.a; p = model.p; delta = model.delta }
    }
    private func field(_ title: String, id: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack{TextField(placeholder, text: text, axis: .vertical).lineLimit(1...4).monospacedDigit()
                .focused($focused,equals:id).accessibilityIdentifier("input_" + id);Button{text.wrappedValue="";focused=id}label:{Image(systemName:"xmark.circle.fill").foregroundStyle(.tertiary).frame(width:28,height:28)}.buttonStyle(.plain).accessibilityLabel("Очистить "+title).accessibilityIdentifier("clear_"+id)}
        }.padding(16).background(AppStyle.paper, in: RoundedRectangle(cornerRadius: 14))
    }
}

#endif
