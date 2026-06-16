//
//  BitmapUtils.swift
//  LineFlow
//
//  Created by macbook Алиса on 4/5/26.
//

import Foundation

enum BitmapUtils {

    static func luminance(of pixel: Pixel) -> Double {
        let r = Double(pixel.r) / 255.0
        let g = Double(pixel.g) / 255.0
        let b = Double(pixel.b) / 255.0
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    static func isBlack(_ pixel: Pixel) -> Bool {
        pixel.r == 0 && pixel.g == 0 && pixel.b == 0 && pixel.a > 0
    }
}
