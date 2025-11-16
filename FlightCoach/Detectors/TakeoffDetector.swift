//
//  TakeoffDetector.swift
//  FlightCoach
//
//  Created by FlightCoach Development Team.
//

import Foundation

/// Detector for takeoff events
///
/// Takeoff is defined as the Weight-On-Wheels (WOW) transition from 1 → 0
/// Characteristics:
/// - Clear WOW signal transition
/// - Increasing airspeed
/// - Positive pitch angle
/// - Increasing altitude
actor TakeoffDetector: ManeuverDetector {
    let maneuverType: ManeuverType = .takeoff
    private let config: DetectionConfiguration

    init(config: DetectionConfiguration = .groundTransition) {
        self.config = config
    }

    func detect(in dataPoints: [FlightDataPoint]) async -> [Maneuver] {
        guard dataPoints.count >= config.minDataPoints else {
            return []
        }

        var detectedManeuvers: [Maneuver] = []

        // Find all WOW transitions from ground to air (1 → 0)
        let liftoffPoints = dataPoints.risingEdges { $0.isAirborne }

        for liftoffIdx in liftoffPoints {
            // Look backward to find rotation start
            let startIdx = findRotationStart(beforeLiftoff: liftoffIdx, in: dataPoints)

            // Look forward to find climb stabilization
            let endIdx = findClimbStabilization(afterLiftoff: liftoffIdx, in: dataPoints)

            guard endIdx > startIdx else { continue }

            // Validate characteristics
            let duration = dataPoints[endIdx].irigTime.timeIntervalSince(dataPoints[startIdx].irigTime)
            guard duration >= config.minDuration && duration <= config.maxDuration else {
                continue
            }

            // Calculate confidence
            let confidence = calculateConfidence(
                startIndex: startIdx,
                liftoffIndex: liftoffIdx,
                endIndex: endIdx,
                data: dataPoints
            )

            guard confidence >= config.minConfidence else {
                continue
            }

            // Create maneuver
            let maneuver = Maneuver(
                id: UUID(),
                type: .takeoff,
                startTime: dataPoints[startIdx].irigTime,
                endTime: dataPoints[endIdx].irigTime,
                startIndex: startIdx,
                endIndex: endIdx,
                confidence: confidence,
                detectionMethod: .ruleBased,
                metrics: nil,
                phases: nil
            )

            detectedManeuvers.append(maneuver)
        }

        return detectedManeuvers
    }

    // MARK: - Helper Methods

    /// Find the start of rotation (pitch increase) before liftoff
    private func findRotationStart(beforeLiftoff liftoffIdx: Int, in data: [FlightDataPoint]) -> Int {
        // Look back up to 10 seconds (200 data points)
        let maxLookback = min(200, liftoffIdx)
        let startSearchIdx = liftoffIdx - maxLookback

        // Find where pitch started increasing
        for i in stride(from: liftoffIdx - 1, through: startSearchIdx, by: -1) {
            if data[i].pitchAngle < 2.0 {  // Ground roll pitch
                return i
            }
        }

        return max(0, liftoffIdx - 40)  // Default to 2 seconds before
    }

    /// Find where climb stabilizes after liftoff
    private func findClimbStabilization(afterLiftoff liftoffIdx: Int, in data: [FlightDataPoint]) -> Int {
        // Look ahead up to 20 seconds
        let maxLookahead = min(400, data.count - liftoffIdx)
        let endSearchIdx = liftoffIdx + maxLookahead

        // Find where climb rate stabilizes
        for i in (liftoffIdx + 20)..<endSearchIdx {
            let pitchAngle = data[i].pitchAngle

            // Stable climb: 10-20° pitch, steady airspeed
            if pitchAngle > 10.0 && pitchAngle < 25.0 {
                // Check stability over next 2 seconds
                let checkWindow = min(i + 40, data.count)
                let pitchStdDev = data.standardDeviation(of: \.pitchAngle, in: i..<checkWindow)

                if pitchStdDev < 5.0 {  // Stable pitch
                    return i
                }
            }
        }

        // Default to 10 seconds after liftoff
        return min(liftoffIdx + 200, data.count - 1)
    }

    /// Calculate confidence score
    private func calculateConfidence(
        startIndex: Int,
        liftoffIndex: Int,
        endIndex: Int,
        data: [FlightDataPoint]
    ) -> Double {
        var score = 0.0
        var maxScore = 0.0

        // 1. Clear WOW transition (40 points) - this is definitive
        maxScore += 40.0
        if !data[liftoffIndex - 1].isAirborne && data[liftoffIndex].isAirborne {
            score += 40.0
        }

        // 2. Airspeed increase (20 points)
        maxScore += 20.0
        let startSpeed = data[startIndex].computedAirspeed
        let endSpeed = data[endIndex].computedAirspeed
        if endSpeed > startSpeed + 20.0 {  // Gained at least 20 kts
            score += 20.0
        } else if endSpeed > startSpeed {
            score += 10.0
        }

        // 3. Altitude gain (20 points)
        maxScore += 20.0
        let altitudeGain = data[endIndex].altitude - data[startIndex].altitude
        if altitudeGain > 100.0 {  // Reasonable climb
            score += 20.0
        } else if altitudeGain > 30.0 {
            score += 10.0
        }

        // 4. Pitch attitude (20 points)
        maxScore += 20.0
        let maxPitch = data[startIndex...endIndex].map { $0.pitchAngle }.max() ?? 0
        if maxPitch > 10.0 && maxPitch < 30.0 {
            score += 20.0  // Typical takeoff pitch
        } else if maxPitch > 5.0 {
            score += 10.0
        }

        return score / maxScore
    }
}
