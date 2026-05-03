import SwiftUI
import Combine

final class AppViewModel: ObservableObject {
    @Published var inputImage: UIImage?
    @Published var baseSkeletonImage: UIImage?
    @Published var skeletonImage: UIImage?
    @Published var filledImage: UIImage?

    @Published var isImporterPresented: Bool = false
    @Published var statusText: String = "Выберите PNG"

    @Published var step: ProcessingStep = .input
    @Published var isEditingEnabled: Bool = false

    @Published var gapDistance: Double = 12.0

    @Published var isShareSheetPresented: Bool = false
    @Published var exportURL: URL?

    // Этап 3 — редактирование скелета
    @Published var skeletonEditingTool: SkeletonEditingTool = .erase
    @Published var skeletonBrushSize: Double = 12.0
    @Published var skeletonStrokes: [SkeletonStroke] = []

    // Этап 6 — редактирование заливки
    @Published var fillEditingTool: FillEditingTool = .deleteRegion

    private let importService = ImageImportService()
    private let processor = FillProcessor()

    func openImporter() {
        isImporterPresented = true
    }

    func resetToInitialState() {
        inputImage = nil
        baseSkeletonImage = nil
        skeletonImage = nil
        filledImage = nil

        skeletonStrokes = []

        step = .input
        isEditingEnabled = false

        gapDistance = 12.0

        isShareSheetPresented = false
        exportURL = nil

        skeletonEditingTool = .erase
        skeletonBrushSize = 12.0
        fillEditingTool = .deleteRegion

        statusText = "Выберите PNG"
    }

    func loadNewImage() {
        resetToInitialState()
        openImporter()
    }

    func handleImportedFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()

            guard let image = importService.loadImage(from: url) else {
                statusText = "Не удалось загрузить PNG"
                return
            }

            inputImage = image
            baseSkeletonImage = nil
            skeletonImage = nil
            filledImage = nil
            skeletonStrokes = []
            step = .input
            isEditingEnabled = false
            gapDistance = 12.0
            skeletonEditingTool = .erase
            skeletonBrushSize = 12.0
            fillEditingTool = .deleteRegion
            statusText = "PNG загружен"
        } catch {
            statusText = "Ошибка импорта файла"
            print("Ошибка импорта файла: \(error)")
        }
    }

    func processImage() {
        guard let inputImage else {
            statusText = "Сначала загрузите изображение"
            return
        }

        statusText = "Строю скелет..."
        isEditingEnabled = false
        skeletonStrokes = []

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let skeletonPreview = self.processor.makeSkeletonPreview(from: inputImage)

            DispatchQueue.main.async {
                guard let skeletonPreview else {
                    self.statusText = "Не удалось построить скелет"
                    return
                }

                self.baseSkeletonImage = skeletonPreview
                self.skeletonImage = skeletonPreview
                self.step = .skeletonEdit
                self.isEditingEnabled = true
                self.statusText = "Этап 3: редактируй скелет"
            }
        }
    }

    func addSkeletonStroke(_ stroke: SkeletonStroke) {
        guard !stroke.points.isEmpty else { return }
        skeletonStrokes.append(stroke)
    }

    func finishSkeletonEditing() {
        guard let currentSkeleton = skeletonImage else {
            step = .gapAdjustment
            isEditingEnabled = false
            return
        }

        let strokes = skeletonStrokes

        statusText = "Применяю правки скелета..."
        isEditingEnabled = false

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let edited = self.processor.applySkeletonEdits(
                to: currentSkeleton,
                strokes: strokes
            ) ?? currentSkeleton

            DispatchQueue.main.async {
                self.skeletonImage = edited
                self.skeletonStrokes = []
                self.step = .gapAdjustment
                self.statusText = "Этап 4: настрой длину разрывов"
            }
        }
    }

    func skipSkeletonEditing() {
        skeletonStrokes = []
        isEditingEnabled = false
        step = .gapAdjustment
        statusText = "Этап 4: настрой длину разрывов"
    }

    func finishGapAdjustment() {
        buildFilledPreview()
    }

    func skipGapAdjustment() {
        buildFilledPreview()
    }

    private func buildFilledPreview() {
        guard let skeletonImage else {
            statusText = "Нет скелета для построения заливки"
            return
        }

        statusText = "Строю заливку..."
        isEditingEnabled = false

        let currentGap = gapDistance

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let result = self.processor.fill(
                fromSkeletonImage: skeletonImage,
                gapDistance: currentGap
            )

            DispatchQueue.main.async {
                self.filledImage = result.image
                self.step = .previewFill
                self.statusText = "Этап 5: предпросмотр заливки"
            }
        }
    }

    func goToFillEdit() {
        step = .fillEdit
        isEditingEnabled = true
        statusText = "Этап 6: тапни по залитой области, чтобы удалить её"
    }

    func deleteFilledRegion(at imagePoint: CGPoint) {
        guard let filledImage else { return }
        guard step == .fillEdit, isEditingEnabled else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let edited = self.processor.removeFilledRegion(
                from: filledImage,
                at: imagePoint
            ) ?? filledImage

            DispatchQueue.main.async {
                self.filledImage = edited
            }
        }
    }

    func finishFillEditing() {
        isEditingEnabled = false
        step = .final
        statusText = "Этап 7: готовый результат"
    }

    func skipFillEditing() {
        isEditingEnabled = false
        step = .final
        statusText = "Этап 7: готовый результат"
    }

    func restart() {
        guard let baseSkeletonImage else {
            step = .input
            statusText = "Нет базового скелета для перезапуска"
            return
        }

        skeletonImage = baseSkeletonImage
        filledImage = nil
        skeletonStrokes = []
        isEditingEnabled = true
        gapDistance = 12.0
        step = .skeletonEdit
        statusText = "Возврат на этап 3"
    }

    func preparePNGForSharing() {
        guard let filledImage else {
            statusText = "Нет результата для сохранения"
            return
        }

        guard let pngData = filledImage.pngData() else {
            statusText = "Не удалось подготовить PNG"
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("filled_layer.png")

        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }

            try pngData.write(to: tempURL, options: .atomic)
            exportURL = tempURL
            isShareSheetPresented = true
            statusText = "PNG готов к сохранению"
        } catch {
            statusText = "Не удалось подготовить файл"
            print("Ошибка записи PNG: \(error)")
        }
    }
}
