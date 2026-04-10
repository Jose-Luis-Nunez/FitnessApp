import FitnessUI
import SwiftUI

public struct AnalyticsTileNumberView: View {
    public let number: String
    public let label: String

    public init(number: String, label: String) {
        self.number = number
        self.label = label
    }

    public var body: some View {
        VStack(spacing: 4) {
            Text(number)
                .font(AppStyle.Font.analyticsBigNumber)
                .foregroundColor(AppStyle.Color.greenGlow)

            Text(label)
                .font(AppStyle.Font.chartAxisSmall)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(height: 85)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

public struct AnalyticsTileTextView: View {
    public let text: String
    public let label: String

    public init(text: String, label: String) {
        self.text = text
        self.label = label
    }

    public var body: some View {
        VStack(spacing: 6) {
            Text(text)
                .font(AppStyle.Font.cardHeadline)
                .foregroundColor(AppStyle.Color.greenGlow)
                .lineLimit(1)

            Text(label)
                .font(AppStyle.Font.chartAxisSmall)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(height: 85)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}
