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
 @MainActor func testCompactOrderWithExpandableReasons()throws{
  let app=XCUIApplication();open(app,"order")
  XCTAssertFalse(find(app,"orderSplit").exists);XCTAssertFalse(find(app,"orderLCMGCD_0").exists)
        XCTAssertTrue(find(app,"orderDivisors_5_part_0").label.contains("d(4)"))
        XCTAssertTrue(find(app,"orderLCM_part_0").label.contains("НОК("))
  let candidates="orderLiftCandidates_25",growth="orderLiftResult_125"
  for id in [candidates,growth] {
   XCTAssertFalse(find(app,id+"_explanationContent").exists)
   scroll(app,id+"_explanation");let button=app.buttons[id+"_explanation"].firstMatch
   XCTAssertEqual(button.value as? String,"Свернуто");button.tap()
   XCTAssertTrue(find(app,id+"_explanationContent").waitForExistence(timeout:5))
   capture("Порядок — раскрытое пояснение "+id)
   scroll(app,id+"_explanation",down:true);button.tap()
   XCTAssertFalse(find(app,id+"_explanationContent").exists)
  }
  XCTAssertEqual(find(app,"answer_order").label,"100");capture("Порядок — компактная запись возвращена")
 }
 @MainActor func testFirstTasksOrderAndNestedCalculation()throws{
  let app=XCUIApplication();open(app,"order")
  XCTAssertTrue(find(app,"orderPrime_2").exists)
  XCTAssertTrue(find(app,"orderDivisors_5").exists)
  XCTAssertTrue(find(app,"orderLiftCandidates_25").exists)
  XCTAssertTrue(find(app,"orderLift_25_power_4").exists)
  XCTAssertFalse(find(app,"orderFactorization_work_0").exists)
  capture("Порядок — запись по простым степеням")
  scroll(app,"orderPrime_5_power_2_work_0");find(app,"orderPrime_5_power_2_work_0").tap()
  XCTAssertTrue(find(app,"notebookIntegerTable").waitForExistence(timeout:8));capture("Порядок — умножение на полях");close(app)
  scroll(app,"orderLCM_reason");capture("Порядок — НОК и НОД, итог 100")
  XCTAssertEqual(find(app,"answer_order").label,"100")
  find(app,"courseInput").tap();find(app,"courseExamples").tap();app.buttons["Практика · P₈₁₂₅(37)"].tap();solve(app)
  XCTAssertTrue(find(app,"orderPrime_13_power_6").exists)
  XCTAssertTrue(find(app,"orderLiftResult_625").exists)
  XCTAssertEqual(find(app,"answer_order").label,"1500")
  scroll(app,"orderPrime_13_power_2_reason");capture("Порядок — проверки делителей по модулю 13")
 }
 @MainActor func testCubicShanksShowsOrderProofAndModuli()throws{
  let app=XCUIApplication();open(app,"tonelli")
  XCTAssertTrue(find(app,"tonelliCubicOrderProof").exists)
  XCTAssertTrue(find(app,"tonelliCubicVerification_2").exists)
  XCTAssertTrue(find(app,"tonelliCubicCompleteness").exists)
  XCTAssertEqual(find(app,"tonelliCriterion_square_2_part_2").label,"Сравнимо по модулю 163")
  XCTAssertEqual(find(app,"answer_tonelli").label,"19, 20, 124")
  scroll(app,"tonelliCubicOrderProof_reason");capture("Кубический Шенкс — доказанный порядок перед k")
  XCTAssertTrue(find(app,"tonelliCubicVerification_2_square_work_2").exists)
  XCTAssertEqual(find(app,"tonelliCubicVerification_2_part_2").label,"124^{2} · 124")
  scroll(app,"tonelliCubicVerification_2_square_reason");capture("Кубический Шенкс — квадрат перед кубом 124")
  scroll(app,"tonelliCubicVerification_2_work_4");find(app,"tonelliCubicVerification_2_work_4").tap()
  XCTAssertTrue(find(app,"notebookIntegerTable").waitForExistence(timeout:8));capture("Кубический Шенкс — умножение 15376 на 124");close(app)
  scroll(app,"tonelliCubicVerification_2_reason");capture("Кубический Шенкс — проверка корней и полнота")
 }
 @MainActor func testQuadraticShanksMatchesLectureCorrections()throws{
  let app=XCUIApplication();open(app,"tonelli")
  find(app,"courseInput").tap();find(app,"courseExamples").tap();find(app,"tonelliExample_2_15_17").tap();solve(app)
  XCTAssertTrue(find(app,"tonelliInitialOrder_part_0").label.contains("= 8"))
  XCTAssertTrue(find(app,"tonelliCorrectedOrder_0_part_0").label.contains("= 2"))
  XCTAssertTrue(find(app,"tonelliCorrectedOrder_1_part_0").label.contains("= 1"))
  XCTAssertFalse(find(app,"tonelliK").exists);XCTAssertFalse(find(app,"tonelliB").exists)
  XCTAssertEqual(find(app,"tonelliCorrected_0_part_1").label,"Сравнимо по модулю 17")
  XCTAssertEqual(find(app,"answer_tonelli").label,"7, 10")
  scroll(app,"tonelliCorrected_0_reason");capture("Шенкс — первая корректировка и фактический порядок 2")
  scroll(app,"tonelliCorrected_1_reason");capture("Шенкс — вторая корректировка и порядок 1")
  scroll(app,"tonelliVerification_1_reason");capture("Шенкс — корни 7 и 10 с проверкой")
 }
 @MainActor func testShanksDoesNotRepeatTheSameSquare()throws{
  let app=XCUIApplication();open(app,"tonelli")
  find(app,"courseInput").tap();app.segmentedControls["rootDegree"].buttons["x²"].tap()
  replace(app,"input_a","15");replace(app,"input_p","17");solve(app)
  XCTAssertTrue(find(app,"tonelliOrder_0").exists)
  XCTAssertFalse(find(app,"tonelliOrder_0_square_2").exists)
  XCTAssertEqual(find(app,"tonelliOrder_0_part_0").label,"15 в степени 2")
  XCTAssertEqual(find(app,"tonelliOrder_0_part_1").label,"Сравнимо по модулю 17")
  XCTAssertEqual(find(app,"answer_tonelli").label,"7, 10")
  scroll(app,"tonelliOrder_0_reason");capture("Шенкс — квадрат одной цепочкой без повтора")
  scroll(app,"tonelliOrder_0_work_2");find(app,"tonelliOrder_0_work_2").tap()
  XCTAssertTrue(find(app,"notebookIntegerTable").waitForExistence(timeout:8));close(app)
 }
 @MainActor func testTonelliCubeSquareAndReasons()throws{
  let app=XCUIApplication();open(app,"tonelli")
  XCTAssertTrue(find(app,"tonelliCriterion_square_2").waitForExistence(timeout:8))
  XCTAssertTrue(find(app,"tonelliCriterion_square_32").exists)
  XCTAssertTrue(find(app,"tonelliCriterion").exists)
  XCTAssertFalse(find(app,"tonelliCriterion_work_0").exists)
  capture("Тонелли — последовательные квадраты на основном листе")
  scroll(app,"tonelliCriterion_square_2_work_0");find(app,"tonelliCriterion_square_2_work_0").tap()
  XCTAssertTrue(app.staticTexts["Удвоение–сложение"].waitForExistence(timeout:5))
  XCTAssertTrue(find(app,"notebookIntegerTable").waitForExistence(timeout:8));capture("Тонелли — только умножение на отдельном листе");close(app)
  scroll(app,"tonelliCriterion_reason");find(app,"tonelliCriterion_reason").tap();XCTAssertTrue(app.staticTexts["Проверка существования корней"].waitForExistence(timeout:5));close(app)
  XCTAssertEqual(find(app,"answer_tonelli").label,"19, 20, 124")
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

 @MainActor func testTonelliPhotographedLectureAndExamplePicker() throws {
  let app=XCUIApplication();open(app,"tonelli")
  for id in ["tonelliOrder_0","tonelliOrder_1","tonelliIdentity_0","tonelliRegroup_1","tonelliExtract"] {XCTAssertTrue(find(app,id).exists,id)}
  scroll(app,"tonelliCriterion_reason");capture("Тонелли — полная цепочка критерия")
  scroll(app,"tonelliIdentity_0_reason");capture("Тонелли — подстановка B и сложение показателей без скрытых шагов")
  XCTAssertEqual(find(app,"answer_tonelli").label,"19, 20, 124")
  find(app,"courseInput").tap();scroll(app,"courseExamples");find(app,"courseExamples").tap();find(app,"tonelliExample_2_5_41").tap();solve(app)
  XCTAssertTrue(find(app,"tonelliCriterion").exists)
  XCTAssertFalse(find(app,"tonelliCriterion_work_0").exists)
  capture("Тонелли — цепочка символа Лежандра на основном листе")
  XCTAssertEqual(find(app,"answer_tonelli").label,"13, 28")
 }


}
