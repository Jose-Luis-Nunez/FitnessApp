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
/// which triggers `@Environment` resolution and catches missing dependencies
/// early in tests rather than at runtime.
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

@Suite("MuscleCategorySelectionView Environment contract")
@MainActor
struct MuscleCategorySelectionViewContractTests {

    @Test
    func requiresAppRouterAndOverlayState() {
        let view = MuscleCategorySelectionView()
            .environment(AppRouter())
            .environment(UIOverlayState())

        assertViewHosts(view)
    }

    @Test
    func worksWithoutExplicitAppRouter() {
        let view = MuscleCategorySelectionView()
            .environment(UIOverlayState())

        assertViewHosts(view)
    }
}

// MARK: - MuscleCategoryView

@Suite("MuscleCategoryView Environment contract")
@MainActor
struct MuscleCategoryViewContractTests {

    @Test
    func requiresAppRouterAndOverlayState() {
        let view = MuscleCategoryView(group: .arms)
            .environment(AppRouter())
            .environment(UIOverlayState())

        assertViewHosts(view)
    }
}
