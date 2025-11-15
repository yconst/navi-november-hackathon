//
//  PerformanceMetrics.swift
//  FlightCoach
//
//  Created by FlightCoach Development Team.
//

import Foundation

/// Performance metrics for a maneuver
struct PerformanceMetrics: Codable, Equatable {
    // MARK: - Overall Score
    let overallScore: Double        // 0-10

    // MARK: - Component Scores
    let machStability: Double       // 0-10
    let gOnsetSmoothness: Double   // 0-10
    let recoveryTiming: Double     // 0-10

    // MARK: - Mach Metrics
    let machMean: Double
    let machStdDev: Double
    let machMaxExcursion: Double
    let machTarget: Double?

    // MARK: - G-Loading Metrics
    let gMax: Double
    let gMin: Double
    let gOnsetTime: Double         // Seconds from 1g to 5g

    // MARK: - Altitude Metrics
    let altitudeLoss: Double       // Feet
    let entryAltitude: Double      // Feet MSL
    let recoveryAltitude: Double   // Feet MSL
    let minAltitude: Double        // Feet MSL
    let timeToMinAltitude: Double  // Seconds

    // MARK: - Safety Margins
    let timeSafetyMargin: Double   // TSM (feet or seconds)
    let minAltitudeMargin: Double  // Above hard deck

    // MARK: - Deviations
    let deviations: [Deviation]

    // MARK: - Quality Assessment
    var qualityText: String {
        switch overallScore {
        case 9.0...10.0:
            return "Excellent execution"
        case 8.0..<9.0:
            return "Good execution with minor issues"
        case 7.0..<8.0:
            return "Acceptable execution with room for improvement"
        case 5.0..<7.0:
            return "Marginal execution - review deviations"
        default:
            return "Poor execution - requires improvement"
        }
    }
}

// MARK: - Deviation

struct Deviation: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let severity: Severity
    let parameter: String
    let value: Double
    let expected: Double
    let deviation: Double
    let issue: String
    let recommendation: String

    enum Severity: String, Codable {
        case minor
        case moderate
        case major

        var displayName: String {
            rawValue.capitalized
        }

        var color: String {
            switch self {
            case .minor: return "yellow"
            case .moderate: return "orange"
            case .major: return "red"
            }
        }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date,
        severity: Severity,
        parameter: String,
        value: Double,
        expected: Double,
        deviation: Double,
        issue: String,
        recommendation: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.severity = severity
        self.parameter = parameter
        self.value = value
        self.expected = expected
        self.deviation = deviation
        self.issue = issue
        self.recommendation = recommendation
    }
}

// MARK: - Sample Data
extension PerformanceMetrics {
    static var sample: PerformanceMetrics {
        PerformanceMetrics(
            overallScore: 8.3,
            machStability: 8.5,
            gOnsetSmoothness: 7.2,
            recoveryTiming: 9.1,
            machMean: 0.803,
            machStdDev: 0.018,
            machMaxExcursion: 0.042,
            machTarget: 0.80,
            gMax: 5.2,
            gMin: -0.3,
            gOnsetTime: 2.3,
            altitudeLoss: 4900,
            entryAltitude: 25000,
            recoveryAltitude: 20100,
            minAltitude: 19800,
            timeToMinAltitude: 11.3,
            timeSafetyMargin: 1200,
            minAltitudeMargin: 800,
            deviations: [
                Deviation(
                    timestamp: Date(),
                    severity: .moderate,
                    parameter: "ADC_MACH",
                    value: 0.842,
                    expected: 0.800,
                    deviation: 0.042,
                    issue: "Mach excursion above databand",
                    recommendation: "Faster aft stick rate needed during pull initiation"
                )
            ]
        )
    }
}
