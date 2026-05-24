import AVFoundation
import CoreGraphics
import Foundation

enum ExportPreset: String, Codable, CaseIterable, Identifiable {
    case fullHD
    case ultraHD
    case vertical
    case square

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullHD: return "1080p"
        case .ultraHD: return "4K"
        case .vertical: return "Vertical"
        case .square: return "Square"
        }
    }

    var detail: String {
        switch self {
        case .fullHD: return "1920x1080 H.264"
        case .ultraHD: return "3840x2160 HEVC"
        case .vertical: return "1080x1920 H.264"
        case .square: return "1080x1080 H.264"
        }
    }

    var requiresPro: Bool {
        self == .ultraHD
    }

    func options(for tier: LicenseTier) -> ExportOptions {
        let watermark = tier == .free
        switch self {
        case .fullHD:
            return ExportOptions(outputSize: CGSize(width: 1920, height: 1080), codec: .h264, bitrate: 16_000_000, includeWatermark: watermark, followMouse: true, frameRate: 60)
        case .ultraHD:
            return ExportOptions(outputSize: CGSize(width: 3840, height: 2160), codec: .hevc, bitrate: 45_000_000, includeWatermark: watermark, followMouse: true, frameRate: 60)
        case .vertical:
            return ExportOptions(outputSize: CGSize(width: 1080, height: 1920), codec: .h264, bitrate: 18_000_000, includeWatermark: watermark, followMouse: true, frameRate: 60)
        case .square:
            return ExportOptions(outputSize: CGSize(width: 1080, height: 1080), codec: .h264, bitrate: 12_000_000, includeWatermark: watermark, followMouse: true, frameRate: 60)
        }
    }
}
