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

    /// Tram 21 runs roughly every 10 min, so 60 s is the sweet spot between
    /// "feels live" and respecting the community-run BVG endpoint. See plan
    /// "Profile Polish & Tram Cache" for the full reasoning.
    public static let autoRefreshInterval: TimeInterval = 60

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
    private let refreshInterval: TimeInterval
    private let maxResults: Int

    private var refreshTask: Task<Void, Never>?

    // MARK: - Init

    public init(
        service: BVGTramServicing = BVGTramService(),
        cache: TramDeparturesCaching = TramDeparturesCache(),
        line: String = TramDeparturesViewModel.defaultLine,
        origin: Endpoint = TramDeparturesViewModel.defaultOrigin,
        destination: Endpoint = TramDeparturesViewModel.defaultDestination,
        refreshInterval: TimeInterval = TramDeparturesViewModel.autoRefreshInterval,
        maxResults: Int = 3
    ) {
        self.service = service
        self.cache = cache
        self.line = line
        self.origin = origin
        self.destination = destination
        self.refreshInterval = refreshInterval
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
            startAutoRefresh()
        } else {
            stopAutoRefresh()
        }
    }

    public func swap() {
        isReversed.toggle()
        // Don't clear `departures` here — the card height would collapse and the
        // surrounding ScrollView would jump. Show whatever cache we have for the
        // new direction (if any) until the live refresh resolves.
        loadCachedSnapshot()
        errorMessage = nil
        Task { await refresh() }
    }

    public func refresh() async {
        isLoading = true
        do {
            let result = try await service.fetchDepartures(
                fromStopId: fromStopId,
                directionStopId: toStopId,
                line: line,
                maxResults: maxResults
            )
            departures = result
            errorMessage = nil
            lastUpdated = Date()
            isStale = false
            cache.save(fromStopId: fromStopId, toStopId: toStopId, line: line, departures: result)
        } catch {
            handleRefreshFailure(error)
        }
        isLoading = false
    }

    /// Called when the host scene transitions back to `.active`. If the data is
    /// older than `foregroundStaleThreshold`, kick off an immediate refresh.
    /// Always (re)starts the periodic timer.
    public func onBecameActive() {
        let needsImmediateFetch: Bool
        if let lastUpdated {
            needsImmediateFetch = Date().timeIntervalSince(lastUpdated) > Self.foregroundStaleThreshold
        } else {
            needsImmediateFetch = true
        }
        if needsImmediateFetch {
            Task { await refresh() }
        }
        startAutoRefresh()
    }

    public func startAutoRefresh() {
        stopAutoRefresh()
        let interval = refreshInterval
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh()
            while !Task.isCancelled {
                let nanos = UInt64(interval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
                if Task.isCancelled { return }
                if await !self.isExpanded { return }
                await self.refresh()
            }
        }
    }

    public func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
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
            errorMessage = tramError.errorDescription ?? "Fehler beim Laden."
        } else {
            errorMessage = "Fehler beim Laden."
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
