//
//  ColorPickerFlowView.swift
//  LineFlow
//
//  Created by macbook Алиса on 20/5/26.
//

import SwiftUI
import PhotosUI

struct ColorPickerFlowView: View {
    @StateObject private var viewModel = ColorPickerViewModel()

    @State private var screen: ColorPickerScreen = .sourceChoice
    @State private var selectedPhotoItem: PhotosPickerItem?

    let onBackToStart: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            if viewModel.isFinished {
                resultScreen
            } else {
                switch screen {
                case .sourceChoice:
                    sourceChoiceScreen
                case .manualPicker:
                    pickerScreen
                case .imagePicker:
                    imagePickerScreen
                }
            }
        }
        .padding()
        .onChange(of: selectedPhotoItem) { newItem in
            loadSelectedPhoto(newItem)
        }
    }

    private var sourceChoiceScreen: some View {
        VStack(spacing: 24) {
            Text("Подбор цвета")
                .font(.largeTitle)
                .bold()

            Text("Выберите, как задать исходный цвет.")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Выбрать цвет") {
                screen = .manualPicker
            }
            .colorButton(background: .purple, foreground: .white)

            Button("Вставить цвет") {
                screen = .imagePicker
            }
            .colorButton(background: .orange, foreground: .blue)

            Button("Назад") {
                onBackToStart()
            }
            .colorButton(background: .gray.opacity(0.25), foreground: .primary)
        }
    }

    private var imagePickerScreen: some View {
        VStack(spacing: 18) {
            Text("Вставить цвет")
                .font(.largeTitle)
                .bold()

            Text(viewModel.importStatusText)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images
            ) {
                Text("Выбрать скриншот")
                    .colorButton(background: .purple, foreground: .white)
            }

            if let image = viewModel.importedColorImage {
                ColorImageSamplerView(
                    image: image,
                    selectedPixelPoint: viewModel.selectedImagePoint
                ) { pixelPoint in
                    viewModel.selectColorFromImportedImage(at: pixelPoint)
                }
                .frame(height: 320)

                HStack(spacing: 16) {
                    colorPreview(title: "Выбранный", color: viewModel.sourceColor)
                }
            } else {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.gray.opacity(0.18))
                    .frame(height: 220)
                    .overlay {
                        Text("Здесь появится выбранное изображение")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
            }

            Button("Перейти к подбору") {
                screen = .manualPicker
            }
            .colorButton(
                background: viewModel.selectedImagePoint == nil ? .gray.opacity(0.2) : .orange,
                foreground: viewModel.selectedImagePoint == nil ? .secondary : .blue
            )
            .disabled(viewModel.selectedImagePoint == nil)

            Button("Назад") {
                screen = .sourceChoice
            }
            .colorButton(background: .gray.opacity(0.25), foreground: .primary)
        }
    }

    private var pickerScreen: some View {
        VStack(spacing: 22) {
            Text("Подбор цвета")
                .font(.largeTitle)
                .bold()

            ColorWheelView(
                hue: $viewModel.hue,
                saturation: $viewModel.saturation,
                brightness: $viewModel.brightness
            )
            .frame(maxWidth: 520)
            .padding(.horizontal)

            Picker("Тип цвета", selection: $viewModel.selectedType) {
                ForEach(ColorShadowType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 16) {
                colorPreview(title: "Исходный", color: viewModel.sourceColor)

                if let resultColor = viewModel.resultColor {
                    colorPreview(title: "Результат", color: resultColor)
                }
            }

            Button("Подобрать цвет") {
                viewModel.calculateResult()
            }
            .colorButton(background: .purple, foreground: .white)

            Button("Назад") {
                screen = .sourceChoice
            }
            .colorButton(background: .gray.opacity(0.25), foreground: .primary)
        }
    }

    private var resultScreen: some View {
        VStack(spacing: 24) {
            Text("Результат")
                .font(.largeTitle)
                .bold()

            if let resultColor = viewModel.resultColor {
                RoundedRectangle(cornerRadius: 18)
                    .fill(resultColor)
                    .frame(height: 180)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.8), lineWidth: 2)
                    }
                    .shadow(radius: 8)
            }

            Button("Начать заново") {
                viewModel.reset()
                selectedPhotoItem = nil
                screen = .sourceChoice
            }
            .colorButton(background: .orange, foreground: .blue)

            Button("В главное меню") {
                onBackToStart()
            }
            .colorButton(background: .gray.opacity(0.25), foreground: .primary)
        }
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                await MainActor.run {
                    viewModel.importStatusText = "Не удалось открыть изображение. Попробуйте выбрать другой скриншот."
                }
                return
            }

            await MainActor.run {
                viewModel.setImportedColorImage(image)
            }
        }
    }

    private func colorPreview(title: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)

            RoundedRectangle(cornerRadius: 12)
                .fill(color)
                .frame(width: 110, height: 64)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.8), lineWidth: 2)
                }
        }
    }
}

private enum ColorPickerScreen {
    case sourceChoice
    case manualPicker
    case imagePicker
}

private struct ColorImageSamplerView: View {
    let image: UIImage
    let selectedPixelPoint: CGPoint?
    let onPointSelected: (CGPoint) -> Void

    var body: some View {
        GeometryReader { geometry in
            let imageSize = pixelSize(of: image)
            let imageRect = aspectFitRect(
                imageSize: imageSize,
                containerSize: geometry.size
            )

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.gray.opacity(0.14))

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                if let selectedPixelPoint {
                    let markerPoint = displayPoint(
                        from: selectedPixelPoint,
                        imageSize: imageSize,
                        imageRect: imageRect
                    )

                    Circle()
                        .stroke(.white, lineWidth: 3)
                        .background {
                            Circle()
                                .fill(.black.opacity(0.18))
                        }
                        .shadow(color: .black.opacity(0.45), radius: 5, x: 0, y: 2)
                        .frame(width: 34, height: 34)
                        .position(markerPoint)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        guard imageRect.contains(value.location) else { return }

                        let pixelPoint = pixelPoint(
                            from: value.location,
                            imageSize: imageSize,
                            imageRect: imageRect
                        )

                        onPointSelected(pixelPoint)
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func pixelSize(of image: UIImage) -> CGSize {
        if let cgImage = image.cgImage {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }

        return image.size
    }

    private func aspectFitRect(
        imageSize: CGSize,
        containerSize: CGSize
    ) -> CGRect {
        guard imageSize.width > 0,
              imageSize.height > 0,
              containerSize.width > 0,
              containerSize.height > 0 else {
            return .zero
        }

        let scale = min(
            containerSize.width / imageSize.width,
            containerSize.height / imageSize.height
        )

        let width = imageSize.width * scale
        let height = imageSize.height * scale

        return CGRect(
            x: (containerSize.width - width) / 2,
            y: (containerSize.height - height) / 2,
            width: width,
            height: height
        )
    }

    private func pixelPoint(
        from displayPoint: CGPoint,
        imageSize: CGSize,
        imageRect: CGRect
    ) -> CGPoint {
        let relativeX = (displayPoint.x - imageRect.minX) / imageRect.width
        let relativeY = (displayPoint.y - imageRect.minY) / imageRect.height

        let x = min(max(relativeX * imageSize.width, 0), imageSize.width - 1)
        let y = min(max(relativeY * imageSize.height, 0), imageSize.height - 1)

        return CGPoint(x: x, y: y)
    }

    private func displayPoint(
        from pixelPoint: CGPoint,
        imageSize: CGSize,
        imageRect: CGRect
    ) -> CGPoint {
        let x = imageRect.minX + pixelPoint.x / imageSize.width * imageRect.width
        let y = imageRect.minY + pixelPoint.y / imageSize.height * imageRect.height

        return CGPoint(x: x, y: y)
    }
}

private extension View {
    func colorButton(background: Color, foreground: Color) -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding()
            .background(background)
            .foregroundColor(foreground)
            .cornerRadius(16)
            .font(.headline)
    }
}
