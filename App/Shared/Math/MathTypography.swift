import SwiftUI

struct MathLine: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        ScrollView(.horizontal) {
            MathText(text: text).fixedSize()
                .textSelection(.enabled).padding(.vertical, 8)
        }
        .scrollIndicators(.visible)
    }
}

struct MathText: View {
    let text: String
    var body: some View { formattedText.font(AppStyle.math).monospacedDigit() }

    private var formattedText: Text {
        let subscripts: [Character: String] = ["₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9", "ᵢ": "i", "ⱼ": "j"]
        let superscripts: [Character: String] = ["⁰": "0", "¹": "1", "²": "2", "³": "3", "⁴": "4", "⁵": "5", "⁶": "6", "⁷": "7", "⁸": "8", "⁹": "9", "ᶜ": "c", "ˡ": "l", "⁻": "−"]
        var result = Text("")
        var run = ""
        var baseline = 0
        func appendRun() {
            if baseline != 0 {
                result = result + Text(run).font(.system(.caption2, design: .serif)).baselineOffset(CGFloat(baseline))
            } else {
                result = result + Text(run)
            }
        }
        for character in text {
            let nextBaseline = subscripts[character] != nil ? -4 : superscripts[character] != nil ? 8 : 0
            if nextBaseline != baseline {
                appendRun()
                run = ""
                baseline = nextBaseline
            }
            run += subscripts[character] ?? superscripts[character] ?? String(character)
        }
        appendRun()
        return result
    }
}
