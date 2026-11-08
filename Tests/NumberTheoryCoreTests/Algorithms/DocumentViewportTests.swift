import XCTest
@testable import NumberTheoryCore

final class DocumentViewportTests: XCTestCase {
    func testCrownRangeAndInvalidInputs() {
        XCTAssertEqual(DocumentViewport.zoom(-100),1)
        XCTAssertEqual(DocumentViewport.zoom(100),6)
        XCTAssertEqual(DocumentViewport.zoom(.nan),1)
        XCTAssertEqual(DocumentViewport.zoom(.infinity),1)
        XCTAssertEqual(DocumentViewport.zoom(2.35),2.35)
    }
    func testFitPreservesPageAspectAndPanCannotLeaveThePage() {
        let page=DocumentSize(width:1000,height:1400), viewport=DocumentSize(width:170,height:110)
        let fit=DocumentViewport.fit(page:page,viewport:viewport)
        XCTAssertEqual(fit.height,110,accuracy:1e-9)
        XCTAssertEqual(fit.width/fit.height,page.width/page.height,accuracy:1e-9)
        XCTAssertEqual(DocumentViewport.offset(DocumentPoint(x:1000,y:1000),page:page,viewport:viewport,zoom:1),DocumentPoint())
        for level in 1...60 {
            let zoom=Double(level)/10
            let p=DocumentViewport.offset(DocumentPoint(x:1e9,y:-1e9),page:page,viewport:viewport,zoom:zoom)
            XCTAssertLessThanOrEqual(abs(p.x),max(0,(fit.width*DocumentViewport.zoom(zoom)-viewport.width)/2)+1e-9)
            XCTAssertLessThanOrEqual(abs(p.y),max(0,(fit.height*DocumentViewport.zoom(zoom)-viewport.height)/2)+1e-9)
        }
        let shifted=DocumentViewport.offset(DocumentPoint(x:1000,y:1000),page:page,viewport:viewport,zoom:3)
        XCTAssertEqual(shifted.y,110,accuracy:1e-9)
        XCTAssertEqual(DocumentViewport.offset(shifted,page:page,viewport:viewport,zoom:1),DocumentPoint())
    }
    func testLandscapeAndDegeneratePagesHaveFiniteGeometry() {
        let viewport=DocumentSize(width:198,height:120)
        let landscape=DocumentViewport.fit(page:DocumentSize(width:4032,height:3024),viewport:viewport)
        XCTAssertLessThanOrEqual(landscape.width,viewport.width)
        XCTAssertLessThanOrEqual(landscape.height,viewport.height)
        for page in [DocumentSize(width:0,height:0),DocumentSize(width:.nan,height:10),DocumentSize(width:1,height:.infinity)] {
            XCTAssertEqual(DocumentViewport.fit(page:page,viewport:viewport),DocumentSize(width:0,height:0))
            XCTAssertEqual(DocumentViewport.offset(DocumentPoint(x:.nan,y:.infinity),page:page,viewport:viewport,zoom:6),DocumentPoint())
        }
    }
}
