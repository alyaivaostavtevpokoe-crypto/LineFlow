import SwiftUI
import Combine

final class AppViewModel: NSObject, ObservableObject {
    @Published var inputImage: UIImage?
    @Published var resultImage: UIImage?
    @Published var isImporterPresented: Bool = false
    @Published var statusText: String = "Выберите PNG"

    @Published var isExporterPresented: Bool = false
    @Published var exportDocument: PNGDocument?

    private let importService = ImageImportService()
    private let processor = FillProcessor()

    func openImporter() {
        isImporterPresented = true
    }

    func handleImportedFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()

            guard let image = importService.loadImage(from: url) else {
                statusText = "Не удалось загрузить PNG"
                return
            }

            inputImage = image
            resultImage = nil
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

        statusText = "Обработка..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let result = self.processor.fill(image: inputImage)

            DispatchQueue.main.async {
                self.resultImage = result.image
                self.statusText = "Обработка завершена"
            }
        }
    }

    func prepareExport() {
        guard let resultImage else {
            statusText = "Сначала обработайте изображение"
            return
        }

        guard let pngData = resultImage.pngData() else {
            statusText = "Не удалось подготовить PNG"
            return
        }

        exportDocument = PNGDocument(data: pngData)
        isExporterPresented = true
    }

    func exportCompleted(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            statusText = "PNG сохранен"
        case .failure(let error):
            statusText = "Не удалось сохранить PNG"
            print("Ошибка экспорта: \(error)")
        }
    }
}
