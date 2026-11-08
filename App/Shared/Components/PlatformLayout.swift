import SwiftUI

extension View {
    /// Keep each handwritten mathematical line intact on the small screen.
    @ViewBuilder func courseMathRow() -> some View {
        #if os(watchOS)
        ScrollView(.horizontal) {
            self.fixedSize(horizontal: true, vertical: false).padding(.vertical, 3)
        }.scrollIndicators(.visible).frame(maxWidth: .infinity, alignment: .leading)
        #else
        self
        #endif
    }

    @ViewBuilder func courseTextSelection() -> some View {
        #if os(watchOS)
        self
        #else
        self.textSelection(.enabled)
        #endif
    }
    @ViewBuilder func coursePaperNavigation() -> some View {
        #if os(watchOS)
        self.modifier(WatchFullPageMarker()).toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        #else
        self.toolbar(.hidden, for: .tabBar)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        #endif
    }
    @ViewBuilder func courseSolutionAppearance() -> some View {
        #if os(watchOS)
        self.modifier(WatchFullPageMarker()).background(Color.white).foregroundStyle(Color.black).environment(\.colorScheme, .light)
        #else
        self.background(AppStyle.paper)
        #endif
    }
    @ViewBuilder func courseCatalogStyle() -> some View {
        #if os(watchOS)
        self.listStyle(.plain)
        #else
        self.listStyle(.insetGrouped)
        #endif
    }
    @ViewBuilder func courseReferenceSearch(_ query: Binding<String>, prompt: String) -> some View {
        #if os(watchOS)
        self.searchable(text: query, prompt: prompt)
        #else
        self.searchable(text: query, placement: .navigationBarDrawer(displayMode: .always), prompt: prompt)
        #endif
    }
}
