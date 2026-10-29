import SwiftUI

@MainActor
final class DivisionModel: ObservableObject {
    @Published var a = "1530" { didSet { if a != oldValue { invalidate() } } }
    @Published var b = "41" { didSet { if b != oldValue { invalidate() } } }
    @Published private(set) var solution: BinaryDivisionSolution?
    @Published private(set) var error: String?
    @Published private(set) var isCalculating = false
    @Published private(set) var calculationID = UUID()
    private var worker: Task<BinaryDivisionSolution, Error>?

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
        let inputs = (a, b)
        isCalculating = true
        let task = Task.detached(priority: .userInitiated) {
            try BinaryDivisionSolver.solve(a: inputs.0, b: inputs.1,
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
