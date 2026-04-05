import SwiftUI

struct AnalyticsDetailSection<Header: View, Content: View>: View {
    let shouldShowIndicator: Bool
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            header()

            ZStack(alignment: .bottom) {
                ScrollView {
                    content()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                }

                if shouldShowIndicator {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppStyle.Color.greenGlow.opacity(0.6))
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
                .fill(AppStyle.Color.greenBlack.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: AppStyle.CornerRadius.card)
                        .stroke(AppStyle.Color.greenGlow.opacity(0.2), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .scale))
        .onTapGesture {}
    }
}

struct AnalyticsDetailHeader: View {
    let title: String
    let subtitle: String?
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onBack()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(AppStyle.Font.tileLabel)
                    Text("Back")
                        .font(AppStyle.Font.tileLabel)
                }
                .foregroundColor(AppStyle.Color.greenGlow)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppStyle.Color.greenGlow)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppStyle.Color.greenGlow)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(AppStyle.Font.tileLabel)
                Text("Back")
                    .font(AppStyle.Font.tileLabel)
            }
            .opacity(0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
