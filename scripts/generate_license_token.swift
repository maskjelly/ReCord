#!/usr/bin/env swift
import CryptoKit
import Foundation

struct SignedLicensePayload: Codable {
    var licenseID: String
    var email: String
    var tier: String
    var issuedAt: Date
    var expiresAt: Date?
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

func usage() -> Never {
    print("""
    Usage:
      scripts/generate_license_token.swift keypair
      LICENSE_PRIVATE_KEY_B64=... scripts/generate_license_token.swift token <email> [pro] [expires-iso8601-or-never]
    """)
    exit(1)
}

let args = CommandLine.arguments
guard args.count >= 2 else { usage() }

switch args[1] {
case "keypair":
    let privateKey = Curve25519.Signing.PrivateKey()
    print("PRIVATE KEY base64, keep secret:")
    print(privateKey.rawRepresentation.base64EncodedString())
    print("PUBLIC KEY base64, paste into LicenseTokenVerifier.productionPublicKeyBase64:")
    print(privateKey.publicKey.rawRepresentation.base64EncodedString())

case "token":
    guard args.count >= 3,
          let privateKeyBase64 = ProcessInfo.processInfo.environment["LICENSE_PRIVATE_KEY_B64"],
          let privateKeyData = Data(base64Encoded: privateKeyBase64) else {
        usage()
    }
    let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
    let email = args[2]
    let tier = args.count >= 4 ? args[3] : "pro"
    let expiresAt: Date?
    if args.count >= 5, args[4] != "never" {
        expiresAt = ISO8601DateFormatter().date(from: args[4])
    } else {
        expiresAt = nil
    }

    let payload = SignedLicensePayload(
        licenseID: UUID().uuidString,
        email: email,
        tier: tier,
        issuedAt: Date(),
        expiresAt: expiresAt
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let payloadData = try encoder.encode(payload)
    let signature = try privateKey.signature(for: payloadData)
    print("\(payloadData.base64URLEncodedString()).\(signature.base64URLEncodedString())")

default:
    usage()
}
