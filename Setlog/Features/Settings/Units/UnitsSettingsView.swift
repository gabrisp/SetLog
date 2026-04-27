import SwiftUI

struct UnitsSettingsView: View {

    @State private var viewModel = UnitsSettingsViewModel()

    var body: some View {
        Form {
            Section("Weight") {
                Picker("Unit", selection: $viewModel.preferredWeightUnit) {
                    Text("kg").tag("kg")
                    Text("lb").tag("lb")
                }
                .pickerStyle(.segmented)
            }

            Section("Distance") {
                Picker("Unit", selection: $viewModel.preferredDistanceUnit) {
                    Text("km").tag("km")
                    Text("mi").tag("mi")
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("Units")
        .navigationBarTitleDisplayMode(.inline)
    }
}
