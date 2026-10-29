import Foundation

enum PowerNotation {
    static func two(_ exponent: Int) -> String {
        let digits = Array("⁰¹²³⁴⁵⁶⁷⁸⁹")
        return "2" + String(exponent).compactMap { $0.wholeNumberValue.map { digits[$0] } }.map(String.init).joined()
    }
}

