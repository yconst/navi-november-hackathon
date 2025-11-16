//
//  DataLoader.swift
//  FlightCoach
//
//  Created by FlightCoach Development Team.
//

import Foundation

/// Service for loading and parsing IRIG telemetry CSV files
actor DataLoader {

    // MARK: - Errors

    enum DataLoaderError: LocalizedError {
        case fileNotFound
        case invalidCSVFormat
        case missingRequiredColumns([String])
        case invalidTimestampFormat(String)
        case parsingFailed(String)

        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "CSV file not found"
            case .invalidCSVFormat:
                return "Invalid CSV format - expected tab or comma-delimited"
            case .missingRequiredColumns(let columns):
                return "Missing required columns: \(columns.joined(separator: ", "))"
            case .invalidTimestampFormat(let format):
                return "Invalid IRIG timestamp format: \(format)"
            case .parsingFailed(let reason):
                return "Parsing failed: \(reason)"
            }
        }
    }

    // MARK: - Required Columns

    private static let requiredColumns = [
        "IRIG_TIME",
        "NZ_NORMAL_ACCEL",
        "ADC_MACH",
        "GPS_ALTITUDE",
        "EGI_ROLL_ANGLE",
        "EGI_PITCH_ANGLE"
    ]

    // MARK: - Public Methods

    /// Load and parse CSV file from URL
    func loadCSV(from url: URL) async throws -> [FlightDataPoint] {
        // Ensure we have access to the file
        guard url.startAccessingSecurityScopedResource() else {
            throw DataLoaderError.fileNotFound
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // Read file contents
        let contents = try String(contentsOf: url, encoding: .utf8)
        let lines = contents.components(separatedBy: .newlines)

        guard lines.count > 1 else {
            throw DataLoaderError.invalidCSVFormat
        }

        // Parse header
        let headerLine = lines[0]
        let headers = parseCSVLine(headerLine)

        // Validate required columns
        try validateHeaders(headers)

        // Create column index map
        let columnMap = createColumnMap(headers)

        // Parse data lines
        var dataPoints: [FlightDataPoint] = []
        dataPoints.reserveCapacity(lines.count - 1)

        for (index, line) in lines.enumerated() {
            // Skip header and empty lines
            guard index > 0 && !line.trimmingCharacters(in: .whitespaces).isEmpty else {
                continue
            }

            do {
                if let dataPoint = try parseDataLine(line, columnMap: columnMap, lineNumber: index) {
                    dataPoints.append(dataPoint)
                }
            } catch {
                print("Warning: Failed to parse line \(index): \(error.localizedDescription)")
                // Continue parsing other lines
            }
        }

        return dataPoints
    }

    // MARK: - Private Methods

    private func parseCSVLine(_ line: String) -> [String] {
        // Simple CSV parser (handles comma-separated values)
        line.components(separatedBy: ",")
    }

    private func validateHeaders(_ headers: [String]) throws {
        let missingColumns = Self.requiredColumns.filter { !headers.contains($0) }
        guard missingColumns.isEmpty else {
            throw DataLoaderError.missingRequiredColumns(missingColumns)
        }
    }

    private func createColumnMap(_ headers: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (index, header) in headers.enumerated() {
            map[header] = index
        }
        return map
    }

    private func parseDataLine(
        _ line: String,
        columnMap: [String: Int],
        lineNumber: Int
    ) throws -> FlightDataPoint? {
        let values = parseCSVLine(line)

        guard values.count == columnMap.count else {
            return nil
        }

        // Parse IRIG timestamp
        guard let irigTimeStr = getValue("IRIG_TIME", from: values, columnMap: columnMap),
              let irigTime = parseIRIGTime(irigTimeStr) else {
            throw DataLoaderError.invalidTimestampFormat(getValue("IRIG_TIME", from: values, columnMap: columnMap) ?? "")
        }

        // Parse all required fields
        let dataPoint = FlightDataPoint(
            irigTime: irigTime,
            deltaIrig: getDoubleValue("Delta_Irig", from: values, columnMap: columnMap) ?? 0.05,
            normalAccel: getDoubleValue("NZ_NORMAL_ACCEL", from: values, columnMap: columnMap) ?? 1.0,
            mach: getDoubleValue("ADC_MACH", from: values, columnMap: columnMap) ?? 0.0,
            altitude: getDoubleValue("GPS_ALTITUDE", from: values, columnMap: columnMap) ?? 0.0,
            rollAngle: getDoubleValue("EGI_ROLL_ANGLE", from: values, columnMap: columnMap) ?? 0.0,
            pitchAngle: getDoubleValue("EGI_PITCH_ANGLE", from: values, columnMap: columnMap) ?? 0.0,
            heading: getDoubleValue("EGI_TRUE_HEADING", from: values, columnMap: columnMap) ?? 0.0,
            rollRate: getDoubleValue("EGI_ROLL_RATE_P", from: values, columnMap: columnMap) ?? 0.0,
            pitchRate: getDoubleValue("EGI_PITCH_RATE_Q", from: values, columnMap: columnMap) ?? 0.0,
            yawRate: getDoubleValue("EGI_YAW_RATE_R", from: values, columnMap: columnMap) ?? 0.0,
            aoa: getDoubleValue("ADC_AOA_CORRECTED", from: values, columnMap: columnMap) ?? 0.0,
            airspeed: getDoubleValue("ADC_TRUE_AIRSPEED", from: values, columnMap: columnMap) ?? 0.0,
            pressureAltitude: getDoubleValue("ADC_PRESSURE_ALTITUDE", from: values, columnMap: columnMap) ?? 0.0,
            computedAirspeed: getDoubleValue("ADC_COMPUTED_AIRSPEED", from: values, columnMap: columnMap) ?? 0.0,
            leftEngineRPM: getDoubleValue("EED_LEFT_ENGINE_RPM", from: values, columnMap: columnMap) ?? 0.0,
            rightEngineRPM: getDoubleValue("EED_RIGHT_ENGINE_RPM", from: values, columnMap: columnMap) ?? 0.0,
            leftFuelFlow: getDoubleValue("LEFT_FUEL_FLOW", from: values, columnMap: columnMap) ?? 0.0,
            rightFuelFlow: getDoubleValue("RIGHT_FUEL_FLOW", from: values, columnMap: columnMap) ?? 0.0,
            stabPos: getDoubleValue("STAB_POS", from: values, columnMap: columnMap) ?? 0.0,
            speedBrakePos: getDoubleValue("SPEED_BRK_POS", from: values, columnMap: columnMap) ?? 0.0,
            rudderPos: getDoubleValue("RUDDER_POS", from: values, columnMap: columnMap) ?? 0.0,
            weightOnWheels: getBoolValue("ADC_AIR_GND_WOW", from: values, columnMap: columnMap) ?? false,
            lateralAccel: getDoubleValue("NY_LATERAL_ACCEL", from: values, columnMap: columnMap) ?? 0.0,
            longitudinalAccel: getDoubleValue("NX_LONG_ACCEL", from: values, columnMap: columnMap) ?? 0.0,
            latitude: parseGPSLatitude(from: values, columnMap: columnMap),
            longitude: parseGPSLongitude(from: values, columnMap: columnMap)
        )

        return dataPoint
    }

    // MARK: - Helper Methods

    private func getValue(_ column: String, from values: [String], columnMap: [String: Int]) -> String? {
        guard let index = columnMap[column], index < values.count else {
            return nil
        }
        return values[index].trimmingCharacters(in: .whitespaces)
    }

    private func getDoubleValue(_ column: String, from values: [String], columnMap: [String: Int]) -> Double? {
        guard let stringValue = getValue(column, from: values, columnMap: columnMap) else {
            return nil
        }
        return Double(stringValue)
    }

    private func getBoolValue(_ column: String, from values: [String], columnMap: [String: Int]) -> Bool? {
        guard let stringValue = getValue(column, from: values, columnMap: columnMap),
              let intValue = Int(stringValue) else {
            return nil
        }
        return intValue == 1
    }

    /// Parse GPS latitude from degrees and minutes format
    /// GPS_LAT_DIRECT: 1=North, 0=South (based on typical GPS encoding)
    /// GPS_LAT_DEG: Degrees (0-90)
    /// GPS_LAT_MIN: Minutes (0-60)
    /// Formula: decimal_degrees = degrees + (minutes / 60)
    private func parseGPSLatitude(from values: [String], columnMap: [String: Int]) -> Double? {
        guard let degrees = getDoubleValue("GPS_LAT_DEG", from: values, columnMap: columnMap),
              let minutes = getDoubleValue("GPS_LAT_MIN", from: values, columnMap: columnMap),
              let direction = getDoubleValue("GPS_LAT_DIRECT", from: values, columnMap: columnMap) else {
            return nil
        }

        var latitude = degrees + (minutes / 60.0)

        // If direction is 0, latitude is South (negative)
        if direction == 0 {
            latitude = -latitude
        }

        return latitude
    }

    /// Parse GPS longitude from degrees and minutes format
    /// GPS_LONG_DIRECT: 1=West, 0=East (based on typical GPS encoding for western hemisphere)
    /// GPS_LONG_DEG: Degrees (0-180)
    /// GPS_LONG_MIN: Minutes (0-60)
    /// Formula: decimal_degrees = degrees + (minutes / 60)
    private func parseGPSLongitude(from values: [String], columnMap: [String: Int]) -> Double? {
        guard let degrees = getDoubleValue("GPS_LONG_DEG", from: values, columnMap: columnMap),
              let minutes = getDoubleValue("GPS_LONG_MIN", from: values, columnMap: columnMap),
              let direction = getDoubleValue("GPS_LONG_DIRECT", from: values, columnMap: columnMap) else {
            return nil
        }

        var longitude = degrees + (minutes / 60.0)

        // If direction is 1, longitude is West (negative)
        // Edwards AFB is in western USA, so longitudes should be negative
        if direction == 1 {
            longitude = -longitude
        }

        return longitude
    }

    /// Parse IRIG timestamp format: "DDD:HH:MM:SS.SSSSSS"
    /// Example: "147:21:25:53.500000"
    private func parseIRIGTime(_ timeString: String) -> Date? {
        let components = timeString.components(separatedBy: ":")
        guard components.count == 4 else { return nil }

        guard let dayOfYear = Int(components[0]),
              let hour = Int(components[1]),
              let minute = Int(components[2]) else {
            return nil
        }

        let secondComponents = components[3].components(separatedBy: ".")
        guard let second = Int(secondComponents[0]) else {
            return nil
        }

        let microseconds = secondComponents.count > 1 ? (Int(secondComponents[1]) ?? 0) : 0

        // Create date from components (assuming current year)
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        var dateComponents = DateComponents()
        dateComponents.year = calendar.component(.year, from: Date())
        dateComponents.day = dayOfYear
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = second
        dateComponents.nanosecond = microseconds * 1000

        return calendar.date(from: dateComponents)
    }
}
