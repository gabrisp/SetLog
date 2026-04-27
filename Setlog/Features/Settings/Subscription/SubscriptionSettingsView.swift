import SwiftUI

struct SubscriptionSettingsView: View {

    @Environment(\.appEnvironment) private var environment
    @State private var viewModel: SubscriptionSettingsViewModel?

    var body: some View {
        let vm = viewModel ?? SubscriptionSettingsViewModel(entitlementService: environment.entitlementService)

        List {
            Section {
                if vm.isPro {
                    Label("Pro Active", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Upgrade to Pro", action: vm.upgrade)
                        .foregroundStyle(Color.accentColor)
                }
            }

            Section("Pro Features") {
                ForEach(vm.proFeatures, id: \.rawValue) { feature in
                    Label(feature.displayName, systemImage: "star")
                }
            }

            Section {
                Button("Restore Purchases", action: vm.restorePurchases)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = SubscriptionSettingsViewModel(entitlementService: environment.entitlementService)
            }
        }
    }
}
