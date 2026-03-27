import SwiftUI
import Combine

final class AppViewModel: NSObject, ObservableObject {
    @Published var inputImage: UIImage?
    @Published var resultImage: UIImage?
    @Published var isImporterPresented: Bool = false
    @Published var statusText: String = "Выберите PNG"

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

        let result = processor.fill(image: inputImage)
        resultImage = result.image
        statusText = "Обработка завершена"
    }

    func saveResultImage() {
        guard let resultImage else {
            statusText = "Сначала обработайте изображение"
            return
        }

        UIImageWriteToSavedPhotosAlbum(
            resultImage,
            self,
            #selector(saveCompleted(_:didFinishSavingWithError:contextInfo:)),
            nil
        )
    }

    @objc private func saveCompleted(
        _ image: UIImage,
        didFinishSavingWithError error: Error?,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        if let error = error {
            statusText = "Не удалось сохранить изображение"
            print("Ошибка сохранения: \(error)")
        } else {
            statusText = "Изображение сохранено в Фото"
        }
    }
}
