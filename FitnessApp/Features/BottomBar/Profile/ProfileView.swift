import SwiftUI
import FitnessUI
import FitnessProfile

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @FocusState private var focusedField: ProfileField?

    enum ProfileField: Hashable {
        case nickname
        case weight
        case height
        case age
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
                        Spacer(minLength: AppStyle.Layout.profileBottomSpacer)
                    }
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                    .padding(.top, AppStyle.Padding.titleTop)
                }
                .onChange(of: focusedField) { field in
                    guard let field else { return }
                    withAnimation {
                        proxy.scrollTo(field, anchor: .center)
                    }
                }
            }
        }
        .onTapGesture {
            focusedField = nil
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(keyboardButtonLabel) {
                    handleKeyboardAction()
                }
                .foregroundColor(AppStyle.Color.green)
            }
        }
        .onAppear {
            viewModel.loadInitialBMI()
        }
        .alert("Fehler", isPresented: $viewModel.showNicknameAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Nickname darf nicht leer sein.")
        }
    }

    private var keyboardButtonLabel: String {
        switch focusedField {
        case .weight: return "Weiter"
        case .height: return "Weiter"
        case .nickname, .age: return "Fertig"
        case nil: return "Fertig"
        }
    }

    private func handleKeyboardAction() {
        switch focusedField {
        case .nickname:
            viewModel.saveNickname()
        case .weight:
            focusedField = .height
        case .height:
            focusedField = .age
        case .age:
            focusedField = nil
            viewModel.saveBodyData()
        case nil:
            break
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

                Text("Willkommen zurück!")
                    .font(AppStyle.Font.profileSubtitle)
                    .foregroundColor(AppStyle.Color.greenLight)
                    .accessibilityIdentifier("id_profile_subtitle")
            } else {
                Text("Profil")
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

                    TextField("Dein Nickname", text: $viewModel.inputNickname)
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
                                Text("Abbrechen")
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
                            Text("Speichern")
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
                HStack {
                    Text("Körperdaten")
                        .font(AppStyle.Font.sectionHeadline)
                        .foregroundColor(AppStyle.Color.white)
                        .fixedSize()

                    Spacer()

                    if !viewModel.isEditingBody {
                        Button {
                            viewModel.startEditingBody()
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(AppStyle.Font.profileEditIcon)
                                .foregroundColor(AppStyle.Color.green)
                        }
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("id_profile_body_edit")
                    }
                }

                if viewModel.isEditingBody {
                    bodyEditForm
                } else {
                    bodyDisplayGrid
                }
            }
        }
    }

    private var bodyEditForm: some View {
        VStack(spacing: AppStyle.CornerRadius.defaultButton) {
            ProfileInputRow(
                label: "Gewicht (kg)",
                text: $viewModel.inputWeight,
                placeholder: "z.B. 75,5",
                keyboardType: .decimalPad,
                accessibilityID: "id_profile_weight_input",
                field: .weight,
                focusedField: $focusedField,
                onSubmit: { focusedField = .height }
            )

            ProfileInputRow(
                label: "Größe (cm)",
                text: $viewModel.inputHeight,
                placeholder: "z.B. 178",
                keyboardType: .numberPad,
                accessibilityID: "id_profile_height_input",
                field: .height,
                focusedField: $focusedField,
                onSubmit: { focusedField = .age }
            )

            ProfileInputRow(
                label: "Alter",
                text: $viewModel.inputAge,
                placeholder: "z.B. 28",
                keyboardType: .numberPad,
                accessibilityID: "id_profile_age_input",
                field: .age,
                focusedField: $focusedField,
                onSubmit: {
                    focusedField = nil
                    viewModel.saveBodyData()
                }
            )

            HStack(spacing: AppStyle.CornerRadius.defaultButton) {
                Button {
                    focusedField = nil
                    viewModel.cancelBodyEdit()
                } label: {
                    Text("Abbrechen")
                        .font(AppStyle.Font.pickerAction)
                        .foregroundColor(AppStyle.Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppStyle.Layout.profileButtonPadding)
                }
                .accessibilityIdentifier("id_profile_body_cancel")

                Button {
                    focusedField = nil
                    viewModel.saveBodyData()
                } label: {
                    Text("Speichern")
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
        .onAppear {
            focusedField = .weight
        }
    }

    private var bodyDisplayGrid: some View {
        HStack(spacing: AppStyle.CornerRadius.defaultButton) {
            MetricTile(
                label: "Gewicht",
                value: viewModel.weightKg > 0 ? WeightFormatter.format(viewModel.weightKg) : "–",
                unit: "kg",
                accessibilityID: "id_profile_weight_tile"
            )

            MetricTile(
                label: "Größe",
                value: viewModel.heightCm > 0 ? String(format: "%.0f", viewModel.heightCm) : "–",
                unit: "cm",
                accessibilityID: "id_profile_height_tile"
            )

            MetricTile(
                label: "Alter",
                value: viewModel.age > 0 ? "\(viewModel.age)" : "–",
                unit: "Jahre",
                accessibilityID: "id_profile_age_tile"
            )
        }
    }

    // MARK: - BMI

    @ViewBuilder
    private var bmiSection: some View {
        if viewModel.hasBodyData || viewModel.bmiResult != nil {
            ProfileCard {
                VStack(spacing: AppStyle.CornerRadius.defaultButton) {
                    HStack {
                        Text("BMI")
                            .font(AppStyle.Font.sectionHeadline)
                            .foregroundColor(AppStyle.Color.white)
                            .fixedSize()

                        Spacer()

                        if viewModel.isLoadingBMI {
                            ProgressView()
                                .tint(AppStyle.Color.green)
                        }
                    }

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
                        Text("Gib Gewicht und Größe ein, um deinen BMI zu berechnen.")
                            .font(AppStyle.Font.profileCardTitle)
                            .foregroundColor(AppStyle.Color.gray)
                    }

                    if let error = viewModel.bmiError {
                        HStack(spacing: 4) {
                            Image(systemName: "wifi.slash")
                                .font(AppStyle.Font.profileSmallIcon)
                            Text("Offline-Berechnung: \(error)")
                                .font(AppStyle.Font.detailCaption)
                        }
                        .foregroundColor(AppStyle.Color.yellow)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        viewModel.fetchBMI()
                    } label: {
                        HStack(spacing: AppStyle.DeviceLayout.cardSpacing) {
                            Image(systemName: "arrow.clockwise")
                                .font(AppStyle.Font.profileSmallIcon)
                            Text("Aktualisieren")
                                .font(AppStyle.Font.pickerAction)
                                .fixedSize()
                        }
                        .foregroundColor(AppStyle.Color.green)
                    }
                    .accessibilityIdentifier("id_profile_bmi_refresh")
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
        .frame(maxWidth: .infinity, alignment: .leading)
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

    var body: some View {
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
        .accessibilityIdentifier(accessibilityID)
    }
}

// MARK: - Input Row

private struct ProfileInputRow: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let keyboardType: UIKeyboardType
    let accessibilityID: String
    let field: ProfileView.ProfileField
    var focusedField: FocusState<ProfileView.ProfileField?>.Binding
    var onSubmit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppStyle.Font.profileInputLabel)
                .foregroundColor(AppStyle.Color.greenLight)
                .fixedSize()

            TextField(placeholder, text: $text)
                .foregroundColor(AppStyle.Color.white)
                .font(AppStyle.Font.tileValue)
                .keyboardType(keyboardType)
                .padding(AppStyle.Layout.profileInputPadding)
                .background(AppStyle.Color.sheetInputBackground)
                .cornerRadius(AppStyle.CornerRadius.tile)
                .focused(focusedField, equals: field)
                .submitLabel(field == .age ? .done : .next)
                .onSubmit { onSubmit?() }
                .accessibilityIdentifier(accessibilityID)
                .id(field)
        }
    }
}
