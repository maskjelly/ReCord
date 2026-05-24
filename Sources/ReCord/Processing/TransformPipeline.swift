import AppKit
import CoreImage
import CoreVideo
import Foundation

final class TransformPipeline {
    private let context: CIContext
    private let cursorRenderer: CursorRenderer
    private var watermarkCache: [String: CIImage] = [:]

    init(context: CIContext = CIContext(options: [.cacheIntermediates: false])) {
        self.context = context
        self.cursorRenderer = CursorRenderer(ringScale: 1.0)
    }

    func render(
        sourceBuffer: CVPixelBuffer,
        state: ZoomFrameState,
        outputBuffer: CVPixelBuffer,
        outputSize: CGSize,
        backgroundColor: CIColor = CIColor(red: 0.06, green: 0.065, blue: 0.08),
        includeWatermark: Bool = false
    ) {
        let source = CIImage(cvPixelBuffer: sourceBuffer)
        let sourceHeight = source.extent.height

        // Cursor events are stored in top-left screen coordinates; Core Image uses bottom-left.
        let ciViewport = CGRect(
            x: state.viewport.minX,
            y: sourceHeight - state.viewport.maxY,
            width: state.viewport.width,
            height: state.viewport.height
        ).intersection(source.extent)

        let cropped = source
            .cropped(to: ciViewport)
            .transformed(by: CGAffineTransform(translationX: -ciViewport.minX, y: -ciViewport.minY))

        let scaleX = outputSize.width / max(ciViewport.width, 1)
        let scaleY = outputSize.height / max(ciViewport.height, 1)
        var transformed = cropped.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        transformed = transformed.cropped(to: CGRect(origin: .zero, size: outputSize))

        let background = CIImage(color: backgroundColor).cropped(to: CGRect(origin: .zero, size: outputSize))
        var composed = transformed.composited(over: background)

        if let cursor = cursorRenderer.image(for: state, viewport: state.viewport, outputSize: outputSize) {
            composed = cursor.composited(over: composed)
        }

        if includeWatermark {
            composed = watermark(for: outputSize).composited(over: composed)
        }

        context.render(composed, to: outputBuffer)
    }

    private func watermark(for outputSize: CGSize) -> CIImage {
        let key = "\(Int(outputSize.width))x\(Int(outputSize.height))"
        if let cached = watermarkCache[key] { return cached }

        let text = "Made with ReCord"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: max(18, outputSize.width / 80), weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.82)
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        let padding = max(14, outputSize.width / 140)
        let canvasSize = CGSize(width: textSize.width + padding * 2, height: textSize.height + padding)
        let image = NSImage(size: canvasSize)
        image.lockFocus()
        NSColor.black.withAlphaComponent(0.32).setFill()
        NSBezierPath(roundedRect: CGRect(origin: .zero, size: canvasSize), xRadius: canvasSize.height / 2, yRadius: canvasSize.height / 2).fill()
        attributed.draw(at: CGPoint(x: padding, y: padding / 2))
        image.unlockFocus()

        let ciImage = CIImage(data: image.tiffRepresentation ?? Data()) ?? CIImage(color: .clear).cropped(to: CGRect(origin: .zero, size: canvasSize))
        let translated = ciImage.transformed(
            by: CGAffineTransform(
                translationX: outputSize.width - canvasSize.width - padding,
                y: padding
            )
        )
        watermarkCache[key] = translated
        return translated
    }
}
