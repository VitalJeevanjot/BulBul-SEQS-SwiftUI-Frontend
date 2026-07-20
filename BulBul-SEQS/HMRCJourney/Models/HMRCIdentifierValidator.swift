import Foundation

enum HMRCIdentifierValidator {
    static let ninoPattern = #"^((?!(BG|GB|KN|NK|NT|TN|ZZ)|(D|F|I|Q|U|V)[A-Z]|[A-Z](D|F|I|O|Q|U|V))[A-Z]{2})[0-9]{6}[A-D]$"#
    static let businessIDPattern = #"^X[A-Z0-9]{1}IS[0-9]{11}$"#

    static func normalizedNINO(_ value: String) -> String {
        String(
            value
                .uppercased()
                .filter { $0.isLetter || $0.isNumber }
                .prefix(9)
        )
    }

    static func isValidNINO(_ value: String) -> Bool {
        matches(value, pattern: ninoPattern)
    }

    static func isValidBusinessID(_ value: String) -> Bool {
        matches(value, pattern: businessIDPattern)
    }

    private static func matches(_ value: String, pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}
