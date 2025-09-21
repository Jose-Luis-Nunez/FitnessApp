import SwiftUI

struct BottomActionBarView: View {
    let viewModel: BottomActionBarViewModel
    let onStart: () -> Void
    let onCompleteSet: () -> Void
    let onQuickDone: () -> Void
    let onCompleteAllQuickDone: () -> Void
    let onCategoryReset: () -> Void
    let onEditLess: () -> Void
    let onEditMore: () -> Void
    let onFinish: () -> Void
    let onAddExercise: () -> Void
    let onResetAllExercises: () -> Void
    // Note: Add/Reset are no longer rendered here; only core training controls remain
    
    // CENTRAL PICKER STATE
    @State private var isShowingEditPicker = false
    @State private var editMode: SetEditingMode = .less

    private let barHeight: CGFloat = 0
    private let backgroundColor = AppStyle.Color.backgroundColor

    var body: some View {
        ZStack(alignment: .bottom) {
            FloatingActionButtonsView(
                viewModel: viewModel,
                onStart: onStart,
                onCompleteSet: onCompleteSet,
                onQuickDone: onQuickDone,
                onCompleteAllQuickDone: onCompleteAllQuickDone,
                onCategoryReset: onCategoryReset,
                onEditLess: onEditLess,
                onEditMore: onEditMore,
                onFinish: onFinish,
                onAddExercise: onAddExercise,
                onResetAllExercises: onResetAllExercises,
                barHeight: barHeight,
                backgroundColor: backgroundColor
            )
        }
        .background(Color.clear)
        .zIndex(2)
    }
}

struct FloatingActionButtonsView: View {
    let viewModel: BottomActionBarViewModel
    let onStart: () -> Void
    let onCompleteSet: () -> Void
    let onQuickDone: () -> Void
    let onCompleteAllQuickDone: () -> Void
    let onCategoryReset: () -> Void
    let onEditLess: () -> Void
    let onEditMore: () -> Void
    let onFinish: () -> Void
    let onAddExercise: () -> Void
    let onResetAllExercises: () -> Void
    let barHeight: CGFloat
    let backgroundColor: Color

    private let buttonWidthRegular: CGFloat = 110
    private let buttonHeightRegular: CGFloat = 40
    private let buttonHeightLarge: CGFloat = 40
    // Narrower small buttons so the centered "Done" can breathe and align nicer
    private let smallButtonFixedWidth: CGFloat = 100
    private let verticalSpacing: CGFloat = 8
    private let topPadding: CGFloat = 10
    private let bottomPadding: CGFloat = 16
    
    private var rowCount: Int {
        var rows = 1
        if viewModel.showQuickDoneBeendenButton || viewModel.showQuickDoneDoneButton {
            rows = 2
        } else if viewModel.showSetControls && viewModel.currentSet == 0 {
            rows = 2
        }
        return rows
    }

    private var totalHeight: CGFloat {
        (buttonHeightRegular * CGFloat(rowCount)) + (verticalSpacing * CGFloat(rowCount - 1)) + bottomPadding
    }

    var body: some View {
        GeometryReader { geometry in
            // Content-Breite exakt wie die ActiveSetView: Bildschirmbreite minus Karten-Padding
            let contentWidth = geometry.size.width - (2 * AppStyle.Padding.card)
            let interItemSpacing: CGFloat = 12
            // Minimalbreite für Less/More, gut lesbar aber kompakt (kleiner, damit "Done" dominanter wird)
            let smallMinWidth: CGFloat = 84
            // Dominanter Done füllt die Restbreite exakt auf, sodass die Summe = contentWidth ist
            let doneComputedWidth = max(160, contentWidth - (2 * smallMinWidth) - (2 * interItemSpacing))

            ZStack(alignment: .bottom) {
                // No background pill here – only floating buttons
                VStack(spacing: verticalSpacing) {
                if viewModel.showQuickDoneBeendenButton {
                    actionButtonExtraLarge(
                        text: "Beenden",
                        textFont: AppStyle.Font.bottomBarButtons,
                        backgroundColor: AppStyle.Color.green,
                        fontColor: AppStyle.Color.white,
                        action: onFinish,
                        width: contentWidth
                    )
                } else if viewModel.showQuickDoneDoneButton {
                    actionButtonExtraLarge(
                        text: "All Done",
                        textFont: AppStyle.Font.bottomBarButtons,
                        backgroundColor: AppStyle.Color.primaryButton,
                        fontColor: AppStyle.Color.white,
                        action: onCompleteAllQuickDone,
                        width: contentWidth
                    )
                } else {
                    if viewModel.showSetControls && viewModel.currentSet == 0 {
                        actionButtonExtraLarge(
                            text: "Quick Done",
                            textFont: AppStyle.Font.bottomBarButtons,
                            backgroundColor: AppStyle.Color.exerciseCardBackground,
                            fontColor: AppStyle.Color.white,
                            action: onQuickDone,
                            width: contentWidth
                        )
                    }

                    HStack(spacing: interItemSpacing) {
                        // Add Exercise button removed from FAB bar; moved to mini menu

                        // Do not show initial "Start Training" in Category View context; only show for subsequent sets
                        if viewModel.showStartButton && (viewModel.currentSet != 0 || viewModel.didJustEditSet) {
                            actionButtonLarge(
                                text: viewModel.startButtonTitle,
                                textFont: AppStyle.Font.bottomBarButtons,
                                backgroundColor: AppStyle.Color.primaryButton,
                                fontColor: AppStyle.Color.white,
                                action: onStart
                            )
                        }

                        if viewModel.showSetControls {
                            // Less links mit Minimalbreite
                            actionButtonFixedLarge(
                                text: "Less",
                                textFont: AppStyle.Font.bottomBarButtons,
                                backgroundColor: AppStyle.Color.green,
                                fontColor: AppStyle.Color.white,
                                action: {
                                    onEditLess()
                                },
                                width: smallMinWidth
                            )

                            // Done füllt exakt die verbleibende Breite
                            actionButtonFixedLarge(
                                text: "Done",
                                textFont: AppStyle.Font.bottomBarButtons,
                                backgroundColor: AppStyle.Color.green,
                                fontColor: AppStyle.Color.white,
                                action: onCompleteSet,
                                width: doneComputedWidth
                            )

                            // More rechts mit Minimalbreite
                            actionButtonFixedLarge(
                                text: "More",
                                textFont: AppStyle.Font.bottomBarButtons,
                                backgroundColor: AppStyle.Color.green,
                                fontColor: AppStyle.Color.white,
                                action: {
                                    onEditMore()
                                },
                                width: smallMinWidth
                            )
                        }

                        // Reset button removed from FAB bar; moved to mini menu

                        if viewModel.showFinishButton {
                            actionButtonLarge(
                                text: "Beenden",
                                textFont: AppStyle.Font.bottomBarButtons,
                                backgroundColor: AppStyle.Color.green,
                                fontColor: AppStyle.Color.white,
                                action: onFinish
                            )
                        }
                    }
                    // Gleiche Breite wie "Quick Done" darüber
                    .frame(width: contentWidth, alignment: .center)
                }
                }
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
                .frame(width: contentWidth)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(width: geometry.size.width, height: totalHeight, alignment: .bottom)
        }
        .frame(height: totalHeight)
    }

    @ViewBuilder
    private func actionButtonLarge(
        text: String,
        textFont: Font,
        backgroundColor: Color,
        fontColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(textFont)
                .foregroundColor(fontColor)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: buttonHeightLarge, maxHeight: buttonHeightLarge)
                .padding(.horizontal, 12)
        }
        .background(backgroundColor)
        .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
    }

    @ViewBuilder
    private func actionButtonFixedLarge(
        text: String,
        textFont: Font,
        backgroundColor: Color,
        fontColor: Color,
        action: @escaping () -> Void,
        width: CGFloat
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(textFont)
                .foregroundColor(fontColor)
                .frame(width: width, height: buttonHeightLarge)
        }
        .background(backgroundColor)
        .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
    }
    @ViewBuilder
    private func actionButtonIntrinsicLarge(
        text: String,
        textFont: Font,
        backgroundColor: Color,
        fontColor: Color,
        action: @escaping () -> Void,
        minHorizontalPadding: CGFloat
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(textFont)
                .foregroundColor(fontColor)
                .padding(.horizontal, minHorizontalPadding)
                .frame(minHeight: buttonHeightLarge, maxHeight: buttonHeightLarge)
                .fixedSize()
        }
        .background(backgroundColor)
        .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
    }

    @ViewBuilder
    private func actionButtonMinimal(
        text: String,
        textFont: Font,
        backgroundColor: Color,
        fontColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(textFont)
                .foregroundColor(fontColor)
                .padding(.horizontal, 12)
                .frame(minHeight: buttonHeightLarge, maxHeight: buttonHeightLarge)
                .fixedSize()
        }
        .background(backgroundColor)
        .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
    }

    @ViewBuilder
    private func actionButtonSmall(
        text: String,
        textFont: Font,
        backgroundColor: Color,
        fontColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(textFont)
                .foregroundColor(fontColor)
                .frame(width: buttonWidthRegular / 1.5, height: buttonHeightRegular)
        }
        .background(backgroundColor)
        .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
    }

    @ViewBuilder
    private func actionButtonFixedSmall(
        text: String,
        textFont: Font,
        backgroundColor: Color,
        fontColor: Color,
        action: @escaping () -> Void,
        width: CGFloat
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(textFont)
                .foregroundColor(fontColor)
                .frame(width: width, height: buttonHeightRegular)
        }
        .background(backgroundColor)
        .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
    }

    @ViewBuilder
    private func actionButtonExtraLarge(
        text: String,
        textFont: Font,
        backgroundColor: Color,
        fontColor: Color,
        action: @escaping () -> Void,
        width: CGFloat
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(textFont)
                .foregroundColor(fontColor)
                .frame(width: width)
                .frame(minHeight: buttonHeightLarge, maxHeight: buttonHeightLarge)
        }
        .background(backgroundColor)
        .cornerRadius(AppStyle.CornerRadius.bottomBarButton)
    }
}
