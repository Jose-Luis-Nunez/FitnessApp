import SwiftUI
import FitnessUI

public struct SBahnDeparturesCardView: View {

    @Bindable private var viewModel: SBahnDeparturesViewModel
    @Environment(\.profileColorTheme) private var profileColors

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

                VStack(alignment: .leading, spacing: 2) {
                    Text("S-Bahn")
                        .font(AppStyle.Font.sectionHeadline)
                        .foregroundColor(profileColors.title)
                        .fixedSize()

                    Text("\(viewModel.fromLabel) → \(viewModel.toLabel)")
                        .font(AppStyle.Font.profileCardTitle)
                        .foregroundColor(profileColors.secondary)
                        .lineLimit(1)
                }

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
            endpointPill(text: viewModel.fromLabel, caption: "Start")

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

            endpointPill(text: viewModel.toLabel, caption: "Destination")
        }
    }

    private func endpointPill(text: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caption)
                .font(AppStyle.Font.profileCardTitle)
                .foregroundColor(profileColors.secondary)
            Text(text)
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
        } else if viewModel.errorMessage == nil {
            if viewModel.lastUpdated == nil {
                requestPromptRow
            } else {
                emptyRow
            }
        }

        if let error = viewModel.errorMessage {
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
        Text("No trains in the next 60 minutes.")
            .font(AppStyle.Font.detailCaption)
            .foregroundColor(profileColors.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var requestPromptRow: some View {
        Text("Tap Refresh to load departures.")
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
                    Text(dep.line)
                        .font(AppStyle.Font.cardSmallBold)
                        .foregroundColor(profileColors.onAccent)
                        .frame(minWidth: AppStyle.Layout.setRowBadgeSize, minHeight: AppStyle.Layout.setRowBadgeSize)
                        .background(profileColors.accentFill)
                        .cornerRadius(AppStyle.CornerRadius.pill)

                    Text(viewModel.formattedTime(for: dep.plannedWhen))
                        .font(AppStyle.Font.tileValue)
                        .foregroundColor(profileColors.title)
                        .fixedSize()

                    delayBadge(for: dep.delayMinutes)

                    Spacer(minLength: 0)

                    Text(dep.direction)
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
        let arrivalStr = viewModel.formattedTime(for: arrival)
        return Text("→ \(viewModel.toLabel) · \(arrivalStr)")
            .font(AppStyle.Font.detailCaption)
            .foregroundColor(profileColors.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Caption rendered for east-short trips with a useful bridge.
    /// Shows the transfer hint and the estimated arrival at destination
    /// after the bridge train.
    private func bridgeCaption(bridge: BridgeHint, arrival: Date?) -> some View {
        let bridgeTimeStr = viewModel.formattedTime(for: bridge.bridgeDeparture)
        var caption = "⤷ Transfer at \(bridge.transferStation) via \(bridge.bridgeLine) · \(bridgeTimeStr)"
        if let arrival {
            caption += " → \(viewModel.toLabel) · \(viewModel.formattedTime(for: arrival))"
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
            Text("+\(delay) min")
                .font(AppStyle.Font.cardSmallBold)
                .foregroundColor(AppStyle.Color.yellow)
        } else if delay < 0 {
            Text("\(delay) min")
                .font(AppStyle.Font.cardSmallBold)
                .foregroundColor(AppStyle.Color.green)
        } else {
            Text("on time")
                .font(AppStyle.Font.cardSmallBold)
                .foregroundColor(AppStyle.Color.green)
        }
    }

    // MARK: - Detail Panel (row-tap)

    @ViewBuilder
    private func detailPanel(for dep: SBahnDeparture) -> some View {
        Divider()
            .background(profileColors.divider)

        VStack(alignment: .leading, spacing: 6) {
            detailRow(label: "Scheduled departure", value: viewModel.formattedTime(for: dep.plannedWhen))
            detailRow(label: "Current departure", value: viewModel.formattedTime(for: dep.when))
            detailRow(label: "Delay", value: detailDelayString(dep.delayMinutes))
            detailRow(label: "Final stop", value: dep.direction)

            if let bridge = dep.bridge {
                Divider()
                    .background(profileColors.divider)
                    .padding(.top, 4)

                Text("Transfer")
                    .font(AppStyle.Font.profileCardTitle)
                    .foregroundColor(profileColors.secondary)

                detailRow(label: "Get off at", value: bridge.transferStation)
                detailRow(
                    label: "Connection",
                    value: "\(bridge.bridgeLine) → \(bridge.bridgeDirection)"
                )
                detailRow(
                    label: "Connection departure",
                    value: viewModel.formattedTime(for: bridge.bridgeDeparture)
                )
            } else {
                detailRow(label: "Connection", value: "Direct to \(viewModel.toLabel)")
            }

            if let arrival = dep.arrivalAtDestination {
                detailRow(
                    label: "Ankunft \(viewModel.toLabel)",
                    value: viewModel.formattedTime(for: arrival)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: AppStyle.DeviceLayout.cardSpacing) {
            Text(label)
                .font(AppStyle.Font.detailCaption)
                .foregroundColor(profileColors.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(AppStyle.Font.detailCaption)
                .foregroundColor(profileColors.title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func detailDelayString(_ delay: Int) -> String {
        if delay > 0 { return "+\(delay) min" }
        if delay < 0 { return "\(delay) min" }
        return "on time"
    }

    // MARK: - Error / Footer

    private func errorRow(_ message: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "wifi.slash")
                .font(AppStyle.Font.profileSmallIcon)
            Text(message)
                .font(AppStyle.Font.detailCaption)
                .lineLimit(2)
        }
        .foregroundColor(AppStyle.Color.yellow)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            footerStatusText

            Spacer()

            RefreshActionButton(isLoading: viewModel.isLoading) {
                Task { await viewModel.refresh() }
            }
            .accessibilityIdentifier("id_profile_sbahn_refresh")
        }
    }

    @ViewBuilder
    private var footerStatusText: some View {
        if let lastUpdated = viewModel.formattedLastUpdated {
            if viewModel.isShowingCachedResult {
                Text("Last request \(lastUpdated)")
                    .font(AppStyle.Font.sheetCaption)
                    .foregroundColor(AppStyle.Color.yellow)
            } else {
                Text("Updated \(lastUpdated)")
                    .font(AppStyle.Font.sheetCaption)
                    .foregroundColor(profileColors.secondary)
            }
        }
    }
}
