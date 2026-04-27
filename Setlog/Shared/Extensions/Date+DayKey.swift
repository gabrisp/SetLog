import Foundation

extension Date {

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    var dayKey: String {
        Date.dayKeyFormatter.string(from: self)
    }

    static var todayDayKey: String {
        Date().dayKey
    }

    static func date(fromDayKey key: String) -> Date? {
        dayKeyFormatter.date(from: key)
    }
}
