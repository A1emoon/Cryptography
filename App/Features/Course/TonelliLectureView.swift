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
        case .congruence(let modulus,let unequal): .congruence(String(modulus),unequal:unequal)
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
        if id == "tonelliInitialOrder" { return "Фактический порядок aʳ" }
        if id == "tonelliNonResidueOrder" { return "Порядок выбранного невычета" }
        if id.hasPrefix("tonelliCorrectedOrder") { return "Порядок исправленного элемента" }
        if id.hasPrefix("tonelliCorrected") { return "Вычисление исправленного элемента" }
        if id == "tonelliCubicOrderBound" { return "Возможные порядки кубического вычета" }
        if id == "tonelliCubicOrderProof" { return "Почему порядок точный" }
        if id == "tonelliUnityOrder" { return "Почему порядок B равен трём" }
        if id == "tonelliCubicCompleteness" { return "Почему других корней нет" }
        if id.hasPrefix("tonelliCubicVerification") { return "Проверка подстановкой" }
        if id == "tonelliK" { return "Откуда показатель k" }
        if id == "tonelliB" { return "Почему выбираем B" }
        if id.hasPrefix("tonelliRegroup") { return "Выделение общей степени" }
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
            Text("2. Находим s, r и порядок").font(.headline)
            StudentFormulaView(atoms: [.rich("p−1 = n^s r"), .text(";"), .rich("P_p(a^r) ∣ n^{s−1}")])
            MathExplainedText(text: "n равно 2 или 3, r не делится на n. Начинаем с a^r и находим его фактический порядок последовательными n-ми степенями. При r=1 дополнительная степень не нужна. Если a^r=1, корректировки не требуются. В кубическом варианте сначала доказываем точный порядок: (a^r)^t≡1 и (a^r)^(t/3)≢1 при t — степени тройки. Лишь после этого записываем 3k=P_p(a^r)=t. Например, 13⁶≡53≢1, 13¹⁸≡58≢1 и 13⁵⁴≡1 по 163 дают P₁₆₃(13²)=27 и k=9.")
            Text("3. Подбираем невычет b").font(.headline)
            StudentFormulaView(atoms: [.text("B"), .congruence("p"), .fractionPower("b", "p−1", "n"), .text(";"), .power("B","n"), .congruence("p"), .text("1; B"), .congruence("p",unequal:true), .text("1")])
            MathExplainedText(text: "Перебираем b=2,3,… до первого n-го степенного невычета. В квадратном случае находим порядок b^r: он равен 2^s, а b^((p−1)/2)=−1. В кубическом варианте используем B=b^((p−1)/3) и вычисляем B² и B³.")
            Text("4. Корректируем элемент и уменьшаем порядок").font(.headline)
            StudentFormulaView(atoms: [.power("Y","n"), .congruence("p"), .text("1 ⇒ ∃j: Y·"), .power("B","j"), .congruence("p"), .text("1")])
            MathExplainedText(text: "Для квадрата пусть текущий элемент имеет порядок t. Его степень t/2 равна −1. Умножаем её на b^((p−1)/2)=−1, выносим общую степень t/2 и получаем исправленный элемент c_i. Вычисляем его фактический порядок и выбираем следующую корректировку сразу по нему: например, возможен скачок 8→2→1. Для куба сохраняется последовательное понижение внешней степени с подбором B^j, как в фотографиях. Из Y^n=1 не следует Y=1; значение внутреннего выражения обязательно проверяем.")
            Text("5. Получаем все корни").font(.headline)
            MathExplainedText(text: "Дойдя до a^r·b^C=1, домножаем на a=x^n и выделяем n-ю степень. Если n=3 и r≡1 по 3, перед этим возводим равенство в квадрат. Выражение в скобках даёт x₁. Остальные квадратные корни: −x₁; остальные кубические: x₁B, x₁B². Поскольку B³≡1 и B≢1, элементы 1,B,B² различны и умножение на них сохраняет куб x₁. Каждый найденный корень проверяем явным равенством xᵢ³=pq+a. Три различных корня исчерпывают решения: ненулевой многочлен степени 3 над полем имеет не более трёх корней.")
        }
    }
}
