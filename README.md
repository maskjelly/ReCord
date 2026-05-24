# ReCord

ReCord is a native macOS 13+ screen recording app focused on ScreenStudio-style post-processed zooms.

## What Exists

- Native SwiftUI macOS app shell with menu bar item, main editor, settings, recording HUD, and recording library.
- Screen recording via `ScreenCaptureKit` with cursor hidden from the raw capture.
- System audio capture through `ScreenCaptureKit` audio output.
- Microphone recording to a separate AAC file.
- Global cursor tracking through `CGEventTap` for mouse movement and clicks.
- Automatic zoom keyframes generated from click events.
- Manual zoom keyframe creation, deletion, and timeline dragging.
- Live editor overlay that previews the export crop, zoom level, cursor, and click pulse while the recording plays.
- Export presets for 1080p, 4K, vertical 9:16, and square 1:1 output.
- Keyboard commands: `Cmd+Shift+R` toggles recording; `Cmd+Shift+Z` drops a manual zoom marker.
- Post-processing export pipeline using `AVAssetReader`, `Core Image`, custom cursor compositing, and `AVAssetWriter`.
- Free/pro feature gates: free exports include a watermark; Pro enables 4K HEVC and watermark-free exports.
- Signed offline license activation using Ed25519 license tokens.
- Session rename, reveal, and delete actions.

## Build

```sh
swift build
```

## Run

```sh
swift run ReCord
```

You can also run the packaged app:

```sh
open dist/ReCord.app
```

## Use

1. Click `Permissions` and approve Screen Recording, Accessibility, and Microphone in System Settings.
2. Click `Record`.
3. Choose the folder where recordings should be saved.
4. Choose the screen or window to record.
5. Click `Start Recording`.
6. Stop from the floating HUD, toolbar, menu bar item, or `Cmd+Shift+R`.
7. Review the recording, drag zoom markers on the timeline, and use `Cmd+Shift+Z` to add manual zoom markers.
8. Choose an export preset in the inspector and click `Export MP4`.

For real recording, grant these permissions in System Settings:

- Privacy & Security > Screen Recording > ReCord
- Privacy & Security > Accessibility > ReCord
- Privacy & Security > Microphone > ReCord

When running from Swift Package Manager, macOS may show the executable path rather than a polished app name in permission prompts. For launch distribution, create/sign a `.app` bundle as described in `Docs/DISTRIBUTION.md`.

## Current Architecture

- `Capture/ScreenRecorder.swift`: `SCStream` setup and raw `.mov` writing.
- `Capture/CursorTracker.swift`: global mouse event logging.
- `Capture/MicrophoneRecorder.swift`: separate mic capture.
- `Processing/ZoomEngine.swift`: click/manual keyframe camera math and smooth viewport calculation.
- `Processing/TransformPipeline.swift`: frame crop/scale/cursor overlay.
- `Processing/VideoExporter.swift`: raw recording to export pipeline.
- `UI/Editor`: preview, timeline, inspector.
- `Licensing/LicenseManager.swift`: signed free/pro license gating.

## Launch Checklist

- Add the final logo as `Sources/ReCord/Resources/AppIcon.icns` before public distribution. `Config/Info.plist` already points to `AppIcon`.
- Generate a license keypair with `scripts/generate_license_token.swift keypair`.
- Set `LicenseTokenVerifier.productionPublicKeyBase64` to the public key before building, or provide `RECORD_LICENSE_PUBLIC_KEY_B64` in the app environment for internal builds. This workspace already has a launch keypair generated; the private key is stored in `dist/ReCord-license-private-key.txt`.
- Build the app bundle with `scripts/build_release_app.sh`.
- Package the DMG with `scripts/package_dmg.sh`.
- Sign with a Developer ID Application certificate and notarize the DMG before public distribution.

## Future Work

- Add a true Xcode app target if you want App Store-style archive workflows instead of the current SPM bundle script.
- Add user-customizable global hotkeys. Current shortcuts are fixed.
- Add region/window picker UI before recording.
- Add webcam overlay.
- Add keyboard shortcut visualizer.
- Add robust audio drift correction for long recordings.
