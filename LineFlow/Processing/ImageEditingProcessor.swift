//
//  ImageEditingProcessor.swift
//  LineFlow
//
//  Created by macbook Алиса on 4/5/26.
//

import UIKit

enum ImageEditingProcessor {

    static func applySkeletonEdits(
        to image: UIImage,
        strokes: [SkeletonStroke]
    ) -> UIImage? {
        guard !strokes.isEmpty else { return image }
        guard var bitmap = ImageBitmap(image: image) else { return nil }

        for stroke in strokes {
            let pixel = strokePixel(for: stroke.tool)

            // ВАЖНО:
            // brushSize теперь трактуется как точное количество пикселей.
            // 1 = 1 пиксель, 2 = 2 пикселя, 3 = 3 пикселя и т.д.
            let brushSizePixels = max(1, Int(stroke.brushSize.rounded()))

            if stroke.points.count == 1, let onlyPoint = stroke.points.first {
                stampBrush(
                    on: &bitmap,
                    centerX: Int(onlyPoint.x.rounded()),
                    centerY: Int(onlyPoint.y.rounded()),
                    size: brushSizePixels,
                    pixel: pixel
                )
                continue
            }

            for index in 1..<stroke.points.count {
                let start = stroke.points[index - 1]
                let end = stroke.points[index]

                drawBrushLine(
                    on: &bitmap,
                    from: start,
                    to: end,
                    size: brushSizePixels,
                    pixel: pixel
                )
            }
        }

        return bitmap.toUIImage(scale: image.scale)
    }

    static func removeFilledRegion(
        from image: UIImage,
        at point: CGPoint
    ) -> UIImage? {
        guard var bitmap = ImageBitmap(image: image) else { return nil }

        let x = Int(point.x.rounded())
        let y = Int(point.y.rounded())

        guard x >= 0, x < bitmap.width, y >= 0, y < bitmap.height else {
            return image
        }

        let startPixel = bitmap.pixelAt(x: x, y: y)

        guard startPixel.a > 0 else {
            return image
        }

        let target = startPixel
        let transparent = Pixel(r: 0, g: 0, b: 0, a: 0)

        var visited = [Bool](repeating: false, count: bitmap.width * bitmap.height)
        var queue: [(Int, Int)] = [(x, y)]
        var head = 0

        let directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]

        while head < queue.count {
            let (cx, cy) = queue[head]
            head += 1

            let idx = cy * bitmap.width + cx
            if visited[idx] { continue }
            visited[idx] = true

            let pixel = bitmap.pixelAt(x: cx, y: cy)
            if !matches(pixel, target) { continue }

            bitmap.setPixel(transparent, x: cx, y: cy)

            for (dx, dy) in directions {
                let nx = cx + dx
                let ny = cy + dy

                guard nx >= 0, nx < bitmap.width, ny >= 0, ny < bitmap.height else {
                    continue
                }

                let nIdx = ny * bitmap.width + nx
                if visited[nIdx] { continue }

                let neighbor = bitmap.pixelAt(x: nx, y: ny)
                if matches(neighbor, target) {
                    queue.append((nx, ny))
                }
            }
        }

        return bitmap.toUIImage(scale: image.scale)
    }

    private static func strokePixel(for tool: SkeletonEditingTool) -> Pixel {
        switch tool {
        case .draw:
            return Pixel(r: 0, g: 0, b: 0, a: 255)
        case .erase:
            return Pixel(r: 255, g: 255, b: 255, a: 255)
        }
    }

    private static func stampBrush(
        on bitmap: inout ImageBitmap,
        centerX: Int,
        centerY: Int,
        size: Int,
        pixel: Pixel
    ) {
        guard bitmap.width > 0, bitmap.height > 0 else { return }

        let brushSize = max(1, size)

        // Делает точный квадрат brushSize x brushSize.
        // Например:
        // size 1 -> 1 пиксель
        // size 2 -> 2x2 пикселя
        // size 3 -> 3x3 пикселя
        let halfBefore = (brushSize - 1) / 2

        let minX = centerX - halfBefore
        let minY = centerY - halfBefore
        let maxX = minX + brushSize - 1
        let maxY = minY + brushSize - 1

        for y in minY...maxY {
            guard y >= 0, y < bitmap.height else { continue }

            for x in minX...maxX {
                guard x >= 0, x < bitmap.width else { continue }

                bitmap.setPixel(pixel, x: x, y: y)
            }
        }
    }

    private static func drawBrushLine(
        on bitmap: inout ImageBitmap,
        from start: CGPoint,
        to end: CGPoint,
        size: Int,
        pixel: Pixel
    ) {
        let x0Start = Int(start.x.rounded())
        let y0Start = Int(start.y.rounded())
        let x1 = Int(end.x.rounded())
        let y1 = Int(end.y.rounded())

        var x0 = x0Start
        var y0 = y0Start

        let dx = abs(x1 - x0)
        let dy = abs(y1 - y0)

        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1

        var err = dx - dy

        while true {
            stampBrush(
                on: &bitmap,
                centerX: x0,
                centerY: y0,
                size: size,
                pixel: pixel
            )

            if x0 == x1 && y0 == y1 {
                break
            }

            let e2 = 2 * err

            if e2 > -dy {
                err -= dy
                x0 += sx
            }

            if e2 < dx {
                err += dx
                y0 += sy
            }
        }
    }

    private static func matches(_ pixel: Pixel, _ target: Pixel) -> Bool {
        pixel.r == target.r &&
        pixel.g == target.g &&
        pixel.b == target.b &&
        pixel.a == target.a
    }
}
