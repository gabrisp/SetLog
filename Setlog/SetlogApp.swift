import SwiftUI

@main
struct SetlogApp: App {

    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView(userPreferencesService: environment.userPreferencesService)
                .environment(environment)
        }
    }
}
