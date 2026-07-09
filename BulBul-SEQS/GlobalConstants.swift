//
//  GloabalConstants.swift
//  BulBul-SEQS
//
//  Created by Jeevanjot Singh on 14/06/26.
//

import Foundation

let testing = true

struct HMRCConfiguration {
    let clientID: String
    let authURL: URL
    let redirectURI: String
    let redirectScheme: String
}

enum AppConfig {
    // Load public, app-bundled HMRC configuration from a local plist.
    // Do not put confidential secrets in this file.
    private static let envVars: [String: Any] = loadPlist(named: "environment_vars")

    private static func loadPlist(named name: String) -> [String: Any] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    private static func value(for key: String) -> String? {
        guard let value = envVars[key] as? String, !value.isEmpty else {
            return nil
        }
        return value
    }

    static var hmrc: HMRCConfiguration? {
        let authURLKey = testing ? "HMRC_AUTH_URL_TEST" : "HMRC_AUTH_URL_PROD"
        guard let clientID = value(for: "HMRC_CLIENT_ID"),
              let authURLValue = value(for: authURLKey),
              let authURL = URL(string: authURLValue),
              let redirectURI = value(for: "HMRC_REDIRECT_URI"),
              let redirectScheme = value(for: "HMRC_REDIRECT_SCHEME") else {
            return nil
        }

        return HMRCConfiguration(
            clientID: clientID,
            authURL: authURL,
            redirectURI: redirectURI,
            redirectScheme: redirectScheme
        )
    }
}
