//
//  ManeuverDetector.swift
//  FlightCoach
//
//  Created by FlightCoach Development Team.
//

import Foundation

/// Protocol for all maneuver detection algorithms
protocol ManeuverDetector {
    /// The type of maneuver this detector identifies
    var maneuverType: ManeuverType { get }

    /// Detect maneuvers in the provided flight data
    /// - Parameter dataPoints: Array of telemetry data points
    /// - Returns: Array of detected maneuvers with confidence scores
    func detect(in dataPoints: [FlightDataPoint]) async -> [Maneuver]
}

/// Result of a detection algorithm with confidence metadata
struct DetectionResult {
    let startIndex: Int
    let endIndex: Int
    let confidence: Double
    let reason: String

    /// Check if this detection meets the minimum confidence threshold
    func meetsThreshold(_ threshold: Double = 0.75) -> Bool {
        return confidence >= threshold
    }
}

/// Configuration for detection algorithms
struct DetectionConfiguration {
    /// Minimum confidence threshold for accepting detections (0.0 - 1.0)
    let minConfidence: Double

    /// Minimum duration for a maneuver (seconds)
    let minDuration: Double

    /// Maximum duration for a maneuver (seconds)
    let maxDuration: Double

    /// Minimum number of data points required
    var minDataPoints: Int {
        Int(minDuration / 0.05) // 20Hz sampling
    }

    /// Maximum number of data points allowed
    var maxDataPoints: Int {
        Int(maxDuration / 0.05)
    }

    /// Default configuration for Split-S maneuvers
    static let splitS = DetectionConfiguration(
        minConfidence: 0.75,
        minDuration: 8.0,   // Typical Split-S: 10-15 seconds
        maxDuration: 25.0
    )

    /// Default configuration for takeoff/landing
    static let groundTransition = DetectionConfiguration(
        minConfidence: 0.90,  // Very high confidence for clear events
        minDuration: 2.0,
        maxDuration: 30.0
    )

    /// Default configuration for level flight
    static let levelFlight = DetectionConfiguration(
        minConfidence: 0.85,
        minDuration: 5.0,
        maxDuration: 300.0  // Up to 5 minutes
    )
}

/// Helper extensions for detection algorithms
extension Array where Element == FlightDataPoint {
    /// Extract a time window of data points
    func window(from startIndex: Int, length: Int) -> [FlightDataPoint] {
        let endIndex = Swift.min(startIndex + length, count)
        guard startIndex < count && startIndex >= 0 else { return [] }
        return Array(self[startIndex..<endIndex])
    }

    /// Find data points where a condition changes from false to true
    func risingEdges(where condition: (FlightDataPoint) -> Bool) -> [Int] {
        var edges: [Int] = []
        for i in 1..<count {
            if !condition(self[i-1]) && condition(self[i]) {
                edges.append(i)
            }
        }
        return edges
    }

    /// Find data points where a condition changes from true to false
    func fallingEdges(where condition: (FlightDataPoint) -> Bool) -> [Int] {
        var edges: [Int] = []
        for i in 1..<count {
            if condition(self[i-1]) && !condition(self[i]) {
                edges.append(i)
            }
        }
        return edges
    }

    /// Calculate rolling average of a parameter
    func rollingAverage(of keyPath: KeyPath<FlightDataPoint, Double>, window: Int) -> [Double] {
        guard window > 0 && !isEmpty else { return [] }

        var result: [Double] = []
        result.reserveCapacity(count)

        for i in 0..<count {
            let start = Swift.max(0, i - window/2)
            let end = Swift.min(count, i + window/2 + 1)
            let windowData = self[start..<end]
            let sum = windowData.reduce(0.0) { $0 + $1[keyPath: keyPath] }
            result.append(sum / Double(windowData.count))
        }

        return result
    }

    /// Calculate standard deviation of a parameter over a range
    func standardDeviation(of keyPath: KeyPath<FlightDataPoint, Double>, in range: Range<Int>) -> Double {
        let dataRange = self[range]
        let values = dataRange.map { $0[keyPath: keyPath] }

        guard !values.isEmpty else { return 0.0 }

        let mean = values.reduce(0.0, +) / Double(values.count)
        let variance = values.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(values.count)

        return sqrt(variance)
    }

    /// Find the index of the maximum value for a given parameter
    func indexOfMax(for keyPath: KeyPath<FlightDataPoint, Double>, in range: Range<Int>? = nil) -> Int? {
        let searchRange = range ?? (0..<count)
        guard !searchRange.isEmpty else { return nil }

        var maxIndex = searchRange.lowerBound
        var maxValue = self[maxIndex][keyPath: keyPath]

        for i in searchRange.dropFirst() {
            let value = self[i][keyPath: keyPath]
            if value > maxValue {
                maxValue = value
                maxIndex = i
            }
        }

        return maxIndex
    }

    /// Find the index of the minimum value for a given parameter
    func indexOfMin(for keyPath: KeyPath<FlightDataPoint, Double>, in range: Range<Int>? = nil) -> Int? {
        let searchRange = range ?? (0..<count)
        guard !searchRange.isEmpty else { return nil }

        var minIndex = searchRange.lowerBound
        var minValue = self[minIndex][keyPath: keyPath]

        for i in searchRange.dropFirst() {
            let value = self[i][keyPath: keyPath]
            if value < minValue {
                minValue = value
                minIndex = i
            }
        }

        return minIndex
    }
}
