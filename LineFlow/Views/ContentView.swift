import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    let onBackToStart: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LineFlowBackground(geometry: geometry)

                VStack(spacing: 0) {
                    Spacer(
                        minLength: geometry.size.height * 0.105
                    )

                    imageArea(size: geometry.size)

                    controls(size: geometry.size)
                }
                .padding(
                    .horizontal,
                    geometry.size.width > geometry.size.height
                        ? 52
                        : 18
                )
                .padding(
                    .bottom,
                    geometry.size.width > geometry.size.height
                        ? 22
                        : 36
                )
            }
        }
        .ignoresSafeArea()
        .fileImporter(
            isPresented: $viewModel.isImporterPresented,
            allowedContentTypes: [.png, .jpeg],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let firstURL = urls.first else {
                    viewModel.statusText = "Файл не выбран"
                    return
                }

                viewModel.handleImportedFile(
                    .success(firstURL)
                )

            case .failure(let error):
                viewModel.handleImportedFile(
                    .failure(error)
                )
            }
        }
        .sheet(
            isPresented: $viewModel.isShareSheetPresented
        ) {
            if let exportURL = viewModel.exportURL {
                ShareSheet(items: [exportURL])
            }
        }
    }

    // MARK: - Image area

    @ViewBuilder
    private func imageArea(size: CGSize) -> some View {
        let landscape = size.width > size.height

        let areaHeight = landscape
            ? size.height * 0.49
            : size.height * 0.47

        Group {
            switch viewModel.step {
            case .input:
                inputImageArea

            case .skeletonEdit, .gapAdjustment:
                skeletonImageArea

            case .previewFill, .fillEdit, .final:
                filledImageArea
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: areaHeight)
        .lineFlowPanel()
        .clipped()
    }

    @ViewBuilder
    private var inputImageArea: some View {
        if viewModel.inputImage != nil {
            EditableImageView(
                image: $viewModel.inputImage,
                isEditingEnabled: false,
                stageTitle: "",
                committedStrokes: [],
                activeTool: .erase,
                brushSize: 1,
                onStrokeFinished: { _ in },
                onTapInImage: nil
            )
        } else {
            Color.white
        }
    }

    private var skeletonImageArea: some View {
        EditableImageView(
            image: $viewModel.skeletonImage,
            isEditingEnabled:
                viewModel.step == .skeletonEdit &&
                viewModel.isEditingEnabled,
            stageTitle: "",
            committedStrokes: viewModel.skeletonStrokes,
            activeTool: viewModel.skeletonEditingTool,
            brushSize: CGFloat(
                viewModel.skeletonBrushSize
            ),
            onStrokeFinished: { stroke in
                viewModel.addSkeletonStroke(stroke)
            },
            onTapInImage: nil
        )
    }

    private var filledImageArea: some View {
        EditableImageView(
            image: $viewModel.filledImage,
            isEditingEnabled:
                viewModel.step == .fillEdit &&
                viewModel.isEditingEnabled,
            stageTitle: "",
            committedStrokes: [],
            activeTool: .erase,
            brushSize: 1,
            onStrokeFinished: { _ in },
            onTapInImage: fillTapHandler
        )
    }

    // MARK: - Controls

    @ViewBuilder
    private func controls(size: CGSize) -> some View {
        let landscape = size.width > size.height

        let maxButtonWidth = landscape
            ? min(size.width * 0.60, 850)
            : min(size.width * 0.88, 620)

        let spacing: CGFloat = landscape ? 8 : 16

        VStack(spacing: spacing) {
            switch viewModel.step {
            case .input:
                inputControls(
                    landscape: landscape,
                    maxButtonWidth: maxButtonWidth
                )

            case .skeletonEdit:
                skeletonEditControls(
                    maxButtonWidth: maxButtonWidth
                )

            case .gapAdjustment:
                gapAdjustmentControls(
                    maxButtonWidth: maxButtonWidth
                )

            case .previewFill:
                previewFillControls(
                    maxButtonWidth: maxButtonWidth
                )

            case .fillEdit:
                fillEditControls(
                    landscape: landscape,
                    maxButtonWidth: maxButtonWidth
                )

            case .final:
                finalControls(
                    landscape: landscape,
                    maxButtonWidth: maxButtonWidth
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, landscape ? 10 : 18)
    }

    private func inputControls(
        landscape: Bool,
        maxButtonWidth: CGFloat
    ) -> some View {
        VStack(spacing: landscape ? 8 : 16) {
            AssetButton(
                imageName: "lf_fill_insert",
                action: viewModel.openImporter,
                maxWidth: maxButtonWidth
            )

            AssetButton(
                imageName: "lf_fill_process",
                action: viewModel.processImage,
                enabled: viewModel.inputImage != nil,
                maxWidth: maxButtonWidth
            )

            AssetButton(
                imageName: "lf_main_menu",
                action: returnToMainMenu,
                maxWidth: landscape ? 150 : 190
            )
        }
    }

    private func skeletonEditControls(
        maxButtonWidth: CGFloat
    ) -> some View {
        VStack(spacing: 8) {
            toolPicker(
                maxWidth: maxButtonWidth
            )

            brushSlider(
                maxWidth: maxButtonWidth
            )

            AssetButton(
                imageName: "lf_fill_done",
                action: viewModel.finishSkeletonEditing,
                maxWidth: maxButtonWidth
            )

            AssetButton(
                imageName: "lf_fill_edit_not_needed",
                action: viewModel.skipSkeletonEditing,
                maxWidth: maxButtonWidth
            )
        }
    }

    private func gapAdjustmentControls(
        maxButtonWidth: CGFloat
    ) -> some View {
        VStack(spacing: 8) {
            gapSlider(
                maxWidth: maxButtonWidth
            )

            AssetButton(
                imageName: "lf_fill_done_2",
                action: viewModel.finishGapAdjustment,
                maxWidth: maxButtonWidth
            )

            AssetButton(
                imageName: "lf_fill_gaps_ok",
                action: viewModel.skipGapAdjustment,
                maxWidth: maxButtonWidth
            )
        }
    }

    private func previewFillControls(
        maxButtonWidth: CGFloat
    ) -> some View {
        AssetButton(
            imageName: "lf_fill_continue",
            action: viewModel.goToFillEdit,
            maxWidth: maxButtonWidth
        )
    }

    private func fillEditControls(
        landscape: Bool,
        maxButtonWidth: CGFloat
    ) -> some View {
        VStack(spacing: landscape ? 8 : 14) {
            Image("lf_fill_delete_mode")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: maxButtonWidth)

            Text("Тапни по области, чтобы удалить её")
                .font(
                    .system(
                        size: landscape ? 18 : 22,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    Color(
                        red: 82 / 255,
                        green: 57 / 255,
                        blue: 131 / 255
                    )
                )

            AssetButton(
                imageName: "lf_fill_done_3",
                action: viewModel.finishFillEditing,
                maxWidth: maxButtonWidth
            )

            AssetButton(
                imageName: "lf_fill_delete_not_needed",
                action: viewModel.skipFillEditing,
                maxWidth: maxButtonWidth
            )
        }
    }

    private func finalControls(
        landscape: Bool,
        maxButtonWidth: CGFloat
    ) -> some View {
        VStack(spacing: landscape ? 8 : 16) {
            AssetButton(
                imageName: "lf_fill_download",
                action: viewModel.preparePNGForSharing,
                maxWidth: maxButtonWidth
            )

            AssetButton(
                imageName: "lf_fill_restart",
                action: viewModel.restart,
                maxWidth: maxButtonWidth
            )

            AssetButton(
                imageName: "lf_fill_load_new",
                action: viewModel.loadNewImage,
                maxWidth: maxButtonWidth
            )

            AssetButton(
                imageName: "lf_main_menu",
                action: returnToMainMenu,
                maxWidth: landscape ? 150 : 190
            )
        }
    }

    // MARK: - Fill editing

    private var fillTapHandler: ((CGPoint) -> Void)? {
        guard viewModel.step == .fillEdit else {
            return nil
        }

        return { point in
            viewModel.deleteFilledRegion(at: point)
        }
    }

    // MARK: - Skeleton editing tools

    private func toolPicker(
        maxWidth: CGFloat
    ) -> some View {
        ZStack {
            Image("lf_fill_tool_selector")
                .resizable()
                .scaledToFit()

            HStack(spacing: 0) {
                Button {
                    viewModel.skeletonEditingTool = .draw
                } label: {
                    Color.clear
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Дорисовка")

                Button {
                    viewModel.skeletonEditingTool = .erase
                } label: {
                    Color.clear
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Стирание")
            }

            toolSelectionIndicator
        }
        .frame(maxWidth: maxWidth)
        .aspectRatio(
            2048 / 98,
            contentMode: .fit
        )
    }

    private var toolSelectionIndicator: some View {
        GeometryReader { geometry in
            let halfWidth = geometry.size.width / 2

            let selectedX: CGFloat =
                viewModel.skeletonEditingTool == .draw
                    ? halfWidth / 2
                    : halfWidth + halfWidth / 2

            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color.white.opacity(0.9),
                    lineWidth: 3
                )
                .frame(
                    width: max(halfWidth - 10, 1),
                    height: max(geometry.size.height - 8, 1)
                )
                .position(
                    x: selectedX,
                    y: geometry.size.height / 2
                )
                .allowsHitTesting(false)
        }
    }

    // MARK: - Functional sliders

    private func brushSlider(
        maxWidth: CGFloat
    ) -> some View {
        LineFlowSlider(
            title: "Размер кисти",
            value: $viewModel.skeletonBrushSize,
            range: 2...40,
            step: 1
        )
        .frame(maxWidth: maxWidth)
    }

    private func gapSlider(
        maxWidth: CGFloat
    ) -> some View {
        LineFlowSlider(
            title: "Максимальная длина разрыва",
            value: $viewModel.gapDistance,
            range: 0...50,
            step: 1
        )
        .frame(maxWidth: maxWidth)
    }

    // MARK: - Navigation

    private func returnToMainMenu() {
        viewModel.resetToInitialState()
        onBackToStart()
    }
}

// MARK: - Custom functional slider

private struct LineFlowSlider: View {
    let title: String

    @Binding var value: Double

    let range: ClosedRange<Double>
    let step: Double

    @State private var isDragging = false

    private var normalizedValue: Double {
        let rangeLength =
            range.upperBound - range.lowerBound

        guard rangeLength > 0 else {
            return 0
        }

        let normalized =
            (value - range.lowerBound) / rangeLength

        return min(
            max(normalized, 0),
            1
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let sliderHeight = geometry.size.height

            let thumbSize = max(
                28,
                min(sliderHeight * 0.48, 44)
            )

            let horizontalInset = thumbSize / 2

            let availableWidth = max(
                geometry.size.width - thumbSize,
                1
            )

            let thumbX =
                horizontalInset +
                availableWidth * CGFloat(normalizedValue)

            ZStack {
                VStack(spacing: 5) {
                    Text(
                        "\(title): \(formattedValue)"
                    )
                    .font(
                        .system(
                            size: max(
                                14,
                                sliderHeight * 0.25
                            ),
                            weight: .heavy,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        Color(
                            red: 82 / 255,
                            green: 57 / 255,
                            blue: 131 / 255
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                    sliderTrack(
                        width: geometry.size.width,
                        horizontalInset: horizontalInset,
                        filledWidth:
                            availableWidth *
                            CGFloat(normalizedValue)
                    )
                }

                sliderThumb(
                    size: thumbSize
                )
                .position(
                    x: thumbX,
                    y: sliderHeight * 0.73
                )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true

                        updateValue(
                            xPosition: gesture.location.x,
                            totalWidth: geometry.size.width,
                            thumbSize: thumbSize
                        )
                    }
                    .onEnded { gesture in
                        updateValue(
                            xPosition: gesture.location.x,
                            totalWidth: geometry.size.width,
                            thumbSize: thumbSize
                        )

                        isDragging = false
                    }
            )
        }
        .frame(height: 72)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(formattedValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                setValue(value + step)

            case .decrement:
                setValue(value - step)

            @unknown default:
                break
            }
        }
    }

    private var formattedValue: String {
        if step.rounded() == step {
            return String(Int(value.rounded()))
        }

        return String(
            format: "%.1f",
            value
        )
    }

    private func sliderTrack(
        width: CGFloat,
        horizontalInset: CGFloat,
        filledWidth: CGFloat
    ) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(
                    Color(
                        red: 31 / 255,
                        green: 31 / 255,
                        blue: 44 / 255
                    )
                )
                .frame(height: 5)

            Capsule()
                .fill(Color.white)
                .frame(
                    width: max(filledWidth, 0),
                    height: 5
                )
        }
        .frame(
            width: max(
                width - horizontalInset * 2,
                1
            )
        )
    }

    private func sliderThumb(
        size: CGFloat
    ) -> some View {
        Image(systemName: "heart.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.white)
            .shadow(
                color: Color.black.opacity(
                    isDragging ? 0.5 : 0.3
                ),
                radius: isDragging ? 4 : 2,
                x: 0,
                y: 1
            )
            .scaleEffect(
                isDragging ? 1.12 : 1
            )
            .animation(
                .easeOut(duration: 0.12),
                value: isDragging
            )
            .frame(
                width: size,
                height: size
            )
    }

    private func updateValue(
        xPosition: CGFloat,
        totalWidth: CGFloat,
        thumbSize: CGFloat
    ) {
        let availableWidth = max(
            totalWidth - thumbSize,
            1
        )

        let adjustedPosition = min(
            max(
                xPosition - thumbSize / 2,
                0
            ),
            availableWidth
        )

        let percentage = Double(
            adjustedPosition / availableWidth
        )

        let rawValue =
            range.lowerBound +
            percentage *
            (range.upperBound - range.lowerBound)

        setValue(rawValue)
    }

    private func setValue(
        _ newValue: Double
    ) {
        guard step > 0 else {
            value = min(
                max(newValue, range.lowerBound),
                range.upperBound
            )

            return
        }

        let numberOfSteps =
            ((newValue - range.lowerBound) / step)
            .rounded()

        let steppedValue =
            range.lowerBound +
            numberOfSteps * step

        value = min(
            max(
                steppedValue,
                range.lowerBound
            ),
            range.upperBound
        )
    }
}
