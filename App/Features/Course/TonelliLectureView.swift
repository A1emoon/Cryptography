import SwiftUI

struct CourseTonelliSolution: View {
    let s: TonelliSolution
    var body: some View {
        ForEach(TonelliLecture.lines(s)) { line in
            StudyLine(id: line.id, atoms: line.atoms.map(atom), reason: StudyReason(title: reasonTitle(line.id), text: line.explanation, equations: line.equations, references: line.references), works: line.works.mapValues(work), singleRow: true)
        }
    }
    private func atom(_ atom: TonelliLectureAtom) -> StudentMathAtom {
        switch atom {
        case .text(let s): .text(s)
        case .rich(let s): .rich(s)
        case .power(let a, let b): b == "1" ? .text(a) : .power(a, b)
        case .fraction(let a, let b): .fraction(a, b)
        case .fractionPower(let a, let b, let c): .fractionPower(a, b, c)
        case .symbol(let a, let b): .symbol(a, b)
        }
    }
    private func work(_ work: TonelliLectureWork) -> StudyWork {
        switch work {
        case .product(let a, let b, let p): .product(a, b, p)
        }
    }
    private func reasonTitle(_ id: String) -> String {
        if id == "tonelliCriterion" { return "Проверка существования корней" }
        if id == "tonelliK" { return "Откуда показатель k" }
        if id == "tonelliB" { return "Почему выбираем B" }
        if id.hasPrefix("tonelliRegroup") { return "Понижение внешней степени" }
        if id.hasPrefix("tonelliCorrection") { return "Домножение на корень из единицы" }
        if id == "tonelliMultiplyByA" { return "Умножение на исходное сравнение" }
        if id.hasPrefix("tonelliExtract") { return "Извлечение корня" }
        return "Почему эта запись верна"
    }
}


struct TonelliLectureHelp: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("1. Проверяем разрешимость").font(.headline)
            MathExplainedText(text: "Для квадратного сравнения вычисляем символ Лежандра. Для кубического — проверяем a^((p−1)/3)=1. Здесь p — простой модуль, а ненулевое a рассматривается как остаток по p.")
            Text("2. Находим s, r и k").font(.headline)
            StudentFormulaView(atoms: [.rich("p−1 = n^s r"), .text(";"), .rich("(a^r)^{n·k} ≡ 1")])
            MathExplainedText(text: "n равно 2 или 3, r не делится на n. k — наименьшее положительное число в последнем равенстве; его находим последовательными n-ми степенями a^r. Если a^r уже равно 1, этот поиск пропускается.")
            Text("3. Подбираем b и B").font(.headline)
            StudentFormulaView(atoms: [.text("B ≡"), .fractionPower("b", "p−1", "n"), .text(";"), .rich("B^n ≡ 1, B ≠ 1")])
            MathExplainedText(text: "Автоматически перебираем b=2,3,… до первого n-го степенного невычета. Для квадратов B=−1; для кубов также вычисляем B².")
            Text("4. Понижаем внешнюю степень").font(.headline)
            StudentFormulaView(atoms: [.rich("Y^n ≡ 1"), .text("⇒"), .rich("Y·B^j ≡ 1")])
            MathExplainedText(text: "Вычисляем Y и выбираем j из 0,…,n−1. Затем подставляем вместо B степень b, складываем показатели и выносим общую n-ю степень. Важно: из Y^n=1 не следует Y=1; после каждого понижения Y проверяется заново.")
            Text("5. Получаем все корни").font(.headline)
            MathExplainedText(text: "Дойдя до a^r·b^C=1, домножаем на a=x^n и выделяем n-ю степень. Если n=3 и r≡1 по 3, перед этим возводим равенство в квадрат. Выражение в скобках даёт x₁. Остальные квадратные корни: −x₁; остальные кубические: x₁B, x₁B². Каждое значение независимо проверяется подстановкой.")
        }
    }
}
