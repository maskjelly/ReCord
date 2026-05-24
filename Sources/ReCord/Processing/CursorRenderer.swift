import AppKit
import CoreImage
import Foundation

final class CursorRenderer {
    private let cursorImage: CIImage
    private let clickRingImage: CIImage
    private let assetScale: CGFloat

    init(scale: CGFloat = 4.0) {
        self.assetScale = scale
        self.cursorImage = CursorRenderer.makeCursorImage(scale: scale)
        self.clickRingImage = CursorRenderer.makeClickRingImage(scale: scale)
    }

    func image(for state: ZoomFrameState, viewport: CGRect, outputSize: CGSize) -> CIImage? {
        guard state.cursorVisible else { return nil }

        let localX = (state.cursorPosition.x - viewport.minX) / viewport.width * outputSize.width
        let localY = outputSize.height - ((state.cursorPosition.y - viewport.minY) / viewport.height * outputSize.height)
        let displayScale = max(0.9, min(1.8, outputSize.width / 1920))
        let cursorScale = displayScale / assetScale

        let scaledCursor = cursorImage.transformed(by: CGAffineTransform(scaleX: cursorScale, y: cursorScale))
        let cursor = scaledCursor.transformed(
            by: CGAffineTransform(
                translationX: localX - 5 * displayScale,
                y: localY - scaledCursor.extent.height + 6 * displayScale
            )
        )

        guard state.clickPulse > 0 else { return cursor }

        let ringScale = (1.0 + state.clickPulse * 0.45) * cursorScale
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

    private static func makeCursorImage(scale: CGFloat) -> CIImage {
        let size = CGSize(width: 42 * scale, height: 56 * scale)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSGraphicsContext.current?.shouldAntialias = true

        NSColor.black.withAlphaComponent(0.28).setFill()
        let shadow = NSBezierPath()
        shadow.move(to: CGPoint(x: 10 * scale, y: 52 * scale))
        shadow.line(to: CGPoint(x: 10 * scale, y: 7 * scale))
        shadow.line(to: CGPoint(x: 37 * scale, y: 33 * scale))
        shadow.line(to: CGPoint(x: 25 * scale, y: 35 * scale))
        shadow.line(to: CGPoint(x: 32 * scale, y: 52 * scale))
        shadow.close()
        shadow.fill()

        NSColor.white.setFill()
        NSColor.black.withAlphaComponent(0.78).setStroke()
        let path = NSBezierPath()
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.lineWidth = 1.8 * scale
        path.move(to: CGPoint(x: 7 * scale, y: 54 * scale))
        path.line(to: CGPoint(x: 7 * scale, y: 8 * scale))
        path.line(to: CGPoint(x: 36 * scale, y: 35 * scale))
        path.line(to: CGPoint(x: 23 * scale, y: 36 * scale))
        path.line(to: CGPoint(x: 30 * scale, y: 53 * scale))
        path.close()
        path.fill()
        path.stroke()

        image.unlockFocus()
        return CIImage(data: image.tiffRepresentation ?? Data()) ?? CIImage(color: .white).cropped(to: CGRect(origin: .zero, size: size))
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
