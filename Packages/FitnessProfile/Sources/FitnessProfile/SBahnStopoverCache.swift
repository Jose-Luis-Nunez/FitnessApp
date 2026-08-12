import Foundation

/// Bounds repeated trip-detail calls during manual refreshes without turning
/// volatile departure data into a long-lived source of truth.
actor SBahnStopoverCache {
    private struct Entry: Sendable {
        let stopovers: [TransitStopover]
        let storedAt: Date
    }

    struct Lookup: Sendable {
        let stopoversByTripId: [String: [TransitStopover]]
        let missingTripIds: [String]
    }

    private let timeToLive: TimeInterval
    private let capacity: Int
    private var entries: [String: Entry] = [:]
    private var insertionOrder: [String] = []

    init(timeToLive: TimeInterval = 60, capacity: Int = 64) {
        self.timeToLive = timeToLive
        self.capacity = max(capacity, 1)
    }

    func lookup(tripIds: [String], now: Date = Date()) -> Lookup {
        removeExpiredEntries(now: now)

        var cached: [String: [TransitStopover]] = [:]
        var missing: [String] = []
        for tripId in tripIds {
            if let entry = entries[tripId] {
                cached[tripId] = entry.stopovers
            } else {
                missing.append(tripId)
            }
        }
        return Lookup(stopoversByTripId: cached, missingTripIds: missing)
    }

    func store(
        stopoversByTripId: [String: [TransitStopover]],
        now: Date = Date()
    ) {
        removeExpiredEntries(now: now)

        for (tripId, stopovers) in stopoversByTripId {
            insertionOrder.removeAll { $0 == tripId }
            entries[tripId] = Entry(stopovers: stopovers, storedAt: now)
            insertionOrder.append(tripId)
        }

        while entries.count > capacity, let oldestTripId = insertionOrder.first {
            insertionOrder.removeFirst()
            entries.removeValue(forKey: oldestTripId)
        }
    }

    private func removeExpiredEntries(now: Date) {
        let expiredTripIds = entries.compactMap { tripId, entry in
            now.timeIntervalSince(entry.storedAt) >= timeToLive ? tripId : nil
        }
        guard !expiredTripIds.isEmpty else { return }

        let expired = Set(expiredTripIds)
        for tripId in expired {
            entries.removeValue(forKey: tripId)
        }
        insertionOrder.removeAll { expired.contains($0) }
    }
}
