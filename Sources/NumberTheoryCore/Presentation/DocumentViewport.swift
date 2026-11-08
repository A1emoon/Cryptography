import Foundation

struct DocumentPoint: Equatable, Sendable {
    var x: Double = 0
    var y: Double = 0
}
struct DocumentSize: Equatable, Sendable {
    let width: Double
    let height: Double
}
/// Geometry shared by Crown zoom, buttons, dragging and accessibility adjustments.
enum DocumentViewport {
    static func zoom(_ value: Double) -> Double { value.isFinite ? min(6, max(1, value)) : 1 }
    static func fit(page: DocumentSize, viewport: DocumentSize) -> DocumentSize {
        guard page.width > 0, page.height > 0, viewport.width > 0, viewport.height > 0,
              page.width.isFinite, page.height.isFinite, viewport.width.isFinite, viewport.height.isFinite else {
            return DocumentSize(width: 0, height: 0)
        }
        let scale = min(viewport.width/page.width, viewport.height/page.height)
        return DocumentSize(width: page.width*scale, height: page.height*scale)
    }
    static func offset(_ proposed: DocumentPoint, page: DocumentSize, viewport: DocumentSize, zoom value: Double) -> DocumentPoint {
        let size = fit(page: page, viewport: viewport), scale = zoom(value)
        let x = max(0, (size.width*scale-viewport.width)/2), y = max(0, (size.height*scale-viewport.height)/2)
        return DocumentPoint(x: min(x, max(-x, proposed.x.isFinite ? proposed.x : 0)), y: min(y, max(-y, proposed.y.isFinite ? proposed.y : 0)))
    }
}
