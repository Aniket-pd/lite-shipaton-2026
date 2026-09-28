import Foundation
import Darwin

/// Creation accepts secure websites only; WebKit never needs a blanket ATS exception.
enum WebsiteURL {
    nonisolated static func normalized(_ input: String) throws -> URL {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw ValidationError.empty }
        guard !value.contains(where: { $0.isWhitespace || $0.isNewline }),
              !value.contains("\\"),
              !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              !value.hasPrefix("/"),
              hasValidPercentEscapes(value) else {
            throw ValidationError.invalid
        }

        let candidate: String
        let schemePattern = "^[a-zA-Z][a-zA-Z0-9+.-]*:"
        if value.range(of: schemePattern, options: .regularExpression) != nil {
            let scheme = value.prefix { $0 != ":" }.lowercased()
            if scheme == "http" { throw ValidationError.insecure }
            if scheme == "https" {
                guard value.lowercased().hasPrefix("https://") else {
                    throw ValidationError.invalid
                }
                candidate = value
            } else if value.range(
                of: "^[a-zA-Z0-9.-]+:[0-9]{1,5}([/?#]|$)",
                options: .regularExpression
            ) != nil {
                // A pasted domain may include a port without including a scheme.
                candidate = "https://" + value
            } else {
                throw ValidationError.unsupportedScheme
            }
        } else {
            candidate = "https://" + value
        }

        guard var components = URLComponents(string: candidate),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty else {
            throw ValidationError.invalid
        }
        guard components.user == nil, components.password == nil else {
            throw ValidationError.credentials
        }
        guard let url = components.url, let asciiHost = url.host,
              isValidHost(asciiHost, bracketedLiteral: host.hasPrefix("[")),
              components.port.map({ (1...65_535).contains($0) }) ?? true else {
            throw ValidationError.invalid
        }
        components.scheme = "https"
        components.host = host.lowercased()
        guard let normalized = components.url else { throw ValidationError.invalid }
        return normalized
    }

    nonisolated private static func isValidHost(_ host: String, bracketedLiteral: Bool) -> Bool {
        if bracketedLiteral || host.contains(":") {
            var address = in6_addr()
            let literal = host.hasPrefix("[") && host.hasSuffix("]")
                ? String(host.dropFirst().dropLast()) : host
            return literal.withCString { inet_pton(AF_INET6, $0, &address) } == 1
        }
        let domain = host.hasSuffix(".") ? String(host.dropLast()) : host
        guard !domain.isEmpty, domain.utf8.count <= 253 else { return false }
        return domain.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { label in
            !label.isEmpty && label.utf8.count <= 63 &&
            label.first != "-" && label.last != "-" &&
            label.utf8.allSatisfy { byte in
                (65...90).contains(byte) || (97...122).contains(byte) ||
                (48...57).contains(byte) || byte == 45
            }
        }
    }

    nonisolated private static func hasValidPercentEscapes(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        for index in bytes.indices where bytes[index] == 37 {
            guard index + 2 < bytes.count,
                  isHex(bytes[index + 1]), isHex(bytes[index + 2]) else { return false }
        }
        return true
    }

    nonisolated private static func isHex(_ byte: UInt8) -> Bool {
        (48...57).contains(byte) || (65...70).contains(byte) || (97...102).contains(byte)
    }

    enum ValidationError: LocalizedError {
        case empty
        case invalid
        case insecure
        case unsupportedScheme
        case credentials

        nonisolated var errorDescription: String? {
            switch self {
            case .empty:
                "Enter a website address, such as example.com."
            case .invalid:
                "Enter a valid website address, such as https://example.com."
            case .insecure:
                "Lite requires a secure website. Use an address that starts with https://."
            case .unsupportedScheme:
                "Use a website address that starts with https://."
            case .credentials:
                "Remove the username and password from this address. You can sign in after creating your Lite App."
            }
        }
    }
}
