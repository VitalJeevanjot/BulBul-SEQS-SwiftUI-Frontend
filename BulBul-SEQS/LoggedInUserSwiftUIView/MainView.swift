//
//  LoggedInUserView.swift
//  BulBul-SEQS
//
//  Created by Jeevanjot Singh on 14/06/26.
//

import SwiftUI

import Foundation

import AuthenticationServices

struct MainView: View {
    @Environment(\.webAuthenticationSession) var webAuthSession
    @State var hmrcAuthError: HMRCAuthPromptError?

    var body: some View {
        Button {
            Task {
                await AuthenticateWithHMRC()
            }
        } label: {
            Text("Auth it")
        }
        .alert(item: $hmrcAuthError) { error in
            Alert(
                title: Text("MTD Authentication Error"),
                message: Text("\(error.code)\n\(error.description)"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#Preview {
    MainView()
}
