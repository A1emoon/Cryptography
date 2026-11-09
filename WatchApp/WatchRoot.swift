import SwiftUI

@main struct NumberTheoryWatchApp: App {
    var body: some Scene { WindowGroup { WatchRootView().tint(AppStyle.accent) } }
}
@MainActor final class WatchNavigationState: ObservableObject {
    static let shared = WatchNavigationState()
    @Published var pages: Set<UUID> = []
}
struct WatchFullPageMarker: ViewModifier {
    @State private var id = UUID()
    func body(content: Content) -> some View {
        content.onAppear { WatchNavigationState.shared.pages.insert(id) }
            .onDisappear { WatchNavigationState.shared.pages.remove(id) }
    }
}
struct WatchRootView: View {
    @AppStorage("watchDarkTheme") private var darkTheme = false
    @State private var selected = 0
    #if DEBUG
    @State private var debugSource: ReferenceSourceSelection?
    #endif
    @ObservedObject private var navigation = WatchNavigationState.shared
    var body: some View {
        NavigationStack {
            Group {
                switch selected {
                case 1: ReferenceLibraryView(kind: .definition)
                case 2: ReferenceLibraryView(kind: .theorem)
                default: WatchHomeView()
                }
            }.toolbar {
                if navigation.pages.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { darkTheme.toggle() } label: {
                            Image(systemName: darkTheme ? "sun.max.fill" : "moon.fill").foregroundStyle(.white)
                        }.accessibilityIdentifier("watchTheme")
                            .accessibilityLabel(darkTheme ? "Включить светлую тему" : "Включить тёмную тему")
                            .accessibilityValue(darkTheme ? "Тёмная" : "Светлая")
                    }
                    ToolbarItem(placement: .bottomBar) { tab(0, "Задачи", "square.grid.2x2", "tasks") }
                    ToolbarItem(placement: .bottomBar) { tab(1, "Опр.", "text.book.closed", "definitions") }
                    ToolbarItem(placement: .bottomBar) { tab(2, "Теоремы", "graduationcap", "theorems") }
                }
            }
        }.id(darkTheme).preferredColorScheme(darkTheme ? .dark : .light)
            .environment(\.colorScheme, darkTheme ? .dark : .light).onAppear {
            #if DEBUG
            if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "--watch-section"), ProcessInfo.processInfo.arguments.count > i+1 {
                selected = Int(ProcessInfo.processInfo.arguments[i+1]) ?? 0
            }
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "--watch-theme"), args.count > i+1 { darkTheme = args[i+1] == "dark" }
            if let i = args.firstIndex(of: "--watch-source"), args.count > i+1, CourseLibrary.shared.source(args[i+1]) != nil {
                var pages: [Int]? = nil
                if let j = args.firstIndex(of: "--watch-pages"), args.count > j+1 { pages = args[j+1].split(separator: ",").compactMap { Int($0) } }
                debugSource = ReferenceSourceSelection(file: args[i+1], pages: pages)
            }
            #endif
        }
        #if DEBUG
        .sheet(item: $debugSource) { ReferenceSourceView(selection: $0) }
        #endif
    }
    private func tab(_ value: Int, _ title: String, _ icon: String, _ id: String) -> some View {
        Button { selected = value } label: {
            VStack(spacing: 2) { Image(systemName: icon).font(.system(size: 13)); Text(title).font(.system(size: 9)) }
                .frame(maxWidth: .infinity).frame(height: 35).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(selected == value ? AppStyle.accent : .gray)
            .accessibilityLabel(value == 1 ? "Определения" : title).accessibilityIdentifier("watchTab_"+id)
    }
}
private enum WatchTask: Identifiable {
    case course(CourseTask), cipolla, rabin
    static let all: [Self] = CourseTask.allCases.map(Self.course) + [.cipolla, .rabin]
    var id: String {
        switch self {
        case .course(let task): task == .modularDivision ? "modular_division" : task.id
        case .cipolla: "cipolla"
        case .rabin: "rabin"
        }
    }
    var title: String { switch self { case .course(let task): task.title; case .cipolla: "Чиполла"; case .rabin: "Берлекэмп–Рабин" } }
    var symbol: String { switch self { case .course(let task): task.symbol; case .cipolla: "x.squareroot"; case .rabin: "function" } }
    var formula: String {
        switch self {
        case .course(.inverse): "a⁻¹ mod m"
        case .course(.order): "Pₘ(a) = ?"
        case .course(.tonelli): "x² ≡ a; x³ ≡ a (mod p)"
        case .course(let task): task.formula
        case .cipolla: "x² ≡ a (mod p)"
        case .rabin: "f(x) ≡ 0 (mod q)"
        }
    }
}
private struct WatchHomeView: View {
    @State private var expanded = false
    var body: some View {
        ScrollViewReader { proxy in
        List {
            ForEach(Array(WatchTask.all.prefix(3))) { task in link(task) }
            Button { expanded.toggle() } label: {
                HStack {
                    Text("Другие задачи · 6").font(.callout)
                    Spacer(minLength: 3)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption2)
                }
            }.id("watchOtherTasks").accessibilityIdentifier("watchOtherTasks").accessibilityValue(expanded ? "Развернуто" : "Свернуто")
            ForEach(expanded ? Array(WatchTask.all.dropFirst(3)) : []) { task in link(task) }
        }.listStyle(.plain).navigationTitle("Задачи")
            .onChange(of: expanded) { _, _ in
                Task { @MainActor in
                    await Task.yield()
                    withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo("watchOtherTasks", anchor: .top) }
                }
            }
        }
    }
    private func link(_ task: WatchTask) -> some View {
        NavigationLink {
            switch task {
            case .course(let kind): CourseTaskView(kind: kind)
            case .cipolla: CipollaView()
            case .rabin: RabinView()
            }
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                Label(task.title, systemImage: task.symbol).font(.system(size: 14, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                DefinitionMathText(text: task.formula, size: 13).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(.vertical, 5)
        }.accessibilityIdentifier("task_"+task.id)
    }
}
