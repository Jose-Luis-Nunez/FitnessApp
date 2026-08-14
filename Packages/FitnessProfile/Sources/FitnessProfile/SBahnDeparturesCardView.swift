import SwiftUI
import FitnessUI
import FitnessResources

public struct SBahnDeparturesCardView: View {

    @Bindable private var viewModel: SBahnDeparturesViewModel
    @Environment(\.appColorTheme) private var appColorTheme
    @Environment(\.locale) private var locale

    private var profileColors: ProfileColorTheme { appColorTheme.profile }

    public init(viewModel: SBahnDeparturesViewModel) {
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
    }

    // MARK: - Header

    private var header: some View {
        Button {
            viewModel.toggleExpanded()
        } label: {
            HStack(spacing: AppStyle.DeviceLayout.cardSpacing) {
                Image(systemName: "tram.tunnel.fill")
                    .font(AppStyle.Font.profileEditIcon)
                    .foregroundColor(profileColors.accent)

                ProfileCardHeading(
                    verbatim: "S-Bahn",
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
        .accessibilityIdentifier("id_profile_sbahn_header")
    }

    // MARK: - Swap Row

    private var swapRow: some View {
        HStack(spacing: AppStyle.DeviceLayout.cardSpacing) {
            endpointPill(text: viewModel.fromLabel, caption: AppText.transitStart)

            Button {
                Task { await viewModel.swap() }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(AppStyle.Font.profileEditIcon)
                    .foregroundColor(profileColors.accent)
                    .frame(width: AppStyle.Layout.checkmarkSize, height: AppStyle.Layout.checkmarkSize)
                    .profileReadOnlyTileSurface(cornerRadius: AppStyle.CornerRadius.defaultButton)
            }
            .accessibilityIdentifier("id_profile_sbahn_swap")
            .disabled(viewModel.isLoading)

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
            if viewModel.lastUpdated == nil {
                requestPromptRow
            } else {
                emptyRow
            }
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
        Text(AppText.transitNoTrains)
            .font(AppStyle.Font.detailCaption)
            .foregroundColor(profileColors.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var requestPromptRow: some View {
        Text(AppText.transitLoadPrompt)
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

    private func departureRow(_ dep: SBahnDeparture, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                viewModel.toggleDetailExpansion(rowID: dep.id)
            } label: {
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

                    if dep.bridge != nil {
                        Image(systemName: "arrow.triangle.branch")
                            .font(AppStyle.Font.profileSmallIcon)
                            .foregroundColor(AppStyle.Color.yellow)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("id_profile_sbahn_row_\(index)")

            if let bridge = dep.bridge {
                bridgeCaption(bridge: bridge, arrival: dep.arrivalAtDestination)
            } else if let arrival = dep.arrivalAtDestination {
                arrivalCaption(arrival: arrival)
            }

            if viewModel.expandedDetailRowID == dep.id {
                detailPanel(for: dep)
            }
        }
        .padding(.horizontal, AppStyle.Padding.card)
        .padding(.vertical, AppStyle.Layout.profileButtonPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .profileReadOnlyTileSurface()
    }

    /// Caption rendered for east-direct trips (no transfer needed).
    /// Shows the estimated arrival at the configured destination so the
    /// user can answer "wann bin ich da?" at a glance.
    private func arrivalCaption(arrival: Date) -> some View {
        let arrivalStr = viewModel.formattedTime(for: arrival, locale: locale)
        return Text(AppText.transitArrival(destination: viewModel.toLabel, time: arrivalStr))
            .font(AppStyle.Font.detailCaption)
            .foregroundColor(profileColors.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Caption rendered for east-short trips with a useful bridge.
    /// Shows the transfer hint and the estimated arrival at destination
    /// after the bridge train.
    private func bridgeCaption(bridge: BridgeHint, arrival: Date?) -> some View {
        let bridgeTimeStr = viewModel.formattedTime(for: bridge.bridgeDeparture, locale: locale)
        let caption: LocalizedStringResource
        if let arrival {
            caption = AppText.transitTransferCaptionArrival(
                station: bridge.transferStation,
                line: bridge.bridgeLine,
                time: bridgeTimeStr,
                destination: viewModel.toLabel,
                arrival: viewModel.formattedTime(for: arrival, locale: locale)
            )
        } else {
            caption = AppText.transitTransferCaption(
                station: bridge.transferStation,
                line: bridge.bridgeLine,
                time: bridgeTimeStr
            )
        }
        return Text(caption)
            .font(AppStyle.Font.detailCaption)
            .foregroundColor(profileColors.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Detail Panel (row-tap)

    @ViewBuilder
    private func detailPanel(for dep: SBahnDeparture) -> some View {
        Divider()
            .background(profileColors.divider)

        VStack(alignment: .leading, spacing: 6) {
            detailRow(label: AppText.transitScheduledDeparture, value: Text(verbatim: viewModel.formattedTime(for: dep.plannedWhen, locale: locale)))
            detailRow(label: AppText.transitCurrentDeparture, value: Text(verbatim: viewModel.formattedTime(for: dep.when, locale: locale)))
            detailRow(label: AppText.transitDelay, value: detailDelayText(dep.delayMinutes))
            detailRow(label: AppText.transitFinalStop, value: Text(verbatim: dep.direction))

            if let bridge = dep.bridge {
                Divider()
                    .background(profileColors.divider)
                    .padding(.top, 4)

                Text(AppText.transitTransfer)
                    .font(AppStyle.Font.profileCardTitle)
                    .foregroundColor(profileColors.secondary)

                detailRow(label: AppText.transitGetOffAt, value: Text(verbatim: bridge.transferStation))
                detailRow(
                    label: AppText.transitConnection,
                    value: Text(verbatim: "\(bridge.bridgeLine) → \(bridge.bridgeDirection)")
                )
                detailRow(
                    label: AppText.transitConnectionDeparture,
                    value: Text(verbatim: viewModel.formattedTime(for: bridge.bridgeDeparture, locale: locale))
                )
            } else {
                detailRow(label: AppText.transitConnection, value: Text(AppText.transitDirectTo(destination: viewModel.toLabel)))
            }

            if let arrival = dep.arrivalAtDestination {
                detailRow(
                    label: AppText.transitArrivalLabel(destination: viewModel.toLabel),
                    value: Text(verbatim: viewModel.formattedTime(for: arrival, locale: locale))
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(label: LocalizedStringResource, value: Text) -> some View {
        HStack(alignment: .top, spacing: AppStyle.DeviceLayout.cardSpacing) {
            Text(label)
                .font(AppStyle.Font.detailCaption)
                .foregroundColor(profileColors.secondary)
                .frame(width: 130, alignment: .leading)
            value
                .font(AppStyle.Font.detailCaption)
                .foregroundColor(profileColors.title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func detailDelayText(_ delay: Int) -> Text {
        if delay > 0 { return Text(verbatim: "+\(delay) min") }
        if delay < 0 { return Text(verbatim: "\(delay) min") }
        return Text(AppText.transitOnTime)
    }

    // MARK: - Error / Footer

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

    private var footer: some View {
        VStack(alignment: .leading, spacing: AppStyle.DeviceLayout.cardSpacing) {
            footerStatusText

            HStack {
                Spacer()

                RefreshActionButton(isLoading: viewModel.isLoading) {
                    Task { await viewModel.refresh() }
                }
                .accessibilityIdentifier("id_profile_sbahn_refresh")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var footerStatusText: some View {
        if let lastUpdated = viewModel.formattedLastUpdated(locale: locale) {
            if viewModel.isShowingCachedResult {
                Text(AppText.transitLastRequest(time: lastUpdated))
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
