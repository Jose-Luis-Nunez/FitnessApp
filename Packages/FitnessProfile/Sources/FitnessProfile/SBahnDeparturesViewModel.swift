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
    nonisolated public static let defaultOrigin = Endpoint(
        stopId: "900100003",
        label: "Alexanderplatz"
    )
    nonisolated public static let defaultDestination = Endpoint(
        stopId: "900120003",
        label: "Ostkreuz"
    )

    // MARK: - Observable State

    public private(set) var isExpanded: Bool = false
    public private(set) var departures: [SBahnDeparture] = []
    public private(set) var isLoading: Bool = false
    public private(set) var error: TransitPresentationFailure?
    public private(set) var lastUpdated: Date?
    public private(set) var isReversed: Bool = false
    /// True when the displayed departures are the last successful cached
    /// request rather than a result fetched during the current app session.
    public private(set) var isShowingCachedResult: Bool = false
    /// ID of the row whose detail panel is currently expanded; `nil` = none.
    public var expandedDetailRowID: String?

    // MARK: - Dependencies

    private let service: BVGSBahnServicing
    private let cache: SBahnDeparturesCaching
    private let origin: Endpoint
    private let destination: Endpoint
    private let maxResults: Int

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
    }

    public func swap() async {
        guard !isLoading else { return }

        isReversed.toggle()
        error = nil
        loadCachedSnapshot()
        await refresh()
    }

    public func toggleDetailExpansion(rowID: String) {
        expandedDetailRowID = (expandedDetailRowID == rowID) ? nil : rowID
    }

    public func refresh() async {
        guard !isLoading else { return }

        let requestedFromStopId = fromStopId
        let requestedToStopId = toStopId
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await service.fetchSBahnRoute(
                fromStopId: requestedFromStopId,
                toStopId: requestedToStopId,
                maxResults: maxResults
            )
            guard !Task.isCancelled else { return }
            cache.save(
                fromStopId: requestedFromStopId,
                toStopId: requestedToStopId,
                departures: result
            )
            guard requestedFromStopId == fromStopId,
                  requestedToStopId == toStopId else { return }
            departures = result
            self.error = nil
            lastUpdated = Date()
            isShowingCachedResult = false
        } catch is CancellationError {
            return
        } catch {
            guard requestedFromStopId == fromStopId,
                  requestedToStopId == toStopId else { return }
            handleRefreshFailure(
                error,
                fromStopId: requestedFromStopId,
                toStopId: requestedToStopId
            )
        }
    }

    // MARK: - Cache helpers

    private func loadCachedSnapshot() {
        departures = []
        lastUpdated = nil
        isShowingCachedResult = false
        expandedDetailRowID = nil
        guard let cached = cache.load(fromStopId: fromStopId, toStopId: toStopId) else {
            return
        }
        departures = cached.departures
        lastUpdated = cached.savedAt
        isShowingCachedResult = true
    }

    private func handleRefreshFailure(
        _ error: Error,
        fromStopId: String,
        toStopId: String
    ) {
        if let cached = cache.load(fromStopId: fromStopId, toStopId: toStopId) {
            departures = cached.departures
            lastUpdated = cached.savedAt
            isShowingCachedResult = true
            self.error = nil
            return
        }
        if let sbahnError = error as? BVGSBahnError {
            switch sbahnError {
            case .invalidURL: self.error = .invalidURL
            case .network: self.error = .network
            case .decoding: self.error = .decoding
            case .rateLimited: self.error = .rateLimited
            case .serverError(let statusCode): self.error = .server(statusCode: statusCode)
            }
        } else {
            self.error = .unknown
        }
    }

    // MARK: - Formatting

    public func formattedTime(for date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    public func formattedLastUpdated(locale: Locale) -> String? {
        guard let lastUpdated else { return nil }
        return formattedTime(for: lastUpdated, locale: locale)
    }
}
