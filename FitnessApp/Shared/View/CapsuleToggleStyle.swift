import SwiftUI

// Reusable capsule toggle style used across pickers
struct CapsuleToggleStyle: ToggleStyle {
    var onColor: Color
    var offColor: Color

    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(configuration.isOn ? onColor : offColor)
                .frame(width: 44, height: 26)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                        .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                        .offset(x: configuration.isOn ? 9 : -9)
                        .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dezimal umschalten")
    }
}


