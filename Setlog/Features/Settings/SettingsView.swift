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

            if let viewModel {
                Section("AI Debug") {
                    debugRow("FM framework present", value: boolLabel(viewModel.fmDebugStatus.frameworkPresent))
                    debugRow("FM runtime supported", value: boolLabel(viewModel.fmDebugStatus.runtimeSupported))
                    debugRow("FM model available", value: boolLabel(viewModel.fmDebugStatus.modelAvailable))
                    debugRow("Current locale", value: viewModel.fmDebugStatus.currentLocaleIdentifier)
                    debugRow("Locale supported", value: boolLabel(viewModel.fmDebugStatus.supportsCurrentLocale))
                    debugRow("FM availability", value: viewModel.fmDebugStatus.availabilityDescription)
                    debugRow("Supported languages", value: viewModel.fmDebugStatus.supportedLanguagesPreview)
                    debugRow("Interpreter mode", value: "Foundation Models first, local fallback")
                    debugRow("Last AFM outcome", value: viewModel.fmDiagnostics.lastOutcome)
                    debugRow("Last AFM path", value: viewModel.fmDiagnostics.lastPath)
                    if let reason = viewModel.fmDiagnostics.lastReason, !reason.isEmpty {
                        debugRow("Last AFM reason", value: reason)
                    }
                    if let at = viewModel.fmDiagnostics.lastAttemptAt {
                        debugRow("Last AFM attempt", value: dateLabel(at))
                    }
                    if !viewModel.fmDiagnostics.lastInputPreview.isEmpty {
                        debugRow("Last input", value: viewModel.fmDiagnostics.lastInputPreview)
                    }

                    Button("Refresh AFM status") {
                        viewModel.refreshAIFeaturesDebug()
                    }
                }
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

    private func debugRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func boolLabel(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    private func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
