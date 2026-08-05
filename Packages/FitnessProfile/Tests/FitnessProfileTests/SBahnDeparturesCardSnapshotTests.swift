import SnapshotTesting
import SwiftUI
import Testing
@testable import FitnessProfile
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
@Suite("S-Bahn departures card — Snapshots", .tags(.snapshot), .serialized)
@MainActor
struct SBahnDeparturesCardSnapshotTests {
    private final class StubService: BVGSBahnServicing, @unchecked Sendable {
        func fetchSBahnRoute(
            fromStopId: String,
            toStopId: String,
            maxResults: Int
        ) async throws -> [SBahnDeparture] {
            Issue.record("Snapshot rendering must not fetch departures")
            return []
        }
    }

    private final class SnapshotCache: SBahnDeparturesCaching, @unchecked Sendable {
        let cached: CachedSBahnDepartures?

        init(cached: CachedSBahnDepartures?) {
            self.cached = cached
        }

        func load(fromStopId: String, toStopId: String) -> CachedSBahnDepartures? {
            cached
        }

        func save(fromStopId: String, toStopId: String, departures: [SBahnDeparture]) {}
    }

    @Test func expandedWithoutRequest() {
        let viewModel = makeViewModel(cached: nil)
        viewModel.toggleExpanded()

        assertCardSnapshot(
            SBahnDeparturesCardView(viewModel: viewModel),
            named: "expanded-no-request"
        )
    }

    @Test func expandedWithCachedResult() {
        let planned = Date(timeIntervalSince1970: 1_767_864_720)
        let cached = CachedSBahnDepartures(
            departures: [
                SBahnDeparture(
                    id: "cached-s3",
                    line: "S3",
                    direction: "S Erkner Bhf",
                    plannedWhen: planned,
                    when: planned.addingTimeInterval(120),
                    bridge: nil,
                    arrivalAtDestination: planned.addingTimeInterval(600)
                )
            ],
            savedAt: Date(timeIntervalSince1970: 1_767_864_000)
        )
        let viewModel = makeViewModel(cached: cached)
        viewModel.toggleExpanded()

        assertCardSnapshot(
            SBahnDeparturesCardView(viewModel: viewModel),
            named: "expanded-cached-result"
        )
    }

    private func makeViewModel(
        cached: CachedSBahnDepartures?
    ) -> SBahnDeparturesViewModel {
        SBahnDeparturesViewModel(
            service: StubService(),
            cache: SnapshotCache(cached: cached),
            maxResults: 4
        )
    }

    private func assertCardSnapshot<V: View>(
        _ view: V,
        named name: String,
        sourceLocation: SourceLocation = #_sourceLocation,
        file: StaticString = #filePath,
        function: StaticString = #function
    ) {
        let size = CGSize(width: 393, height: 520)
        let hosted = view
            .padding(.horizontal, 16)
            .frame(width: size.width, height: size.height, alignment: .top)
            .background(Color.black)
        let controller = UIHostingController(rootView: hosted)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .black

        SnapshotTesting.assertSnapshot(
            of: controller,
            as: .image(
                precision: 0.99,
                perceptualPrecision: 0.98,
                size: size
            ),
            named: name,
            record: ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"
                ? .all
                : .never,
            file: file,
            testName: "\(function)",
            line: UInt(sourceLocation.line)
        )
    }
}
#endif
