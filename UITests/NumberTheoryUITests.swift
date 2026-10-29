import XCTest

final class NumberTheoryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    @MainActor
    func testDefaultSolutionAndAlgorithmDescription() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["task_doubling"].tap()
        XCTAssertTrue(app.otherElements["doublingFormula"].exists || app.staticTexts["r = (a · b) mod m"].exists)
        XCTAssertTrue(app.buttons["algorithmInfo"].waitForExistence(timeout: 10))
        capture("Главный экран")
        app.buttons["algorithmInfo"].tap()
        XCTAssertTrue(app.staticTexts["Как это работает"].waitForExistence(timeout: 5))
        capture("Описание алгоритма")
        app.buttons["closeAlgorithm"].tap()
        scrollToAnswer(app)
        XCTAssertEqual(app.staticTexts["answer"].label, "117")
        capture("Таблица и ответ")
        XCTAssertTrue(app.staticTexts["doublingFactor"].exists)
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testNegativeInputOneAndInvalidModulus() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["task_doubling"].tap()
        replace(app, field: "a", with: "-1000")
        replace(app, field: "b", with: "1")
        app.buttons["solve"].tap()
        scrollToAnswer(app)
        XCTAssertEqual(app.staticTexts["answer"].label, "92")
        for _ in 0..<5 { app.swipeDown() }
        replace(app, field: "m", with: "0")
        app.buttons["solve"].tap()
        XCTAssertTrue(app.staticTexts["inputError"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["answer"].exists)
    }

    @MainActor
    func testDivisionClassExampleAndNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["task_division"].waitForExistence(timeout: 10))
        capture("Выбор задания")
        app.buttons["task_division"].tap()
        XCTAssertTrue(app.staticTexts["a = b · q + r"].exists)
        capture("Формула и ввод деления")
        app.buttons["algorithmInfo"].tap()
        XCTAssertTrue(app.staticTexts["Деление с остатком"].waitForExistence(timeout: 5))
        app.buttons["closeAlgorithm"].tap()
        scrollTo(app, identifier: "divisionStep_0")
        capture("Шаг двоичного деления")
        scrollTo(app, identifier: "divisionQuotient")
        XCTAssertEqual(app.staticTexts["divisionQuotient"].label, "q = 37")
        XCTAssertEqual(app.staticTexts["divisionRemainder"].label, "r = 13")
        capture("Ответ двоичного деления")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["task_doubling"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDivisionInputAndZeroDivisor() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["task_division"].tap()
        replace(app, field: "a", with: "13")
        replace(app, field: "b", with: "7")
        app.buttons["solve"].tap()
        scrollTo(app, identifier: "divisionQuotient")
        XCTAssertEqual(app.staticTexts["divisionQuotient"].label, "q = 1")
        XCTAssertEqual(app.staticTexts["divisionRemainder"].label, "r = 6")
        for _ in 0..<7 { app.swipeDown() }
        replace(app, field: "b", with: "0")
        app.buttons["solve"].tap()
        XCTAssertTrue(app.staticTexts["inputError"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["divisionQuotient"].exists)
    }

    @MainActor
    func testModularInverseMethodsAndDescription() throws {
        let app = XCUIApplication()
        app.launch()
        scrollTo(app, identifier: "task_inverse")
        capture("Четыре задачи")
        app.buttons["task_inverse"].tap()
        XCTAssertTrue(app.buttons["algorithmInfo"].waitForExistence(timeout: 5))
        capture("Ввод обращения")
        app.buttons["algorithmInfo"].tap()
        XCTAssertTrue(app.staticTexts["Сначала — деление пополам"].waitForExistence(timeout: 5))
        app.buttons["closeAlgorithm"].tap()
        scrollTo(app, identifier: "jumpToModularAnswer")
        app.buttons["jumpToModularAnswer"].tap()
        XCTAssertTrue(app.staticTexts["modularAnswer"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["modularAnswer"].isHittable)
        XCTAssertEqual(app.staticTexts["modularAnswer"].label, "145")
        capture("Ответ обращения")
        app.buttons["closeModularAnswer"].tap()
        scrollTo(app, identifier: "modularFrame_1")
        capture("Матрица обращения и нулевые строки")
        scrollBackTo(app, identifier: "modularMethod")
        app.buttons["modularMethod"].tap()
        app.buttons["По степеням двойки"].tap()
        app.buttons["solve"].tap()
        scrollTo(app, identifier: "liftStage_0")
        capture("Подъём по степеням двойки")
        scrollBackTo(app, identifier: "jumpToModularAnswer")
        app.buttons["jumpToModularAnswer"].tap()
        XCTAssertEqual(app.staticTexts["modularAnswer"].label, "145")
        app.buttons["closeModularAnswer"].tap()
        scrollBackTo(app, identifier: "input_m")
        replace(app, field: "m", with: "15")
        scrollTo(app, identifier: "solve")
        app.buttons["solve"].tap()
        XCTAssertTrue(app.staticTexts["inputError"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["modularAnswer"].exists)
    }

    @MainActor
    func testModularFractionAndNonexistentInverse() throws {
        let app = XCUIApplication()
        app.launch()
        scrollTo(app, identifier: "task_modular_division")
        app.buttons["task_modular_division"].tap()
        scrollTo(app, identifier: "jumpToModularAnswer")
        capture("Выбор метода деления по модулю")
        app.buttons["jumpToModularAnswer"].tap()
        XCTAssertTrue(app.staticTexts["modularAnswer"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["modularAnswer"].label, "72")
        XCTAssertTrue(app.staticTexts["modularAnswer"].isHittable)
        capture("Ответ дроби")
        app.buttons["closeModularAnswer"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        scrollTo(app, identifier: "task_inverse")
        app.buttons["task_inverse"].tap()
        replace(app, field: "a", with: "6")
        replace(app, field: "m", with: "15")
        scrollTo(app, identifier: "solve")
        app.buttons["solve"].tap()
        scrollTo(app, identifier: "jumpToModularAnswer")
        app.buttons["jumpToModularAnswer"].tap()
        XCTAssertEqual(app.staticTexts["modularAnswer"].label, "Обратного элемента нет")
        capture("Обратного элемента нет")
    }

    @MainActor
    func testPolynomialExampleTableAndValidation() throws {
        let app = XCUIApplication()
        app.launch()
        scrollTo(app, identifier: "task_polynomial")
        capture("Пять задач")
        app.buttons["task_polynomial"].tap()
        XCTAssertTrue(app.buttons["algorithmInfo"].waitForExistence(timeout: 5))
        capture("Ввод многочленов")
        app.buttons["algorithmInfo"].tap()
        XCTAssertTrue(app.staticTexts["1. Записываем коэффициенты"].waitForExistence(timeout: 5))
        app.buttons["closeAlgorithm"].tap()
        scrollTo(app, identifier: "polynomialShowAnswer")
        app.buttons["polynomialShowAnswer"].tap()
        XCTAssertEqual(app.descendants(matching: .any)["polynomialAnswer"].firstMatch.label, "3α³ + α²")
        capture("Ответ многочленов")
        app.buttons["closePolynomialAnswer"].tap()
        scrollTo(app, identifier: "polynomialShiftFactor")
        XCTAssertTrue(app.descendants(matching: .any)["polynomialTable"].firstMatch.exists)
        capture("Таблица многочленов")
        let table = app.descendants(matching: .any)["polynomialTable"].firstMatch
        table.swipeLeft()
        table.swipeLeft()
        XCTAssertTrue(app.staticTexts["polynomialColumnResult_2"].isHittable)
        XCTAssertEqual(app.staticTexts["polynomialColumnResult_2"].label, "(3, 1, 0, 0)")
        capture("Последний столбец таблицы многочленов")
        scrollBackTo(app, identifier: "input_p")
        replace(app, field: "p", with: "0")
        scrollTo(app, identifier: "solve")
        app.buttons["solve"].tap()
        XCTAssertTrue(app.staticTexts["inputError"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["polynomialShowAnswer"].exists)
    }

    @MainActor
    func testDirectDivisionConditionsAndImmediateCapture() throws {
        let app = XCUIApplication()
        app.launch()
        scrollTo(app, identifier: "task_modular_division")
        app.buttons["task_modular_division"].tap()
        scrollTo(app, identifier: "modularCondition_1")
        XCTAssertEqual(app.descendants(matching: .any)["modularCondition_1"].firstMatch.label,
                       "Условие для рабочей строки: меньше или равно 153")
        XCTAssertEqual(app.descendants(matching: .any)["modularMatrix_1"].firstMatch.label,
                       "Строка 1: 104, −1. Строка 2: 179, 1. Строка 3: 0, 0")
        capture("Строка 104 подходит под условие 153")
        scrollTo(app, identifier: "modularCondition_2")
        XCTAssertEqual(app.descendants(matching: .any)["modularCondition_2"].firstMatch.label,
                       "Условие для рабочей строки: меньше или равно 49")
        XCTAssertEqual(app.descendants(matching: .any)["modularMatrix_2"].firstMatch.label,
                       "Строка 1: 104, −1. Строка 2: 179, 1. Строка 3: 104, −1")
        capture("Сразу добавляем 104 и обновляем условие")
        scrollTo(app, identifier: "modularCondition_7")
        XCTAssertEqual(app.descendants(matching: .any)["modularCondition_7"].firstMatch.label,
                       "Условие для рабочей строки: меньше или равно 23")
        capture("Добавляем 26 и обновляем условие")
    }

    @MainActor
    func testPowerMatrixFormatting() throws {
        let app = XCUIApplication()
        app.launch()
        scrollTo(app, identifier: "task_inverse")
        app.buttons["task_inverse"].tap()
        scrollTo(app, identifier: "modularMatrix_0")
        let initial = app.descendants(matching: .any)["modularMatrix_0"].firstMatch
        XCTAssertTrue(initial.label.contains("Строка 3"))
        XCTAssertTrue(initial.label.contains("2⁹"))
        capture("Исходная матрица со степенями")
        scrollTo(app, identifier: "modularMatrix_1")
        let first = app.descendants(matching: .any)["modularMatrix_1"].firstMatch
        XCTAssertEqual(first.label, "Строка 1: 2⁹, 2⁹, −112")
        scrollTo(app, identifier: "modularMatrix_2")
        let second = app.descendants(matching: .any)["modularMatrix_2"].firstMatch
        XCTAssertEqual(second.label, "Строка 1: 2⁸, 2⁸, −56")
        XCTAssertTrue(app.descendants(matching: .any)["modularOperation_2"].firstMatch.label.contains("M₁(½)"))
        capture("Первая строка и индексы преобразований")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        scrollTo(app, identifier: "task_modular_division")
        app.buttons["task_modular_division"].tap()
        scrollTo(app, identifier: "modularMatrix_1")
        let fraction = app.descendants(matching: .any)["modularMatrix_1"].firstMatch
        XCTAssertTrue(fraction.label.contains("Строка 3"))
        capture("Полная матрица дроби и индексы")
    }

    @MainActor
    func testNotebookArithmeticStyles() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["task_doubling"].tap()
        setSolutionStyle(app, "Как в конспекте")
        assertNotebookAnswer(app, "117")
        XCTAssertFalse(app.staticTexts["Выбор множителя"].exists)
        XCTAssertFalse(app.staticTexts["Начальное значение"].exists)
        capture("Конспект — удвоение и сложение")
        setSolutionStyle(app, "Подробно")
        scrollTo(app, identifier: "answer")
        XCTAssertEqual(app.staticTexts["answer"].label, "117")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["task_division"].tap()
        setSolutionStyle(app, "Как в конспекте")
        assertNotebookAnswer(app, "1530 = 41 · 37 + 13")
        capture("Конспект — двоичное деление")
        setSolutionStyle(app, "Подробно")
        scrollTo(app, identifier: "divisionQuotient")
        XCTAssertEqual(app.staticTexts["divisionQuotient"].label, "q = 37")
    }

    @MainActor
    func testNotebookModularStylesAndPersistence() throws {
        let app = XCUIApplication()
        app.launch()
        scrollTo(app, identifier: "task_inverse")
        app.buttons["task_inverse"].tap()
        setSolutionStyle(app, "Как в конспекте")
        scrollTo(app, identifier: "notebookMatrix_1")
        capture("Конспект — матрица степени двойки")
        assertNotebookAnswer(app, "145")
        XCTAssertFalse(app.staticTexts["Проверяем существование"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        scrollTo(app, identifier: "task_inverse")
        app.buttons["task_inverse"].tap()
        scrollTo(app, identifier: "solutionStyle")
        XCTAssertTrue(app.descendants(matching: .any)["notebookSolution"].firstMatch.waitForExistence(timeout: 10))
        scrollBackTo(app, identifier: "modularMethod")
        app.buttons["modularMethod"].tap()
        app.buttons["По степеням двойки"].tap()
        app.buttons["solve"].tap()
        scrollTo(app, identifier: "notebookLift_0")
        capture("Конспект — подъём обратного")
        assertNotebookAnswer(app, "145")
        scrollBackTo(app, identifier: "modularMethod")
        app.buttons["modularMethod"].tap()
        app.buttons["Расширенный бинарный Евклид"].tap()
        app.buttons["solve"].tap()
        assertNotebookAnswer(app, "145")
        setSolutionStyle(app, "Подробно")
        scrollTo(app, identifier: "jumpToModularAnswer")
        app.buttons["jumpToModularAnswer"].tap()
        XCTAssertEqual(app.staticTexts["modularAnswer"].label, "145")
        app.buttons["closeModularAnswer"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        scrollTo(app, identifier: "task_modular_division")
        app.buttons["task_modular_division"].tap()
        setSolutionStyle(app, "Как в конспекте")
        scrollTo(app, identifier: "notebookMatrix_2")
        capture("Конспект — третья строка и условия")
        assertNotebookAnswer(app, "72")
        setSolutionStyle(app, "Подробно")
    }

    @MainActor
    func testNotebookPolynomialStyle() throws {
        let app = XCUIApplication()
        app.launch()
        scrollTo(app, identifier: "task_polynomial")
        app.buttons["task_polynomial"].tap()
        setSolutionStyle(app, "Как в конспекте")
        scrollTo(app, identifier: "notebookPolynomialTable")
        capture("Конспект — таблица многочленов")
        assertNotebookAnswer(app, "3α³ + α²")
        capture("Конспект — многочлены и ответ")
        XCTAssertFalse(app.staticTexts["Верхняя строка таблицы"].exists)
        XCTAssertFalse(app.staticTexts["Коэффициенты по mod 5"].exists)
        setSolutionStyle(app, "Подробно")
        scrollTo(app, identifier: "polynomialShowAnswer")
        app.buttons["polynomialShowAnswer"].tap()
        XCTAssertEqual(app.descendants(matching: .any)["polynomialAnswer"].firstMatch.label, "3α³ + α²")
    }

    @MainActor
    private func setSolutionStyle(_ app: XCUIApplication, _ title: String) {
        let control = app.segmentedControls["solutionStyle"]
        let button = control.buttons[title]
        for _ in 0..<25 {
            if button.exists {
                let frame = button.frame
                let visibleTop = app.navigationBars.firstMatch.frame.maxY
                if button.isHittable && frame.minY > visibleTop && frame.maxY < app.frame.maxY {
                    break
                }
                if frame.minY <= visibleTop { app.swipeDown() }
                else { app.swipeUp() }
            } else if app.descendants(matching: .any)["notebookSolution"].firstMatch.exists {
                app.swipeDown()
            } else { app.swipeUp() }
        }
        XCTAssertTrue(button.isHittable)
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let paper = app.descendants(matching: .any)["notebookSolution"].firstMatch
        if title == "Как в конспекте" { XCTAssertTrue(paper.waitForExistence(timeout: 5)) }
        else {
            expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: paper)
            waitForExpectations(timeout: 5)
        }
    }

    @MainActor
    private func assertNotebookAnswer(_ app: XCUIApplication, _ expected: String) {
        scrollTo(app, identifier: "notebookAnswer")
        XCTAssertEqual(app.descendants(matching: .any)["notebookAnswer"].firstMatch.label, expected)
        XCTAssertTrue(app.descendants(matching: .any)["notebookSolution"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Ход решения"].exists)
    }

    @MainActor
    private func scrollBackTo(_ app: XCUIApplication, identifier: String) {
        let target = app.descendants(matching: .any)[identifier].firstMatch
        for _ in 0..<25 {
            if target.isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(target.isHittable)
    }

    @MainActor
    private func scrollTo(_ app: XCUIApplication, identifier: String) {
        let target = app.descendants(matching: .any)[identifier].firstMatch
        for _ in 0..<25 {
            if target.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(target.waitForExistence(timeout: 5))
    }

    @MainActor
    private func replace(_ app: XCUIApplication, field: String, with text: String) {
        let element = app.descendants(matching: .any)["input_\(field)"].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        element.tap()
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        let oldValue = element.value as? String ?? ""
        element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldValue.count) + text)
        XCTAssertEqual(element.value as? String, text, "The input must be replaced before checking the calculation")
        let done = app.buttons["Готово"]
        if done.exists { done.tap() }
    }

    @MainActor
    private func scrollToAnswer(_ app: XCUIApplication) {
        for _ in 0..<10 {
            if app.staticTexts["answer"].isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["answer"].waitForExistence(timeout: 5))
    }
}
