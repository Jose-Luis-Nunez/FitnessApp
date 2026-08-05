import FitnessCore
import FitnessUI
import SwiftUI

extension TotalAnalyticsView {

    var categoryProgressView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(AppStyle.Font.analyticsExerciseData)
                .foregroundColor(AppStyle.Color.white)
                .padding(.horizontal, AppStyle.Padding.horizontal)

            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        let cardWidth = geometry.size.width * 0.90 - (AppStyle.Padding.horizontal * 2)

                        ForEach(categoryProgressData) { data in
                            categoryCard(data: data)
                                .frame(width: cardWidth)
                                .frame(height: 300)
                        }
                    }
                    .padding(.horizontal, AppStyle.Padding.horizontal)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
            }
            .frame(height: 320)
        }
    }

    func categoryCard(data: CategoryProgressData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Category: \(data.category.displayName)")
                    .font(AppStyle.Font.cardHeadline)
                    .foregroundColor(AppStyle.Color.white)

                Spacer()

                Text("\(data.exerciseCount) exercise\(data.exerciseCount == 1 ? "" : "s")")
                    .font(AppStyle.Font.calendarSubheader)
                    .foregroundColor(AppStyle.Color.greenGlow)
            }
            .frame(height: 30)

            if data.exercises.isEmpty {
                VStack {
                    Spacer()
                    Text("No training")
                        .font(AppStyle.Font.pickerAction)
                        .foregroundColor(AppStyle.Color.white.opacity(0.6))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ZStack(alignment: .bottom) {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(data.exercises) { exerciseData in
                                exerciseProgressRow(data: exerciseData)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.bottom, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if data.exercises.count > 3 {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(AppStyle.Font.chartAxisSmall)
                                    .foregroundColor(AppStyle.Color.white.opacity(0.5))
                                    .padding(.bottom, 4)
                                Spacer()
                            }
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }

    func exerciseProgressRow(data: ExerciseProgressData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(data.exercise.name)
                .font(AppStyle.Font.detailExercise)
                .foregroundColor(AppStyle.Color.white)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start")
                        .font(AppStyle.Font.chartLabel)
                        .foregroundColor(AppStyle.Color.white.opacity(0.6))
                    HStack(spacing: 4) {
                        Text("\(formatWeight(data.initialWeight)) kg")
                            .font(AppStyle.Font.detailCaption)
                            .foregroundColor(AppStyle.Color.white)
                        Text("(\(formatDateShort(data.startDate)))")
                            .font(AppStyle.Font.chartAxisSmall)
                            .foregroundColor(AppStyle.Color.white.opacity(0.6))
                    }
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    Text("Current")
                        .font(AppStyle.Font.chartLabel)
                        .foregroundColor(AppStyle.Color.white.opacity(0.6))
                    Text("\(formatWeight(data.currentWeight)) kg")
                        .font(AppStyle.Font.detailCaption)
                        .foregroundColor(AppStyle.Color.greenGlow)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Progress")
                        .font(AppStyle.Font.chartLabel)
                        .foregroundColor(AppStyle.Color.white.opacity(0.6))

                    let difference = data.weightDifference
                    let percentage = data.weightPercentage
                    let frequency = data.improvementFrequency

                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(spacing: 2) {
                            if difference > 0 {
                                Text("+\(formatWeight(difference)) kg")
                                    .font(AppStyle.Font.cardSmallMedium)
                                    .foregroundColor(AppStyle.Color.green)
                                Text("(\(String(format: "%.1f", frequency)))")
                                    .font(AppStyle.Font.analyticsAxis)
                                    .foregroundColor(AppStyle.Color.green.opacity(0.7))
                            } else if difference < 0 {
                                Text("\(formatWeight(difference)) kg")
                                    .font(AppStyle.Font.cardSmallMedium)
                                    .foregroundColor(.red)
                                Text("(\(String(format: "%.1f", frequency)))")
                                    .font(AppStyle.Font.analyticsAxis)
                                    .foregroundColor(.red.opacity(0.7))
                            } else {
                                Text("0 kg")
                                    .font(AppStyle.Font.cardSmallMedium)
                                    .foregroundColor(AppStyle.Color.white.opacity(0.6))
                                Text("(\(String(format: "%.1f", frequency)))")
                                    .font(AppStyle.Font.analyticsAxis)
                                    .foregroundColor(AppStyle.Color.white.opacity(0.4))
                            }
                        }

                        if percentage != 0 {
                            Text(percentage > 0 ? "+\(Int(percentage))%" : "\(Int(percentage))%")
                                .font(AppStyle.Font.analyticsAxis)
                                .foregroundColor(percentage > 0 ? AppStyle.Color.green.opacity(0.8) : .red.opacity(0.8))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    func formatDateShort(_ date: Date) -> String {
        DateFormatter.germanVeryShort.string(from: date)
    }

    func formatWeight(_ weight: Double) -> String {
        WeightFormatter.format(weight)
    }
}
