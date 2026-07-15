import SwiftUI
import UIKit
import ZixflowDataPipelines

struct ContentView: View {
    @State private var status = "Ready"
    @State private var deviceToken: String?

    private let tokenPollTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("API key ends with …\(String(Config.apiKey.suffix(6))). Replace Config.apiKey before testing.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(status)
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Device Token")
                            .font(.headline)
                        Text(deviceToken ?? "Not yet registered")
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                        Button("Copy device token") {
                            guard let token = deviceToken else {
                                status = "No device token registered yet"
                                return
                            }
                            UIPasteboard.general.string = token
                            status = "Device token copied to clipboard"
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }

                    Group {
                        action("Identify") {
                            Zixflow.shared.identify(
                                userId: "user@example.com",
                                traits: [
                                    "first_name": "John",
                                    "last_name": "Doe",
                                    "email": "user@example.com",
                                    "plan": "premium"
                                ]
                            )
                            status = "identify sent"
                        }

                        action("Track") {
                            Zixflow.shared.track(
                                name: "Product Purchased",
                                properties: [
                                    "product_id": "123",
                                    "product_name": "Widget",
                                    "price": 29.99,
                                    "currency": "USD"
                                ]
                            )
                            status = "track sent"
                        }

                        action("Screen") {
                            Zixflow.shared.screen(
                                title: "Product Detail",
                                properties: [
                                    "product_id": "123",
                                    "category": "Electronics"
                                ]
                            )
                            status = "screen sent"
                        }

                        action("Set profile attributes") {
                            Zixflow.shared.setProfileAttributes([
                                "age": 30,
                                "subscription_status": "active"
                            ])
                            status = "profile attributes set"
                        }

                        action("Set device attributes") {
                            Zixflow.shared.setDeviceAttributes([
                                "store_region": "us-west",
                                "preferred_language": "en"
                            ])
                            status = "device attributes set"
                        }

                        action("Alias") {
                            Zixflow.shared.alias(newId: "new-user-id")
                            status = "alias sent"
                        }

                        action("Flush") {
                            Zixflow.shared.flush {
                                status = "flush completed"
                            }
                        }

                        action("Show device token") {
                            if let token = Zixflow.shared.registeredDeviceToken {
                                status = "token: \(token)"
                            } else {
                                status = "Device token not yet registered"
                            }
                        }

                        action("Clear identify") {
                            Zixflow.shared.clearIdentify()
                            status = "clearIdentify()"
                        }

                        action("Reset") {
                            Zixflow.shared.reset()
                            status = "reset()"
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Zixflow iOS SDK")
            .onAppear {
                Zixflow.shared.screen(title: "Home")
                deviceToken = Zixflow.shared.registeredDeviceToken
            }
            .onReceive(tokenPollTimer) { _ in
                if deviceToken == nil {
                    deviceToken = Zixflow.shared.registeredDeviceToken
                }
            }
        }
    }

    private func action(_ title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }
}

#Preview {
    ContentView()
}
