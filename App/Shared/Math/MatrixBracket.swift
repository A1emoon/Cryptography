import SwiftUI

struct MatrixBracket: Shape {
    let right: Bool
    func path(in rect: CGRect) -> Path {
        let outside = right ? rect.maxX - 1 : rect.minX + 1
        let inside = right ? rect.minX + 1 : rect.maxX - 1
        var p = Path()
        p.move(to: CGPoint(x: inside, y: rect.minY + 1))
        p.addCurve(to: CGPoint(x: inside, y: rect.maxY - 1),
                   control1: CGPoint(x: outside, y: rect.height * 0.15),
                   control2: CGPoint(x: outside, y: rect.height * 0.85))
        return p
    }
}

