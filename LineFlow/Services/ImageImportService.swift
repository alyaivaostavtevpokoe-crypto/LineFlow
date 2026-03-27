import UIKit

final class ImageImportService {
    func loadImage(from url: URL) -> UIImage? {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {//выполнить код перед выходом из функции
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            print("Не удалось прочитать файл по URL: \(url)")
            return nil
        }

        return image
    }
}

