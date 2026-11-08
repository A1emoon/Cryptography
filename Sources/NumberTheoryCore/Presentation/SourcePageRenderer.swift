import Foundation
import CoreGraphics
import ImageIO

struct SourcePageRaster: @unchecked Sendable {
    let image: CGImage // Immutable after construction; safe to transfer from a rendering task.
}
enum SourcePageRenderer {
    static func render(url: URL, page number: Int, pixels: Int) throws -> SourcePageRaster {
        try Task.checkCancellation()
        guard (1...2400).contains(pixels) else { throw RenderError.unavailable }
        if url.pathExtension.lowercased() == "pdf" {
            guard let document = CGPDFDocument(url as CFURL), number > 0, number <= document.numberOfPages, let page = document.page(at: number) else { throw RenderError.unavailable }
            return try renderPDFPage(page, pixels: pixels)
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: pixels] as CFDictionary) else { throw RenderError.unavailable }
        try Task.checkCancellation()
        return SourcePageRaster(image: image)
    }
    static func renderPDFPage(_ page: CGPDFPage, pixels: Int) throws -> SourcePageRaster {
        try Task.checkCancellation()
        guard (1...2400).contains(pixels) else { throw RenderError.unavailable }
        let box = page.getBoxRect(.cropBox)
        guard box.width > 0, box.height > 0, box.width.isFinite, box.height.isFinite else { throw RenderError.unavailable }
        let rotated = abs(page.rotationAngle)%180 != 0
        let pageSize = rotated ? CGSize(width: box.height, height: box.width) : box.size
        let factor = CGFloat(pixels)/max(pageSize.width, pageSize.height)
        let width = max(1, Int((pageSize.width*factor).rounded())), height = max(1, Int((pageSize.height*factor).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw RenderError.unavailable }
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // CGPDFPage's fitting transform does not magnify a small page into a larger rectangle.
        // Scale the bitmap context explicitly, then let Core Graphics geometry handle crop/rotation at native size.
        context.scaleBy(x: CGFloat(width)/pageSize.width, y: CGFloat(height)/pageSize.height)
        context.concatenate(page.getDrawingTransform(.cropBox, rect: CGRect(origin: .zero, size: pageSize), rotate: 0, preserveAspectRatio: true))
        context.drawPDFPage(page)
        try Task.checkCancellation()
        guard let image = context.makeImage() else { throw RenderError.unavailable }
        return SourcePageRaster(image: image)
    }
    enum RenderError: LocalizedError { case unavailable; var errorDescription: String? { "Не удалось открыть страницу конспекта." } }
}
