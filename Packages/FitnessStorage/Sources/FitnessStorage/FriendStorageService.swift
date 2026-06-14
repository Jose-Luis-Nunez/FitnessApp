import Foundation
import os
import SwiftData
import FitnessCore
import Factory

private let logger = Logger(subsystem: "FitnessStorage", category: "FriendStorageService")

/// Implements `FriendStoring` backed by `FriendModel` in SwiftData.
///
/// Upsert is keyed by normalised name (lowercased, whitespace-trimmed) so
/// re-importing for the same friend replaces their snapshot in-place without
/// creating duplicates.
@Observable
@MainActor
public final class FriendStorageService: FriendStoring {
    public private(set) var friends: [Friend] = []

    // Retain the CONTAINER, not just its mainContext — `mainContext` does not
    // strongly hold its container, so storing only the context lets a
    // caller-owned container deallocate and the store vanish under us. We derive
    // the container from the injected context (`.container`) to keep the
    // `modelContext:` init signature unchanged.
    @ObservationIgnored private let modelContainer: ModelContainer
    @ObservationIgnored private var modelContext: ModelContext { modelContainer.mainContext }

    public init(modelContext: ModelContext? = nil) {
        self.modelContainer = modelContext?.container ?? Container.shared.modelContainer()
        reload()
    }

    @discardableResult
    public func upsertFriend(name: String, envelopeJSON: String, workoutName: String) throws -> Friend {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = trimmedName.lowercased()

        let descriptor = FetchDescriptor<FriendModel>()
        let all = try modelContext.fetch(descriptor)
        let existing = all.first { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key }

        if let model = existing {
            model.envelopeJSON = envelopeJSON
            model.workoutName = workoutName
            try modelContext.save()
            reload()
            return model.toDomain()
        } else {
            let model = FriendModel(
                id: UUID(),
                name: trimmedName,
                addedAt: Date(),
                envelopeJSON: envelopeJSON,
                workoutName: workoutName
            )
            modelContext.insert(model)
            try modelContext.save()
            reload()
            return model.toDomain()
        }
    }

    public func deleteFriend(id: UUID) {
        do {
            let descriptor = FetchDescriptor<FriendModel>()
            let all = try modelContext.fetch(descriptor)
            guard let model = all.first(where: { $0.id == id }) else { return }
            modelContext.delete(model)
            try modelContext.save()
            reload()
        } catch {
            logger.error("Failed to delete friend \(id, privacy: .public): \(error, privacy: .public)")
        }
    }

    public func loadEnvelope(for friendId: UUID) throws -> WorkoutShareEnvelope {
        let descriptor = FetchDescriptor<FriendModel>()
        let all = try modelContext.fetch(descriptor)
        guard let model = all.first(where: { $0.id == friendId }) else {
            throw WorkoutShareError.schemaMismatch(detail: "Friend not found: \(friendId)")
        }
        guard let data = model.envelopeJSON.data(using: .utf8) else {
            throw WorkoutShareError.invalidJSON
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WorkoutShareEnvelope.self, from: data)
    }

    private func reload() {
        do {
            let descriptor = FetchDescriptor<FriendModel>(
                sortBy: [SortDescriptor(\.addedAt)]
            )
            friends = try modelContext.fetch(descriptor).map { $0.toDomain() }
        } catch {
            logger.error("Failed to reload friends: \(error, privacy: .public)")
        }
    }
}
