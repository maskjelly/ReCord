import AVFoundation
import CoreGraphics
import Foundation

enum ExportPreset: String, Codable, CaseIterable, Identifiable {
    case fullHD

    var id: String { rawValue }

    var title: String { "1080p" }
    var detail: String { "1920×1080 H.264" }
    var requiresPro: Bool { false }

    func options(for tier: LicenseTier) -> ExportOptions {
        let watermark = tier == .free
        let zoomRampMultiplier = ReCordStorage.zoomRampMultiplier
        let zoomSmoothingWindow = ReCordStorage.zoomSmoothingWindow
        let cameraSmoothingWindow = ReCordStorage.cameraSmoothingWindow
        return ExportOptions(
            outputSize: CGSize(width: 1920, height: 1080),
            codec: .h264,
            bitrate: 16_000_000,
            includeWatermark: watermark,
            followMouse: true,
            frameRate: 60,
            zoomRampMultiplier: zoomRampMultiplier,
            zoomSmoothingWindow: zoomSmoothingWindow,
            cameraSmoothingWindow: cameraSmoothingWindow
        )
    }
}
