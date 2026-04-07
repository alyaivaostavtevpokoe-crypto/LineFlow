import UIKit

final class FillProcessor {
    private func luminance(of pixel: Pixel) -> Double {
        let r = Double(pixel.r) / 255.0
        let g = Double(pixel.g) / 255.0
        let b = Double(pixel.b) / 255.0
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    private func isBlack(_ pixel: Pixel) -> Bool {
        pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a > 0
    }

    private func bitmapFromMask(
        _ mask: [Bool],
        width: Int,
        height: Int
    ) -> ImageBitmap {
        var pixels = [Pixel]()
        pixels.reserveCapacity(width * height)

        for value in mask {
            if value {
                pixels.append(Pixel(r: 0, g: 0, b: 0, a: 255))
            } else {
                pixels.append(Pixel(r: 255, g: 255, b: 255, a: 255))
            }
        }

        return ImageBitmap(width: width, height: height, pixels: pixels)
    }

    private func resizedForProcessing(_ image: UIImage, maxDimension: CGFloat = 1200) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)

        guard maxSide > maxDimension else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func blackNeighborCount(
        in source: ImageBitmap,
        x: Int,
        y: Int
    ) -> Int {
        let directions = [
            (-1, -1), (0, -1), (1, -1),
            (-1,  0),          (1,  0),
            (-1,  1), (0,  1), (1,  1)
        ]

        var count = 0

        for (dx, dy) in directions {
            let nx = x + dx
            let ny = y + dy

            guard nx >= 0, nx < source.width, ny >= 0, ny < source.height else {
                continue
            }

            if isBlack(source.pixelAt(x: nx, y: ny)) {
                count += 1
            }
        }

        return count
    }

    private func findEndpoints(in source: ImageBitmap) -> [(Int, Int)] {
        var endpoints: [(Int, Int)] = []

        for y in 0..<source.height {
            for x in 0..<source.width {
                let pixel = source.pixelAt(x: x, y: y)

                if !isBlack(pixel) {
                    continue
                }

                let neighborCount = blackNeighborCount(in: source, x: x, y: y)

                if neighborCount == 1 {
                    endpoints.append((x, y))
                }
            }
        }

        return endpoints
    }

    private func drawLine(
        on bitmap: inout ImageBitmap,
        from start: (Int, Int),
        to end: (Int, Int)
    ) {
        let (x0Start, y0Start) = start
        let (x1, y1) = end

        var x0 = x0Start
        var y0 = y0Start

        let dx = abs(x1 - x0)
        let dy = abs(y1 - y0)

        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1

        var err = dx - dy

        while true {
            bitmap.setPixel(Pixel(r: 0, g: 0, b: 0, a: 255), x: x0, y: y0)

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

    private func adaptiveThresholdBitmap(
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
                    gray[idx] = luminance(of: pixel)
                }
            }
        }

        // Integral image для быстрого локального среднего
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

    private func removeShortConnectedComponents(
        from source: ImageBitmap,
        minLength: Int = 10
    ) -> ImageBitmap {
        let width = source.width
        let height = source.height
        let total = width * height

        var resultBitmap = source
        var visited = [Bool](repeating: false, count: total)

        let directions = [
            (-1, -1), (0, -1), (1, -1),
            (-1,  0),          (1,  0),
            (-1,  1), (0,  1), (1,  1)
        ]

        for y in 0..<height {
            for x in 0..<width {
                let startIndex = y * width + x

                if visited[startIndex] {
                    continue
                }

                let startPixel = source.pixelAt(x: x, y: y)

                if !isBlack(startPixel) {
                    visited[startIndex] = true
                    continue
                }

                var queue: [(Int, Int)] = [(x, y)]
                var head = 0
                var componentPixels: [(Int, Int)] = [(x, y)]

                visited[startIndex] = true

                while head < queue.count {
                    let (currentX, currentY) = queue[head]
                    head += 1

                    for (dx, dy) in directions {
                        let nx = currentX + dx
                        let ny = currentY + dy

                        guard nx >= 0, nx < width, ny >= 0, ny < height else {
                            continue
                        }

                        let neighborIndex = ny * width + nx

                        if visited[neighborIndex] {
                            continue
                        }

                        let neighborPixel = source.pixelAt(x: nx, y: ny)

                        if isBlack(neighborPixel) {
                            visited[neighborIndex] = true
                            queue.append((nx, ny))
                            componentPixels.append((nx, ny))
                        }
                    }
                }

                let componentLength = componentPixels.count

                if componentLength < minLength {
                    for (px, py) in componentPixels {
                        resultBitmap.setPixel(
                            Pixel(r: 255, g: 255, b: 255, a: 255),
                            x: px,
                            y: py
                        )
                    }
                }
            }
        }

        return resultBitmap
    }

    private func skeletonizeGuoHall(from source: ImageBitmap) -> ImageBitmap {
        let width = source.width
        let height = source.height
        let total = width * height

        guard width > 2, height > 2 else {
            return source
        }

        func idx(_ x: Int, _ y: Int) -> Int {
            y * width + x
        }

        var mask = [Bool](repeating: false, count: total)

        for y in 0..<height {
            for x in 0..<width {
                mask[idx(x, y)] = isBlack(source.pixelAt(x: x, y: y))
            }
        }

        var changed = true
        var iterationCount = 0
        let maxIterations = 200

        while changed && iterationCount < maxIterations {
            changed = false
            iterationCount += 1

            for subIteration in 0...1 {
                var toDelete = [Bool](repeating: false, count: total)

                for y in 1..<(height - 1) {
                    for x in 1..<(width - 1) {
                        let i = idx(x, y)

                        if !mask[i] {
                            continue
                        }

                        let p2 = mask[idx(x, y - 1)]
                        let p3 = mask[idx(x + 1, y - 1)]
                        let p4 = mask[idx(x + 1, y)]
                        let p5 = mask[idx(x + 1, y + 1)]
                        let p6 = mask[idx(x, y + 1)]
                        let p7 = mask[idx(x - 1, y + 1)]
                        let p8 = mask[idx(x - 1, y)]
                        let p9 = mask[idx(x - 1, y - 1)]

                        let c =
                            (!p2 && (p3 || p4) ? 1 : 0) +
                            (!p4 && (p5 || p6) ? 1 : 0) +
                            (!p6 && (p7 || p8) ? 1 : 0) +
                            (!p8 && (p9 || p2) ? 1 : 0)

                        let n1 =
                            ((p9 || p2) ? 1 : 0) +
                            ((p3 || p4) ? 1 : 0) +
                            ((p5 || p6) ? 1 : 0) +
                            ((p7 || p8) ? 1 : 0)

                        let n2 =
                            ((p2 || p3) ? 1 : 0) +
                            ((p4 || p5) ? 1 : 0) +
                            ((p6 || p7) ? 1 : 0) +
                            ((p8 || p9) ? 1 : 0)

                        let n = min(n1, n2)

                        let m: Bool
                        if subIteration == 0 {
                            m = (p6 || p7 || !p9) && p8
                        } else {
                            m = (p2 || p3 || !p5) && p4
                        }

                        if c == 1 && (n == 2 || n == 3) && !m {
                            toDelete[i] = true
                        }
                    }
                }

                var deletedSomething = false

                for i in 0..<total {
                    if toDelete[i] {
                        mask[i] = false
                        deletedSomething = true
                    }
                }

                if deletedSomething {
                    changed = true
                }
            }
        }

        return bitmapFromMask(mask, width: width, height: height)
    }

    private func closeContourGaps(
        in source: ImageBitmap,
        maxDistance: Double = 12.0
    ) -> ImageBitmap {
        var resultBitmap = source
        let endpoints = findEndpoints(in: source)

        if endpoints.count < 2 {
            return resultBitmap
        }

        let maxDistanceSquared = maxDistance * maxDistance
        var used = [Bool](repeating: false, count: endpoints.count)

        func squaredDistance(_ a: (Int, Int), _ b: (Int, Int)) -> Double {
            let dx = Double(a.0 - b.0)
            let dy = Double(a.1 - b.1)
            return dx * dx + dy * dy
        }

        for i in 0..<endpoints.count {
            if used[i] {
                continue
            }

            let start = endpoints[i]
            var bestIndex: Int?
            var bestDistanceSquared = maxDistanceSquared

            for j in (i + 1)..<endpoints.count {
                if used[j] {
                    continue
                }

                let end = endpoints[j]
                let d2 = squaredDistance(start, end)

                if d2 <= bestDistanceSquared {
                    bestDistanceSquared = d2
                    bestIndex = j
                }
            }

            if let j = bestIndex {
                let end = endpoints[j]
                drawLine(on: &resultBitmap, from: start, to: end)
                used[i] = true
                used[j] = true
            }
        }

        return resultBitmap
    }

    func makeBinaryImage(from image: UIImage) -> UIImage? {
        let processingImage = resizedForProcessing(image)

        guard let sourceBitmap = ImageBitmap(image: processingImage) else {
            return nil
        }

        let binaryBitmap = adaptiveThresholdBitmap(
            from: sourceBitmap,
            windowRadius: 3,
            offset: 0.05
        )

        return binaryBitmap.toUIImage(scale: processingImage.scale)
    }

    func fill(image: UIImage) -> FillResult {
        let processingImage = resizedForProcessing(image)

        guard let sourceBitmap = ImageBitmap(image: processingImage) else {
            return FillResult(image: image, size: image.size)
        }

        let binaryBitmap = adaptiveThresholdBitmap(
            from: sourceBitmap,
            windowRadius: 3,
            offset: 0.05
        )

        let cleanedBitmap = removeShortConnectedComponents(
            from: binaryBitmap,
            minLength: 10
        )

        let skeletonBitmap = skeletonizeGuoHall(from: cleanedBitmap)

        let closedBitmap = closeContourGaps(
            in: skeletonBitmap,
            maxDistance: 12.0
        )

        let width = closedBitmap.width
        let height = closedBitmap.height
        let total = width * height

        var isBoundary = [Bool](repeating: false, count: total)
        var outside = [Bool](repeating: false, count: total)

        for y in 0..<height {
            for x in 0..<width {
                let pixel = closedBitmap.pixelAt(x: x, y: y)
                let idx = y * width + x
                isBoundary[idx] = isBlack(pixel)
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

        let resultImage = resultBitmap.toUIImage(scale: processingImage.scale) ?? processingImage

        return FillResult(
            image: resultImage,
            size: CGSize(width: width, height: height)
        )
    }
}
