//
//  LevelFlightDetector.swift
//  FlightCoach
//
//  Created by FlightCoach Development Team.
//

import Foundation

/// Detector for level flight segments (1g trim shots)
///
/// Level flight is characterized by:
/// - Normal acceleration near 1.0g (±0.2g)
/// - Stable altitude (minimal vertical velocity)
/// - Wings level (low roll angle)
/// - Sustained for at least a few seconds
actor LevelFlightDetector: ManeuverDetector {
    let maneuverType: ManeuverType = .levelFlight
    private let config: DetectionConfiguration

    init(config: DetectionConfiguration = .levelFlight) {
        self.config = config
    }

    func detect(in dataPoints: [FlightDataPoint]) async -> [Maneuver] {
        guard dataPoints.count >= config.minDataPoints else {
            return []
        }

        var detectedManeuvers: [Maneuver] = []
        var i = 0

        while i < dataPoints.count {
            // Skip if not airborne
            guard dataPoints[i].isAirborne else {
                i += 1
                continue
            }

            // Check if current point qualifies as level flight
            if isLevelFlight(dataPoints[i]) {
                // Find the extent of this level flight segment
                if let segment = findLevelFlightSegment(startingAt: i, in: dataPoints) {
                    detectedManeuvers.append(segment)
                    i = segment.endIndex + 1  // Skip past this segment
                    continue
                }
            }

            i += 1
        }

        return detectedManeuvers
    }

    // MARK: - Helper Methods

    /// Check if a single data point qualifies as level flight
    private func isLevelFlight(_ point: FlightDataPoint) -> Bool {
        // Must be airborne
        guard point.isAirborne else { return false }

        // Near 1g
        guard abs(point.normalAccel - 1.0) < 0.2 else { return false }

        // Wings relatively level
        guard abs(point.rollAngle) < 30.0 else { return false }

        return true
    }

    /// Find a continuous level flight segment starting at the given index
    private func findLevelFlightSegment(startingAt startIdx: Int, in data: [FlightDataPoint]) -> Maneuver? {
        var endIdx = startIdx

        // Extend segment as long as conditions hold
        let maxSearchIdx = min(startIdx + config.maxDataPoints, data.count)

        for i in (startIdx + 1)..<maxSearchIdx {
            if isLevelFlight(data[i]) {
                endIdx = i
            } else {
                // Allow brief interruptions (up to 1 second = 20 points)
                if i - endIdx > 20 {
                    break  // Too long an interruption
                }
            }
        }

        // Check minimum duration
        let duration = data[endIdx].irigTime.timeIntervalSince(data[startIdx].irigTime)
        guard duration >= config.minDuration else {
            return nil
        }

        // Calculate confidence
        let confidence = calculateConfidence(
            startIndex: startIdx,
            endIndex: endIdx,
            data: data
        )

        guard confidence >= config.minConfidence else {
            return nil
        }

        // Create maneuver
        return Maneuver(
            id: UUID(),
            type: .levelFlight,
            startTime: data[startIdx].irigTime,
            endTime: data[endIdx].irigTime,
            startIndex: startIdx,
            endIndex: endIdx,
            confidence: confidence,
            detectionMethod: .ruleBased,
            metrics: nil,
            phases: nil
        )
    }

    /// Calculate confidence score for level flight segment
    private func calculateConfidence(
        startIndex: Int,
        endIndex: Int,
        data: [FlightDataPoint]
    ) -> Double {
        var score = 0.0
        var maxScore = 0.0

        // 1. G-loading stability (40 points)
        maxScore += 40.0
        let gStdDev = data.standardDeviation(of: \.normalAccel, in: startIndex..<(endIndex + 1))
        if gStdDev < 0.05 {
            score += 40.0  // Very stable
        } else if gStdDev < 0.1 {
            score += 30.0  // Good
        } else if gStdDev < 0.2 {
            score += 20.0  // Acceptable
        } else {
            score += 10.0
        }

        // 2. Altitude stability (30 points)
        maxScore += 30.0
        let altStdDev = data.standardDeviation(of: \.altitude, in: startIndex..<(endIndex + 1))
        if altStdDev < 50.0 {
            score += 30.0  // Within 50 feet
        } else if altStdDev < 100.0 {
            score += 20.0  // Within 100 feet
        } else if altStdDev < 200.0 {
            score += 10.0
        }

        // 3. Roll stability (20 points)
        maxScore += 20.0
        let rollStdDev = data.standardDeviation(of: \.rollAngle, in: startIndex..<(endIndex + 1))
        if rollStdDev < 5.0 {
            score += 20.0  // Very stable wings
        } else if rollStdDev < 10.0 {
            score += 15.0
        } else if rollStdDev < 20.0 {
            score += 10.0
        }

        // 4. Duration (10 points) - longer segments are more confident
        maxScore += 10.0
        let duration = data[endIndex].irigTime.timeIntervalSince(data[startIndex].irigTime)
        if duration > 30.0 {
            score += 10.0  // 30+ seconds
        } else if duration > 15.0 {
            score += 7.0
        } else if duration > 10.0 {
            score += 5.0
        } else {
            score += 3.0
        }

        return score / maxScore
    }
}
