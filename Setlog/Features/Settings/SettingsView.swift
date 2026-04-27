import SwiftUI

struct SettingsView: View {

    @Environment(AppRouter.self) private var router
    @Environment(\.appEnvironment) private var environment

    @State private var viewModel: SettingsViewModel?

    var body: some View {
        List {
            Section {
                NavigationLink(value: SettingsRoute.editProfile) {
                    Label("Edit Profile", systemImage: "person")
                }
                NavigationLink(value: SettingsRoute.units) {
                    Label("Units", systemImage: "ruler")
                }
            }

            Section {
                NavigationLink(value: SettingsRoute.subscription) {
                    Label("Subscription", systemImage: "star")
                }
            }

            Section {
                NavigationLink(value: SettingsRoute.privacy) {
                    Label("Privacy", systemImage: "hand.raised")
                }
                NavigationLink(value: SettingsRoute.appInfo) {
                    Label("App Info", systemImage: "info.circle")
                }
            }

            Section("Development") {
                Button("Clear Recent Items") {
                    viewModel?.clearRecentItems()
                }
                Button("Reset Onboarding") {
                    viewModel?.resetOnboarding()
                }
                .foregroundStyle(.orange)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = SettingsViewModel(
                    userPreferencesService: environment.userPreferencesService,
                    entitlementService: environment.entitlementService
                )
            }
        }
    }
}
