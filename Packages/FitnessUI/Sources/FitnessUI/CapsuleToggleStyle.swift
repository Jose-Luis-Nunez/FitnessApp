import FitnessResources
import SwiftUI

public struct CapsuleToggleStyle: ToggleStyle {
    public var onColor: Color
    public var offColor: Color

    public init(onColor: Color, offColor: Color) {
        self.onColor = onColor
        self.offColor = offColor
    }

    public func makeBody(configuration: Configuration) -> some View {
        let thumbOffset = (AppStyle.Layout.capsuleToggleWidth - AppStyle.Layout.capsuleToggleThumb) / 2 - 2
        Button(action: { configuration.isOn.toggle() }) {
            RoundedRectangle(cornerRadius: AppStyle.CornerRadius.capsuleToggle, style: .continuous)
                .fill(configuration.isOn ? onColor : offColor)
                .frame(width: AppStyle.Layout.capsuleToggleWidth, height: AppStyle.Layout.capsuleToggleHeight)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: AppStyle.Layout.capsuleToggleThumb, height: AppStyle.Layout.capsuleToggleThumb)
                        .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                        .offset(x: configuration.isOn ? thumbOffset : -thumbOffset)
                        .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppText.accessibilityDecimalSwitch)
    }
}
