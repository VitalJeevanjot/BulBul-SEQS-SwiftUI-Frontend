import SwiftUI

struct BusinessRowCard: View {
    let business: StoredBusiness

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "briefcase.fill")
                .font(.title3)
                .foregroundStyle(.indigo)
                .frame(width: 48, height: 48)
                .background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 4) {
                Text(business.tradingName ?? "HMRC Business")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(business.businessID)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(business.typeOfBusiness.replacingOccurrences(of: "-", with: " ").capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 8) {
                Image(systemName: business.hasDetails ? "checkmark.icloud.fill" : "exclamationmark.icloud.fill")
                    .foregroundStyle(business.hasDetails ? .green : .orange)
                    .accessibilityLabel(business.hasDetails ? "Saved in iCloud" : "Details unavailable")
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(Color.hmrcCardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.1))
        }
    }
}
