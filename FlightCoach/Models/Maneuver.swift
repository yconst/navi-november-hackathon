//
//  Maneuver.swift
//  FlightCoach
//
//  Created by FlightCoach Development Team.
//

import Foundation
import SwiftUI

/// Represents a detected maneuver with metadata and performance metrics
struct Maneuver: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ManeuverType

    // MARK: - Time Range
    let startTime: Date
    let endTime: Date
    let startIndex: Int             // Index in telemetry data array
    let endIndex: Int               // Index in telemetry data array

    // MARK: - Detection Metadata
    let confidence: Double          // 0.0 to 1.0
    let detectionMethod: DetectionMethod

    // MARK: - Performance Metrics (calculated during analysis)
    var metrics: PerformanceMetrics?

    // MARK: - Phase Breakdown (for complex maneuvers like Split-S)
    var phases: [ManeuverPhase]?

    // MARK: - Computed Properties

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var overallScore: Double {
        metrics?.overallScore ?? 0.0
    }

    var scoreColor: Color {
        switch overallScore {
        case 9.0...10.0: return .green
        case 7.0..<9.0: return .blue
        case 5.0..<7.0: return .yellow
        default: return .red
        }
    }

    var timeRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let start = formatter.string(from: startTime)
        let end = formatter.string(from: endTime)
        return "\(start) - \(end) (\(String(format: "%.1f", duration))s)"
    }
}

// MARK: - Maneuver Type

enum ManeuverType: String, Codable, CaseIterable {
    case takeoff
    case landing
    case levelFlight
    case climb
    case descent
    case splitS
    case windUpTurn
    case rollerCoaster
    case unknown

    var displayName: String {
        switch self {
        case .splitS: return "Split-S"
        case .windUpTurn: return "Wind-Up Turn"
        case .rollerCoaster: return "Roller Coaster"
        case .levelFlight: return "Level Flight"
        default: return rawValue.capitalized
        }
    }

    var icon: String {
        switch self {
        case .takeoff: return "airplane.departure"
        case .landing: return "airplane.arrival"
        case .splitS: return "arrow.down.right.circle.fill"
        case .windUpTurn: return "arrow.clockwise.circle.fill"
        case .rollerCoaster: return "waveform.path"
        case .levelFlight: return "minus.circle"
        case .climb: return "arrow.up.circle"
        case .descent: return "arrow.down.circle"
        case .unknown: return "questionmark.circle"
        }
    }

    var description: String {
        switch self {
        case .takeoff: return "Aircraft leaves ground (WOW: 1→0)"
        case .landing: return "Aircraft touches down (WOW: 0→1)"
        case .levelFlight: return "Sustained 1g flight"
        case .climb: return "Positive vertical speed"
        case .descent: return "Negative vertical speed"
        case .splitS: return "Roll inverted → pull through → recover"
        case .windUpTurn: return "Sustained bank with increasing g-loading"
        case .rollerCoaster: return "Cyclic 0g ↔ 2g oscillations"
        case .unknown: return "Unknown maneuver type"
        }
    }
}

// MARK: - Detection Method

enum DetectionMethod: String, Codable {
    case ruleBased = "rule-based"
    case mlBased = "ml-based"
    case hybrid
    case manual

    var displayName: String {
        switch self {
        case .ruleBased: return "Rule-Based"
        case .mlBased: return "ML-Based"
        case .hybrid: return "Hybrid"
        case .manual: return "Manual"
        }
    }
}

// MARK: - Maneuver Phase

struct ManeuverPhase: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let startTime: Date
    let endTime: Date
    let startIndex: Int
    let endIndex: Int
    let description: String
    var keyMetrics: [String: Double]

    init(
        id: UUID = UUID(),
        name: String,
        startTime: Date,
        endTime: Date,
        startIndex: Int,
        endIndex: Int,
        description: String,
        keyMetrics: [String: Double] = [:]
    ) {
        self.id = id
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.description = description
        self.keyMetrics = keyMetrics
    }

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

// MARK: - Sample Data
extension Maneuver {
    static var sample: Maneuver {
        Maneuver(
            id: UUID(),
            type: .splitS,
            startTime: Date(),
            endTime: Date().addingTimeInterval(14.85),
            startIndex: 0,
            endIndex: 297,
            confidence: 0.92,
            detectionMethod: .ruleBased,
            metrics: PerformanceMetrics.sample,
            phases: [
                ManeuverPhase(
                    name: "Roll Inverted",
                    startTime: Date(),
                    endTime: Date().addingTimeInterval(2.7),
                    startIndex: 0,
                    endIndex: 54,
                    description: "Roll from upright to inverted",
                    keyMetrics: ["max_roll_angle": 178.5]
                ),
                ManeuverPhase(
                    name: "Pull Through",
                    startTime: Date().addingTimeInterval(2.7),
                    endTime: Date().addingTimeInterval(11.3),
                    startIndex: 54,
                    endIndex: 226,
                    description: "Pull from inverted to upright",
                    keyMetrics: ["min_g": -0.3, "max_g": 5.2]
                ),
                ManeuverPhase(
                    name: "Recovery",
                    startTime: Date().addingTimeInterval(11.3),
                    endTime: Date().addingTimeInterval(14.85),
                    startIndex: 226,
                    endIndex: 297,
                    description: "Return to 1g level flight",
                    keyMetrics: ["recovery_altitude": 20100]
                )
            ]
        )
    }
}
