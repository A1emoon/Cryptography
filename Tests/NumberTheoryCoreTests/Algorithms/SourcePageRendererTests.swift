import XCTest
import CoreGraphics
@testable import NumberTheoryCore

final class SourcePageRendererTests: XCTestCase {
    private func page() throws -> (CGPDFDocument, CGPDFPage) {
        // A deterministic in-memory PDF fixture with a coloured square and known margins.
        let data = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: data))
        var box = CGRect(x: 0, y: 0, width: 100, height: 100)
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 20, y: 20, width: 60, height: 60))
        context.endPDFPage(); context.closePDF()
        let provider = try XCTUnwrap(CGDataProvider(data: data))
        let document = try XCTUnwrap(CGPDFDocument(provider))
        return (document, try XCTUnwrap(document.page(at: 1)))
    }
    private func redCoverage(_ image: CGImage) throws -> Double {
        let data = try XCTUnwrap(image.dataProvider?.data)
        let bytes = try XCTUnwrap(CFDataGetBytePtr(data))
        var count = 0
        for y in 0..<image.height {
            for x in 0..<image.width {
                let p = y*image.bytesPerRow + x*4
                if bytes[p] > 200 && bytes[p+1] < 40 && bytes[p+2] < 40 { count += 1 }
            }
        }
        return Double(count)/Double(image.width*image.height)
    }
    func testHigherResolutionActuallyMagnifiesThePDFContent() throws {
        let (document, page) = try page()
        XCTAssertEqual(document.numberOfPages, 1)
        for pixels in [100, 400, 1200] {
            let raster = try SourcePageRenderer.renderPDFPage(page, pixels: pixels)
            XCTAssertEqual(raster.image.width, pixels)
            XCTAssertEqual(raster.image.height, pixels)
            // The red square must keep 60% of each dimension at every resolution.
            // A merely centred, unscaled PDF occupies 1/16 of the expected area at 400px.
            XCTAssertEqual(try redCoverage(raster.image), 0.36, accuracy: 0.015)
        }
    }
    func testInvalidRasterDimensionsAreRejected() throws {
        let (document, page) = try page()
        XCTAssertEqual(document.numberOfPages, 1)
        XCTAssertThrowsError(try SourcePageRenderer.renderPDFPage(page, pixels: 0))
        XCTAssertThrowsError(try SourcePageRenderer.renderPDFPage(page, pixels: 2401))
    }
}
