//
//  LandingDetector.swift
//  FlightCoach
//
//  Created by FlightCoach Development Team.
//

import Foundation

/// Detector for landing events
///
/// Landing is defined as the Weight-On-Wheels (WOW) transition from 0 → 1
/// Characteristics:
/// - Clear WOW signal transition
/// - Decreasing airspeed
/// - Positive descent rate before touchdown
/// - Low altitude
actor LandingDetector: ManeuverDetector {
    let maneuverType: ManeuverType = .landing
    private let config: DetectionConfiguration

    init(config: DetectionConfiguration = .groundTransition) {
        self.config = config
    }

    func detect(in dataPoints: [FlightDataPoint]) async -> [Maneuver] {
        guard dataPoints.count >= config.minDataPoints else {
            return []
        }

        var detectedManeuvers: [Maneuver] = []

        // Find all WOW transitions from air to ground (0 → 1)
        let touchdownPoints = dataPoints.fallingEdges { $0.isAirborne }

        for touchdownIdx in touchdownPoints {
            // Look backward to find approach start (typically base turn or final)
            let startIdx = findApproachStart(beforeTouchdown: touchdownIdx, in: dataPoints)

            // Look forward to find rollout completion
            let endIdx = findRolloutEnd(afterTouchdown: touchdownIdx, in: dataPoints)

            guard endIdx > startIdx else { continue }

            // Validate characteristics
            let duration = dataPoints[endIdx].irigTime.timeIntervalSince(dataPoints[startIdx].irigTime)
            guard duration >= config.minDuration && duration <= config.maxDuration else {
                continue
            }

            // Calculate confidence
            let confidence = calculateConfidence(
                startIndex: startIdx,
                touchdownIndex: touchdownIdx,
                endIndex: endIdx,
                data: dataPoints
            )

            guard confidence >= config.minConfidence else {
                continue
            }

            // Create maneuver
            let maneuver = Maneuver(
                id: UUID(),
                type: .landing,
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

    /// Find the start of the approach before touchdown
    private func findApproachStart(beforeTouchdown touchdownIdx: Int, in data: [FlightDataPoint]) -> Int {
        // Look back up to 20 seconds (400 data points)
        let maxLookback = min(400, touchdownIdx)
        let startSearchIdx = touchdownIdx - maxLookback

        // Find where descent started (typically from pattern altitude)
        for i in stride(from: touchdownIdx - 1, through: startSearchIdx, by: -1) {
            // Look for level or climbing flight before descent
            if i > 20 {
                let recentVerticalVelocity = (data[i].altitude - data[i - 20].altitude) / 1.0  // Over 1 second
                if recentVerticalVelocity > -50 {  // Not descending much
                    return i
                }
            }
        }

        return max(0, touchdownIdx - 200)  // Default to 10 seconds before
    }

    /// Find where rollout ends (aircraft comes to stop or exits runway)
    private func findRolloutEnd(afterTouchdown touchdownIdx: Int, in data: [FlightDataPoint]) -> Int {
        // Look ahead up to 20 seconds
        let maxLookahead = min(400, data.count - touchdownIdx)
        let endSearchIdx = touchdownIdx + maxLookahead

        // Find where aircraft slows significantly or stops
        for i in (touchdownIdx + 20)..<endSearchIdx {
            let airspeed = data[i].computedAirspeed

            // Very slow or stopped
            if airspeed < 10.0 {
                return i
            }

            // Check for taxi speed (slow and steady)
            if airspeed < 30.0 {
                let checkWindow = min(i + 40, data.count)
                if i + 40 < data.count {
                    let speedStdDev = data.standardDeviation(of: \.computedAirspeed, in: i..<checkWindow)
                    if speedStdDev < 5.0 {  // Steady taxi speed
                        return i
                    }
                }
            }
        }

        // Default to 15 seconds after touchdown
        return min(touchdownIdx + 300, data.count - 1)
    }

    /// Calculate confidence score
    private func calculateConfidence(
        startIndex: Int,
        touchdownIndex: Int,
        endIndex: Int,
        data: [FlightDataPoint]
    ) -> Double {
        var score = 0.0
        var maxScore = 0.0

        // 1. Clear WOW transition (40 points) - this is definitive
        maxScore += 40.0
        if data[touchdownIndex - 1].isAirborne && !data[touchdownIndex].isAirborne {
            score += 40.0
        }

        // 2. Airspeed decrease (20 points)
        maxScore += 20.0
        let startSpeed = data[startIndex].computedAirspeed
        let endSpeed = data[endIndex].computedAirspeed
        if startSpeed > endSpeed + 30.0 {  // Lost at least 30 kts
            score += 20.0
        } else if startSpeed > endSpeed {
            score += 10.0
        }

        // 3. Altitude descent (20 points)
        maxScore += 20.0
        let altitudeLoss = data[startIndex].altitude - data[touchdownIndex].altitude
        if altitudeLoss > 100.0 {  // Reasonable descent
            score += 20.0
        } else if altitudeLoss > 20.0 {
            score += 10.0
        }

        // 4. Low final altitude (20 points) - should be near ground
        maxScore += 20.0
        let touchdownAltitude = data[touchdownIndex].altitude
        if touchdownAltitude < 100.0 {  // Near field elevation
            score += 20.0
        } else if touchdownAltitude < 500.0 {
            score += 10.0
        }

        return score / maxScore
    }
}
