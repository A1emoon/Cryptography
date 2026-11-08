import XCTest

final class NumberTheoryUITests:XCTestCase {
 override func setUpWithError()throws{continueAfterFailure=false}
 @MainActor private func find(_ app:XCUIApplication,_ id:String)->XCUIElement{app.descendants(matching:.any)[id].firstMatch}
 @MainActor private func scroll(_ app:XCUIApplication,_ id:String,down:Bool=false){let e=find(app,id);for _ in 0..<40{if e.isHittable{return};if down{app.swipeDown()}else{app.swipeUp()}};XCTAssertTrue(e.isHittable,id)}
 @MainActor private func capture(_ name:String){let a=XCTAttachment(screenshot:XCUIScreen.main.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
 @MainActor private func close(_ app:XCUIApplication){app.buttons["closeStudentDetail"].firstMatch.tap()}
 @MainActor private func replace(_ app:XCUIApplication,_ id:String,_ value:String){let clear="clear_"+id.replacingOccurrences(of:"input_",with:"");scroll(app,clear);find(app,clear).tap();if !value.isEmpty{find(app,id).typeText(value);XCTAssertEqual(find(app,id).value as? String,value)};if app.buttons["Готово"].exists{app.buttons["Готово"].firstMatch.tap()}}

 @MainActor private func open(_ app:XCUIApplication,_ id:String){app.launch();scroll(app,"task_"+id);find(app,"task_"+id).tap();XCTAssertTrue(find(app,"studentSolution").waitForExistence(timeout:15))}
 @MainActor private func solve(_ app:XCUIApplication){scroll(app,"courseSolve");find(app,"courseSolve").tap();XCTAssertTrue(find(app,"studentSolution").waitForExistence(timeout:15))}
 @MainActor func testFirstTasksOrderAndNestedCalculation()throws{
  let app=XCUIApplication();app.launch();capture("Задачи — приоритетные три")
  XCTAssertTrue(find(app,"task_inverse").isHittable);XCTAssertTrue(find(app,"task_order").exists);XCTAssertTrue(find(app,"task_tonelli").exists)
  find(app,"task_order").tap();XCTAssertTrue(find(app,"studentSolution").waitForExistence(timeout:15))
  XCTAssertFalse(app.segmentedControls["solutionStyle"].exists)
  find(app,"orderFactorization_work_0").tap();XCTAssertTrue(app.staticTexts["Разложение модуля"].waitForExistence(timeout:5));capture("Порядок — факторизация отдельно");close(app)
  scroll(app,"order_trial_5_4_2_0_work_1")
  find(app,"order_trial_5_4_2_0_work_1").tap();XCTAssertTrue(app.staticTexts["Вспомогательное вычисление степени"].waitForExistence(timeout:5));close(app)
  scroll(app,"answer_order");XCTAssertEqual(find(app,"answer_order").label,"100");capture("Порядок — НОК и ответ")
 }
 @MainActor func testTonelliCubeSquareAndReasons()throws{
  let app=XCUIApplication();open(app,"tonelli");XCTAssertFalse(find(app,"notebookIntegerTable").exists);capture("Тонелли — начало студенческого решения")
  find(app,"tonelliCriterion_reason").tap();XCTAssertTrue(app.staticTexts["Проверка существования корней"].waitForExistence(timeout:5));capture("Тонелли — пояснение дробного показателя");close(app)
  find(app,"tonelliCriterion_work_0").tap();XCTAssertTrue(app.staticTexts["Вспомогательное вычисление степени"].waitForExistence(timeout:5));scroll(app,"powerProduct_0_work_2");find(app,"powerProduct_0_work_2").tap();XCTAssertTrue(find(app,"notebookIntegerTable").waitForExistence(timeout:10));capture("Тонелли — вложенная таблица");close(app);close(app)
  scroll(app,"tonelliCorrection_1");capture("Тонелли — понижение порядка")
  scroll(app,"answer_tonelli");XCTAssertEqual(find(app,"answer_tonelli").label,"19, 20, 124");capture("Тонелли — все кубические корни")
  find(app,"courseInput").tap();replace(app,"input_a","15");replace(app,"input_p","17");app.segmentedControls["rootDegree"].buttons["x²"].tap();solve(app)
  scroll(app,"answer_tonelli");XCTAssertEqual(find(app,"answer_tonelli").label,"7, 10");capture("Тонелли — квадратное сравнение")
  find(app,"courseInput").tap();replace(app,"input_a","0");find(app,"closeCourseInput").tap();XCTAssertEqual(find(app,"answer_tonelli").label,"7, 10")
 }
 @MainActor func testCombinedInverseNumbersAndPolynomials()throws{
  let app=XCUIApplication();open(app,"inverse");capture("Обращение — нечётный модуль")
  scroll(app,"answer_inverse");XCTAssertEqual(find(app,"answer_inverse").label,"2")
  find(app,"courseInput").tap();app.segmentedControls["inverseDomain"].buttons["Многочлены"].tap();solve(app)
  XCTAssertTrue(find(app,"polyInverseFrame_0").exists);capture("Обращение — многочлены")
  scroll(app,"answer_inverse");XCTAssertEqual(find(app,"answer_inverse").label,"5α³ + 5α² + 2α + 1");capture("Обращение — результат по практике")
  find(app,"courseInput").tap();app.segmentedControls["inverseDomain"].buttons["Числа"].tap();replace(app,"input_a","113");replace(app,"input_m","512");solve(app);capture("Обращение — начальная матрица степени двойки")
  scroll(app,"modularFrame_1");capture("Обращение — только первая строка")
  scroll(app,"answer_inverse");XCTAssertEqual(find(app,"answer_inverse").label,"145")
 }
 @MainActor func testOriginalArithmeticUsesUnifiedSheet()throws{
  for (id,answer) in [("doubling","117"),("division","1530 = 41 · 37 + 13"),("modular_division","72"),("polynomial","3α³ + α²")] {
   let app=XCUIApplication();open(app,id);XCTAssertFalse(app.segmentedControls["solutionStyle"].exists);capture(id+" — студенческая запись")
   let key="answer_"+(id=="modular_division" ? "modularDivision":id)
   scroll(app,key);XCTAssertEqual(find(app,key).label,answer);capture(id+" — ответ");app.terminate()
  }
 }
 @MainActor func testLibrarySearchProofAndOfflineSource()throws{
  let app=XCUIApplication();app.launch();app.tabBars.buttons["Определения"].tap()
  let search=app.searchFields.firstMatch;XCTAssertTrue(search.waitForExistence(timeout:5));search.tap();search.typeText("порядок\n");XCTAssertTrue(find(app,"reference_order").waitForExistence(timeout:5));scroll(app,"reference_order");find(app,"reference_order").tap();XCTAssertTrue(find(app,"definitionPaper").waitForExistence(timeout:5));capture("Определения — поиск и статья")
  app.navigationBars.buttons.element(boundBy:0).tap();app.tabBars.buttons["Теоремы"].tap();let theoremSearch=app.searchFields.firstMatch;theoremSearch.tap();theoremSearch.typeText("Тонелли");scroll(app,"reference_tonelli-nonresidue");find(app,"reference_tonelli-nonresidue").tap();scroll(app,"referenceProof");capture("Теоремы — доказательство")
  find(app,"theoremSources").tap();scroll(app,"source_L7_5");find(app,"source_L7_5").tap();XCTAssertTrue(find(app,"referencePDF").waitForExistence(timeout:10));XCTAssertEqual(find(app,"referencePDF").value as? String,"1");capture("Исходный PDF — без интернета");find(app,"closeReferenceSource").tap()
 }
 @MainActor func testSignedInputZeroAndRejectedModulus()throws{
  let app=XCUIApplication();open(app,"doubling");find(app,"courseInput").tap();replace(app,"input_a","-1000");replace(app,"input_b","1");solve(app);scroll(app,"answer_doubling");XCTAssertEqual(find(app,"answer_doubling").label,"92")
  find(app,"courseInput").tap();replace(app,"input_m","0");scroll(app,"courseSolve");find(app,"courseSolve").tap();XCTAssertTrue(find(app,"inputError").waitForExistence(timeout:10));XCTAssertFalse(find(app,"answer_doubling").exists)
  app.terminate();open(app,"tonelli");find(app,"courseInput").tap();replace(app,"input_a","2");replace(app,"input_p","7");solve(app);scroll(app,"answer_tonelli");XCTAssertEqual(find(app,"answer_tonelli").label,"Решений нет")
  find(app,"courseInput").tap();replace(app,"input_a","0");solve(app);scroll(app,"answer_tonelli");XCTAssertEqual(find(app,"answer_tonelli").label,"0")
 }

 @MainActor func testPreparationReductionStaysOutsideMainSheet()throws{
  let app=XCUIApplication();open(app,"doubling");find(app,"courseInput").tap();replace(app,"input_m","7");solve(app)
  XCTAssertEqual(app.descendants(matching:.any).matching(identifier:"notebookIntegerTable").count,1)
  find(app,"doublingPreparation_work_0").tap();XCTAssertTrue(find(app,"productResult").waitForExistence(timeout:10));XCTAssertEqual(find(app,"productResult").label,"1");capture("Остаток — отдельное вспомогательное вычисление");close(app)
  scroll(app,"answer_doubling");XCTAssertEqual(find(app,"answer_doubling").label,"5")
 }

}
