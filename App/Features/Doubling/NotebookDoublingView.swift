import SwiftUI

struct NotebookDoublingView: View {
    let solution: DoublingSolution
    var body: some View {
        NotebookPaper {
            MathLine(solution.expression)
            NotebookDoublingWork(solution: solution)
            NotebookAnswer(text: solution.answer.description)
        }
    }
}
struct NotebookDoublingWork: View {
    let solution: DoublingSolution
    var body: some View {
        NotebookBinaryConversion(conversion: solution.conversionA)
        NotebookBinaryConversion(conversion: solution.conversionB)
        if let preparation = solution.preparation {
            MathLine("\(solution.originalAddend) ≡ \(preparation.answer) (mod \(solution.modulus))")
        }
        if let table = solution.table { NotebookIntegerTable(table: table) }
        if let correction = solution.signCorrection { MathLine(correction.expression) }
    }
}

