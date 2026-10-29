import SwiftUI

struct FloorFractionView: View {
    let numerator: String
    let denominator: String
    @ScaledMetric(relativeTo: .title3) private var bracketWidth = 8.0
    var body: some View {
        VStack(spacing: 14) {
            MathText(text: numerator).fixedSize()
            MathText(text: denominator).fixedSize()
        }
        .padding(.horizontal, 4)
        .overlay { Rectangle().fill(Color.primary).frame(height: 1) }
        .padding(.horizontal, bracketWidth + 4).padding(.vertical, 4)
        .overlay(alignment: .leading) { FloorBracket(isRight: false).stroke(lineWidth: 1.25).frame(width: bracketWidth) }
        .overlay(alignment: .trailing) { FloorBracket(isRight: true).stroke(lineWidth: 1.25).frame(width: bracketWidth) }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Целая часть дроби: числитель \(numerator), знаменатель \(denominator)")
    }
}

private struct FloorBracket: Shape {
    let isRight: Bool
    func path(in rect: CGRect) -> Path {
        let x = isRight ? rect.maxX - 1 : rect.minX + 1
        let endX = isRight ? rect.minX + 1 : rect.maxX - 1
        var path = Path()
        path.move(to: CGPoint(x: x, y: rect.minY + 1))
        path.addLine(to: CGPoint(x: x, y: rect.maxY - 1))
        path.addLine(to: CGPoint(x: endX, y: rect.maxY - 1))
        return path
    }
}

struct BinaryLengthView: View {
    let info: BinaryLength
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if info.number.isZero {
                MathLine("a = 0")
            } else {
                MathLine("l₂(\(info.number)) = \(info.length)")
                MathLine("\(PowerNotation.two(info.length - 1)) = \(info.lowerPower) ≤ \(info.number) < \(info.upperPower) = \(PowerNotation.two(info.length))")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct DivisorChainView: View {
    let shifts: [DivisorShift]
    let dividend: Natural
    let boundSymbol: String
    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .center, spacing: 10) {
                ForEach(shifts) { shift in
                    HStack(spacing: 10) {
                        if shift.id > 0 {
                            VStack(spacing: 3) {
                                Text(String(shift.id)).font(.caption2)
                                Text("<<").font(.caption2.monospaced())
                                Text("→").font(.title3)
                            }
                            .foregroundStyle(.secondary)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Шаг \(shift.id): сдвиг влево на один бит")
                        }
                        VStack(spacing: 6) {
                            Text(shift.multiple.description).font(AppStyle.math).monospacedDigit()
                            Text((shift.multiple <= dividend ? "≤ " : "> ") + boundSymbol).font(.caption2)
                                .foregroundStyle(shift.multiple <= dividend ? AppStyle.accent : .secondary)
                        }
                        .fixedSize()
                    }
                }
            }
            .padding(.vertical, 10)
        }
        .scrollIndicators(.visible)
    }
}
