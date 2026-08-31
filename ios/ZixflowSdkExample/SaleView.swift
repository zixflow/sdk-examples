import SwiftUI

/// Demo screen opened via the `zixflowdemo://sale` push notification deeplink
/// (either tapping the notification body or an action button).
struct SaleView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("🔥")
                .font(.system(size: 48))
            Text("Flash Sale — 70% OFF!")
                .font(.title2)
                .bold()
                .multilineTextAlignment(.center)
            Text("Opened via push notification deeplink (zixflowdemo://sale).")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Back") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    SaleView()
}
