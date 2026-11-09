import SwiftUI

/// The source transcription and the explanatory article are intentionally independent.
struct ReferenceDefinitionPage: View {
    let entry: ReferenceEntry
    @State private var sources = false
    @State private var explanation = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let definition = entry.verbatimDefinition {
                    if !definition.heading.isEmpty {
                        DefinitionMathText(text: definition.heading)
                            .accessibilityIdentifier("referenceTitle")
                    }
                    ForEach(definition.blocks.indices, id: \.self) { index in
                        DefinitionBlockView(block: definition.blocks[index])
                    }
                } else {
                    // Supporting articles are not presented as verbatim lecture quotations.
                    DefinitionMathText(text: entry.title).accessibilityIdentifier("referenceTitle")
                    DefinitionMathText(text: entry.body)
                    ForEach(entry.formulas.indices, id: \.self) { index in
                        ReferencePaperFormulaView(formula: entry.formulas[index])
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppStyle.pagePadding).padding(.top, AppStyle.paperTop).padding(.bottom, 44)
                .accessibilityElement(children: .contain).accessibilityIdentifier("definitionPaper")
        }.courseReferenceAppearance()
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .coursePaperNavigation()
            .toolbar { CoursePageTools(firstTitle: "Источники", firstIcon: "books.vertical", firstID: "definitionSources", firstAction: { sources = true }, secondTitle: "Разбор", secondIcon: "text.bubble", secondID: "definitionExplanation", secondAction: { explanation = true }) }
            .sheet(isPresented: $sources) { ReferenceArticleSources(entry: entry) }
            .sheet(isPresented: $explanation) {
                StudentDetailSheet(title: "Разбор определения", large: true) {
                    ReferenceArticleContent(entry: entry)
                }
            }
    }
}
struct DefinitionMathText: View {
    let text: String
    var size: CGFloat = AppStyle.referenceFontSize
    var body: some View {
        let expanded = ReferenceMathTypesetting.expandedScripts(text)
        Text(ReferenceMathTypesetting.format(AttributedString(expanded), text: expanded, baseSize: size))
            .font(.system(size: size, design: .serif)).monospacedDigit()
            .lineSpacing(7).fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 4)
    }
}
private struct DefinitionBlockView: View {
    let block: ReferenceDefinitionBlock
    var body: some View {
        #if os(watchOS)
        writtenBlock.courseMathRow().accessibilityIdentifier("definitionBlockScroll")
        #else
        writtenBlock
        #endif
    }
    @ViewBuilder private var writtenBlock: some View {
        switch block.kind {
        case "text": DefinitionMathText(text: block.text)
        case "set":
            #if os(watchOS)
            HStack(spacing: 8) {
                DefinitionFormula(atoms: block.prefix)
                setContents
            }.fixedSize().accessibilityElement(children: .contain).accessibilityIdentifier("definitionSet")
            #else
            VStack(alignment: .leading, spacing: 14) {
                DefinitionFormula(atoms: block.prefix)
                HStack(spacing: 6) {
                    DefinitionBracket(curly: true).stroke(AppStyle.paperInk, lineWidth: 1.3).frame(width: 12)
                    DefinitionFormula(atoms: block.atoms, wraps: false)
                    Rectangle().frame(width: 1)
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(block.rows.indices, id: \.self) { index in DefinitionFormula(atoms: block.rows[index].value) }
                    }
                    DefinitionBracket(curly: true).stroke(AppStyle.paperInk, lineWidth: 1.3).frame(width: 12).scaleEffect(x: -1, y: 1)
                }.fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .contain).accessibilityIdentifier("definitionSet")
            }
            #endif
        case "cases", "system":
            #if os(watchOS)
            HStack(alignment: .center, spacing: 10) {
                DefinitionFormula(atoms: block.prefix, wraps: false)
                rows
            }.fixedSize()
            #else
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 10) {
                    DefinitionFormula(atoms: block.prefix, wraps: false)
                    rows.fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 12) {
                    if !block.prefix.isEmpty { DefinitionFormula(atoms: block.prefix) }
                    rows
                }
            }
            #endif
        default: DefinitionFormula(atoms: block.atoms)
        }
    }
    private var setContents: some View {
        HStack(spacing: 6) {
            DefinitionBracket(curly: true).stroke(AppStyle.paperInk, lineWidth: 1.3).frame(width: 12)
            DefinitionFormula(atoms: block.atoms, wraps: false)
            Rectangle().frame(width: 1)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(block.rows.indices, id: \.self) { index in DefinitionFormula(atoms: block.rows[index].value) }
            }
            DefinitionBracket(curly: true).stroke(AppStyle.paperInk, lineWidth: 1.3).frame(width: 12).scaleEffect(x: -1, y: 1)
        }.fixedSize(horizontal: true, vertical: false)
    }
    private var rows: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 14) {
            ForEach(block.rows.indices, id: \.self) { index in
                GridRow(alignment: .center) {
                    DefinitionFormula(atoms: block.rows[index].value)
                        .accessibilityElement(children: .contain).accessibilityIdentifier("definitionCase_\(index)")
                    if !block.rows[index].condition.isEmpty { DefinitionFormula(atoms: block.rows[index].condition) }
                }.accessibilityElement(children: .contain).accessibilityIdentifier("definitionCase_\(index)")
            }
        }.padding(.leading, block.bracket == "brace" ? 21 : 14)
            .padding(.vertical, 8)
            .background(alignment: .leading) {
                DefinitionBracket(curly: block.bracket == "brace").stroke(AppStyle.paperInk, lineWidth: 1.3).frame(width: block.bracket == "brace" ? 15 : 8)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(block.bracket == "brace" ? "definitionSystem" : "definitionCases")
    }
}
/// Stretchable brackets; the multi-line alternatives in the notes use a square bracket.
private struct DefinitionBracket: Shape {
    let curly: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        if !curly {
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        } else {
            let w = rect.width, h = rect.height
            p.move(to: CGPoint(x: w, y: 0))
            p.addCurve(to: CGPoint(x: w*0.55, y: h*0.25), control1: CGPoint(x: w*0.35, y: 0), control2: CGPoint(x: w*0.55, y: h*0.12))
            p.addCurve(to: CGPoint(x: 0, y: h*0.5), control1: CGPoint(x: w*0.55, y: h*0.43), control2: CGPoint(x: w*0.3, y: h*0.5))
            p.addCurve(to: CGPoint(x: w*0.55, y: h*0.75), control1: CGPoint(x: w*0.3, y: h*0.5), control2: CGPoint(x: w*0.55, y: h*0.57))
            p.addCurve(to: CGPoint(x: w, y: h), control1: CGPoint(x: w*0.55, y: h*0.88), control2: CGPoint(x: w*0.35, y: h))
        }
        return p
    }
}
struct DefinitionFormula: View {
    let atoms: [ReferenceAtom]
    var wraps = true
    var size: CGFloat = AppStyle.referenceFontSize
    var body: some View {
        #if os(watchOS)
        HStack(alignment: .definitionMathAxis, spacing: 5) { cells }.fixedSize(horizontal: true, vertical: false)
        #else
        if wraps {
            DefinitionFlow(spacing: 5) { cells }
        } else {
            HStack(alignment: .center, spacing: 5) { cells }.fixedSize(horizontal: true, vertical: false)
        }
        #endif
    }
    @ViewBuilder private var cells: some View {
        ForEach(atoms.indices, id: \.self) { index in
            DefinitionAtom(atom: atoms[index], size: size)
        }
    }
}
private struct DefinitionAtom: View {
    let atom: ReferenceAtom
    let size: CGFloat
    var body: some View {
        Group {
        switch atom.kind {
        case "sum", "product":
            HStack(spacing: 5) {
                VStack(spacing: 0) {
                    DefinitionMathText(text: atom.b, size: size*0.62)
                    Text(atom.kind == "sum" ? "∑" : "∏").font(.system(size: size*1.65, design: .serif))
                    DefinitionMathText(text: atom.a, size: size*0.62)
                }.fixedSize()
                DefinitionMathText(text: atom.c, size: size)
            }
        case "symbol", "fraction":
            HStack(spacing: 3) {
                if atom.kind == "symbol" { Text("(").font(.system(size: size*2, design: .serif)) }
                VStack(spacing: 1) {
                    DefinitionMathText(text: atom.a, size: size)
                    Rectangle().frame(height: 1)
                    DefinitionMathText(text: atom.b, size: size)
                }.fixedSize(horizontal: true, vertical: false)
                if atom.kind == "symbol" { Text(")").font(.system(size: size*2, design: .serif)) }
            }
        case "underProduct":
            VStack(spacing: 1) {
                DefinitionAtom(atom: ReferenceAtom(kind: "product", a: atom.a, b: atom.b, c: atom.c), size: size)
                DefinitionUnderBracket().stroke(AppStyle.paperInk, lineWidth: 1).frame(height: 8)
                DefinitionMathText(text: "Q", size: size*0.7)
            }.fixedSize()
        case "productSymbol":
            HStack(spacing: 6) {
                VStack(spacing: 0) {
                    DefinitionMathText(text: atom.b, size: size*0.62)
                    Text("∏").font(.system(size: size*1.65, design: .serif))
                    DefinitionMathText(text: atom.a, size: size*0.62)
                }
                DefinitionAtom(atom: ReferenceAtom(kind: "symbol", a: atom.c, b: "q_j", c: ""), size: size)
            }.fixedSize()
        case "congruence":
            VStack(spacing: 0) {
                DefinitionMathText(text: atom.a, size: size*0.62)
                Text(atom.b.isEmpty ? "≡" : atom.b).font(.system(size: size, design: .serif))
            }.fixedSize().padding(.bottom, 6)
        case "operator":
            VStack(spacing: 0) {
                DefinitionMathText(text: atom.a, size: size)
                if atom.c.isEmpty { DefinitionMathText(text: atom.b, size: size*0.62) }
                else {
                    HStack(alignment: .definitionMathAxis, spacing: 2) {
                        DefinitionMathText(text: "a^n", size: size*0.62)
                        DefinitionAtom(atom: ReferenceAtom(kind: "congruence", a: atom.c, b: "", c: ""), size: size*0.62)
                        DefinitionMathText(text: "1", size: size*0.62)
                    }
                }
            }.fixedSize()
        case "overline":
            DefinitionMathText(text: atom.a, size: size)
                .overlay(alignment: .top) { Rectangle().frame(height: 1) }
        case "power": DefinitionMathText(text: atom.a + "^{" + atom.b + "}", size: size)
        default: DefinitionMathText(text: atom.a, size: size)
        }
        }.alignmentGuide(.definitionMathAxis) { dimensions in
            switch atom.kind {
            case "congruence": dimensions.height - size*0.6 - 6
            case "operator": dimensions[.firstTextBaseline] - size*0.33
            case "underProduct": dimensions.height/2 - size*0.8
            default: dimensions.height/2
            }
        }
    }
}

/// Measures long text cells with the available width and vertically centres stacked notation.
private struct DefinitionFlow: Layout {
    let spacing: CGFloat
    private struct Placement { let point: CGPoint; let size: CGSize }
    private func arrange(_ subviews: Subviews, width: CGFloat) -> (CGSize, [Placement]) {
        let width = max(1, width)
        var rows: [[(Int, CGSize, CGFloat)]] = [[]], rowWidth: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let ideal = subview.sizeThatFits(.unspecified)
            let size = ideal.width > width ? subview.sizeThatFits(ProposedViewSize(width: width, height: nil)) : ideal
            if rowWidth > 0 && rowWidth + spacing + size.width > width + 0.5 { rows.append([]); rowWidth = 0 }
            let axis = subview.dimensions(in: ProposedViewSize(size))[.definitionMathAxis]
            rows[rows.count-1].append((index, size, axis))
            rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
        }
        var points = Array(repeating: Placement(point: .zero, size: .zero), count: subviews.count)
        var y: CGFloat = 0, used: CGFloat = 0
        for row in rows {
            let above = row.map { $0.2 }.max() ?? 0
            let below = row.map { $0.1.height - $0.2 }.max() ?? 0
            let height = above + below
            var x: CGFloat = 0
            for (index, size, axis) in row {
                points[index] = Placement(point: CGPoint(x: x, y: y + above-axis), size: size)
                x += size.width + spacing
            }
            used = max(used, max(0, x-spacing)); y += height + spacing
        }
        return (CGSize(width: used, height: max(0, y-spacing)), points)
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? .greatestFiniteMagnitude).0
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (view, placement) in zip(subviews, arrange(subviews, width: bounds.width).1) {
            view.place(at: CGPoint(x: bounds.minX+placement.point.x, y: bounds.minY+placement.point.y), proposal: ProposedViewSize(placement.size))
        }
    }
}

private struct DefinitionUnderBracket: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 0, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.maxX, y: 0))
        return p
    }
}

private enum DefinitionMathAxis: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat { context.height/2 }
}
private extension VerticalAlignment {
    static let definitionMathAxis = VerticalAlignment(DefinitionMathAxis.self)
}
