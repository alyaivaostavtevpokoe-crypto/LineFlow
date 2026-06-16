import UIKit
import CoreGraphics

struct Pixel {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8
}

struct ImageBitmap {
    let width: Int
    let height: Int
    var pixels: [Pixel]

    init(width: Int, height: Int, pixels: [Pixel]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    init?(image: UIImage) {
        guard let cgImage = image.cgImage else { return nil }

        width = cgImage.width
        height = cgImage.height

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8

        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &rawData,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var pixels: [Pixel] = []
        pixels.reserveCapacity(width * height)

        for i in stride(from: 0, to: rawData.count, by: 4) {
            let pixel = Pixel(
                r: rawData[i],
                g: rawData[i + 1],
                b: rawData[i + 2],
                a: rawData[i + 3]
            )
            pixels.append(pixel)
        }

        self.pixels = pixels
    }

    func index(x: Int, y: Int) -> Int {
        y * width + x
    }

    func pixelAt(x: Int, y: Int) -> Pixel {
        pixels[index(x: x, y: y)]
    }

    mutating func setPixel(_ pixel: Pixel, x: Int, y: Int) {
        pixels[index(x: x, y: y)] = pixel
    }

    func toUIImage(scale: CGFloat = 1.0) -> UIImage? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8

        var rawData = [UInt8]()
        rawData.reserveCapacity(width * height * 4)

        for pixel in pixels {
            rawData.append(pixel.r)
            rawData.append(pixel.g)
            rawData.append(pixel.b)
            rawData.append(pixel.a)
        }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(rawData) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}

