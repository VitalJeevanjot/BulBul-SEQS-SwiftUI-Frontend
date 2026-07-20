import SwiftUI

struct UserHeaderView: View {
    let displayName: String
    let signOut: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color.accentColor)

            Text(displayName)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            Button("Logout", systemImage: "rectangle.portrait.and.arrow.right", action: signOut)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("logout-button")
        }
        .padding(12)
        .background(Color.hmrcCardBackground, in: RoundedRectangle(cornerRadius: 12))
    }
}
