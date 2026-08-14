import SwiftUI
import FitnessCore
import FitnessResources
import FitnessUI

/// Presents post-exercise feedback as a separate, draggable sheet above the
/// training flow. Its compact rest height comes directly from the currently
/// rendered training sheet so both surfaces occupy the exact same frame.
///
/// A custom presentation surface is intentional here. Starting with iOS 26,
/// native sheets add system-controlled Liquid Glass insets around small custom
/// detents. Those insets make the content narrower and shorter than the
/// requested detent and impose a different corner radius. Rendering the sheet
/// inside the existing full-width presentation layer preserves the two rest
/// states and drag interaction while allowing its compact geometry and surface
/// to match the training sheet exactly.
public struct FeedbackSheetComponent: View {
    @Bindable public var coordinator: TrainingCoordinator
    public let category: MuscleCategoryGroup?
    public let initialDetentHeight: CGFloat

    @Environment(UIOverlayState.self) private var overlayState
    @State private var viewModel: FeedbackViewModel?
    @State private var presentationState = FeedbackSheetPresentationState()
    @GestureState private var dragTranslation: CGFloat = 0

    public init(
        coordinator: TrainingCoordinator,
        category: MuscleCategoryGroup? = nil,
        initialDetentHeight: CGFloat = 380
    ) {
        self.coordinator = coordinator
        self.category = category
        self.initialDetentHeight = initialDetentHeight
    }

    private var compactHeight: CGFloat {
        max(1, initialDetentHeight)
    }

    public var body: some View {
        GeometryReader { geometry in
            if coordinator.isFeedbackSheetPresented, let vm = viewModel {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(AppStyle.Opacity.overlayBackdrop)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { dismissFeedback() }
                        .accessibilityElement()
                        .accessibilityLabel(AppText.feedbackCancel)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { dismissFeedback() }
                        .accessibilityIdentifier(TrainingIDs.feedbackSheetBackdrop)

                    feedbackSheet(viewModel: vm, geometry: geometry)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .bottom)
                .zIndex(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(coordinator.isFeedbackSheetPresented)
        .animation(
            .easeInOut(duration: 0.25),
            value: coordinator.isFeedbackSheetPresented
        )
        .onAppear {
            if coordinator.isFeedbackSheetPresented {
                handlePresentationChange(true)
            }
        }
        .onChange(of: coordinator.isFeedbackSheetPresented) { _, isPresented in
            handlePresentationChange(isPresented)
        }
    }

    private func feedbackSheet(
        viewModel: FeedbackViewModel,
        geometry: GeometryProxy
    ) -> some View {
        let compactPresentationHeight = compactHeight + geometry.safeAreaInsets.bottom
        let largeHeight = max(
            compactPresentationHeight,
            geometry.size.height
                - geometry.safeAreaInsets.top
                + geometry.safeAreaInsets.bottom
        )
        let visibleHeight = presentationState.height(
            compactHeight: compactPresentationHeight,
            largeHeight: largeHeight,
            dragTranslation: dragTranslation
        )

        return FeedbackSheetView(
            viewModel: viewModel,
            isPresented: presentationBinding
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: visibleHeight, alignment: .top)
        .background { feedbackSheetSurface }
        .clipShape(feedbackSheetShape)
        .overlay { feedbackSheetBorder }
        .overlay(alignment: .top) { feedbackDragRegion }
        .offset(y: presentationState.dismissOffset(dragTranslation: dragTranslation))
        .simultaneousGesture(compactSheetDragGesture)
        .animation(.interactiveSpring, value: presentationState.isExpanded)
        .animation(.interactiveSpring, value: viewModel.symptoms.isEmpty)
        .onChange(of: viewModel.symptoms.isEmpty) { _, isEmpty in
            presentationState.synchronizeWithSymptoms(isEmpty: isEmpty)
        }
    }

    private var feedbackDragGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let result = presentationState.endDrag(
                    translation: value.translation.height,
                    source: .header
                )
                if result == .dismiss {
                    dismissFeedback()
                }
            }
    }

    /// The compact form does not need to scroll, so an upward swipe from its
    /// content can expand it even when the drag does not begin on the header.
    /// Once expanded, the ScrollView keeps its normal behavior and the header
    /// hit region controls collapse and dismissal.
    private var compactSheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onEnded { value in
                guard !presentationState.isExpanded,
                      value.translation.height < -40 else { return }

                _ = presentationState.endDrag(
                    translation: value.translation.height,
                    source: .compactSurface
                )
            }
    }

    private var feedbackDragRegion: some View {
        Rectangle()
            .fill(Color.white.opacity(0.001))
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .contentShape(Rectangle())
            .gesture(feedbackDragGesture)
            .accessibilityHidden(true)
    }

    private var presentationBinding: Binding<Bool> {
        Binding(
            get: { coordinator.isFeedbackSheetPresented },
            set: { newValue in
                if !newValue { dismissFeedback() }
            }
        )
    }

    private func handlePresentationChange(_ isPresented: Bool) {
        overlayState.isEditingSheetVisible = isPresented

        guard isPresented, let exercise = coordinator.currentExercise else {
            if !isPresented {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel = nil
                }
            }
            return
        }

        let sessionId = coordinator.currentSessionId(for: exercise.id) ?? UUID()
        let newViewModel = FeedbackViewModel(
            exerciseId: exercise.id,
            sessionId: sessionId,
            exerciseCategory: category,
            draftStore: coordinator.draftStore,
            currentFocusedExerciseId: { [weak coordinator] in
                coordinator?.focusedExerciseId
            }
        )
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel = newViewModel
            presentationState.synchronizeWithSymptoms(
                isEmpty: newViewModel.symptoms.isEmpty
            )
        }
    }

    private func dismissFeedback() {
        withAnimation(.easeInOut(duration: 0.25)) {
            coordinator.closeFeedback()
        }
    }

    private var feedbackSheetShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: AppStyle.CornerRadius.sheet,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: AppStyle.CornerRadius.sheet,
            style: .continuous
        )
    }

    private var feedbackSheetSurface: some View {
        ZStack {
            feedbackSheetShape
                .fill(
                    LinearGradient(
                        colors: [
                            AppStyle.Color.idleCardSoft,
                            AppStyle.Color.idleCardBackground,
                            AppStyle.Color.idleCardDark,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            feedbackSheetShape
                .fill(
                    RadialGradient(
                        colors: [
                            AppStyle.Color.idleCardInnerGlow,
                            .clear,
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var feedbackSheetBorder: some View {
        feedbackSheetShape
            .strokeBorder(
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
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
    }
}
