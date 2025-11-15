//
//  DataLoaderTests.swift
//  FlightCoachTests
//
//  Created by FlightCoach Development Team.
//

import XCTest
@testable import FlightCoach

final class DataLoaderTests: XCTestCase {

    var dataLoader: DataLoader!

    override func setUp() async throws {
        try await super.setUp()
        dataLoader = DataLoader()
    }

    override func tearDown() async throws {
        dataLoader = nil
        try await super.tearDown()
    }

    // MARK: - CSV Loading Tests

    func testLoadValidCSV() async throws {
        // Given
        let csvURL = try getTestCSVURL()

        // When
        let dataPoints = try await dataLoader.loadCSV(from: csvURL)

        // Then
        XCTAssertEqual(dataPoints.count, 3, "Should load 3 data points from test CSV")
    }

    func testLoadedDataPointValues() async throws {
        // Given
        let csvURL = try getTestCSVURL()

        // When
        let dataPoints = try await dataLoader.loadCSV(from: csvURL)

        // Then
        guard let firstPoint = dataPoints.first else {
            XCTFail("Should have at least one data point")
            return
        }

        XCTAssertEqual(firstPoint.normalAccel, 1.02, accuracy: 0.01)
        XCTAssertEqual(firstPoint.mach, 0.81, accuracy: 0.01)
        XCTAssertEqual(firstPoint.altitude, 25000.0, accuracy: 0.1)
        XCTAssertEqual(firstPoint.rollAngle, 2.3, accuracy: 0.1)
        XCTAssertEqual(firstPoint.pitchAngle, 5.1, accuracy: 0.1)
        XCTAssertFalse(firstPoint.weightOnWheels)
    }

    func testDeltaIrigValues() async throws {
        // Given
        let csvURL = try getTestCSVURL()

        // When
        let dataPoints = try await dataLoader.loadCSV(from: csvURL)

        // Then
        XCTAssertEqual(dataPoints[0].deltaIrig, 0.0, accuracy: 0.001)
        XCTAssertEqual(dataPoints[1].deltaIrig, 0.05, accuracy: 0.001)
        XCTAssertEqual(dataPoints[2].deltaIrig, 0.10, accuracy: 0.001)
    }

    // MARK: - IRIG Timestamp Parsing Tests

    func testIRIGTimestampParsing() async throws {
        // Given
        let csvURL = try getTestCSVURL()

        // When
        let dataPoints = try await dataLoader.loadCSV(from: csvURL)

        // Then - Use GMT timezone since DataLoader parses in GMT
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let firstPoint = dataPoints[0]
        let components = calendar.dateComponents([.hour, .minute, .second], from: firstPoint.irigTime)

        XCTAssertEqual(components.hour, 21, "Hour should be 21 in GMT")
        XCTAssertEqual(components.minute, 25, "Minute should be 25")
        XCTAssertEqual(components.second, 53, "Second should be 53")
    }

    func testTimestampSequence() async throws {
        // Given
        let csvURL = try getTestCSVURL()

        // When
        let dataPoints = try await dataLoader.loadCSV(from: csvURL)

        // Then
        XCTAssertTrue(dataPoints[1].irigTime > dataPoints[0].irigTime)
        XCTAssertTrue(dataPoints[2].irigTime > dataPoints[1].irigTime)

        // Verify ~0.05 second intervals
        let interval1 = dataPoints[1].irigTime.timeIntervalSince(dataPoints[0].irigTime)
        let interval2 = dataPoints[2].irigTime.timeIntervalSince(dataPoints[1].irigTime)

        XCTAssertEqual(interval1, 0.05, accuracy: 0.01)
        XCTAssertEqual(interval2, 0.05, accuracy: 0.01)
    }

    // MARK: - Error Handling Tests

    func testLoadNonExistentFile() async {
        // Given
        let nonExistentURL = URL(fileURLWithPath: "/tmp/nonexistent.csv")

        // When/Then
        do {
            _ = try await dataLoader.loadCSV(from: nonExistentURL)
            XCTFail("Should throw an error for non-existent file")
        } catch {
            // Expected to throw
            XCTAssertTrue(error is DataLoader.DataLoaderError || error is CocoaError)
        }
    }

    func testLoadInvalidCSVFormat() async throws {
        // Given
        let invalidCSV = """
        This is not a valid CSV format
        with no proper structure
        """
        let tempURL = try createTempCSV(content: invalidCSV, filename: "invalid.csv")

        // When/Then
        do {
            _ = try await dataLoader.loadCSV(from: tempURL)
            XCTFail("Should throw an error for invalid CSV format")
        } catch let error as DataLoader.DataLoaderError {
            // Expected to throw DataLoaderError
            XCTAssertNotNil(error.errorDescription)
        } catch {
            // May also throw other errors during parsing
            XCTAssertTrue(true, "Error thrown as expected: \(error)")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testMissingRequiredColumns() async throws {
        // Given
        let missingColumnsCSV = """
        IRIG_TIME,ADC_MACH
        147:21:25:53.500000,0.81
        """
        let tempURL = try createTempCSV(content: missingColumnsCSV, filename: "missing_columns.csv")

        // When/Then
        do {
            _ = try await dataLoader.loadCSV(from: tempURL)
            XCTFail("Should throw an error for missing required columns")
        } catch let error as DataLoader.DataLoaderError {
            if case .missingRequiredColumns(let columns) = error {
                XCTAssertTrue(columns.contains("NZ_NORMAL_ACCEL"))
                XCTAssertTrue(columns.contains("GPS_ALTITUDE"))
            } else {
                XCTFail("Expected missingRequiredColumns error")
            }
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Data Integrity Tests

    func testAllDataPointsHaveUniqueIDs() async throws {
        // Given
        let csvURL = try getTestCSVURL()

        // When
        let dataPoints = try await dataLoader.loadCSV(from: csvURL)

        // Then
        let uniqueIDs = Set(dataPoints.map { $0.id })
        XCTAssertEqual(uniqueIDs.count, dataPoints.count, "All data points should have unique IDs")
    }

    func testWeightOnWheelsConversion() async throws {
        // Given
        let wowCSV = """
        IRIG_TIME,Delta_Irig,NZ_NORMAL_ACCEL,ADC_MACH,GPS_ALTITUDE,EGI_ROLL_ANGLE,EGI_PITCH_ANGLE,EGI_TRUE_HEADING,EGI_ROLL_RATE_P,EGI_PITCH_RATE_Q,EGI_YAW_RATE_R,ADC_AOA_CORRECTED,ADC_TRUE_AIRSPEED,ADC_PRESSURE_ALTITUDE,ADC_COMPUTED_AIRSPEED,EED_LEFT_ENGINE_RPM,EED_RIGHT_ENGINE_RPM,LEFT_FUEL_FLOW,RIGHT_FUEL_FLOW,STAB_POS,SPEED_BRK_POS,RUDDER_POS,ADC_AIR_GND_WOW,NY_LATERAL_ACCEL,NX_LONG_ACCEL
        147:21:25:53.500000,0.0,1.0,0.8,100,0,0,0,0,0,0,0,100,100,100,50,50,0.002,0.002,0,0,0,1,0,0
        147:21:25:53.550000,0.05,1.0,0.8,200,0,0,0,0,0,0,0,100,100,100,50,50,0.002,0.002,0,0,0,0,0,0
        """
        let tempURL = try createTempCSV(content: wowCSV, filename: "wow_test.csv")

        // When
        let dataPoints = try await dataLoader.loadCSV(from: tempURL)

        // Then
        XCTAssertTrue(dataPoints[0].weightOnWheels, "First point should be on ground (WOW=1)")
        XCTAssertFalse(dataPoints[1].weightOnWheels, "Second point should be in air (WOW=0)")
        XCTAssertFalse(dataPoints[0].isAirborne)
        XCTAssertTrue(dataPoints[1].isAirborne)

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Performance Tests

    func testLoadLargeCSVPerformance() async throws {
        // Given
        let largeCSV = try createLargeTestCSV(rowCount: 1000)

        // When/Then
        let startTime = Date()
        let dataPoints = try await dataLoader.loadCSV(from: largeCSV)
        let duration = Date().timeIntervalSince(startTime)

        XCTAssertEqual(dataPoints.count, 1000)
        XCTAssertLessThan(duration, 5.0, "Should load 1000 rows in less than 5 seconds")

        // Cleanup
        try? FileManager.default.removeItem(at: largeCSV)
    }

    // MARK: - Helper Methods

    private func getTestCSVURL() throws -> URL {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "test_data", withExtension: "csv") else {
            throw XCTSkip("Test CSV file not found in test bundle")
        }
        return url
    }

    private func createTempCSV(content: String, filename: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func createLargeTestCSV(rowCount: Int) throws -> URL {
        var csvContent = "IRIG_TIME,Delta_Irig,NZ_NORMAL_ACCEL,ADC_MACH,GPS_ALTITUDE,EGI_ROLL_ANGLE,EGI_PITCH_ANGLE,EGI_TRUE_HEADING,EGI_ROLL_RATE_P,EGI_PITCH_RATE_Q,EGI_YAW_RATE_R,ADC_AOA_CORRECTED,ADC_TRUE_AIRSPEED,ADC_PRESSURE_ALTITUDE,ADC_COMPUTED_AIRSPEED,EED_LEFT_ENGINE_RPM,EED_RIGHT_ENGINE_RPM,LEFT_FUEL_FLOW,RIGHT_FUEL_FLOW,STAB_POS,SPEED_BRK_POS,RUDDER_POS,ADC_AIR_GND_WOW,NY_LATERAL_ACCEL,NX_LONG_ACCEL\n"

        for i in 0..<rowCount {
            let seconds = 53.0 + (Double(i) * 0.05)
            let deltaIrig = Double(i) * 0.05
            let row = "147:21:25:\(String(format: "%.6f", seconds)),\(String(format: "%.6f", deltaIrig)),1.0,0.8,25000,0,0,0,0,0,0,0,300,25000,300,50,50,0.002,0.002,0,0,0,0,0,0\n"
            csvContent += row
        }

        return try createTempCSV(content: csvContent, filename: "large_test.csv")
    }
}
