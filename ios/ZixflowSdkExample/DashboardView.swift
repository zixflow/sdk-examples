import SwiftUI

/// Demo screen opened via the `zixflowdemo://dashboard` push notification deeplink
/// (either tapping the notification body or an action button).
struct DashboardView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("📊")
                .font(.system(size: 48))
            Text("Your Dashboard")
                .font(.title2)
                .bold()
                .multilineTextAlignment(.center)
            Text("Opened via push notification deeplink (zixflowdemo://dashboard).")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Back") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    DashboardView()
}
