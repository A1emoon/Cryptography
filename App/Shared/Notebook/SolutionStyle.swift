import SwiftUI

enum SolutionStyle: String, CaseIterable {
    case detailed, notebook
    var title: String { self == .detailed ? "Подробно" : "Как в конспекте" }
}
#if !os(watchOS)
struct SolutionStylePicker: View {
    @Binding var selection: SolutionStyle
    var body: some View {
        Picker("Оформление решения", selection: $selection) {
            ForEach(SolutionStyle.allCases, id: \.self) { style in
                Text(style.title).tag(style)
            }
        }.pickerStyle(.segmented).accessibilityIdentifier("solutionStyle")
            .padding(.horizontal, 22).padding(.bottom, 18)
    }
}

#endif

/// Mathematical fragments wrap as units; a single long fragment can be scrolled.
struct NotebookFlow: Layout {
    var spacing: CGFloat = 12
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? 360).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrange(subviews, width: bounds.width)
        for (view, point) in zip(subviews, layout.points) {
            view.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }
    private func arrange(_ views: Subviews, width: CGFloat) -> (size: CGSize, points: [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, usedWidth: CGFloat = 0
        var points: [CGPoint] = []
        for view in views {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            points.append(CGPoint(x: x, y: y))
            usedWidth = max(usedWidth, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: usedWidth, height: y + rowHeight), points)
    }
}
struct NotebookPaper<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 20, content: content)
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(AppStyle.paper, in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("notebookSolution")
    }
}
struct NotebookAnswer: View {
    let text: String
    var body: some View {
        MathText(text: "Ответ: " + text)
            .fixedSize(horizontal: false, vertical: true).courseTextSelection()
            .padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("notebookAnswer").accessibilityLabel(text)
    }
}
