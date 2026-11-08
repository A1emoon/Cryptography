import SwiftUI
@main struct NumberTheoryApp:App {
 var body:some Scene {WindowGroup {
  TabView {
   HomeView().tabItem{Label("Задачи",systemImage:"square.grid.2x2")}
   ReferenceLibraryView(kind:.definition).tabItem{Label("Определения",systemImage:"text.book.closed")}
   ReferenceLibraryView(kind:.theorem).tabItem{Label("Теоремы",systemImage:"graduationcap")}
  }.tint(AppStyle.accent)
 }}
}
