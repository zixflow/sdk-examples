import SwiftUI

@main
struct ZixflowSdkExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var router = NavigationRouter.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(item: $router.activeScreen) { screen in
                    switch screen {
                    case .sale:
                        SaleView()
                    case .dashboard:
                        DashboardView()
                    }
                }
        }
    }
}
