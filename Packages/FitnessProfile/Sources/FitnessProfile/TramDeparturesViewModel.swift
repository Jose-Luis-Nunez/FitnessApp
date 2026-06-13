import Foundation

@Observable
@MainActor
public final class TramDeparturesViewModel {

    // MARK: - Endpoint Configuration

    public struct Endpoint: Equatable, Sendable {
        public let stopId: String
        public let label: String

        public init(stopId: String, label: String) {
            self.stopId = stopId
            self.label = label
        }
    }

    /// Default line / endpoints for the Blockdammweg ↔ Marktstr. Tram 21 route.
    public static let defaultLine: String = "21"
    public static let defaultOrigin = Endpoint(stopId: "900162504", label: "Blockdammweg")
    public static let defaultDestination = Endpoint(stopId: "900160535", label: "Marktstr.")

    /// When the app comes back to foreground, only re-fetch if the last successful
    /// load is older than this. Avoids hammering the API on quick app-switches.
    public static let foregroundStaleThreshold: TimeInterval = 60

    // MARK: - Observable State

    public private(set) var isExpanded: Bool = false
    public private(set) var departures: [TramDeparture] = []
    public var isLoading: Bool = false
    public var errorMessage: String?
    public var lastUpdated: Date?
    public var isReversed: Bool = false
    /// True when the currently displayed departures come from the cache (no live
    /// confirmation since app start, or last refresh attempt failed but a cache
    /// hit was used as fallback).
    public var isStale: Bool = false

    // MARK: - Dependencies

    private let service: BVGTramServicing
    private let cache: TramDeparturesCaching
    private let line: String
    private let origin: Endpoint
    private let destination: Endpoint
    private let maxResults: Int
    private let scheduler = RefreshScheduler()

    // MARK: - Init

    public init(
        service: BVGTramServicing = BVGTramService(),
        cache: TramDeparturesCaching = TramDeparturesCache(),
        line: String = TramDeparturesViewModel.defaultLine,
        origin: Endpoint = TramDeparturesViewModel.defaultOrigin,
        destination: Endpoint = TramDeparturesViewModel.defaultDestination,
        maxResults: Int = 3
    ) {
        self.service = service
        self.cache = cache
        self.line = line
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
    public var lineName: String { line }

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

    public func refresh() async {
        isLoading = true
        // `defer` guarantees the loading flag is cleared on every exit path —
        // including `Task.isCancelled` early returns — so the spinner can't
        // get orphaned when the scheduler cancels an in-flight task.
        defer { isLoading = false }
        do {
            let result = try await service.fetchDepartures(
                fromStopId: fromStopId,
                directionStopId: toStopId,
                line: line,
                maxResults: maxResults
            )
            guard !Task.isCancelled else { return }
            departures = result
            errorMessage = nil
            lastUpdated = Date()
            isStale = false
            scheduler.reportSuccess()
            cache.save(fromStopId: fromStopId, toStopId: toStopId, line: line, departures: result)
        } catch is CancellationError {
            return
        } catch {
            handleRefreshFailure(error)
            scheduler.reportFailure()
        }
    }

    /// Called when the host scene transitions back to `.active`. Refreshes
    /// only when the card is expanded AND no recent failure — avoids
    /// hammering the network from a tunnel/no-Wi-Fi state on every
    /// foreground. Backoff logic lives in `RefreshScheduler`.
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
        guard let cached = cache.load(fromStopId: fromStopId, toStopId: toStopId, line: line) else {
            return
        }
        departures = cached.departures
        lastUpdated = cached.savedAt
        isStale = true
    }

    private func handleRefreshFailure(_ error: Error) {
        if let cached = cache.load(fromStopId: fromStopId, toStopId: toStopId, line: line) {
            departures = cached.departures
            lastUpdated = cached.savedAt
            isStale = true
            errorMessage = nil
            return
        }
        if let tramError = error as? BVGTramError {
            errorMessage = tramError.errorDescription ?? "Failed to load."
        } else {
            errorMessage = "Failed to load."
        }
    }

    // MARK: - Formatting

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    public func formattedTime(for date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    public var formattedLastUpdated: String? {
        guard let lastUpdated else { return nil }
        return formattedTime(for: lastUpdated)
    }
}
