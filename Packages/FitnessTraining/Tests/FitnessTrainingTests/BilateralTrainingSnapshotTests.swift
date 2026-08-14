#if canImport(UIKit)
import FitnessAnalytics
import FitnessCore
import FitnessTestSupport
import FitnessUI
import SnapshotTesting
import SwiftUI
import Testing
import UIKit
@testable import FitnessTraining

@MainActor
private func makeBilateralExercise() -> Exercise {
    FitnessTestSupport.makeExercise(
        name: "Torso Rotation",
        weight: 20,
        reps: 12,
        sets: 3,
        category: .abs,
        executionMode: .bilateral
    )
}

@MainActor
private func makeTrainingSessionCoordinator(for exercise: Exercise) -> TrainingCoordinator {
    let coordinator = TrainingCoordinator(
        findCategory: { _ in exercise.category },
        onExerciseUpdate: { _, _ in },
        onExerciseReset: { _, _ in },
        analyticsViewModel: AnalyticsViewModel(storageService: StubAnalyticsStorage())
    )
    coordinator.startTraining(for: exercise)
    return coordinator
}

@MainActor
@Suite("Bilateral training — UIKit contracts", .tags(.integration))
struct BilateralTrainingUIKitContractTests {
    @Test(
        "Bilateral card fits compact, regular, and large widths",
        arguments: [CGFloat(320), CGFloat(393), CGFloat(430)]
    )
    func bilateralCardFits(width: CGFloat) {
        let bilateral = makeBilateralExercise()
        let viewModel = ActiveSetViewModel()
        viewModel.startSet(for: bilateral, category: .abs)
        let view = SimpleActiveSetView(
            exercise: bilateral,
            setProgress: .constant(viewModel.setProgress),
            viewModel: viewModel
        )
        let host = UIHostingController(rootView: view)

        let measured = host.sizeThatFits(
            in: CGSize(width: width, height: .greatestFiniteMagnitude)
        )

        #expect(measured.width <= width)
        #expect(measured.height > 0)
        #expect(measured.height == AppStyle.Layout.trainingSheetBilateralSetViewportHeight)
        #expect(measured.width.isFinite)
        #expect(measured.height.isFinite)
    }

    @Test(
        "Filled bilateral content fits the three-pair viewport",
        arguments: [CGFloat(320), CGFloat(393), CGFloat(430)]
    )
    func filledBilateralCardFits(width: CGFloat) {
        let bilateral = makeBilateralExercise()
        let viewModel = ActiveSetViewModel()
        viewModel.startSet(for: bilateral, category: .abs)
        viewModel.setProgress = bilateral.trainingSteps.map {
            SetProgress(
                status: .completedDone,
                currentReps: bilateral.reps,
                weight: bilateral.weight,
                side: $0.side,
                logicalSetIndex: $0.logicalSetIndex
            )
        }
        let view = SimpleActiveSetView(
            exercise: bilateral,
            setProgress: .constant(viewModel.setProgress),
            viewModel: viewModel
        )
        let host = UIHostingController(rootView: view)

        let measured = host.sizeThatFits(
            in: CGSize(width: width, height: .greatestFiniteMagnitude)
        )

        #expect(measured.width <= width)
        #expect(measured.height <= AppStyle.Layout.trainingSheetBilateralSetViewportHeight)
    }

    @Test(
        "Training sheet session keeps standard columns bounded at every supported width",
        arguments: [CGFloat(320), CGFloat(393), CGFloat(430)]
    )
    func standardTrainingSheetSessionFits(width: CGFloat) {
        let standard = FitnessTestSupport.makeExercise(
            name: "Exercise 12",
            weight: 20,
            reps: 12,
            sets: 3,
            category: .abs
        )
        let coordinator = makeTrainingSessionCoordinator(for: standard)
        let host = UIHostingController(
            rootView: TrainingSessionComponent(coordinator: coordinator)
        )

        let measured = host.sizeThatFits(
            in: CGSize(width: width, height: .greatestFiniteMagnitude)
        )

        #expect(measured.width <= width)
        #expect(measured.height == AppStyle.Layout.trainingSheetStandardSessionHeight)
    }

    @Test(
        "Training sheet session keeps bilateral columns bounded at every supported width",
        arguments: [CGFloat(320), CGFloat(393), CGFloat(430)]
    )
    func bilateralTrainingSheetSessionFits(width: CGFloat) {
        let coordinator = makeTrainingSessionCoordinator(for: makeBilateralExercise())
        let host = UIHostingController(
            rootView: TrainingSessionComponent(coordinator: coordinator)
        )

        let measured = host.sizeThatFits(
            in: CGSize(width: width, height: .greatestFiniteMagnitude)
        )

        #expect(measured.width <= width)
        #expect(measured.height == AppStyle.Layout.trainingSheetBilateralSessionHeight)
    }

    @Test("Ten sets stay inside the fixed sheet-session viewport")
    func tenSetsUseFixedScrollViewport() {
        let manySets = FitnessTestSupport.makeExercise(
            name: "Ten Sets",
            weight: 20,
            reps: 12,
            sets: 10,
            category: .abs
        )
        let coordinator = makeTrainingSessionCoordinator(for: manySets)
        let host = UIHostingController(
            rootView: TrainingSessionComponent(coordinator: coordinator)
        )

        let measured = host.sizeThatFits(
            in: CGSize(width: 393, height: CGFloat.greatestFiniteMagnitude)
        )
        let threeSetCoordinator = makeTrainingSessionCoordinator(
            for: FitnessTestSupport.makeExercise(
                name: "Three Sets",
                weight: 20,
                reps: 12,
                sets: 3,
                category: .abs
            )
        )
        let threeSetHost = UIHostingController(
            rootView: TrainingSessionComponent(coordinator: threeSetCoordinator)
        )
        let threeSetMeasured = threeSetHost.sizeThatFits(
            in: CGSize(width: 393, height: CGFloat.greatestFiniteMagnitude)
        )

        #expect(abs(measured.height - threeSetMeasured.height) < 0.001)
        #expect(coordinator.activeSetViewModel.setProgress.count == 10)
    }

}

@MainActor
@Suite("Bilateral training session — Snapshots", .tags(.snapshot), .serialized)
struct BilateralTrainingSessionSnapshotTests {
    @Test(
        "Standard training-sheet rail stays aligned at supported widths",
        arguments: [CGFloat(320), CGFloat(430)]
    )
    func standardTrainingSheetSessionSnapshot(width: CGFloat) throws {
        let standard = FitnessTestSupport.makeExercise(
            name: "Exercise 12",
            weight: 20,
            reps: 12,
            sets: 3,
            category: .abs
        )
        try assertTrainingSessionSnapshot(
            coordinator: makeTrainingSessionCoordinator(for: standard),
            width: width,
            height: AppStyle.Layout.trainingSheetStandardSessionHeight,
            name: "standard-\(Int(width))"
        )
    }

    @Test(
        "Bilateral training-sheet rail stays aligned at supported widths",
        arguments: [CGFloat(320), CGFloat(430)]
    )
    func bilateralTrainingSheetSessionSnapshot(width: CGFloat) throws {
        try assertTrainingSessionSnapshot(
            coordinator: makeTrainingSessionCoordinator(for: makeBilateralExercise()),
            width: width,
            height: AppStyle.Layout.trainingSheetBilateralSessionHeight,
            name: "bilateral-\(Int(width))"
        )
    }

    private func assertTrainingSessionSnapshot(
        coordinator: TrainingCoordinator,
        width: CGFloat,
        height: CGFloat,
        name: String,
        sourceLocation: SourceLocation = #_sourceLocation,
        function: StaticString = #function
    ) throws {
        let size = CGSize(width: width, height: height)
        let view = TrainingSessionComponent(
            coordinator: coordinator,
            muscleArtwork: try appAssetImage(named: "defaultAbsIcon")
        )
            .appColorTheme(.green)
            .environment(\.locale, Locale(identifier: "en_US"))
            .frame(width: width, height: height)
            .background(AppStyle.Color.backgroundColor)
        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .black

        SnapshotTesting.assertSnapshot(
            of: controller,
            as: .image(precision: 0.99, perceptualPrecision: 0.98, size: size),
            named: name,
            record: ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"
                ? .all
                : .never,
            file: #filePath,
            testName: "\(function)",
            line: UInt(sourceLocation.line)
        )
    }

}

@MainActor
private func assertSetCardSnapshot(
    width: CGFloat,
    filled: Bool,
    rightStepActive: Bool = false,
    executionMode: ExerciseExecutionMode = .bilateral,
    weight: Double = 20,
    reps: Int = 12,
    snapshotName: String? = nil,
    sourceLocation: SourceLocation = #_sourceLocation,
    file: StaticString = #filePath,
    function: StaticString = #function
) {
    let exercise = FitnessTestSupport.makeExercise(
        name: "Torso Rotation",
        weight: weight,
        reps: reps,
        sets: 3,
        category: .abs,
        executionMode: executionMode
    )
    let viewModel = ActiveSetViewModel()
    viewModel.startSet(for: exercise, category: .abs)

    if rightStepActive {
        viewModel.setProgress[0] = SetProgress(
            status: .completedDone,
            currentReps: exercise.reps,
            weight: exercise.weight,
            side: .left,
            logicalSetIndex: 0
        )
        viewModel.setProgress[1] = SetProgress(
            status: .inProgress,
            currentReps: exercise.reps,
            weight: exercise.weight,
            side: .right,
            logicalSetIndex: 0
        )
        viewModel.activeSetIndex = 1
    } else if filled {
        viewModel.setProgress = exercise.trainingSteps.map {
            SetProgress(
                status: .completedDone,
                currentReps: exercise.reps,
                weight: exercise.weight,
                side: $0.side,
                logicalSetIndex: $0.logicalSetIndex
            )
        }
    }

    let height: CGFloat = executionMode == .bilateral
        ? AppStyle.Layout.trainingSheetBilateralSetViewportHeight
        : 160
    let size = CGSize(width: width, height: height)
    let content = SimpleActiveSetView(
        exercise: exercise,
        setProgress: .constant(viewModel.setProgress),
        viewModel: viewModel
    )
    let view = VStack(spacing: 0) {
        content
            .frame(width: size.width, alignment: .top)
        Spacer(minLength: 0)
    }
    .appColorTheme(.green)
    .environment(\.locale, Locale(identifier: "en_US"))
    .frame(width: size.width, height: size.height, alignment: .top)
    .clipped()
    .background(AppStyle.Color.backgroundColor)

    let controller = UIHostingController(rootView: view)
    controller.view.frame = CGRect(origin: .zero, size: size)
    controller.view.backgroundColor = .black

    let shouldRecord = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1"

    SnapshotTesting.assertSnapshot(
        of: controller,
        as: .image(precision: 0.99, perceptualPrecision: 0.98, size: size),
        named: snapshotName
            ?? "\(rightStepActive ? "right-active" : (filled ? "filled" : "empty"))-\(Int(width))",
        record: shouldRecord ? .all : .never,
        file: file,
        testName: "\(function)",
        line: UInt(sourceLocation.line)
    )
}

@Suite("Bilateral training card — Snapshots", .tags(.snapshot), .serialized)
@MainActor
struct BilateralTrainingCardSnapshotTests {
    @Test(
        "Empty reps remain readable at compact, regular, and large widths",
        arguments: [CGFloat(320)]
    )
    func empty(width: CGFloat) {
        assertSetCardSnapshot(width: width, filled: false)
    }

    @Test(
        "Filled reps remain readable at compact, regular, and large widths",
        arguments: [CGFloat(320), CGFloat(430)]
    )
    func filled(width: CGFloat) {
        assertSetCardSnapshot(width: width, filled: true)
    }

    @Test(
        "Standard KG and reps rhythm stays unchanged",
        arguments: [CGFloat(320)]
    )
    func standardFilled(width: CGFloat) {
        assertSetCardSnapshot(
            width: width,
            filled: true,
            executionMode: .standard
        )
    }

    @Test("Left set number stays highlighted while Right is active")
    func rightStepActive() {
        assertSetCardSnapshot(
            width: 393,
            filled: false,
            rightStepActive: true
        )
    }

    @Test("Longest formatted weight and maximum reps stay inside the compact pair row")
    func compactBoundaryValues() {
        assertSetCardSnapshot(
            width: 320,
            filled: true,
            weight: 299.5,
            reps: 50,
            snapshotName: "boundary-320"
        )
    }
}
#endif
