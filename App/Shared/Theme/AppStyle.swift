import SwiftUI

enum AppStyle {
    #if os(watchOS)
    static let isWatch = true
    static let background = Color.black
    static let paper = Color.white
    static let soft = Color(white: 0.94)
    static let catalogText = Color.black
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
    static let accent = Color.accentColor
    static let line = Color.primary.opacity(0.12)
}
