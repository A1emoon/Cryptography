import SwiftUI

@MainActor
final class CipollaModel: ObservableObject {
    @Published var a = "29" { didSet { if a != oldValue { invalidate() } } }
    @Published var p = "109" { didSet { if p != oldValue { invalidate() } } }
    @Published var delta = "" { didSet { if delta != oldValue { invalidate() } } }
    @Published private(set) var solution: CipollaSolution?
    @Published private(set) var error: String?
    @Published private(set) var isCalculating = false
    @Published private(set) var calculationID = UUID()
    private var worker: Task<CipollaSolution, Error>?
    func invalidate() {
        worker?.cancel(); worker = nil
        calculationID = UUID(); solution = nil; error = nil; isCalculating = false
    }
    func cancel() { worker?.cancel(); worker = nil; calculationID = UUID(); isCalculating = false }
    func example(_ a: String, _ p: String) { self.a = a; self.p = p; delta = ""; solve() }
    func solve() {
        invalidate()
        let id = calculationID, inputs = (a, p, delta)
        isCalculating = true
        let task = Task.detached(priority: .userInitiated) {
            try CipollaSolver.solve(a: inputs.0, p: inputs.1, delta: inputs.2, check: { try Task.checkCancellation() })
        }
        worker = task
        Task { [weak self] in
            do {
                let result = try await task.value
                guard let self, self.calculationID == id else { return }
                self.solution = result; self.isCalculating = false; self.worker = nil
            } catch {
                guard let self, self.calculationID == id else { return }
                if !(error is CancellationError) { self.error = error.localizedDescription }
                self.isCalculating = false; self.worker = nil
            }
        }
    }
}
