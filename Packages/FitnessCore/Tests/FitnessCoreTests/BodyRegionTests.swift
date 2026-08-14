import Testing
@testable import FitnessCore

@Suite("BodyRegion")
struct BodyRegionTests {

    @Test func everyCategoryHasTheExactExpectedRegions() {
        let expected: [BodyCategory: Set<BodyRegion>] = [
            .back: [
                .neckLeft, .neckRight, .shoulderLeft, .shoulderRight,
                .upperBack, .middleBack, .lowerBack,
            ],
            .abs: [.abs, .obliquesLeft, .obliquesRight],
            .chest: [.chestLeft, .chestRight],
            .arm: [
                .bicepsLeft, .bicepsRight, .tricepsLeft, .tricepsRight,
                .forearmLeft, .forearmRight, .handLeft, .handRight,
                .wristLeft, .wristRight,
            ],
            .legs: [
                .thighFront, .thighBack, .thighInner, .thighOuter,
                .kneeLeft, .kneeRight, .calf, .foot, .ankle,
            ],
        ]

        #expect(Set(expected.keys) == Set(BodyCategory.allCases))
        #expect(Set(expected.values.flatMap { $0 }) == Set(BodyRegion.allCases))
        for category in BodyCategory.allCases {
            #expect(Set(BodyRegion.regions(in: category)) == expected[category])
        }
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
        #expect(BodyRegion.middleBack.iconAssetName == "middle_back")
        #expect(BodyRegion.wristLeft.iconAssetName == "wrist_left")
        #expect(BodyRegion.wristRight.iconAssetName == "wrist_right")
        #expect(BodyRegion.handLeft.iconAssetName == "hand_left")
        #expect(BodyRegion.handRight.iconAssetName == "hand_right")
    }
}
