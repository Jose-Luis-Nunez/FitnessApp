import SwiftUI
import FitnessUI
import FitnessResources

public struct TramDeparturesCardView: View {

    @Bindable private var viewModel: TramDeparturesViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var locale

    private var profileColors: ProfileColorTheme { appColorTheme.profile }

    public init(viewModel: TramDeparturesViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if viewModel.isExpanded {
                VStack(alignment: .leading, spacing: AppStyle.Padding.card) {
                    swapRow
                    contentBody
                        .frame(minHeight: AppStyle.Layout.tramDeparturesAreaMinHeight, alignment: .top)
                    footer
                }
                .padding(.top, AppStyle.Padding.card)
            }
        }
        .profileCardSurface()
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.onBecameActive()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        Button {
            viewModel.toggleExpanded()
        } label: {
            HStack(spacing: AppStyle.DeviceLayout.cardSpacing) {
                Image(systemName: "tram.fill")
                    .font(AppStyle.Font.profileEditIcon)
                    .foregroundColor(profileColors.accent)

                ProfileCardHeading(
                    AppText.transitTramLine(line: viewModel.lineName),
                    detail: "\(viewModel.fromLabel) → \(viewModel.toLabel)"
                )

                Spacer()

                Image(systemName: "chevron.down")
                    .font(AppStyle.Font.profileSmallIcon)
                    .foregroundColor(profileColors.accent)
                    .rotationEffect(.degrees(viewModel.isExpanded ? 180 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("id_profile_tram_header")
    }

    // MARK: - Swap Row

    private var swapRow: some View {
        HStack(spacing: AppStyle.DeviceLayout.cardSpacing) {
            endpointPill(text: viewModel.fromLabel, caption: AppText.transitStart)

            Button {
                viewModel.swap()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(AppStyle.Font.profileEditIcon)
                    .foregroundColor(profileColors.accent)
                    .frame(width: AppStyle.Layout.checkmarkSize, height: AppStyle.Layout.checkmarkSize)
                    .profileReadOnlyTileSurface(cornerRadius: AppStyle.CornerRadius.defaultButton)
            }
            .accessibilityIdentifier("id_profile_tram_swap")

            endpointPill(text: viewModel.toLabel, caption: AppText.transitDestination)
        }
    }

    private func endpointPill(text: String, caption: LocalizedStringResource) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caption)
                .font(AppStyle.Font.profileCardTitle)
                .foregroundColor(profileColors.secondary)
            Text(verbatim: text)
                .font(AppStyle.Font.tileValue)
                .foregroundColor(profileColors.title)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, AppStyle.Padding.card)
        .padding(.vertical, AppStyle.Layout.profileInputPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .profileReadOnlyTileSurface()
    }

    // MARK: - Content Body

    @ViewBuilder
    private var contentBody: some View {
        if viewModel.isLoading && viewModel.departures.isEmpty {
            loadingRow
        } else if !viewModel.departures.isEmpty {
            departuresList
        } else if viewModel.error == nil {
            emptyRow
        }

        if let error = viewModel.error {
            errorRow(error)
        }
    }

    private var loadingRow: some View {
        HStack {
            ProgressView()
                .tint(profileColors.accent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppStyle.Layout.profileButtonPadding)
    }

    private var emptyRow: some View {
        Text(AppText.transitNoDepartures)
            .font(AppStyle.Font.detailCaption)
            .foregroundColor(profileColors.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var departuresList: some View {
        VStack(spacing: AppStyle.DeviceLayout.cardSpacing) {
            ForEach(Array(viewModel.departures.enumerated()), id: \.element.id) { index, dep in
                departureRow(dep, index: index)
            }
        }
    }

    private func departureRow(_ dep: TramDeparture, index: Int) -> some View {
        HStack(spacing: AppStyle.DeviceLayout.cardSpacing) {
            Text(verbatim: dep.line)
                .font(AppStyle.Font.cardSmallBold)
                .foregroundColor(profileColors.onAccent)
                .frame(minWidth: AppStyle.Layout.setRowBadgeSize, minHeight: AppStyle.Layout.setRowBadgeSize)
                .background(profileColors.accentFill)
                .cornerRadius(AppStyle.CornerRadius.pill)

            Text(verbatim: viewModel.formattedTime(for: dep.plannedWhen, locale: locale))
                .font(AppStyle.Font.tileValue)
                .foregroundColor(profileColors.title)
                .fixedSize()

            delayBadge(for: dep.delayMinutes)

            Spacer(minLength: 0)

            Text(verbatim: dep.direction)
                .font(AppStyle.Font.detailCaption)
                .foregroundColor(profileColors.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, AppStyle.Padding.card)
        .padding(.vertical, AppStyle.Layout.profileButtonPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .profileReadOnlyTileSurface()
        .accessibilityIdentifier("id_profile_tram_row_\(index)")
    }

    @ViewBuilder
    private func delayBadge(for delay: Int) -> some View {
        if delay > 0 {
            Text(verbatim: "+\(delay) min")
                .font(AppStyle.Font.cardSmallBold)
                .foregroundColor(AppStyle.Color.yellow)
        } else if delay < 0 {
            Text(verbatim: "\(delay) min")
                .font(AppStyle.Font.cardSmallBold)
                .foregroundColor(profileColors.accent)
        } else {
            Text(AppText.transitOnTime)
                .font(AppStyle.Font.cardSmallBold)
                .foregroundColor(profileColors.accent)
        }
    }

    private func errorRow(_ failure: TransitPresentationFailure) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "wifi.slash")
                .font(AppStyle.Font.profileSmallIcon)
            Text(failure.localizedResource)
                .font(AppStyle.Font.detailCaption)
                .lineLimit(2)
        }
        .foregroundColor(AppStyle.Color.yellow)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: AppStyle.DeviceLayout.cardSpacing) {
            footerStatusText

            HStack {
                Spacer()

                RefreshActionButton(isLoading: viewModel.isLoading) {
                    Task { await viewModel.refresh() }
                }
                .accessibilityIdentifier("id_profile_tram_refresh")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var footerStatusText: some View {
        if let lastUpdated = viewModel.formattedLastUpdated(locale: locale) {
            if viewModel.isStale {
                Text(AppText.transitCached(time: lastUpdated))
                    .font(AppStyle.Font.sheetCaption)
                    .foregroundColor(AppStyle.Color.yellow)
            } else {
                Text(AppText.transitUpdated(time: lastUpdated))
                    .font(AppStyle.Font.sheetCaption)
                    .foregroundColor(profileColors.secondary)
            }
        }
    }

}
