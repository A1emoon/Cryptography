import Foundation

enum ReferenceKind: String, Codable, CaseIterable, Sendable { case definition, theorem }
enum ReferenceTier: String, Codable, CaseIterable, Sendable {
    case required, additional, support
    var rank: Int { switch self { case .required: 0; case .additional: 1; case .support: 2 } }
}
struct ReferenceAtom: Codable, Sendable {
    let kind: String
    let a: String
    let b: String
    let c: String
}
struct ReferenceProofStep: Codable, Sendable {
    let text: String
    let formulas: [[ReferenceAtom]]
    let heading: String?
    let explanation: String?
}
struct ReferenceLocation: Codable, Sendable, Identifiable {
    let file: String
    let page: Int
    var id: String { "\(file)_\(page)" }
}
struct ReferenceSource: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let path: String
    let pages: Int
    let role: String
    let notice: String?
}
struct ReferenceWrittenProof: Codable, Sendable {
    let given: [[ReferenceAtom]]
    let claim: [[ReferenceAtom]]
    let lines: [[ReferenceAtom]]
}
/// A literal passage, kept separately from the explanatory article.
struct ReferenceDefinitionRow: Codable, Sendable {
    let value: [ReferenceAtom]
    let condition: [ReferenceAtom]
}
struct ReferenceDefinitionBlock: Codable, Sendable {
    let kind: String
    let text: String
    let atoms: [ReferenceAtom]
    let prefix: [ReferenceAtom]
    let rows: [ReferenceDefinitionRow]
    let bracket: String
}
struct ReferenceDefinition: Codable, Sendable {
    let heading: String
    let blocks: [ReferenceDefinitionBlock]
    let sources: [ReferenceLocation]
}
/// nil pages is reserved for the explicitly opened full source catalogue.
/// An empty or invalid excerpt never falls back to the complete document.
struct ReferenceSourceSelection: Identifiable, Sendable {
    let file: String
    let pages: [Int]?
    var id: String { file + "_" + (pages?.map(String.init).joined(separator: "_") ?? "all") }
    func indices(pageCount: Int) -> [Int]? {
        guard pageCount > 0 else { return nil }
        guard let pages else { return Array(0..<pageCount) }
        guard !pages.isEmpty, pages.allSatisfy({ (1...pageCount).contains($0) }) else { return nil }
        return Array(Set(pages)).sorted().map { $0 - 1 }
    }
    static func excerpts(_ locations: [ReferenceLocation]) -> [Self] {
        var files: [String] = []
        for location in locations where !files.contains(location.file) { files.append(location.file) }
        return files.map { file in Self(file: file, pages: Array(Set(locations.filter { $0.file == file }.map(\.page))).sorted()) }
    }
}
struct ReferenceEntry: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let kind: ReferenceKind
    let section: String
    let body: String
    let formulas: [[ReferenceAtom]]
    let sources: [ReferenceLocation]
    let proof: [ReferenceProofStep]
    let proofOrigin: String?
    let correction: String?
    let aliases: [String]
    let related: [String]
    let tier: ReferenceTier
    let courseOrder: Int?
    let sourceMarker: String?
    let sourceStatement: String?
    let writtenProof: ReferenceWrittenProof?
    let verbatimDefinition: ReferenceDefinition?
    var isRequired: Bool { tier == .required }
    var badge: String {
        if tier == .required { return kind == .theorem ? "Основной список · №\(courseOrder ?? 0)" : "Определение из конспекта" }
        return tier == .additional ? "Утверждение из конспекта" : "Справочное пояснение"
    }
}
struct CourseLibrary: Codable, Sendable {
    let version: Int
    let entries: [ReferenceEntry]
    let sources: [ReferenceSource]
    var error: String? = nil
    enum CodingKeys: String, CodingKey { case version, entries, sources }
    static let shared: CourseLibrary = {
        do {
            #if SWIFT_PACKAGE
            let bundle = Bundle.module
            #else
            let bundle = Bundle.main
            #endif
            guard let url = bundle.url(forResource: "course-library", withExtension: "json") else {
                return CourseLibrary(version: 2, entries: [], sources: [], error: "Не найден файл справочника.")
            }
            return try JSONDecoder().decode(CourseLibrary.self, from: Data(contentsOf: url))
        } catch { return CourseLibrary(version: 2, entries: [], sources: [], error: "Не удалось прочитать справочник: \(error.localizedDescription)") }
    }()
    subscript(_ id: String) -> ReferenceEntry? { entries.first { $0.id == id } }
    func source(_ id: String) -> ReferenceSource? { sources.first { $0.id == id } }
    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
            .replacingOccurrences(of: "ё", with: "е").replacingOccurrences(of: "−", with: "-")
    }
    func courseEntries(_ kind: ReferenceKind) -> [ReferenceEntry] { search("", kind: kind).filter { $0.tier == .required } }
    func search(_ query: String, kind: ReferenceKind, section: String? = nil) -> [ReferenceEntry] {
        let words = Self.normalized(query).split(whereSeparator: \.isWhitespace).map(String.init)
        return entries.filter { entry in
            guard entry.kind == kind, section == nil || section == entry.section else { return false }
            let number = entry.courseOrder.map { "№\($0) Утв \($0) Теорема \($0)" } ?? ""
            let all = Self.normalized(([entry.title,entry.body,number] + entry.aliases + entry.proof.map(\.text) + (entry.verbatimDefinition?.blocks.map { $0.text + " " + ($0.atoms + $0.prefix + $0.rows.flatMap { $0.value + $0.condition }).map { $0.a + " " + $0.b + " " + $0.c }.joined(separator: " ") } ?? [])).joined(separator: " "))
            return words.allSatisfy { all.contains($0) }
        }.sorted {
            if $0.tier != $1.tier { return $0.tier.rank < $1.tier.rank }
            if let a = $0.courseOrder, let b = $1.courseOrder, a != b { return a < b }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
}
