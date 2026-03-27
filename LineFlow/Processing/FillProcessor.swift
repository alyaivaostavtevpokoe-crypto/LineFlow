import UIKit

final class FillProcessor {
    func fill(image: UIImage) -> FillResult {
        guard let sourceBitmap = ImageBitmap(image: image) else {
            return FillResult(image: image, size: image.size)
        }

        let width = sourceBitmap.width
        let height = sourceBitmap.height
        let total = width * height

        var isBoundary = [Bool](repeating: false, count: total)
        var outside = [Bool](repeating: false, count: total)

        func brightness(of pixel: Pixel) -> Double {
            let r = Double(pixel.r) / 255.0
            let g = Double(pixel.g) / 255.0
            let b = Double(pixel.b) / 255.0
            return (r + g + b) / 3.0
        }

        for y in 0..<height {
            for x in 0..<width {
                let pixel = sourceBitmap.pixelAt(x: x, y: y)
                let alpha = Double(pixel.a) / 255.0
                let value = brightness(of: pixel)

                let boundary = alpha > 0.05 && value < 0.7
                isBoundary[y * width + x] = boundary
            }
        }

        var queue: [(Int, Int)] = []

        func enqueueIfNeeded(x: Int, y: Int) {
            guard x >= 0, x < width, y >= 0, y < height else { return }

            let idx = y * width + x
            if outside[idx] || isBoundary[idx] { return }

            outside[idx] = true
            queue.append((x, y))
        }

        for x in 0..<width {
            enqueueIfNeeded(x: x, y: 0)
            enqueueIfNeeded(x: x, y: height - 1)
        }

        for y in 0..<height {
            enqueueIfNeeded(x: 0, y: y)
            enqueueIfNeeded(x: width - 1, y: y)
        }

        let directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        var head = 0

        while head < queue.count {
            let (x, y) = queue[head]
            head += 1

            for (dx, dy) in directions {
                enqueueIfNeeded(x: x + dx, y: y + dy)
            }
        }

        var resultBitmap = ImageBitmap(
            width: width,
            height: height,
            pixels: [Pixel](repeating: Pixel(r: 0, g: 0, b: 0, a: 0), count: total)
        )

        let fillPixel = Pixel(r: 255, g: 0, b: 0, a: 255)

        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x

                if !isBoundary[idx] && !outside[idx] {
                    resultBitmap.setPixel(fillPixel, x: x, y: y)
                }
            }
        }

        let resultImage = resultBitmap.toUIImage(scale: image.scale) ?? image

        return FillResult(
            image: resultImage,
            size: CGSize(width: width, height: height)
        )
    }
}

