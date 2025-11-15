//
//  ManeuverDetectionServiceTests.swift
//  FlightCoachTests
//
//  Created by FlightCoach Development Team.
//

import XCTest
@testable import FlightCoach

final class ManeuverDetectionServiceTests: XCTestCase {

    var service: ManeuverDetectionService!

    override func setUp() async throws {
        try await super.setUp()
        service = ManeuverDetectionService()
    }

    override func tearDown() async throws {
        service = nil
        try await super.tearDown()
    }

    // MARK: - Service Coordination Tests

    func testDetectAllManeuvers_EmptyData() async throws {
        // Given
        let dataPoints: [FlightDataPoint] = []

        // When
        let maneuvers = await service.detectAllManeuvers(in: dataPoints)

        // Then
        XCTAssertEqual(maneuvers.count, 0)
    }

    func testDetectAllManeuvers_ProgressCallback() async throws {
        // Given
        let dataPoints = createCompleteFlightData()
        var progressUpdates: [Double] = []

        // When
        let maneuvers = await service.detectAllManeuvers(in: dataPoints) { progress in
            progressUpdates.append(progress)
        }

        // Then
        XCTAssertGreaterThan(maneuvers.count, 0)
        XCTAssertGreaterThan(progressUpdates.count, 0)
        XCTAssertTrue(progressUpdates.contains(1.0), "Should reach 100% progress")
    }

    func testDetectAllManeuvers_SortedByTime() async throws {
        // Given
        let dataPoints = createCompleteFlightData()

        // When
        let maneuvers = await service.detectAllManeuvers(in: dataPoints)

        // Then
        for i in 1..<maneuvers.count {
            XCTAssertLessThanOrEqual(
                maneuvers[i-1].startTime,
                maneuvers[i].startTime,
                "Maneuvers should be sorted by start time"
            )
        }
    }

    // MARK: - Specific Detector Tests

    func testDetectManeuvers_SplitSOnly() async throws {
        // Given
        let dataPoints = createCompleteFlightData()

        // When
        let maneuvers = await service.detectManeuvers(ofType: .splitS, in: dataPoints)

        // Then
        XCTAssertTrue(maneuvers.allSatisfy { $0.type == .splitS })
    }

    func testDetectManeuvers_TakeoffOnly() async throws {
        // Given
        let dataPoints = createCompleteFlightData()

        // When
        let maneuvers = await service.detectManeuvers(ofType: .takeoff, in: dataPoints)

        // Then
        XCTAssertTrue(maneuvers.allSatisfy { $0.type == .takeoff })
    }

    func testDetectManeuvers_LandingOnly() async throws {
        // Given
        let dataPoints = createCompleteFlightData()

        // When
        let maneuvers = await service.detectManeuvers(ofType: .landing, in: dataPoints)

        // Then
        XCTAssertTrue(maneuvers.allSatisfy { $0.type == .landing })
    }

    // MARK: - Integration Tests

    func testDetectAllManeuvers_CompleteFlight() async throws {
        // Given - Complete flight: Takeoff → Split-S → Level → Landing
        let dataPoints = createCompleteFlightData()

        // When
        let maneuvers = await service.detectAllManeuvers(in: dataPoints)

        // Then
        XCTAssertGreaterThan(maneuvers.count, 0, "Should detect at least some maneuvers")

        // Check for expected maneuver types
        let types = Set(maneuvers.map { $0.type })
        XCTAssertTrue(types.contains(.takeoff), "Should detect takeoff")
        XCTAssertTrue(types.contains(.landing), "Should detect landing")
    }

    func testDetectAllManeuvers_NoOverlaps() async throws {
        // Given
        let dataPoints = createCompleteFlightData()

        // When
        let maneuvers = await service.detectAllManeuvers(in: dataPoints)

        // Then - Check no maneuvers overlap
        for i in 0..<maneuvers.count {
            for j in (i+1)..<maneuvers.count {
                let range1 = maneuvers[i].startIndex...maneuvers[i].endIndex
                let range2 = maneuvers[j].startIndex...maneuvers[j].endIndex

                // Level flight can overlap with others, but specific maneuvers shouldn't
                if maneuvers[i].type != .levelFlight && maneuvers[j].type != .levelFlight {
                    XCTAssertFalse(
                        range1.overlaps(range2),
                        "Maneuvers \(i) (\(maneuvers[i].type)) and \(j) (\(maneuvers[j].type)) should not overlap"
                    )
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// Create a complete flight scenario with multiple maneuvers
    private func createCompleteFlightData() -> [FlightDataPoint] {
        var allData: [FlightDataPoint] = []
        var currentTime = Date()

        // Ground operations (5 seconds)
        allData.append(contentsOf: createGroundData(duration: 5.0, startTime: currentTime))
        currentTime = currentTime.addingTimeInterval(5.0)

        // Takeoff (15 seconds)
        allData.append(contentsOf: createTakeoffData(startTime: currentTime))
        currentTime = currentTime.addingTimeInterval(15.0)

        // Climb to altitude (30 seconds)
        allData.append(contentsOf: createClimbData(duration: 30.0, startTime: currentTime))
        currentTime = currentTime.addingTimeInterval(30.0)

        // Level flight (20 seconds)
        allData.append(contentsOf: createLevelFlightData(duration: 20.0, startTime: currentTime))
        currentTime = currentTime.addingTimeInterval(20.0)

        // Split-S maneuver (14 seconds)
        allData.append(contentsOf: createSplitSData(startTime: currentTime))
        currentTime = currentTime.addingTimeInterval(14.0)

        // Level flight (20 seconds)
        allData.append(contentsOf: createLevelFlightData(duration: 20.0, startTime: currentTime))
        currentTime = currentTime.addingTimeInterval(20.0)

        // Descent (20 seconds)
        allData.append(contentsOf: createDescentData(duration: 20.0, startTime: currentTime))
        currentTime = currentTime.addingTimeInterval(20.0)

        // Landing (15 seconds)
        allData.append(contentsOf: createLandingData(startTime: currentTime))
        currentTime = currentTime.addingTimeInterval(15.0)

        // Ground rollout (10 seconds)
        allData.append(contentsOf: createGroundData(duration: 10.0, startTime: currentTime))

        return allData
    }

    private func createGroundData(duration: Double, startTime: Date) -> [FlightDataPoint] {
        let numPoints = Int(duration / 0.05)
        return (0..<numPoints).map { i in
            return FlightDataPoint(
                irigTime: startTime.addingTimeInterval(Double(i) * 0.05),
                deltaIrig: Double(i) * 0.05,
                normalAccel: 1.0,
                mach: 0.0,
                altitude: 100.0,
                rollAngle: 0.0,
                pitchAngle: 0.0,
                heading: 90.0,
                rollRate: 0.0,
                pitchRate: 0.0,
                yawRate: 0.0,
                aoa: 0.0,
                airspeed: 0.0,
                pressureAltitude: 100.0,
                computedAirspeed: 0.0,
                leftEngineRPM: 20.0,
                rightEngineRPM: 20.0,
                leftFuelFlow: 0.001,
                rightFuelFlow: 0.001,
                stabPos: 0.0,
                speedBrakePos: 0.0,
                rudderPos: 0.0,
                weightOnWheels: true,
                lateralAccel: 0.0,
                longitudinalAccel: 0.0
            )
        }
    }

    private func createTakeoffData(startTime: Date) -> [FlightDataPoint] {
        let numPoints = 300  // 15 seconds
        return (0..<numPoints).map { i in
            let progress = Double(i) / Double(numPoints)
            let liftoffPoint = 0.4  // Liftoff at 40% through sequence

            return FlightDataPoint(
                irigTime: startTime.addingTimeInterval(Double(i) * 0.05),
                deltaIrig: Double(i) * 0.05,
                normalAccel: progress < liftoffPoint ? 1.0 : 1.2,
                mach: 0.25 * progress,
                altitude: progress < liftoffPoint ? 100.0 : 100.0 + (progress - liftoffPoint) * 1000.0,
                rollAngle: 0.0,
                pitchAngle: progress < liftoffPoint ? 0.0 : 15.0,
                heading: 90.0,
                rollRate: 0.0,
                pitchRate: 0.0,
                yawRate: 0.0,
                aoa: 5.0,
                airspeed: 150.0 * progress,
                pressureAltitude: 100.0,
                computedAirspeed: 150.0 * progress,
                leftEngineRPM: 50.0 + progress * 50.0,
                rightEngineRPM: 50.0 + progress * 50.0,
                leftFuelFlow: 0.005,
                rightFuelFlow: 0.005,
                stabPos: -10.0,
                speedBrakePos: 0.0,
                rudderPos: 0.0,
                weightOnWheels: progress < liftoffPoint,
                lateralAccel: 0.0,
                longitudinalAccel: 0.2
            )
        }
    }

    private func createClimbData(duration: Double, startTime: Date) -> [FlightDataPoint] {
        let numPoints = Int(duration / 0.05)
        return (0..<numPoints).map { i in
            let progress = Double(i) / Double(numPoints)

            return FlightDataPoint(
                irigTime: startTime.addingTimeInterval(Double(i) * 0.05),
                deltaIrig: Double(i) * 0.05,
                normalAccel: 1.1,
                mach: 0.50 + progress * 0.30,
                altitude: 700.0 + progress * 24300.0,
                rollAngle: 0.0,
                pitchAngle: 20.0,
                heading: 90.0,
                rollRate: 0.0,
                pitchRate: 0.0,
                yawRate: 0.0,
                aoa: 8.0,
                airspeed: 200.0 + progress * 100.0,
                pressureAltitude: 700.0 + progress * 24300.0,
                computedAirspeed: 200.0 + progress * 100.0,
                leftEngineRPM: 100.0,
                rightEngineRPM: 100.0,
                leftFuelFlow: 0.010,
                rightFuelFlow: 0.010,
                stabPos: -15.0,
                speedBrakePos: 0.0,
                rudderPos: 0.0,
                weightOnWheels: false,
                lateralAccel: 0.0,
                longitudinalAccel: 0.1
            )
        }
    }

    private func createLevelFlightData(duration: Double, startTime: Date) -> [FlightDataPoint] {
        let numPoints = Int(duration / 0.05)
        return (0..<numPoints).map { i in
            return FlightDataPoint(
                irigTime: startTime.addingTimeInterval(Double(i) * 0.05),
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
        }
    }

    private func createSplitSData(startTime: Date) -> [FlightDataPoint] {
        // Reuse the helper from SplitSDetectorTests
        let duration = 14.0
        let numPoints = Int(duration / 0.05)
        var dataPoints: [FlightDataPoint] = []

        for i in 0..<numPoints {
            let time = startTime.addingTimeInterval(Double(i) * 0.05)
            let progress = Double(i) / Double(numPoints)

            var rollAngle: Double
            var gLoad: Double
            var altitude: Double

            if progress < 0.2 {
                rollAngle = (progress / 0.2) * 178.0
                gLoad = 1.0
                altitude = 25000.0 - (progress / 0.2) * 500
            } else if progress < 0.7 {
                rollAngle = 178.0
                let pullProgress = (progress - 0.2) / 0.5
                gLoad = 0.3 + pullProgress * 4.2
                altitude = 24500.0 - pullProgress * 4500

                if pullProgress > 0.5 {
                    rollAngle = 178.0 * (1.0 - (pullProgress - 0.5) / 0.5)
                }
            } else {
                rollAngle = 0.0
                let recoveryProgress = (progress - 0.7) / 0.3
                gLoad = 4.5 - recoveryProgress * 3.5
                altitude = 20000.0
            }

            dataPoints.append(FlightDataPoint(
                irigTime: time,
                deltaIrig: Double(i) * 0.05,
                normalAccel: gLoad,
                mach: 0.80,
                altitude: altitude,
                rollAngle: rollAngle,
                pitchAngle: progress < 0.5 ? -20.0 : 10.0,
                heading: 180.0,
                rollRate: 0.0,
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
                weightOnWheels: false,
                lateralAccel: 0.0,
                longitudinalAccel: 0.0
            ))
        }

        return dataPoints
    }

    private func createDescentData(duration: Double, startTime: Date) -> [FlightDataPoint] {
        let numPoints = Int(duration / 0.05)
        return (0..<numPoints).map { i in
            let progress = Double(i) / Double(numPoints)

            return FlightDataPoint(
                irigTime: startTime.addingTimeInterval(Double(i) * 0.05),
                deltaIrig: Double(i) * 0.05,
                normalAccel: 1.0,
                mach: 0.50 - progress * 0.30,
                altitude: 20000.0 - progress * 19900.0,
                rollAngle: 0.0,
                pitchAngle: -10.0,
                heading: 270.0,
                rollRate: 0.0,
                pitchRate: 0.0,
                yawRate: 0.0,
                aoa: 2.0,
                airspeed: 250.0 - progress * 100.0,
                pressureAltitude: 20000.0 - progress * 19900.0,
                computedAirspeed: 250.0 - progress * 100.0,
                leftEngineRPM: 60.0,
                rightEngineRPM: 60.0,
                leftFuelFlow: 0.003,
                rightFuelFlow: 0.003,
                stabPos: 5.0,
                speedBrakePos: 0.0,
                rudderPos: 0.0,
                weightOnWheels: false,
                lateralAccel: 0.0,
                longitudinalAccel: -0.1
            )
        }
    }

    private func createLandingData(startTime: Date) -> [FlightDataPoint] {
        let numPoints = 300  // 15 seconds
        return (0..<numPoints).map { i in
            let progress = Double(i) / Double(numPoints)
            let touchdownPoint = 0.6  // Touchdown at 60%

            return FlightDataPoint(
                irigTime: startTime.addingTimeInterval(Double(i) * 0.05),
                deltaIrig: Double(i) * 0.05,
                normalAccel: progress > touchdownPoint ? 1.0 : 0.9,
                mach: 0.20 * (1.0 - progress),
                altitude: progress < touchdownPoint ? 100.0 + (1.0 - progress) * 400.0 : 100.0,
                rollAngle: 0.0,
                pitchAngle: progress < touchdownPoint ? 3.0 : 0.0,
                heading: 270.0,
                rollRate: 0.0,
                pitchRate: 0.0,
                yawRate: 0.0,
                aoa: 8.0,
                airspeed: 150.0 * (1.0 - progress),
                pressureAltitude: 100.0,
                computedAirspeed: 150.0 * (1.0 - progress),
                leftEngineRPM: 30.0,
                rightEngineRPM: 30.0,
                leftFuelFlow: 0.002,
                rightFuelFlow: 0.002,
                stabPos: 5.0,
                speedBrakePos: progress > touchdownPoint ? 60.0 : 0.0,
                rudderPos: 0.0,
                weightOnWheels: progress > touchdownPoint,
                lateralAccel: 0.0,
                longitudinalAccel: progress > touchdownPoint ? -0.3 : 0.0
            )
        }
    }
}
