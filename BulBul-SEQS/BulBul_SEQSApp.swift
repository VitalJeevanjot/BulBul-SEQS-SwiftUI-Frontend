//
//  BulBul_SEQSApp.swift
//  BulBul-SEQS
//
//  Created by Jeevanjot Singh on 26/05/26.
//

import Amplify
import Authenticator
import AWSAPIPlugin
import AWSCognitoAuthPlugin
import SwiftUI

@main
struct BulBul_SEQSApp: App {
    init() {
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSAPIPlugin())
            try Amplify.configure(with: .amplifyOutputs)
        } catch {
            print("Unable to configure Amplify \(error)")
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
