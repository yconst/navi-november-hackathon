//
//  RealDataDetectionTests.swift
//  FlightCoachTests
//
//  Test maneuver detection on actual flight data
//

import XCTest
@testable import FlightCoach

final class RealDataDetectionTests: XCTestCase {

    var dataLoader: DataLoader!
    var detectionService: ManeuverDetectionService!

    override func setUp() async throws {
        try await super.setUp()
        dataLoader = DataLoader()
        detectionService = ManeuverDetectionService()
    }

    override func tearDown() async throws {
        dataLoader = nil
        detectionService = nil
        try await super.tearDown()
    }

    // MARK: - Real Flight Data Tests

    func testDetectManeuversInRealFlightData() async throws {
        // Given - Load the actual T-38 flight data
        let csvURL = try getRealFlightDataURL()
        print("\n=== Loading Real Flight Data ===")
        print("CSV Path: \(csvURL.path)")

        let startLoad = Date()
        let dataPoints = try await dataLoader.loadCSV(from: csvURL)
        let loadDuration = Date().timeIntervalSince(startLoad)

        print("✅ Loaded \(dataPoints.count) data points in \(String(format: "%.2f", loadDuration)) seconds")
        print("Flight Duration: \(String(format: "%.1f", dataPoints.last!.irigTime.timeIntervalSince(dataPoints.first!.irigTime) / 60.0)) minutes")
        print("Data Rate: \(String(format: "%.1f", 1.0 / (dataPoints[1].deltaIrig))) Hz")

        // When - Detect all maneuvers
        print("\n=== Running Maneuver Detection ===")
        let startDetection = Date()

        var progressUpdates: [Double] = []
        let maneuvers = await detectionService.detectAllManeuvers(in: dataPoints) { progress in
            progressUpdates.append(progress)
            if progress == 0.25 || progress == 0.5 || progress == 0.75 || progress == 1.0 {
                print("Detection Progress: \(Int(progress * 100))%")
            }
        }

        let detectionDuration = Date().timeIntervalSince(startDetection)
        print("✅ Detection completed in \(String(format: "%.2f", detectionDuration)) seconds")

        // Then - Analyze results
        var report = "\n=== Detection Results ===\n"
        report += "Total Maneuvers Detected: \(maneuvers.count)\n"
        print(report, terminator: "")

        // Group by type
        let maneuversByType = Dictionary(grouping: maneuvers, by: { $0.type })
        for (type, typedManeuvers) in maneuversByType.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let typeReport = "\n\(type.displayName): \(typedManeuvers.count) detected\n"
            report += typeReport
            print(typeReport, terminator: "")

            for (index, maneuver) in typedManeuvers.enumerated() {
                let duration = maneuver.duration
                let confidence = maneuver.confidence
                let startTime = formatTime(maneuver.startTime, relativeTo: dataPoints.first!.irigTime)

                let maneuverLine = "  [\(index + 1)] Time: \(startTime), Duration: \(String(format: "%.1f", duration))s, Confidence: \(String(format: "%.0f", confidence * 100))%\n"
                report += maneuverLine
                print(maneuverLine, terminator: "")

                // Print phases for Split-S
                if type == .splitS, let phases = maneuver.phases {
                    for phase in phases {
                        print("      - \(phase.name): \(String(format: "%.1f", phase.duration))s")
                    }
                }
            }
        }

        // Statistics
        report += "\n=== Statistics ===\n"
        print("\n=== Statistics ===")
        let avgConfidence = maneuvers.map { $0.confidence }.reduce(0, +) / Double(maneuvers.count)
        let avgLine = "Average Confidence: \(String(format: "%.1f", avgConfidence * 100))%\n"
        report += avgLine
        print(avgLine, terminator: "")

        let totalManeuverTime = maneuvers.reduce(0.0) { $0 + $1.duration }
        let totalFlightTime = dataPoints.last!.irigTime.timeIntervalSince(dataPoints.first!.irigTime)
        let coveragePercent = (totalManeuverTime / totalFlightTime) * 100
        let coverageLine = "Flight Coverage: \(String(format: "%.1f", coveragePercent))% (\(String(format: "%.0f", totalManeuverTime))s / \(String(format: "%.0f", totalFlightTime))s)\n"
        report += coverageLine
        print(coverageLine, terminator: "")

        // Write report to file
        let reportPath = "/tmp/detection_results.txt"
        try? report.write(toFile: reportPath, atomically: true, encoding: .utf8)
        print("\nResults written to: \(reportPath)")

        // Assertions
        XCTAssertGreaterThan(maneuvers.count, 0, "Should detect at least some maneuvers")
        XCTAssertTrue(progressUpdates.contains(1.0), "Should reach 100% progress")

        // Verify no overlaps
        for i in 0..<maneuvers.count {
            for j in (i+1)..<maneuvers.count {
                let range1 = maneuvers[i].startIndex...maneuvers[i].endIndex
                let range2 = maneuvers[j].startIndex...maneuvers[j].endIndex

                // Allow level flight to overlap with others
                if maneuvers[i].type != .levelFlight && maneuvers[j].type != .levelFlight {
                    XCTAssertFalse(range1.overlaps(range2),
                        "Maneuvers \(i) and \(j) should not overlap")
                }
            }
        }

        print("\n=== Test Complete ===\n")
    }

    func testDetectSplitSInRealData() async throws {
        // Given
        let csvURL = try getRealFlightDataURL()
        let dataPoints = try await dataLoader.loadCSV(from: csvURL)

        print("\n=== Testing Split-S Detection ===")
        print("Searching \(dataPoints.count) data points...")

        // When
        let splitSManeuvers = await detectionService.detectManeuvers(ofType: .splitS, in: dataPoints)

        // Then
        print("\nSplit-S Maneuvers Found: \(splitSManeuvers.count)")

        for (index, maneuver) in splitSManeuvers.enumerated() {
            print("\n[\(index + 1)] Split-S Detection:")
            print("  Start: \(formatTime(maneuver.startTime, relativeTo: dataPoints.first!.irigTime))")
            print("  Duration: \(String(format: "%.1f", maneuver.duration)) seconds")
            print("  Confidence: \(String(format: "%.0f", maneuver.confidence * 100))%")
            print("  Data Points: \(maneuver.startIndex) - \(maneuver.endIndex) (\(maneuver.endIndex - maneuver.startIndex) points)")

            if let phases = maneuver.phases {
                print("  Phases:")
                for phase in phases {
                    print("    - \(phase.name): \(String(format: "%.1f", phase.duration))s")
                    if !phase.keyMetrics.isEmpty {
                        for (key, value) in phase.keyMetrics.sorted(by: { $0.key < $1.key }) {
                            print("      \(key): \(String(format: "%.2f", value))")
                        }
                    }
                }
            }

            // Show key data points
            let entryPoint = dataPoints[maneuver.startIndex]
            let exitPoint = dataPoints[maneuver.endIndex]
            print("  Entry: Alt=\(String(format: "%.0f", entryPoint.altitude))ft, Mach=\(String(format: "%.2f", entryPoint.mach)), G=\(String(format: "%.1f", entryPoint.normalAccel))")
            print("  Exit:  Alt=\(String(format: "%.0f", exitPoint.altitude))ft, Mach=\(String(format: "%.2f", exitPoint.mach)), G=\(String(format: "%.1f", exitPoint.normalAccel))")
            print("  Altitude Loss: \(String(format: "%.0f", entryPoint.altitude - exitPoint.altitude)) feet")
        }

        print("\n=== Split-S Test Complete ===\n")
    }

    func testFlightStatistics() async throws {
        // Given
        let csvURL = try getRealFlightDataURL()
        let dataPoints = try await dataLoader.loadCSV(from: csvURL)

        print("\n=== Flight Data Statistics ===")

        // Time statistics
        let duration = dataPoints.last!.irigTime.timeIntervalSince(dataPoints.first!.irigTime)
        print("Total Duration: \(String(format: "%.1f", duration / 60.0)) minutes (\(String(format: "%.0f", duration)) seconds)")
        print("Sample Rate: \(String(format: "%.1f", 1.0 / dataPoints[1].deltaIrig)) Hz")
        print("Total Data Points: \(dataPoints.count)")

        // Altitude statistics
        let altitudes = dataPoints.map { $0.altitude }
        let minAlt = altitudes.min() ?? 0
        let maxAlt = altitudes.max() ?? 0
        print("\nAltitude Range: \(String(format: "%.0f", minAlt)) - \(String(format: "%.0f", maxAlt)) feet")

        // Airborne time
        let airbornePoints = dataPoints.filter { $0.isAirborne }
        let airborneDuration = Double(airbornePoints.count) * 0.05 / 60.0
        print("Airborne Time: \(String(format: "%.1f", airborneDuration)) minutes")

        // G-loading statistics
        let gValues = dataPoints.map { $0.normalAccel }
        let minG = gValues.min() ?? 0
        let maxG = gValues.max() ?? 0
        let avgG = gValues.reduce(0, +) / Double(gValues.count)
        print("\nG-Loading:")
        print("  Min: \(String(format: "%.2f", minG))g")
        print("  Max: \(String(format: "%.2f", maxG))g")
        print("  Average: \(String(format: "%.2f", avgG))g")

        // Mach statistics
        let machValues = dataPoints.filter { $0.isAirborne }.map { $0.mach }
        if !machValues.isEmpty {
            let avgMach = machValues.reduce(0, +) / Double(machValues.count)
            let maxMach = machValues.max() ?? 0
            print("\nMach Number (airborne):")
            print("  Average: \(String(format: "%.2f", avgMach))")
            print("  Max: \(String(format: "%.2f", maxMach))")
        }

        // Inverted flight
        let invertedPoints = dataPoints.filter { $0.isInverted }
        if !invertedPoints.isEmpty {
            let invertedTime = Double(invertedPoints.count) * 0.05
            print("\nInverted Flight: \(String(format: "%.1f", invertedTime)) seconds")
        }

        print("\n=== Statistics Complete ===\n")
    }

    // MARK: - Helper Methods

    private func getRealFlightDataURL() throws -> URL {
        // Try to find the actual flight data CSV
        let fileManager = FileManager.default
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        // Check common locations
        let possiblePaths = [
            URL(fileURLWithPath: "/Users/yanconst/Projects/FlightCoach/AirForce_Sortie_Aeromod.csv"),
            projectDir.appendingPathComponent("AirForce_Sortie_Aeromod.csv"),
            projectDir.appendingPathComponent("FlightCoachTests/test_data.csv"),
            projectDir.appendingPathComponent("T38_70min.csv")
        ]

        for path in possiblePaths {
            if fileManager.fileExists(atPath: path.path) {
                return path
            }
        }

        // Fall back to test data
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "test_data", withExtension: "csv") else {
            throw XCTSkip("No flight data CSV found")
        }
        return url
    }

    private func formatTime(_ time: Date, relativeTo start: Date) -> String {
        let elapsed = time.timeIntervalSince(start)
        let minutes = Int(elapsed / 60)
        let seconds = Int(elapsed.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
}
