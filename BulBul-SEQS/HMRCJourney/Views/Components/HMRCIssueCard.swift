import SwiftUI

struct HMRCIssueCard: View {
    let issue: HMRCJourneyIssue

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 6) {
                Text(issue.title)
                    .font(.subheadline.weight(.bold))
                Text(issue.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if issue.code != nil || issue.statusCode != nil {
                    HStack(spacing: 8) {
                        if let code = issue.code {
                            Text(code)
                        }
                        if let statusCode = issue.statusCode {
                            Text("HTTP \(statusCode)")
                        }
                    }
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(.orange)
                }

                if let correlationID = issue.correlationID {
                    Text("Reference: \(correlationID)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
