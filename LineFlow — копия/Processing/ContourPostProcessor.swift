//
//  ContourPostProcessor.swift
//  LineFlow
//
//  Created by macbook Алиса on 4/5/26.
//

import Foundation

enum ContourPostProcessor {

    static func closeContourGaps(
        in bitmap: ImageBitmap,
        maxDistance: Double
    ) -> ImageBitmap {

        let maxDistance = max(0, maxDistance)
        let maxDistanceSquared = maxDistance * maxDistance

        var result = bitmap
        let endpoints = findEndpoints(in: bitmap)

        guard endpoints.count >= 2 else {
            return result
        }

        var used = Set<Int>()

        for i in 0..<endpoints.count {
            if used.contains(i) { continue }

            let p1 = endpoints[i]
            var bestIndex: Int?
            var bestDistanceSquared = maxDistanceSquared

            for j in (i + 1)..<endpoints.count {
                if used.contains(j) { continue }

                let p2 = endpoints[j]
                let dx = Double(p1.x - p2.x)
                let dy = Double(p1.y - p2.y)
                let distanceSquared = dx * dx + dy * dy

                // ВАЖНО:
                // <= значит, что при значении шкалы 12
                // соединяются разрывы длиной ДО 12 px включительно.
                if distanceSquared <= bestDistanceSquared {
                    bestDistanceSquared = distanceSquared
                    bestIndex = j
                }
            }

            if let j = bestIndex {
                used.insert(i)
                used.insert(j)

                let p2 = endpoints[j]
                drawLine(from: p1, to: p2, on: &result)
            }
        }

        return result
    }

    static func removeShortConnectedComponents(
        from bitmap: ImageBitmap,
        minLength: Int
    ) -> ImageBitmap {

        let width = bitmap.width
        let height = bitmap.height
        let total = width * height

        var visited = [Bool](repeating: false, count: total)
        var result = bitmap

        let white = Pixel(r: 255, g: 255, b: 255, a: 255)

        func index(_ x: Int, _ y: Int) -> Int {
            y * width + x
        }

        let directions = [
            (1, 0), (-1, 0), (0, 1), (0, -1),
            (1, 1), (1, -1), (-1, 1), (-1, -1)
        ]

        for y in 0..<height {
            for x in 0..<width {
                let startIndex = index(x, y)

                if visited[startIndex] { continue }
                visited[startIndex] = true

                guard BitmapUtils.isBlack(bitmap.pixelAt(x: x, y: y)) else {
                    continue
                }

                var component: [(Int, Int)] = []
                var queue: [(Int, Int)] = [(x, y)]
                var head = 0

                while head < queue.count {
                    let (cx, cy) = queue[head]
                    head += 1

                    component.append((cx, cy))

                    for (dx, dy) in directions {
                        let nx = cx + dx
                        let ny = cy + dy

                        guard nx >= 0, nx < width, ny >= 0, ny < height else {
                            continue
                        }

                        let nIndex = index(nx, ny)

                        if visited[nIndex] { continue }
                        visited[nIndex] = true

                        if BitmapUtils.isBlack(bitmap.pixelAt(x: nx, y: ny)) {
                            queue.append((nx, ny))
                        }
                    }
                }

                if component.count < minLength {
                    for (cx, cy) in component {
                        result.setPixel(white, x: cx, y: cy)
                    }
                }
            }
        }

        return result
    }

    private static func findEndpoints(in bitmap: ImageBitmap) -> [(x: Int, y: Int)] {
        let width = bitmap.width
        let height = bitmap.height

        var endpoints: [(x: Int, y: Int)] = []

        guard width > 2, height > 2 else {
            return endpoints
        }

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {

                if !BitmapUtils.isBlack(bitmap.pixelAt(x: x, y: y)) {
                    continue
                }

                var count = 0

                for dy in -1...1 {
                    for dx in -1...1 {
                        if dx == 0 && dy == 0 { continue }

                        if BitmapUtils.isBlack(bitmap.pixelAt(x: x + dx, y: y + dy)) {
                            count += 1
                        }
                    }
                }

                if count == 1 {
                    endpoints.append((x: x, y: y))
                }
            }
        }

        return endpoints
    }

    private static func drawLine(
        from p1: (x: Int, y: Int),
        to p2: (x: Int, y: Int),
        on bitmap: inout ImageBitmap
    ) {
        let black = Pixel(r: 0, g: 0, b: 0, a: 255)

        let dx = abs(p2.x - p1.x)
        let dy = -abs(p2.y - p1.y)
        let sx = p1.x < p2.x ? 1 : -1
        let sy = p1.y < p2.y ? 1 : -1

        var err = dx + dy
        var x = p1.x
        var y = p1.y

        while true {
            bitmap.setPixel(black, x: x, y: y)

            if x == p2.x && y == p2.y {
                break
            }

            let e2 = 2 * err

            if e2 >= dy {
                err += dy
                x += sx
            }

            if e2 <= dx {
                err += dx
                y += sy
            }
        }
    }
}
