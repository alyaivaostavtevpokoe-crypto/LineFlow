//
//  ColorPickerViewModel.swift
//  LineFlow
//
//  Created by macbook Алиса on 20/5/26.
//

import SwiftUI
import UIKit
import Combine

final class ColorPickerViewModel: ObservableObject {
    @Published var hue: Double = 0.52
    @Published var saturation: Double = 0.75
    @Published var brightness: Double = 0.85

    @Published var selectedType: ColorShadowType = .brightShadow
    @Published var resultColor: Color?
    @Published var isFinished: Bool = false

    @Published var importedColorImage: UIImage?
    @Published var selectedImagePoint: CGPoint?
    @Published var importStatusText: String = "Выберите скриншот с цветом, затем тапните по нужному месту."

    var sourceColor: Color {
        Color(
            hue: hue,
            saturation: saturation,
            brightness: brightness
        )
    }

    func setImportedColorImage(_ image: UIImage) {
        importedColorImage = image
        selectedImagePoint = nil
        resultColor = nil
        isFinished = false
        importStatusText = "Тапните по цвету на изображении. Лучше нажимать ближе к центру однотонной области."
    }

    func selectColorFromImportedImage(at pixelPoint: CGPoint) {
        guard let importedColorImage else {
            importStatusText = "Сначала выберите изображение."
            return
        }

        guard let sampledColor = ColorMathProcessor.sampleColor(
            from: importedColorImage,
            at: pixelPoint
        ) else {
            importStatusText = "Не удалось определить цвет. Попробуйте выбрать другое изображение."
            return
        }

        hue = sampledColor.hue
        saturation = sampledColor.saturation
        brightness = sampledColor.brightness
        selectedImagePoint = pixelPoint
        resultColor = nil
        isFinished = false
        importStatusText = "Цвет выбран. Теперь можно перейти к подбору."
    }

    func calculateResult() {
        let result = ColorMathProcessor.makeColor(
            hue: hue,
            saturation: saturation,
            brightness: brightness,
            type: selectedType
        )

        resultColor = Color(
            hue: result.hue,
            saturation: result.saturation,
            brightness: result.brightness
        )

        isFinished = true
    }

    func reset() {
        hue = 0.52
        saturation = 0.75
        brightness = 0.85
        selectedType = .brightShadow
        resultColor = nil
        isFinished = false
        importedColorImage = nil
        selectedImagePoint = nil
        importStatusText = "Выберите скриншот с цветом, затем тапните по нужному месту."
    }
}
