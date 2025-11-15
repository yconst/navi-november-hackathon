//
//  ManeuverDetectionService.swift
//  FlightCoach
//
//  Created by FlightCoach Development Team.
//

import Foundation

/// Service that coordinates all maneuver detection algorithms
///
/// This service runs multiple detectors in sequence and combines their results.
/// Priority is given to more specific detectors (e.g., Split-S) over generic ones (e.g., level flight).
actor ManeuverDetectionService {

    // MARK: - Detectors

    private let splitSDetector: SplitSDetector
    private let takeoffDetector: TakeoffDetector
    private let landingDetector: LandingDetector
    private let levelFlightDetector: LevelFlightDetector

    // MARK: - Configuration

    /// Progress callback for long-running detection
    typealias ProgressCallback = (Double) -> Void

    init() {
        self.splitSDetector = SplitSDetector()
        self.takeoffDetector = TakeoffDetector()
        self.landingDetector = LandingDetector()
        self.levelFlightDetector = LevelFlightDetector()
    }

    // MARK: - Detection

    /// Detect all maneuvers in the flight data
    /// - Parameters:
    ///   - dataPoints: Complete flight telemetry data
    ///   - progress: Optional callback for progress updates (0.0 to 1.0)
    /// - Returns: Array of detected maneuvers, sorted by start time
    func detectAllManeuvers(
        in dataPoints: [FlightDataPoint],
        progress: ProgressCallback? = nil
    ) async -> [Maneuver] {

        guard !dataPoints.isEmpty else {
            return []
        }

        var allManeuvers: [Maneuver] = []
        let totalSteps = 4.0
        var currentStep = 0.0

        // Step 1: Detect takeoffs (high priority, clear signal)
        progress?(currentStep / totalSteps)
        let takeoffs = await takeoffDetector.detect(in: dataPoints)
        allManeuvers.append(contentsOf: takeoffs)
        currentStep += 1

        // Step 2: Detect landings (high priority, clear signal)
        progress?(currentStep / totalSteps)
        let landings = await landingDetector.detect(in: dataPoints)
        allManeuvers.append(contentsOf: landings)
        currentStep += 1

        // Step 3: Detect Split-S maneuvers (TIER 2, complex)
        progress?(currentStep / totalSteps)
        let splitSManeuvers = await splitSDetector.detect(in: dataPoints)
        allManeuvers.append(contentsOf: splitSManeuvers)
        currentStep += 1

        // Step 4: Detect level flight segments (fill remaining gaps)
        progress?(currentStep / totalSteps)
        let levelFlightSegments = await levelFlightDetector.detect(in: dataPoints)

        // Only add level flight segments that don't overlap with other maneuvers
        let nonOverlappingLevelFlight = levelFlightSegments.filter { levelSegment in
            !allManeuvers.contains { existingManeuver in
                overlaps(levelSegment, with: existingManeuver)
            }
        }
        allManeuvers.append(contentsOf: nonOverlappingLevelFlight)

        progress?(1.0)

        // Sort by start time
        return allManeuvers.sorted { $0.startTime < $1.startTime }
    }

    /// Detect only a specific type of maneuver
    /// - Parameters:
    ///   - type: The type of maneuver to detect
    ///   - dataPoints: Complete flight telemetry data
    /// - Returns: Array of detected maneuvers of the specified type
    func detectManeuvers(
        ofType type: ManeuverType,
        in dataPoints: [FlightDataPoint]
    ) async -> [Maneuver] {

        switch type {
        case .splitS:
            return await splitSDetector.detect(in: dataPoints)
        case .takeoff:
            return await takeoffDetector.detect(in: dataPoints)
        case .landing:
            return await landingDetector.detect(in: dataPoints)
        case .levelFlight:
            return await levelFlightDetector.detect(in: dataPoints)
        default:
            // Not yet implemented
            return []
        }
    }

    // MARK: - Helper Methods

    /// Check if two maneuvers overlap in time
    private func overlaps(_ m1: Maneuver, with m2: Maneuver) -> Bool {
        let range1 = m1.startIndex...m1.endIndex
        let range2 = m2.startIndex...m2.endIndex
        return range1.overlaps(range2)
    }
}
