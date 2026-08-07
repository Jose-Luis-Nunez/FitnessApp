import FitnessCore
import FitnessStorage
import FitnessTestSupport
import FitnessUI
import SnapshotTesting
import SwiftUI
import Testing
@testable import FitnessTraining

#if canImport(UIKit)
import UIKit

@Suite("Feedback sheet — Snapshots", .tags(.snapshot), .serialized)
@MainActor
struct FeedbackSheetViewSnapshotTests {
    @Test func compact() {
        let viewModel = makeViewModel()
        assertFeedbackSnapshot(
            viewModel: viewModel,
            size: CGSize(width: 393, height: 480),
            named: "compact"
        )
    }

    @Test func expandedWithPain() throws {
        let viewModel = makeViewModel()
        viewModel.symptoms = [.pain]
        viewModel.painRegions = [.chestLeft]
        viewModel.energyLevel = 3
        let painImages: [BodyRegion: Image] = [
            .chestLeft: try appAssetImage(named: "chest_left"),
            .chestRight: try appAssetImage(named: "chest_right"),
        ]

        assertFeedbackSnapshot(
            viewModel: viewModel,
            size: CGSize(width: 393, height: 852),
            named: "expanded-pain",
            painRegionImageProvider: { painImages[$0] ?? Image(systemName: "xmark") }
        )
    }

    private func makeViewModel() -> FeedbackViewModel {
        let storage = InMemoryFeedbackStorage()
        return FeedbackViewModel(
            exerciseId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            sessionId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            exerciseCategory: .chest,
            saveFeedbackUseCase: SaveFeedbackUseCase(feedbackStorage: storage),
            feedbackStorage: storage
        )
    }

    private func assertFeedbackSnapshot(
        viewModel: FeedbackViewModel,
        size: CGSize,
        named name: String,
        painRegionImageProvider: @escaping (BodyRegion) -> Image = {
            Image($0.iconAssetName)
        },
        sourceLocation: SourceLocation = #_sourceLocation,
        function: StaticString = #function
    ) {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: AppStyle.CornerRadius.sheet,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: AppStyle.CornerRadius.sheet,
            style: .continuous
        )
        let view = FeedbackSheetView(
            viewModel: viewModel,
            isPresented: .constant(true),
            painRegionImageProvider: painRegionImageProvider
        )
        .frame(width: size.width, height: size.height)
        .background {
            ZStack {
                LinearGradient(
                    colors: [
                        AppStyle.Color.idleCardSoft,
                        AppStyle.Color.idleCardBackground,
                        AppStyle.Color.idleCardDark,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [AppStyle.Color.idleCardInnerGlow, .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 200
                )
            }
        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        AppStyle.Color.idleCardBorderLight,
                        AppStyle.Color.idleCardBorderDark,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: AppStyle.Layout.idleCardBorderWidth
            )
        }
        .environment(
            \.safeAreaInsets,
            EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 0)
        )
        .environment(\.colorScheme, .dark)
        .environment(\.locale, Locale(identifier: "en_US"))

        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .black
        let window = UIWindow(frame: controller.view.frame)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        defer { window.isHidden = true }

        SnapshotTesting.assertSnapshot(
            of: controller,
            as: .wait(
                for: 0.1,
                on: .image(
                    precision: 0.99,
                    perceptualPrecision: 0.98,
                    size: size
                )
            ),
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
#endif
