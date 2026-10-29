import SwiftUI

struct DivisionInfoView: View {
    @Environment(\.dismiss) private var dismiss
    private let steps = [
        ("Определяем двоичные длины", "Для положительных чисел находим l₂(a) и l₂(b) по соседним степеням двойки. Обозначаем l = l₂(a) − l₂(b)."),
        ("Строим удвоения делителя", "Получаем b, 2b, 4b, 8b и так далее до первого значения, которое больше делимого. Знак << над стрелкой обозначает сдвиг влево на один бит — умножение на 2. Сохраняем показатели степеней."),
        ("Выбираем наибольшую подходящую степень", "Проверяем показатели l и l − 1. Если 2ˡ·b не превышает текущее делимое, выбираем 2ˡ. Иначе выбираем 2ˡ⁻¹."),
        ("Вычитаем и пополняем частное", "Вычитаем 2ˡ·b и прибавляем к частному 2ˡ. Если выбран показатель l − 1, вычитаем 2ˡ⁻¹·b и прибавляем 2ˡ⁻¹. В решении показываем рекурсивное преобразование целой части дроби."),
        ("Повторяем", "Для нового делимого снова определяем длину, выбираем степень и вычитаем. Когда число меньше делителя, останавливаемся."),
        ("Записываем ответ", "Частное q равно сумме выбранных степеней двойки. Последнее число — остаток r. Записываем a = b·q + r и проверяем границы остатка.")
    ]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Деление с остатком").font(.title2.weight(.semibold))
                    Text("Вариант из конспекта: частное формируется как сумма степеней двойки. Числа записываем в десятичном виде, а двоичная структура определяет выбор вычитаемых кратных.")
                        .foregroundStyle(.secondary)
                    TaskFormulaView(formula: "a = b · q + r", definitions: "a — делимое; b — делитель; q — частное; r — остаток.")
                    Text("Рекуррентные формулы").font(.headline)
                    MathLine("l = l₂(a) − l₂(b)")
                    MathLine("a ≥ 2ˡ · b > 0")
                    recurrence(power: "2ˡ")
                    Text("Если кратное с показателем l не подходит, используем l − 1:")
                        .font(.footnote).foregroundStyle(.secondary)
                    MathLine("2ˡ⁻¹ · b ≤ a < 2ˡ · b")
                    recurrence(power: "2ˡ⁻¹")
                    Text("⌊x⌋ обозначает целую часть: наибольшее целое, не превосходящее x.")
                        .font(.footnote).foregroundStyle(.secondary)
                    ForEach(steps.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 12) {
                            Text(String(index + 1)).font(.subheadline.weight(.semibold)).foregroundStyle(AppStyle.accent)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(steps[index].0).font(.headline)
                                Text(steps[index].1).font(.callout).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Divider()
                    Text("Ноль и отрицательные числа").font(.headline)
                    Text("Деление на 0 недопустимо. Если делимое равно 0, частное и остаток равны 0. Для отрицательных входов сначала делим модули чисел, затем восстанавливаем знаки с отдельным пояснением. Во всех случаях ответ удовлетворяет 0 ≤ r < |b|. Это евклидово деление; при отрицательном делителе частное не обязано совпадать с округлением a/b вниз.")
                        .font(.callout).foregroundStyle(.secondary)
                }.padding(22)
            }
            .background(AppStyle.background).navigationTitle("Об алгоритме").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() }.accessibilityIdentifier("closeAlgorithm") } }
        }
        .presentationDetents([.large]).presentationDragIndicator(.visible)
    }

    private func recurrence(power: String) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                FloorFractionView(numerator: "a", denominator: "b")
                MathText(text: "=")
                FloorFractionView(numerator: "a − \(power) · b", denominator: "b")
                MathText(text: "+ \(power)")
            }.padding(.vertical, 8)
        }
    }

}
