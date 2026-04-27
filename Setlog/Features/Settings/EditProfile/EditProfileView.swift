import SwiftUI

struct EditProfileView: View {

    @State private var viewModel = EditProfileViewModel()

    var body: some View {
        Form {
            Section("Name") {
                TextField("Display Name", text: $viewModel.displayName)
            }
            // TODO: Avatar image picker
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save", action: viewModel.save)
            }
        }
    }
}
