//
//  FillBuilder.swift
//  LineFlow
//
//  Created by macbook Алиса on 4/5/26.
//

import Foundation

enum FillBuilder {

    static func buildFill(from bitmap: ImageBitmap) -> ImageBitmap {

        let width = bitmap.width
        let height = bitmap.height
        let total = width * height

        var isBoundary = [Bool](repeating: false, count: total)
        var outside = [Bool](repeating: false, count: total)

        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                isBoundary[idx] = BitmapUtils.isBlack(bitmap.pixelAt(x: x, y: y))
            }
        }

        var queue: [(Int, Int)] = []

        func enqueue(_ x: Int, _ y: Int) {
            guard x >= 0, x < width, y >= 0, y < height else { return }

            let idx = y * width + x
            if outside[idx] || isBoundary[idx] { return }

            outside[idx] = true
            queue.append((x, y))
        }

        for x in 0..<width {
            enqueue(x, 0)
            enqueue(x, height - 1)
        }

        for y in 0..<height {
            enqueue(0, y)
            enqueue(width - 1, y)
        }

        let directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        var head = 0

        while head < queue.count {
            let (x, y) = queue[head]
            head += 1

            for (dx, dy) in directions {
                enqueue(x + dx, y + dy)
            }
        }

        var result = ImageBitmap(
            width: width,
            height: height,
            pixels: [Pixel](
                repeating: Pixel(r: 0, g: 0, b: 0, a: 0),
                count: total
            )
        )

        let red = Pixel(r: 255, g: 0, b: 0, a: 255)

        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x

                if !outside[idx] && !isBoundary[idx] {
                    result.setPixel(red, x: x, y: y)
                }
            }
        }

        return result
    }
}
