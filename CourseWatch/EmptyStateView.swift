import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Button(title == "Set up Canvas" ? "Open Settings" : "Refresh") {
                action()
            }
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

