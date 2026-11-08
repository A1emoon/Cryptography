import SwiftUI

/// Typesets the small ^{...}/_{...} notation used by the local course data.
/// Ordinary prose, glossary links and nested exponents keep their attributes.
enum ReferenceMathTypesetting {
    /// Normalise Unicode script glyphs before layout so indices use the surrounding math font.
    static func expandedScripts(_ source: String) -> String {
        let superscripts = Set("⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁼⁽⁾ⁿⁱᵃᵇᶜᵈᵉᶠᵍʰʲᵏˡᵐᵒᵖʳˢᵗᵘᵛʷˣʸᶻᵞᑫᵠᴺᴳᴱᴵᴰᴮ")
        let subscripts = Set("₀₁₂₃₄₅₆₇₈₉₊₋₌₍₎ₐₑₕᵢⱼₖₗₘₙₒₚᵣₛₜᵤᵥₓ")
        var result = "", content = "", mode: Character?
        func flush() {
            if let marker = mode { result += String(marker) + "{" + content + "}" }
            content = ""; mode = nil
        }
        for c in source {
            let next: Character? = superscripts.contains(c) ? "^" : subscripts.contains(c) ? "_" : nil
            if let next {
                if mode != next { flush(); mode = next }
                content += c == "ᑫ" ? "q" : String(c).precomposedStringWithCompatibilityMapping
            } else { flush(); result.append(c) }
        }
        flush()
        return result
    }
    static func format(_ source: AttributedString, text: String, baseSize: CGFloat? = nil) -> AttributedString {
        var result = source
        struct Script { let marker: String.Index; let content: Range<String.Index>; let removed: [Range<String.Index>]; let subscripted: Bool }
        var scripts: [Script] = []
        func closing(_ opening: String.Index) -> String.Index? {
            let open = text[opening], close: Character = open == "{" ? "}" : ")"
            var depth = 0, i = opening
            while i < text.endIndex {
                if text[i] == open { depth += 1 }
                if text[i] == close { depth -= 1; if depth == 0 { return i } }
                i = text.index(after: i)
            }
            return nil
        }
        for marker in text.indices where text[marker] == "^" || text[marker] == "_" {
            let start = text.index(after: marker)
            guard start < text.endIndex else { continue }
            var end = start
            var removals = [marker..<start]
            var contentStart = start
            if text[start] == "{" || text[start] == "(" {
                guard let last = closing(start) else { continue }
                end = last
                contentStart = text.index(after: start)
                removals += [start..<contentStart, last..<text.index(after: last)]
            } else {
                while end < text.endIndex && (text[end].isLetter || text[end].isNumber) { end = text.index(after: end) }
                if end == start, !text[start].isWhitespace { end = text.index(after: start) }
                if text[marker] == "^", end < text.endIndex, text[end] == "(", let last = closing(end) { end = text.index(after: last) }
            }
            guard contentStart < end else { continue }
            scripts.append(Script(marker: marker, content: contentStart..<end, removed: removals, subscripted: text[marker] == "_"))
        }
        for script in scripts {
            guard let lower = AttributedString.Index(script.content.lowerBound, within: result), let upper = AttributedString.Index(script.content.upperBound, within: result) else { continue }
            let parents = scripts.filter { $0.marker < script.marker && $0.content.contains(script.marker) }
            let offset = parents.reduce(CGFloat(0)) { $0 + ($1.subscripted ? -4 : 6) } + (script.subscripted ? -4 : 6)
            if let baseSize {
                result[lower..<upper].font = .system(size: baseSize * (parents.isEmpty ? 0.68 : 0.53), design: .serif)
            } else { result[lower..<upper].font = .system(parents.isEmpty ? .caption : .caption2, design: .serif) }
            #if os(watchOS)
            result[lower..<upper].swiftUI.baselineOffset = offset * ((baseSize ?? 20) / 20)
            #else
            result[lower..<upper].uiKit.baselineOffset = offset * ((baseSize ?? 20) / 20)
            #endif
        }
        for range in scripts.flatMap(\.removed).sorted(by: { $0.lowerBound > $1.lowerBound }) {
            if let lower = AttributedString.Index(range.lowerBound, within: result), let upper = AttributedString.Index(range.upperBound, within: result) { result.replaceSubrange(lower..<upper, with: AttributedString("")) }
        }
        return result
    }
}
struct ReferenceMathText: View {
    let text: String
    var body: some View {
        Text(ReferenceMathTypesetting.format(AttributedString(text), text: text))
            .font(AppStyle.math).monospacedDigit().padding(.vertical, 4)
    }
}
struct ReferenceFormulaView: View {
    let formula: [ReferenceAtom]
    var reason: StudyReason? = nil
    var identifier = "referenceFormula"
    private var atoms: [StudentMathAtom] {
        formula.flatMap { atom in
            guard atom.kind == "text" else { return [atom.student] }
            let s = atom.a
            var depth = 0, start = s.startIndex, parts: [StudentMathAtom] = []
            for i in s.indices {
                let c = s[i]
                if "({[".contains(c) { depth += 1 }
                if ")}]".contains(c) { depth = max(0, depth - 1) }
                if depth == 0 && "=≡⇒⇔".contains(c) {
                    let prefix = String(s[start..<i]).trimmingCharacters(in: .whitespaces)
                    if !prefix.isEmpty { parts.append(.rich(prefix)) }
                    parts.append(.text(String(c))); start = s.index(after: i)
                }
            }
            let rest = String(s[start...]).trimmingCharacters(in: .whitespaces)
            if !rest.isEmpty { parts.append(.rich(rest)) }
            return parts
        }
    }
    var body: some View {
        if let reason { StudyLine(id: identifier, atoms: atoms, reason: reason) }
        else { StudentFormulaView(atoms: atoms) }
    }
}

/// Plain mathematical writing for the theorem page: native wrapping, no controls or links.
struct ReferencePaperFormulaView: View {
    let formula: [ReferenceAtom]
    private func spaced(_ source: String) -> String {
        var result = "", depth = 0
        for c in source {
            if "({[".contains(c) { depth += 1 }
            if ")}]".contains(c) { depth = max(0, depth - 1) }
            if depth == 0 && "=≡⇒⇔≤≥→".contains(c) {
                if result.last?.isWhitespace == false { result.append(" ") }
                result.append(c); result.append(" ")
            } else {
                result.append(c)
                if depth == 0 && ";,".contains(c) { result.append(" ") }
            }
        }
        return result
    }
    var body: some View {
        if formula.count == 1, let atom = formula.first, atom.kind == "text" {
            let text = spaced(ReferenceMathTypesetting.expandedScripts(atom.a))
            Text(ReferenceMathTypesetting.format(AttributedString(text), text: text))
                .font(AppStyle.math).monospacedDigit()
                .lineSpacing(7).fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 3).courseMathRow()
        } else {
            ReferenceFormulaView(formula: formula)
        }
    }
}
