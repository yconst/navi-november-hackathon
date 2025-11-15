//
//  FlightDataPoint.swift
//  FlightCoach
//
//  Created by FlightCoach Development Team.
//

import Foundation

/// Single telemetry data point sampled at 20Hz (0.05s intervals)
struct FlightDataPoint: Identifiable, Codable, Equatable {
    let id: UUID

    // MARK: - Timestamp
    let irigTime: Date              // Parsed from "DDD:HH:MM:SS.SSSSSS"
    let deltaIrig: Double           // Time since last sample (should be ~0.05s)

    // MARK: - Critical Flight Parameters
    let normalAccel: Double         // NZ_NORMAL_ACCEL (g's) - CRITICAL
    let mach: Double                // ADC_MACH
    let altitude: Double            // GPS_ALTITUDE (feet MSL)
    let rollAngle: Double           // EGI_ROLL_ANGLE (degrees)
    let pitchAngle: Double          // EGI_PITCH_ANGLE (degrees)
    let heading: Double             // EGI_TRUE_HEADING (degrees)

    // MARK: - Rates
    let rollRate: Double            // EGI_ROLL_RATE_P (deg/s)
    let pitchRate: Double           // EGI_PITCH_RATE_Q (deg/s)
    let yawRate: Double             // EGI_YAW_RATE_R (deg/s)

    // MARK: - Aerodynamics
    let aoa: Double                 // ADC_AOA_CORRECTED (units)
    let airspeed: Double            // ADC_TRUE_AIRSPEED (knots)
    let pressureAltitude: Double    // ADC_PRESSURE_ALTITUDE (feet)
    let computedAirspeed: Double    // ADC_COMPUTED_AIRSPEED (KCAS)

    // MARK: - Engine Data
    let leftEngineRPM: Double       // EED_LEFT_ENGINE_RPM (N1)
    let rightEngineRPM: Double      // EED_RIGHT_ENGINE_RPM (N1)
    let leftFuelFlow: Double        // LEFT_FUEL_FLOW
    let rightFuelFlow: Double       // RIGHT_FUEL_FLOW

    // MARK: - Control Surfaces
    let stabPos: Double             // STAB_POS
    let speedBrakePos: Double       // SPEED_BRK_POS
    let rudderPos: Double           // RUDDER_POS

    // MARK: - State
    let weightOnWheels: Bool        // ADC_AIR_GND_WOW (1=ground, 0=air)

    // MARK: - Accelerations (for reference)
    let lateralAccel: Double        // NY_LATERAL_ACCEL (g's)
    let longitudinalAccel: Double   // NX_LONG_ACCEL (g's)

    // MARK: - Initializer
    init(
        id: UUID = UUID(),
        irigTime: Date,
        deltaIrig: Double,
        normalAccel: Double,
        mach: Double,
        altitude: Double,
        rollAngle: Double,
        pitchAngle: Double,
        heading: Double,
        rollRate: Double,
        pitchRate: Double,
        yawRate: Double,
        aoa: Double,
        airspeed: Double,
        pressureAltitude: Double,
        computedAirspeed: Double,
        leftEngineRPM: Double,
        rightEngineRPM: Double,
        leftFuelFlow: Double,
        rightFuelFlow: Double,
        stabPos: Double,
        speedBrakePos: Double,
        rudderPos: Double,
        weightOnWheels: Bool,
        lateralAccel: Double,
        longitudinalAccel: Double
    ) {
        self.id = id
        self.irigTime = irigTime
        self.deltaIrig = deltaIrig
        self.normalAccel = normalAccel
        self.mach = mach
        self.altitude = altitude
        self.rollAngle = rollAngle
        self.pitchAngle = pitchAngle
        self.heading = heading
        self.rollRate = rollRate
        self.pitchRate = pitchRate
        self.yawRate = yawRate
        self.aoa = aoa
        self.airspeed = airspeed
        self.pressureAltitude = pressureAltitude
        self.computedAirspeed = computedAirspeed
        self.leftEngineRPM = leftEngineRPM
        self.rightEngineRPM = rightEngineRPM
        self.leftFuelFlow = leftFuelFlow
        self.rightFuelFlow = rightFuelFlow
        self.stabPos = stabPos
        self.speedBrakePos = speedBrakePos
        self.rudderPos = rudderPos
        self.weightOnWheels = weightOnWheels
        self.lateralAccel = lateralAccel
        self.longitudinalAccel = longitudinalAccel
    }

    // MARK: - Computed Properties

    /// Returns the time in seconds since the start of the flight data
    var relativeTime: TimeInterval {
        return irigTime.timeIntervalSince1970
    }

    /// Check if aircraft is airborne
    var isAirborne: Bool {
        return !weightOnWheels
    }

    /// Check if aircraft is inverted (roll angle > 150° or < -150°)
    var isInverted: Bool {
        return abs(rollAngle) > 150
    }
}

// MARK: - Sample Data
extension FlightDataPoint {
    /// Sample data point for previews and testing
    static var sample: FlightDataPoint {
        FlightDataPoint(
            irigTime: Date(),
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
    }
}
