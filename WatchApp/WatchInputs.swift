import SwiftUI

struct WatchValueField: View {
    let title: String
    let key: String
    @Binding var value: String
    @State private var edit = false
    var body: some View {
        Button { edit = true } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(value.isEmpty ? "Ввести" : value).font(.system(.body, design: .monospaced))
                    .lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.accessibilityIdentifier("input_"+key)
            .sheet(isPresented: $edit) { WatchKeypad(title: title, value: $value) }
    }
}
private struct WatchKeypad: View {
    let title: String
    @Binding var value: String
    @State private var draft = ""
    @Environment(\.dismiss) private var dismiss
    private let keys = ["7","8","9","4","5","6","1","2","3","-","0",","]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    TextField(title, text: $draft).font(.system(.body, design: .monospaced)).accessibilityIdentifier("watchNumberDraft")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
                        ForEach(keys, id: \.self) { key in Button(key) { draft += key }.accessibilityIdentifier("watchKey_"+key) }
                    }
                    HStack { Button("Очистить") { draft = "" }; Button { if !draft.isEmpty { draft.removeLast() } } label: { Image(systemName: "delete.left") } }
                    CourseDisclosureGroup("Другие символы") {
                        HStack { ForEach(["^","*"," "], id: \.self) { key in Button(key == " " ? "␣" : key) { draft += key } } }
                    }
                }.padding(.horizontal, 4)
            }.navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Готово") { value = draft; dismiss() }.accessibilityIdentifier("watchNumberDone") }
                }
        }.onAppear { draft = value }
    }
}
struct CourseInputView: View {
    @ObservedObject var model: CourseTaskModel
    @State private var i = CourseInputs()
    @Environment(\.dismiss) private var dismiss
    private var kind: CourseTask { model.kind }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(kind.formula).font(.system(.caption, design: .serif)).fixedSize(horizontal: false, vertical: true)
                    if kind == .inverse {
                        Picker("Объект", selection: $i.polynomials) { Text("Числа").tag(false); Text("Многочлены").tag(true) }.accessibilityIdentifier("inverseDomain")
                    }
                    if kind == .tonelli {
                        Picker("Степень", selection: $i.degree) { Text("x²").tag(2); Text("x³").tag(3) }.accessibilityIdentifier("rootDegree")
                    }
                }
                fields
                Section {
                    Button("Пример из конспекта") { let domain = i.polynomials; i = kind.initial; i.polynomials = domain }
                    CourseDisclosureGroup("Параметры") {
                        if kind == .inverse && i.polynomials {
                            Picker("Метод", selection: $i.polyMethod) { ForEach(PolynomialInverseMethod.allCases, id: \.self) { Text($0.title).tag($0) } }
                        } else if kind == .inverse || kind == .modularDivision {
                            Picker("Метод", selection: $i.method) { ForEach(ModularMethod.allCases.filter { kind == .modularDivision || $0 != .direct }) { Text($0.title).tag($0) } }
                        } else if kind == .order {
                            WatchValueField(title: "Разложение · необязательно", key: "factors", value: $i.factors)
                        }
                    }
                    Button("Решить") { model.solve(i); dismiss() }.buttonStyle(.borderedProminent).accessibilityIdentifier("courseSolve")
                }
            }.navigationTitle("Условие")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() }.accessibilityIdentifier("closeCourseInput") } }
        }.onAppear { i = model.inputs }
    }
    @ViewBuilder private var fields: some View {
        if kind == .inverse && i.polynomials {
            WatchValueField(title: "A(α) · коэффициенты", key: "polyA", value: $i.polyA)
            WatchValueField(title: "M(α) · модуль", key: "polyM", value: $i.polyM)
            WatchValueField(title: "p · простой модуль", key: "p", value: $i.p)
        } else {
            if kind == .modularDivision { WatchValueField(title: "u · числитель", key: "u", value: $i.u) }
            WatchValueField(title: kind == .polynomial ? "A(α) · коэффициенты" : kind == .modularDivision ? "v · знаменатель" : kind == .division ? "a · делимое" : "a", key: "a", value: $i.a)
            if [.doubling, .division, .polynomial].contains(kind) { WatchValueField(title: kind == .polynomial ? "B(α) · коэффициенты" : kind == .division ? "b · делитель" : "b", key: "b", value: $i.b) }
            if kind != .division && kind != .tonelli { WatchValueField(title: kind == .polynomial ? "M(α) · модуль" : "m · модуль", key: "m", value: $i.m) }
            if kind == .tonelli || kind == .polynomial { WatchValueField(title: "p · простой модуль", key: "p", value: $i.p) }
        }
    }
}
struct CipollaInputView: View {
    @ObservedObject var model: CipollaModel
    @State private var a = ""
    @State private var p = ""
    @State private var delta = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Text("x² ≡ a (mod p)").font(.system(.body, design: .serif))
                WatchValueField(title: "a · подкоренное число", key: "a", value: $a)
                WatchValueField(title: "p · простой модуль", key: "p", value: $p)
                CourseDisclosureGroup("Параметры") { WatchValueField(title: "δ · автоматически", key: "delta", value: $delta) }
                Button("Пример из конспекта") { a = "29"; p = "109"; delta = "" }
                Button("Решить") { model.a = a; model.p = p; model.delta = delta; model.solve(); dismiss() }
                    .buttonStyle(.borderedProminent).accessibilityIdentifier("cipollaSolve")
            }.navigationTitle("Условие").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
        }.onAppear { a = model.a; p = model.p; delta = model.delta }
    }
}
struct RabinInputView: View {
    @ObservedObject var model: RabinModel
    @State private var f = ""
    @State private var q = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Text("f(x) ≡ 0 (mod q)").font(.system(.body, design: .serif))
                WatchValueField(title: "f · коэффициенты", key: "f", value: $f)
                WatchValueField(title: "q · простой модуль", key: "q", value: $q)
                Button("Пример из конспекта") { f = "1,3,2,1"; q = "7" }
                Button("Решить") { model.solve(coefficients: f, q: q); dismiss() }.buttonStyle(.borderedProminent).accessibilityIdentifier("rabinSolve")
            }.navigationTitle("Условие").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
        }.onAppear { f = model.coefficients; q = model.q }
    }
}
