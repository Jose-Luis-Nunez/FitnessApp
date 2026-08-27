import SwiftUI
import FitnessUI
import UniformTypeIdentifiers
import FitnessResources

/// Edge-to-edge Add Friend form presented inside a transparent full-screen host.
///
/// A native medium sheet is intentionally avoided: on iOS 26 its Liquid Glass
/// presentation adds system-owned side and bottom insets. The training and
/// feedback sheets use app-owned geometry for the same reason. Keeping this
/// surface inside a full-screen host lets the gradient reach both horizontal
/// edges and the physical bottom while preserving the familiar bottom-sheet
/// interaction.
struct AddFriendSheet: View {
    private enum AID {
        static let nameInput = "id_friends_add_name_input"
        static let fileButton = "id_friends_add_file_button"
    }

    @Binding var isPresented: Bool
    @State private var viewModel: AddFriendViewModel
    @FocusState private var nameFieldFocused: Bool
    @Environment(\.appColorTheme) private var appColorTheme

    private var profileColors: ProfileColorTheme { appColorTheme.profile }
    @GestureState private var dragTranslation: CGFloat = 0

    private static let friendShareType = UTType(exportedAs: "com.fitnesspro.friend-share")
    private static let contentHeight: CGFloat = 440
    private static let fileButtonHeight: CGFloat = 64

    init(
        isPresented: Binding<Bool>,
        initialJSON: String? = nil,
        fileName: String? = nil,
        importCoordinator: FriendImportCoordinator? = nil,
        onAdded: @escaping () -> Void
    ) {
        _isPresented = isPresented
        _viewModel = State(initialValue: AddFriendViewModel(
            initialJSON: initialJSON,
            fileName: fileName,
            importCoordinator: importCoordinator,
            onAdded: onAdded,
            onDismiss: { isPresented.wrappedValue = false }
        ))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Button {
                    isPresented = false
                } label: {
                    Color.black.opacity(AppStyle.Opacity.overlayBackdrop)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .ignoresSafeArea()
                .accessibilityLabel(AppText.friendCancelAdding)

                sheetContent(geometry: geometry)
                    .offset(y: max(0, dragTranslation))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .bottom)
        }
        .animation(.easeInOut(duration: 0.15), value: nameFieldFocused)
        .preferredColorScheme(.dark)
        .presentationBackground(.clear)
        .fileImporter(
            isPresented: $viewModel.showingFileImporter,
            allowedContentTypes: [Self.friendShareType],
            allowsMultipleSelection: false,
            onCompletion: { result in
                guard case let .success(urls) = result,
                      let url = urls.first else {
                    viewModel.fileSelectionFailed()
                    return
                }
                viewModel.friendFileSelected(url)
            },
            onCancellation: {}
        )
    }

    private func sheetContent(geometry: GeometryProxy) -> some View {
        let bottomInset = geometry.safeAreaInsets.bottom
        let maximumHeight = max(
            1,
            geometry.size.height
                - geometry.safeAreaInsets.top
                + bottomInset
                - AppStyle.Layout.trainingSheetMinimumBackdropHeight
        )
        let visibleHeight = min(Self.contentHeight + bottomInset, maximumHeight)

        return VStack(spacing: 0) {
            sheetHeader

            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppStyle.Padding.sectionSpacing) {
                    Text(AppText.friendAdd)
                        .font(AppStyle.Font.sheetTitle)
                        .foregroundColor(AppStyle.Color.white)
                        .frame(maxWidth: .infinity, alignment: .center)

                    instructionSection
                    nameSection
                    fileSelectionButton

                    if let msg = viewModel.errorMessage {
                        Text(msg.localizedResource)
                            .font(AppStyle.Font.profileCardTitle)
                            .foregroundColor(AppStyle.Color.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, AppStyle.Padding.horizontal)
                .padding(.bottom, AppStyle.Padding.sectionSpacing)
            }
            .scrollIndicators(.hidden)

            if !nameFieldFocused {
                ProfileActionRow(
                    secondaryLabel: AppText.actionCancel,
                    primaryLabel: AppText.actionSave,
                    isPrimaryEnabled: !viewModel.isSaveDisabled,
                    secondaryAccessibilityIdentifier: "id_friends_add_cancel",
                    primaryAccessibilityIdentifier: "id_friends_add_save",
                    onSecondary: { isPresented = false },
                    onPrimary: { viewModel.saveTapped() }
                )
                .padding(.horizontal, AppStyle.Padding.horizontal)
                .padding(.top, AppStyle.Padding.sectionSpacing)
                .padding(.bottom, max(AppStyle.Padding.card, bottomInset))
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: visibleHeight, alignment: .top)
        .background { trainingSheetGradient }
        .clipShape(AmbientSheetSurface.shape)
        .overlay(alignment: .top) { sheetDragRegion }
    }

    private var sheetHeader: some View {
        Capsule()
            .fill(Color.white.opacity(AppStyle.Opacity.grabberHandle))
            .frame(
                width: AppStyle.Layout.grabberWidth,
                height: AppStyle.Layout.grabberHeight
            )
            .padding(.top, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
    }

    private var sheetDragRegion: some View {
        Rectangle()
            .fill(Color.white.opacity(0.001))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Rectangle())
            .gesture(sheetDragGesture)
            .accessibilityHidden(true)
    }

    private var sheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                if value.translation.height > 80 {
                    isPresented = false
                }
            }
    }

    private var trainingSheetGradient: some View {
        AmbientSheetSurface.shape
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
            .ignoresSafeArea(edges: .bottom)
    }

    private var instructionSection: some View {
        VStack(alignment: .leading, spacing: AppStyle.Padding.cardVertical) {
            Text(AppText.friendImportTrainingData)
                .font(AppStyle.Font.profileInputLabel)
                .foregroundColor(profileColors.title)

            Text(AppText.friendImportInstructions)
                .font(AppStyle.Font.detailCaption)
                .foregroundColor(profileColors.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nameSection: some View {
        CardTextField(
            label: AppText.friendName,
            placeholder: AppText.friendNamePlaceholder,
            text: $viewModel.friendName,
            isFocused: $nameFieldFocused,
            accessibilityIdentifier: AID.nameInput
        )
    }

    private var fileSelectionButton: some View {
        Button {
            viewModel.chooseFileTapped()
        } label: {
            HStack(spacing: AppStyle.Padding.card) {
                Image(systemName: viewModel.hasData ? "checkmark.circle.fill" : "doc.badge.plus")
                    .font(AppStyle.Font.sheetSectionLabel)
                    .foregroundColor(profileColors.accent)

                Text(AppText.friendChooseFile)
                    .font(AppStyle.Font.sheetSectionLabel)
                    .foregroundColor(profileColors.title)
                    .lineLimit(1)

                Spacer()

                Image(systemName: viewModel.hasData ? "arrow.triangle.2.circlepath" : "chevron.right")
                    .font(AppStyle.Font.defaultFont)
                    .foregroundColor(profileColors.accent)
            }
            .padding(.horizontal, AppStyle.Padding.card)
            .frame(maxWidth: .infinity, minHeight: Self.fileButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.defaultButton)
                    .fill(profileColors.innerBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppStyle.CornerRadius.defaultButton)
                    .stroke(
                        viewModel.hasData ? profileColors.accent : profileColors.innerStroke,
                        lineWidth: AppStyle.Layout.profileSurfaceBorderWidth
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AID.fileButton)
        .accessibilityValue(fileSelectionAccessibilityValue)
    }

    private var fileSelectionAccessibilityValue: LocalizedStringResource {
        guard viewModel.hasData else { return AppText.commonNotSelected }
        guard let fileName = viewModel.fileName else { return AppText.commonSelected }
        return AppText.friendSelectedFile(name: fileName)
    }
}

private extension FriendImportFailure {
    var localizedResource: LocalizedStringResource {
        switch self {
        case .unreadableFile: AppText.friendFileUnreadable
        case .invalidJSON: AppText.errorInvalidWorkoutJson
        case .newerVersion: AppText.errorNewerWorkoutVersion
        case .incompleteData: AppText.errorIncompleteWorkout
        case .savingFailed: AppText.errorSavingFailed
        }
    }
}
