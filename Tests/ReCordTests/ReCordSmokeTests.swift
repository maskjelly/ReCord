import XCTest
import AVFoundation
import CryptoKit
@testable import ReCord

final class ReCordSmokeTests: XCTestCase {
    func testSanity() {
        XCTAssertTrue(true)
    }

    func testSignedLicenseVerifierAcceptsValidToken() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let payload = SignedLicensePayload(
            licenseID: UUID().uuidString,
            email: "founder@example.com",
            tier: .pro,
            issuedAt: Date(),
            expiresAt: nil
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let payloadData = try encoder.encode(payload)
        let signature = try privateKey.signature(for: payloadData)
        let token = "\(payloadData.base64URLEncodedString()).\(signature.base64URLEncodedString())"

        let verified = try LicenseTokenVerifier.verify(
            token: token,
            publicKeyBase64: privateKey.publicKey.rawRepresentation.base64EncodedString()
        )

        XCTAssertEqual(verified.email, payload.email)
        XCTAssertEqual(verified.tier, .pro)
    }

    func testAutomaticKeyframesRespectClickSpacing() {
        let events = [
            CursorEvent(timestamp: 0.1, location: Point2D(x: 10, y: 10), kind: .leftDown),
            CursorEvent(timestamp: 0.5, location: Point2D(x: 20, y: 20), kind: .leftDown),
            CursorEvent(timestamp: 2.2, location: Point2D(x: 30, y: 30), kind: .leftDown)
        ]

        let keyframes = generateAutomaticKeyframes(from: events)

        XCTAssertEqual(keyframes.count, 2)
        XCTAssertEqual(keyframes[0].source, .automatic)
        XCTAssertEqual(keyframes[1].position, Point2D(x: 30, y: 30))
    }

    func testZoomCameraFollowsCursorDuringActiveZoom() {
        let events = [
            CursorEvent(timestamp: 0.0, location: Point2D(x: 100, y: 100), kind: .move),
            CursorEvent(timestamp: 0.8, location: Point2D(x: 600, y: 400), kind: .move),
            CursorEvent(timestamp: 1.0, location: Point2D(x: 700, y: 500), kind: .move)
        ]
        let keyframe = ZoomKeyframe(
            timestamp: 0.0,
            position: Point2D(x: 100, y: 100),
            zoom: 1.8,
            duration: 0.3,
            hold: 1.0,
            source: .automatic
        )
        let engine = ZoomEngine(
            displaySize: CGSize(width: 1000, height: 800),
            cursorEvents: events,
            keyframes: [keyframe],
            configuration: .default(
                outputSize: CGSize(width: 1000, height: 800),
                cameraSmoothingWindow: 0.22
            )
        )

        let state = engine.state(at: 0.9)

        XCTAssertGreaterThan(state.cameraCenter.x, 400)
        XCTAssertGreaterThan(state.cameraCenter.y, 250)
        XCTAssertEqual(state.cursorPosition.x, 650, accuracy: 1)
        XCTAssertEqual(state.cursorPosition.y, 450, accuracy: 1)
    }

    func testExportPresetAppliesFreeWatermarkAndPro4K() {
        let freeVertical = ExportPreset.vertical.options(for: .free)
        XCTAssertEqual(freeVertical.outputSize.width, 1080)
        XCTAssertEqual(freeVertical.outputSize.height, 1920)
        XCTAssertTrue(freeVertical.includeWatermark)

        let pro4K = ExportPreset.ultraHD.options(for: .pro)
        XCTAssertEqual(pro4K.outputSize.width, 3840)
        XCTAssertEqual(pro4K.outputSize.height, 2160)
        XCTAssertFalse(pro4K.includeWatermark)
        XCTAssertTrue(ExportPreset.ultraHD.requiresPro)
    }

    func testExportExistingRawWhenRequested() async throws {
        guard let rawPath = ProcessInfo.processInfo.environment["RECORD_EXPORT_TEST_RAW_URL"] else {
            throw XCTSkip("Set RECORD_EXPORT_TEST_RAW_URL to run the real raw-file export smoke test.")
        }

        let duration = Double(ProcessInfo.processInfo.environment["RECORD_EXPORT_TEST_DURATION"] ?? "") ?? 5
        let width = Double(ProcessInfo.processInfo.environment["RECORD_EXPORT_TEST_WIDTH"] ?? "") ?? 640
        let height = Double(ProcessInfo.processInfo.environment["RECORD_EXPORT_TEST_HEIGHT"] ?? "") ?? 360
        let frameRate = Int(ProcessInfo.processInfo.environment["RECORD_EXPORT_TEST_FPS"] ?? "") ?? 30
        let rawURL = URL(fileURLWithPath: rawPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: rawURL.path))

        let session = RecordingSession(
            id: UUID(),
            title: "Export Smoke Test",
            duration: duration,
            displaySize: Size2D(width: 2560, height: 1440),
            rawVideoURL: rawURL,
            cursorEvents: [
                CursorEvent(timestamp: 0, location: Point2D(x: 1280, y: 720), kind: .move),
                CursorEvent(timestamp: min(duration, 1), location: Point2D(x: 1320, y: 720), kind: .move)
            ],
            zoomKeyframes: []
        )
        let output = try await VideoExporter().export(
            session: session,
            options: ExportOptions(
                outputSize: CGSize(width: width, height: height),
                codec: .h264,
                bitrate: width >= 1920 ? 16_000_000 : 2_500_000,
                includeWatermark: false,
                followMouse: true,
                frameRate: frameRate,
                zoomRampMultiplier: 1.5,
                zoomSmoothingWindow: 0.18,
                cameraSmoothingWindow: 0.75
            ),
            progress: { _ in },
            log: { print($0) }
        )
        defer { try? FileManager.default.removeItem(at: output.deletingLastPathComponent()) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        let asset = AVAsset(url: output)
        let exportedDuration = try await asset.load(.duration).seconds
        XCTAssertGreaterThan(exportedDuration, 0)
        XCTAssertLessThan(exportedDuration, duration + 1)
    }
}
