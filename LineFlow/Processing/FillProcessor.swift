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

    private func strokePixel(for tool: SkeletonEditingTool) -> Pixel {
        switch tool {
        case .draw:
            return Pixel(r: 0, g: 0, b: 0, a: 255)
        case .erase:
            return Pixel(r: 255, g: 255, b: 255, a: 255)
        }
    }

    private func stampBrush(
        on bitmap: inout ImageBitmap,
        centerX: Int,
        centerY: Int,
        radius: Int,
        pixel: Pixel
    ) {
        guard bitmap.width > 0, bitmap.height > 0 else { return }

        guard radius > 0 else {
            if centerX >= 0, centerX < bitmap.width, centerY >= 0, centerY < bitmap.height {
                bitmap.setPixel(pixel, x: centerX, y: centerY)
            }
            return
        }

        let minX = max(0, centerX - radius)
        let maxX = min(bitmap.width - 1, centerX + radius)
        let minY = max(0, centerY - radius)
        let maxY = min(bitmap.height - 1, centerY + radius)

        guard minX <= maxX, minY <= maxY else { return }

        let radiusSquared = radius * radius

        for y in minY...maxY {
            for x in minX...maxX {
                let dx = x - centerX
                let dy = y - centerY

                if dx * dx + dy * dy <= radiusSquared {
                    bitmap.setPixel(pixel, x: x, y: y)
                }
            }
        }
    
    }

    private func drawBrushLine(
        on bitmap: inout ImageBitmap,
        from start: CGPoint,
        to end: CGPoint,
        radius: Int,
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
                radius: radius,
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

    func applySkeletonEdits(
        to image: UIImage,
        strokes: [SkeletonStroke]
    ) -> UIImage? {
        guard !strokes.isEmpty else { return image }
        guard var bitmap = ImageBitmap(image: image) else { return nil }

        for stroke in strokes {
            let pixel = strokePixel(for: stroke.tool)
            let radius = max(1, Int((stroke.brushSize / 2).rounded()))

            if stroke.points.count == 1, let onlyPoint = stroke.points.first {
                stampBrush(
                    on: &bitmap,
                    centerX: Int(onlyPoint.x.rounded()),
                    centerY: Int(onlyPoint.y.rounded()),
                    radius: radius,
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
                    radius: radius,
                    pixel: pixel
                )
            }
        }

        return bitmap.toUIImage(scale: image.scale)
    }

    func removeFilledRegion(
        from image: UIImage,
        at imagePoint: CGPoint
    ) -> UIImage? {
        guard var bitmap = ImageBitmap(image: image) else { return nil }

        let x = Int(imagePoint.x.rounded())
        let y = Int(imagePoint.y.rounded())

        guard x >= 0, x < bitmap.width, y >= 0, y < bitmap.height else {
            return image
        }

        let startPixel = bitmap.pixelAt(x: x, y: y)

        // Удаляем только непрозрачную заливку, а не прозрачный фон
        guard startPixel.a > 0 else {
            return image
        }

        let target = startPixel
        let transparent = Pixel(r: 0, g: 0, b: 0, a: 0)

        var visited = [Bool](repeating: false, count: bitmap.width * bitmap.height)
        var queue: [(Int, Int)] = [(x, y)]
        var head = 0

        func matches(_ pixel: Pixel, _ target: Pixel) -> Bool {
            pixel.r == target.r &&
            pixel.g == target.g &&
            pixel.b == target.b &&
            pixel.a == target.a
        }

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
        guard let sourceBitmap = ImageBitmap(image: image) else {
            return nil
        }

        let binaryBitmap = adaptiveThresholdBitmap(
            from: sourceBitmap,
            windowRadius: 3,
            offset: 0.05
        )

        return binaryBitmap.toUIImage(scale: image.scale)
    }

    func makeSkeletonPreview(from image: UIImage) -> UIImage? {
        guard let sourceBitmap = ImageBitmap(image: image) else {
            return nil
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

        return skeletonBitmap.toUIImage(scale: image.scale)
    }

    func fill(fromSkeletonImage skeletonImage: UIImage, gapDistance: Double = 12.0) -> FillResult {
        guard let sourceBitmap = ImageBitmap(image: skeletonImage) else {
            return FillResult(image: skeletonImage, size: skeletonImage.size)
        }

        let closedBitmap = closeContourGaps(
            in: sourceBitmap,
            maxDistance: gapDistance
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

        guard let resultImage = resultBitmap.toUIImage(scale: skeletonImage.scale) else {
            return FillResult(image: skeletonImage, size: skeletonImage.size)
        }

        return FillResult(
            image: resultImage,
            size: skeletonImage.size
        )
    }

    func fill(image: UIImage, gapDistance: Double = 12.0) -> FillResult {
        guard let sourceBitmap = ImageBitmap(image: image) else {
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
            maxDistance: gapDistance
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

        guard let resultImage = resultBitmap.toUIImage(scale: image.scale) else {
            return FillResult(image: image, size: image.size)
        }

        return FillResult(
            image: resultImage,
            size: image.size
        )
    }
}
