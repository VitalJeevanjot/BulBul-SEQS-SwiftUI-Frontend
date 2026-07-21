import Amplify
import AWSPluginsCore
import CryptoKit
import Darwin
import Foundation
import Security

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
import SystemConfiguration
#endif

enum FraudPreventionHeaders {
    static func serializedForCurrentRequest() async throws -> String {
        let deviceID = try DeviceIdentifierStore.deviceID()
        let user = try? await Amplify.Auth.getCurrentUser()
        let now = Date()
        let localIPs = DeviceNetworkDetails.localIPAddresses()
        let visual = await DeviceVisualDetails.collect()
        let signInDate = await authenticationDate() ?? now
        let userReference = user?.userId ?? "unknown-user"
        let mfaReference = SHA256.hash(data: Data("\(deviceID):\(userReference)".utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        var headers: [String: String] = [
            "Gov-Client-Connection-Method": connectionMethod,
            "Gov-Client-Device-ID": deviceID,
            "Gov-Client-Local-IPs": localIPs.map(percentEncode).joined(separator: ","),
            "Gov-Client-Local-IPs-Timestamp": millisecondTimestamp(now),
            "Gov-Client-Multi-Factor": "type=TOTP&timestamp=\(percentEncode(minuteTimestamp(signInDate)))&unique-reference=\(mfaReference)",
            "Gov-Client-Public-IP": "",
            "Gov-Client-Public-IP-Timestamp": "",
            "Gov-Client-Public-Port": "",
            "Gov-Client-Screens": visual.screens,
            "Gov-Client-Timezone": timezone,
            "Gov-Client-User-Agent": userAgent,
            "Gov-Client-User-IDs": userIDs(applicationUserID: userReference),
            "Gov-Client-Window-Size": visual.windowSize,
            "Gov-Vendor-Forwarded": "",
            "Gov-Vendor-License-IDs": "",
            "Gov-Vendor-Product-Name": "",
            "Gov-Vendor-Public-IP": "",
            "Gov-Vendor-Version": "bulbul-seqs=\(percentEncode(appVersion))",
        ]

#if os(macOS)
        headers["Gov-Client-MAC-Addresses"] = DeviceNetworkDetails.macAddresses()
            .map(percentEncode)
            .joined(separator: ",")
#endif

        let data = try JSONSerialization.data(withJSONObject: headers, options: [.sortedKeys])
        guard let value = String(data: data, encoding: .utf8) else {
            throw FraudHeaderError.serializationFailed
        }
        return value
    }

    private static var connectionMethod: String {
#if os(iOS)
        "MOBILE_APP_VIA_SERVER"
#else
        "DESKTOP_APP_VIA_SERVER"
#endif
    }

    private static func userIDs(applicationUserID: String) -> String {
#if os(iOS)
        "bulbul-seqs=\(percentEncode(applicationUserID))"
#else
        "os=\(percentEncode(NSUserName()))&bulbul-seqs=\(percentEncode(applicationUserID))"
#endif
    }

    private static var userAgent: String {
        let system = ProcessInfo.processInfo.operatingSystemVersion
        let version = "\(system.majorVersion).\(system.minorVersion).\(system.patchVersion)"
#if os(iOS)
        let family = "iOS"
#else
        let family = "MacOS"
#endif
        return "os-family=\(family)&os-version=\(percentEncode(version))&device-manufacturer=Apple&device-model=\(percentEncode(DeviceSystemDetails.modelIdentifier))"
    }

    private static var timezone: String {
        let seconds = TimeZone.current.secondsFromGMT()
        let sign = seconds >= 0 ? "+" : "-"
        let absolute = abs(seconds)
        return String(format: "UTC%@%02d:%02d", sign, absolute / 3600, (absolute % 3600) / 60)
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    private static func authenticationDate() async -> Date? {
        guard let session = try? await Amplify.Auth.fetchAuthSession(),
              let provider = session as? AuthCognitoTokensProvider,
              let tokens = try? provider.getCognitoTokens().get()
        else { return nil }

        let pieces = tokens.idToken.split(separator: ".")
        guard pieces.count > 1 else { return nil }
        var payload = String(pieces[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let authTime = object["auth_time"] as? TimeInterval
        else { return nil }
        return Date(timeIntervalSince1970: authTime)
    }

    private static func millisecondTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private static func minuteTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
        return formatter.string(from: date)
    }

    private static func percentEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
    }
}

private enum FraudHeaderError: LocalizedError {
    case keychain(OSStatus)
    case serializationFailed

    var errorDescription: String? {
        switch self {
        case .keychain(let status): "The device identifier could not be stored securely (Keychain status \(status))."
        case .serializationFailed: "The fraud-prevention headers could not be encoded."
        }
    }
}

private enum DeviceIdentifierStore {
    private static let service = "com.jsv.bulbul-seqs.fraud-prevention"
    private static let account = "gov-client-device-id"

    static func deviceID() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess,
           let data = result as? Data,
           let existing = String(data: data, encoding: .utf8),
           UUID(uuidString: existing) != nil {
            return existing
        }
        guard status == errSecItemNotFound || status == errSecSuccess else {
            throw FraudHeaderError.keychain(status)
        }

        let generated = UUID().uuidString.lowercased()
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(generated.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw FraudHeaderError.keychain(addStatus) }
        return generated
    }
}

private enum DeviceNetworkDetails {
    static func localIPAddresses() -> [String] {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return [] }
        defer { freeifaddrs(pointer) }

        var addresses = Set<String>()
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let address = entry.pointee.ifa_addr else { continue }
            let family = Int32(address.pointee.sa_family)
            guard family == AF_INET || family == AF_INET6 else { continue }
            guard entry.pointee.ifa_flags & UInt32(IFF_LOOPBACK) == 0 else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let length = socklen_t(address.pointee.sa_len)
            if getnameinfo(address, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                let value = String(cString: host).components(separatedBy: "%").first ?? ""
                if !value.isEmpty { addresses.insert(value) }
            }
        }
        return addresses.sorted()
    }

#if os(macOS)
    static func macAddresses() -> [String] {
        let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? []
        return Array(Set(interfaces.compactMap { SCNetworkInterfaceGetHardwareAddressString($0) as String? })).sorted()
    }
#endif
}

private enum DeviceSystemDetails {
    static var modelIdentifier: String {
        var size = 0
        let key: String
#if os(iOS)
        key = "hw.machine"
#else
        key = "hw.model"
#endif
        guard sysctlbyname(key, nil, &size, nil, 0) == 0 else { return "Apple-device" }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname(key, &value, &size, nil, 0) == 0 else { return "Apple-device" }
        return String(cString: value)
    }
}

private struct DeviceVisualDetails: Sendable {
    let screens: String
    let windowSize: String

    @MainActor
    static func collect() -> DeviceVisualDetails {
#if os(iOS)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let screenValues = scenes.map { scene in
            let screen = scene.screen
            let width = Int(screen.bounds.width * screen.nativeScale)
            let height = Int(screen.bounds.height * screen.nativeScale)
            return "width=\(width)&height=\(height)&scaling-factor=\(screen.nativeScale)&colour-depth=32"
        }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.flatMap(\.windows).first
        let scale = window?.screen.nativeScale ?? 1
        let width = Int((window?.bounds.width ?? 1) * scale)
        let height = Int((window?.bounds.height ?? 1) * scale)
#else
        let screenValues = NSScreen.screens.map { screen in
            let width = Int(screen.frame.width * screen.backingScaleFactor)
            let height = Int(screen.frame.height * screen.backingScaleFactor)
            let depth = screen.depth.bitsPerPixel
            return "width=\(width)&height=\(height)&scaling-factor=\(screen.backingScaleFactor)&colour-depth=\(depth)"
        }
        let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first
        let scale = window?.backingScaleFactor ?? 1
        let width = Int((window?.frame.width ?? 1) * scale)
        let height = Int((window?.frame.height ?? 1) * scale)
#endif
        return DeviceVisualDetails(
            screens: screenValues.joined(separator: ","),
            windowSize: "width=\(max(width, 1))&height=\(max(height, 1))"
        )
    }
}
