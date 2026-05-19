//
//  BinarizationProcessor.swift
//  LineFlow
//
//  Created by macbook Алиса on 4/5/26.
//

import Foundation

enum BinarizationProcessor {

    static func adaptiveThresholdBitmap(
        from source: ImageBitmap,
        windowRadius: Int = 3,
        offset: Double = 0.05
    ) -> ImageBitmap {
        let width = source.width
        let height = source.height
        let total = width * height

        var gray = [Double](repeating: 0.0, count: total)

        for y in 0..<height {
            for x in 0..<width {
                let pixel = source.pixelAt(x: x, y: y)
                let alpha = Double(pixel.a) / 255.0
                let idx = y * width + x

                if alpha < 0.05 {
                    gray[idx] = 1.0
                } else {
                    gray[idx] = BitmapUtils.luminance(of: pixel)
                }
            }
        }

        var integral = [Double](repeating: 0.0, count: (width + 1) * (height + 1))

        func integralIndex(_ x: Int, _ y: Int) -> Int {
            y * (width + 1) + x
        }

        for y in 0..<height {
            var rowSum = 0.0

            for x in 0..<width {
                rowSum += gray[y * width + x]

                integral[integralIndex(x + 1, y + 1)] =
                    integral[integralIndex(x + 1, y)] + rowSum
            }
        }

        func rectSum(minX: Int, minY: Int, maxX: Int, maxY: Int) -> Double {
            let x1 = minX
            let y1 = minY
            let x2 = maxX + 1
            let y2 = maxY + 1

            return integral[integralIndex(x2, y2)]
                - integral[integralIndex(x1, y2)]
                - integral[integralIndex(x2, y1)]
                + integral[integralIndex(x1, y1)]
        }

        var resultPixels = [Pixel](
            repeating: Pixel(r: 255, g: 255, b: 255, a: 255),
            count: total
        )

        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x

                let minX = max(0, x - windowRadius)
                let maxX = min(width - 1, x + windowRadius)
                let minY = max(0, y - windowRadius)
                let maxY = min(height - 1, y + windowRadius)

                let sum = rectSum(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
                let count = (maxX - minX + 1) * (maxY - minY + 1)
                let localMean = sum / Double(count)
                let threshold = localMean - offset

                if gray[idx] < threshold {
                    resultPixels[idx] = Pixel(r: 0, g: 0, b: 0, a: 255)
                } else {
                    resultPixels[idx] = Pixel(r: 255, g: 255, b: 255, a: 255)
                }
            }
        }

        return ImageBitmap(width: width, height: height, pixels: resultPixels)
    }
}
