import Foundation

@Observable
@MainActor
public final class SBahnDeparturesViewModel {

    // MARK: - Endpoint Configuration

    public struct Endpoint: Equatable, Sendable {
        public let stopId: String
        public let label: String

        public init(stopId: String, label: String) {
            self.stopId = stopId
            self.label = label
        }
    }

    /// Default endpoints for the S-Bahn-Card: S+U Alexanderplatz → S Ostkreuz.
    public static let defaultOrigin = Endpoint(stopId: "900100003", label: "Alexanderplatz")
    public static let defaultDestination = Endpoint(stopId: "900120003", label: "Ostkreuz")

    /// 60s TTL on app resume — same as Tram. Avoids hammering the API on
    /// quick app-switches.
    public static let foregroundStaleThreshold: TimeInterval = 60

    // MARK: - Observable State

    public private(set) var isExpanded: Bool = false
    public private(set) var departures: [SBahnDeparture] = []
    public var isLoading: Bool = false
    public var errorMessage: String?
    public var lastUpdated: Date?
    public var isReversed: Bool = false
    /// True when the displayed departures come from the cache (no live
    /// confirmation since app start, or last refresh failed but a cache hit
    /// was used as fallback).
    public var isStale: Bool = false
    /// ID of the row whose detail panel is currently expanded; `nil` = none.
    public var expandedDetailRowID: String?

    // MARK: - Dependencies

    private let service: BVGSBahnServicing
    private let cache: SBahnDeparturesCaching
    private let origin: Endpoint
    private let destination: Endpoint
    private let maxResults: Int
    private let scheduler = RefreshScheduler()

    // MARK: - Init

    public init(
        service: BVGSBahnServicing = BVGSBahnService(),
        cache: SBahnDeparturesCaching = SBahnDeparturesCache(),
        origin: Endpoint = SBahnDeparturesViewModel.defaultOrigin,
        destination: Endpoint = SBahnDeparturesViewModel.defaultDestination,
        maxResults: Int = 4
    ) {
        self.service = service
        self.cache = cache
        self.origin = origin
        self.destination = destination
        self.maxResults = maxResults
        loadCachedSnapshot()
    }

    // MARK: - Derived

    public var fromLabel: String { isReversed ? destination.label : origin.label }
    public var toLabel: String { isReversed ? origin.label : destination.label }
    public var fromStopId: String { isReversed ? destination.stopId : origin.stopId }
    public var toStopId: String { isReversed ? origin.stopId : destination.stopId }

    // MARK: - Intents

    public func toggleExpanded() {
        isExpanded.toggle()
        if isExpanded {
            scheduleRefresh()
        }
    }

    public func swap() {
        isReversed.toggle()
        loadCachedSnapshot()
        errorMessage = nil
        scheduleRefresh()
    }

    public func toggleDetailExpansion(rowID: String) {
        expandedDetailRowID = (expandedDetailRowID == rowID) ? nil : rowID
    }

    public func refresh() async {
        isLoading = true
        // `defer` guarantees the loading flag is cleared on every exit path —
        // including `Task.isCancelled` early returns — so the spinner can't
        // get orphaned when the scheduler cancels an in-flight task.
        defer { isLoading = false }
        do {
            let result = try await service.fetchSBahnRoute(
                fromStopId: fromStopId,
                toStopId: toStopId,
                maxResults: maxResults
            )
            guard !Task.isCancelled else { return }
            departures = result
            errorMessage = nil
            lastUpdated = Date()
            isStale = false
            scheduler.reportSuccess()
            cache.save(fromStopId: fromStopId, toStopId: toStopId, departures: result)
        } catch is CancellationError {
            return
        } catch {
            handleRefreshFailure(error)
            scheduler.reportFailure()
        }
    }

    /// Called when host scene transitions back to `.active`. Refresh only if
    /// expanded AND no recent failure. Backoff logic lives in
    /// `RefreshScheduler`.
    public func onBecameActive() {
        guard isExpanded else { return }
        if scheduler.shouldSkipAutoRefresh(staleThreshold: Self.foregroundStaleThreshold) {
            return
        }
        let isStaleData = lastUpdated.map { Date().timeIntervalSince($0) > Self.foregroundStaleThreshold } ?? true
        if isStaleData {
            scheduleRefresh()
        }
    }

    private func scheduleRefresh() {
        scheduler.schedule { [weak self] in
            await self?.refresh()
        }
    }

    // MARK: - Cache helpers

    private func loadCachedSnapshot() {
        guard let cached = cache.load(fromStopId: fromStopId, toStopId: toStopId) else {
            return
        }
        departures = cached.departures
        lastUpdated = cached.savedAt
        isStale = true
    }

    private func handleRefreshFailure(_ error: Error) {
        if let cached = cache.load(fromStopId: fromStopId, toStopId: toStopId) {
            departures = cached.departures
            lastUpdated = cached.savedAt
            isStale = true
            errorMessage = nil
            return
        }
        if let sbahnError = error as? BVGSBahnError {
            errorMessage = sbahnError.errorDescription ?? "Failed to load."
        } else {
            errorMessage = "Failed to load."
        }
    }

    // MARK: - Formatting

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "HH:mm"
        return f
    }()

    public func formattedTime(for date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    public var formattedLastUpdated: String? {
        guard let lastUpdated else { return nil }
        return formattedTime(for: lastUpdated)
    }
}
