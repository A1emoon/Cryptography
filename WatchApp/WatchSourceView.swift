import SwiftUI
import CoreGraphics
import ImageIO

struct ReferenceSourceView: View {
    let selection: ReferenceSourceSelection
    @State private var index = 0
    @State private var scale = 1.0
    @State private var notice = false
    @Environment(\.dismiss) private var dismiss
    private var source: ReferenceSource? { CourseLibrary.shared.source(selection.file) }
    private var pages: [Int] { selection.indices(pageCount: source?.pages ?? 0)?.map { $0+1 } ?? [] }
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white.ignoresSafeArea()
            if let source, !pages.isEmpty, pages.indices.contains(index), let base = Bundle.main.resourceURL {
                WatchPageCanvas(url: base.appendingPathComponent(source.path), page: pages[index], scale: $scale, onPage: changePage)
                    .id("\(source.id)_\(pages[index])")
                    .ignoresSafeArea()
                    .accessibilityAction(named: "Следующая страница") { changePage(1) }
                    .accessibilityAction(named: "Предыдущая страница") { changePage(-1) }
                    .accessibilityAction(named: "Сбросить масштаб") { scale = 1 }
                    .accessibilityAction(named: "Об источнике") { notice = true }
            } else {
                ContentUnavailableView("Страницы не найдены", systemImage: "doc.questionmark").foregroundStyle(.black)
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white).frame(width: 34, height: 34)
                    .background(Color.black.opacity(0.65), in: Circle())
            }.buttonStyle(.plain).padding(.top, 8).padding(.leading, 10)
                .accessibilityLabel("Закрыть конспект").accessibilityIdentifier("closeReferenceSource")
        }.ignoresSafeArea().toolbar(.hidden, for: .navigationBar).persistentSystemOverlays(.hidden)
            .sheet(isPresented: $notice) { StudentDetailSheet(title: "Об источнике", large: true) { Text(source?.notice ?? source?.title ?? "") } }
    }
    private func changePage(_ delta: Int) {
        let next = index+delta
        guard pages.indices.contains(next) else { return }
        scale = 1; index = next
    }
}
private struct WatchPageCanvas: View {
    let url: URL
    let page: Int
    @Binding var scale: Double
    let onPage: (Int) -> Void
    @State private var raster: SourcePageRaster?
    @State private var error: String?
    @State private var position = DocumentPoint()
    @GestureState private var drag = CGSize.zero
    @FocusState private var crownFocused: Bool
    private var quality: Int { min(2400, max(600, Int(ceil(scale)*400))) }
    var body: some View {
        GeometryReader { geometry in
            let viewport = DocumentSize(width: geometry.size.width, height: geometry.size.height)
            ZStack {
                Color.white
                if let raster {
                    let pageSize = DocumentSize(width: Double(raster.image.width), height: Double(raster.image.height))
                    let fit = DocumentViewport.fit(page: pageSize, viewport: viewport)
                    let offset = DocumentViewport.offset(DocumentPoint(x: position.x+drag.width, y: position.y+drag.height), page: pageSize, viewport: viewport, zoom: scale)
                    Image(decorative: raster.image, scale: 1).resizable()
                        .frame(width: fit.width*scale, height: fit.height*scale)
                        .position(x: geometry.size.width/2+offset.x, y: geometry.size.height/2+offset.y)
                    Color.clear.contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 1).updating($drag) { value, state, _ in state = value.translation }
                            .onEnded { value in
                                if scale <= 1.01, abs(value.translation.width) > 40,
                                   abs(value.translation.width) > abs(value.translation.height)*1.5 {
                                    onPage(value.translation.width < 0 ? 1 : -1)
                                    return
                                }
                                position = DocumentViewport.offset(DocumentPoint(x: position.x+value.translation.width, y: position.y+value.translation.height), page: pageSize, viewport: viewport, zoom: scale)
                                crownFocused = true
                            })
                        .onTapGesture(count: 2) { scale = 1; position = DocumentPoint(); crownFocused = true }
                        .onChange(of: scale) { old, new in
                            let factor = DocumentViewport.zoom(new)/DocumentViewport.zoom(old)
                            position = DocumentViewport.offset(DocumentPoint(x: position.x*factor, y: position.y*factor), page: pageSize, viewport: viewport, zoom: new)
                            crownFocused = true
                        }
                } else if let error { Text(error).font(.caption2).foregroundStyle(.black).padding(8) }
                else { ProgressView().tint(.black) }
            }.clipped().contentShape(Rectangle())
                .focusable().focused($crownFocused).focusEffectDisabled()
                .digitalCrownRotation($scale, from: 1, through: 6, by: 0.05, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: false)
                .digitalCrownAccessory(.hidden)
                .accessibilityElement(children: .ignore).accessibilityLabel("Конспект, страница \(page). Колёсико — масштаб, перетаскивание — перемещение. При исходном масштабе смахните вбок для смены страницы; двойное касание сбрасывает масштаб.")
                .accessibilityValue(raster == nil ? (error ?? "Загрузка") : "\(Int(scale*100)) процентов" + (position == DocumentPoint() ? "" : "; страница сдвинута"))
                .accessibilityIdentifier("watchSourcePage")
                .accessibilityAdjustableAction { direction in
                    switch direction { case .increment: scale = DocumentViewport.zoom(scale+0.5); case .decrement: scale = DocumentViewport.zoom(scale-0.5); @unknown default: break }
                }
        }.task(id: "\(url.path)_\(page)_\(quality)") {
            let pixels = quality
            do {
                if raster != nil { try await Task.sleep(for: .milliseconds(180)) }
                let task = Task.detached(priority: .utility) { try SourcePageRenderer.render(url: url, page: page, pixels: pixels) }
                let result = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
                try Task.checkCancellation(); raster = result; error = nil; crownFocused = true
            } catch is CancellationError { }
            catch { self.error = error.localizedDescription }
        }
    }
}
