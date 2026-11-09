import SwiftUI

enum AppStyle {
    #if os(watchOS)
    static let isWatch = true
    static let background = Color.black
    static var paper: Color { watchDark ? .black : .white }
    static var soft: Color { Color(white: watchDark ? 0.12 : 0.94) }
    static var catalogText: Color { paperInk }
    static let contentPadding: CGFloat = 8
    static let pagePadding: CGFloat = 10
    static let paperTop: CGFloat = 12
    static let referenceFontSize: CGFloat = 16
    static let math = Font.system(size: 17, design: .serif)
    #else
    static let isWatch = false
    static let background = Color(uiColor: .systemGroupedBackground)
    static let paper = Color(uiColor: .secondarySystemGroupedBackground)
    static let soft = Color(uiColor: .tertiarySystemGroupedBackground)
    static let catalogText = Color.primary
    static let contentPadding: CGFloat = 22
    static let pagePadding: CGFloat = 24
    static let paperTop: CGFloat = 28
    static let referenceFontSize: CGFloat = 20
    static let math = Font.system(.title3, design: .serif)
    #endif
    #if os(watchOS)
    static var watchDark: Bool { UserDefaults.standard.bool(forKey: "watchDarkTheme") }
    static var watchScheme: ColorScheme { watchDark ? .dark : .light }
    static var referencePaper: Color { paper }
    static var paperInk: Color { watchDark ? Color(white: 0.95) : .black }
    #else
    static let referencePaper = Color.white
    static let paperInk = Color.black
    #endif
    static let accent = Color.accentColor
    static let line = Color.primary.opacity(0.12)
}
