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
                    ForEach(CourseTask.allCases){task in
                        NavigationLink{CourseTaskView(kind:task)}label:{TaskCard(title:task.title,subtitle:task.subtitle,formula:task.formula,example:task.example,icon:task.symbol)}.buttonStyle(.plain).accessibilityIdentifier("task_"+(task == .modularDivision ? "modular_division":task.id))
                    }
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
            .navigationTitle("Задачи")
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
            MathText(text:formula).padding(.vertical,4).foregroundStyle(AppStyle.accent)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            MathText(text:example).padding(.vertical,4).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(AppStyle.paper, in: RoundedRectangle(cornerRadius: 22))
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }
}

