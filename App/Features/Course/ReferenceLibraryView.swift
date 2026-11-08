import SwiftUI
#if !os(watchOS)
import PDFKit
#endif

extension ReferenceAtom {
    var student:StudentMathAtom {
        switch kind{
        case "power":.power(a,b)
        case "fraction":.fraction(a,b)
        case "fractionPower":.fractionPower(a,b,c)
        case "symbol":.symbol(a,b)
        default:.rich(a)
        }
    }
}
struct ReferenceLibraryView: View {
    let kind: ReferenceKind
    @State private var query = ""
    @State private var section: String?
    @State private var sources = false
    @State private var supportExpanded = false
    private let library = CourseLibrary.shared
    private var result: [ReferenceEntry] { library.search(query, kind: kind, section: section) }
    private var sections: [String] { Array(Set(library.entries.filter { $0.kind == kind && $0.tier != .support }.map(\.section))).sorted() }
    var body: some View {
        ReferenceLibraryNavigation {
            List {
                if let error = library.error { Text(error).foregroundStyle(.red) }
                #if !os(watchOS)
                Section {
                    Picker("Тема", selection: $section) {
                        Text("Все темы").tag(String?.none)
                        ForEach(sections, id: \.self) { Text($0).tag(Optional($0)) }
                    }.accessibilityIdentifier("referenceSection")
                }
                #endif
                if result.isEmpty { ContentUnavailableView.search(text: query) }
                let required = result.filter { $0.tier == .required }
                if !required.isEmpty {
                    Section(AppStyle.isWatch ? "" : (kind == .definition ? "Определения из конспектов" : "Основной список")) {
                        ForEach(required) { entry in ReferenceCatalogRow(entry: entry) }
                    }.accessibilityElement(children:.contain).accessibilityIdentifier("requiredReferences")
                }
                let additional = result.filter { $0.tier == .additional }
                if !additional.isEmpty {
                    Section("Другие утверждения из конспектов") {
                        ForEach(additional) { entry in ReferenceCatalogRow(entry: entry) }
                    }.accessibilityElement(children:.contain).accessibilityIdentifier("additionalReferences")
                }
                let support = result.filter { $0.tier == .support }
                if !support.isEmpty {
                    Section {
                        #if os(watchOS)
                        Button { supportExpanded.toggle() } label: {
                            Label("Справочные пояснения · \(support.count)", systemImage: "info.circle").font(.subheadline)
                        }
                        if supportExpanded || !query.isEmpty { ForEach(support) { entry in ReferenceCatalogRow(entry: entry) } }
                        #else
                        CourseDisclosureGroup(isExpanded: Binding(get: { supportExpanded || !query.isEmpty }, set: { supportExpanded = $0 })) {
                            ForEach(support) { entry in ReferenceCatalogRow(entry: entry) }
                        } label: {
                            Label("Справочные пояснения · \(support.count)", systemImage: "info.circle").font(.subheadline)
                        }.accessibilityElement(children:.contain)
                        #endif
                    }
                }
                #if os(watchOS)
                CourseDisclosureGroup("Фильтр по теме") {
                    Picker("Тема", selection: $section) {
                        Text("Все темы").tag(String?.none)
                        ForEach(sections, id: \.self) { Text($0).tag(Optional($0)) }
                    }.accessibilityIdentifier("referenceSection")
                }
                #endif
            }.courseCatalogStyle().background(AppStyle.background)
                .courseReferenceSearch($query, prompt: kind == .definition ? "Найти определение" : "Найти теорему")
                .navigationTitle(kind == .definition ? "Определения" : "Теоремы")
                .toolbar { ToolbarItem(placement: .topBarTrailing) {
                    Button { sources = true } label: { Image(systemName: "books.vertical") }
                        .accessibilityLabel("Все исходные конспекты").accessibilityIdentifier("referenceSources").courseToolbarControl()
                } }.sheet(isPresented: $sources) { ReferenceSourcesView() }
                .onAppear {
                    #if DEBUG && os(watchOS)
                    if let value = ProcessInfo.processInfo.environment["WATCH_REFERENCE_QUERY"] { query = value }
                    #endif
                }
        }
    }
}
private struct ReferenceCatalogRow: View {
    let entry: ReferenceEntry
    var body: some View {
        NavigationLink { ReferenceArticleView(entry: entry) } label: {
            Text(entry.title).font(.body.weight(.medium)).foregroundStyle(AppStyle.catalogText)
                .fixedSize(horizontal: false, vertical: true).padding(.vertical, 4)
        }.accessibilityLabel(entry.title).accessibilityIdentifier("reference_" + entry.id)
            .listRowBackground(AppStyle.paper.clipShape(RoundedRectangle(cornerRadius: AppStyle.isWatch ? 18 : 0)))
    }
}
struct ReferenceArticleView: View {
    let entry: ReferenceEntry
    var body: some View {
        if entry.kind == .theorem {
            ReferenceTheoremPage(entry: entry)
        } else {
            ReferenceDefinitionPage(entry: entry)
        }
    }
}
/// A theorem always opens on its copyable sheet. Sources and explanations live in separate sheets.
struct ReferenceTheoremPage: View {
    let entry: ReferenceEntry
    @State private var sources = false
    @State private var explanation = false
    var body: some View {
        ScrollView {
            ReferenceWrittenProofView(entry: entry)
                .padding(.horizontal, AppStyle.pagePadding).padding(.top, AppStyle.paperTop).padding(.bottom, 44)
        }.background(Color.white).foregroundStyle(Color.black)
            .environment(\.colorScheme, .light)
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .coursePaperNavigation()
            .toolbar { CoursePageTools(firstTitle: "Источники", firstIcon: "books.vertical", firstID: "theoremSources", firstAction: { sources = true }, secondTitle: "Разбор", secondIcon: "text.bubble", secondID: "theoremExplanation", secondAction: { explanation = true }) }
            .sheet(isPresented: $sources) { ReferenceArticleSources(entry: entry) }
            .sheet(isPresented: $explanation) {
                StudentDetailSheet(title: entry.title, large: true) {
                    Text("Формулировка").font(.headline)
                    ReferenceText(text: entry.body, excluding: entry.id)
                    ForEach(entry.formulas.indices, id: \.self) { ReferenceFormulaView(formula: entry.formulas[$0]) }
                    Text("Подробное доказательство").font(.headline).padding(.top, 8)
                    Text(entry.proofOrigin == "lecture" ? "По доказательству из конспекта; пропущенные переходы раскрыты." : "Доказательство дополнено по формулировке из конспекта.")
                        .font(.caption).foregroundStyle(.secondary)
                    ReferenceProofView(entry: entry)
                    if !entry.related.isEmpty {
                        Text("Связанные материалы").font(.headline)
                        ReferenceLinks(ids: entry.related, prefix: "relatedReference_")
                    }
                }
            }
    }
}
struct ReferenceWrittenProofView: View {
    let entry: ReferenceEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let proof = entry.writtenProof {
                section("Дано.", formulas: proof.given, id: "theoremGiven")
                section("Доказать.", formulas: proof.claim, id: "theoremClaim")
                VStack(alignment: .leading, spacing: 16) {
                    Text("Доказательство.").font(.system(.headline, design: .serif)).accessibilityIdentifier("referenceProof")
                    ForEach(proof.lines.indices, id: \.self) { i in
                        ReferencePaperFormulaView(formula: proof.lines[i])
                    }
                }.accessibilityElement(children: .contain).accessibilityIdentifier("referenceProofBody")
                Text("Ч. т. д.").font(.system(.title3, design: .serif))
                    .frame(maxWidth: .infinity, alignment: .trailing).accessibilityIdentifier("referenceQED")
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain).accessibilityIdentifier("theoremPaper")
    }
    private func section(_ title: String, formulas: [[ReferenceAtom]], id: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(.headline, design: .serif))
            ForEach(formulas.indices, id: \.self) { i in ReferencePaperFormulaView(formula: formulas[i]) }
        }.accessibilityElement(children: .contain).accessibilityIdentifier(id)
    }
}
struct ReferenceEntrySheet: View {
    let entry: ReferenceEntry
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ReferenceArticleView(entry: entry)
                .toolbar { ToolbarItem(placement: .topBarLeading) {
                    Button("Готово") { dismiss() }.accessibilityIdentifier("closeStudentDetail")
                } }
        }.presentationDetents([.large]).presentationDragIndicator(.visible)
            .environment(\.colorScheme, .light)
    }
}
struct ReferenceArticleContent: View {
    let entry: ReferenceEntry
    var showTitle = true
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(entry.badge.uppercased()).font(.caption.weight(.semibold)).tracking(0.7).foregroundStyle(AppStyle.accent)
            if showTitle {
                Text(entry.title).font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("referenceTitle")
            }
            Text(entry.section).font(.caption).foregroundStyle(.secondary)
            ReferenceText(text: entry.body, excluding: entry.id)
            ForEach(entry.formulas.indices, id: \.self) { ReferenceFormulaView(formula: entry.formulas[$0]) }
            if let correction = entry.correction {
                ReferenceCorrectionView(text: correction, entryID: entry.id)
            }
            if !entry.related.isEmpty {
                VStack(alignment: .leading, spacing: 12) { Text("Связанные материалы").font(.headline); ReferenceLinks(ids: entry.related, prefix: "relatedReference_") }
            }
            Divider()
            ReferenceSourceLinks(entry: entry)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
private struct ReferenceCorrectionView: View {
    let text: String
    let entryID: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Уточнение записи", systemImage: "checkmark.seal").font(.subheadline.weight(.semibold))
            ReferenceText(text: text, excluding: entryID)
        }.padding(16).background(AppStyle.accent.opacity(0.065), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityIdentifier("referenceCorrection")
    }
}
struct ReferenceArticleSources: View {
    let entry: ReferenceEntry
    var body: some View {
        StudentDetailSheet(title: "Источники", large: true) {
            Text(entry.title).font(AppStyle.isWatch ? .caption2 : .headline)
            #if os(watchOS)
            ReferenceSourceLinks(entry: entry)
            if let correction = entry.correction {
                CourseDisclosureGroup("Уточнение записи") { ReferenceCorrectionView(text: correction, entryID: entry.id) }
            }
            #else
            if let correction = entry.correction { ReferenceCorrectionView(text: correction, entryID: entry.id) }
            ReferenceSourceLinks(entry: entry)
            #endif
        }
    }
}
private struct ReferenceSourceLinks: View {
    let entry: ReferenceEntry
    @State private var selectedSource: ReferenceSourceSelection?
    private var excerpts: [ReferenceSourceSelection] {
        ReferenceSourceSelection.excerpts(entry.verbatimDefinition?.sources ?? entry.sources)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !AppStyle.isWatch { Text("Источники").font(.headline) }
            ForEach(excerpts) { excerpt in
                if let file = CourseLibrary.shared.source(excerpt.file) {
                    Button { selectedSource = excerpt } label: {
                        Label("\(file.title) · \(file.path.hasSuffix("pdf") ? "стр. " + (excerpt.pages ?? []).map(String.init).joined(separator: ", ") : "фото")", systemImage: file.path.hasSuffix("pdf") ? "doc.richtext" : "photo")
                            .font(.callout).multilineTextAlignment(.leading)
                    }.accessibilityIdentifier("source_" + excerpt.file + "_" + String(excerpt.pages?.first ?? 1))
                }
            }
        }.sheet(item: $selectedSource) { ReferenceSourceView(selection: $0) }
    }
}
struct ReferenceProofView: View {
    let entry: ReferenceEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(entry.proof.indices, id: \.self) { i in
                let block = entry.proof[i]
                VStack(alignment: .leading, spacing: 12) {
                    if let heading = block.heading { Text(heading).font(.system(.headline, design: .serif)) }
                    if !block.text.isEmpty { ReferenceText(text: block.text, excluding: entry.id) }
                    ForEach(block.formulas.indices, id: \.self) { j in
                        ReferenceFormulaView(formula: block.formulas[j], reason: StudyReason(title: "Обоснование перехода", text: block.explanation ?? block.text, references: entry.related), identifier: "proof_\(entry.id)_\(i)_\(j)")
                    }
                }
            }
            Text("Ч. т. д.").font(.system(.title3, design: .serif)).frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier("referenceQED")
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children:.contain).accessibilityIdentifier("referenceProofBody")
    }
}
struct ReferenceLinks:View{
    let ids:[String]
    var prefix="referenceLink_"
    @State private var entry:ReferenceEntry?
    var body:some View{
        VStack(alignment:.leading,spacing:12){
            ForEach(ids,id:\.self){id in
                if let item=CourseLibrary.shared[id]{
                    Button{entry=item}label:{Label(item.title,systemImage:item.kind == .theorem ? "text.book.closed" : "textformat.abc").font(.callout).multilineTextAlignment(.leading).fixedSize(horizontal:false,vertical:true)}.accessibilityIdentifier(prefix+id)
                }
            }
        }.sheet(item:$entry){item in ReferenceEntrySheet(entry:item)}
    }
}
struct ReferenceText:View{
    let text:String
    var excluding:String?=nil
    @State private var entry:ReferenceEntry?
    private var attributed:AttributedString{
        var result=AttributedString(text)
        var patterns:[(String,String)]=MathTerm.allCases.compactMap{term in
            let id = term == .gcd && !text.lowercased().contains("многочлен") && !text.contains("deg") ? "integer-gcd" : term.referenceID
            return id.map{($0,term.pattern)}
        }
        let known=Set(patterns.map(\.0))
        for entry in CourseLibrary.shared.entries where entry.kind == .definition && !known.contains(entry.id){
            for phrase in [entry.title]+entry.aliases where phrase.count>3{
                patterns.append((entry.id,NSRegularExpression.escapedPattern(for:phrase)))
            }
        }
        for (id,pattern) in patterns where id != excluding{
            guard CourseLibrary.shared[id] != nil,let regex=try? NSRegularExpression(pattern:"\\b(?:"+pattern+")\\b",options:[.caseInsensitive]) else{continue}
            for match in regex.matches(in:text,range:NSRange(text.startIndex...,in:text)){
                guard let range=Range(match.range,in:text),let low=AttributedString.Index(range.lowerBound,within:result),let high=AttributedString.Index(range.upperBound,within:result),result[low..<high].runs.allSatisfy({$0.link==nil}) else{continue}
                result[low..<high].link=URL(string:"course-reference://entry/"+id)
            }
        }
        return ReferenceMathTypesetting.format(result,text:text)
    }
    var body:some View{
        Text(attributed).font(.callout).tint(AppStyle.accent).fixedSize(horizontal:false,vertical:true)
            .environment(\.openURL,OpenURLAction{url in
                guard url.scheme=="course-reference",let item=CourseLibrary.shared[url.lastPathComponent] else{return .systemAction};entry=item;return .handled
            }).sheet(item:$entry){item in ReferenceEntrySheet(entry:item)}
    }
}
private struct ReferenceSourcesView:View{
    @Environment(\.dismiss) private var dismiss
    @State private var source:ReferenceSourceSelection?
    var body:some View{
        NavigationStack{
            List{
                Section{Text("Приоритет отдан PDF. Фотографии используются для дополнений и примеров. Исходные файлы включены в приложение и открываются без интернета.").font(.callout)}
                ForEach(["Основной источник","Пример и дополнение"],id:\.self){role in
                    Section(role){ForEach(CourseLibrary.shared.sources.filter{$0.role==role}){s in
                        Button{source=ReferenceSourceSelection(file:s.id,pages:nil)}label:{VStack(alignment:.leading,spacing:6){Label(s.title,systemImage:s.path.hasSuffix("pdf") ? "doc.richtext" : "photo");if let notice=s.notice{Text(notice).font(.caption).foregroundStyle(.secondary)}}}
                    }}
                }
            }.navigationTitle("Конспекты").toolbar{ToolbarItem(placement:.confirmationAction){Button("Готово"){dismiss()}.accessibilityIdentifier("closeReferenceSources")}}
        }.sheet(item:$source){ReferenceSourceView(selection:$0)}
    }
}
#if !os(watchOS)
private struct ReferenceSourceView: View {
    let selection: ReferenceSourceSelection
    @State private var notice = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Group {
                if let source = CourseLibrary.shared.source(selection.file), let base = Bundle.main.resourceURL {
                    let url = base.appendingPathComponent(source.path)
                    if source.path.hasSuffix("pdf") {
                        VStack(spacing: 0) {
                            CoursePDFView(url: url, selection: selection)
                            if let pages = selection.pages {
                                Text("Страницы оригинала: " + pages.map(String.init).joined(separator: ", "))
                                    .font(.footnote).foregroundStyle(.secondary).padding(10)
                            }
                        }
                    } else if let image = UIImage(contentsOfFile: url.path) {
                        ScrollView([.horizontal, .vertical]) { Image(uiImage: image).resizable().scaledToFit().frame(width: UIScreen.main.bounds.width-24).padding(12) }
                    } else { ContentUnavailableView("Источник не найден", systemImage: "doc.questionmark", description: Text(source.title)) }
                }
            }.navigationTitle(CourseLibrary.shared.source(selection.file)?.title ?? "Источник").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if CourseLibrary.shared.source(selection.file)?.notice != nil {
                            Button { notice = true } label: { Image(systemName: "info.circle") }
                                .accessibilityLabel("Об источнике и дисклеймере").accessibilityIdentifier("sourceNotice")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() }.accessibilityIdentifier("closeReferenceSource") }
                }.sheet(isPresented: $notice) { StudentDetailSheet(title: "Об источнике", large: true) { Text(CourseLibrary.shared.source(selection.file)?.notice ?? "") } }
        }.presentationDetents([.large])
    }
}
private struct CoursePDFView: UIViewRepresentable {
    let url: URL
    let selection: ReferenceSourceSelection
    final class Coordinator { var key: String? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.accessibilityIdentifier = "referencePDF"
        load(view, coordinator: context.coordinator)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) { load(view, coordinator: context.coordinator) }
    private func load(_ view: PDFView, coordinator: Coordinator) {
        let key = url.path + selection.id
        guard coordinator.key != key else { return }
        coordinator.key = key
        guard let original = PDFDocument(url: url), let indices = selection.indices(pageCount: original.pageCount) else {
            view.document = nil
            view.accessibilityLabel = "Не удалось открыть выбранные страницы"
            view.accessibilityValue = "0"
            return
        }
        if selection.pages == nil { view.document = original }
        else {
            // This transient document contains only the requested pages; the bundled source is unchanged.
            let excerpt = PDFDocument()
            for index in indices {
                guard let page = original.page(at: index)?.copy() as? PDFPage else {
                    view.document = nil; view.accessibilityLabel = "Не удалось открыть выбранные страницы"; view.accessibilityValue = "0"; return
                }
                excerpt.insert(page, at: excerpt.pageCount)
            }
            view.document = excerpt
        }
        let count = view.document?.pageCount ?? 0
        view.accessibilityLabel = selection.pages.map { "Страницы оригинала: " + $0.map(String.init).joined(separator: ", ") } ?? "Полный конспект"
        // Reports the actual PDFKit document, rather than the requested range.
        view.accessibilityValue = String(count)
    }
}
#endif

extension MathTerm{
    var referenceID:String?{
        switch self{
        case .quadraticResidue:"quadratic-residue"
        case .gcd:"polynomial-gcd"
        case .finiteField:"finite-field"
        case .prime:"prime"
        case .monic:"monic"
        case .leading:"leading"
        case .coefficient:"coefficient"
        case .polynomial:"polynomial"
        case .root:"root"
        case .residueClass:"residue-class"
        case .congruence:"congruence"
        case .equivalent:"equivalent"
        case .remainder:"remainder"
        case .inverse:"inverse"
        case .degree:"degree"
        case .factor:"factor"
        case .multiplicity:"multiplicity"
        case .fermat:"fermat"
        case .euclid:"euclid"
        case .horner:"horner"
        case .legendre:"legendre"
        case .jacobi:"jacobi"
        case .reciprocity:"reciprocity"
        case .euler:"euler-criterion"
        case .extensionField:"extension-field"
        case .conjugate:"conjugate"
        case .binary:"binary"
        }
    }
}

/// The watch has one navigation stack shared by its three bottom destinations.
private struct ReferenceLibraryNavigation<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        #if os(watchOS)
        content()
        #else
        NavigationStack { content() }
        #endif
    }
}
