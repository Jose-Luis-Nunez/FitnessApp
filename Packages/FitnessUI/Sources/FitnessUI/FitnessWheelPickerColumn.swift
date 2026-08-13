import SwiftUI

/// Reusable wheel-picker column with a title and a typed selection binding.
///
/// Works with any `Hashable` value type. Rendering of each option is delegated
/// to the caller via `label`, which keeps locale-sensitive formatting (e.g.
/// weight with a decimal separator) out of this component.
///
/// Designed so features like the Profile body-metrics row and the Exercise
/// set/rep/weight picker can share a single implementation. Use inside an
/// `HStack` to build multi-column wheels and apply
/// `AppStyle.Layout.profileWheelHeight` on the parent container.
public struct FitnessWheelPickerColumn<Value: Hashable, Label: View>: View {
    public let title: String
    @Binding public var selection: Value
    public let values: [Value]
    public let accessibilityID: String?
    private let label: (Value) -> Label
    @Environment(\.appColorTheme) private var appColorTheme

    private var profileColors: ProfileColorTheme { appColorTheme.profile }

    public init(
        title: String,
        selection: Binding<Value>,
        values: [Value],
        accessibilityID: String? = nil,
        @ViewBuilder label: @escaping (Value) -> Label
    ) {
        self.title = title
        _selection = selection
        self.values = values
        self.accessibilityID = accessibilityID
        self.label = label
    }

    public var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(AppStyle.Font.profileCardTitle)
                .foregroundColor(profileColors.secondary)
                .frame(maxWidth: .infinity)

            Picker(title, selection: $selection) {
                ForEach(values, id: \.self) { value in
                    label(value)
                        .tag(value)
                        .foregroundColor(profileColors.accent)
                }
            }
#if os(iOS)
            .pickerStyle(.wheel)
#else
            .pickerStyle(.menu)
#endif
            .frame(maxWidth: .infinity)
            .clipped()
            .modifier(OptionalAccessibilityID(id: accessibilityID))
        }
    }
}

private struct OptionalAccessibilityID: ViewModifier {
    let id: String?

    func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}
