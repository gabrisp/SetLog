import Foundation

enum CustomTab: String, CaseIterable {
    case calendar = "Calendar"
    case stats = "Stats"

    var symbol: String {
        switch self {
        case .calendar:
            return "calendar"
        case .stats:
            return "cellularbars"
        }
    }

    var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}
