import XCTest

final class WatchSmokeTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor private func find(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    @MainActor private func advance(_ app: XCUIApplication) {
        let start=app.coordinate(withNormalizedOffset:CGVector(dx:0.94,dy:0.62))
        let end=app.coordinate(withNormalizedOffset:CGVector(dx:0.94,dy:0.47))
        start.press(forDuration:0.05,thenDragTo:end,withVelocity:.slow,thenHoldForDuration:0.3)
    }
    @MainActor private func visibleRow(_ app: XCUIApplication, _ element: XCUIElement) -> CGRect? {
        guard element.exists, element.isHittable else { return nil }
        var bottom = app.frame.maxY-8
        for id in ["watchTab_tasks", "watchTab_definitions", "watchTab_theorems"] {
            let tab = find(app,id)
            if tab.exists && tab.isHittable { bottom = min(bottom,tab.frame.minY-3) }
        }
        let viewport = CGRect(x: app.frame.minX+5, y: 55, width: app.frame.width-10, height: max(1,bottom-55))
        let intersection = element.frame.intersection(viewport)
        return !intersection.isNull && intersection.height > 12 ? intersection : nil
    }
    @MainActor private func reach(_ app: XCUIApplication, _ id: String) {
        for _ in 0..<45 { if visibleRow(app,find(app,id)) != nil { return }; advance(app) }
        XCTFail("Row is outside the list viewport: "+id)
    }
    @MainActor private func tapRow(_ app: XCUIApplication, _ id: String) {
        reach(app,id)
        guard let rect = visibleRow(app,find(app,id)) else { return }
        // Watch automation may report a hit point behind the bottom toolbar for a clipped row.
        app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:rect.midX-app.frame.minX,dy:rect.midY-app.frame.minY)).tap()
    }
    @MainActor private func pageAction(_ app: XCUIApplication, _ id: String, _ title: String) {
        find(app,"watchPageActions").tap()
        if find(app,id).waitForExistence(timeout:3) { find(app,id).tap() }
        else { app.buttons[title].firstMatch.tap() }
    }
    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor private func otherTasks(_ app: XCUIApplication) {
        tapRow(app,"watchOtherTasks")
        XCTAssertEqual(find(app,"watchOtherTasks").value as? String,"Развернуто")
    }
    @MainActor func testWatchLaunchesWithPrimaryTasks() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(find(app,"task_inverse").waitForExistence(timeout:15))
        XCTAssertFalse(find(app,"task_doubling").exists)
        capture("Часы — задачи и три раздела")
        reach(app,"task_tonelli"); capture("Часы — первые три задачи")
        otherTasks(app); reach(app,"task_cipolla"); reach(app,"task_rabin")
        XCTAssertTrue(find(app,"task_rabin").exists)
        capture("Часы — остальные задачи раскрыты")
    }
    @MainActor func testAllNineAlgorithmsComputeOffline() {
        let examples = [("inverse","answer_inverse","2"), ("order","answer_order","100"), ("tonelli","answer_tonelli","19, 20, 124"), ("doubling","answer_doubling","117"), ("division","answer_division","1530 = 41 · 37 + 13"), ("modular_division","answer_modularDivision","72"), ("polynomial","answer_polynomial","3α³ + α²"), ("cipolla","cipollaAnswer","47, 62"), ("rabin","rabinAnswerValue","[1]₇")]
        for (index, example) in examples.enumerated() {
            let (task, answer, expected) = example
            let app = XCUIApplication(); app.launch()
            XCTAssertTrue(find(app,"task_inverse").waitForExistence(timeout:15))
            if index >= 3 { otherTasks(app) }
            tapRow(app,"task_"+task)
            XCTAssertTrue(find(app,"studentSolution").waitForExistence(timeout:20), task)
            if !find(app,answer).exists { reach(app,answer) }; XCTAssertTrue(find(app,answer).waitForExistence(timeout:15), task)
            XCTAssertEqual(find(app,answer).label, expected, task)
            if index < 3 || task == "cipolla" { capture("Часы — решение "+task) }
            app.terminate()
        }
    }
    @MainActor func testNumericKeypadChangesTheProblem() {
        let app = XCUIApplication(); app.launch(); find(app,"task_inverse").tap()
        XCTAssertTrue(find(app,"studentSolution").waitForExistence(timeout:15))
        pageAction(app,"courseInput","Изменить условие"); reach(app,"input_a"); find(app,"input_a").tap()
        XCTAssertTrue(find(app,"watchNumberDraft").waitForExistence(timeout:5))
        reach(app,"Очистить")
        app.buttons["Очистить"].tap()
        // A single digit is entered through the watch keypad, without a phone or dictation.
        XCUIDevice.shared.rotateDigitalCrown(delta:-0.8); reach(app,"watchKey_2"); find(app,"watchKey_2").tap()
        find(app,"watchNumberDone").tap()
        reach(app,"courseSolve"); capture("Часы — ввод условия"); find(app,"courseSolve").tap()
        XCTAssertTrue(find(app,"answer_inverse").waitForExistence(timeout:15))
        XCTAssertEqual(find(app,"answer_inverse").label,"129")
    }
    @MainActor func testDefinitionAndTheoremKeepWhiteSheetsAndSources() {
        for (section, entry, paper, sourceButton) in [("1","residue-system","definitionPaper","definitionSources"),("2","egyptian-algebraic","theoremPaper","theoremSources")] {
            let app = XCUIApplication(); app.launchArguments = ["--watch-section", section]; app.launch()
            XCTAssertTrue(find(app,"reference_"+entry).waitForExistence(timeout:15)); tapRow(app,"reference_"+entry)
            XCTAssertTrue(find(app,paper).waitForExistence(timeout:8)); capture("Часы — "+paper)
            XCTAssertFalse(find(app,"referenceCorrection").exists)
            pageAction(app,sourceButton,"Источники")
            let source = section == "1" ? "source_L1_1" : "source_L1_2"
            reach(app,source); find(app,source).tap()
            XCTAssertTrue(find(app,"watchSourcePage").waitForExistence(timeout:10))
            let ready = NSPredicate(format: "value CONTAINS %@", "процентов")
            expectation(for: ready, evaluatedWith: find(app,"watchSourcePage")); waitForExpectations(timeout:15)
            capture("Часы — источник "+section)
            app.terminate()
        }
    }
    @MainActor func testCrownZoomPanResetAndSelectedPagesForPDFAndPhoto() {
        for (source,pages) in [("N1","103,104"),("PHOTO1","1")] {
            let app = XCUIApplication(); app.launchArguments = ["--watch-source",source,"--watch-pages",pages]; app.launch()
            let canvas = find(app,"watchSourcePage")
            XCTAssertTrue(canvas.waitForExistence(timeout:15))
            let ready = NSPredicate(format: "value CONTAINS %@", "процентов")
            expectation(for:ready,evaluatedWith:canvas);waitForExpectations(timeout:15)
            XCTAssertGreaterThanOrEqual(canvas.frame.width,app.frame.width-2)
            XCTAssertGreaterThanOrEqual(canvas.frame.height,app.frame.height-2)
            XCTAssertFalse(find(app,"sourceZoom").exists)
            XCTAssertFalse(find(app,"sourceNextPage").exists)
            let initial = canvas.value as? String
            XCUIDevice.shared.rotateDigitalCrown(delta:1)
            if canvas.value as? String == initial { XCUIDevice.shared.rotateDigitalCrown(delta:-1) }
            XCTAssertNotEqual(canvas.value as? String,initial,"Digital Crown must change the full-screen page scale")
            let start = app.coordinate(withNormalizedOffset:CGVector(dx:0.65,dy:0.75))
            start.press(forDuration:0.1,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.30,dy:0.30)))
            XCTAssertTrue((canvas.value as? String)?.contains("сдвинута") == true)
            capture("Часы — полный экран и Crown "+source)
            app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).doubleTap()
            XCTAssertEqual(canvas.value as? String,"100 процентов")
            if source == "N1" {
                XCTAssertTrue(canvas.label.contains("103"))
                app.coordinate(withNormalizedOffset:CGVector(dx:0.85,dy:0.6)).press(forDuration:0.05,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.15,dy:0.6)))
                let changed=NSPredicate(format:"label CONTAINS %@","104")
                expectation(for:changed,evaluatedWith:find(app,"watchSourcePage"));waitForExpectations(timeout:8)
                capture("Часы — следующая выбранная страница")
            }
            find(app,"closeReferenceSource").tap()
            XCTAssertTrue(find(app,"task_inverse").waitForExistence(timeout:8))
            app.terminate()
        }
    }
    @MainActor func testThreeBottomSectionsAreIndependentButtons() {
        let app=XCUIApplication();app.launch()
        XCTAssertTrue(find(app,"task_inverse").waitForExistence(timeout:15))
        XCTAssertTrue(find(app,"watchTab_definitions").exists)
        find(app,"watchTab_definitions").tap()
        XCTAssertTrue(find(app,"reference_residue-system").waitForExistence(timeout:8))
        find(app,"watchTab_theorems").tap()
        XCTAssertTrue(find(app,"reference_egyptian-algebraic").waitForExistence(timeout:8))
        find(app,"watchTab_tasks").tap()
        XCTAssertTrue(find(app,"task_inverse").waitForExistence(timeout:8))
        capture("Часы — три самостоятельные кнопки разделов")
    }



    @MainActor func testLectureNotationScrollsAsWholeRows() {
        for (query,id,marker) in [("Лежандра","legendre","definitionCases"),("Кармайкла","carmichael","definitionCases"),("квадратичное расширение","extension-field","definitionSet")] {
            let app=XCUIApplication();app.launchArguments=["--watch-section","1"];app.launchEnvironment["WATCH_REFERENCE_QUERY"]=query;app.launch()
            XCTAssertTrue(find(app,"reference_"+id).waitForExistence(timeout:15));capture("Часы — скруглённая карточка "+id);tapRow(app,"reference_"+id)
            XCTAssertTrue(find(app,marker).waitForExistence(timeout:8))
            let element=find(app,marker)
            XCTAssertGreaterThan(element.frame.width,app.frame.width*0.7)
            reach(app,marker)
            let before=element.frame.minX
            let y=min(app.frame.maxY-45,max(105,element.frame.midY))
            app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:app.frame.width-15,dy:y)).press(forDuration:0.05,thenDragTo:app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:15,dy:y)),withVelocity:.slow,thenHoldForDuration:0.2)
            XCTAssertLessThan(element.frame.minX,before-10,"The complete definition must scroll horizontally")
            capture("Часы — определение одной строкой "+id)
            app.terminate()
        }
    }
    @MainActor private func tapMath(_ app: XCUIApplication, _ id: String) {
        for _ in 0..<40 {
            let target=find(app,id)
            if let rect=visibleRow(app,target) {
                app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:rect.midX,dy:rect.midY)).tap();return
            }
            if target.exists && target.frame.minY>65 && target.frame.minY<app.frame.maxY-35 {
                let y=min(app.frame.maxY-35,target.frame.midY)
                app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:app.frame.width-50,dy:y)).press(forDuration:0.05,thenDragTo:app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:12,dy:y)),withVelocity:.slow,thenHoldForDuration:0.2)
            } else { advance(app) }
        }
        XCTFail("Cannot reveal math action "+id)
    }
    @MainActor func testAuxiliaryWindowsAndNestedMultiplicationAreReadable() {
        let app=XCUIApplication();app.launch();tapRow(app,"task_tonelli")
        XCTAssertTrue(find(app,"tonelliCriterion_square_2").waitForExistence(timeout:15))
        XCTAssertTrue(find(app,"tonelliCriterion_square_32").exists)
        XCTAssertFalse(find(app,"tonelliCriterion_work_0").exists)
        capture("Часы — последовательные квадраты видны сразу")
        tapMath(app,"tonelliCriterion_square_2_work_0")
        XCTAssertTrue(app.staticTexts["Удвоение–сложение"].waitForExistence(timeout:8))
        XCTAssertTrue(find(app,"notebookIntegerTable").waitForExistence(timeout:8))
        capture("Часы — отдельно только таблица умножения")
        find(app,"closeStudentDetail").tap()
        XCTAssertTrue(find(app,"tonelliCriterion_square_2").waitForExistence(timeout:8))
        XCTAssertEqual(find(app,"answer_tonelli").label,"19, 20, 124")
    }
    @MainActor func testMatricesAndTheoremEqualitiesStayOnOneLine() {
        let app=XCUIApplication();app.launch();tapRow(app,"task_inverse")
        let chain=find(app,"modularMatrixChain")
        XCTAssertTrue(chain.waitForExistence(timeout:15))
        reach(app,"modularFrame_0")
        let first=find(app,"modularFrame_0"),next=find(app,"modularFrame_1")
        XCTAssertEqual(first.frame.midY,next.frame.midY,accuracy:5)
        let before=first.frame.minX
        let y=min(app.frame.maxY-35,max(105,first.frame.midY))
        app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:app.frame.width-15,dy:y)).press(forDuration:0.05,thenDragTo:app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:15,dy:y)),withVelocity:.slow,thenHoldForDuration:0.2)
        XCTAssertLessThan(first.frame.minX,before-10)
        capture("Часы — преобразования матриц в одной цепочке")
        app.terminate();app.launchArguments=["--watch-section","2"];app.launch()
        capture("Часы — скруглённые теоремы")
        tapRow(app,"reference_egyptian-algebraic")
        XCTAssertTrue(find(app,"theoremPaper").waitForExistence(timeout:8))
        capture("Часы — доказательство без переноса формул")
    }
    @MainActor func testCipollaAndRabinAuxiliaryWindowsKeepTheirPresenter() {
        for (task,action,title) in [("cipolla","cipolla_legendre_work_0","Вычисление символа"),("rabin","rabin_gcd_work_1","Вспомогательное вычисление степени")] {
            let app=XCUIApplication();app.launch()
            XCTAssertTrue(find(app,"task_inverse").waitForExistence(timeout:15))
            otherTasks(app);tapRow(app,"task_"+task)
            XCTAssertTrue(find(app,"studentSolution").waitForExistence(timeout:15))
            tapMath(app,action)
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout:8))
            capture("Часы — вспомогательное окно "+task)
            find(app,"closeStudentDetail").tap()
            XCTAssertTrue(find(app,"studentSolution").waitForExistence(timeout:8))
            app.terminate()
        }
    }

    @MainActor func testTonelliLectureDescentAndSharedExamples() {
        let app=XCUIApplication();app.launch();tapRow(app,"task_tonelli")
        XCTAssertTrue(find(app,"tonelliCriterion_square_2").waitForExistence(timeout:15))
        for id in ["tonelliOrder_0","tonelliOrder_1","tonelliIdentity_0","tonelliRegroup_1","tonelliExtract"] { XCTAssertTrue(find(app,id).exists,id) }
        XCTAssertEqual(find(app,"answer_tonelli").label,"19, 20, 124")
        capture("Часы — все основные вычисления на листе")
        pageAction(app,"courseInput","Изменить условие")
        reach(app,"Примеры с пары");app.buttons["Примеры с пары"].firstMatch.tap();tapRow(app,"tonelliExample_2_5_41")
        reach(app,"courseSolve");find(app,"courseSolve").tap()
        XCTAssertTrue(find(app,"tonelliCriterion").waitForExistence(timeout:15))
        XCTAssertFalse(find(app,"tonelliCriterion_work_0").exists)
        XCTAssertEqual(find(app,"answer_tonelli").label,"13, 28")
        capture("Часы — символ Лежандра со всеми преобразованиями")
    }

}
