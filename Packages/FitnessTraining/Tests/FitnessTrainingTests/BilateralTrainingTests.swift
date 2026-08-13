import FitnessCore
import FitnessAnalytics
import FitnessTestSupport
import FitnessTrainingTestSupport
import FitnessUI
import SnapshotTesting
import SwiftUI
import Testing
@testable import FitnessTraining
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Suite("Bilateral training", .tags(.fast), .serialized)
struct BilateralTrainingTests {
    private func exercise() -> Exercise {
        FitnessTestSupport.makeExercise(
            name: "Torso Rotation",
            weight: 20,
            reps: 12,
            sets: 3,
            category: .abs,
            executionMode: .bilateral
        )
    }

    private func sessionCoordinator(for exercise: Exercise) -> TrainingCoordinator {
        let coordinator = TrainingCoordinator(
            findCategory: { _ in exercise.category },
            onExerciseUpdate: { _, _ in },
            onExerciseReset: { _, _ in },
            analyticsViewModel: AnalyticsViewModel(storageService: StubAnalyticsStorage())
        )
        coordinator.startTraining(for: exercise)
        return coordinator
    }

    @Test("Three logical sets expand to L1 R1 L2 R2 L3 R3")
    func createsPairwiseSteps() {
        let sut = ActiveSetViewModel()
        sut.startSet(for: exercise(), category: .abs)

        #expect(sut.setProgress.count == 6)
        #expect(sut.setProgress.map(\.logicalSetIndex) == [0, 0, 1, 1, 2, 2])
        #expect(sut.setProgress.map(\.side) == [.left, .right, .left, .right, .left, .right])
    }

    @Test("Finish is unavailable until the final right step")
    func finishesOnlyAfterRightThree() {
        let sut = ActiveSetViewModel()
        let useCase = CompleteSetUseCase()
        sut.startSet(for: exercise(), category: .abs)

        for _ in 0..<5 {
            #expect(useCase.execute(activeSetViewModel: sut))
            #expect(!sut.isLastSetCompleted)
        }
        #expect(sut.activeSetIndex == 5)
        #expect(sut.setProgress[5].side == .right)

        #expect(useCase.execute(activeSetViewModel: sut))
        #expect(sut.isLastSetCompleted)
        #expect(sut.currentSet == 6)
    }

    @Test("Less values and picker memory stay independent per side")
    func sideAdjustmentsAreIndependent() {
        let sut = ActiveSetViewModel()
        sut.startSet(for: exercise(), category: .abs)

        sut.startEditingSet(index: 0, mode: .less)
        sut.updateCurrentReps(8, 18)
        sut.isEditing = false
        sut.startNextSet()

        sut.startEditingSet(index: 1, mode: .less)
        sut.updateCurrentReps(10, 19)
        sut.isEditing = false
        sut.startNextSet()

        #expect(sut.setProgress[0].side == .left)
        #expect(sut.setProgress[0].currentReps == 8)
        #expect(sut.setProgress[1].side == .right)
        #expect(sut.setProgress[1].currentReps == 10)

        sut.startEditingSet(index: 2, mode: .less)
        #expect(sut.repsInput == "8")
        #expect(sut.weightInput == "18")
        sut.isEditing = false
        sut.pendingEditIndex = nil

        sut.startEditingSet(index: 3, mode: .less)
        #expect(sut.repsInput == "10")
        #expect(sut.weightInput == "19")
    }

    @Test("Editing an older side does not move the active step")
    func olderStepEditDoesNotAdvance() {
        let sut = ActiveSetViewModel()
        sut.startSet(for: exercise(), category: .abs)
        sut.completeCurrentSet()
        sut.startNextSet()
        sut.completeCurrentSet()
        sut.startNextSet()
        #expect(sut.currentSet == 2)

        sut.startEditingSet(index: 0, mode: .edit)
        sut.updateCurrentReps(11, 20)

        #expect(sut.currentSet == 2)
        #expect(sut.activeSetIndex == 2)
        #expect(sut.setProgress[0].side == .left)
        #expect(sut.setProgress[0].logicalSetIndex == 0)
    }

    @Test("Achievement entry follows the active bilateral side")
    func achievementFollowsActiveSide() {
        let sut = ActiveSetViewModel()
        sut.startSet(for: exercise(), category: .abs)

        sut.startRecordingAchievement(index: 1)
        #expect(sut.isEditing == false)

        sut.startRecordingAchievement(index: 0)
        sut.updateCurrentReps(12, 20)
        #expect(sut.setProgress[0].status == .completedDone)
        #expect(sut.setProgress[0].side == .left)
        #expect(sut.setProgress[0].logicalSetIndex == 0)

        sut.isEditing = false
        sut.pendingEditIndex = nil
        sut.startNextSet()
        #expect(sut.activeSetIndex == 1)
        #expect(sut.setProgress[1].side == .right)
        #expect(sut.setProgress[1].logicalSetIndex == 0)

        sut.startRecordingAchievement(index: 1)
        #expect(sut.editMode == .achievement)
        #expect(sut.pendingEditIndex == 1)
    }

    @Test("Quick Done completes all six steps with metadata")
    func quickDoneCompletesAllSteps() {
        let sut = ActiveSetViewModel()
        sut.startQuickDone(for: exercise(), category: .abs)

        #expect(sut.setProgress.count == 6)
        #expect(sut.setProgress.allSatisfy { $0.status == .completedDone })
        #expect(sut.setProgress.map(\.side) == [.left, .right, .left, .right, .left, .right])
        #expect(sut.isLastSetCompleted)
    }

    @Test("Weight progression requires all six bilateral steps")
    func progressionRequiresBothSides() {
        let exercise = exercise()
        let sut = ExerciseWeightProgressionUseCase()
        let completed = exercise.trainingSteps.map {
            SetProgress(
                status: .completedMore,
                currentReps: 12,
                weight: 22,
                side: $0.side,
                logicalSetIndex: $0.logicalSetIndex
            )
        }

        #expect(sut.execute(exercise: exercise, setProgress: completed).weight == 22)
        #expect(sut.execute(exercise: exercise, setProgress: Array(completed.dropLast())).weight == 20)
    }

    @Test("Cancel clears the complete bilateral session")
    func cancelClearsAllSteps() {
        let sut = ActiveSetViewModel()
        sut.startSet(for: exercise(), category: .abs)
        sut.completeCurrentSet()

        sut.cancelActiveSet()

        #expect(sut.currentExercise == nil)
        #expect(sut.setProgress.isEmpty)
        #expect(sut.currentSet == 0)
        #expect(sut.timerSeconds == 0)
    }

    @Test("Switching exercises resumes the same bilateral side and timer")
    func coordinatorResumesExactStep() {
        let bilateral = exercise()
        let other = FitnessTestSupport.makeExercise(name: "Curl")
        let clock = FakeClock()
        var timerServices: [TimerService] = []
        let coordinator = TrainingCoordinator(
            findCategory: { _ in .arms },
            onExerciseUpdate: { _, _ in },
            onExerciseReset: { _, _ in },
            analyticsViewModel: AnalyticsViewModel(storageService: StubAnalyticsStorage()),
            sessionFactory: {
                let timerService = TimerService(
                    clock: clock,
                    tickInterval: .seconds(60)
                )
                timerServices.append(timerService)
                return ActiveSetViewModel(timerService: timerService)
            }
        )

        coordinator.startTraining(for: bilateral)
        let bilateralSession = coordinator.activeSetViewModel
        let bilateralTimer = timerServices[0]
        coordinator.completeSet()
        clock.advance(by: 5)
        let timerBeforeSwitch = bilateralTimer.elapsedSeconds()
        #expect(coordinator.activeSetViewModel.setProgress[1].side == .right)

        coordinator.startTraining(for: other)
        let result = coordinator.startTraining(for: bilateral)

        guard case .resumed? = result else {
            Issue.record("Expected bilateral session to resume")
            return
        }
        #expect(coordinator.activeSetViewModel === bilateralSession)
        #expect(coordinator.activeSetViewModel.activeSetIndex == 1)
        #expect(coordinator.activeSetViewModel.setProgress[1].side == .right)
        #expect(bilateralTimer.elapsedSeconds() == timerBeforeSwitch)
    }

    @Test("Left set number stays active while its right step is active")
    func bilateralPairSharesSetNumberHighlight() {
        let viewModel = ActiveSetViewModel()
        viewModel.startSet(for: exercise(), category: .abs)
        let progress = viewModel.setProgress

        #expect(
            SetRowHighlightResolver.isActiveSetNumber(
                rowIndex: 0,
                progress: progress[0],
                activeSetIndex: 1,
                allProgress: progress,
                placement: .bilateralLeft
            )
        )
        #expect(
            !SetRowHighlightResolver.isActiveSetNumber(
                rowIndex: 2,
                progress: progress[2],
                activeSetIndex: 1,
                allProgress: progress,
                placement: .bilateralLeft
            )
        )
        #expect(
            !SetRowHighlightResolver.isActiveSetNumber(
                rowIndex: 0,
                progress: progress[0],
                activeSetIndex: 1,
                allProgress: progress,
                placement: .standard
            )
        )
        #expect(
            !SetRowHighlightResolver.isActiveSetNumber(
                rowIndex: 0,
                progress: progress[0],
                activeSetIndex: progress.endIndex,
                allProgress: progress,
                placement: .bilateralLeft
            )
        )

        let progressWithoutSideMetadata = [
            SetProgress(status: .completedDone, currentReps: 12, weight: 20),
            SetProgress(status: .inProgress, currentReps: 12, weight: 20)
        ]
        #expect(
            !SetRowHighlightResolver.isActiveSetNumber(
                rowIndex: 0,
                progress: progressWithoutSideMetadata[0],
                activeSetIndex: 1,
                allProgress: progressWithoutSideMetadata,
                placement: .bilateralLeft
            )
        )
    }

    #if canImport(UIKit)
    @Test(
        "Bilateral card fits compact, regular, and large widths",
        arguments: [CGFloat(320), CGFloat(393), CGFloat(430)]
    )
    func bilateralCardFits(width: CGFloat) {
        let bilateral = exercise()
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
        let bilateral = exercise()
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
        let coordinator = sessionCoordinator(for: standard)
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
        let coordinator = sessionCoordinator(for: exercise())
        let host = UIHostingController(
            rootView: TrainingSessionComponent(coordinator: coordinator)
        )

        let measured = host.sizeThatFits(
            in: CGSize(width: width, height: .greatestFiniteMagnitude)
        )

        #expect(measured.width <= width)
        #expect(measured.height == AppStyle.Layout.trainingSheetBilateralSessionHeight)
    }

    @Test(
        "Standard training-sheet rail stays aligned at supported widths",
        arguments: [CGFloat(320), CGFloat(393), CGFloat(430)]
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
            coordinator: sessionCoordinator(for: standard),
            width: width,
            height: AppStyle.Layout.trainingSheetStandardSessionHeight,
            name: "standard-\(Int(width))"
        )
    }

    @Test(
        "Bilateral training-sheet rail stays aligned at supported widths",
        arguments: [CGFloat(320), CGFloat(393), CGFloat(430)]
    )
    func bilateralTrainingSheetSessionSnapshot(width: CGFloat) throws {
        try assertTrainingSessionSnapshot(
            coordinator: sessionCoordinator(for: exercise()),
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

    @Test("Ten sets stay inside the fixed sheet-session viewport")
    func tenSetsUseFixedScrollViewport() {
        let manySets = FitnessTestSupport.makeExercise(
            name: "Ten Sets",
            weight: 20,
            reps: 12,
            sets: 10,
            category: .abs
        )
        let coordinator = sessionCoordinator(for: manySets)
        let host = UIHostingController(
            rootView: TrainingSessionComponent(coordinator: coordinator)
        )

        let measured = host.sizeThatFits(
            in: CGSize(width: 393, height: CGFloat.greatestFiniteMagnitude)
        )
        let threeSetCoordinator = sessionCoordinator(
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

    @Test(
        "Bilateral columns share equal value width at every supported width",
        arguments: [CGFloat(320), CGFloat(393), CGFloat(430)]
    )
    func bilateralColumnMetrics(width: CGFloat) {
        let metrics = BilateralSetLayoutMetrics(containerWidth: width)
        let badgeSlot = AppStyle.Layout.setRowBadgeSize
            + AppStyle.Layout.bilateralColumnSpacing
        let usedWidth = metrics.leftColumnWidth
            + metrics.rightColumnWidth

        #expect(abs(usedWidth - width) < 0.001)
        #expect(abs((metrics.leftColumnWidth - metrics.rightColumnWidth) - badgeSlot) < 0.001)
        #expect(metrics.rightColumnWidth >= 130)
    }

    @Test("Bilateral pair keeps surplus between Left and Right")
    func bilateralPairAnchorsToOuterInsets() {
        let metrics = BilateralPairLayoutMetrics(
            containerWidth: 300,
            leftIdealWidth: 110,
            rightIdealWidth: 80,
            badgeSlotWidth: 30,
            minimumPairSpacing: 12
        )

        #expect(metrics.leftWidth == 110)
        #expect(metrics.rightWidth == 80)
        #expect(metrics.resolvedPairSpacing == 110)
        #expect(
            metrics.leftWidth
                + metrics.resolvedPairSpacing
                + metrics.rightWidth == 300
        )
    }

    @Test("Tight bilateral pair keeps symmetric value widths")
    func bilateralPairCompressionRemainsSymmetric() {
        let metrics = BilateralPairLayoutMetrics(
            containerWidth: 200,
            leftIdealWidth: 130,
            rightIdealWidth: 110,
            badgeSlotWidth: 30,
            minimumPairSpacing: 4
        )

        #expect(metrics.leftWidth - 30 == metrics.rightWidth)
        #expect(metrics.resolvedPairSpacing == 4)
        #expect(
            metrics.leftWidth
                + metrics.resolvedPairSpacing
                + metrics.rightWidth == 200
        )
    }

    @Test("Only standard and bilateral-left rows show a set number")
    func bilateralRightOmitsSetNumber() {
        #expect(SetRowPlacement.standard.showsSetNumber)
        #expect(SetRowPlacement.bilateralLeft.showsSetNumber)
        #expect(!SetRowPlacement.bilateralRight.showsSetNumber)
    }

    @Test("Bilateral metric spacing matches compact and standard rhythms")
    func bilateralMetricSpacingTokens() {
        #expect(AppStyle.Layout.setRowChipHorizontalPadding == 8)
        #expect(AppStyle.Layout.bilateralMetricSpacingTight == 2)
        #expect(AppStyle.Layout.bilateralMetricSpacingCompact == 4)
        #expect(AppStyle.Layout.bilateralMetricSpacingComfortable == 8)
        #expect(AppStyle.Layout.bilateralPairSpacingTight == 4)
        #expect(AppStyle.Layout.bilateralPairSpacingCompact == 8)
        #expect(AppStyle.Layout.bilateralPairSpacingComfortable == 12)
        #expect(AppStyle.Layout.bilateralMetricChipHorizontalPaddingTight == 2)
        #expect(AppStyle.Layout.bilateralMetricChipHorizontalPadding == 4)
    }
    #endif
}

#if canImport(UIKit)
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
        arguments: [CGFloat(320), CGFloat(393), CGFloat(430)]
    )
    func empty(width: CGFloat) {
        assertSetCardSnapshot(width: width, filled: false)
    }

    @Test(
        "Filled reps remain readable at compact, regular, and large widths",
        arguments: [CGFloat(320), CGFloat(393), CGFloat(430)]
    )
    func filled(width: CGFloat) {
        assertSetCardSnapshot(width: width, filled: true)
    }

    @Test(
        "Standard KG and reps rhythm stays unchanged",
        arguments: [CGFloat(320), CGFloat(430)]
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
