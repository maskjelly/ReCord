# ReCord Distribution Plan

ReCord should ship as a direct-download, notarized macOS app. It should not target the Mac App Store because full cursor tracking depends on `CGEventTap`, which requires Accessibility permission and does not work reliably in sandboxed apps.

## Recommended Channel

- Direct download from the ReCord website.
- Payment/license handling through LemonSqueezy, Paddle, Stripe, or a small custom license service.
- Notarized `.dmg` containing `ReCord.app`.

## App Sandbox

Do not enable App Sandbox for the full product.

Required capabilities are user-approved through TCC permissions instead:

- Screen Recording: `CGRequestScreenCaptureAccess` / `ScreenCaptureKit`
- Accessibility: `AXIsProcessTrustedWithOptions` / `CGEventTap`
- Microphone: `AVCaptureDevice.requestAccess(for: .audio)`

## Signing And Notarization

Use an Apple Developer ID Application certificate.

```sh
codesign --force --deep --options runtime --sign "Developer ID Application: YOUR NAME (TEAMID)" ReCord.app
xcrun notarytool submit ReCord.dmg --keychain-profile "notary-profile" --wait
xcrun stapler staple ReCord.dmg
```

Use hardened runtime. Avoid unnecessary entitlements. If a future helper tool or XPC service is added, it must be signed and notarized with the same team.

## Free Tier

Default proposal:

- 1080p export max.
- ReCord watermark.
- Same core recording/editor experience so users can feel the product value.

## Paid Tier

- 4K HEVC export.
- No watermark.
- Advanced cursor styling.
- Custom export presets.
- Future advanced timeline controls.

## License Security

The app verifies signed offline license tokens with Ed25519. Before launch:

- Generate a keypair with `scripts/generate_license_token.swift keypair`.
- Keep the private key secret.
- Paste the public key into `LicenseTokenVerifier.productionPublicKeyBase64`, or set `RECORD_LICENSE_PUBLIC_KEY_B64` only for internal/dev builds.
- Generate customer tokens with `LICENSE_PRIVATE_KEY_B64=... scripts/generate_license_token.swift token customer@example.com pro never`.
- Optional online activation/deactivation endpoint.

Client-side licensing can always be bypassed. The goal is to keep honest users honest without making the app brittle.
