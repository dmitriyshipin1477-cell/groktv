import SwiftUI

/// Dismissible error banner shown at the top of the chat screen.
struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.yellow)

            Text(message)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Color.white)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Dismiss", action: onDismiss)
                .font(Theme.labelFont)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.errorBackground)
                .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ErrorBannerView(message: "Invalid API key (401).", onDismiss: {})
        .padding(80)
        .background(Color.black)
}
