import SwiftUI
import Combine

final class AppViewModel: ObservableObject {
    @Published var inputImage: UIImage?
    @Published var baseSkeletonImage: UIImage?
    @Published var skeletonImage: UIImage?
    @Published var filledImage: UIImage?

    @Published var isImporterPresented = false
    @Published var statusText = "Выберите PNG"

    @Published var step: ProcessingStep = .input
    @Published var isEditingEnabled = false

    // Значение задаётся в пикселях изображения.
    @Published var gapDistance: Double = 12

    @Published var isShareSheetPresented = false
    @Published var exportURL: URL?

    // Один размер применяется и для дорисовки,
    // и для стирания скелета.
    @Published var skeletonEditingTool:
        SkeletonEditingTool = .erase

    @Published var skeletonBrushSize: Double = 12

    @Published var skeletonStrokes:
        [SkeletonStroke] = []

    @Published var fillEditingTool:
        FillEditingTool = .deleteRegion

    private let importService = ImageImportService()
    private let processor = FillProcessor()

    // MARK: - Import

    func openImporter() {
        isImporterPresented = true
    }

    func handleImportedFile(
        _ result: Result<URL, Error>
    ) {
        do {
            let url = try result.get()

            guard let image =
                importService.loadImage(from: url)
            else {
                statusText =
                    "Не удалось загрузить изображение"
                return
            }

            inputImage = image
            baseSkeletonImage = nil
            skeletonImage = nil
            filledImage = nil

            skeletonStrokes = []

            step = .input
            isEditingEnabled = false

            gapDistance = 12
            skeletonBrushSize = 12
            skeletonEditingTool = .erase
            fillEditingTool = .deleteRegion

            statusText = "Изображение загружено"
        } catch {
            statusText = "Ошибка импорта файла"

            print(
                "Ошибка импорта файла: \(error)"
            )
        }
    }

    // MARK: - Reset

    func resetToInitialState() {
        inputImage = nil
        baseSkeletonImage = nil
        skeletonImage = nil
        filledImage = nil

        skeletonStrokes = []

        step = .input
        isEditingEnabled = false

        gapDistance = 12
        skeletonBrushSize = 12

        skeletonEditingTool = .erase
        fillEditingTool = .deleteRegion

        isShareSheetPresented = false
        exportURL = nil

        statusText = "Выберите PNG"
    }

    func loadNewImage() {
        resetToInitialState()
        openImporter()
    }

    // MARK: - Skeleton generation

    func processImage() {
        guard let inputImage else {
            statusText =
                "Сначала загрузите изображение"
            return
        }

        statusText = "Строю скелет..."
        isEditingEnabled = false
        skeletonStrokes = []

        DispatchQueue.global(
            qos: .userInitiated
        ).async { [weak self] in
            guard let self else {
                return
            }

            let skeletonPreview =
                self.processor.makeSkeletonPreview(
                    from: inputImage
                )

            DispatchQueue.main.async {
                guard let skeletonPreview else {
                    self.statusText =
                        "Не удалось построить скелет"
                    return
                }

                self.baseSkeletonImage =
                    skeletonPreview

                self.skeletonImage =
                    skeletonPreview

                self.step = .skeletonEdit
                self.isEditingEnabled = true

                self.statusText =
                    "Редактирование скелета"
            }
        }
    }

    // MARK: - Skeleton editing

    func addSkeletonStroke(
        _ stroke: SkeletonStroke
    ) {
        guard !stroke.points.isEmpty else {
            return
        }

        skeletonStrokes.append(stroke)
    }

    func finishSkeletonEditing() {
        guard let currentSkeleton =
            skeletonImage
        else {
            step = .gapAdjustment
            isEditingEnabled = false
            return
        }

        let strokes = skeletonStrokes

        statusText =
            "Применяю правки скелета..."

        isEditingEnabled = false

        DispatchQueue.global(
            qos: .userInitiated
        ).async { [weak self] in
            guard let self else {
                return
            }

            let edited =
                self.processor.applySkeletonEdits(
                    to: currentSkeleton,
                    strokes: strokes
                ) ?? currentSkeleton

            DispatchQueue.main.async {
                self.skeletonImage = edited
                self.skeletonStrokes = []

                self.step = .gapAdjustment

                self.statusText =
                    "Настройте длину разрывов"
            }
        }
    }

    func skipSkeletonEditing() {
        skeletonStrokes = []
        isEditingEnabled = false

        step = .gapAdjustment

        statusText =
            "Настройте длину разрывов"
    }

    // MARK: - Gap adjustment

    func finishGapAdjustment() {
        buildFilledPreview()
    }

    func skipGapAdjustment() {
        buildFilledPreview()
    }

    private func buildFilledPreview() {
        guard let skeletonImage else {
            statusText =
                "Нет скелета для построения заливки"
            return
        }

        statusText = "Строю заливку..."
        isEditingEnabled = false

        // Значение ползунка передаётся
        // в FillProcessor как количество пикселей.
        let currentGap = max(
            0,
            gapDistance.rounded()
        )

        DispatchQueue.global(
            qos: .userInitiated
        ).async { [weak self] in
            guard let self else {
                return
            }

            let result = self.processor.fill(
                from: skeletonImage,
                gapDistance: currentGap
            )

            DispatchQueue.main.async {
                self.filledImage = result.image
                self.step = .previewFill

                self.statusText =
                    "Предпросмотр заливки"
            }
        }
    }

    // MARK: - Fill editing

    func goToFillEdit() {
        step = .fillEdit
        isEditingEnabled = true

        statusText =
            "Тапните по области, чтобы удалить её"
    }

    func deleteFilledRegion(
        at imagePoint: CGPoint
    ) {
        guard let filledImage else {
            return
        }

        guard
            step == .fillEdit,
            isEditingEnabled
        else {
            return
        }

        DispatchQueue.global(
            qos: .userInitiated
        ).async { [weak self] in
            guard let self else {
                return
            }

            let edited =
                self.processor.removeFilledRegion(
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

        statusText = "Готовый результат"
    }

    func skipFillEditing() {
        isEditingEnabled = false
        step = .final

        statusText = "Готовый результат"
    }

    // MARK: - Restart

    func restart() {
        guard let baseSkeletonImage else {
            step = .input

            statusText =
                "Нет базового скелета для перезапуска"

            return
        }

        skeletonImage = baseSkeletonImage
        filledImage = nil

        skeletonStrokes = []

        isEditingEnabled = true

        gapDistance = 12
        skeletonBrushSize = 12
        skeletonEditingTool = .erase

        step = .skeletonEdit

        statusText =
            "Возврат к редактированию скелета"
    }

    // MARK: - Export

    func preparePNGForSharing() {
        guard let filledImage else {
            statusText =
                "Нет результата для сохранения"
            return
        }

        guard let pngData =
            filledImage.pngData()
        else {
            statusText =
                "Не удалось подготовить PNG"
            return
        }

        let temporaryURL =
            FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "filled_layer.png"
                )

        do {
            if FileManager.default.fileExists(
                atPath: temporaryURL.path
            ) {
                try FileManager.default.removeItem(
                    at: temporaryURL
                )
            }

            try pngData.write(
                to: temporaryURL,
                options: .atomic
            )

            exportURL = temporaryURL
            isShareSheetPresented = true

            statusText =
                "PNG готов к сохранению"
        } catch {
            statusText =
                "Не удалось подготовить файл"

            print(
                "Ошибка записи PNG: \(error)"
            )
        }
    }
}
