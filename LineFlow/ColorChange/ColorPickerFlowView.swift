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
        GeometryReader { geometry in
            ZStack {
                LineFlowBackground(geometry: geometry)
                content(size: geometry.size)
            }
        }
        .ignoresSafeArea()
        .onChange(of: selectedPhotoItem) { newItem in
            loadSelectedPhoto(newItem)
        }
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        let landscape = size.width > size.height
        let maxWidth = landscape ? min(size.width * 0.62, 900) : min(size.width * 0.90, 680)

        VStack(spacing: landscape ? 10 : 18) {
            Spacer(minLength: landscape ? size.height * 0.15 : size.height * 0.13)

            if viewModel.isFinished {
                resultScreen(maxWidth: maxWidth, size: size)
            } else {
                switch screen {
                case .sourceChoice:
                    sourceChoiceScreen(maxWidth: maxWidth, landscape: landscape)
                case .manualPicker:
                    pickerScreen(maxWidth: maxWidth, size: size)
                case .imagePicker:
                    imagePickerScreen(maxWidth: maxWidth, size: size)
                }
            }
            Spacer(minLength: 16)
        }
        .padding(.horizontal, landscape ? 52 : 18)
    }

    private func sourceChoiceScreen(maxWidth: CGFloat, landscape: Bool) -> some View {
        VStack(spacing: landscape ? 12 : 22) {
            Text("Подбор цвета")
                .font(.system(size: landscape ? 38 : 46, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 82 / 255, green: 57 / 255, blue: 131 / 255))
            Text("Выберите, как задать исходный цвет.")
                .font(.system(size: landscape ? 20 : 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 82 / 255, green: 57 / 255, blue: 131 / 255))

            AssetButton(imageName: "lf_color_choose", action: { screen = .manualPicker }, maxWidth: maxWidth)
            AssetButton(imageName: "lf_color_insert", action: { screen = .imagePicker }, maxWidth: maxWidth)
            AssetButton(imageName: "lf_color_back_light", action: onBackToStart, maxWidth: maxWidth)
        }
    }

    private func imagePickerScreen(maxWidth: CGFloat, size: CGSize) -> some View {
        let landscape = size.width > size.height
        return VStack(spacing: landscape ? 8 : 15) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Image("lf_color_choose_screenshot")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: maxWidth)
            }

            Group {
                if let image = viewModel.importedColorImage {
                    ColorImageSamplerView(
                        image: image,
                        selectedPixelPoint: viewModel.selectedImagePoint,
                        onPointSelected: viewModel.selectColorFromImportedImage
                    )
                } else {
                    Color.white
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: landscape ? size.height * 0.44 : size.height * 0.48)
            .lineFlowPanel()

            if viewModel.selectedImagePoint != nil {
                VStack(spacing: 5) {
                    Text("Выбранный цвет")
                        .font(.system(size: landscape ? 17 : 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 82 / 255, green: 57 / 255, blue: 131 / 255))
                    RoundedRectangle(cornerRadius: 0)
                        .fill(viewModel.sourceColor)
                        .frame(width: landscape ? 150 : 180, height: landscape ? 52 : 68)
                }
            }

            AssetButton(
                imageName: "lf_color_go_to_picker",
                action: { screen = .manualPicker },
                enabled: viewModel.selectedImagePoint != nil,
                maxWidth: maxWidth
            )
            AssetButton(imageName: "lf_color_back_light", action: { screen = .sourceChoice }, maxWidth: maxWidth)
        }
    }

    private func pickerScreen(maxWidth: CGFloat, size: CGSize) -> some View {
        let landscape = size.width > size.height
        return VStack(spacing: landscape ? 7 : 14) {
            ColorWheelView(
                hue: $viewModel.hue,
                saturation: $viewModel.saturation,
                brightness: $viewModel.brightness
            )
            .frame(width: landscape ? min(size.width * 0.39, 520) : min(size.width * 0.72, 520),
                   height: landscape ? size.height * 0.42 : size.height * 0.38)
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color.white)

            shadowPicker(maxWidth: maxWidth)

            VStack(spacing: 4) {
                Text("Исходный")
                    .font(.system(size: landscape ? 17 : 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 82 / 255, green: 57 / 255, blue: 131 / 255))
                RoundedRectangle(cornerRadius: 0)
                    .fill(viewModel.sourceColor)
                    .frame(width: landscape ? 150 : 180, height: landscape ? 52 : 68)
            }

            AssetButton(imageName: "lf_color_calculate", action: viewModel.calculateResult, maxWidth: maxWidth)
            AssetButton(imageName: "lf_color_back", action: { screen = .sourceChoice }, maxWidth: maxWidth)
        }
    }

    private func shadowPicker(maxWidth: CGFloat) -> some View {
        ZStack {
            Image("lf_color_shadow_selector")
                .resizable()
                .scaledToFit()
            HStack(spacing: 0) {
                Button { viewModel.selectedType = .brightShadow } label: { Color.clear }
                Button { viewModel.selectedType = .classicShadow } label: { Color.clear }
                Button { viewModel.selectedType = .reflectedShadow } label: { Color.clear }
            }
        }
        .frame(maxWidth: maxWidth)
        .aspectRatio(2048 / 107, contentMode: .fit)
    }

    private func resultScreen(maxWidth: CGFloat, size: CGSize) -> some View {
        let landscape = size.width > size.height
        return VStack(spacing: landscape ? 12 : 22) {
            Text("Результат")
                .font(.system(size: landscape ? 38 : 46, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 82 / 255, green: 57 / 255, blue: 131 / 255))

            RoundedRectangle(cornerRadius: 0)
                .fill(viewModel.resultColor ?? .white)
                .frame(maxWidth: .infinity)
                .frame(height: landscape ? size.height * 0.22 : size.height * 0.28)
                .lineFlowPanel()

            AssetButton(imageName: "lf_color_restart", action: {
                viewModel.reset()
                selectedPhotoItem = nil
                screen = .sourceChoice
            }, maxWidth: maxWidth)

            AssetButton(imageName: "lf_color_main_menu", action: onBackToStart, maxWidth: maxWidth)
        }
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                await MainActor.run {
                    viewModel.importStatusText = "Не удалось открыть изображение"
                }
                return
            }
            await MainActor.run {
                viewModel.setImportedColorImage(image)
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
            let imageRect = aspectFitRect(imageSize: imageSize, containerSize: geometry.size)

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)

                if let selectedPixelPoint {
                    Circle()
                        .stroke(.white, lineWidth: 3)
                        .background(Circle().fill(.black.opacity(0.18)))
                        .frame(width: 34, height: 34)
                        .position(displayPoint(from: selectedPixelPoint, imageSize: imageSize, imageRect: imageRect))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onEnded { value in
                    guard imageRect.contains(value.location) else { return }
                    onPointSelected(pixelPoint(from: value.location, imageSize: imageSize, imageRect: imageRect))
                }
            )
        }
        .clipped()
    }

    private func pixelSize(of image: UIImage) -> CGSize {
        if let cg = image.cgImage { return CGSize(width: cg.width, height: cg.height) }
        return image.size
    }

    private func aspectFitRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(x: (containerSize.width - width) / 2, y: (containerSize.height - height) / 2, width: width, height: height)
    }

    private func pixelPoint(from point: CGPoint, imageSize: CGSize, imageRect: CGRect) -> CGPoint {
        let x = (point.x - imageRect.minX) / imageRect.width * imageSize.width
        let y = (point.y - imageRect.minY) / imageRect.height * imageSize.height
        return CGPoint(x: min(max(x, 0), imageSize.width - 1), y: min(max(y, 0), imageSize.height - 1))
    }

    private func displayPoint(from point: CGPoint, imageSize: CGSize, imageRect: CGRect) -> CGPoint {
        CGPoint(x: imageRect.minX + point.x / imageSize.width * imageRect.width,
                y: imageRect.minY + point.y / imageSize.height * imageRect.height)
    }
}
