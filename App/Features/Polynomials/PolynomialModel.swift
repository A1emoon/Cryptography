import SwiftUI

@MainActor
final class PolynomialModel: ObservableObject {
    @Published var a = "1, 2, 1" { didSet { if a != oldValue { invalidate() } } }
    @Published var b = "2, 0, 1, 3" { didSet { if b != oldValue { invalidate() } } }
    @Published var m = "1, 0, 0, 2, 2" { didSet { if m != oldValue { invalidate() } } }
    @Published var p = "5" { didSet { if p != oldValue { invalidate() } } }
    @Published private(set) var solution: PolynomialSolution?
    @Published private(set) var error: String?
    @Published private(set) var isCalculating = false
    @Published private(set) var calculationID = UUID()
    private var worker: Task<PolynomialSolution, Error>?

    func invalidate() {
        worker?.cancel()
        worker = nil
        calculationID = UUID()
        solution = nil
        error = nil
        isCalculating = false
    }
    func solve() {
        invalidate()
        let id = calculationID, inputs = (a, b, m, p)
        isCalculating = true
        let task = Task.detached(priority: .userInitiated) {
            try PolynomialSolver.solve(a: inputs.0, b: inputs.1, m: inputs.2, p: inputs.3,
                                       check: { try Task.checkCancellation() })
        }
        worker = task
        Task { [weak self] in
            do {
                let result = try await task.value
                guard let self, self.calculationID == id else { return }
                self.solution = result
                self.isCalculating = false
                self.worker = nil
            } catch {
                guard let self, self.calculationID == id else { return }
                if !(error is CancellationError) { self.error = error.localizedDescription }
                self.isCalculating = false
                self.worker = nil
            }
        }
    }
}
