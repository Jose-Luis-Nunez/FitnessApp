import SwiftUI
import FitnessUI
import FitnessProfile

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var isBodyExpanded = false
    @State private var isBMIExpanded = false
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
                        bmiSection
                        TramDeparturesCardView(viewModel: viewModel.tramVM)
                        SBahnDeparturesCardView(viewModel: viewModel.sbahnVM)
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
        // BMI loading is lazy — triggered on first expand below, not on
        // appear. This avoids the "loading spinner while collapsed" UX bug
        // and saves a network call when the user never opens the BMI card.
        .alert("Error", isPresented: $viewModel.showNicknameAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Nickname cannot be empty.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: AppStyle.DeviceLayout.cardSpacing) {
            ZStack {
                Circle()
                    .fill(AppStyle.Color.greenDark)
                    .frame(
                        width: AppStyle.Layout.profileAvatarSize,
                        height: AppStyle.Layout.profileAvatarSize
                    )

                Image(systemName: "person.fill")
                    .font(AppStyle.Font.profileAvatarIcon)
                    .foregroundColor(AppStyle.Color.greenGlow)
            }
            .accessibilityIdentifier("id_profile_avatar")

            if viewModel.hasProfile {
                Text("Hey \(viewModel.nickname)")
                    .font(AppStyle.Font.profileGreeting)
                    .foregroundColor(AppStyle.Color.white)
                    .accessibilityIdentifier("id_profile_greeting")
            } else {
                Text("Profile")
                    .font(AppStyle.Font.profileGreeting)
                    .foregroundColor(AppStyle.Color.white)
            }
        }
        .padding(.top, AppStyle.Padding.titleTop)
    }

    // MARK: - Nickname

    private var nicknameSection: some View {
        ProfileCard {
            if viewModel.isEditingNickname || !viewModel.hasProfile {
                VStack(spacing: AppStyle.CornerRadius.defaultButton) {
                    Text("Nickname")
                        .font(AppStyle.Font.profileInputLabel)
                        .foregroundColor(AppStyle.Color.greenLight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize()

                    TextField("Your nickname", text: $viewModel.inputNickname)
                        .foregroundColor(AppStyle.Color.white)
                        .font(AppStyle.Font.tileValue)
                        .padding(AppStyle.Layout.profileInputPadding)
                        .background(AppStyle.Color.sheetInputBackground)
                        .cornerRadius(AppStyle.CornerRadius.tile)
                        .focused($focusedField, equals: .nickname)
                        .submitLabel(.done)
                        .onSubmit { viewModel.saveNickname() }
                        .accessibilityIdentifier("id_profile_nickname_input")
                        .id(ProfileField.nickname)

                    HStack(spacing: AppStyle.CornerRadius.defaultButton) {
                        if viewModel.hasProfile {
                            Button {
                                focusedField = nil
                                viewModel.cancelNicknameEdit()
                            } label: {
                                Text("Cancel")
                                    .font(AppStyle.Font.pickerAction)
                                    .foregroundColor(AppStyle.Color.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, AppStyle.Layout.profileButtonPadding)
                            }
                            .accessibilityIdentifier("id_profile_nickname_cancel")
                        }

                        Button {
                            focusedField = nil
                            viewModel.saveNickname()
                        } label: {
                            Text("Save")
                                .font(AppStyle.Font.pickerAction)
                                .foregroundColor(AppStyle.Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppStyle.Layout.profileButtonPadding)
                                .background(
                                    viewModel.isNicknameInputEmpty
                                    ? AppStyle.Color.green.opacity(AppStyle.Opacity.subtleStroke)
                                    : AppStyle.Color.green
                                )
                                .cornerRadius(AppStyle.CornerRadius.defaultButton)
                        }
                        .disabled(viewModel.isNicknameInputEmpty)
                        .accessibilityIdentifier("id_profile_nickname_save")
                    }
                }
                .onAppear {
                    if !viewModel.hasProfile {
                        viewModel.inputNickname = ""
                    }
                    focusedField = .nickname
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nickname")
                            .font(AppStyle.Font.profileCardTitle)
                            .foregroundColor(AppStyle.Color.greenLight)
                            .fixedSize()
                        Text(viewModel.nickname)
                            .font(AppStyle.Font.sectionHeadline)
                            .foregroundColor(AppStyle.Color.white)
                    }

                    Spacer()

                    Button {
                        viewModel.startEditingNickname()
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(AppStyle.Font.profileEditIcon)
                            .foregroundColor(AppStyle.Color.green)
                    }
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("id_profile_nickname_edit")
                }
            }
        }
    }

    // MARK: - Body Data

    private var bodyDataSection: some View {
        ProfileCard {
            VStack(spacing: AppStyle.Padding.card) {
                Button {
                    isBodyExpanded.toggle()
                } label: {
                    HStack(spacing: AppStyle.DeviceLayout.cardSpacing) {
                        Text("Body Details")
                            .font(AppStyle.Font.sectionHeadline)
                            .foregroundColor(AppStyle.Color.white)
                            .fixedSize()

                        Spacer()

                        if isBodyExpanded && !viewModel.isEditingBody {
                            Button {
                                viewModel.startEditingBody()
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(AppStyle.Font.profileEditIcon)
                                    .foregroundColor(AppStyle.Color.green)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("id_profile_body_edit")
                        }

                        Image(systemName: "chevron.down")
                            .font(AppStyle.Font.profileSmallIcon)
                            .foregroundColor(AppStyle.Color.greenLight)
                            .rotationEffect(.degrees(isBodyExpanded ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("id_profile_body_header")

                if isBodyExpanded {
                    if viewModel.isEditingBody {
                        bodyEditForm
                    } else {
                        bodyDisplayGrid
                    }
                }
            }
        }
        .onChange(of: viewModel.isEditingBody) { _, isEditing in
            if isEditing { isBodyExpanded = true }
        }
    }

    private var bodyEditForm: some View {
        VStack(spacing: AppStyle.CornerRadius.defaultButton) {
            BodyMetricsWheelRow(viewModel: viewModel)

            HStack(spacing: AppStyle.CornerRadius.defaultButton) {
                Button {
                    viewModel.cancelBodyEdit()
                } label: {
                    Text("Cancel")
                        .font(AppStyle.Font.pickerAction)
                        .foregroundColor(AppStyle.Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppStyle.Layout.profileButtonPadding)
                }
                .accessibilityIdentifier("id_profile_body_cancel")

                Button {
                    viewModel.saveBodyData()
                } label: {
                    Text("Save")
                        .font(AppStyle.Font.pickerAction)
                        .foregroundColor(AppStyle.Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppStyle.Layout.profileButtonPadding)
                        .background(AppStyle.Color.green)
                        .cornerRadius(AppStyle.CornerRadius.defaultButton)
                }
                .accessibilityIdentifier("id_profile_body_save")
            }
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

    // MARK: - BMI

    @ViewBuilder
    private var bmiSection: some View {
        if viewModel.hasBodyData || viewModel.bmiResult != nil {
            ProfileCard {
                VStack(spacing: AppStyle.CornerRadius.defaultButton) {
                    Button {
                        isBMIExpanded.toggle()
                        if isBMIExpanded {
                            viewModel.loadBMIIfNeeded()
                        }
                    } label: {
                        HStack(spacing: AppStyle.DeviceLayout.cardSpacing) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("BMI")
                                    .font(AppStyle.Font.sectionHeadline)
                                    .foregroundColor(AppStyle.Color.white)
                                    .fixedSize()

                                Text("Your body mass index")
                                    .font(AppStyle.Font.profileCardTitle)
                                    .foregroundColor(AppStyle.Color.greenLight)
                                    .lineLimit(1)
                            }

                            Spacer()

                            // No loading indicator in the header — would
                            // otherwise be visible even when the card is
                            // collapsed. Loading lives in the expanded
                            // body, consistent with Tram/SBahn cards.

                            Image(systemName: "chevron.down")
                                .font(AppStyle.Font.profileSmallIcon)
                                .foregroundColor(AppStyle.Color.greenLight)
                                .rotationEffect(.degrees(isBMIExpanded ? 180 : 0))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("id_profile_bmi_header")

                    if isBMIExpanded {
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
                                .foregroundColor(AppStyle.Color.gray)
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
                            RefreshActionButton(isLoading: viewModel.isLoadingBMI) {
                                viewModel.fetchBMI()
                            }
                            .accessibilityIdentifier("id_profile_bmi_refresh")
                        }
                    }
                }
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
                    .fill(AppStyle.Color.white)
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

// MARK: - Profile Card Container

private struct ProfileCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(AppStyle.Padding.card)
        .frame(
            maxWidth: .infinity,
            minHeight: AppStyle.Layout.profileCardCollapsedMinHeight,
            alignment: .leading
        )
        .background(AppStyle.Color.profileCardBackground)
        .cornerRadius(AppStyle.CornerRadius.card)
    }
}

// MARK: - Metric Tile

private struct MetricTile: View {
    let label: String
    let value: String
    let unit: String
    let accessibilityID: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 4) {
                Text(label)
                    .font(AppStyle.Font.profileCardTitle)
                    .foregroundColor(AppStyle.Color.greenLight)
                    .fixedSize()

                Text(value)
                    .font(AppStyle.Font.profileCardValue)
                    .foregroundColor(AppStyle.Color.white)

                Text(unit)
                    .font(AppStyle.Font.profileCardUnit)
                    .foregroundColor(AppStyle.Color.gray)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, minHeight: AppStyle.Layout.profileCardMinHeight)
            .background(AppStyle.Color.sheetInputBackground)
            .cornerRadius(AppStyle.CornerRadius.tile)
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
                        .foregroundColor(AppStyle.Color.white.opacity(0.85))
                    Toggle("", isOn: $showWeightDecimal)
                        .labelsHidden()
                        .toggleStyle(
                            CapsuleToggleStyle(
                                onColor: AppStyle.Color.greenGlow,
                                offColor: AppStyle.Color.gray
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
