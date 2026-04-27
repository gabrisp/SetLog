import SwiftUI

struct SettingsFlowView: View {

    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.settingsPath) {
            SettingsView()
                .navigationDestination(for: SettingsRoute.self) { route in
                    switch route {
                    case .editProfile:
                        EditProfileView()
                    case .units:
                        UnitsSettingsView()
                    case .subscription:
                        SubscriptionSettingsView()
                    case .privacy:
                        PrivacySettingsView()
                    case .appInfo:
                        AppInfoSettingsView()
                    }
                }
        }
    }
}
