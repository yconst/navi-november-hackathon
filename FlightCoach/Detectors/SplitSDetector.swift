//
//  SplitSDetector.swift
//  FlightCoach
//
//  Created by FlightCoach Development Team.
//

import Foundation

/// Detector for Split-S maneuvers using three-phase detection
///
/// Split-S Definition:
/// 1. Roll Inverted (Phase 1): Roll from upright to inverted (150-180° bank)
/// 2. Pull Through (Phase 2): Pull negative g to positive g (typically -0.5 to +5.0)
/// 3. Recovery (Phase 3): Return to level flight (1g trim, upright)
///
/// Key Parameters:
/// - Roll angle transition: 0° → 150-180° → 0°
/// - G-loading: 1g → negative g → 3-5g → 1g
/// - Altitude loss: Typically 4000-6000 feet
/// - Duration: 10-15 seconds typical
actor SplitSDetector: ManeuverDetector {
    let maneuverType: ManeuverType = .splitS
    private let config: DetectionConfiguration

    init(config: DetectionConfiguration = .splitS) {
        self.config = config
    }

    func detect(in dataPoints: [FlightDataPoint]) async -> [Maneuver] {
        guard dataPoints.count >= config.minDataPoints else {
            return []
        }

        var detectedManeuvers: [Maneuver] = []

        // Find candidate start points: aircraft transitioning to inverted
        let invertedTransitions = findInvertedTransitions(in: dataPoints)

        for startIdx in invertedTransitions {
            // Try to detect a complete Split-S starting from this point
            if let maneuver = detectSplitS(startingAt: startIdx, in: dataPoints) {
                // Check for overlap with existing detections
                if !overlaps(maneuver, with: detectedManeuvers) {
                    detectedManeuvers.append(maneuver)
                }
            }
        }

        return detectedManeuvers
    }

    // MARK: - Phase Detection

    /// Find indices where aircraft transitions to inverted flight
    private func findInvertedTransitions(in data: [FlightDataPoint]) -> [Int] {
        return data.risingEdges { $0.isInverted }
    }

    /// Attempt to detect a complete Split-S starting at the given index
    private func detectSplitS(startingAt startIdx: Int, in data: [FlightDataPoint]) -> Maneuver? {
        // Ensure we're airborne
        guard data[startIdx].isAirborne else {
            return nil
        }

        // Search window: look ahead for completion (max duration)
        let searchWindow = min(startIdx + config.maxDataPoints, data.count)
        let searchData = Array(data[startIdx..<searchWindow])

        // Phase 1: Roll Inverted (look backward to find roll entry)
        guard let phase1 = detectRollInverted(endingAt: startIdx, in: data) else {
            return nil
        }

        // Phase 2: Pull Through (starting from inverted)
        guard let phase2 = detectPullThrough(startingAt: startIdx, in: searchData) else {
            return nil
        }

        // Phase 3: Recovery (starting from pull completion)
        let phase2EndIdx = startIdx + phase2.endIndex
        guard phase2EndIdx < data.count else {
            return nil
        }

        let recoverySearchData = Array(data[phase2EndIdx..<searchWindow])
        guard let phase3 = detectRecovery(startingAt: phase2EndIdx, in: recoverySearchData) else {
            return nil
        }

        // Calculate overall maneuver bounds
        let maneuverStart = phase1.startIndex
        let maneuverEnd = phase2EndIdx + phase3.endIndex

        // Validate duration
        let duration = data[maneuverEnd].irigTime.timeIntervalSince(data[maneuverStart].irigTime)
        guard duration >= config.minDuration && duration <= config.maxDuration else {
            return nil
        }

        // Calculate confidence
        let confidence = calculateConfidence(
            phase1: phase1,
            phase2: phase2,
            phase3: phase3,
            data: data,
            startIndex: maneuverStart,
            endIndex: maneuverEnd
        )

        guard confidence >= config.minConfidence else {
            return nil
        }

        // Create maneuver with phases
        return Maneuver(
            id: UUID(),
            type: .splitS,
            startTime: data[maneuverStart].irigTime,
            endTime: data[maneuverEnd].irigTime,
            startIndex: maneuverStart,
            endIndex: maneuverEnd,
            confidence: confidence,
            detectionMethod: .ruleBased,
            metrics: nil,  // Will be calculated in analysis phase
            phases: [
                phase1.toManeuverPhase(data: data),
                phase2.toManeuverPhase(data: data, offsetIndex: startIdx),
                phase3.toManeuverPhase(data: data, offsetIndex: phase2EndIdx)
            ]
        )
    }

    // MARK: - Phase 1: Roll Inverted

    /// Detect the roll to inverted phase (looking backward from inverted point)
    private func detectRollInverted(endingAt endIdx: Int, in data: [FlightDataPoint]) -> PhaseDetectionResult? {
        // Look back up to 5 seconds (100 data points at 20Hz)
        let maxLookback = 100
        let startSearchIdx = max(0, endIdx - maxLookback)

        // Find where roll started (last time we were upright)
        var rollStartIdx: Int?
        for i in stride(from: endIdx - 1, through: startSearchIdx, by: -1) {
            if !data[i].isInverted && abs(data[i].rollAngle) < 45.0 {
                rollStartIdx = i
                break
            }
        }

        guard let startIdx = rollStartIdx else {
            return nil
        }

        // Validate roll characteristics
        let rollData = Array(data[startIdx...endIdx])
        let maxRollRate = rollData.map { abs($0.rollRate) }.max() ?? 0

        // Typical roll rate: 60-90 deg/sec
        guard maxRollRate > 30.0 else {
            return nil  // Too slow to be intentional roll
        }

        return PhaseDetectionResult(
            name: "Roll Inverted",
            startIndex: startIdx,
            endIndex: endIdx,
            description: "Roll from upright to inverted",
            keyMetrics: [
                "max_roll_angle": abs(data[endIdx].rollAngle),
                "max_roll_rate": maxRollRate
            ]
        )
    }

    // MARK: - Phase 2: Pull Through

    /// Detect the pull through phase (starting from inverted)
    private func detectPullThrough(startingAt startIdx: Int, in searchData: [FlightDataPoint]) -> PhaseDetectionResult? {
        // Look for g-loading increase
        guard let minGIdx = searchData.indexOfMin(for: \.normalAccel, in: 0..<min(40, searchData.count)) else {
            return nil
        }

        let minG = searchData[minGIdx].normalAccel

        // Look for peak g after minimum
        guard let maxGIdx = searchData.indexOfMax(for: \.normalAccel, in: minGIdx..<min(minGIdx + 100, searchData.count)) else {
            return nil
        }

        let maxG = searchData[maxGIdx].normalAccel

        // Validate g-loading profile
        // Should go from near 0g (or slightly negative) to 3-5g
        guard minG < 0.8 && maxG > 3.0 else {
            return nil
        }

        // Calculate g-onset time (time from min to max g)
        let gOnsetTime = searchData[maxGIdx].irigTime.timeIntervalSince(searchData[minGIdx].irigTime)

        // Ideal g-onset: 2.0-2.5 seconds
        // Acceptable range: 1.5-4.0 seconds
        guard gOnsetTime > 1.0 && gOnsetTime < 5.0 else {
            return nil
        }

        return PhaseDetectionResult(
            name: "Pull Through",
            startIndex: 0,
            endIndex: maxGIdx,
            description: "Pull from inverted to upright",
            keyMetrics: [
                "min_g": minG,
                "max_g": maxG,
                "g_onset_time": gOnsetTime,
                "altitude_loss": searchData[0].altitude - searchData[maxGIdx].altitude
            ]
        )
    }

    // MARK: - Phase 3: Recovery

    /// Detect the recovery phase (returning to level flight)
    private func detectRecovery(startingAt startIdx: Int, in searchData: [FlightDataPoint]) -> PhaseDetectionResult? {
        // Look for return to 1g trim and upright
        var recoveryIdx: Int?

        for i in 0..<min(60, searchData.count) {  // Within 3 seconds
            let point = searchData[i]

            // Check for level flight conditions
            if abs(point.normalAccel - 1.0) < 0.2 &&  // Near 1g
               abs(point.rollAngle) < 15.0 &&          // Nearly wings level
               !point.isInverted {
                recoveryIdx = i
                break
            }
        }

        guard let endIdx = recoveryIdx else {
            return nil
        }

        return PhaseDetectionResult(
            name: "Recovery",
            startIndex: 0,
            endIndex: endIdx,
            description: "Return to level flight",
            keyMetrics: [
                "recovery_altitude": searchData[endIdx].altitude,
                "final_g": searchData[endIdx].normalAccel
            ]
        )
    }

    // MARK: - Confidence Calculation

    /// Calculate confidence score for the detected maneuver
    private func calculateConfidence(
        phase1: PhaseDetectionResult,
        phase2: PhaseDetectionResult,
        phase3: PhaseDetectionResult,
        data: [FlightDataPoint],
        startIndex: Int,
        endIndex: Int
    ) -> Double {
        var score = 0.0
        var maxScore = 0.0

        // 1. Roll quality (30 points)
        maxScore += 30.0
        if let maxRollAngle = phase1.keyMetrics["max_roll_angle"] {
            if maxRollAngle > 165.0 && maxRollAngle < 195.0 {
                score += 30.0  // Perfect inverted
            } else if maxRollAngle > 150.0 && maxRollAngle < 210.0 {
                score += 20.0  // Good enough
            } else {
                score += 10.0  // Marginal
            }
        }

        // 2. G-loading profile (25 points)
        maxScore += 25.0
        if let minG = phase2.keyMetrics["min_g"],
           let maxG = phase2.keyMetrics["max_g"] {
            let gRange = maxG - minG
            if gRange > 4.0 && gRange < 6.0 {
                score += 25.0  // Ideal range
            } else if gRange > 3.0 {
                score += 15.0
            } else {
                score += 5.0
            }
        }

        // 3. G-onset timing (20 points)
        maxScore += 20.0
        if let gOnsetTime = phase2.keyMetrics["g_onset_time"] {
            if gOnsetTime > 2.0 && gOnsetTime < 2.5 {
                score += 20.0  // Ideal
            } else if gOnsetTime > 1.5 && gOnsetTime < 3.5 {
                score += 15.0  // Good
            } else {
                score += 5.0   // Acceptable
            }
        }

        // 4. Recovery quality (15 points)
        maxScore += 15.0
        if let finalG = phase3.keyMetrics["final_g"] {
            if abs(finalG - 1.0) < 0.1 {
                score += 15.0  // Perfect trim
            } else if abs(finalG - 1.0) < 0.3 {
                score += 10.0  // Good trim
            } else {
                score += 5.0
            }
        }

        // 5. Altitude loss (10 points) - should be reasonable
        maxScore += 10.0
        let altitudeLoss = data[startIndex].altitude - data[endIndex].altitude
        if altitudeLoss > 3500 && altitudeLoss < 6500 {
            score += 10.0  // Typical range
        } else if altitudeLoss > 2500 && altitudeLoss < 8000 {
            score += 5.0
        }

        return score / maxScore
    }

    // MARK: - Helper Methods

    /// Check if a maneuver overlaps with any existing detections
    private func overlaps(_ maneuver: Maneuver, with existing: [Maneuver]) -> Bool {
        for existingManeuver in existing {
            // Check for any overlap in index ranges
            let newRange = maneuver.startIndex...maneuver.endIndex
            let existingRange = existingManeuver.startIndex...existingManeuver.endIndex

            if newRange.overlaps(existingRange) {
                return true
            }
        }
        return false
    }
}

// MARK: - Supporting Types

/// Internal result from phase detection
private struct PhaseDetectionResult {
    let name: String
    let startIndex: Int
    let endIndex: Int
    let description: String
    let keyMetrics: [String: Double]

    func toManeuverPhase(data: [FlightDataPoint], offsetIndex: Int = 0) -> ManeuverPhase {
        let absoluteStart = offsetIndex + startIndex
        let absoluteEnd = offsetIndex + endIndex

        return ManeuverPhase(
            name: name,
            startTime: data[absoluteStart].irigTime,
            endTime: data[absoluteEnd].irigTime,
            startIndex: absoluteStart,
            endIndex: absoluteEnd,
            description: description,
            keyMetrics: keyMetrics
        )
    }
}
