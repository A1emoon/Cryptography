import SwiftUI

enum StudentMathAtom {
    case text(String)
    case rich(String)
    case floorFraction(String,String)
    case fraction(String, String)
    case symbol(String, String)
    case power(String, String)
    case fractionPower(String, String, String)
    var spoken: String {
        switch self {
        case .text(let text): text
        case .rich(let text): text
        case .floorFraction(let a,let b): "Целая часть \(a), делённое на \(b)"
        case .symbol(let a, let b): "Символ \(a) по \(b)"
        case .fraction(let a, let b): "\(a), делённое на \(b)"
        case .power(let base, let exponent): "\(base) в степени \(exponent)"
        case .fractionPower(let base, let a, let b): "\(base) в степени \(a), делённое на \(b)"
        }
    }
}
struct StudentFraction: View {
    let numerator: String
    let denominator: String
    var small = false
    var body: some View {
        VStack(spacing: 3) {
            Text(numerator)
            Rectangle().frame(height: 0.8)
            Text(denominator)
        }.font(.system(small ? .caption : .title3, design: .serif))
            .monospacedDigit().fixedSize().padding(.horizontal, 2).padding(.vertical, 3)
    }
}
private struct StudentMathToken: View {
    let atom: StudentMathAtom
    let isLink: Bool
    var unwrapped = false
    let action: () -> Void
    @ViewBuilder private var mathematicalText: some View {
        switch atom {
        case .text(let text): MathText(text: text)
        case .rich(let text): ReferenceMathText(text:text)
        case .floorFraction(let a,let b): FloorFractionView(numerator:a,denominator:b)
        case .symbol(let a, let b):
            StudentFraction(numerator: a, denominator: b).padding(.horizontal, 10)
                .overlay(alignment: .leading) { MatrixBracket(right: false).stroke(lineWidth: 1.2).frame(width: 7) }
                .overlay(alignment: .trailing) { MatrixBracket(right: true).stroke(lineWidth: 1.2).frame(width: 7) }
        case .fraction(let a, let b): StudentFraction(numerator: a, denominator: b)
        case .power(let base, let exponent):
            HStack(alignment: .top, spacing: 1) {
                MathText(text: base).padding(.top, 9)
                Text(exponent).font(.system(.caption, design: .serif)).padding(.bottom, 12)
            }
        case .fractionPower(let base, let a, let b):
            HStack(alignment: .top, spacing: 1) {
                MathText(text: base).padding(.top, 16)
                StudentFraction(numerator: a, denominator: b, small: true).padding(.bottom, 16)
            }
        }
    }
    @ViewBuilder private var label: some View {
        HStack(spacing: 3) {
            mathematicalText
            if isLink {
                Image(systemName: "arrow.up.right.square").font(.system(size: 10)).foregroundStyle(AppStyle.accent)
            }
        }.fixedSize().padding(.vertical, 6)
    }
    var body: some View {
        if unwrapped { token.fixedSize() }
        else {
        #if os(watchOS)
        token.fixedSize()
        #else
        ViewThatFits(in: .horizontal) {
            token.fixedSize()
            ScrollView(.horizontal) { token.fixedSize() }.frame(height: overflowHeight)
        }
        #endif
        }
    }
    private var overflowHeight: CGFloat {
        #if os(watchOS)
        switch atom {
        case .text: 44
        case .rich, .power: 56
        default: 80
        }
        #else
        88
        #endif
    }
    @ViewBuilder private var token: some View {
        if isLink {
            Button(action: action) { label }.buttonStyle(.plain)
                .accessibilityLabel("Вычисление: " + atom.spoken)
        } else { label.accessibilityLabel(atom.spoken) }
    }
}
/// Wraps equalities as mathematical fragments; oversized fragments scroll within the page.
private struct StudentMathFlow: Layout {
    private func arrange(_ views: Subviews, width: CGFloat) -> (CGSize, [(CGPoint, CGSize)]) {
        let width = max(1, width)
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, used: CGFloat = 0
        var positions: [(CGPoint, CGSize)] = []
        var rowStart = 0
        func alignRow() {
            for i in rowStart..<positions.count { positions[i].0.y += (row - positions[i].1.height) / 2 }
            rowStart = positions.count
        }
        for view in views {
            let natural = view.sizeThatFits(.unspecified)
            let w = min(width, natural.width)
            let size = view.sizeThatFits(ProposedViewSize(width: w, height: nil))
            if x > 0 && x + w > width { alignRow(); x = 0; y += row + 4; row = 0 }
            positions.append((CGPoint(x: x, y: y), CGSize(width: w, height: size.height)))
            used = max(used, x + w); x += w + 6; row = max(row, size.height)
        }
        alignRow()
        return (CGSize(width: used, height: y + row), positions)
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? 340).0
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let positions = arrange(subviews, width: bounds.width).1
        for (view, item) in zip(subviews, positions) {
            view.place(at: CGPoint(x: bounds.minX + item.0.x, y: bounds.minY + item.0.y),
                proposal: ProposedViewSize(width: item.1.width, height: item.1.height))
        }
    }
}
struct StudentFormulaView: View {
    let atoms: [StudentMathAtom]
    var body: some View {
        #if os(watchOS)
        HStack(spacing: 6) {
            ForEach(atoms.indices, id: \.self) { index in
                StudentMathToken(atom: atoms[index], isLink: false, action: {})
            }
        }.courseMathRow()
        #else
        StudentMathFlow {
            ForEach(atoms.indices, id: \.self) { index in
                StudentMathToken(atom: atoms[index], isLink: false, action: {})
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
        #endif
    }
}
struct StudentMathLine: View {
    let atoms: [StudentMathAtom]
    var workIndices: Set<Int> = []
    let identifier: String
    let onWork: (Int) -> Void
    let onReason: () -> Void
    var singleRow = false
    private var groups: [[Int]] {
        var result: [[Int]] = [], i = 0
        while i < atoms.count {
            if case .text(let text) = atoms[i], ["=", "≡", "⇒", "⇔"].contains(text), i + 1 < atoms.count {
                result.append([i, i + 1]); i += 2
            } else { result.append([i]); i += 1 }
        }
        return result
    }
    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            if singleRow {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(atoms.indices, id: \.self) { index in
                            StudentMathToken(atom: atoms[index], isLink: workIndices.contains(index), unwrapped: true, action: { onWork(index) })
                                .accessibilityIdentifier(workIndices.contains(index) ? "\(identifier)_work_\(index)" : "\(identifier)_part_\(index)")
                        }
                    }.fixedSize().padding(.vertical, 3)
                }.scrollIndicators(.visible).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(identifier + "_scroll")
            } else {
            #if os(watchOS)
            HStack(spacing: 6) {
                ForEach(atoms.indices, id: \.self) { index in
                    StudentMathToken(atom: atoms[index], isLink: workIndices.contains(index), action: { onWork(index) })
                        .accessibilityIdentifier(workIndices.contains(index) ? "\(identifier)_work_\(index)" : "\(identifier)_part_\(index)")
                }
            }.courseMathRow().accessibilityIdentifier(identifier + "_scroll")
            #else
            StudentMathFlow {
                ForEach(groups.indices, id: \.self) { group in
                    HStack(spacing: 6) {
                        ForEach(groups[group], id: \.self) { index in
                            StudentMathToken(atom: atoms[index], isLink: workIndices.contains(index), action: { onWork(index) })
                                .accessibilityIdentifier(workIndices.contains(index) ? "\(identifier)_work_\(index)" : "\(identifier)_part_\(index)")
                        }
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            #endif
            }
            Button(action: onReason) {
                Image(systemName: "questionmark.circle").font(.system(size: 15))
                    .foregroundStyle(AppStyle.accent.opacity(0.8)).frame(width: 32, height: 38)
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Пояснить эту строку")
                .accessibilityIdentifier(identifier + "_reason")
        }.accessibilityElement(children: .contain).accessibilityIdentifier(identifier)
    }
}
struct StudentDetailSheet<Content: View>: View {
    let title: String
    var large = false
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(title).font(AppStyle.isWatch ? .headline : .title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                    content()
                }.frame(maxWidth: .infinity, alignment: .leading).padding(AppStyle.contentPadding)
            }.background(AppStyle.isWatch ? Color.white : AppStyle.background)
                .navigationTitle(AppStyle.isWatch ? "" : "К записи решения").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }.accessibilityIdentifier("closeStudentDetail").courseToolbarControl()
                } }
        }
        #if os(watchOS)
        .background(Color.white).foregroundStyle(Color.black).environment(\.colorScheme, .light)
        #endif
        .accessibilityIdentifier("studentDetailSheet")
        .presentationDetents(large ? [.large] : [.medium, .large]).presentationDragIndicator(.visible)
    }
}
