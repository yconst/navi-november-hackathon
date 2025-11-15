//
//  SplitSDetectorTests.swift
//  FlightCoachTests
//
//  Created by FlightCoach Development Team.
//

import XCTest
@testable import FlightCoach

final class SplitSDetectorTests: XCTestCase {

    var detector: SplitSDetector!

    override func setUp() async throws {
        try await super.setUp()
        detector = SplitSDetector()
    }

    override func tearDown() async throws {
        detector = nil
        try await super.tearDown()
    }

    // MARK: - Basic Detection Tests

    func testDetectSplitS_ValidManeuver() async throws {
        // Given - Create a realistic Split-S maneuver
        let dataPoints = createSplitSManeuver()

        // When
        let maneuvers = await detector.detect(in: dataPoints)

        // Then
        XCTAssertEqual(maneuvers.count, 1, "Should detect exactly one Split-S")
        let maneuver = try XCTUnwrap(maneuvers.first)
        XCTAssertEqual(maneuver.type, .splitS)
        XCTAssertGreaterThan(maneuver.confidence, 0.75, "Confidence should meet threshold")
    }

    func testDetectSplitS_NoManeuver() async throws {
        // Given - Level flight only
        let dataPoints = createLevelFlight(duration: 20.0)

        // When
        let maneuvers = await detector.detect(in: dataPoints)

        // Then
        XCTAssertEqual(maneuvers.count, 0, "Should not detect Split-S in level flight")
    }

    func testDetectSplitS_MinimumDataPoints() async throws {
        // Given - Too few data points
        let dataPoints = createSplitSManeuver(duration: 5.0)  // Below minimum

        // When
        let maneuvers = await detector.detect(in: dataPoints)

        // Then
        XCTAssertEqual(maneuvers.count, 0, "Should not detect with insufficient data")
    }

    // MARK: - Phase Detection Tests

    func testDetectSplitS_ValidPhases() async throws {
        // Given
        let dataPoints = createSplitSManeuver()

        // When
        let maneuvers = await detector.detect(in: dataPoints)

        // Then
        let maneuver = try XCTUnwrap(maneuvers.first)
        let phases = try XCTUnwrap(maneuver.phases)

        XCTAssertEqual(phases.count, 3, "Should have three phases")
        XCTAssertEqual(phases[0].name, "Roll Inverted")
        XCTAssertEqual(phases[1].name, "Pull Through")
        XCTAssertEqual(phases[2].name, "Recovery")
    }

    func testDetectSplitS_Phase1_RollInverted() async throws {
        // Given
        let dataPoints = createSplitSManeuver()

        // When
        let maneuvers = await detector.detect(in: dataPoints)

        // Then
        let maneuver = try XCTUnwrap(maneuvers.first)
        let phases = try XCTUnwrap(maneuver.phases)
        let rollPhase = phases[0]

        // Check roll phase metrics
        XCTAssertNotNil(rollPhase.keyMetrics["max_roll_angle"])
        XCTAssertNotNil(rollPhase.keyMetrics["max_roll_rate"])

        let maxRollAngle = try XCTUnwrap(rollPhase.keyMetrics["max_roll_angle"])
        XCTAssertGreaterThan(maxRollAngle, 150.0, "Should roll past 150°")
    }

    func testDetectSplitS_Phase2_PullThrough() async throws {
        // Given
        let dataPoints = createSplitSManeuver()

        // When
        let maneuvers = await detector.detect(in: dataPoints)

        // Then
        let maneuver = try XCTUnwrap(maneuvers.first)
        let phases = try XCTUnwrap(maneuver.phases)
        let pullPhase = phases[1]

        // Check pull through metrics
        XCTAssertNotNil(pullPhase.keyMetrics["min_g"])
        XCTAssertNotNil(pullPhase.keyMetrics["max_g"])
        XCTAssertNotNil(pullPhase.keyMetrics["g_onset_time"])

        let minG = try XCTUnwrap(pullPhase.keyMetrics["min_g"])
        let maxG = try XCTUnwrap(pullPhase.keyMetrics["max_g"])

        XCTAssertLessThan(minG, 0.8, "Should experience low/negative g")
        XCTAssertGreaterThan(maxG, 3.0, "Should pull at least 3g")
    }

    func testDetectSplitS_Phase3_Recovery() async throws {
        // Given
        let dataPoints = createSplitSManeuver()

        // When
        let maneuvers = await detector.detect(in: dataPoints)

        // Then
        let maneuver = try XCTUnwrap(maneuvers.first)
        let phases = try XCTUnwrap(maneuver.phases)
        let recoveryPhase = phases[2]

        // Check recovery metrics
        XCTAssertNotNil(recoveryPhase.keyMetrics["recovery_altitude"])
        XCTAssertNotNil(recoveryPhase.keyMetrics["final_g"])

        let finalG = try XCTUnwrap(recoveryPhase.keyMetrics["final_g"])
        XCTAssertEqual(finalG, 1.0, accuracy: 0.3, "Should recover near 1g")
    }

    // MARK: - Confidence Scoring Tests

    func testDetectSplitS_HighConfidence() async throws {
        // Given - Perfect execution
        let dataPoints = createSplitSManeuver(
            maxRollAngle: 178.0,
            minG: 0.2,
            maxG: 4.8,
            gOnsetTime: 2.3
        )

        // When
        let maneuvers = await detector.detect(in: dataPoints)

        // Then
        let maneuver = try XCTUnwrap(maneuvers.first)
        XCTAssertGreaterThan(maneuver.confidence, 0.90, "Perfect execution should have high confidence")
    }

    func testDetectSplitS_LowConfidence() async throws {
        // Given - Marginal execution
        let dataPoints = createSplitSManeuver(
            maxRollAngle: 155.0,  // Barely inverted
            minG: 0.7,            // Not enough unload
            maxG: 3.2,            // Lower g
            gOnsetTime: 4.5       // Too slow
        )

        // When
        let maneuvers = await detector.detect(in: dataPoints)

        // Then - May or may not detect, but if detected, confidence should be lower
        if let maneuver = maneuvers.first {
            XCTAssertLessThan(maneuver.confidence, 0.85, "Marginal execution should have lower confidence")
        }
    }

    // MARK: - Edge Cases

    func testDetectSplitS_GroundOperation() async throws {
        // Given - On ground
        let dataPoints = createSplitSManeuver(onGround: true)

        // When
        let maneuvers = await detector.detect(in: dataPoints)

        // Then
        XCTAssertEqual(maneuvers.count, 0, "Should not detect Split-S on ground")
    }

    func testDetectSplitS_AbortedManeuver() async throws {
        // Given - Start inverted but don't complete
        let dataPoints = createAbortedSplitS()

        // When
        let maneuvers = await detector.detect(in: dataPoints)

        // Then
        XCTAssertEqual(maneuvers.count, 0, "Should not detect incomplete Split-S")
    }

    func testDetectSplitS_MultipleSplitS() async throws {
        // Given - Two Split-S maneuvers separated by level flight
        var dataPoints: [FlightDataPoint] = []
        dataPoints.append(contentsOf: createSplitSManeuver(startTime: Date()))
        dataPoints.append(contentsOf: createLevelFlight(duration: 10.0, startTime: Date(timeIntervalSinceNow: 15)))
        dataPoints.append(contentsOf: createSplitSManeuver(startTime: Date(timeIntervalSinceNow: 25)))

        // When
        let maneuvers = await detector.detect(in: dataPoints)

        // Then
        XCTAssertEqual(maneuvers.count, 2, "Should detect both Split-S maneuvers")
    }

    // MARK: - Helper Methods

    /// Create a realistic Split-S maneuver sequence
    private func createSplitSManeuver(
        startTime: Date = Date(),
        duration: Double = 14.0,
        maxRollAngle: Double = 178.0,
        minG: Double = 0.3,
        maxG: Double = 4.5,
        gOnsetTime: Double = 2.5,
        onGround: Bool = false
    ) -> [FlightDataPoint] {
        var dataPoints: [FlightDataPoint] = []
        let numPoints = Int(duration / 0.05)  // 20Hz
        let baseAltitude = 25000.0

        for i in 0..<numPoints {
            let time = startTime.addingTimeInterval(Double(i) * 0.05)
            let progress = Double(i) / Double(numPoints)

            // Determine phase
            var rollAngle: Double
            var gLoad: Double
            var altitude: Double

            if progress < 0.2 {  // Phase 1: Roll inverted (0-20%)
                let rollProgress = progress / 0.2
                rollAngle = rollProgress * maxRollAngle
                gLoad = 1.0
                altitude = baseAltitude - (rollProgress * 500)
            } else if progress < 0.7 {  // Phase 2: Pull through (20-70%)
                rollAngle = maxRollAngle
                let pullProgress = (progress - 0.2) / 0.5

                // G-loading curve
                if pullProgress < 0.2 {
                    gLoad = 1.0 - (pullProgress / 0.2) * (1.0 - minG)
                } else {
                    let gTransition = (pullProgress - 0.2) / 0.8
                    gLoad = minG + gTransition * (maxG - minG)
                }

                altitude = baseAltitude - 500 - (pullProgress * 4500)

                // Roll back upright during pull
                if pullProgress > 0.5 {
                    let rollBackProgress = (pullProgress - 0.5) / 0.5
                    rollAngle = maxRollAngle * (1.0 - rollBackProgress)
                }
            } else {  // Phase 3: Recovery (70-100%)
                let recoveryProgress = (progress - 0.7) / 0.3
                rollAngle = 0.0
                gLoad = maxG - (recoveryProgress * (maxG - 1.0))
                altitude = baseAltitude - 5000 + (recoveryProgress * 200)
            }

            let dataPoint = FlightDataPoint(
                irigTime: time,
                deltaIrig: Double(i) * 0.05,
                normalAccel: gLoad,
                mach: 0.80,
                altitude: altitude,
                rollAngle: rollAngle,
                pitchAngle: progress < 0.5 ? -20.0 : 10.0,
                heading: 180.0,
                rollRate: i > 0 ? (rollAngle - dataPoints[i-1].rollAngle) / 0.05 : 0.0,
                pitchRate: 0.0,
                yawRate: 0.0,
                aoa: 5.0,
                airspeed: 300.0,
                pressureAltitude: altitude,
                computedAirspeed: 300.0,
                leftEngineRPM: 95.0,
                rightEngineRPM: 95.0,
                leftFuelFlow: 0.008,
                rightFuelFlow: 0.008,
                stabPos: -20.0,
                speedBrakePos: 0.0,
                rudderPos: 0.0,
                weightOnWheels: onGround,
                lateralAccel: 0.0,
                longitudinalAccel: 0.0
            )

            dataPoints.append(dataPoint)
        }

        return dataPoints
    }

    /// Create level flight
    private func createLevelFlight(duration: Double, startTime: Date = Date()) -> [FlightDataPoint] {
        var dataPoints: [FlightDataPoint] = []
        let numPoints = Int(duration / 0.05)

        for i in 0..<numPoints {
            let time = startTime.addingTimeInterval(Double(i) * 0.05)

            let dataPoint = FlightDataPoint(
                irigTime: time,
                deltaIrig: Double(i) * 0.05,
                normalAccel: 1.0,
                mach: 0.80,
                altitude: 25000.0,
                rollAngle: 0.0,
                pitchAngle: 0.0,
                heading: 180.0,
                rollRate: 0.0,
                pitchRate: 0.0,
                yawRate: 0.0,
                aoa: 3.0,
                airspeed: 300.0,
                pressureAltitude: 25000.0,
                computedAirspeed: 300.0,
                leftEngineRPM: 80.0,
                rightEngineRPM: 80.0,
                leftFuelFlow: 0.005,
                rightFuelFlow: 0.005,
                stabPos: 0.0,
                speedBrakePos: 0.0,
                rudderPos: 0.0,
                weightOnWheels: false,
                lateralAccel: 0.0,
                longitudinalAccel: 0.0
            )

            dataPoints.append(dataPoint)
        }

        return dataPoints
    }

    /// Create an aborted Split-S (roll inverted but don't pull through)
    private func createAbortedSplitS() -> [FlightDataPoint] {
        var dataPoints: [FlightDataPoint] = []
        let numPoints = 200  // 10 seconds

        for i in 0..<numPoints {
            let time = Date().addingTimeInterval(Double(i) * 0.05)
            let progress = Double(i) / Double(numPoints)

            var rollAngle: Double
            if progress < 0.3 {
                rollAngle = (progress / 0.3) * 178.0
            } else if progress < 0.6 {
                rollAngle = 178.0  // Stay inverted
            } else {
                // Roll back upright without pulling
                rollAngle = 178.0 * (1.0 - (progress - 0.6) / 0.4)
            }

            let dataPoint = FlightDataPoint(
                irigTime: time,
                deltaIrig: Double(i) * 0.05,
                normalAccel: 0.5,  // Stay light, no pull
                mach: 0.80,
                altitude: 25000.0 - Double(i) * 2.0,  // Slight altitude loss
                rollAngle: rollAngle,
                pitchAngle: -10.0,
                heading: 180.0,
                rollRate: 0.0,
                pitchRate: 0.0,
                yawRate: 0.0,
                aoa: 2.0,
                airspeed: 300.0,
                pressureAltitude: 25000.0,
                computedAirspeed: 300.0,
                leftEngineRPM: 80.0,
                rightEngineRPM: 80.0,
                leftFuelFlow: 0.005,
                rightFuelFlow: 0.005,
                stabPos: 0.0,
                speedBrakePos: 0.0,
                rudderPos: 0.0,
                weightOnWheels: false,
                lateralAccel: 0.0,
                longitudinalAccel: 0.0
            )

            dataPoints.append(dataPoint)
        }

        return dataPoints
    }
}
