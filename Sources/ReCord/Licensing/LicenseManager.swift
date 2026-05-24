import CryptoKit
import Foundation

enum LicenseTier: String, Codable, CaseIterable, Identifiable {
    case free
    case pro

    var id: String { rawValue }
}

struct FeatureGate {
    var tier: LicenseTier

    var exportOptions: ExportOptions {
        ExportPreset.fullHD.options(for: tier)
    }

    var allows4KExport: Bool { tier == .pro }
    var includesWatermark: Bool { tier == .free }
    var maxRecordingDuration: TimeInterval? { nil }
}

struct SignedLicensePayload: Codable, Equatable {
    var licenseID: String
    var email: String
    var tier: LicenseTier
    var issuedAt: Date
    var expiresAt: Date?
}

enum LicenseTokenVerifier {
    static let productionPublicKeyBase64 = "S3J1yawvKujQuLBt4QHtzh4xbazOAPELTPS40VgK4Qg="

    static func verify(
        token: String,
        publicKeyBase64: String = productionPublicKeyBase64,
        now: Date = Date()
    ) throws -> SignedLicensePayload {
        let parts = token.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".")
        guard parts.count == 2,
              let payloadData = Data(base64URLEncoded: String(parts[0])),
              let signature = Data(base64URLEncoded: String(parts[1])) else {
            throw LicenseError.invalidKey
        }

        let configuredPublicKey = ProcessInfo.processInfo.environment["RECORD_LICENSE_PUBLIC_KEY_B64"] ?? publicKeyBase64
        guard !configuredPublicKey.hasPrefix("REPLACE_WITH"),
              let publicKeyData = Data(base64Encoded: configuredPublicKey) else {
            throw LicenseError.licenseVerifierNotConfigured
        }

        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        guard publicKey.isValidSignature(signature, for: payloadData) else {
            throw LicenseError.invalidSignature
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(SignedLicensePayload.self, from: payloadData)

        if let expiresAt = payload.expiresAt, expiresAt < now {
            throw LicenseError.expired
        }

        return payload
    }
}

final class LicenseManager: ObservableObject {
    @Published private(set) var tier: LicenseTier = .free
    @Published private(set) var licensedEmail: String = ""
    @Published var licenseKey: String = ""

    private var licenseURL: URL {
        ReCordStorage.applicationSupportDirectory.appendingPathComponent("license.json")
    }

    init() {
        load()
    }

    func activate(key: String) throws {
        let payload = try LicenseTokenVerifier.verify(token: key)
        tier = payload.tier
        licensedEmail = payload.email
        licenseKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        try save()
    }

    func deactivate() throws {
        tier = .free
        licensedEmail = ""
        licenseKey = ""
        try save()
    }

    private func save() throws {
        try ReCordStorage.ensureDirectories()
        let payload = StoredLicense(tier: tier, licensedEmail: licensedEmail, licenseToken: licenseKey)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(payload).write(to: licenseURL, options: .atomic)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: licenseURL.path) else { return }
        do {
            let stored = try JSONDecoder().decode(StoredLicense.self, from: Data(contentsOf: licenseURL))
            _ = try LicenseTokenVerifier.verify(token: stored.licenseToken)
            tier = stored.tier
            licensedEmail = stored.licensedEmail
            licenseKey = stored.licenseToken
        } catch {
            tier = .free
            licensedEmail = ""
            licenseKey = ""
        }
    }
}

private struct StoredLicense: Codable {
    var tier: LicenseTier
    var licensedEmail: String
    var licenseToken: String
}

enum LicenseError: LocalizedError {
    case invalidKey
    case invalidSignature
    case expired
    case licenseVerifierNotConfigured

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Invalid license token."
        case .invalidSignature:
            return "This license token is not signed by ReCord."
        case .expired:
            return "This license has expired."
        case .licenseVerifierNotConfigured:
            return "License verification is not configured for this build. Add your production Ed25519 public key before selling Pro licenses."
        }
    }
}

extension Data {
    init?(base64URLEncoded value: String) {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - base64.count % 4
        if padding < 4 {
            base64.append(String(repeating: "=", count: padding))
        }
        self.init(base64Encoded: base64)
    }

    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
