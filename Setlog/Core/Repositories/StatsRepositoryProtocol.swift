import Foundation

enum ExerciseStatsRange: Equatable {
    case sevenDays
    case thirtyDays
    case ninetyDays
    case oneYear
    case all

    func startDate(now: Date = Date()) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .sevenDays:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: -30, to: now)
        case .ninetyDays:
            return calendar.date(byAdding: .day, value: -90, to: now)
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: now)
        case .all:
            return nil
        }
    }
}

enum ExerciseStatsBucket {
    case day
    case week
    case month
}

struct ExerciseStatsSummaryDTO {
    var savedExerciseID: UUID
    var name: String
    var lastUsedAt: Date?
    var sessionCount: Int
    var setCount: Int
    var totalVolume: Double
    var bestSetWeight: Double
    var bestE1RM: Double
    var trendE1RM30d: Double
}

struct ExerciseTimelinePointDTO {
    var savedExerciseID: UUID
    var bucketStart: Date
    var totalVolume: Double
    var totalReps: Int
    var maxWeight: Double
    var bestE1RM: Double
    var setCount: Int
}

struct ExercisePRsDTO {
    var savedExerciseID: UUID
    var bestWeight: Double
    var bestWeightDate: Date?
    var bestE1RM: Double
    var bestE1RMDate: Date?
    var bestSessionVolume: Double
    var bestSessionVolumeDate: Date?
}

protocol StatsRepositoryProtocol {
    func fetchExerciseSummaries(range: ExerciseStatsRange) async throws -> [ExerciseStatsSummaryDTO]
    func fetchExerciseTimeline(
        savedExerciseID: UUID,
        range: ExerciseStatsRange,
        bucket: ExerciseStatsBucket
    ) async throws -> [ExerciseTimelinePointDTO]
    func fetchExercisePRs(savedExerciseID: UUID) async throws -> ExercisePRsDTO?
}
