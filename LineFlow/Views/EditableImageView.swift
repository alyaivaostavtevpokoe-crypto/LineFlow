//
//  EditableImageView.swift
//  LineFlow
//
//  Created by macbook Алиса on 21/4/26.
//
import SwiftUI

struct EditableImageView: View {
    @Binding var image: UIImage?
    let isEditingEnabled: Bool
    let stageTitle: String

    let committedStrokes: [SkeletonStroke]
    let activeTool: SkeletonEditingTool
    let brushSize: CGFloat
    let onStrokeFinished: (SkeletonStroke) -> Void

    let onTapInImage: ((CGPoint) -> Void)?

    @State private var currentStrokePoints: [CGPoint] = []

    var body: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size

            ZStack {
                checkerboardBackground

                if let image {
                    let imageRect = fittedImageRect(
                        imageSize: image.size,
                        containerSize: containerSize
                    )

                    ZStack(alignment: .topLeading) {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: imageRect.width, height: imageRect.height)

                        strokesLayer(
                            imageSize: image.size,
                            displaySize: imageRect.size
                        )
                        .frame(width: imageRect.width, height: imageRect.height)
                        .clipped()
                    }
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)

                    stageBadge
                } else {
                    Text("Изображение отсутствует")
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .gesture(mainGesture(containerSize: containerSize))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 540)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(20)
    }

    // MARK: - Основной жест

    private func mainGesture(containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isEditingEnabled, let image else { return }
                guard onTapInImage == nil else { return }

                let imageRect = fittedImageRect(
                    imageSize: image.size,
                    containerSize: containerSize
                )

                guard let point = mapViewPointToImagePoint(
                    value.location,
                    imageRect: imageRect,
                    imageSize: image.size
                ) else { return }

                currentStrokePoints.append(point)
            }
            .onEnded { value in
                guard isEditingEnabled, let image else {
                    currentStrokePoints = []
                    return
                }

                let imageRect = fittedImageRect(
                    imageSize: image.size,
                    containerSize: containerSize
                )

                // режим тапа (этап 6)
                if let onTapInImage {
                    guard let point = mapViewPointToImagePoint(
                        value.location,
                        imageRect: imageRect,
                        imageSize: image.size
                    ) else { return }

                    onTapInImage(point)
                    currentStrokePoints = []
                    return
                }

                let cleaned = deduplicated(points: currentStrokePoints)

                guard !cleaned.isEmpty else {
                    currentStrokePoints = []
                    return
                }

                let stroke = SkeletonStroke(
                    points: cleaned,
                    tool: activeTool,
                    brushSize: brushSize
                )

                onStrokeFinished(stroke)
                currentStrokePoints = []
            }
    }

    // MARK: - Рисование линий

    @ViewBuilder
    private func strokesLayer(
        imageSize: CGSize,
        displaySize: CGSize
    ) -> some View {
        let all = committedStrokes + currentStrokeAsArray()

        ForEach(all) { stroke in
            Path { path in
                let mapped = stroke.points.map {
                    mapImagePointToDisplayPoint(
                        $0,
                        imageSize: imageSize,
                        displaySize: displaySize
                    )
                }

                guard let first = mapped.first else { return }

                path.move(to: first)

                if mapped.count == 1 {
                    path.addLine(to: first)
                } else {
                    for p in mapped.dropFirst() {
                        path.addLine(to: p)
                    }
                }
            }
            .stroke(
                stroke.tool == .draw ? Color.black : Color.white,
                style: StrokeStyle(
                    lineWidth: brushWidth(
                        brushSize: stroke.brushSize,
                        imageSize: imageSize,
                        displaySize: displaySize
                    ),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }

    // MARK: - UI

    private var stageBadge: some View {
        VStack {
            HStack {
                Text(stageTitle)
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)

                Spacer()
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Геометрия

    private func fittedImageRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }

        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        let drawSize: CGSize
        if imageAspect > containerAspect {
            let width = containerSize.width
            let height = width / imageAspect
            drawSize = CGSize(width: width, height: height)
        } else {
            let height = containerSize.height
            let width = height * imageAspect
            drawSize = CGSize(width: width, height: height)
        }

        let origin = CGPoint(
            x: (containerSize.width - drawSize.width) / 2,
            y: (containerSize.height - drawSize.height) / 2
        )

        return CGRect(origin: origin, size: drawSize)
    }

    // MARK: - Координаты

    private func mapViewPointToImagePoint(
        _ point: CGPoint,
        imageRect: CGRect,
        imageSize: CGSize
    ) -> CGPoint? {
        guard imageRect.contains(point) else { return nil }

        let x = (point.x - imageRect.minX) / imageRect.width
        let y = (point.y - imageRect.minY) / imageRect.height

        return CGPoint(
            x: x * imageSize.width,
            y: y * imageSize.height
        )
    }

    private func mapImagePointToDisplayPoint(
        _ point: CGPoint,
        imageSize: CGSize,
        displaySize: CGSize
    ) -> CGPoint {
        let x = point.x / imageSize.width
        let y = point.y / imageSize.height

        return CGPoint(
            x: x * displaySize.width,
            y: y * displaySize.height
        )
    }

    // MARK: - Вспомогательные

    private func currentStrokeAsArray() -> [SkeletonStroke] {
        guard !currentStrokePoints.isEmpty else { return [] }

        return [
            SkeletonStroke(
                points: currentStrokePoints,
                tool: activeTool,
                brushSize: brushSize
            )
        ]
    }

    private func deduplicated(points: [CGPoint]) -> [CGPoint] {
        var result: [CGPoint] = []
        var last: CGPoint?

        for p in points {
            if let last {
                let dx = p.x - last.x
                let dy = p.y - last.y
                if dx*dx + dy*dy < 0.5 { continue }
            }
            result.append(p)
            last = p
        }

        return result
    }

    private func brushWidth(
        brushSize: CGFloat,
        imageSize: CGSize,
        displaySize: CGSize
    ) -> CGFloat {
        guard imageSize.width > 0 else { return brushSize }
        let scale = displaySize.width / imageSize.width
        return max(1, brushSize * scale)
    }

    // MARK: - Фон

    private var checkerboardBackground: some View {
        GeometryReader { geometry in
            let tile: CGFloat = 18
            let columns = Int(geometry.size.width / tile) + 2
            let rows = Int(geometry.size.height / tile) + 2

            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<columns, id: \.self) { column in
                            Rectangle()
                                .fill((row + column).isMultiple(of: 2)
                                      ? Color.white
                                      : Color.gray.opacity(0.15))
                                .frame(width: tile, height: tile)
                        }
                    }
                }
            }
        }
        .cornerRadius(20)
    }
}
