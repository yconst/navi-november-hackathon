//
//  FlightDataPointTests.swift
//  FlightCoachTests
//
//  Created by FlightCoach Development Team.
//

import XCTest
@testable import FlightCoach

final class FlightDataPointTests: XCTestCase {

    // MARK: - Initialization Tests

    func testFlightDataPointInitialization() {
        // Given
        let date = Date()

        // When
        let dataPoint = FlightDataPoint(
            irigTime: date,
            deltaIrig: 0.05,
            normalAccel: 1.02,
            mach: 0.81,
            altitude: 25000,
            rollAngle: 2.3,
            pitchAngle: 5.1,
            heading: 57.9,
            rollRate: 0,
            pitchRate: 0,
            yawRate: 0.022,
            aoa: 0.13,
            airspeed: 28.3,
            pressureAltitude: 2299.5,
            computedAirspeed: 11.56,
            leftEngineRPM: 46.28,
            rightEngineRPM: 46.5,
            leftFuelFlow: 0.00193,
            rightFuelFlow: 0.00193,
            stabPos: -30.37,
            speedBrakePos: 43.74,
            rudderPos: 7.27,
            weightOnWheels: false,
            lateralAccel: 0.10,
            longitudinalAccel: 0.08
        )

        // Then
        XCTAssertEqual(dataPoint.irigTime, date)
        XCTAssertEqual(dataPoint.deltaIrig, 0.05, accuracy: 0.001)
        XCTAssertEqual(dataPoint.normalAccel, 1.02, accuracy: 0.001)
        XCTAssertEqual(dataPoint.mach, 0.81, accuracy: 0.001)
        XCTAssertEqual(dataPoint.altitude, 25000, accuracy: 0.1)
        XCTAssertFalse(dataPoint.weightOnWheels)
    }

    // MARK: - Computed Properties Tests

    func testIsAirborne() {
        // Given - Aircraft on ground
        var dataPoint = FlightDataPoint.sample
        var modifiedDataPoint = FlightDataPoint(
            irigTime: dataPoint.irigTime,
            deltaIrig: dataPoint.deltaIrig,
            normalAccel: dataPoint.normalAccel,
            mach: dataPoint.mach,
            altitude: dataPoint.altitude,
            rollAngle: dataPoint.rollAngle,
            pitchAngle: dataPoint.pitchAngle,
            heading: dataPoint.heading,
            rollRate: dataPoint.rollRate,
            pitchRate: dataPoint.pitchRate,
            yawRate: dataPoint.yawRate,
            aoa: dataPoint.aoa,
            airspeed: dataPoint.airspeed,
            pressureAltitude: dataPoint.pressureAltitude,
            computedAirspeed: dataPoint.computedAirspeed,
            leftEngineRPM: dataPoint.leftEngineRPM,
            rightEngineRPM: dataPoint.rightEngineRPM,
            leftFuelFlow: dataPoint.leftFuelFlow,
            rightFuelFlow: dataPoint.rightFuelFlow,
            stabPos: dataPoint.stabPos,
            speedBrakePos: dataPoint.speedBrakePos,
            rudderPos: dataPoint.rudderPos,
            weightOnWheels: true, // On ground
            lateralAccel: dataPoint.lateralAccel,
            longitudinalAccel: dataPoint.longitudinalAccel
        )

        // Then
        XCTAssertFalse(modifiedDataPoint.isAirborne)

        // Given - Aircraft in air
        modifiedDataPoint = FlightDataPoint(
            irigTime: dataPoint.irigTime,
            deltaIrig: dataPoint.deltaIrig,
            normalAccel: dataPoint.normalAccel,
            mach: dataPoint.mach,
            altitude: dataPoint.altitude,
            rollAngle: dataPoint.rollAngle,
            pitchAngle: dataPoint.pitchAngle,
            heading: dataPoint.heading,
            rollRate: dataPoint.rollRate,
            pitchRate: dataPoint.pitchRate,
            yawRate: dataPoint.yawRate,
            aoa: dataPoint.aoa,
            airspeed: dataPoint.airspeed,
            pressureAltitude: dataPoint.pressureAltitude,
            computedAirspeed: dataPoint.computedAirspeed,
            leftEngineRPM: dataPoint.leftEngineRPM,
            rightEngineRPM: dataPoint.rightEngineRPM,
            leftFuelFlow: dataPoint.leftFuelFlow,
            rightFuelFlow: dataPoint.rightFuelFlow,
            stabPos: dataPoint.stabPos,
            speedBrakePos: dataPoint.speedBrakePos,
            rudderPos: dataPoint.rudderPos,
            weightOnWheels: false, // In air
            lateralAccel: dataPoint.lateralAccel,
            longitudinalAccel: dataPoint.longitudinalAccel
        )

        // Then
        XCTAssertTrue(modifiedDataPoint.isAirborne)
    }

    func testIsInverted() {
        // Given - Upright flight
        var dataPoint = createDataPoint(rollAngle: 10.0)

        // Then
        XCTAssertFalse(dataPoint.isInverted)

        // Given - Inverted flight (positive)
        dataPoint = createDataPoint(rollAngle: 175.0)

        // Then
        XCTAssertTrue(dataPoint.isInverted)

        // Given - Inverted flight (negative)
        dataPoint = createDataPoint(rollAngle: -160.0)

        // Then
        XCTAssertTrue(dataPoint.isInverted)

        // Given - Edge case (exactly 150°)
        dataPoint = createDataPoint(rollAngle: 150.0)

        // Then
        XCTAssertFalse(dataPoint.isInverted)

        // Given - Edge case (just over 150°)
        dataPoint = createDataPoint(rollAngle: 150.1)

        // Then
        XCTAssertTrue(dataPoint.isInverted)
    }

    // MARK: - Codable Tests

    func testCodableEncoding() throws {
        // Given
        let dataPoint = FlightDataPoint.sample

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(dataPoint)

        // Then
        XCTAssertFalse(data.isEmpty)
    }

    func testCodableDecoding() throws {
        // Given
        let original = FlightDataPoint.sample
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        // When
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FlightDataPoint.self, from: data)

        // Then
        XCTAssertEqual(decoded.normalAccel, original.normalAccel, accuracy: 0.001)
        XCTAssertEqual(decoded.mach, original.mach, accuracy: 0.001)
        XCTAssertEqual(decoded.altitude, original.altitude, accuracy: 0.1)
        XCTAssertEqual(decoded.rollAngle, original.rollAngle, accuracy: 0.1)
        XCTAssertEqual(decoded.weightOnWheels, original.weightOnWheels)
    }

    func testCodableRoundTrip() throws {
        // Given
        let original = FlightDataPoint.sample

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FlightDataPoint.self, from: data)

        // Then
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Sample Data Tests

    func testSampleData() {
        // When
        let sample = FlightDataPoint.sample

        // Then
        XCTAssertGreaterThan(sample.altitude, 0)
        XCTAssertGreaterThan(sample.mach, 0)
        XCTAssertGreaterThan(sample.normalAccel, 0)
        XCTAssertFalse(sample.weightOnWheels)
        XCTAssertTrue(sample.isAirborne)
    }

    // MARK: - Helper Methods

    private func createDataPoint(rollAngle: Double) -> FlightDataPoint {
        FlightDataPoint(
            irigTime: Date(),
            deltaIrig: 0.05,
            normalAccel: 1.0,
            mach: 0.8,
            altitude: 25000,
            rollAngle: rollAngle,
            pitchAngle: 0,
            heading: 0,
            rollRate: 0,
            pitchRate: 0,
            yawRate: 0,
            aoa: 0,
            airspeed: 300,
            pressureAltitude: 25000,
            computedAirspeed: 300,
            leftEngineRPM: 50,
            rightEngineRPM: 50,
            leftFuelFlow: 0.002,
            rightFuelFlow: 0.002,
            stabPos: 0,
            speedBrakePos: 0,
            rudderPos: 0,
            weightOnWheels: false,
            lateralAccel: 0,
            longitudinalAccel: 0
        )
    }
}
