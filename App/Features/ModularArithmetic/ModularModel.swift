import SwiftUI

@MainActor
final class ModularModel: ObservableObject {
    let isDivision: Bool
    @Published var a: String { didSet { if a != oldValue { invalidate() } } }
    @Published var numerator: String { didSet { if numerator != oldValue { invalidate() } } }
    @Published var modulus: String { didSet { if modulus != oldValue { invalidate() } } }
    @Published var method: ModularMethod = .automatic { didSet { if method != oldValue { invalidate() } } }
    @Published private(set) var solution: ModularSolution?
    @Published private(set) var error: String?
    @Published private(set) var isCalculating = false
    @Published private(set) var calculationID = UUID()
    private var worker: Task<ModularSolution, Error>?

    init(isDivision: Bool) {
        self.isDivision = isDivision
        a = isDivision ? "179" : "113"
        numerator = "153"
        modulus = isDivision ? "283" : "512"
    }
    func invalidate() {
        worker?.cancel(); worker = nil
        calculationID = UUID()
        isCalculating = false; solution = nil; error = nil
    }
    func example(a: String, m: String, n: String = "1") {
        self.a = a; modulus = m; numerator = n; method = .automatic
        solve()
    }
    func solve() {
        invalidate()
        let id = calculationID
        let values = (a, modulus, isDivision ? numerator : nil, method)
        isCalculating = true
        let task = Task.detached(priority: .userInitiated) {
            try ModularSolver.solve(a: values.0, modulus: values.1, numerator: values.2, method: values.3,
                                    check: { try Task.checkCancellation() })
        }
        worker = task
        Task { [weak self] in
            do {
                let result = try await task.value
                guard let self, self.calculationID == id else { return }
                self.solution = result; self.isCalculating = false; self.worker = nil
            } catch is CancellationError {
                guard let self, self.calculationID == id else { return }
                self.isCalculating = false; self.worker = nil
            } catch {
                guard let self, self.calculationID == id else { return }
                self.error = error.localizedDescription; self.isCalculating = false; self.worker = nil
            }
        }
    }
}
