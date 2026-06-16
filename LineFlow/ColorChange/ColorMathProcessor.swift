//
//  ColorMathProcessor.swift
//  LineFlow
//
//  Created by macbook Алиса on 20/5/26.
//

import UIKit

enum ColorMathProcessor {

    static func makeColor(
        hue: Double,
        saturation: Double,
        brightness: Double,
        type: ColorShadowType
    ) -> (hue: Double, saturation: Double, brightness: Double) {

        switch type {

        case .brightShadow:
            // Яркая тень:

            return (
                hue: hue,
                saturation: clamp(saturation + 0.18),
                brightness: brightness
            )

        case .classicShadow:
            // Классическая тень:
            
            return (
                hue: hue,
                saturation: clamp(saturation + 0.12),
                brightness: clamp(brightness - 0.25)
            )

        case .reflectedShadow:
            // Отраженная тень:
            
            return (
                hue: wrapHue(hue - 0.25),
                saturation: clamp(saturation + 0.12),
                brightness: clamp(brightness - 0.25)
            )
        }
    }

    static func sampleColor(
        from image: UIImage,
        at pixelPoint: CGPoint,
        radius: Int = 3
    ) -> (hue: Double, saturation: Double, brightness: Double)? {
        guard let bitmap = ImageBitmap(image: image) else { return nil }

        let centerX = min(max(Int(pixelPoint.x.rounded()), 0), bitmap.width - 1)
        let centerY = min(max(Int(pixelPoint.y.rounded()), 0), bitmap.height - 1)

        let minX = max(centerX - radius, 0)
        let maxX = min(centerX + radius, bitmap.width - 1)
        let minY = max(centerY - radius, 0)
        let maxY = min(centerY + radius, bitmap.height - 1)

        var redSum = 0.0
        var greenSum = 0.0
        var blueSum = 0.0
        var alphaSum = 0.0
        var count = 0.0

        for y in minY...maxY {
            for x in minX...maxX {
                let pixel = bitmap.pixelAt(x: x, y: y)
                redSum += Double(pixel.r)
                greenSum += Double(pixel.g)
                blueSum += Double(pixel.b)
                alphaSum += Double(pixel.a)
                count += 1
            }
        }

        guard count > 0 else { return nil }

        let red = CGFloat(redSum / count / 255.0)
        let green = CGFloat(greenSum / count / 255.0)
        let blue = CGFloat(blueSum / count / 255.0)
        let alpha = CGFloat(alphaSum / count / 255.0)

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var finalAlpha: CGFloat = 0

        UIColor(
            red: red,
            green: green,
            blue: blue,
            alpha: alpha
        ).getHue(
            &hue,
            saturation: &saturation,
            brightness: &brightness,
            alpha: &finalAlpha
        )

        return (
            hue: Double(hue),
            saturation: Double(saturation),
            brightness: Double(brightness)
        )
    }

    private static func clamp(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }

    private static func wrapHue(_ value: Double) -> Double {
        var result = value

        while result < 0 {
            result += 1
        }

        while result > 1 {
            result -= 1
        }

        return result
    }
}
