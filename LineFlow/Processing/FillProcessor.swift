import UIKit

final class FillProcessor {

    func fill(from image: UIImage, gapDistance: Double = 12.0) -> FillResult {
        guard let sourceBitmap = ImageBitmap(image: image) else {
            return FillResult(image: image, size: image.size)
        }

        let closedBitmap = ContourPostProcessor.closeContourGaps(
            in: sourceBitmap,
            maxDistance: gapDistance
        )

        let resultBitmap = FillBuilder.buildFill(from: closedBitmap)

        guard let resultImage = resultBitmap.toUIImage(scale: image.scale) else {
            return FillResult(image: image, size: image.size)
        }

        return FillResult(
            image: resultImage,
            size: image.size
        )
    }

    func makeBinaryImage(from image: UIImage) -> UIImage? {
        guard let bitmap = ImageBitmap(image: image) else {
            return nil
        }

        let binary = BinarizationProcessor.adaptiveThresholdBitmap(
            from: bitmap,
            windowRadius: 3,
            offset: 0.05
        )

        return binary.toUIImage(scale: image.scale)
    }

    func makeSkeletonPreview(from image: UIImage) -> UIImage? {
        guard let sourceBitmap = ImageBitmap(image: image) else {
            return nil
        }

        let binaryBitmap = BinarizationProcessor.adaptiveThresholdBitmap(
            from: sourceBitmap,
            windowRadius: 3,
            offset: 0.05
        )

        let cleanedBitmap = ContourPostProcessor.removeShortConnectedComponents(
            from: binaryBitmap,
            minLength: 10
        )

        let skeletonBitmap = Skeletonizer.skeletonizeGuoHall(
            from: cleanedBitmap
        )

        return skeletonBitmap.toUIImage(scale: image.scale)
    }

    func applySkeletonEdits(
        to image: UIImage,
        strokes: [SkeletonStroke]
    ) -> UIImage? {
        ImageEditingProcessor.applySkeletonEdits(to: image, strokes: strokes)
    }

    func removeFilledRegion(
        from image: UIImage,
        at point: CGPoint
    ) -> UIImage? {
        ImageEditingProcessor.removeFilledRegion(from: image, at: point)
    }
}
