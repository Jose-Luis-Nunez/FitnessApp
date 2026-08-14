import FitnessResources
import FitnessUI
import SwiftUI

public struct AnalyticsDetailSection<Header: View, Content: View>: View {
    @Environment(\.appColorTheme) private var appColorTheme
    public let shouldShowIndicator: Bool
    private let headerBuilder: () -> Header
    private let contentBuilder: () -> Content

    public init(
        shouldShowIndicator: Bool,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.shouldShowIndicator = shouldShowIndicator
        self.headerBuilder = header
        self.contentBuilder = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBuilder()

            ZStack(alignment: .bottom) {
                ScrollView {
                    contentBuilder()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                }

                if shouldShowIndicator {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(AppStyle.Font.chartAxisSmall)
                                .foregroundColor(appColorTheme.accent.glow.opacity(0.6))
                                .padding(.bottom, 8)
                            Spacer()
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(height: 271)
        .background(
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card)
                .fill(appColorTheme.accent.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card)
                        .stroke(appColorTheme.accent.glow.opacity(0.2), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .scale))
        .onTapGesture {}
    }
}

public struct AnalyticsDetailHeader: View {
    @Environment(\.appColorTheme) private var appColorTheme
    public let title: LocalizedStringResource
    public let subtitle: String?
    public let onBack: () -> Void

    public init(title: LocalizedStringResource, subtitle: String?, onBack: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.onBack = onBack
    }

    public var body: some View {
        HStack {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onBack()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(AppStyle.Font.tileLabel)
                    Text(AppText.actionBack)
                        .font(AppStyle.Font.tileLabel)
                }
                .foregroundColor(appColorTheme.accent.glow)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(title)
                    .font(AppStyle.Font.cardValueBold)
                    .foregroundColor(appColorTheme.accent.glow)

                if let subtitle = subtitle {
                    Text(verbatim: subtitle)
                        .font(AppStyle.Font.streakLabel)
                        .foregroundColor(appColorTheme.accent.glow)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(AppStyle.Font.tileLabel)
                Text(AppText.actionBack)
                    .font(AppStyle.Font.tileLabel)
            }
            .opacity(0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
