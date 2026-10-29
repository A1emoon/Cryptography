import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Теория чисел").font(.largeTitle.weight(.bold)).tracking(-1)
                        .accessibilityAddTraits(.isHeader)
                    Text("Теоретико-числовые методы\nв криптографии")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Выберите задачу").font(.title2.weight(.semibold)).padding(.top, 8)
                    NavigationLink {
                        CalculatorView()
                    } label: {
                        TaskCard(title: "Удвоение–сложение", subtitle: "Произведение по модулю",
                                 formula: "r = (a · b) mod m", example: "(78 · 96) mod 273 = 117", icon: "multiply")
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("task_doubling")
                    NavigationLink {
                        DivisionView()
                    } label: {
                        TaskCard(title: "Двоичное деление уголком", subtitle: "Частное как сумма степеней двойки",
                                 formula: "a = b · q + r", example: "1530 = 41 · 37 + 13", icon: "divide")
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("task_division")
                    NavigationLink {
                        ModularView(isDivision: false)
                    } label: {
                        TaskCard(title: "Обратное по модулю", subtitle: "Бинарный Евклид и степени двойки",
                                 formula: "a⁻¹ mod m = x", example: "113⁻¹ mod 512 = 145", icon: "arrow.triangle.2.circlepath")
                    }.buttonStyle(.plain).accessibilityIdentifier("task_inverse")
                    NavigationLink {
                        ModularView(isDivision: true)
                    } label: {
                        TaskCard(title: "Деление по модулю", subtitle: "Через обратное или третью строку",
                                 formula: "(u / v) mod m = x", example: "(153 / 179) mod 283 = 72", icon: "divide.circle")
                    }.buttonStyle(.plain).accessibilityIdentifier("task_modular_division")
                    NavigationLink {
                        PolynomialView()
                    } label: {
                        TaskCard(title: "Многочлены: удвоение–сложение", subtitle: "Сдвиги и приведение коэффициентов",
                                 formula: "R(α) = A(α) · B(α) mod (M(α), p)",
                                 example: "mod (α⁴ + 2α + 2, 5) → 3α³ + α²", icon: "function")
                    }.buttonStyle(.plain).accessibilityIdentifier("task_polynomial")
                    NavigationLink {
                        CipollaView()
                    } label: {
                        TaskCard(title: "Алгоритм Чиполлы", subtitle: "Квадратные корни по простому модулю",
                                 formula: "x² ≡ a (mod p)", example: "x² ≡ 29 (mod 109) ⇒ x ≡ 47, 62", icon: "x.squareroot")
                    }.buttonStyle(.plain).accessibilityIdentifier("task_cipolla")
                    NavigationLink {
                        RabinView()
                    } label: {
                        TaskCard(title: "Алгоритм Берлекэмпа–Рабина", subtitle: "Корни многочлена по простому модулю",
                                 formula: "f(x) ≡ 0 (mod q)", example: "x³ + 3x² + 2x + 1 ≡ 0 (mod 7) → [1]₇", icon: "function")
                    }.buttonStyle(.plain).accessibilityIdentifier("task_rabin")
                }
                .padding(22)
            }
            .background(AppStyle.background)
            .navigationTitle("Задания")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppStyle.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

private struct TaskCard: View {
    let title: String
    let subtitle: String
    let formula: String
    let example: String
    let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon).font(.title3.weight(.semibold))
                    .foregroundStyle(AppStyle.accent).frame(width: 42, height: 42)
                    .background(AppStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            Text(formula).font(.system(.title3, design: .serif)).foregroundStyle(AppStyle.accent)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            Text(example).font(.system(.callout, design: .serif)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(AppStyle.paper, in: RoundedRectangle(cornerRadius: 22))
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }
}

