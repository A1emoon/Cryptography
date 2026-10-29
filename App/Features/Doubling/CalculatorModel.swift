import SwiftUI

@MainActor
final class CalculatorModel: ObservableObject {
    @Published var a = "78"
    @Published var b = "96"
    @Published var modulus = "273"
    @Published private(set) var solution: DoublingSolution?
    @Published private(set) var error: String?
    @Published private(set) var isCalculating = false
    @Published private(set) var calculationID = UUID()
    private var worker: Task<DoublingSolution, Error>?

    func invalidate() {
        worker?.cancel()
        worker = nil
        calculationID = UUID()
        isCalculating = false
        solution = nil
        error = nil
    }

    func solve() {
        invalidate()
        let id = calculationID
        let inputs = (a, b, modulus)
        isCalculating = true
        let task = Task.detached(priority: .userInitiated) {
            try DoublingSolver.solve(a: inputs.0, b: inputs.1, modulus: inputs.2,
                                     checkCancellation: { try Task.checkCancellation() })
        }
        worker = task
        Task { [weak self] in
            do {
                let result = try await task.value
                guard let self, self.calculationID == id else { return }
                self.solution = result
                self.isCalculating = false
                self.worker = nil
            } catch is CancellationError {
                guard let self, self.calculationID == id else { return }
                self.isCalculating = false
                self.worker = nil
            } catch {
                guard let self, self.calculationID == id else { return }
                self.error = error.localizedDescription
                self.isCalculating = false
                self.worker = nil
            }
        }
    }
}
