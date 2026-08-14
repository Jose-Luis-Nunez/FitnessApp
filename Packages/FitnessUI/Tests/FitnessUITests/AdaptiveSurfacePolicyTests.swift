import FitnessTestSupport
import Testing
@testable import FitnessUI

@Suite("Adaptive Surfaces — Policy", .tags(.fast))
@MainActor
struct AdaptiveSurfacePolicyTests {
    @Test
    func currentPlatformPolicy() {
#if os(visionOS)
        #expect(AppGlassTreatment.currentPlatform == .legacyMaterial)
        #expect(AppDarkSurfaceTreatment.currentPlatform == .nativeGlass)
#else
        if #available(iOS 27.0, macOS 27.0, *) {
            #expect(AppGlassTreatment.currentPlatform == .clear)
            #expect(AppDarkSurfaceTreatment.currentPlatform == .flat)
        } else if #available(iOS 26.0, macOS 26.0, *) {
            #expect(AppGlassTreatment.currentPlatform == .regular)
            #expect(AppDarkSurfaceTreatment.currentPlatform == .nativeGlass)
        } else {
            #expect(AppGlassTreatment.currentPlatform == .legacyMaterial)
            #expect(AppDarkSurfaceTreatment.currentPlatform == .nativeGlass)
        }
#endif
    }
}
