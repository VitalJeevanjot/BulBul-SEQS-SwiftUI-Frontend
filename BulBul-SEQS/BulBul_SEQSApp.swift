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
import SwiftData
import SwiftUI

@main
struct BulBul_SEQSApp: App {
    private let modelContainer: ModelContainer

    init() {
        modelContainer = Self.makeModelContainer()

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
                .modelContainer(modelContainer)
#if os(macOS)
                .frame(minWidth: 420, minHeight: 640)
#endif
        }
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            HMRCUserProfile.self,
            StoredBusiness.self,
        ])
        let configuration = ModelConfiguration(
            "HMRCBusinessStore",
            schema: schema,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Unable to create the SwiftData store: \(error)")
        }
    }
}
