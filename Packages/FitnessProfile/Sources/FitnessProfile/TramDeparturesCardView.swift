import SwiftUI
import FitnessUI

public struct TramDeparturesCardView: View {

    @Bindable private var viewModel: TramDeparturesViewModel
    @Environment(\.scenePhase) private var scenePhase

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
        .padding(AppStyle.Padding.card)
        .frame(
            maxWidth: .infinity,
            minHeight: AppStyle.Layout.profileCardCollapsedMinHeight,
            alignment: .leading
        )
        .background(AppStyle.Color.profileCardBackground)
        .cornerRadius(AppStyle.CornerRadius.card)
        .onChange(of: scenePhase) { _, newPhase in
            guard viewModel.isExpanded else { return }
            switch newPhase {
            case .active:
                viewModel.onBecameActive()
            case .inactive, .background:
                viewModel.stopAutoRefresh()
            @unknown default:
                break
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
                    .foregroundColor(AppStyle.Color.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Tram \(viewModel.lineName)")
                        .font(AppStyle.Font.sectionHeadline)
                        .foregroundColor(AppStyle.Color.white)
                        .fixedSize()

                    Text("\(viewModel.fromLabel) → \(viewModel.toLabel)")
                        .font(AppStyle.Font.profileCardTitle)
                        .foregroundColor(AppStyle.Color.greenLight)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(AppStyle.Font.profileSmallIcon)
                    .foregroundColor(AppStyle.Color.greenLight)
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
            endpointPill(text: viewModel.fromLabel, caption: "Start")

            Button {
                viewModel.swap()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(AppStyle.Font.profileEditIcon)
                    .foregroundColor(AppStyle.Color.green)
                    .frame(width: AppStyle.Layout.checkmarkSize, height: AppStyle.Layout.checkmarkSize)
                    .background(AppStyle.Color.sheetInputBackground)
                    .cornerRadius(AppStyle.CornerRadius.defaultButton)
            }
            .accessibilityIdentifier("id_profile_tram_swap")

            endpointPill(text: viewModel.toLabel, caption: "Destination")
        }
    }

    private func endpointPill(text: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caption)
                .font(AppStyle.Font.profileCardTitle)
                .foregroundColor(AppStyle.Color.greenLight)
            Text(text)
                .font(AppStyle.Font.tileValue)
                .foregroundColor(AppStyle.Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, AppStyle.Padding.card)
        .padding(.vertical, AppStyle.Layout.profileInputPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppStyle.Color.sheetInputBackground)
        .cornerRadius(AppStyle.CornerRadius.tile)
    }

    // MARK: - Content Body

    @ViewBuilder
    private var contentBody: some View {
        if viewModel.isLoading && viewModel.departures.isEmpty {
            loadingRow
        } else if !viewModel.departures.isEmpty {
            departuresList
        } else if viewModel.errorMessage == nil {
            emptyRow
        }

        if let error = viewModel.errorMessage {
            errorRow(error)
        }
    }

    private var loadingRow: some View {
        HStack {
            ProgressView()
                .tint(AppStyle.Color.green)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppStyle.Layout.profileButtonPadding)
    }

    private var emptyRow: some View {
        Text("Keine Abfahrten in den nächsten 60 Minuten.")
            .font(AppStyle.Font.detailCaption)
            .foregroundColor(AppStyle.Color.gray)
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
            Text(dep.line)
                .font(AppStyle.Font.cardSmallBold)
                .foregroundColor(AppStyle.Color.white)
                .frame(minWidth: AppStyle.Layout.setRowBadgeSize, minHeight: AppStyle.Layout.setRowBadgeSize)
                .background(AppStyle.Color.green)
                .cornerRadius(AppStyle.CornerRadius.pill)

            Text(viewModel.formattedTime(for: dep.when))
                .font(AppStyle.Font.tileValue)
                .foregroundColor(AppStyle.Color.white)
                .fixedSize()

            delayBadge(for: dep.delayMinutes)

            Spacer(minLength: 0)

            Text(dep.direction)
                .font(AppStyle.Font.detailCaption)
                .foregroundColor(AppStyle.Color.greenLight)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, AppStyle.Padding.card)
        .padding(.vertical, AppStyle.Layout.profileButtonPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppStyle.Color.sheetInputBackground)
        .cornerRadius(AppStyle.CornerRadius.tile)
        .accessibilityIdentifier("id_profile_tram_row_\(index)")
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
            Text("pünktlich")
                .font(AppStyle.Font.cardSmallBold)
                .foregroundColor(AppStyle.Color.green)
        }
    }

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

    // MARK: - Footer

    private var footer: some View {
        HStack {
            footerStatusText

            Spacer()

            RefreshActionButton(isLoading: viewModel.isLoading) {
                Task { await viewModel.refresh() }
            }
            .accessibilityIdentifier("id_profile_tram_refresh")
        }
    }

    @ViewBuilder
    private var footerStatusText: some View {
        if let lastUpdated = viewModel.formattedLastUpdated {
            if viewModel.isStale {
                Text("No internet · cached \(lastUpdated)")
                    .font(AppStyle.Font.sheetCaption)
                    .foregroundColor(AppStyle.Color.yellow)
            } else {
                Text("Updated \(lastUpdated)")
                    .font(AppStyle.Font.sheetCaption)
                    .foregroundColor(AppStyle.Color.gray)
            }
        }
    }
}
