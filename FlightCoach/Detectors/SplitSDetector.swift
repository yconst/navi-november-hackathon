//
//  SplitSDetector.swift
//  FlightCoach
//
//  Created by FlightCoach Development Team.
//  Enhanced based on T-38C Aerodynamic Modeling documentation
//

import Foundation

/// Detector for Split-S maneuvers using comprehensive phase detection
///
/// Split-S Definition (per T-38C documentation):
/// A descending aerobatic maneuver converting altitude to speed, ending 180° from entry
///
/// Standard Configurations:
/// - Subsonic: Entry at 0.8M / 25,000 ft
/// - Supersonic: Entry at ~1.1M / 30,000 ft
///
/// Five-Phase Detection:
/// 1. Entry: Stable flight at target Mach and altitude
/// 2. Roll to Inverted: Roll to ~180° bank with 0g to -1g
/// 3. Dive Entry: Inverted with steep nose-down (>45°), speed increasing
/// 4. Pull-Through: High g-loading (approaching 5g), pitch recovering
/// 5. Recovery: Level flight, opposite heading, ~1g
///
/// Key Signatures:
/// - Bank angle: 0° → 180° → 0°
/// - Load factor: 1g → 0/-1g → 5g → 1g
/// - Pitch angle: 0° → <-45° → 0°
/// - Heading change: ~180°
/// - Airspeed: Stable → Increasing → Stabilizing
/// - Altitude loss: Significant (2000-6000 ft typical)
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

        // Find candidate entry points: look for roll initiation anywhere in flight
        let entryPoints = findEntryPoints(in: dataPoints)

        for entryIdx in entryPoints {
            // Try to detect a complete Split-S starting from this entry point
            if let maneuver = detectSplitS(startingAt: entryIdx, in: dataPoints) {
                // Check for overlap with existing detections
                if !overlaps(maneuver, with: detectedManeuvers) {
                    detectedManeuvers.append(maneuver)
                }
            }
        }

        return detectedManeuvers
    }

    // MARK: - Entry Point Detection

    /// Find candidate entry points: look for start of roll to inverted anywhere in flight
    /// Relaxed conditions to detect aerobatic maneuvers that may not have stable setup
    private func findEntryPoints(in data: [FlightDataPoint]) -> [Int] {
        var candidates: [Int] = []

        // Look for characteristic Split-S initiation: roll toward inverted from upright
        for i in 100..<(data.count - 400) {  // Need lookback and lookahead
            guard data[i].isAirborne else { continue }

            // Look for roll initiation: transitioning from near-level to banking
            let lookbackWindow = i-20..<i  // 1 second before
            let currentWindow = i..<min(i+20, data.count)  // 1 second current

            // Previous state: relatively wings-level (within 45° of level)
            let avgPriorRoll = data[lookbackWindow].map { abs($0.rollAngle) }.reduce(0, +) / Double(lookbackWindow.count)

            // Current state: rolling or already inverted (approaching 90° or more)
            let currentRoll = abs(data[i].rollAngle)

            // Check for roll initiation or already in roll
            let isRollInitiation = avgPriorRoll < 45.0 && currentRoll > 60.0
            let isAlreadyRolling = currentRoll > 90.0 && currentRoll < 210.0

            // Check altitude is reasonable for aerobatics (above 15k ft)
            let altitude = data[i].altitude
            guard altitude > 15000 else { continue }

            // Check for reasonable speed (Mach 0.5-1.3)
            let mach = data[i].mach
            guard mach > 0.5 && mach < 1.3 else { continue }

            // Look for g-loading characteristic of Split-S entry (0.5g to 1.5g range initially)
            let avgG = data[lookbackWindow].map { $0.normalAccel }.reduce(0, +) / Double(lookbackWindow.count)
            guard avgG > 0.3 && avgG < 2.0 else { continue }

            if isRollInitiation || isAlreadyRolling {
                candidates.append(i)
                // Skip ahead to avoid detecting same maneuver multiple times
                // Jump forward by at least 10 seconds (200 points)
            }
        }

        return candidates
    }

    // MARK: - Complete Maneuver Detection

    /// Attempt to detect a complete Split-S starting at the given entry point
    private func detectSplitS(startingAt entryIdx: Int, in data: [FlightDataPoint]) -> Maneuver? {
        // Ensure we're airborne
        guard data[entryIdx].isAirborne else {
            return nil
        }

        // Search window: Split-S typically 15-40 seconds
        let maxSearchPoints = 800  // 40 seconds at 20Hz
        let searchEnd = min(entryIdx + maxSearchPoints, data.count)

        // Phase 1: Entry (already validated)
        let phase1Start = max(0, entryIdx - 100)  // Include 5s before for context

        // Phase 2: Roll to Inverted
        guard let phase2 = detectRollToInverted(startingAt: entryIdx, in: data, searchEnd: searchEnd) else {
            return nil
        }

        let rollEndIdx = entryIdx + phase2.endIndex
        guard rollEndIdx < data.count - 100 else { return nil }

        // Phase 3: Dive Entry
        guard let phase3 = detectDiveEntry(startingAt: rollEndIdx, in: data, searchEnd: searchEnd) else {
            return nil
        }

        let diveEndIdx = rollEndIdx + phase3.endIndex
        guard diveEndIdx < data.count - 100 else { return nil }

        // Phase 4: Pull-Through
        guard let phase4 = detectPullThrough(startingAt: diveEndIdx, in: data, searchEnd: searchEnd) else {
            return nil
        }

        let pullEndIdx = diveEndIdx + phase4.endIndex
        guard pullEndIdx < data.count - 60 else { return nil }

        // Phase 5: Recovery
        guard let phase5 = detectRecovery(startingAt: pullEndIdx, in: data, searchEnd: searchEnd) else {
            return nil
        }

        let recoveryEndIdx = pullEndIdx + phase5.endIndex

        // Calculate overall maneuver bounds
        let maneuverStart = phase1Start
        let maneuverEnd = recoveryEndIdx

        // Validate duration
        let duration = data[maneuverEnd].irigTime.timeIntervalSince(data[maneuverStart].irigTime)
        guard duration >= config.minDuration && duration <= config.maxDuration else {
            return nil
        }

        // Calculate confidence
        let confidence = calculateConfidence(
            entryIdx: entryIdx,
            phase2: phase2,
            phase3: phase3,
            phase4: phase4,
            phase5: phase5,
            data: data,
            startIndex: maneuverStart,
            endIndex: maneuverEnd
        )

        guard confidence >= config.minConfidence else {
            return nil
        }

        // Create maneuver with all five phases
        let phase1 = PhaseDetectionResult(
            name: "Entry",
            startIndex: 0,
            endIndex: entryIdx - phase1Start,
            description: "Stable flight at entry conditions",
            keyMetrics: [
                "entry_mach": data[entryIdx].mach,
                "entry_altitude": data[entryIdx].altitude,
                "entry_heading": data[entryIdx].heading
            ]
        )

        return Maneuver(
            id: UUID(),
            type: .splitS,
            startTime: data[maneuverStart].irigTime,
            endTime: data[maneuverEnd].irigTime,
            startIndex: maneuverStart,
            endIndex: maneuverEnd,
            confidence: confidence,
            detectionMethod: .ruleBased,
            metrics: nil,
            phases: [
                phase1.toManeuverPhase(data: data, offsetIndex: phase1Start),
                phase2.toManeuverPhase(data: data, offsetIndex: entryIdx),
                phase3.toManeuverPhase(data: data, offsetIndex: rollEndIdx),
                phase4.toManeuverPhase(data: data, offsetIndex: diveEndIdx),
                phase5.toManeuverPhase(data: data, offsetIndex: pullEndIdx)
            ]
        )
    }

    // MARK: - Phase 2: Roll to Inverted

    /// Detect roll to inverted phase
    private func detectRollToInverted(startingAt startIdx: Int, in data: [FlightDataPoint], searchEnd: Int) -> PhaseDetectionResult? {
        let searchWindow = min(150, searchEnd - startIdx)  // Max 7.5 seconds for roll

        // Look for bank angle approaching 180°
        var invertedIdx: Int?
        for i in 20..<searchWindow {  // Start after 1 second
            let absRoll = abs(data[startIdx + i].rollAngle)
            if absRoll > 150 && absRoll < 210 {
                invertedIdx = i
                break
            }
        }

        guard let invIdx = invertedIdx else {
            return nil
        }

        // Validate g-loading during roll: should see 0g to -1g
        let rollData = data[startIdx..<(startIdx + invIdx)]
        let minG = rollData.map { $0.normalAccel }.min() ?? 1.0
        let maxRollRate = rollData.map { abs($0.rollRate) }.max() ?? 0.0

        // Check for negative g or near-zero g during roll
        guard minG < 0.8 else {  // Should see reduced g
            return nil
        }

        // Check for reasonable roll rate (not too slow)
        guard maxRollRate > 20.0 else {  // At least some intentional roll
            return nil
        }

        return PhaseDetectionResult(
            name: "Roll to Inverted",
            startIndex: 0,
            endIndex: invIdx,
            description: "Roll from upright to inverted (~180°)",
            keyMetrics: [
                "max_roll_angle": abs(data[startIdx + invIdx].rollAngle),
                "min_g_during_roll": minG,
                "max_roll_rate": maxRollRate
            ]
        )
    }

    // MARK: - Phase 3: Dive Entry

    /// Detect dive entry phase (inverted, nose going down)
    private func detectDiveEntry(startingAt startIdx: Int, in data: [FlightDataPoint], searchEnd: Int) -> PhaseDetectionResult? {
        let searchWindow = min(200, searchEnd - startIdx)  // Max 10 seconds

        // Look for steep dive angle development
        var steepDiveIdx: Int?
        for i in 20..<searchWindow {
            let pitch = data[startIdx + i].pitchAngle
            // Looking for steep nose-down (negative pitch)
            if pitch < -45.0 {
                steepDiveIdx = i
                break
            }
        }

        guard let diveIdx = steepDiveIdx else {
            return nil
        }

        // Validate: airspeed should be increasing
        let startSpeed = data[startIdx].computedAirspeed
        let diveSpeed = data[startIdx + diveIdx].computedAirspeed
        guard diveSpeed > startSpeed + 10.0 else {  // Speed increasing
            return nil
        }

        // Validate: altitude decreasing
        let altLoss = data[startIdx].altitude - data[startIdx + diveIdx].altitude
        guard altLoss > 500.0 else {  // Losing altitude
            return nil
        }

        return PhaseDetectionResult(
            name: "Dive Entry",
            startIndex: 0,
            endIndex: diveIdx,
            description: "Inverted dive, speed increasing",
            keyMetrics: [
                "min_pitch_angle": data[startIdx..<(startIdx + diveIdx)].map { $0.pitchAngle }.min() ?? 0,
                "speed_increase": diveSpeed - startSpeed,
                "altitude_loss": altLoss
            ]
        )
    }

    // MARK: - Phase 4: Pull-Through

    /// Detect pull-through phase (high g, recovering from dive)
    private func detectPullThrough(startingAt startIdx: Int, in data: [FlightDataPoint], searchEnd: Int) -> PhaseDetectionResult? {
        let searchWindow = min(250, searchEnd - startIdx)  // Max 12.5 seconds

        // Look for high g-loading (approaching 5g)
        var maxGIdx: Int?
        var maxG = 0.0

        for i in 10..<searchWindow {
            let g = data[startIdx + i].normalAccel
            if g > maxG {
                maxG = g
                maxGIdx = i
            }

            // If we found good g-loading and pitch is recovering, this is it
            if g > 3.0 && data[startIdx + i].pitchAngle > -20.0 {
                maxGIdx = i
                break
            }
        }

        guard let pullIdx = maxGIdx, maxG > 3.0 else {
            return nil
        }

        // Validate: pitch angle should be recovering (becoming less negative)
        let startPitch = data[startIdx].pitchAngle
        let endPitch = data[startIdx + pullIdx].pitchAngle
        guard endPitch > startPitch else {  // Nose coming up
            return nil
        }

        // Calculate g-onset time
        let gOnsetTime = data[startIdx + pullIdx].irigTime.timeIntervalSince(data[startIdx].irigTime)

        return PhaseDetectionResult(
            name: "Pull-Through",
            startIndex: 0,
            endIndex: pullIdx,
            description: "High-g pull from dive to level",
            keyMetrics: [
                "max_g": maxG,
                "g_onset_time": gOnsetTime,
                "pitch_change": endPitch - startPitch,
                "altitude_at_max_g": data[startIdx + pullIdx].altitude
            ]
        )
    }

    // MARK: - Phase 5: Recovery

    /// Detect recovery phase (return to level flight)
    private func detectRecovery(startingAt startIdx: Int, in data: [FlightDataPoint], searchEnd: Int) -> PhaseDetectionResult? {
        let searchWindow = min(150, searchEnd - startIdx)  // Max 7.5 seconds

        // Look for return to level flight conditions
        var recoveryIdx: Int?

        for i in 20..<searchWindow {
            let point = data[startIdx + i]

            // Check for level flight: near 1g, wings level, positive pitch near zero
            if abs(point.normalAccel - 1.0) < 0.3 &&
               abs(point.rollAngle) < 30.0 &&
               point.pitchAngle > -10.0 && point.pitchAngle < 15.0 {
                recoveryIdx = i
                break
            }
        }

        guard let recIdx = recoveryIdx else {
            return nil
        }

        // Calculate heading change from entry
        // Note: This is a simplified check; proper implementation would handle heading wraparound
        let headingChange = abs(data[startIdx + recIdx].heading - data[startIdx].heading)

        return PhaseDetectionResult(
            name: "Recovery",
            startIndex: 0,
            endIndex: recIdx,
            description: "Level flight recovery",
            keyMetrics: [
                "recovery_altitude": data[startIdx + recIdx].altitude,
                "recovery_heading": data[startIdx + recIdx].heading,
                "heading_change": headingChange,
                "final_g": data[startIdx + recIdx].normalAccel
            ]
        )
    }

    // MARK: - Confidence Calculation

    /// Calculate confidence score based on all phase characteristics
    private func calculateConfidence(
        entryIdx: Int,
        phase2: PhaseDetectionResult,
        phase3: PhaseDetectionResult,
        phase4: PhaseDetectionResult,
        phase5: PhaseDetectionResult,
        data: [FlightDataPoint],
        startIndex: Int,
        endIndex: Int
    ) -> Double {
        var score = 0.0
        var maxScore = 0.0

        // 1. Entry conditions (10 points) - relaxed scoring for aerobatic flight
        maxScore += 10.0
        let entryMach = data[entryIdx].mach
        let entryAlt = data[entryIdx].altitude

        // Check if entry matches standard configurations (bonus points)
        let isGoodSubsonicEntry = (entryMach > 0.75 && entryMach < 0.85) && (entryAlt > 24000 && entryAlt < 26000)
        let isGoodSupersonicEntry = (entryMach > 1.05 && entryMach < 1.15) && (entryAlt > 29000 && entryAlt < 31000)

        if isGoodSubsonicEntry || isGoodSupersonicEntry {
            score += 10.0  // Perfect textbook entry
        } else if (entryMach > 0.7 && entryMach < 1.2) && entryAlt > 15000 {
            score += 8.0   // Good aerobatic entry
        } else if (entryMach > 0.5 && entryMach < 1.3) && entryAlt > 10000 {
            score += 5.0   // Acceptable entry
        } else {
            score += 2.0   // Marginal but detected
        }

        // 2. Roll quality (20 points)
        maxScore += 20.0
        if let maxRoll = phase2.keyMetrics["max_roll_angle"] {
            if maxRoll > 165 && maxRoll < 195 {
                score += 20.0  // Perfect inverted
            } else if maxRoll > 150 && maxRoll < 210 {
                score += 15.0  // Good inverted
            } else {
                score += 8.0
            }
        }

        // 3. Negative g during roll (10 points)
        maxScore += 10.0
        if let minG = phase2.keyMetrics["min_g_during_roll"] {
            if minG < 0.2 && minG > -1.5 {
                score += 10.0  // Good 0g to -1g range
            } else if minG < 0.8 {
                score += 6.0
            }
        }

        // 4. Dive angle (15 points)
        maxScore += 15.0
        if let minPitch = phase3.keyMetrics["min_pitch_angle"] {
            if minPitch < -60 {
                score += 15.0  // Very steep dive (>60°)
            } else if minPitch < -45 {
                score += 12.0  // Good dive angle
            } else if minPitch < -30 {
                score += 7.0
            }
        }

        // 5. Speed increase during dive (10 points)
        maxScore += 10.0
        if let speedInc = phase3.keyMetrics["speed_increase"] {
            if speedInc > 30 {
                score += 10.0
            } else if speedInc > 15 {
                score += 7.0
            } else if speedInc > 5 {
                score += 4.0
            }
        }

        // 6. Peak g-loading (20 points)
        maxScore += 20.0
        if let maxG = phase4.keyMetrics["max_g"] {
            if maxG > 4.5 && maxG < 6.0 {
                score += 20.0  // Approaching 5g (ideal)
            } else if maxG > 3.5 && maxG < 7.0 {
                score += 15.0  // Good g-loading
            } else if maxG > 3.0 {
                score += 10.0  // Acceptable
            }
        }

        // 7. Recovery quality (10 points)
        maxScore += 10.0
        if let finalG = phase5.keyMetrics["final_g"] {
            if abs(finalG - 1.0) < 0.15 {
                score += 10.0  // Excellent 1g trim
            } else if abs(finalG - 1.0) < 0.3 {
                score += 7.0
            } else {
                score += 4.0
            }
        }

        return score / maxScore
    }

    // MARK: - Helper Methods

    /// Check if a maneuver overlaps with any existing detections
    private func overlaps(_ maneuver: Maneuver, with existing: [Maneuver]) -> Bool {
        for existingManeuver in existing {
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
