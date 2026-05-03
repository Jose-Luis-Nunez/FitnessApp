import Testing
@testable import FitnessCore

@Suite("BodyRegion")
struct BodyRegionTests {

    @Test func everyRegionMapsToCategory() {
        for region in BodyRegion.allCases {
            _ = region.category
        }
    }

    @Test func categoryFilterCoversAllRegions() {
        let grouped = BodyCategory.allCases.flatMap { BodyRegion.regions(in: $0) }
        #expect(Set(grouped) == Set(BodyRegion.allCases))
    }

    @Test func backCategoryIncludesNeckAndShoulders() {
        let regions = BodyRegion.regions(in: .back)
        #expect(regions.contains(.neckLeft))
        #expect(regions.contains(.neckRight))
        #expect(regions.contains(.shoulderLeft))
        #expect(regions.contains(.shoulderRight))
        #expect(regions.contains(.upperBack))
        #expect(regions.contains(.middleBack))
        #expect(regions.contains(.lowerBack))
    }

    @Test func legsCategoryIncludesInnerOuterAndBothKnees() {
        let regions = BodyRegion.regions(in: .legs)
        #expect(regions.contains(.thighInner))
        #expect(regions.contains(.thighOuter))
        #expect(regions.contains(.kneeLeft))
        #expect(regions.contains(.kneeRight))
    }

    @Test func armCategoryIncludesBicepsAndTricepsSides() {
        let regions = BodyRegion.regions(in: .arm)
        #expect(regions.contains(.bicepsLeft))
        #expect(regions.contains(.bicepsRight))
        #expect(regions.contains(.tricepsLeft))
        #expect(regions.contains(.tricepsRight))
        #expect(regions.contains(.forearmLeft))
        #expect(regions.contains(.forearmRight))
        #expect(regions.contains(.handLeft))
        #expect(regions.contains(.handRight))
        #expect(regions.contains(.wristLeft))
        #expect(regions.contains(.wristRight))
    }

    @Test func chestCategoryIncludesLeftAndRight() {
        let regions = BodyRegion.regions(in: .chest)
        #expect(regions.contains(.chestLeft))
        #expect(regions.contains(.chestRight))
    }

    @Test func muscleGroupToBodyCategoryMapping() {
        #expect(BodyCategory.from(muscleGroup: .arms) == .arm)
        #expect(BodyCategory.from(muscleGroup: .chest) == .chest)
        #expect(BodyCategory.from(muscleGroup: .back) == .back)
        #expect(BodyCategory.from(muscleGroup: .legs) == .legs)
        #expect(BodyCategory.from(muscleGroup: .abs) == .abs)
    }

    @Test func iconAssetNameFollowsConvention() {
        #expect(BodyRegion.bicepsLeft.iconAssetName == "biceps_left")
        #expect(BodyRegion.bicepsRight.iconAssetName == "biceps_right")
        #expect(BodyRegion.tricepsLeft.iconAssetName == "triceps_left")
        #expect(BodyRegion.tricepsRight.iconAssetName == "triceps_right")
        #expect(BodyRegion.obliquesLeft.iconAssetName == "obliques_left")
        #expect(BodyRegion.shoulderLeft.iconAssetName == "shoulder_left")
        #expect(BodyRegion.abs.iconAssetName == "Abs")
        #expect(BodyRegion.forearmLeft.iconAssetName == "forearm_left")
        #expect(BodyRegion.forearmRight.iconAssetName == "forearm_right")
        #expect(BodyRegion.forearmLeft.displayName == "Forearm left")
        #expect(BodyRegion.forearmRight.displayName == "Forearm right")
        #expect(BodyRegion.middleBack.iconAssetName == "middle_back")
        #expect(BodyRegion.middleBack.displayName == "Middle back")
        #expect(BodyRegion.wristLeft.iconAssetName == "wrist_left")
        #expect(BodyRegion.wristRight.iconAssetName == "wrist_right")
        #expect(BodyRegion.wristLeft.displayName == "Wrist left")
        #expect(BodyRegion.wristRight.displayName == "Wrist right")
        #expect(BodyRegion.handLeft.iconAssetName == "hand_left")
        #expect(BodyRegion.handRight.iconAssetName == "hand_right")
        #expect(BodyRegion.handLeft.displayName == "Hand left")
        #expect(BodyRegion.handRight.displayName == "Hand right")
    }
}
