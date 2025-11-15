//
//  FlightCoachDocument.swift
//  FlightCoach
//
//  Created by Ioannis Chatzikonstantinou on 15/11/25.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var flightCoachDocument: UTType {
        UTType(exportedAs: "com.flightcoach.flight-session")
    }
}

/// Document representing a single flight session
/// Follows three-phase workflow: Import → Analyze → Query
struct FlightCoachDocument: FileDocument {

    // MARK: - Document State

    var state: DocumentState = .empty

    // MARK: - Metadata

    var flightDate: Date?
    var pilotName: String?
    var aircraftTailNumber: String?
    var notes: String?

    // MARK: - Data

    var telemetryData: [FlightDataPoint] = []
    var detectedManeuvers: [Maneuver] = []

    // MARK: - Analysis State

    var analysisCompleted: Bool = false
    var analysisDate: Date?
    var analysisProgress: Double = 0.0

    // MARK: - Computed Properties

    var duration: TimeInterval {
        guard let first = telemetryData.first, let last = telemetryData.last else {
            return 0
        }
        return last.irigTime.timeIntervalSince(first.irigTime)
    }

    var dataPointCount: Int {
        telemetryData.count
    }

    var isEmpty: Bool {
        telemetryData.isEmpty
    }

    // MARK: - File Document

    static var readableContentTypes: [UTType] {
        [.flightCoachDocument, .json]
    }

    static var writableContentTypes: [UTType] {
        [.flightCoachDocument]
    }

    // MARK: - Initializers

    init() {
        self.state = .empty
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let decoded = try decoder.decode(FlightCoachDocument.self, from: data)
            self = decoded
        } catch {
            print("Failed to decode document: \(error)")
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(self)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Document State

enum DocumentState: String, Codable {
    case empty          // No data imported yet
    case importing      // CSV being parsed
    case analyzing      // Maneuver detection running
    case ready          // Ready for queries
    case error          // Import or analysis failed

    var displayName: String {
        switch self {
        case .empty: return "New Flight"
        case .importing: return "Importing..."
        case .analyzing: return "Analyzing..."
        case .ready: return "Ready"
        case .error: return "Error"
        }
    }

    var icon: String {
        switch self {
        case .empty: return "doc.badge.plus"
        case .importing: return "arrow.down.doc"
        case .analyzing: return "brain"
        case .ready: return "checkmark.circle"
        case .error: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Codable

extension FlightCoachDocument: Codable {
    enum CodingKeys: String, CodingKey {
        case state
        case flightDate
        case pilotName
        case aircraftTailNumber
        case notes
        case telemetryData
        case detectedManeuvers
        case analysisCompleted
        case analysisDate
        case analysisProgress
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        state = try container.decode(DocumentState.self, forKey: .state)
        flightDate = try container.decodeIfPresent(Date.self, forKey: .flightDate)
        pilotName = try container.decodeIfPresent(String.self, forKey: .pilotName)
        aircraftTailNumber = try container.decodeIfPresent(String.self, forKey: .aircraftTailNumber)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        telemetryData = try container.decode([FlightDataPoint].self, forKey: .telemetryData)
        detectedManeuvers = try container.decode([Maneuver].self, forKey: .detectedManeuvers)
        analysisCompleted = try container.decode(Bool.self, forKey: .analysisCompleted)
        analysisDate = try container.decodeIfPresent(Date.self, forKey: .analysisDate)
        analysisProgress = try container.decode(Double.self, forKey: .analysisProgress)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(state, forKey: .state)
        try container.encodeIfPresent(flightDate, forKey: .flightDate)
        try container.encodeIfPresent(pilotName, forKey: .pilotName)
        try container.encodeIfPresent(aircraftTailNumber, forKey: .aircraftTailNumber)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(telemetryData, forKey: .telemetryData)
        try container.encode(detectedManeuvers, forKey: .detectedManeuvers)
        try container.encode(analysisCompleted, forKey: .analysisCompleted)
        try container.encodeIfPresent(analysisDate, forKey: .analysisDate)
        try container.encode(analysisProgress, forKey: .analysisProgress)
    }
}

// MARK: - Sample Data

extension FlightCoachDocument {
    static var sample: FlightCoachDocument {
        var doc = FlightCoachDocument()
        doc.state = .ready
        doc.flightDate = Date()
        doc.pilotName = "John Doe"
        doc.aircraftTailNumber = "AF-001"
        doc.telemetryData = [FlightDataPoint.sample]
        doc.detectedManeuvers = [Maneuver.sample]
        doc.analysisCompleted = true
        doc.analysisDate = Date()
        doc.analysisProgress = 1.0
        return doc
    }
}
