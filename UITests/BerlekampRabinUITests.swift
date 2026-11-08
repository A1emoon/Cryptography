import XCTest

final class BerlekampRabinUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor private func find(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    @MainActor private func scroll(_ app: XCUIApplication, _ id: String, down: Bool = false) {
        let element = find(app, id)
        for _ in 0..<20 {
            if element.isHittable { return }
            if down { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), id)
    }
    @MainActor private func open(_ app: XCUIApplication) {
        app.launch(); scroll(app, "task_rabin"); find(app,"task_rabin").tap()
        XCTAssertTrue(find(app,"rabinAnswerValue").waitForExistence(timeout: 10))
    }
    @MainActor private func capture(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    @MainActor private func close(_ app: XCUIApplication) { app.buttons["closeStudentDetail"].firstMatch.tap() }
    @MainActor private func replace(_ app:XCUIApplication,_ id:String,_ value:String){
        let clear="clear_"+id.replacingOccurrences(of:"input_",with:"")
        scroll(app,clear);find(app,clear).tap()
        if !value.isEmpty{find(app,id).typeText(value);XCTAssertEqual(find(app,id).value as? String,value)}
        if app.buttons["Готово"].exists{app.buttons["Готово"].firstMatch.tap()}
    }
    @MainActor private func solve(_ app: XCUIApplication, _ f: String, _ q: String) {
        app.buttons["rabinInput"].tap()
        replace(app,"input_f",f); replace(app,"input_q",q)
        scroll(app,"rabinSolve"); app.buttons["rabinSolve"].tap()
    }
    @MainActor func testLectureStudentPageCalculationsAndGlossary() throws {
        let app = XCUIApplication(); open(app)
        XCTAssertEqual(find(app,"rabinAnswerValue").label,"[1]₇")
        XCTAssertFalse(app.segmentedControls["solutionStyle"].exists)
        XCTAssertFalse(app.staticTexts["Ход решения"].exists)
        XCTAssertFalse(find(app,"notebookPolynomialTable").exists)
        XCTAssertFalse(find(app,"rabinLongDivision").exists)
        capture("Рабин — единая студенческая запись")
        scroll(app,"rabin_gcd_reason"); find(app,"rabin_gcd_reason").tap()
        XCTAssertTrue(app.staticTexts["Почему ищем НОД"].waitForExistence(timeout: 5))
        scroll(app,"rabinTerm_gcd"); app.buttons["rabinTerm_gcd"].tap()
        XCTAssertTrue(app.staticTexts["НОД многочленов"].waitForExistence(timeout: 5))
        capture("Рабин — определение термина из пояснения")
        close(app); close(app)
        find(app,"rabin_gcd_work_1").tap()
        XCTAssertTrue(app.staticTexts["Вспомогательное вычисление степени"].waitForExistence(timeout: 5))
        capture("Рабин — вычисление в другом месте")
        scroll(app,"rabinPowerProduct_2"); app.buttons["rabinPowerProduct_2"].tap()
        XCTAssertTrue(find(app,"notebookPolynomialTable").waitForExistence(timeout: 10))
        capture("Рабин — вложенное удвоение–сложение")
        close(app); close(app)
        scroll(app,"rabin_gcd_work_3"); find(app,"rabin_gcd_work_3").tap()
        XCTAssertTrue(find(app,"rabinLongDivision").waitForExistence(timeout: 5))
        capture("Рабин — НОД и деление уголком")
        scroll(app,"rabinGCDResult")
        XCTAssertEqual(find(app,"rabinGCDResult").label,"x + 6")
        close(app)
        XCTAssertTrue(find(app,"rabin_gcd_work_3").isHittable)
        XCTAssertEqual(find(app,"rabinAnswerValue").label,"[1]₇")
    }
    @MainActor func testAllBranchesInputAndCancel() throws {
        let app = XCUIApplication(); open(app)
        solve(app,"1,0,4","5")
        scroll(app,"rabin_split_gcd_0_reason"); find(app,"rabin_split_gcd_0_reason").tap()
        XCTAssertTrue(app.staticTexts["Почему меняем δ"].waitForExistence(timeout: 5))
        capture("Рабин — почему не подошёл первый сдвиг")
        close(app)
        scroll(app,"rabinAnswerValue")
        XCTAssertEqual(find(app,"rabinAnswerValue").label,"{ [1]₅, [4]₅ }")
        capture("Рабин — две ветви и два корня")
        app.buttons["rabinInput"].tap(); replace(app,"input_f","0")
        app.buttons["closeRabinInput"].tap()
        XCTAssertEqual(find(app,"rabinAnswerValue").label,"{ [1]₅, [4]₅ }")
        solve(app,"1,0,1","9")
        XCTAssertTrue(find(app,"inputError").waitForExistence(timeout: 5))
        XCTAssertFalse(find(app,"rabinAnswerValue").exists)
        solve(app,"1,0,1","7")
        XCTAssertTrue(find(app,"rabinAnswerValue").waitForExistence(timeout: 5))
        XCTAssertEqual(find(app,"rabinAnswerValue").label,"∅")
        solve(app,"0","7")
        XCTAssertTrue(find(app,"rabinAnswerValue").waitForExistence(timeout: 5))
        XCTAssertEqual(find(app,"rabinAnswerValue").label,"ℤ₇")
        solve(app,"1,1,0","2")
        XCTAssertTrue(find(app,"rabinAnswerValue").waitForExistence(timeout: 5))
        XCTAssertEqual(find(app,"rabinAnswerValue").label,"{ [0]₂, [1]₂ }")
        capture("Рабин — поле из двух элементов")
    }
}
