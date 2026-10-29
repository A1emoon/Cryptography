import SwiftUI

@MainActor
final class RabinModel: ObservableObject {
    @Published private(set) var coefficients = "1, 3, 2, 1"
    @Published private(set) var q = "7"
    @Published private(set) var solution: RabinSolution?
    @Published private(set) var error: String?
    @Published private(set) var isCalculating = false
    @Published private(set) var calculationID = UUID()
    private var worker: Task<RabinSolution, Error>?
    func cancel() {
        worker?.cancel(); worker = nil; calculationID = UUID(); isCalculating = false
    }
    func solve(coefficients: String? = nil, q: String? = nil) {
        cancel()
        if let coefficients { self.coefficients = coefficients }
        if let q { self.q = q }
        solution = nil; error = nil; isCalculating = true
        let id = calculationID, f = self.coefficients, p = self.q
        let task = Task.detached(priority: .userInitiated) {
            try BerlekampRabinSolver.solve(coefficients: f, q: p, check: { try Task.checkCancellation() })
        }
        worker = task
        Task { [weak self] in
            do {
                let value = try await task.value
                guard let self, self.calculationID == id else { return }
                self.solution = value; self.worker = nil; self.isCalculating = false
            } catch {
                guard let self, self.calculationID == id else { return }
                if !(error is CancellationError) { self.error = error.localizedDescription }
                self.worker = nil; self.isCalculating = false
            }
        }
    }
}
