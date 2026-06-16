import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text(viewModel.statusText)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            currentImageSection()

            currentControlsSection()

            Spacer()
        }
        .padding()
        .fileImporter(
            isPresented: $viewModel.isImporterPresented,
            allowedContentTypes: [.png],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let firstURL = urls.first {
                    viewModel.handleImportedFile(.success(firstURL))
                } else {
                    viewModel.statusText = "Файл не выбран"
                }
            case .failure(let error):
                viewModel.handleImportedFile(.failure(error))
            }
        }
        .sheet(isPresented: $viewModel.isShareSheetPresented) {
            if let exportURL = viewModel.exportURL {
                ShareSheet(items: [exportURL])
            }
        }
    }

    @ViewBuilder
    private func currentImageSection() -> some View {
        switch viewModel.step {
        case .input:
            if let image = viewModel.inputImage {
                EditableImageView(
                    image: .constant(image),
                    isEditingEnabled: false,
                    stageTitle: "Исходное изображение",
                    committedStrokes: [],
                    activeTool: .erase,
                    brushSize: 1,
                    onStrokeFinished: { _ in },
                    onTapInImage: nil
                )
            } else {
                placeholderView(text: "Здесь появится выбранное изображение")
            }

        case .skeletonEdit, .gapAdjustment:
            EditableImageView(
                image: $viewModel.skeletonImage,
                isEditingEnabled: viewModel.step == .skeletonEdit && viewModel.isEditingEnabled,
                stageTitle: "Скелет контура",
                committedStrokes: viewModel.skeletonStrokes,
                activeTool: viewModel.skeletonEditingTool,
                brushSize: CGFloat(viewModel.skeletonBrushSize),
                onStrokeFinished: { stroke in
                    viewModel.addSkeletonStroke(stroke)
                },
                onTapInImage: nil
            )

        case .previewFill, .fillEdit, .final:
            EditableImageView(
                image: $viewModel.filledImage,
                isEditingEnabled: viewModel.step == .fillEdit && viewModel.isEditingEnabled,
                stageTitle: "Заливка",
                committedStrokes: [],
                activeTool: .erase,
                brushSize: 1,
                onStrokeFinished: { _ in },
                onTapInImage: viewModel.step == .fillEdit ? { point in
                    viewModel.deleteFilledRegion(at: point)
                } : nil
            )
        }
    }

    @ViewBuilder
    private func currentControlsSection() -> some View {
        switch viewModel.step {
        case .input:
            inputControls()

        case .skeletonEdit:
            skeletonEditControls()

        case .gapAdjustment:
            gapAdjustmentControls()

        case .previewFill:
            previewControls()

        case .fillEdit:
            fillEditControls()

        case .final:
            finalControls()
        }
    }

    private func inputControls() -> some View {
        VStack(spacing: 14) {
            Button("Вставьте изображение") {
                viewModel.openImporter()
            }
            .mainButtonStyle(background: .orange, foreground: .blue)

            Button("Перейти к обработке") {
                viewModel.processImage()
            }
            .mainButtonStyle(background: .orange, foreground: .blue)
            .disabled(viewModel.inputImage == nil)
            .opacity(viewModel.inputImage == nil ? 0.5 : 1.0)
        }
    }

    private func skeletonEditControls() -> some View {
        VStack(spacing: 14) {
            Picker("Инструмент", selection: $viewModel.skeletonEditingTool) {
                ForEach(SkeletonEditingTool.allCases) { tool in
                    Text(tool.title).tag(tool)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 8) {
                Text("Размер кисти: \(Int(viewModel.skeletonBrushSize))")
                    .font(.subheadline)

                Slider(
                    value: $viewModel.skeletonBrushSize,
                    in: 2...40,
                    step: 1
                )
            }

            Button("Готово") {
                viewModel.finishSkeletonEditing()
            }
            .mainButtonStyle(background: .orange, foreground: .blue)

            Button("Редакция не нужна") {
                viewModel.skipSkeletonEditing()
            }
            .mainButtonStyle(background: .gray.opacity(0.25), foreground: .primary)
        }
    }

    private func gapAdjustmentControls() -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Максимальная длина разрыва: \(Int(viewModel.gapDistance))")
                    .font(.subheadline)

                Slider(
                    value: $viewModel.gapDistance,
                    in: 1...50,
                    step: 1
                )
            }

            Button("Готово 2") {
                viewModel.finishGapAdjustment()
            }
            .mainButtonStyle(background: .orange, foreground: .blue)

            Button("Разрывы в норме") {
                viewModel.skipGapAdjustment()
            }
            .mainButtonStyle(background: .gray.opacity(0.25), foreground: .primary)
        }
    }

    private func previewControls() -> some View {
        Button("Продолжить") {
            viewModel.goToFillEdit()
        }
        .mainButtonStyle(background: .orange, foreground: .blue)
    }

    private func fillEditControls() -> some View {
        VStack(spacing: 14) {
            Picker("Инструмент", selection: $viewModel.fillEditingTool) {
                ForEach(FillEditingTool.allCases) { tool in
                    Text(tool.title).tag(tool)
                }
            }
            .pickerStyle(.segmented)

            Text("Тапни по залитой области, чтобы удалить её")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Готово 3") {
                viewModel.finishFillEditing()
            }
            .mainButtonStyle(background: .orange, foreground: .blue)

            Button("Удаление не нужно") {
                viewModel.skipFillEditing()
            }
            .mainButtonStyle(background: .gray.opacity(0.25), foreground: .primary)
        }
    }

    private func finalControls() -> some View {
        VStack(spacing: 14) {
            Button("Скачать") {
                viewModel.preparePNGForSharing()
            }
            .mainButtonStyle(background: .green, foreground: .white)

            Button("Начать заново") {
                viewModel.restart()
            }
            .mainButtonStyle(background: .orange, foreground: .blue)

            Button("Загрузить новое изображение") {
                viewModel.loadNewImage()
            }
            .mainButtonStyle(background: .blue, foreground: .white)
        }
    }

    private func placeholderView(text: String) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.gray.opacity(0.12))
            .frame(height: 540)
            .overlay {
                Text(text)
                    .foregroundStyle(.secondary)
            }
    }
}

private extension View {
    func mainButtonStyle(background: Color, foreground: Color) -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding()
            .background(background)
            .foregroundColor(foreground)
            .cornerRadius(16)
            .contentShape(Rectangle()) // 🔥 ВОТ ЭТО ВАЖНО
    }
}
