import XCTest

final class ReferenceCourseUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor private func find(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    @MainActor private func scroll(_ app: XCUIApplication, _ id: String) {
        for _ in 0..<45 { if find(app,id).isHittable { return }; app.swipeUp() }
        XCTAssertTrue(find(app,id).isHittable,id)
    }
    @MainActor private func close(_ app: XCUIApplication) {
        let buttons=app.buttons.matching(identifier: "closeStudentDetail")
        let visible=buttons.allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(visible); visible?.tap()
    }
    @MainActor private func capture(_ name: String) {
        let a=XCTAttachment(screenshot:XCUIScreen.main.screenshot()); a.name=name; a.lifetime = .keepAlways; add(a)
    }
    @MainActor func testCatalogRowsContainOnlyTitles() throws {
        let app=XCUIApplication(); app.launch(); app.tabBars.buttons["Теоремы"].tap()
        let theorem=find(app,"reference_egyptian-algebraic")
        XCTAssertTrue(theorem.waitForExistence(timeout:8))
        XCTAssertEqual(theorem.label,"Алгоритмическая временная сложность египетского умножения")
        XCTAssertFalse(app.staticTexts["Есть уточнение"].exists)
        XCTAssertTrue(find(app,"reference_binary-division-bit").isHittable)
        capture("Теоремы — только названия")
        app.tabBars.buttons["Определения"].tap()
        let definition=find(app,"reference_residue-system")
        XCTAssertTrue(definition.waitForExistence(timeout:5))
        XCTAssertEqual(definition.label,"Полная система наименьших неотрицательных вычетов")
        XCTAssertFalse(app.staticTexts["Есть уточнение"].exists)
        capture("Определения — только названия")
    }
    @MainActor func testRequiredListOpensDirectlyOnWhiteProofSheet() throws {
        let app=XCUIApplication(); app.launch(); app.tabBars.buttons["Теоремы"].tap()
        XCTAssertTrue(find(app,"reference_egyptian-algebraic").waitForExistence(timeout:8))
        XCTAssertFalse(find(app,"reference_lagrange").exists)
        capture("Теоремы — прежние цвета карточек")
        find(app,"reference_egyptian-algebraic").tap()
        XCTAssertTrue(find(app,"theoremGiven").waitForExistence(timeout:5))
        XCTAssertTrue(find(app,"theoremPaper").exists)
        XCTAssertTrue(app.staticTexts["Дано."].exists)
        XCTAssertTrue(app.staticTexts["Доказать."].exists)
        XCTAssertFalse(find(app,"referenceCleanProof").exists)
        XCTAssertFalse(find(app,"referenceCorrection").exists)
        XCTAssertFalse(find(app,"source_L1_2").exists)
        XCTAssertFalse(find(app,"proof_egyptian-algebraic_1_0_reason").exists)
        capture("Теорема 1 — белый лист без дополнительных блоков")
        scroll(app,"referenceQED"); capture("Теорема 1 — доказательство и ЧТД")
        XCTAssertTrue(find(app,"theoremSources").isHittable)
        XCTAssertTrue(find(app,"theoremExplanation").isHittable)
    }
    @MainActor func testLectureDefinitionAndOriginalDisclaimer() throws {
        let app=XCUIApplication(); app.launch(); app.tabBars.buttons["Определения"].tap()
        XCTAssertTrue(find(app,"reference_residue-system").waitForExistence(timeout:5))
        capture("Определения — прежние цвета")
        find(app,"reference_residue-system").tap()
        XCTAssertTrue(find(app,"definitionPaper").waitForExistence(timeout:5))
        XCTAssertFalse(find(app,"source_N1_3").exists)
        XCTAssertFalse(find(app,"referenceCorrection").exists)
        capture("Определение — белый лист с формулами конспекта")
        find(app,"definitionSources").tap(); scroll(app,"source_N1_3"); find(app,"source_N1_3").tap()
        XCTAssertTrue(find(app,"referencePDF").waitForExistence(timeout:8))
        XCTAssertEqual(find(app,"referencePDF").value as? String, "1")
        XCTAssertTrue(find(app,"referencePDF").label.contains("3"))
        capture("Источник определения — только нужная страница")
        find(app,"sourceNotice").tap()
        XCTAssertTrue(app.staticTexts["Об источнике"].waitForExistence(timeout:5))
    }
    @MainActor func testDetailedInductionExplanationIsSeparateFromPaper() throws {
        let app=XCUIApplication(); app.launch(); app.tabBars.buttons["Теоремы"].tap()
        let search=app.searchFields.firstMatch; search.tap(); search.typeText("№16")
        XCTAssertTrue(find(app,"reference_five-order").waitForExistence(timeout:5)); find(app,"reference_five-order").tap()
        XCTAssertTrue(find(app,"theoremGiven").waitForExistence(timeout:5))
        capture("Порядок 5 — математическая индукция на листе")
        find(app,"theoremExplanation").tap()
        XCTAssertTrue(app.staticTexts["Подробное доказательство"].waitForExistence(timeout:5))
        scroll(app,"proof_five-order_1_1_reason"); find(app,"proof_five-order_1_1_reason").tap()
        XCTAssertTrue(app.staticTexts["Обоснование перехода"].waitForExistence(timeout:5))
        capture("Отдельное подробное объяснение перехода")
        close(app); close(app)
        XCTAssertTrue(find(app,"theoremGiven").isHittable)
        XCTAssertFalse(find(app,"proof_five-order_1_1_reason").exists)
        scroll(app,"referenceQED"); capture("Порядок 5 — окончание математического доказательства")
    }
    @MainActor func testLectureSymbolsInFieldAndRootProofs() throws {
        for (number,id,symbol) in [("24","extension-is-field","GF(q"),("36","two-square-four","m+2")] {
            let app=XCUIApplication(); app.launch(); app.tabBars.buttons["Теоремы"].tap()
            let search=app.searchFields.firstMatch; search.tap(); search.typeText("№"+number)
            XCTAssertTrue(find(app,"reference_"+id).waitForExistence(timeout:5)); find(app,"reference_"+id).tap()
            XCTAssertTrue(find(app,"theoremPaper").waitForExistence(timeout:5))
            let formula=app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@",symbol)).firstMatch
            XCTAssertTrue(formula.exists, symbol)
            capture("Обозначения лектора — теорема "+number)
            scroll(app,"referenceQED"); capture("Обозначения лектора — окончание "+number)
            app.terminate()
        }
    }
    @MainActor func testSourcesAndCorrectionsAreOnlyInSeparateSheet() throws {
        let app=XCUIApplication(); app.launch(); app.tabBars.buttons["Теоремы"].tap()
        let search=app.searchFields.firstMatch; search.tap(); search.typeText("№32")
        XCTAssertTrue(find(app,"reference_rabin-probability").waitForExistence(timeout:5)); find(app,"reference_rabin-probability").tap()
        XCTAssertTrue(find(app,"theoremGiven").waitForExistence(timeout:5))
        XCTAssertFalse(find(app,"referenceCorrection").exists)
        capture("Вероятностная оценка — только математическая запись")
        find(app,"theoremSources").tap()
        XCTAssertTrue(find(app,"referenceCorrection").waitForExistence(timeout:5))
        scroll(app,"source_L9_1"); find(app,"source_L9_1").tap()
        XCTAssertTrue(find(app,"referencePDF").waitForExistence(timeout:8))
        find(app,"closeReferenceSource").tap(); close(app)
        XCTAssertTrue(find(app,"theoremGiven").isHittable)
        scroll(app,"referenceQED"); capture("Вероятностная оценка — завершённое доказательство")
    }
    @MainActor func testDefinitionCasesAndSeparateExplanation() throws {
        for (query, id, rows) in [("функция Эйлера", "totient", 2), ("Лежандра", "legendre", 3), ("Кармайкла", "carmichael", 2)] {
            let app=XCUIApplication(); app.launch(); app.tabBars.buttons["Определения"].tap()
            let search=app.searchFields.firstMatch; search.tap(); search.typeText(query)
            XCTAssertTrue(find(app,"reference_"+id).waitForExistence(timeout:5)); find(app,"reference_"+id).tap()
            XCTAssertTrue(find(app,"definitionPaper").waitForExistence(timeout:5))
            XCTAssertTrue(find(app,"definitionCases").exists)
            for i in 0..<rows { XCTAssertTrue(find(app,"definitionCase_\(i)").exists) }
            XCTAssertFalse(find(app,"referenceCorrection").exists)
            capture("Определение — "+id)
            find(app,"definitionExplanation").tap()
            XCTAssertTrue(app.staticTexts["Разбор определения"].waitForExistence(timeout:5))
            close(app)
            XCTAssertTrue(find(app,"definitionPaper").isHittable)
            app.terminate()
        }
    }
    @MainActor func testTwoPageExcerptContainsExactlyThosePages() throws {
        let app=XCUIApplication(); app.launch(); app.tabBars.buttons["Теоремы"].tap()
        let search=app.searchFields.firstMatch; search.tap(); search.typeText("№30")
        XCTAssertTrue(find(app,"reference_tonelli-nonresidue").waitForExistence(timeout:5))
        find(app,"reference_tonelli-nonresidue").tap(); find(app,"theoremSources").tap()
        scroll(app,"source_N1_103"); find(app,"source_N1_103").tap()
        XCTAssertTrue(find(app,"referencePDF").waitForExistence(timeout:8))
        XCTAssertEqual(find(app,"referencePDF").value as? String, "2")
        XCTAssertEqual(find(app,"referencePDF").label,"Страницы оригинала: 103, 104")
        capture("Источник теоремы — только две страницы")
    }
    @MainActor func testDefinitionSetAndSumNotation() throws {
        for (query,id,marker) in [("квадратичное расширение", "extension-field", "definitionSet"), ("многочлен", "polynomial", "definitionPaper"), ("двухкомпонентный", "two-component-log", "definitionPaper")] {
            let app=XCUIApplication(); app.launch(); app.tabBars.buttons["Определения"].tap()
            let search=app.searchFields.firstMatch; search.tap(); search.typeText(query)
            XCTAssertTrue(find(app,"reference_"+id).waitForExistence(timeout:5)); find(app,"reference_"+id).tap()
            XCTAssertTrue(find(app,marker).waitForExistence(timeout:5))
            capture("Определение — "+id)
            app.terminate()
        }
    }

}
