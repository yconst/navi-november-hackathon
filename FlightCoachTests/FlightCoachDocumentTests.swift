//
//  FlightCoachDocumentTests.swift
//  FlightCoachTests
//
//  Created by FlightCoach Development Team.
//

import XCTest
@testable import FlightCoach

final class FlightCoachDocumentTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        // When
        let document = FlightCoachDocument()

        // Then
        XCTAssertEqual(document.state, .empty)
        XCTAssertTrue(document.isEmpty)
        XCTAssertEqual(document.telemetryData.count, 0)
        XCTAssertEqual(document.detectedManeuvers.count, 0)
        XCTAssertFalse(document.analysisCompleted)
        XCTAssertEqual(document.analysisProgress, 0.0)
    }

    // MARK: - State Tests

    func testDocumentStateTransitions() {
        // Given
        var document = FlightCoachDocument()

        // When - Start importing
        document.state = .importing

        // Then
        XCTAssertEqual(document.state, .importing)
        XCTAssertEqual(document.state.displayName, "Importing...")

        // When - Move to analyzing
        document.state = .analyzing

        // Then
        XCTAssertEqual(document.state, .analyzing)
        XCTAssertEqual(document.state.displayName, "Analyzing...")

        // When - Complete to ready
        document.state = .ready

        // Then
        XCTAssertEqual(document.state, .ready)
        XCTAssertEqual(document.state.displayName, "Ready")
    }

    func testDocumentStateIcons() {
        XCTAssertEqual(DocumentState.empty.icon, "doc.badge.plus")
        XCTAssertEqual(DocumentState.importing.icon, "arrow.down.doc")
        XCTAssertEqual(DocumentState.analyzing.icon, "brain")
        XCTAssertEqual(DocumentState.ready.icon, "checkmark.circle")
        XCTAssertEqual(DocumentState.error.icon, "exclamationmark.triangle")
    }

    // MARK: - Data Tests

    func testAddTelemetryData() {
        // Given
        var document = FlightCoachDocument()
        let dataPoints = [FlightDataPoint.sample]

        // When
        document.telemetryData = dataPoints

        // Then
        XCTAssertEqual(document.dataPointCount, 1)
        XCTAssertFalse(document.isEmpty)
    }

    func testDurationCalculation() {
        // Given
        var document = FlightCoachDocument()
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(70 * 60) // 70 minutes

        let firstPoint = createDataPoint(time: startTime)
        let lastPoint = createDataPoint(time: endTime)

        // When
        document.telemetryData = [firstPoint, lastPoint]

        // Then
        XCTAssertEqual(document.duration, 70 * 60, accuracy: 1.0)
    }

    func testEmptyDuration() {
        // Given
        let document = FlightCoachDocument()

        // Then
        XCTAssertEqual(document.duration, 0.0)
    }

    // MARK: - Metadata Tests

    func testMetadataStorage() {
        // Given
        var document = FlightCoachDocument()

        // When
        document.pilotName = "John Doe"
        document.aircraftTailNumber = "AF-001"
        document.flightDate = Date()
        document.notes = "Test flight"

        // Then
        XCTAssertEqual(document.pilotName, "John Doe")
        XCTAssertEqual(document.aircraftTailNumber, "AF-001")
        XCTAssertNotNil(document.flightDate)
        XCTAssertEqual(document.notes, "Test flight")
    }

    // MARK: - Maneuver Tests

    func testAddManeuvers() {
        // Given
        var document = FlightCoachDocument()
        let maneuver = Maneuver.sample

        // When
        document.detectedManeuvers = [maneuver]

        // Then
        XCTAssertEqual(document.detectedManeuvers.count, 1)
        XCTAssertEqual(document.detectedManeuvers.first?.type, .splitS)
    }

    func testMultipleManeuvers() {
        // Given
        var document = FlightCoachDocument()
        let maneuvers = [
            Maneuver.sample,
            createManeuver(type: .windUpTurn),
            createManeuver(type: .takeoff)
        ]

        // When
        document.detectedManeuvers = maneuvers

        // Then
        XCTAssertEqual(document.detectedManeuvers.count, 3)
        XCTAssertTrue(document.detectedManeuvers.contains(where: { $0.type == .splitS }))
        XCTAssertTrue(document.detectedManeuvers.contains(where: { $0.type == .windUpTurn }))
        XCTAssertTrue(document.detectedManeuvers.contains(where: { $0.type == .takeoff }))
    }

    // MARK: - Analysis State Tests

    func testAnalysisProgress() {
        // Given
        var document = FlightCoachDocument()

        // When
        document.analysisProgress = 0.5

        // Then
        XCTAssertEqual(document.analysisProgress, 0.5, accuracy: 0.01)
    }

    func testAnalysisCompletion() {
        // Given
        var document = FlightCoachDocument()

        // When
        document.analysisCompleted = true
        document.analysisDate = Date()
        document.analysisProgress = 1.0

        // Then
        XCTAssertTrue(document.analysisCompleted)
        XCTAssertNotNil(document.analysisDate)
        XCTAssertEqual(document.analysisProgress, 1.0, accuracy: 0.01)
    }

    // MARK: - Codable Tests

    func testDocumentEncoding() throws {
        // Given
        let document = FlightCoachDocument.sample

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)

        // Then
        XCTAssertFalse(data.isEmpty)

        // Verify JSON is valid
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(json)
    }

    func testDocumentDecoding() throws {
        // Given
        let original = FlightCoachDocument.sample
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        // When
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FlightCoachDocument.self, from: data)

        // Then
        XCTAssertEqual(decoded.state, original.state)
        XCTAssertEqual(decoded.pilotName, original.pilotName)
        XCTAssertEqual(decoded.aircraftTailNumber, original.aircraftTailNumber)
        XCTAssertEqual(decoded.dataPointCount, original.dataPointCount)
        XCTAssertEqual(decoded.detectedManeuvers.count, original.detectedManeuvers.count)
        XCTAssertEqual(decoded.analysisCompleted, original.analysisCompleted)
    }

    func testDocumentRoundTrip() throws {
        // Given
        var original = FlightCoachDocument()
        original.state = .ready
        original.pilotName = "Test Pilot"
        original.aircraftTailNumber = "T-38-001"
        original.flightDate = Date()
        original.telemetryData = [FlightDataPoint.sample]
        original.detectedManeuvers = [Maneuver.sample]
        original.analysisCompleted = true
        original.analysisProgress = 1.0

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FlightCoachDocument.self, from: data)

        // Then
        XCTAssertEqual(decoded.state, original.state)
        XCTAssertEqual(decoded.pilotName, original.pilotName)
        XCTAssertEqual(decoded.aircraftTailNumber, original.aircraftTailNumber)
        XCTAssertEqual(decoded.dataPointCount, original.dataPointCount)
        XCTAssertEqual(decoded.analysisCompleted, original.analysisCompleted)
    }

    // MARK: - Sample Data Tests

    func testSampleDocument() {
        // When
        let sample = FlightCoachDocument.sample

        // Then
        XCTAssertEqual(sample.state, .ready)
        XCTAssertFalse(sample.isEmpty)
        XCTAssertGreaterThan(sample.dataPointCount, 0)
        XCTAssertGreaterThan(sample.detectedManeuvers.count, 0)
        XCTAssertTrue(sample.analysisCompleted)
        XCTAssertEqual(sample.analysisProgress, 1.0)
        XCTAssertNotNil(sample.pilotName)
        XCTAssertNotNil(sample.aircraftTailNumber)
    }

    // MARK: - FileDocument Protocol Tests

    func testReadableContentTypes() {
        // When
        let contentTypes = FlightCoachDocument.readableContentTypes

        // Then
        XCTAssertTrue(contentTypes.contains(.flightCoachDocument))
        XCTAssertTrue(contentTypes.contains(.json))
    }

    func testWritableContentTypes() {
        // When
        let contentTypes = FlightCoachDocument.writableContentTypes

        // Then
        XCTAssertTrue(contentTypes.contains(.flightCoachDocument))
    }

    func testFileWrapperGeneration() throws {
        // Given
        let document = FlightCoachDocument.sample

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)

        // Then
        XCTAssertFalse(data.isEmpty)

        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(json)
    }

    // MARK: - Workflow Tests

    func testCompleteWorkflow() {
        // Given - Start with empty document
        var document = FlightCoachDocument()
        XCTAssertEqual(document.state, .empty)

        // Phase 1: Import
        document.state = .importing
        document.telemetryData = [FlightDataPoint.sample]
        document.flightDate = Date()
        XCTAssertFalse(document.isEmpty)

        // Phase 2: Analyze
        document.state = .analyzing
        document.analysisProgress = 0.5
        document.detectedManeuvers = [Maneuver.sample]
        XCTAssertEqual(document.detectedManeuvers.count, 1)

        // Complete analysis
        document.analysisProgress = 1.0
        document.analysisCompleted = true
        document.analysisDate = Date()

        // Phase 3: Ready
        document.state = .ready
        XCTAssertTrue(document.analysisCompleted)
        XCTAssertEqual(document.state, .ready)
    }

    // MARK: - Helper Methods

    private func createDataPoint(time: Date) -> FlightDataPoint {
        FlightDataPoint(
            irigTime: time,
            deltaIrig: 0.05,
            normalAccel: 1.0,
            mach: 0.8,
            altitude: 25000,
            rollAngle: 0,
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

    private func createManeuver(type: ManeuverType) -> Maneuver {
        Maneuver(
            id: UUID(),
            type: type,
            startTime: Date(),
            endTime: Date().addingTimeInterval(10),
            startIndex: 0,
            endIndex: 200,
            confidence: 0.85,
            detectionMethod: .ruleBased,
            metrics: nil,
            phases: nil
        )
    }
}
