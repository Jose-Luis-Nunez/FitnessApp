import Foundation
import SwiftUI

// MARK: - Progress Chart Calculator
class ProgressChartCalculator {
    struct ChartPoint {
        let weight: Double
        let xPosition: CGFloat
        let yPosition: CGFloat
        let isCurrentWeight: Bool
    }
    
    static func calculateDynamicMilestones(
        milestones: [(date: Date, weight: Double)],
        currentWeight: Double,
        geometry: GeometryProxy
    ) -> [ChartPoint] {
        guard !milestones.isEmpty else { return [] }
        
        // Limit to maximum 5 milestones with smart filtering
        let filteredMilestones = limitToFiveMilestones(milestones)
        
        let width = geometry.size.width
        let height = geometry.size.height
        let chartTopY = height * 0.25    // 25% from top (more margin)
        let chartBottomY = height * 0.75  // 75% from top (more margin)
        let chartRange = chartBottomY - chartTopY
        
        // Find min and max weights for proper scaling
        let weights = filteredMilestones.map { $0.weight }
        let minWeight = weights.min() ?? 0
        let maxWeight = weights.max() ?? minWeight + 1
        let weightRange = maxWeight - minWeight
        
        // If all weights are the same, use single point
        if weightRange == 0 {
            let xPos = width * 0.5
            let yPos = chartTopY + chartRange * 0.5
            return [ChartPoint(
                weight: minWeight,
                xPosition: xPos,
                yPosition: yPos,
                isCurrentWeight: true
            )]
        }
        
        var chartPoints: [ChartPoint] = []
        
        for (index, milestone) in filteredMilestones.enumerated() {
            // X position: distribute evenly across chart width (15% to 85%)
            let xProgress = filteredMilestones.count == 1 ? 0.5 : CGFloat(index) / CGFloat(filteredMilestones.count - 1)
            let xPosition = width * (0.15 + xProgress * 0.7)
            
            // Y position: proportional to actual weight value
            let weightProgress = (milestone.weight - minWeight) / weightRange
            let yPosition = chartBottomY - (chartRange * weightProgress)
            
            chartPoints.append(ChartPoint(
                weight: milestone.weight,
                xPosition: xPosition,
                yPosition: yPosition,
                isCurrentWeight: milestone.weight == currentWeight
            ))
        }
        
        return chartPoints
    }
    
    private static func limitToFiveMilestones(_ milestones: [(date: Date, weight: Double)]) -> [(date: Date, weight: Double)] {
        // If 5 or fewer milestones, return all
        guard milestones.count > 5 else { return milestones }
        
        // Behalte ersten Meilenstein (Startwert)
        let firstMilestone = milestones[0]

        // Behalte die letzten 4 Meilensteine (neueste Fortschritte)  
        let lastFourMilestones = Array(milestones.suffix(4))

        // Kombiniere: [Startwert] + [neueste 4]
        return [firstMilestone] + lastFourMilestones
    }
    
    static func generateCurvePath(
        chartPoints: [ChartPoint],
        geometry: GeometryProxy
    ) -> Path {
        Path { path in
            let width = geometry.size.width
            let height = geometry.size.height
            let bottomY = height * 0.75  // Match chartBottomY
            
            if chartPoints.isEmpty {
                // Fallback: simple horizontal line
                path.move(to: CGPoint(x: 0, y: bottomY))
                path.addLine(to: CGPoint(x: width, y: bottomY))
            } else {
                // Start from bottom left
                path.move(to: CGPoint(x: 0, y: bottomY))
                
                // Create smooth curve through milestone points
                for (index, point) in chartPoints.enumerated() {
                    if index == 0 {
                        // Straighter curve to first point - no wave
                        path.addCurve(
                            to: CGPoint(x: point.xPosition, y: point.yPosition),
                            control1: CGPoint(x: point.xPosition * 0.5, y: bottomY - 2),
                            control2: CGPoint(x: point.xPosition * 0.8, y: point.yPosition + 5)
                        )
                    } else {
                        let previousPoint = chartPoints[index - 1]
                        let controlDistance = (point.xPosition - previousPoint.xPosition) * 0.3
                        
                        path.addCurve(
                            to: CGPoint(x: point.xPosition, y: point.yPosition),
                            control1: CGPoint(x: previousPoint.xPosition + controlDistance, y: previousPoint.yPosition),
                            control2: CGPoint(x: point.xPosition - controlDistance, y: point.yPosition)
                        )
                    }
                }
                
                // Curve to end
                if let lastPoint = chartPoints.last {
                    path.addCurve(
                        to: CGPoint(x: width, y: lastPoint.yPosition - 5),
                        control1: CGPoint(x: lastPoint.xPosition + (width - lastPoint.xPosition) * 0.3, y: lastPoint.yPosition),
                        control2: CGPoint(x: width * 0.9, y: lastPoint.yPosition - 3)
                    )
                }
            }
        }
    }
    
    static func generateCurvePathForFill(
        chartPoints: [ChartPoint],
        geometry: GeometryProxy
    ) -> Path {
        Path { path in
            let width = geometry.size.width
            let height = geometry.size.height
            let bottomY = height * 0.75  // Match chartBottomY
            
            if chartPoints.isEmpty {
                // Fallback: simple horizontal line with fill
                path.move(to: CGPoint(x: 0, y: bottomY))
                path.addLine(to: CGPoint(x: width, y: bottomY))
            } else {
                // Start from bottom left
                path.move(to: CGPoint(x: 0, y: bottomY))
                
                // Create smooth curve through milestone points
                for (index, point) in chartPoints.enumerated() {
                    if index == 0 {
                        // Straighter curve to first point - no wave
                        path.addCurve(
                            to: CGPoint(x: point.xPosition, y: point.yPosition),
                            control1: CGPoint(x: point.xPosition * 0.5, y: bottomY - 2),
                            control2: CGPoint(x: point.xPosition * 0.8, y: point.yPosition + 5)
                        )
                    } else {
                        let previousPoint = chartPoints[index - 1]
                        let controlDistance = (point.xPosition - previousPoint.xPosition) * 0.3
                        
                        path.addCurve(
                            to: CGPoint(x: point.xPosition, y: point.yPosition),
                            control1: CGPoint(x: previousPoint.xPosition + controlDistance, y: previousPoint.yPosition),
                            control2: CGPoint(x: point.xPosition - controlDistance, y: point.yPosition)
                        )
                    }
                }
                
                // Curve to end
                if let lastPoint = chartPoints.last {
                    path.addCurve(
                        to: CGPoint(x: width, y: lastPoint.yPosition - 5),
                        control1: CGPoint(x: lastPoint.xPosition + (width - lastPoint.xPosition) * 0.3, y: lastPoint.yPosition),
                        control2: CGPoint(x: width * 0.9, y: lastPoint.yPosition - 3)
                    )
                }
                
                // Close path for fill
                path.addLine(to: CGPoint(x: width, y: height))
                path.addLine(to: CGPoint(x: 0, y: height))
                path.closeSubpath()
            }
        }
    }
} 