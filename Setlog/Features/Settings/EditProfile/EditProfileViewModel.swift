import Foundation

@Observable
final class EditProfileViewModel {
    var displayName: String = ""
    // TODO: var avatarImage: UIImage? = nil

    func save() {
        // TODO: Persist via userPreferencesService or profileRepository
    }
}
