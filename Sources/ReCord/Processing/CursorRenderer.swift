import AppKit
import CoreImage
import Foundation

final class CursorRenderer {
    private let systemCursor: CIImage
    private let systemCursorHotspot: CGPoint
    private let clickRingImage: CIImage
    private let ringAssetScale: CGFloat

    init(ringScale: CGFloat = 4.0) {
        self.ringAssetScale = ringScale

        let cursor = NSCursor.arrow
        let rawCIImage: CIImage
        let rawPixelSize: CGSize
        if let tiff = cursor.image.tiffRepresentation,
           let ci = CIImage(data: tiff) {
            rawCIImage = ci
            rawPixelSize = ci.extent.size
        } else {
            rawPixelSize = CGSize(width: 32, height: 32)
            rawCIImage = CIImage(color: .white).cropped(to: CGRect(origin: .zero, size: rawPixelSize))
        }

        let pointSize = cursor.image.size
        let pixelScale: CGFloat = pointSize.width > 0 ? rawPixelSize.width / pointSize.width : 1.0

        // Normalize cursor to point dimensions so displayScale maps 1:1 at 1080p
        let normalizeTransform = CGAffineTransform(scaleX: 1.0 / pixelScale, y: 1.0 / pixelScale)
        self.systemCursor = rawCIImage.transformed(by: normalizeTransform)
        self.systemCursorHotspot = CGPoint(
            x: cursor.hotSpot.x,
            y: cursor.hotSpot.y
        )

        self.clickRingImage = CursorRenderer.makeClickRingImage(scale: ringScale)
    }

    func image(for state: ZoomFrameState, viewport: CGRect, outputSize: CGSize) -> CIImage? {
        guard state.cursorVisible else { return nil }

        let localX = (state.cursorPosition.x - viewport.minX) / viewport.width * outputSize.width
        let localY = outputSize.height - ((state.cursorPosition.y - viewport.minY) / viewport.height * outputSize.height)
        let displayScale = max(0.9, min(1.8, outputSize.width / 1920))

        let cursorScale = displayScale
        let scaledCursor = systemCursor.transformed(by: CGAffineTransform(scaleX: cursorScale, y: cursorScale))
        let cursor = scaledCursor.transformed(
            by: CGAffineTransform(
                translationX: localX - systemCursorHotspot.x * cursorScale,
                y: localY - systemCursorHotspot.y * cursorScale
            )
        )

        guard state.clickPulse > 0 else { return cursor }

        let ringScale = (1.0 + state.clickPulse * 0.45) * displayScale / ringAssetScale
        let ring = clickRingImage
            .transformed(by: CGAffineTransform(scaleX: ringScale, y: ringScale))
            .transformed(
                by: CGAffineTransform(
                    translationX: localX - 26 * displayScale * (1.0 + state.clickPulse * 0.45),
                    y: localY - 26 * displayScale * (1.0 + state.clickPulse * 0.45)
                )
            )

        return cursor.composited(over: ring)
    }

    private static func makeClickRingImage(scale: CGFloat) -> CIImage {
        let size = CGSize(width: 56 * scale, height: 56 * scale)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSGraphicsContext.current?.shouldAntialias = true
        NSColor.systemBlue.withAlphaComponent(0.22).setStroke()
        let ring = NSBezierPath(ovalIn: CGRect(x: 6 * scale, y: 6 * scale, width: 44 * scale, height: 44 * scale))
        ring.lineWidth = 3 * scale
        ring.stroke()
        image.unlockFocus()
        return CIImage(data: image.tiffRepresentation ?? Data()) ?? CIImage(color: .clear).cropped(to: CGRect(origin: .zero, size: size))
    }
}
