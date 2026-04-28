import SwiftUI

@main
struct SetlogApp: App {

    @State private var environment = AppEnvironment()

    init() {
        print("[BOOT] SetlogApp init")
    }

    var body: some Scene {
        WindowGroup {
            RootView(userPreferencesService: environment.userPreferencesService)
                .environment(environment)
                .environment(environment.router)
                .environment(\.appEnvironment, environment)
        }
    }
}
