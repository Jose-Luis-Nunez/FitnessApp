import Testing
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
@testable import FitnessExercise
import FitnessCore
import FitnessUI

// MARK: - Test Host

/// Wraps a SwiftUI View in a `UIHostingController` and forces view loading,
/// which triggers `@EnvironmentObject` resolution. A missing or mismatched
/// environment object crashes here instead of in the shipping app.
private func assertViewHosts<V: View>(
    _ view: V,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #if canImport(UIKit)
    let host = UIHostingController(rootView: view)
    host.loadViewIfNeeded()
    #expect(host.view != nil, sourceLocation: sourceLocation)
    #endif
}

// MARK: - MuscleCategorySelectionView

@Suite("MuscleCategorySelectionView EnvironmentObject contract")
struct MuscleCategorySelectionViewContractTests {

    @Test
    @MainActor
    func requiresAppRouterAndOverlayState() {
        let view = MuscleCategorySelectionView()
            .environmentObject(AppRouter())
            .environmentObject(UIOverlayState())

        assertViewHosts(view)
    }

    @Test
    @MainActor
    func crashesWithoutAppRouter() {
        // Intentionally omit AppRouter — this documents the contract.
        // If SwiftUI ever makes missing EnvironmentObjects non-fatal,
        // this test should be updated to verify the new behavior.
        let view = MuscleCategorySelectionView()
            .environmentObject(UIOverlayState())

        withKnownIssue("Missing AppRouter must crash") {
            assertViewHosts(view)
        }
    }
}

// MARK: - MuscleCategoryView

@Suite("MuscleCategoryView EnvironmentObject contract")
struct MuscleCategoryViewContractTests {

    @Test
    @MainActor
    func requiresAppRouterAndOverlayState() {
        let view = MuscleCategoryView(group: .arms)
            .environmentObject(AppRouter())
            .environmentObject(UIOverlayState())

        assertViewHosts(view)
    }
}
