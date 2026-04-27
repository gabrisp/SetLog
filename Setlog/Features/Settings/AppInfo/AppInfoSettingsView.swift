import SwiftUI

struct AppInfoSettingsView: View {

    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"

    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: "\(version) (\(build))")
            }
            // TODO: Acknowledgements, open source licenses
        }
        .navigationTitle("App Info")
        .navigationBarTitleDisplayMode(.inline)
    }
}
