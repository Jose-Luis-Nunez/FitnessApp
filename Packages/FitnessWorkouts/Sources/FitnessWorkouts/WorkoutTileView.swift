import SwiftUI
import FitnessCore
import FitnessUI

public struct WorkoutTileView: View {
    let workout: Workout
    let isDefault: Bool
    let exerciseCount: Int
    let onTap: () -> Void
    var onLongPress: (() -> Void)? = nil
    var onSettingsTap: (() -> Void)? = nil

    private static let cornerRadius: CGFloat = AppStyle.CornerRadius.defaultButton

    public init(
        workout: Workout,
        isDefault: Bool,
        exerciseCount: Int,
        onTap: @escaping () -> Void,
        onLongPress: (() -> Void)? = nil,
        onSettingsTap: (() -> Void)? = nil
    ) {
        self.workout = workout
        self.isDefault = isDefault
        self.exerciseCount = exerciseCount
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.onSettingsTap = onSettingsTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    if let onSettingsTap {
                        Button(action: onSettingsTap) {
                            Image("settingsIconMenu")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                                .foregroundColor(AppStyle.Color.white.opacity(0.8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 6)

                Spacer()

                Text(workout.name)
                    .font(AppStyle.Font.categorySelectionNameFont)
                    .foregroundColor(AppStyle.Color.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Spacer()
            }
            .padding(16)
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .appDarkSurface(
                backgroundColor: isDefault ? AppStyle.Color.green.opacity(0.2) : AppStyle.Color.exerciseCardBackground,
                in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
            )
            .overlay {
                if isDefault {
                    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                        .stroke(AppStyle.Color.green, lineWidth: 2)
                }
            }
            .overlay(
                VStack {
                    HStack {
                        ZStack {
                            Circle()
                                .stroke(
                                    isDefault ? AppStyle.Color.green : Color.white.opacity(0.6),
                                    lineWidth: 3
                                )
                                .frame(width: 34, height: 34)
                            Circle()
                                .stroke(
                                    isDefault ? AppStyle.Color.green.opacity(0.4) : Color.white.opacity(0.3),
                                    lineWidth: 1
                                )
                                .frame(width: 26, height: 26)
                            Text("\(exerciseCount)")
                                .font(AppStyle.Font.detailBadge)
                                .foregroundColor(isDefault ? AppStyle.Color.green : Color.white)
                        }
                        .padding(.leading, 20)
                        .padding(.top, 20)
                        Spacer()
                    }
                    Spacer()
                }
            )
        }
        .onLongPressGesture {
            onLongPress?()
        }
    }
}
