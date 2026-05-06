import CoreData
import Foundation

@MainActor
final class CoreDataStatsRepository: StatsRepositoryProtocol {

    private struct JoinedSet {
        let savedExerciseID: UUID
        let savedExerciseName: String
        let workoutSessionID: UUID
        let createdAt: Date
        let reps: Int
        let weightKg: Double
        let isWarmup: Bool
    }

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchExerciseSummaries(range: ExerciseStatsRange) async throws -> [ExerciseStatsSummaryDTO] {
        let joined = try fetchJoinedSets(startDate: range.startDate())
        guard !joined.isEmpty else { return [] }

        let now = Date()
        let trendStart = Calendar.current.date(byAdding: .day, value: -30, to: now)
        let trendPrevStart = Calendar.current.date(byAdding: .day, value: -60, to: now)

        let grouped = Dictionary(grouping: joined, by: { $0.savedExerciseID })
        var summaries: [ExerciseStatsSummaryDTO] = []

        for (savedExerciseID, rows) in grouped {
            let name = rows.first?.savedExerciseName ?? "Exercise"
            let nonWarmup = rows.filter { !$0.isWarmup }
            let setCount = nonWarmup.count
            let sessionCount = Set(nonWarmup.map { $0.workoutSessionID }).count
            let totalVolume = nonWarmup.reduce(0) { $0 + ($1.weightKg * Double($1.reps)) }
            let bestSetWeight = nonWarmup.map(\.weightKg).max() ?? 0
            let bestE1RM = nonWarmup.map { e1rm(weight: $0.weightKg, reps: $0.reps) }.max() ?? 0
            let lastUsedAt = rows.map(\.createdAt).max()

            let recent = nonWarmup.filter { row in
                guard let trendStart else { return false }
                return row.createdAt >= trendStart
            }
            let previous = nonWarmup.filter { row in
                guard let trendStart, let trendPrevStart else { return false }
                return row.createdAt >= trendPrevStart && row.createdAt < trendStart
            }
            let recentAvg = recent.isEmpty ? 0 : recent.map { e1rm(weight: $0.weightKg, reps: $0.reps) }.reduce(0, +) / Double(recent.count)
            let prevAvg = previous.isEmpty ? 0 : previous.map { e1rm(weight: $0.weightKg, reps: $0.reps) }.reduce(0, +) / Double(previous.count)

            summaries.append(
                ExerciseStatsSummaryDTO(
                    savedExerciseID: savedExerciseID,
                    name: name,
                    lastUsedAt: lastUsedAt,
                    sessionCount: sessionCount,
                    setCount: setCount,
                    totalVolume: totalVolume,
                    bestSetWeight: bestSetWeight,
                    bestE1RM: bestE1RM,
                    trendE1RM30d: recentAvg - prevAvg
                )
            )
        }

        return summaries.sorted { lhs, rhs in
            if lhs.lastUsedAt == rhs.lastUsedAt {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return (lhs.lastUsedAt ?? .distantPast) > (rhs.lastUsedAt ?? .distantPast)
        }
    }

    func fetchExerciseTimeline(
        savedExerciseID: UUID,
        range: ExerciseStatsRange,
        bucket: ExerciseStatsBucket
    ) async throws -> [ExerciseTimelinePointDTO] {
        let joined = try fetchJoinedSets(startDate: range.startDate())
            .filter { $0.savedExerciseID == savedExerciseID }
            .filter { !$0.isWarmup }

        guard !joined.isEmpty else { return [] }

        let grouped = Dictionary(grouping: joined) { row in
            bucketStart(for: row.createdAt, bucket: bucket)
        }

        return grouped
            .map { date, rows in
                ExerciseTimelinePointDTO(
                    savedExerciseID: savedExerciseID,
                    bucketStart: date,
                    totalVolume: rows.reduce(0) { $0 + ($1.weightKg * Double($1.reps)) },
                    totalReps: rows.reduce(0) { $0 + $1.reps },
                    maxWeight: rows.map(\.weightKg).max() ?? 0,
                    bestE1RM: rows.map { e1rm(weight: $0.weightKg, reps: $0.reps) }.max() ?? 0,
                    setCount: rows.count
                )
            }
            .sorted { $0.bucketStart < $1.bucketStart }
    }

    func fetchExercisePRs(savedExerciseID: UUID) async throws -> ExercisePRsDTO? {
        let joined = try fetchJoinedSets(startDate: nil)
            .filter { $0.savedExerciseID == savedExerciseID }
            .filter { !$0.isWarmup }

        guard !joined.isEmpty else { return nil }

        let bestWeightRow = joined.max { $0.weightKg < $1.weightKg }
        let bestE1RMRow = joined.max { e1rm(weight: $0.weightKg, reps: $0.reps) < e1rm(weight: $1.weightKg, reps: $1.reps) }

        let bySession = Dictionary(grouping: joined, by: { $0.workoutSessionID })
        let sessionVolumes: [(date: Date, volume: Double)] = bySession.values.compactMap { rows in
            guard let date = rows.map(\.createdAt).max() else { return nil }
            let volume = rows.reduce(0) { $0 + ($1.weightKg * Double($1.reps)) }
            return (date, volume)
        }
        let bestSession = sessionVolumes.max { $0.volume < $1.volume }

        return ExercisePRsDTO(
            savedExerciseID: savedExerciseID,
            bestWeight: bestWeightRow?.weightKg ?? 0,
            bestWeightDate: bestWeightRow?.createdAt,
            bestE1RM: bestE1RMRow.map { e1rm(weight: $0.weightKg, reps: $0.reps) } ?? 0,
            bestE1RMDate: bestE1RMRow?.createdAt,
            bestSessionVolume: bestSession?.volume ?? 0,
            bestSessionVolumeDate: bestSession?.date
        )
    }

    private func fetchJoinedSets(startDate: Date?) throws -> [JoinedSet] {
        let savedRequest = SavedExercise.fetchRequest()
        let savedExercises = try context.fetch(savedRequest)
        let savedNameByID: [UUID: String] = Dictionary(
            uniqueKeysWithValues: savedExercises.compactMap { item in
                guard let id = item.id else { return nil }
                return (id, item.name ?? "Exercise")
            }
        )

        let exerciseRequest = ExerciseEntry.fetchRequest()
        exerciseRequest.predicate = NSPredicate(format: "savedExerciseID != nil")
        let exercises = try context.fetch(exerciseRequest)

        var savedByExerciseID: [UUID: UUID] = [:]
        var sessionByExerciseID: [UUID: UUID] = [:]
        for entry in exercises {
            guard let exerciseID = entry.id,
                  let savedID = entry.savedExerciseID,
                  let sessionID = entry.workoutSessionID else {
                continue
            }
            savedByExerciseID[exerciseID] = savedID
            sessionByExerciseID[exerciseID] = sessionID
        }

        let setRequest = WorkoutSet.fetchRequest()
        if let startDate {
            setRequest.predicate = NSPredicate(format: "createdAt >= %@", startDate as CVarArg)
        }
        let sets = try context.fetch(setRequest)

        return sets.compactMap { set in
            guard let exerciseID = set.exerciseEntryID,
                  let savedID = savedByExerciseID[exerciseID],
                  let sessionID = sessionByExerciseID[exerciseID],
                  let createdAt = set.createdAt else {
                return nil
            }

            let name = savedNameByID[savedID] ?? "Exercise"
            let reps = Int(set.reps)
            let weight = convertToKg(value: set.weight, unit: set.unit ?? "kg")
            return JoinedSet(
                savedExerciseID: savedID,
                savedExerciseName: name,
                workoutSessionID: sessionID,
                createdAt: createdAt,
                reps: max(0, reps),
                weightKg: max(0, weight),
                isWarmup: set.isWarmup
            )
        }
    }

    private func bucketStart(for date: Date, bucket: ExerciseStatsBucket) -> Date {
        let calendar = Calendar.current
        switch bucket {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return calendar.date(from: components) ?? calendar.startOfDay(for: date)
        case .month:
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? calendar.startOfDay(for: date)
        }
    }

    private func convertToKg(value: Double, unit: String) -> Double {
        let normalized = unit
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized == "lb" || normalized == "lbs" {
            return value * 0.45359237
        }
        return value
    }

    private func e1rm(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }
}
