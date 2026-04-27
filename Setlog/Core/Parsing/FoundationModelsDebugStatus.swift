import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct FoundationModelsDebugStatus {
    var frameworkPresent: Bool
    var runtimeSupported: Bool
    var modelAvailable: Bool
    var availabilityDescription: String
    var currentLocaleIdentifier: String
    var supportsCurrentLocale: Bool
    var supportedLanguagesPreview: String

    static func probe() -> FoundationModelsDebugStatus {
#if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel.default
            let locale = Locale.current
            let langs = model.supportedLanguages.map { String(describing: $0) }.sorted()
            let preview: String
            if langs.isEmpty {
                preview = "none"
            } else {
                let head = langs.prefix(8).joined(separator: ", ")
                preview = langs.count > 8 ? "\(head), ..." : head
            }
            return FoundationModelsDebugStatus(
                frameworkPresent: true,
                runtimeSupported: true,
                modelAvailable: model.isAvailable,
                availabilityDescription: String(describing: model.availability),
                currentLocaleIdentifier: locale.identifier,
                supportsCurrentLocale: model.supportsLocale(locale),
                supportedLanguagesPreview: preview
            )
        } else {
            return FoundationModelsDebugStatus(
                frameworkPresent: true,
                runtimeSupported: false,
                modelAvailable: false,
                availabilityDescription: "OS below iOS 26",
                currentLocaleIdentifier: Locale.current.identifier,
                supportsCurrentLocale: false,
                supportedLanguagesPreview: "n/a"
            )
        }
#else
        return FoundationModelsDebugStatus(
            frameworkPresent: false,
            runtimeSupported: false,
            modelAvailable: false,
            availabilityDescription: "FoundationModels framework not linked",
            currentLocaleIdentifier: Locale.current.identifier,
            supportsCurrentLocale: false,
            supportedLanguagesPreview: "n/a"
        )
#endif
    }
}
