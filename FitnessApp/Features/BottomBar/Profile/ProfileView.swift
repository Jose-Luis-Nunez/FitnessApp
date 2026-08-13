import SwiftUI
import FitnessUI
import FitnessProfile
import FitnessFriends

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var isBodyExpanded = false
    @AppStorage(DefaultIconColorScheme.storageKey) private var iconColorScheme: DefaultIconColorScheme = .green
    @Environment(\.profileColorTheme) private var profileColors
    @FocusState private var focusedField: ProfileField?

    enum ProfileField: Hashable {
        case nickname
    }

    var body: some View {
        ZStack {
            AppStyle.Color.backgroundColor.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: AppStyle.Padding.card) {
                        headerSection
                        nicknameSection
                        bodyDataSection
                        iconColorSection
                        FriendsSection()
                        SBahnDeparturesCardView(viewModel: viewModel.sbahnVM)
                        TramDeparturesCardView(viewModel: viewModel.tramVM)
                        Spacer(minLength: AppStyle.Layout.profileBottomSpacer)
                    }
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                    .padding(.top, AppStyle.Padding.titleTop)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: focusedField) { field in
                    guard let field else { return }
                    withAnimation {
                        proxy.scrollTo(field, anchor: .center)
                    }
                }
            }
        }
        // BMI is calculated locally on first expand. Server validation remains
        // explicit through Refresh or follows a real weight/height change.
        .alert("Error", isPresented: $viewModel.showNicknameAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Nickname cannot be empty.")
        }
    }

    // MARK: - Icon Color

    /// Lets the user switch the *default* category icons between the original
    /// (`green`) and the new `grey` variants. The app root maps this persisted
    /// preference into `ProfileColorTheme` and injects it through the SwiftUI
    /// environment, so profile components update without feature-model plumbing.
    private var iconColorSection: some View {
        ProfileCardContainer {
            HStack(spacing: AppStyle.Padding.card) {
                ProfileCardHeading("Default Icon Color")
                    .layoutPriority(1)

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    iconColorButton(for: .green)

                    Rectangle()
                        .fill(profileColors.divider)
                        .frame(width: AppStyle.Layout.separatorWidth, height: 24)

                    iconColorButton(for: .grey)
                }
                .frame(width: AppStyle.Layout.profileColorPickerWidth)
                .profileReadOnlyTileSurface()
                .accessibilityIdentifier("id_profile_icon_color_picker")
            }
        }
    }

    private func iconColorButton(for scheme: DefaultIconColorScheme) -> some View {
        let isSelected = iconColorScheme == scheme

        return Button {
            iconColorScheme = scheme
        } label: {
            Text(scheme.displayName)
                .font(AppStyle.Font.profileCardTitle)
                .foregroundColor(isSelected ? profileColors.title : profileColors.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: AppStyle.Layout.chipHeight)
                .background {
                    RoundedRectangle(
                        cornerRadius: AppStyle.CornerRadius.tile,
                        style: .continuous
                    )
                    .fill(isSelected ? profileColors.selectionBackground : .clear)
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: AppStyle.CornerRadius.tile,
                            style: .continuous
                        )
                        .stroke(
                            isSelected ? profileColors.selectionStroke : .clear,
                            lineWidth: AppStyle.Layout.darkSurfaceOutlineWidth
                        )
                    }
                }
        }
        .frame(maxWidth: .infinity, minHeight: AppStyle.Layout.minimumTapTargetSize)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityIdentifier("id_profile_icon_color_\(scheme.rawValue)")
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: AppStyle.DeviceLayout.cardSpacing) {
            ZStack {
                Circle()
                    .fill(profileColors.innerBackground)
                    .frame(
                        width: AppStyle.Layout.profileAvatarSize,
                        height: AppStyle.Layout.profileAvatarSize
                    )
                    .overlay {
                        Circle()
                            .stroke(
                                profileColors.innerStroke,
                                lineWidth: AppStyle.Layout.profileSurfaceBorderWidth
                            )
                    }

                Image(systemName: "person.fill")
                    .font(AppStyle.Font.profileAvatarIcon)
                    .foregroundColor(profileColors.accent)
            }
            .accessibilityIdentifier("id_profile_avatar")

            if viewModel.hasProfile {
                Text("Hey \(viewModel.nickname)")
                    .font(AppStyle.Font.profileGreeting)
                    .foregroundColor(profileColors.title)
                    .accessibilityIdentifier("id_profile_greeting")
            } else {
                Text("Profile")
                    .font(AppStyle.Font.profileGreeting)
                    .foregroundColor(profileColors.title)
            }
        }
        .padding(.top, AppStyle.Padding.titleTop)
    }

    // MARK: - Nickname

    @ViewBuilder
    private var nicknameSection: some View {
        if viewModel.isEditingNickname || !viewModel.hasProfile {
            ProfileCardContainer {
                VStack(spacing: AppStyle.CornerRadius.defaultButton) {
                    ProfileCardHeading("Nickname")
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Your nickname", text: $viewModel.inputNickname)
                        .foregroundColor(profileColors.title)
                        .font(AppStyle.Font.tileValue)
                        .padding(AppStyle.Layout.profileInputPadding)
                        .background(profileColors.inputBackground)
                        .cornerRadius(AppStyle.CornerRadius.tile)
                        .focused($focusedField, equals: .nickname)
                        .submitLabel(.done)
                        .onSubmit { viewModel.saveNickname() }
                        .accessibilityIdentifier("id_profile_nickname_input")
                        .id(ProfileField.nickname)

                    ProfileActionRow(
                        secondaryLabel: viewModel.hasProfile ? "Cancel" : nil,
                        primaryLabel: "Save",
                        isPrimaryEnabled: !viewModel.isNicknameInputEmpty,
                        secondaryAccessibilityIdentifier: "id_profile_nickname_cancel",
                        primaryAccessibilityIdentifier: "id_profile_nickname_save",
                        onSecondary: {
                            focusedField = nil
                            viewModel.cancelNicknameEdit()
                        },
                        onPrimary: {
                            focusedField = nil
                            viewModel.saveNickname()
                        }
                    )
                }
                .onAppear {
                    if !viewModel.hasProfile {
                        viewModel.inputNickname = ""
                    }
                    focusedField = .nickname
                }
            }
        } else {
            Button {
                viewModel.startEditingNickname()
            } label: {
                ProfileCardContainer {
                    ProfileCardHeading("Nickname", detail: viewModel.nickname)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit nickname")
            .accessibilityIdentifier("id_profile_nickname_edit")
        }
    }

    // MARK: - Body Data

    private var bodyDataSection: some View {
        ProfileCardContainer {
            VStack(spacing: AppStyle.Padding.card) {
                Button {
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        isBodyExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: AppStyle.DeviceLayout.cardSpacing) {
                        ProfileCardHeading("Body Details")

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(AppStyle.Font.profileSmallIcon)
                            .foregroundColor(profileColors.accent)
                            .rotationEffect(.degrees(isBodyExpanded ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("id_profile_body_header")

                if isBodyExpanded {
                    Group {
                        if viewModel.isEditingBody {
                            bodyEditForm
                        } else {
                            bodyReadOnlyContent
                        }
                    }
                }
            }
        }
        .onChange(of: viewModel.isEditingBody) { _, isEditing in
            guard isEditing else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isBodyExpanded = true
            }
        }
        .onChange(of: isBodyExpanded) { _, isExpanded in
            if isExpanded {
                viewModel.loadBMIIfNeeded()
            }
        }
    }

    private var bodyEditForm: some View {
        VStack(spacing: AppStyle.CornerRadius.defaultButton) {
            BodyMetricsWheelRow(viewModel: viewModel)

            ProfileActionRow(
                secondaryLabel: "Cancel",
                primaryLabel: "Save",
                secondaryAccessibilityIdentifier: "id_profile_body_cancel",
                primaryAccessibilityIdentifier: "id_profile_body_save",
                onSecondary: {
                    viewModel.cancelBodyEdit()
                },
                onPrimary: {
                    viewModel.saveBodyData()
                }
            )
        }
    }

    private var bodyReadOnlyContent: some View {
        VStack(alignment: .leading, spacing: AppStyle.Padding.card) {
            bodyDisplayGrid
            bmiContent
        }
    }

    private var bodyDisplayGrid: some View {
        HStack(spacing: AppStyle.CornerRadius.defaultButton) {
            MetricTile(
                label: "Weight",
                value: viewModel.weightKg > 0 ? WeightFormatter.format(viewModel.weightKg) : "–",
                unit: "kg",
                accessibilityID: "id_profile_weight_tile",
                action: { viewModel.startEditingBody() }
            )

            MetricTile(
                label: "Height",
                value: viewModel.heightCm > 0 ? String(format: "%.0f", viewModel.heightCm) : "–",
                unit: "cm",
                accessibilityID: "id_profile_height_tile",
                action: { viewModel.startEditingBody() }
            )

            MetricTile(
                label: "Age",
                value: viewModel.age > 0 ? "\(viewModel.age)" : "–",
                unit: "Years",
                accessibilityID: "id_profile_age_tile",
                action: { viewModel.startEditingBody() }
            )
        }
    }

    // MARK: - BMI (part of Body Details)

    private var bmiContent: some View {
        VStack(alignment: .leading, spacing: AppStyle.CornerRadius.defaultButton) {
            Divider()
                .background(profileColors.divider)

            ProfileCardHeading("BMI", detail: "Your body mass index")

            if let bmi = viewModel.bmiResult {
                HStack(alignment: .firstTextBaseline, spacing: AppStyle.DeviceLayout.cardSpacing) {
                    Text(viewModel.formattedBMI)
                        .font(AppStyle.Font.profileCardValue)
                        .foregroundColor(bmiColor(for: bmi.category))
                        .accessibilityIdentifier("id_profile_bmi_value")

                    Text(bmi.category.displayName)
                        .font(AppStyle.Font.profileBMICategory)
                        .foregroundColor(bmiColor(for: bmi.category))
                        .fixedSize()
                        .accessibilityIdentifier("id_profile_bmi_category")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                bmiBar(value: bmi.value)
            } else if !viewModel.hasBodyData {
                Text("Enter your weight and height to calculate your BMI.")
                    .font(AppStyle.Font.profileCardTitle)
                    .foregroundColor(profileColors.secondary)
            }

            if let error = viewModel.bmiError {
                HStack(spacing: 4) {
                    Image(systemName: "wifi.slash")
                        .font(AppStyle.Font.profileSmallIcon)
                    Text(error)
                        .font(AppStyle.Font.detailCaption)
                }
                .foregroundColor(AppStyle.Color.yellow)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer()
                RefreshActionButton(
                    isLoading: viewModel.isLoadingBMI,
                    isEnabled: viewModel.hasBodyData
                ) {
                    viewModel.fetchBMI()
                }
                .accessibilityIdentifier("id_profile_bmi_refresh")
            }
        }
    }

    // MARK: - BMI Bar

    private func bmiBar(value: Double) -> some View {
        GeometryReader { geo in
            let barWidth = geo.size.width
            let clampedBMI = min(max(value, 15), 40)
            let position = (clampedBMI - 15) / 25.0

            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    Rectangle().fill(AppStyle.Color.bmiUnderweight)
                    Rectangle().fill(AppStyle.Color.bmiNormal)
                    Rectangle().fill(AppStyle.Color.bmiOverweight)
                    Rectangle().fill(AppStyle.Color.bmiObese)
                }
                .frame(height: AppStyle.Layout.profileBMIBarHeight)
                .cornerRadius(AppStyle.Layout.profileBMIBarHeight / 2)

                Circle()
                    .fill(profileColors.title)
                    .frame(
                        width: AppStyle.Layout.profileBMIThumbSize,
                        height: AppStyle.Layout.profileBMIThumbSize
                    )
                    .shadow(color: AppStyle.Shadow.cardColor, radius: AppStyle.Shadow.cardRadius, y: AppStyle.Shadow.cardY)
                    .offset(x: barWidth * position - AppStyle.Layout.profileBMIThumbSize / 2)
            }
        }
        .frame(height: AppStyle.Layout.profileBMIThumbSize)
        .accessibilityIdentifier("id_profile_bmi_bar")
    }

    // MARK: - Helpers

    private func bmiColor(for category: BMICategory) -> Color {
        switch category {
        case .underweight: return AppStyle.Color.bmiUnderweight
        case .normal: return AppStyle.Color.bmiNormal
        case .overweight: return AppStyle.Color.bmiOverweight
        case .obese: return AppStyle.Color.bmiObese
        case .unknown: return AppStyle.Color.gray
        }
    }
}

// MARK: - Metric Tile

private struct MetricTile: View {
    let label: String
    let value: String
    let unit: String
    let accessibilityID: String
    var action: (() -> Void)? = nil
    @Environment(\.profileColorTheme) private var profileColors

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 4) {
                Text(label)
                    .font(AppStyle.Font.profileCardTitle)
                    .foregroundColor(profileColors.secondary)
                    .fixedSize()

                Text(value)
                    .font(AppStyle.Font.profileCardValue)
                    .foregroundColor(profileColors.title)

                Text(unit)
                    .font(AppStyle.Font.profileCardUnit)
                    .foregroundColor(profileColors.secondary)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, minHeight: AppStyle.Layout.profileCardMinHeight)
            .profileReadOnlyTileSurface()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityIdentifier(accessibilityID)
    }
}

// MARK: - Body Metrics Wheel Row

/// Three side-by-side wheel pickers (Weight / Height / Age) driven directly by
/// `ProfileViewModel` via typed bindings. The weight column supports a Decimal
/// toggle that switches between integer-only (30, 31, …) and half-step
/// (30, 30.5, …) options — same UX as `ExerciseWeightPickerView` but without
/// String parsing.
private struct BodyMetricsWheelRow: View {
    @Bindable var viewModel: ProfileViewModel
    @State private var showWeightDecimal: Bool = false
    @Environment(\.profileColorTheme) private var profileColors

    private static let heightOptions: [Int] = Array(100...230)
    private static let ageOptions: [Int] = Array(10...100)

    /// Resolved via two cached arrays in `WeightOptionsGenerator` so toggling
    /// the Decimal switch never re-allocates or re-filters the 341-element
    /// option list on each render.
    private var filteredWeightOptions: [Double] {
        showWeightDecimal
            ? WeightOptionsGenerator.bodyWeightOptionsKg
            : WeightOptionsGenerator.bodyWeightOptionsKgIntegerOnly
    }

    var body: some View {
        VStack(spacing: AppStyle.DeviceLayout.cardSpacing) {
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Text("Decimal")
                        .font(AppStyle.Font.defaultFont)
                        .foregroundColor(profileColors.title.opacity(0.85))
                    Toggle("", isOn: $showWeightDecimal)
                        .labelsHidden()
                        .toggleStyle(
                            CapsuleToggleStyle(
                                onColor: profileColors.accent,
                                offColor: profileColors.divider
                                    .opacity(AppStyle.Opacity.fadedOverlay)
                            )
                        )
                }
            }

            HStack(alignment: .top, spacing: 0) {
                FitnessWheelPickerColumn(
                    title: "Weight (kg)",
                    selection: $viewModel.draftWeightKg,
                    values: filteredWeightOptions,
                    accessibilityID: "id_profile_weight_wheel"
                ) { value in
                    Text(WeightFormatter.format(value))
                }

                FitnessWheelPickerColumn(
                    title: "Height (cm)",
                    selection: $viewModel.draftHeightCm,
                    values: Self.heightOptions,
                    accessibilityID: "id_profile_height_wheel"
                ) { value in
                    Text("\(value)")
                }

                FitnessWheelPickerColumn(
                    title: "Age",
                    selection: $viewModel.draftAge,
                    values: Self.ageOptions,
                    accessibilityID: "id_profile_age_wheel"
                ) { value in
                    Text("\(value)")
                }
            }
            .frame(height: AppStyle.Layout.profileWheelHeight)
        }
        .onAppear {
            if viewModel.draftWeightKg != floor(viewModel.draftWeightKg) {
                showWeightDecimal = true
            }
        }
    }
}
