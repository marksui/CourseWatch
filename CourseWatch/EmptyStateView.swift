import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let primaryButtonTitle: String
    let secondaryButtonTitle: String?
    let primaryAction: () -> Void
    let secondaryAction: (() -> Void)?

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

            HStack(spacing: 10) {
                Button(primaryButtonTitle) {
                    primaryAction()
                }

                if let secondaryButtonTitle, let secondaryAction {
                    Button(secondaryButtonTitle) {
                        secondaryAction()
                    }
                }
            }
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
