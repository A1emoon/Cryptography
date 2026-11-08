import SwiftUI

/// Native iPhone disclosure and an equivalent expandable section on watchOS.
struct CourseDisclosureGroup<Content: View, Label: View>: View {
    private let external: Binding<Bool>?
    @State private var local = false
    @ViewBuilder private let content: () -> Content
    @ViewBuilder private let label: () -> Label
    init(isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content, @ViewBuilder label: @escaping () -> Label) {
        external = isExpanded; self.content = content; self.label = label
    }
    init(_ title: String, @ViewBuilder content: @escaping () -> Content) where Label == Text {
        external = nil; self.content = content; self.label = { Text(title) }
    }
    private var expanded: Binding<Bool> { external ?? $local }
    var body: some View {
        #if os(watchOS)
        Section {
            Button { expanded.wrappedValue.toggle() } label: {
                HStack { label(); Spacer(minLength: 3); Image(systemName: expanded.wrappedValue ? "chevron.up" : "chevron.down").font(.caption2) }
            }.buttonStyle(.plain)
            if expanded.wrappedValue { content() }
        }
        #else
        DisclosureGroup(isExpanded: expanded, content: content, label: label)
        #endif
    }
}
