//
//  PKCE.swift
//  BulBul-SEQS
//
//  Created by Jeevanjot Singh on 14/06/26.
//

import Foundation
import CryptoKit

struct PKCE {
    let verifier: String
    let challenge: String
    
    static func make() -> PKCE {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        
        let verifier = Data(bytes).base64URLEncodedString()
        
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(digest).base64URLEncodedString()
        
        return PKCE(verifier: verifier, challenge: challenge)
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
