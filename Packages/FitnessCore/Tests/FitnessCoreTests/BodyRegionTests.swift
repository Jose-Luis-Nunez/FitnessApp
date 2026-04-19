import XCTest
@testable import FitnessCore

final class BodyRegionTests: XCTestCase {

    func testEveryRegionMapsToCategory() {
        for region in BodyRegion.allCases {
            _ = region.category
        }
    }

    func testCategoryFilterCoversAllRegions() {
        let grouped = BodyCategory.allCases.flatMap { BodyRegion.regions(in: $0) }
        XCTAssertEqual(Set(grouped), Set(BodyRegion.allCases))
    }

    func testBackCategoryIncludesNeckAndShoulders() {
        let regions = BodyRegion.regions(in: .back)
        XCTAssertTrue(regions.contains(.neckLeft))
        XCTAssertTrue(regions.contains(.neckRight))
        XCTAssertTrue(regions.contains(.shoulderLeft))
        XCTAssertTrue(regions.contains(.shoulderRight))
        XCTAssertTrue(regions.contains(.upperBack))
        XCTAssertTrue(regions.contains(.middleBack))
        XCTAssertTrue(regions.contains(.lowerBack))
    }

    func testLegsCategoryIncludesInnerOuterAndBothKnees() {
        let regions = BodyRegion.regions(in: .legs)
        XCTAssertTrue(regions.contains(.thighInner))
        XCTAssertTrue(regions.contains(.thighOuter))
        XCTAssertTrue(regions.contains(.kneeLeft))
        XCTAssertTrue(regions.contains(.kneeRight))
    }

    func testArmCategoryIncludesBicepsAndTricepsSides() {
        let regions = BodyRegion.regions(in: .arm)
        XCTAssertTrue(regions.contains(.bicepsLeft))
        XCTAssertTrue(regions.contains(.bicepsRight))
        XCTAssertTrue(regions.contains(.tricepsLeft))
        XCTAssertTrue(regions.contains(.tricepsRight))
        XCTAssertTrue(regions.contains(.forearmLeft))
        XCTAssertTrue(regions.contains(.forearmRight))
        XCTAssertTrue(regions.contains(.handLeft))
        XCTAssertTrue(regions.contains(.handRight))
        XCTAssertTrue(regions.contains(.wristLeft))
        XCTAssertTrue(regions.contains(.wristRight))
    }

    func testChestCategoryIncludesLeftAndRight() {
        let regions = BodyRegion.regions(in: .chest)
        XCTAssertTrue(regions.contains(.chestLeft))
        XCTAssertTrue(regions.contains(.chestRight))
    }

    func testMuscleGroupToBodyCategoryMapping() {
        XCTAssertEqual(BodyCategory.from(muscleGroup: .arms), .arm)
        XCTAssertEqual(BodyCategory.from(muscleGroup: .chest), .chest)
        XCTAssertEqual(BodyCategory.from(muscleGroup: .back), .back)
        XCTAssertEqual(BodyCategory.from(muscleGroup: .legs), .legs)
        XCTAssertEqual(BodyCategory.from(muscleGroup: .abs), .abs)
    }

    func testIconAssetNameFollowsUserConvention() {
        XCTAssertEqual(BodyRegion.bicepsLeft.iconAssetName, "biceps_left")
        XCTAssertEqual(BodyRegion.bicepsRight.iconAssetName, "biceps_right")
        XCTAssertEqual(BodyRegion.tricepsLeft.iconAssetName, "triceps_left")
        XCTAssertEqual(BodyRegion.tricepsRight.iconAssetName, "triceps_right")
        XCTAssertEqual(BodyRegion.obliquesLeft.iconAssetName, "obliques_left")
        XCTAssertEqual(BodyRegion.shoulderLeft.iconAssetName, "shoulder_left")
        XCTAssertEqual(BodyRegion.abs.iconAssetName, "Abs")
        XCTAssertEqual(BodyRegion.forearmLeft.iconAssetName, "forearm_left")
        XCTAssertEqual(BodyRegion.forearmRight.iconAssetName, "forearm_right")
        XCTAssertEqual(BodyRegion.forearmLeft.displayName, "Forearm left")
        XCTAssertEqual(BodyRegion.forearmRight.displayName, "Forearm right")
        XCTAssertEqual(BodyRegion.middleBack.iconAssetName, "middle_back")
        XCTAssertEqual(BodyRegion.middleBack.displayName, "Middle back")
        XCTAssertEqual(BodyRegion.wristLeft.iconAssetName, "wrist_left")
        XCTAssertEqual(BodyRegion.wristRight.iconAssetName, "wrist_right")
        XCTAssertEqual(BodyRegion.wristLeft.displayName, "Wrist left")
        XCTAssertEqual(BodyRegion.wristRight.displayName, "Wrist right")
        XCTAssertEqual(BodyRegion.handLeft.iconAssetName, "hand_left")
        XCTAssertEqual(BodyRegion.handRight.iconAssetName, "hand_right")
        XCTAssertEqual(BodyRegion.handLeft.displayName, "Hand left")
        XCTAssertEqual(BodyRegion.handRight.displayName, "Hand right")
    }

}
