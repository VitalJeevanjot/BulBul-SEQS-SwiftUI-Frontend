import SwiftUI

struct BusinessesListView: View {
    let businesses: [StoredBusiness]
    let namespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your businesses")
                        .font(.title2.weight(.bold))
                    Text("Select a business to see its HMRC details")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(businesses.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(.indigo.opacity(0.1), in: Capsule())
            }

            LazyVStack(spacing: 12) {
                ForEach(businesses) { business in
                    NavigationLink {
                        BusinessDetailView(business: business)
#if os(iOS)
                            .navigationTransition(.zoom(sourceID: business.businessID, in: namespace))
#endif
                    } label: {
                        BusinessRowCard(business: business)
#if os(iOS)
                            .matchedTransitionSource(id: business.businessID, in: namespace)
#endif
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("business-\(business.businessID)")
                }
            }
        }
    }
}
