import XCTest

final class CipollaUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor private func find(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    @MainActor private func scroll(_ app: XCUIApplication, _ id: String) {
        let e = find(app, id)
        for _ in 0..<22 { if e.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(e.isHittable, id)
    }
    @MainActor private func open(_ app: XCUIApplication) {
        app.launch(); scroll(app,"task_cipolla"); find(app,"task_cipolla").tap()
        XCTAssertTrue(find(app,"cipollaAnswer").waitForExistence(timeout: 10))
    }
    @MainActor private func capture(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    @MainActor private func close(_ app: XCUIApplication) {
        let button=app.buttons.matching(identifier:"closeStudentDetail").allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(button); button?.tap()
    }
    @MainActor private func replace(_ app:XCUIApplication,_ id:String,_ value:String){
        let clear="clear_"+id.replacingOccurrences(of:"input_",with:"")
        scroll(app,clear);find(app,clear).tap()
        if !value.isEmpty{find(app,id).typeText(value);XCTAssertEqual(find(app,id).value as? String,value)}
        if app.buttons["Готово"].exists{app.buttons["Готово"].firstMatch.tap()}
    }
    @MainActor private func solve(_ app: XCUIApplication, _ a: String, _ p: String, _ delta: String = "") {
        app.buttons["cipollaInput"].tap()
        replace(app,"input_a",a); replace(app,"input_p",p); replace(app,"input_delta",delta)
        scroll(app,"cipollaSolve"); app.buttons["cipollaSolve"].tap()
    }
    @MainActor func testStudentPageNestedCalculationsAndReasons() throws {
        let app = XCUIApplication(); open(app)
        XCTAssertEqual(find(app,"cipollaAnswer").label,"47, 62")
        XCTAssertFalse(app.segmentedControls["solutionStyle"].exists)
        XCTAssertFalse(find(app,"notebookIntegerTable").exists)
        XCTAssertFalse(app.staticTexts["Последовательные квадраты"].exists)
        capture("Чиполла — студенческий лист")
        find(app,"cipolla_legendre_work_0").tap()
        scroll(app,"cipolla_symbol_stage_1_reason"); find(app,"cipolla_symbol_stage_1_reason").tap()
        XCTAssertTrue(app.staticTexts["Откуда степень 756"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "108 · 28")).firstMatch.exists)
        capture("Чиполла — объяснение дробного показателя")
        scroll(app,"cipollaTerm_reciprocity"); find(app,"cipollaTerm_reciprocity").tap()
        XCTAssertTrue(find(app,"theoremPaper").waitForExistence(timeout: 5))
        capture("Чиполла — определение термина")
        close(app); close(app); close(app)
        scroll(app,"cipolla_exponent_reason"); capture("Чиполла — выбор δ и дробная степень")
        find(app,"cipolla_exponent_reason").tap()
        XCTAssertTrue(app.staticTexts["Почему показатель 55"].waitForExistence(timeout: 5))
        scroll(app,"cipollaTerm_conjugate"); find(app,"cipollaTerm_conjugate").tap()
        XCTAssertTrue(app.otherElements["definitionPaper"].waitForExistence(timeout: 5))
        close(app); close(app)
        scroll(app,"cipolla_binary_work_2"); find(app,"cipolla_binary_work_2").tap()
        XCTAssertTrue(app.staticTexts["Перевод показателя в двоичную систему"].waitForExistence(timeout: 5)); close(app)
        scroll(app,"cipolla_power_2_work_2"); capture("Чиполла — последовательные квадраты")
        find(app,"cipolla_power_2_work_2").tap()
        XCTAssertTrue(app.staticTexts["Умножение в расширении поля"].waitForExistence(timeout: 5))
        capture("Чиполла — вспомогательные произведения")
        scroll(app,"cipolla_scalar_power_2_4_work_0"); find(app,"cipolla_scalar_power_2_4_work_0").tap()
        XCTAssertTrue(app.staticTexts["Удвоение–сложение"].waitForExistence(timeout: 5))
        XCTAssertTrue(find(app,"notebookIntegerTable").waitForExistence(timeout: 5))
        capture("Чиполла — вложенная таблица удвоения–сложения")
        scroll(app,"cipollaScalarResult"); XCTAssertEqual(find(app,"cipollaScalarResult").label,"40")
        close(app); XCTAssertTrue(find(app,"cipolla_scalar_power_2_4_work_0").isHittable)
        close(app); XCTAssertTrue(find(app,"cipolla_power_2_work_2").isHittable)
        scroll(app,"cipollaAnswer"); capture("Чиполла — завершение и проверка")
        XCTAssertEqual(find(app,"cipollaAnswer").label,"47, 62")
        app.buttons["cipollaAnswerReason"].tap()
        XCTAssertTrue(app.staticTexts["Почему такой ответ"].waitForExistence(timeout: 5)); close(app)
        XCTAssertTrue(find(app,"cipollaAnswer").isHittable)
    }
    @MainActor func testInputCancellationManualDeltaAndSpecialCases() throws {
        let app = XCUIApplication(); open(app)
        app.buttons["cipollaInput"].tap(); replace(app,"input_a","0"); app.buttons["closeCipollaInput"].tap()
        XCTAssertEqual(find(app,"cipollaAnswer").label,"47, 62")
        app.buttons["cipollaHelp"].tap()
        XCTAssertTrue(app.staticTexts["Алгоритм Чиполлы"].waitForExistence(timeout: 5)); close(app)
        solve(app,"2","3")
        XCTAssertTrue(find(app,"cipollaAnswer").waitForExistence(timeout: 5)); XCTAssertEqual(find(app,"cipollaAnswer").label,"Решений нет")
        solve(app,"29","15")
        XCTAssertTrue(find(app,"inputError").waitForExistence(timeout: 5)); XCTAssertFalse(find(app,"cipollaAnswer").exists)
        solve(app,"29","109","2")
        XCTAssertTrue(find(app,"inputError").waitForExistence(timeout: 5))
        solve(app,"29","109","4")
        XCTAssertTrue(find(app,"cipollaAnswer").waitForExistence(timeout: 5)); XCTAssertEqual(find(app,"cipollaAnswer").label,"47, 62")
        XCTAssertTrue(find(app,"cipolla_candidate_0").exists); XCTAssertFalse(find(app,"cipolla_candidate_1").exists)
        solve(app,"0","109")
        XCTAssertTrue(find(app,"cipollaAnswer").waitForExistence(timeout: 5)); XCTAssertEqual(find(app,"cipollaAnswer").label,"0")
        solve(app,"-1","2")
        XCTAssertTrue(find(app,"cipollaAnswer").waitForExistence(timeout: 5)); XCTAssertEqual(find(app,"cipollaAnswer").label,"1")
        solve(app,"4","13")
        XCTAssertTrue(find(app,"cipollaAnswer").waitForExistence(timeout: 5)); XCTAssertEqual(find(app,"cipollaAnswer").label,"2, 11")
        XCTAssertTrue(find(app,"cipolla_candidate_root").exists)
        capture("Чиполла — корень найден при подборе δ")
    }
}
