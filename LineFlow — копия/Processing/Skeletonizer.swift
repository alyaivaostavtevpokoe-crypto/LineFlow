//
//  Skeletonizer.swift
//  LineFlow
//
//  Created by macbook Алиса on 4/5/26.
//

import Foundation

enum Skeletonizer {

    static func skeletonizeGuoHall(from source: ImageBitmap) -> ImageBitmap {
        let width = source.width
        let height = source.height
        let total = width * height

        guard width > 2, height > 2 else {
            return source
        }

        @inline(__always)
        func idx(_ x: Int, _ y: Int) -> Int {
            y * width + x
        }

        var mask = [UInt8](repeating: 0, count: total)

        // 1. Перевод исходного bitmap в маску 0/1
        for y in 0..<height {
            for x in 0..<width {
                mask[idx(x, y)] = BitmapUtils.isBlack(source.pixelAt(x: x, y: y)) ? 1 : 0
            }
        }

        var changed = true
        var iterationCount = 0
        let maxIterations = 200

        let availableCores = ProcessInfo.processInfo.activeProcessorCount
        let workerCount = max(1, min(availableCores, height - 2))

        while changed && iterationCount < maxIterations {
            changed = false
            iterationCount += 1

            for subIteration in 0...1 {
                var toDelete = [UInt8](repeating: 0, count: total)
                var chunkChanged = [Bool](repeating: false, count: workerCount)

                // 2. Параллельная фаза поиска пикселей на удаление
                mask.withUnsafeBufferPointer { maskBuffer in
                    toDelete.withUnsafeMutableBufferPointer { deleteBuffer in

                        DispatchQueue.concurrentPerform(iterations: workerCount) { workerIndex in
                            let rowsCount = height - 2
                            let rowsPerWorker = (rowsCount + workerCount - 1) / workerCount

                            let startY = 1 + workerIndex * rowsPerWorker
                            let endY = min(height - 1, startY + rowsPerWorker)

                            guard startY < endY else { return }

                            for y in startY..<endY {
                                for x in 1..<(width - 1) {
                                    let i = idx(x, y)

                                    if maskBuffer[i] == 0 {
                                        continue
                                    }

                                    let p2 = maskBuffer[idx(x, y - 1)] != 0
                                    let p3 = maskBuffer[idx(x + 1, y - 1)] != 0
                                    let p4 = maskBuffer[idx(x + 1, y)] != 0
                                    let p5 = maskBuffer[idx(x + 1, y + 1)] != 0
                                    let p6 = maskBuffer[idx(x, y + 1)] != 0
                                    let p7 = maskBuffer[idx(x - 1, y + 1)] != 0
                                    let p8 = maskBuffer[idx(x - 1, y)] != 0
                                    let p9 = maskBuffer[idx(x - 1, y - 1)] != 0

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
                                        deleteBuffer[i] = 1
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. Параллельная фаза удаления
                mask.withUnsafeMutableBufferPointer { maskBuffer in
                    toDelete.withUnsafeBufferPointer { deleteBuffer in

                        DispatchQueue.concurrentPerform(iterations: workerCount) { workerIndex in
                            let rowsCount = height - 2
                            let rowsPerWorker = (rowsCount + workerCount - 1) / workerCount

                            let startY = 1 + workerIndex * rowsPerWorker
                            let endY = min(height - 1, startY + rowsPerWorker)

                            guard startY < endY else { return }

                            var localChanged = false

                            for y in startY..<endY {
                                for x in 1..<(width - 1) {
                                    let i = idx(x, y)

                                    if deleteBuffer[i] != 0 {
                                        maskBuffer[i] = 0
                                        localChanged = true
                                    }
                                }
                            }

                            chunkChanged[workerIndex] = localChanged
                        }
                    }
                }

                if chunkChanged.contains(true) {
                    changed = true
                }
            }
        }

        return bitmapFromMask(mask, width: width, height: height)
    }

    private static func bitmapFromMask(
        _ mask: [UInt8],
        width: Int,
        height: Int
    ) -> ImageBitmap {
        var pixels = [Pixel]()
        pixels.reserveCapacity(width * height)

        let black = Pixel(r: 0, g: 0, b: 0, a: 255)
        let white = Pixel(r: 255, g: 255, b: 255, a: 255)

        for value in mask {
            pixels.append(value != 0 ? black : white)
        }

        return ImageBitmap(width: width, height: height, pixels: pixels)
    }
}
