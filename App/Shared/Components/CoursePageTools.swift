import SwiftUI

/// Shared page actions use a compact menu on watchOS and direct toolbar controls on iOS.
struct CoursePageTools: ToolbarContent {
    let firstTitle: String
    let firstIcon: String
    let firstID: String
    let firstAction: () -> Void
    let secondTitle: String
    let secondIcon: String
    let secondID: String
    let secondAction: () -> Void
    var body: some ToolbarContent {
        #if os(watchOS)
        ToolbarItem(placement: .topBarTrailing) { WatchPageActions(tools: self) }
        #else
        ToolbarItemGroup(placement: .topBarTrailing) { firstButton; secondButton }
        #endif
    }
    private var firstButton: some View {
        Button(action: firstAction) { Label(firstTitle, systemImage: firstIcon).labelStyle(.iconOnly) }
            .accessibilityLabel(firstTitle).accessibilityIdentifier(firstID).courseToolbarControl()
    }
    private var secondButton: some View {
        Button(action: secondAction) { Label(secondTitle, systemImage: secondIcon) }
            .accessibilityLabel(secondTitle).accessibilityIdentifier(secondID).courseToolbarControl()
    }
}
extension View {
    @ViewBuilder func courseToolbarControl() -> some View {
        #if os(watchOS)
        self.buttonStyle(.borderedProminent).tint(AppStyle.accent).foregroundStyle(.white)
        #else
        self
        #endif
    }
}

#if os(watchOS)
/// A single compact toolbar control keeps the mathematical sheet free of a large bottom button.
private struct WatchPageActions: View {
    let tools: CoursePageTools
    @State private var presented = false
    var body: some View {
        Button { presented = true } label: { Image(systemName: "ellipsis") }
            .courseToolbarControl().accessibilityLabel("Действия").accessibilityIdentifier("watchPageActions")
            .confirmationDialog("Действия", isPresented: $presented, titleVisibility: .visible) {
                Button(tools.firstTitle, action: tools.firstAction).accessibilityIdentifier(tools.firstID)
                Button(tools.secondTitle, action: tools.secondAction).accessibilityIdentifier(tools.secondID)
                Button("Отмена", role: .cancel) { }
            }
    }
}
#endif
