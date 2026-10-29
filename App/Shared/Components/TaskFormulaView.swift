import SwiftUI

struct TaskFormulaView: View {
    let formula: String
    let definitions: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MathLine(formula).foregroundStyle(AppStyle.accent)
            Text(definitions).font(.footnote).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(AppStyle.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
}
