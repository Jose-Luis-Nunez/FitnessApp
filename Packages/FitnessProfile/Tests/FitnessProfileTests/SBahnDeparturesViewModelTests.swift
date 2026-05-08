import Testing
import Foundation
import FitnessTestSupport
@testable import FitnessProfile

@Suite("SBahnDeparturesViewModel Tests", .tags(.fast))
@MainActor
struct SBahnDeparturesViewModelTests {

    // MARK: - Helpers

    private final class MockService: BVGSBahnServicing, @unchecked Sendable {
        var results: [SBahnDeparture] = []
        var error: BVGSBahnError?
        private(set) var callCount = 0
        private(set) var lastFromStopId: String?
        private(set) var lastToStopId: String?

        func fetchSBahnRoute(
            fromStopId: String,
            toStopId: String,
            maxResults: Int
        ) async throws -> [SBahnDeparture] {
            callCount += 1
            lastFromStopId = fromStopId
            lastToStopId = toStopId
            if let error { throw error }
            return results
        }
    }

    private final class MockCache: SBahnDeparturesCaching, @unchecked Sendable {
        struct Key: Hashable { let from: String; let to: String }
        var storage: [Key: CachedSBahnDepartures] = [:]
        private(set) var saveCount = 0

        func load(fromStopId: String, toStopId: String) -> CachedSBahnDepartures? {
            storage[Key(from: fromStopId, to: toStopId)]
        }

        func save(fromStopId: String, toStopId: String, departures: [SBahnDeparture]) {
            saveCount += 1
            storage[Key(from: fromStopId, to: toStopId)] = CachedSBahnDepartures(
                departures: departures,
                savedAt: Date()
            )
        }

        func preload(fromStopId: String, toStopId: String, departures: [SBahnDeparture], savedAt: Date = Date()) {
            storage[Key(from: fromStopId, to: toStopId)] = CachedSBahnDepartures(
                departures: departures,
                savedAt: savedAt
            )
        }
    }

    private static func makeDeparture(
        id: String = "dep-1",
        line: String = "S3",
        direction: String = "S Erkner Bhf",
        delaySeconds: TimeInterval = 0,
        bridge: BridgeHint? = nil
    ) -> SBahnDeparture {
        let planned = Date(timeIntervalSince1970: 1_714_000_000)
        return SBahnDeparture(
            id: id,
            line: line,
            direction: direction,
            plannedWhen: planned,
            when: planned.addingTimeInterval(delaySeconds),
            bridge: bridge
        )
    }

    private static func makeBridge(
        transferStation: String = "S Ostbahnhof",
        bridgeLine: String = "S3",
        bridgeDirection: String = "S Erkner Bhf"
    ) -> BridgeHint {
        BridgeHint(
            transferStation: transferStation,
            bridgeLine: bridgeLine,
            bridgeDeparture: Date(timeIntervalSince1970: 1_714_000_180),
            bridgeDirection: bridgeDirection
        )
    }

    private static func makeVM(
        service: MockService = MockService(),
        cache: MockCache = MockCache()
    ) -> SBahnDeparturesViewModel {
        SBahnDeparturesViewModel(
            service: service,
            cache: cache,
            maxResults: 3
        )
    }

    // MARK: - Refresh happy path

    @Test func refresh_storesResultsAndUpdatesState() async {
        let service = MockService()
        service.results = [Self.makeDeparture(id: "a"), Self.makeDeparture(id: "b")]
        let cache = MockCache()
        let vm = Self.makeVM(service: service, cache: cache)

        await vm.refresh()

        #expect(vm.departures.map(\.id) == ["a", "b"])
        #expect(vm.errorMessage == nil)
        #expect(vm.lastUpdated != nil)
        #expect(vm.isStale == false)
        #expect(vm.isLoading == false)
        #expect(cache.saveCount == 1)
    }

    // MARK: - Refresh failure with cache fallback

    @Test func refresh_networkError_fallsBackToCacheAndMarksStale() async {
        let service = MockService()
        service.error = .network
        let cache = MockCache()
        cache.preload(
            fromStopId: SBahnDeparturesViewModel.defaultOrigin.stopId,
            toStopId: SBahnDeparturesViewModel.defaultDestination.stopId,
            departures: [Self.makeDeparture(id: "cached")]
        )
        let vm = Self.makeVM(service: service, cache: cache)

        await vm.refresh()

        #expect(vm.departures.map(\.id) == ["cached"])
        #expect(vm.isStale == true)
        #expect(vm.errorMessage == nil)
    }

    @Test func refresh_networkError_withoutCache_setsErrorMessage() async {
        let service = MockService()
        service.error = .network
        let vm = Self.makeVM(service: service)

        await vm.refresh()

        #expect(vm.departures.isEmpty)
        #expect(vm.errorMessage != nil)
    }

    // MARK: - Cache preload on init

    @Test func init_loadsCachedDeparturesAsStale() {
        let cache = MockCache()
        cache.preload(
            fromStopId: SBahnDeparturesViewModel.defaultOrigin.stopId,
            toStopId: SBahnDeparturesViewModel.defaultDestination.stopId,
            departures: [Self.makeDeparture(id: "init-cached")]
        )
        let vm = Self.makeVM(cache: cache)

        #expect(vm.departures.map(\.id) == ["init-cached"])
        #expect(vm.isStale == true)
    }

    // MARK: - Bridge passthrough

    @Test func refresh_preservesBridgeHint() async throws {
        let service = MockService()
        let bridge = Self.makeBridge()
        service.results = [Self.makeDeparture(id: "with-bridge", bridge: bridge)]
        let vm = Self.makeVM(service: service)

        await vm.refresh()

        let dep = try #require(vm.departures.first)
        #expect(dep.bridge?.bridgeLine == "S3")
        #expect(dep.bridge?.transferStation == "S Ostbahnhof")
    }

    // MARK: - Detail expansion toggle

    @Test func toggleDetailExpansion_setsAndClearsExpandedRowID() {
        let vm = Self.makeVM()

        vm.toggleDetailExpansion(rowID: "row-1")
        #expect(vm.expandedDetailRowID == "row-1")

        vm.toggleDetailExpansion(rowID: "row-1")
        #expect(vm.expandedDetailRowID == nil)
    }

    @Test func toggleDetailExpansion_switchesBetweenRows() {
        let vm = Self.makeVM()

        vm.toggleDetailExpansion(rowID: "row-1")
        vm.toggleDetailExpansion(rowID: "row-2")
        #expect(vm.expandedDetailRowID == "row-2")
    }

    // MARK: - Swap

    @Test func swap_togglesReversedAndScheduleRefresh() async {
        let service = MockService()
        service.results = [Self.makeDeparture(id: "swap-result")]
        let vm = Self.makeVM(service: service)

        let initialFrom = vm.fromStopId
        vm.swap()
        #expect(vm.fromStopId != initialFrom)
        #expect(vm.isReversed == true)

        // Yield so the Task spawned by swap()/scheduleRefresh() can run.
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(service.callCount >= 1)
    }

    // MARK: - Toggle expanded triggers refresh

    @Test func toggleExpanded_whenExpanding_schedulesRefresh() async {
        let service = MockService()
        service.results = [Self.makeDeparture(id: "toggle-result")]
        let vm = Self.makeVM(service: service)

        vm.toggleExpanded()
        #expect(vm.isExpanded == true)

        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(service.callCount >= 1)
    }

    // MARK: - onBecameActive only refreshes when expanded + stale

    @Test func onBecameActive_whenCollapsed_doesNotRefresh() async {
        let service = MockService()
        let vm = Self.makeVM(service: service)
        // VM starts collapsed (isExpanded = false)
        vm.onBecameActive()

        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(service.callCount == 0)
    }
}
