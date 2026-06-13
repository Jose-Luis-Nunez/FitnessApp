import Testing
import Foundation
import FitnessTestSupport
@testable import FitnessProfile

@Suite("TramDeparturesViewModel Tests", .tags(.fast))
@MainActor
struct TramDeparturesViewModelTests {

    // MARK: - Helpers

    private final class MockService: BVGTramServicing, @unchecked Sendable {
        var results: [TramDeparture] = []
        var error: BVGTramError?
        private(set) var callCount = 0
        private(set) var lastFromStopId: String?
        private(set) var lastDirectionStopId: String?
        private(set) var lastLine: String?

        func fetchDepartures(
            fromStopId: String,
            directionStopId: String,
            line: String,
            maxResults: Int
        ) async throws -> [TramDeparture] {
            callCount += 1
            lastFromStopId = fromStopId
            lastDirectionStopId = directionStopId
            lastLine = line
            if let error { throw error }
            return results
        }
    }

    private final class MockCache: TramDeparturesCaching, @unchecked Sendable {
        struct Key: Hashable { let from: String; let to: String; let line: String }
        var storage: [Key: CachedDepartures] = [:]
        private(set) var saveCount = 0

        func load(fromStopId: String, toStopId: String, line: String) -> CachedDepartures? {
            storage[Key(from: fromStopId, to: toStopId, line: line)]
        }

        func save(fromStopId: String, toStopId: String, line: String, departures: [TramDeparture]) {
            saveCount += 1
            storage[Key(from: fromStopId, to: toStopId, line: line)] = CachedDepartures(
                departures: departures,
                savedAt: Date()
            )
        }

        func preload(fromStopId: String, toStopId: String, line: String, departures: [TramDeparture], savedAt: Date = Date()) {
            storage[Key(from: fromStopId, to: toStopId, line: line)] = CachedDepartures(
                departures: departures,
                savedAt: savedAt
            )
        }
    }

    private static func makeDeparture(
        id: String = "dep-1",
        line: String = "21",
        direction: String = "Rummelsburg, Marktstraße",
        delaySeconds: TimeInterval = 0
    ) -> TramDeparture {
        let planned = Date(timeIntervalSince1970: 1_714_000_000)
        return TramDeparture(
            id: id,
            line: line,
            direction: direction,
            plannedWhen: planned,
            when: planned.addingTimeInterval(delaySeconds)
        )
    }

    private static func makeVM(
        service: MockService = MockService(),
        cache: MockCache = MockCache()
    ) -> TramDeparturesViewModel {
        TramDeparturesViewModel(
            service: service,
            cache: cache,
            maxResults: 3
        )
    }

    // MARK: - Initial State

    @Test func initialState_matchesDefaults() {
        let vm = Self.makeVM()
        #expect(vm.isExpanded == false)
        #expect(vm.departures.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.isReversed == false)
        #expect(vm.isStale == false)
        #expect(vm.fromLabel == "Blockdammweg")
        #expect(vm.toLabel == "Marktstr.")
        #expect(vm.lineName == "21")
    }

    @Test func init_loadsCachedDeparturesAsStale() {
        let cache = MockCache()
        let savedAt = Date(timeIntervalSinceNow: -3600)
        cache.preload(
            fromStopId: "900162504",
            toStopId: "900160535",
            line: "21",
            departures: [Self.makeDeparture(id: "from-cache")],
            savedAt: savedAt
        )
        let vm = Self.makeVM(service: MockService(), cache: cache)
        #expect(vm.departures.count == 1)
        #expect(vm.departures.first?.id == "from-cache")
        #expect(vm.isStale == true)
        #expect(vm.lastUpdated == savedAt)
    }

    // MARK: - Refresh

    @Test func refresh_success_updatesDeparturesAndClearsStale() async {
        let service = MockService()
        service.results = [Self.makeDeparture(id: "a"), Self.makeDeparture(id: "b")]
        let cache = MockCache()
        let vm = Self.makeVM(service: service, cache: cache)
        await vm.refresh()
        #expect(vm.departures.count == 2)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
        #expect(vm.lastUpdated != nil)
        #expect(vm.isStale == false)
        #expect(cache.saveCount == 1)
    }

    @Test func refresh_failureWithCache_showsCachedAndStaleFlag_noErrorMessage() async {
        let service = MockService()
        let cache = MockCache()
        cache.preload(
            fromStopId: "900162504",
            toStopId: "900160535",
            line: "21",
            departures: [Self.makeDeparture(id: "cached-1")]
        )
        service.error = .network
        let vm = Self.makeVM(service: service, cache: cache)
        await vm.refresh()
        #expect(vm.departures.count == 1)
        #expect(vm.departures.first?.id == "cached-1")
        #expect(vm.isStale == true)
        #expect(vm.errorMessage == nil, "On a cache hit we show no error message")
        #expect(vm.isLoading == false)
    }

    @Test func refresh_failureWithoutCache_setsErrorMessage() async {
        let service = MockService()
        service.error = .rateLimited
        let vm = Self.makeVM(service: service)
        await vm.refresh()
        #expect(vm.departures.isEmpty)
        #expect(vm.errorMessage == BVGTramError.rateLimited.errorDescription)
        #expect(vm.isLoading == false)
    }

    @Test func refresh_usesCurrentFromAndTo() async {
        let service = MockService()
        let vm = Self.makeVM(service: service)
        await vm.refresh()
        #expect(service.lastFromStopId == "900162504")
        #expect(service.lastDirectionStopId == "900160535")
        #expect(service.lastLine == "21")
    }

    // MARK: - Swap

    @Test func swap_togglesReversedAndSwapsLabels() {
        let vm = Self.makeVM()
        vm.swap()
        #expect(vm.isReversed == true)
        #expect(vm.fromLabel == "Marktstr.")
        #expect(vm.toLabel == "Blockdammweg")
        #expect(vm.fromStopId == "900160535")
        #expect(vm.toStopId == "900162504")
    }

    @Test func swap_loadsCachedForNewDirection_doesNotEmptyDepartures() async {
        let service = MockService()
        let cache = MockCache()
        // Preload cache for both directions
        cache.preload(
            fromStopId: "900162504",
            toStopId: "900160535",
            line: "21",
            departures: [Self.makeDeparture(id: "forward")]
        )
        cache.preload(
            fromStopId: "900160535",
            toStopId: "900162504",
            line: "21",
            departures: [Self.makeDeparture(id: "reverse")]
        )
        // Make the live call slow / fail so we observe the cache transition
        service.error = .network
        let vm = Self.makeVM(service: service, cache: cache)
        #expect(vm.departures.first?.id == "forward")
        vm.swap()
        // After swap, before refresh resolves, departures should already reflect
        // the cache for the new direction (no flash of empty content).
        #expect(vm.departures.first?.id == "reverse")
        #expect(vm.isStale == true)
    }

    // MARK: - Expand / Collapse

    @Test func toggleExpanded_triggersOneRefresh() async {
        let service = MockService()
        service.results = [Self.makeDeparture(id: "a")]
        let vm = Self.makeVM(service: service)
        vm.toggleExpanded()
        #expect(vm.isExpanded == true)
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(service.callCount == 1, "Expanding triggers exactly one refresh")
    }

    @Test func toggleExpanded_secondCall_collapsesWithoutRefresh() async {
        let service = MockService()
        service.results = [Self.makeDeparture(id: "a")]
        let vm = Self.makeVM(service: service)
        vm.toggleExpanded()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let countAfterExpand = service.callCount
        vm.toggleExpanded()
        #expect(vm.isExpanded == false)
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(service.callCount == countAfterExpand, "Collapsing does not trigger a refresh")
    }

    // MARK: - onBecameActive

    @Test func onBecameActive_whenCollapsed_doesNotRefresh() async {
        let service = MockService()
        service.results = [Self.makeDeparture(id: "a")]
        let vm = Self.makeVM(service: service)
        vm.onBecameActive()
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(service.callCount == 0, "No refresh when card is collapsed")
    }

    @Test func onBecameActive_expandedWithStaleData_triggersRefresh() async {
        let service = MockService()
        service.results = [Self.makeDeparture(id: "a")]
        let vm = Self.makeVM(service: service)
        vm.toggleExpanded()
        try? await Task.sleep(nanoseconds: 100_000_000)
        let countAfterExpand = service.callCount
        vm.lastUpdated = Date(timeIntervalSinceNow: -3600)
        vm.onBecameActive()
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(service.callCount > countAfterExpand, "Stale data triggers a refresh on foreground")
    }

    @Test func onBecameActive_expandedWithFreshData_doesNotRefresh() async {
        let service = MockService()
        service.results = [Self.makeDeparture(id: "a")]
        let vm = Self.makeVM(service: service)
        vm.toggleExpanded()
        try? await Task.sleep(nanoseconds: 100_000_000)
        let countAfterExpand = service.callCount
        vm.onBecameActive()
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(service.callCount == countAfterExpand, "Fresh data skips refresh on foreground")
    }

    // MARK: - Formatting

    @Test func formattedTime_producesHHmm() {
        let vm = Self.makeVM()
        var components = DateComponents()
        components.year = 2026; components.month = 4; components.day = 21
        components.hour = 19; components.minute = 21
        components.timeZone = TimeZone(identifier: "Europe/Berlin")
        let date = Calendar(identifier: .gregorian).date(from: components)!
        let formatted = vm.formattedTime(for: date)
        #expect(formatted.contains(":"))
        #expect(formatted.count == 5)
    }

    // MARK: - Delay Computation

    @Test func delayMinutes_positiveWhenLate() {
        let dep = Self.makeDeparture(delaySeconds: 180)
        #expect(dep.delayMinutes == 3)
    }

    @Test func delayMinutes_negativeWhenEarly() {
        let dep = Self.makeDeparture(delaySeconds: -120)
        #expect(dep.delayMinutes == -2)
    }

    @Test func delayMinutes_zeroWhenOnTime() {
        let dep = Self.makeDeparture(delaySeconds: 0)
        #expect(dep.delayMinutes == 0)
    }

    // MARK: - Cancellation-leak fix (defer { isLoading = false })
    // Mirror tests of SBahnDeparturesViewModelTests so the same bug class
    // is regression-guarded on both VMs.

    @Test func refresh_whenSucceeding_clearsIsLoading() async {
        let service = MockService()
        service.results = [Self.makeDeparture()]
        let vm = Self.makeVM(service: service)
        await vm.refresh()
        #expect(vm.isLoading == false)
    }

    @Test func refresh_whenFailing_clearsIsLoading() async {
        let service = MockService()
        service.error = .network
        let vm = Self.makeVM(service: service)
        await vm.refresh()
        #expect(vm.isLoading == false)
    }

    @Test func refresh_whenCancelled_clearsIsLoading() async {
        let service = BlockableMockService()
        let vm = TramDeparturesViewModel(
            service: service,
            cache: MockCache(),
            line: TramDeparturesViewModel.defaultLine,
            origin: TramDeparturesViewModel.defaultOrigin,
            destination: TramDeparturesViewModel.defaultDestination,
            maxResults: 3
        )
        let task = Task { await vm.refresh() }
        await service.awaitSuspension()
        #expect(vm.isLoading == true)

        task.cancel()
        service.resumeWithCancellation()
        await task.value

        #expect(vm.isLoading == false)
    }

    // MARK: - Failure backoff (RefreshScheduler-backed)

    @Test func onBecameActive_recentFailure_doesNotRefetch() async {
        let service = MockService()
        service.error = .network
        let vm = Self.makeVM(service: service)
        vm.toggleExpanded()
        try? await Task.sleep(nanoseconds: 80_000_000)
        let countAfterFirst = service.callCount

        vm.onBecameActive()
        try? await Task.sleep(nanoseconds: 80_000_000)
        #expect(service.callCount == countAfterFirst)
    }

    /// MockService variant that suspends on a continuation, allowing the
    /// test to deterministically cancel the in-flight task.
    private final class BlockableMockService: BVGTramServicing, @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<[TramDeparture], Error>?
        private var suspensionCallback: (() -> Void)?

        func awaitSuspension() async {
            await withCheckedContinuation { (cb: CheckedContinuation<Void, Never>) in
                lock.lock()
                if continuation != nil {
                    lock.unlock()
                    cb.resume()
                } else {
                    suspensionCallback = { cb.resume() }
                    lock.unlock()
                }
            }
        }

        func resumeWithCancellation() {
            lock.lock()
            let c = continuation
            continuation = nil
            lock.unlock()
            c?.resume(throwing: CancellationError())
        }

        func fetchDepartures(
            fromStopId: String,
            directionStopId: String,
            line: String,
            maxResults: Int
        ) async throws -> [TramDeparture] {
            try await withCheckedThrowingContinuation { c in
                lock.lock()
                continuation = c
                let cb = suspensionCallback
                suspensionCallback = nil
                lock.unlock()
                cb?()
            }
        }
    }
}
