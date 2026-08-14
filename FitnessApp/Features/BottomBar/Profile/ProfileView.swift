import SwiftUI
import FitnessUI
import FitnessProfile
import FitnessFriends
import FitnessResources

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var isBodyExpanded = false
    @Binding private var accentScheme: AppAccentScheme
    @Binding private var appLanguage: AppLanguage
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var locale
    @FocusState private var focusedField: ProfileField?

    private var profileColors: ProfileColorTheme { appColorTheme.profile }

    init(accentScheme: Binding<AppAccentScheme>, appLanguage: Binding<AppLanguage>) {
        _accentScheme = accentScheme
        _appLanguage = appLanguage
    }

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
                        languageSection
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
        .alert(AppText.commonError, isPresented: $viewModel.showNicknameAlert) {
            Button(AppText.actionOk, role: .cancel) {}
        } message: {
            Text(AppText.profileNicknameEmpty)
        }
    }

    // MARK: - Accent Color

    /// The app root persists this binding and injects the resulting app theme.
    /// Changing it invalidates color consumers while keeping feature identity.
    private var iconColorSection: some View {
        ProfileCardContainer {
            HStack(spacing: AppStyle.Padding.card) {
                ProfileCardHeading(AppText.profileAccentColor)
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
            }
        }
    }

    private func iconColorButton(for scheme: AppAccentScheme) -> some View {
        let isSelected = accentScheme == scheme

        return Button {
            accentScheme = scheme
        } label: {
            Text(scheme.localizedName)
                .font(AppStyle.Font.profileCardTitle)
                .foregroundColor(isSelected ? profileColors.title : profileColors.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: AppStyle.Layout.minimumTapTargetSize)
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
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? AppText.commonSelected : AppText.commonNotSelected)
        .accessibilityIdentifier("id_profile_icon_color_\(scheme.rawValue)")
    }

    // MARK: - Language

    private var languageSection: some View {
        let languages = AppLanguage.allCases
        let optionWidth = (
            AppStyle.Layout.profileColorPickerWidth - AppStyle.Layout.separatorWidth
        ) / 2

        return ProfileCardContainer {
            HStack(spacing: AppStyle.Padding.card) {
                ProfileCardHeading(AppText.profileLanguage)
                    .layoutPriority(1)

                Spacer(minLength: 0)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(languages) { language in
                            if language != languages.first {
                                Rectangle()
                                    .fill(profileColors.divider)
                                    .frame(
                                        width: AppStyle.Layout.separatorWidth,
                                        height: 24
                                    )
                            }

                            languageButton(for: language)
                                .frame(width: optionWidth)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(width: AppStyle.Layout.profileColorPickerWidth)
                .profileReadOnlyTileSurface()
            }
        }
    }

    private func languageButton(for language: AppLanguage) -> some View {
        let isSelected = appLanguage == language

        return Button {
            appLanguage = language
        } label: {
            Text(verbatim: language.autonym)
                .font(AppStyle.Font.profileCardTitle)
                .foregroundColor(isSelected ? profileColors.title : profileColors.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: AppStyle.Layout.minimumTapTargetSize)
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
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? AppText.commonSelected : AppText.commonNotSelected)
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
                Text(AppText.profileGreeting(name: viewModel.nickname))
                    .font(AppStyle.Font.profileGreeting)
                    .foregroundColor(profileColors.title)
            } else {
                Text(AppText.profileTitle)
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
                    ProfileCardHeading(AppText.profileNickname)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("", text: $viewModel.inputNickname, prompt: Text(AppText.profileNicknamePlaceholder))
                        .foregroundColor(profileColors.title)
                        .font(AppStyle.Font.tileValue)
                        .padding(AppStyle.Layout.profileInputPadding)
                        .background(profileColors.inputBackground)
                        .cornerRadius(AppStyle.CornerRadius.tile)
                        .focused($focusedField, equals: .nickname)
                        .submitLabel(.done)
                        .onSubmit { viewModel.saveNickname() }
                        .id(ProfileField.nickname)

                    ProfileActionRow(
                        secondaryLabel: viewModel.hasProfile ? AppText.actionCancel : nil,
                        primaryLabel: AppText.actionSave,
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
                    ProfileCardHeading(AppText.profileNickname, detail: viewModel.nickname)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(AppText.accessibilityEditNickname)
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
                        ProfileCardHeading(AppText.profileBodyDetails)

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
                secondaryLabel: AppText.actionCancel,
                primaryLabel: AppText.actionSave,
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
                label: AppText.profileWeight,
                value: viewModel.weightKg > 0 ? WeightFormatter.format(viewModel.weightKg, locale: locale) : "–",
                unit: "kg",
                accessibilityID: "id_profile_weight_tile",
                action: { viewModel.startEditingBody() }
            )

            MetricTile(
                label: AppText.profileHeight,
                value: viewModel.heightCm > 0
                    ? viewModel.heightCm.formatted(.number.precision(.fractionLength(0)).locale(locale))
                    : "–",
                unit: "cm",
                accessibilityID: "id_profile_height_tile",
                action: { viewModel.startEditingBody() }
            )

            MetricTile(
                label: AppText.profileAge,
                value: viewModel.age > 0 ? "\(viewModel.age)" : "–",
                localizedUnit: AppText.profileYears,
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

            ProfileCardHeading(AppText.profileBmi, localizedDetail: AppText.profileBmiDetail)

            if let bmi = viewModel.bmiResult {
                HStack(alignment: .firstTextBaseline, spacing: AppStyle.DeviceLayout.cardSpacing) {
                    Text(verbatim: viewModel.formattedBMI(locale: locale))
                        .font(AppStyle.Font.profileCardValue)
                        .foregroundColor(bmiColor(for: bmi.category))
                        .accessibilityIdentifier("id_profile_bmi_value")

                    Text(localizedBMICategory(bmi.category))
                        .font(AppStyle.Font.profileBMICategory)
                        .foregroundColor(bmiColor(for: bmi.category))
                        .fixedSize()
                        .accessibilityIdentifier("id_profile_bmi_category")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                bmiBar(value: bmi.value)
            } else if !viewModel.hasBodyData {
                Text(AppText.profileBmiPrompt)
                    .font(AppStyle.Font.profileCardTitle)
                    .foregroundColor(profileColors.secondary)
            }

            if let error = viewModel.bmiError {
                HStack(spacing: 4) {
                    Image(systemName: "wifi.slash")
                        .font(AppStyle.Font.profileSmallIcon)
                    Text(localizedBMIStatus(error))
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
                    Rectangle().fill(appColorTheme.accent.glow)
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
        case .normal: return appColorTheme.accent.glow
        case .overweight: return AppStyle.Color.bmiOverweight
        case .obese: return AppStyle.Color.bmiObese
        case .unknown: return AppStyle.Color.gray
        }
    }

    private func localizedBMICategory(_ category: BMICategory) -> LocalizedStringResource {
        switch category {
        case .underweight: AppText.profileBmiUnderweight
        case .normal: AppText.profileBmiNormal
        case .overweight: AppText.profileBmiOverweight
        case .obese: AppText.profileBmiObese
        case .unknown: AppText.commonUnknown
        }
    }

    private func localizedBMIStatus(_ status: BMIStatusMessage) -> LocalizedStringResource {
        switch status {
        case .offlineLocalResult: AppText.profileBmiOffline
        case .calculationFailed: AppText.profileBmiFailed
        }
    }
}

// MARK: - Metric Tile

private struct MetricTile: View {
    let label: LocalizedStringResource
    let value: String
    private let unit: MetricUnit
    let accessibilityID: String
    var action: (() -> Void)? = nil
    @Environment(\.appColorTheme) private var appColorTheme

    private var profileColors: ProfileColorTheme { appColorTheme.profile }

    init(
        label: LocalizedStringResource,
        value: String,
        unit: String,
        accessibilityID: String,
        action: (() -> Void)? = nil
    ) {
        self.label = label
        self.value = value
        self.unit = .verbatim(unit)
        self.accessibilityID = accessibilityID
        self.action = action
    }

    init(
        label: LocalizedStringResource,
        value: String,
        localizedUnit: LocalizedStringResource,
        accessibilityID: String,
        action: (() -> Void)? = nil
    ) {
        self.label = label
        self.value = value
        unit = .localized(localizedUnit)
        self.accessibilityID = accessibilityID
        self.action = action
    }

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 4) {
                Text(label)
                    .font(AppStyle.Font.profileCardTitle)
                    .foregroundColor(profileColors.secondary)
                    .fixedSize()

                Text(verbatim: value)
                    .font(AppStyle.Font.profileCardValue)
                    .foregroundColor(profileColors.title)

                unit.text
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

    private enum MetricUnit {
        case verbatim(String)
        case localized(LocalizedStringResource)

        var text: Text {
            switch self {
            case .verbatim(let value): Text(verbatim: value)
            case .localized(let resource): Text(resource)
            }
        }
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
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var locale

    private var profileColors: ProfileColorTheme { appColorTheme.profile }

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
                    Text(AppText.commonDecimal)
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
                    title: AppText.profileWeightKg,
                    selection: $viewModel.draftWeightKg,
                    values: filteredWeightOptions,
                    accessibilityID: "id_profile_weight_wheel"
                ) { value in
                    Text(verbatim: WeightFormatter.format(value, locale: locale))
                }

                FitnessWheelPickerColumn(
                    title: AppText.profileHeightCm,
                    selection: $viewModel.draftHeightCm,
                    values: Self.heightOptions,
                    accessibilityID: "id_profile_height_wheel"
                ) { value in
                    Text(verbatim: "\(value)")
                }

                FitnessWheelPickerColumn(
                    title: AppText.profileAge,
                    selection: $viewModel.draftAge,
                    values: Self.ageOptions,
                    accessibilityID: "id_profile_age_wheel"
                ) { value in
                    Text(verbatim: "\(value)")
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
