import Foundation

@Observable
final class UnitsSettingsViewModel {
    var preferredWeightUnit: String = "kg"   // "kg" or "lb"
    var preferredDistanceUnit: String = "km" // "km" or "mi"

    func save() {
        // TODO: Persist via userPreferencesService
    }
}
