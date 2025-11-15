//
//  ManeuverTests.swift
//  FlightCoachTests
//
//  Created by FlightCoach Development Team.
//

import XCTest
@testable import FlightCoach

final class ManeuverTests: XCTestCase {

    // MARK: - Initialization Tests

    func testManeuverInitialization() {
        // Given
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(15)

        // When
        let maneuver = Maneuver(
            id: UUID(),
            type: .splitS,
            startTime: startTime,
            endTime: endTime,
            startIndex: 0,
            endIndex: 300,
            confidence: 0.92,
            detectionMethod: .ruleBased,
            metrics: nil,
            phases: nil
        )

        // Then
        XCTAssertEqual(maneuver.type, .splitS)
        XCTAssertEqual(maneuver.confidence, 0.92, accuracy: 0.01)
        XCTAssertEqual(maneuver.detectionMethod, .ruleBased)
        XCTAssertNil(maneuver.metrics)
        XCTAssertNil(maneuver.phases)
    }

    // MARK: - Duration Tests

    func testDurationCalculation() {
        // Given
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(14.85)

        let maneuver = Maneuver(
            id: UUID(),
            type: .splitS,
            startTime: startTime,
            endTime: endTime,
            startIndex: 0,
            endIndex: 297,
            confidence: 0.92,
            detectionMethod: .ruleBased,
            metrics: nil,
            phases: nil
        )

        // Then
        XCTAssertEqual(maneuver.duration, 14.85, accuracy: 0.01)
    }

    // MARK: - Score Color Tests

    func testScoreColor() {
        // Given - Excellent score (9-10)
        var maneuver = createManeuver(withScore: 9.5)

        // Then
        XCTAssertEqual(maneuver.scoreColor.description, "green")

        // Given - Good score (7-9)
        maneuver = createManeuver(withScore: 8.0)

        // Then
        XCTAssertEqual(maneuver.scoreColor.description, "blue")

        // Given - Fair score (5-7)
        maneuver = createManeuver(withScore: 6.0)

        // Then
        XCTAssertEqual(maneuver.scoreColor.description, "yellow")

        // Given - Poor score (<5)
        maneuver = createManeuver(withScore: 4.0)

        // Then
        XCTAssertEqual(maneuver.scoreColor.description, "red")
    }

    // MARK: - ManeuverType Tests

    func testManeuverTypeDisplayNames() {
        XCTAssertEqual(ManeuverType.splitS.displayName, "Split-S")
        XCTAssertEqual(ManeuverType.windUpTurn.displayName, "Wind-Up Turn")
        XCTAssertEqual(ManeuverType.rollerCoaster.displayName, "Roller Coaster")
        XCTAssertEqual(ManeuverType.takeoff.displayName, "Takeoff")
        XCTAssertEqual(ManeuverType.landing.displayName, "Landing")
    }

    func testManeuverTypeIcons() {
        XCTAssertEqual(ManeuverType.takeoff.icon, "airplane.departure")
        XCTAssertEqual(ManeuverType.landing.icon, "airplane.arrival")
        XCTAssertEqual(ManeuverType.splitS.icon, "arrow.down.right.circle.fill")
        XCTAssertEqual(ManeuverType.windUpTurn.icon, "arrow.clockwise.circle.fill")
    }

    func testManeuverTypeDescriptions() {
        XCTAssertFalse(ManeuverType.splitS.description.isEmpty)
        XCTAssertTrue(ManeuverType.splitS.description.contains("Roll inverted"))
        XCTAssertTrue(ManeuverType.takeoff.description.contains("WOW"))
    }

    func testAllManeuverTypes() {
        // When
        let allTypes = ManeuverType.allCases

        // Then
        XCTAssertEqual(allTypes.count, 9)
        XCTAssertTrue(allTypes.contains(.splitS))
        XCTAssertTrue(allTypes.contains(.windUpTurn))
        XCTAssertTrue(allTypes.contains(.rollerCoaster))
        XCTAssertTrue(allTypes.contains(.takeoff))
        XCTAssertTrue(allTypes.contains(.landing))
    }

    // MARK: - DetectionMethod Tests

    func testDetectionMethodDisplayNames() {
        XCTAssertEqual(DetectionMethod.ruleBased.displayName, "Rule-Based")
        XCTAssertEqual(DetectionMethod.mlBased.displayName, "ML-Based")
        XCTAssertEqual(DetectionMethod.hybrid.displayName, "Hybrid")
        XCTAssertEqual(DetectionMethod.manual.displayName, "Manual")
    }

    // MARK: - ManeuverPhase Tests

    func testManeuverPhaseInitialization() {
        // Given
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(2.7)

        // When
        let phase = ManeuverPhase(
            name: "Roll Inverted",
            startTime: startTime,
            endTime: endTime,
            startIndex: 0,
            endIndex: 54,
            description: "Roll from upright to inverted",
            keyMetrics: ["max_roll_angle": 178.5]
        )

        // Then
        XCTAssertEqual(phase.name, "Roll Inverted")
        XCTAssertEqual(phase.duration, 2.7, accuracy: 0.01)
        XCTAssertEqual(phase.keyMetrics["max_roll_angle"], 178.5)
    }

    func testManeuverPhaseWithMultipleMetrics() {
        // Given
        let phase = ManeuverPhase(
            name: "Pull Through",
            startTime: Date(),
            endTime: Date().addingTimeInterval(8.6),
            startIndex: 54,
            endIndex: 226,
            description: "Pull from inverted to upright",
            keyMetrics: [
                "min_g": -0.3,
                "max_g": 5.2,
                "altitude_loss": 4900
            ]
        )

        // Then
        XCTAssertEqual(phase.keyMetrics.count, 3)
        XCTAssertEqual(phase.keyMetrics["min_g"], -0.3)
        XCTAssertEqual(phase.keyMetrics["max_g"], 5.2)
        XCTAssertEqual(phase.keyMetrics["altitude_loss"], 4900)
    }

    // MARK: - Codable Tests

    func testManeuverCodable() throws {
        // Given
        let maneuver = Maneuver.sample

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(maneuver)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Maneuver.self, from: data)

        // Then
        XCTAssertEqual(decoded.type, maneuver.type)
        XCTAssertEqual(decoded.confidence, maneuver.confidence, accuracy: 0.01)
        XCTAssertEqual(decoded.detectionMethod, maneuver.detectionMethod)
        XCTAssertEqual(decoded.startIndex, maneuver.startIndex)
        XCTAssertEqual(decoded.endIndex, maneuver.endIndex)
    }

    // MARK: - Sample Data Tests

    func testSampleManeuver() {
        // When
        let sample = Maneuver.sample

        // Then
        XCTAssertEqual(sample.type, .splitS)
        XCTAssertGreaterThan(sample.confidence, 0.8)
        XCTAssertNotNil(sample.metrics)
        XCTAssertNotNil(sample.phases)
        XCTAssertEqual(sample.phases?.count, 3)
    }

    func testSampleManeuverPhases() {
        // Given
        let sample = Maneuver.sample

        // Then
        guard let phases = sample.phases else {
            XCTFail("Sample maneuver should have phases")
            return
        }

        XCTAssertEqual(phases[0].name, "Roll Inverted")
        XCTAssertEqual(phases[1].name, "Pull Through")
        XCTAssertEqual(phases[2].name, "Recovery")

        // Verify phase metrics
        XCTAssertNotNil(phases[0].keyMetrics["max_roll_angle"])
        XCTAssertNotNil(phases[1].keyMetrics["min_g"])
        XCTAssertNotNil(phases[1].keyMetrics["max_g"])
        XCTAssertNotNil(phases[2].keyMetrics["recovery_altitude"])
    }

    // MARK: - Time Range Formatting Tests

    func testTimeRangeFormatted() {
        // Given
        let calendar = Calendar.current
        let startTime = calendar.date(from: DateComponents(year: 2024, month: 11, day: 15, hour: 14, minute: 30, second: 10))!
        let endTime = startTime.addingTimeInterval(14.85)

        let maneuver = Maneuver(
            id: UUID(),
            type: .splitS,
            startTime: startTime,
            endTime: endTime,
            startIndex: 0,
            endIndex: 297,
            confidence: 0.92,
            detectionMethod: .ruleBased,
            metrics: nil,
            phases: nil
        )

        // When
        let formatted = maneuver.timeRangeFormatted

        // Then
        XCTAssertTrue(formatted.contains("14:30:10"))
        XCTAssertTrue(formatted.contains("14.8"))
    }

    // MARK: - Helper Methods

    private func createManeuver(withScore score: Double) -> Maneuver {
        let metrics = PerformanceMetrics(
            overallScore: score,
            machStability: score,
            gOnsetSmoothness: score,
            recoveryTiming: score,
            machMean: 0.80,
            machStdDev: 0.02,
            machMaxExcursion: 0.03,
            machTarget: 0.80,
            gMax: 5.0,
            gMin: -0.5,
            gOnsetTime: 2.5,
            altitudeLoss: 5000,
            entryAltitude: 25000,
            recoveryAltitude: 20000,
            minAltitude: 19500,
            timeToMinAltitude: 12,
            timeSafetyMargin: 1500,
            minAltitudeMargin: 1000,
            deviations: []
        )

        return Maneuver(
            id: UUID(),
            type: .splitS,
            startTime: Date(),
            endTime: Date().addingTimeInterval(15),
            startIndex: 0,
            endIndex: 300,
            confidence: 0.92,
            detectionMethod: .ruleBased,
            metrics: metrics,
            phases: nil
        )
    }
}
