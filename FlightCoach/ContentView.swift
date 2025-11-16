//
//  ContentView.swift
//  FlightCoach
//
//  Created by Ioannis Chatzikonstantinou on 15/11/25.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: FlightCoachDocument

    @State private var showingFileImporter = false
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Main content based on document state
                switch document.state {
                case .empty:
                    ImportPromptView(onImportTapped: {
                        showingFileImporter = true
                    })

                case .importing:
                    ProgressView("Importing CSV...")
                        .progressViewStyle(.circular)

                case .analyzing:
                    AnalysisProgressView(progress: document.analysisProgress)

                case .ready:
                    ReadyView(document: document)

                case .error:
                    ErrorView(message: errorMessage ?? "Unknown error")
                }
            }
            .navigationTitle("FlightCoach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Image(systemName: document.state.icon)
                        Text(document.state.displayName)
                            .font(.headline)
                    }
                }

                if document.state == .ready {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            // TODO: Open voice query interface
                        } label: {
                            Image(systemName: "mic.circle.fill")
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.commaSeparatedText, .delimitedText],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }

    // MARK: - File Import Handler

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await importCSV(from: url)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            document.state = .error
        }
    }

    private func importCSV(from url: URL) async {
        document.state = .importing
        isLoading = true

        do {
            // Load CSV data
            let dataLoader = DataLoader()
            let dataPoints = try await dataLoader.loadCSV(from: url)

            // Update document with imported data
            await MainActor.run {
                document.telemetryData = dataPoints
                document.flightDate = dataPoints.first?.irigTime
                document.state = .analyzing
                document.analysisProgress = 0.0
            }

            // Run maneuver detection
            let detectionService = ManeuverDetectionService()
            let maneuvers = await detectionService.detectAllManeuvers(in: dataPoints) { progress in
                Task { @MainActor in
                    document.analysisProgress = progress
                }
            }

            // Update document with results
            await MainActor.run {
                document.detectedManeuvers = maneuvers
                document.analysisCompleted = true
                document.analysisDate = Date()
                document.analysisProgress = 1.0
                document.state = .ready
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                document.state = .error
                isLoading = false
            }
        }
    }
}

// MARK: - Import Prompt View

struct ImportPromptView: View {
    let onImportTapped: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            VStack(spacing: 8) {
                Text("Import Flight Data")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Select an IRIG CSV file to begin analysis")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onImportTapped) {
                Label("Choose CSV File", systemImage: "folder")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: 300)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Label("20Hz telemetry data", systemImage: "waveform")
                Label("84,000 data points per hour", systemImage: "chart.line.uptrend.xyaxis")
                Label("Split-S detection & analysis", systemImage: "arrow.down.right.circle")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Analysis Progress View

struct AnalysisProgressView: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Analyzing Flight Data...")
                .font(.title2)
                .fontWeight(.semibold)

            ProgressView(value: progress, total: 1.0)
                .frame(width: 300)
                .tint(.accentColor)

            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ProgressStepView(
                    title: "Detecting maneuvers",
                    completed: progress > 0.3
                )
                ProgressStepView(
                    title: "Calculating performance metrics",
                    completed: progress > 0.6
                )
                ProgressStepView(
                    title: "Finalizing analysis",
                    completed: progress > 0.9
                )
            }
            .padding(.top)
        }
        .padding()
    }
}

struct ProgressStepView: View {
    let title: String
    let completed: Bool

    var body: some View {
        HStack {
            Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(completed ? .green : .secondary)
            Text(title)
                .foregroundColor(completed ? .primary : .secondary)
        }
        .font(.subheadline)
    }
}

// MARK: - Ready View

struct ReadyView: View {
    let document: FlightCoachDocument

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary Card
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Analysis Complete")
                            .font(.headline)
                        Spacer()
                    }

                    Divider()

                    InfoRow(label: "Data Points", value: "\(document.dataPointCount)")
                    InfoRow(label: "Duration", value: formatDuration(document.duration))
                    InfoRow(label: "Maneuvers", value: "\(document.detectedManeuvers.count)")
                    if let date = document.flightDate {
                        InfoRow(label: "Flight Date", value: formatDate(date))
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Flight Path Visualization
                FlightPathView(dataPoints: document.telemetryData)

                // Maneuvers List
                if !document.detectedManeuvers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Detected Maneuvers")
                            .font(.title3)
                            .fontWeight(.bold)

                        ForEach(document.detectedManeuvers) { maneuver in
                            NavigationLink {
                                ManeuverDetailView(
                                    maneuver: maneuver,
                                    flightStartTime: document.telemetryData.first?.irigTime
                                )
                            } label: {
                                ManeuverRowView(
                                    maneuver: maneuver,
                                    flightStartTime: document.telemetryData.first?.irigTime
                                )
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No maneuvers detected")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("The flight data didn't contain any recognizable maneuvers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .padding()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)m \(seconds)s"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Maneuver Row View

struct ManeuverRowView: View {
    let maneuver: Maneuver
    let flightStartTime: Date?

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: maneuver.type.icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(maneuver.type.color)
                .cornerRadius(10)

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(maneuver.type.displayName)
                    .font(.headline)

                HStack(spacing: 16) {
                    Label(formatTime(maneuver.startTime), systemImage: "clock")
                    Label(formatDuration(maneuver.duration), systemImage: "timer")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Confidence Badge
            VStack(spacing: 2) {
                Text("\(Int(maneuver.confidence * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                Text("conf")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func formatTime(_ time: Date) -> String {
        guard let startTime = flightStartTime else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: time)
        }

        let elapsed = time.timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        return String(format: "%.1fs", duration)
    }
}

// MARK: - Maneuver Detail View

struct ManeuverDetailView: View {
    let maneuver: Maneuver
    let flightStartTime: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: maneuver.type.icon)
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(maneuver.type.color)
                        .cornerRadius(15)

                    VStack(alignment: .leading) {
                        Text(maneuver.type.displayName)
                            .font(.title)
                            .fontWeight(.bold)
                        Text("\(Int(maneuver.confidence * 100))% Confidence")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                Divider()

                // Timing
                VStack(alignment: .leading, spacing: 12) {
                    Text("Timing")
                        .font(.headline)

                    DetailRow(label: "Start Time", value: formatTime(maneuver.startTime))
                    DetailRow(label: "End Time", value: formatTime(maneuver.endTime))
                    DetailRow(label: "Duration", value: String(format: "%.1f seconds", maneuver.duration))
                }

                Divider()

                // Data Range
                VStack(alignment: .leading, spacing: 12) {
                    Text("Data Range")
                        .font(.headline)

                    DetailRow(label: "Start Index", value: "\(maneuver.startIndex)")
                    DetailRow(label: "End Index", value: "\(maneuver.endIndex)")
                    DetailRow(label: "Data Points", value: "\(maneuver.endIndex - maneuver.startIndex + 1)")
                }

                // Phases (if available)
                if let phases = maneuver.phases, !phases.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Phases")
                            .font(.headline)

                        ForEach(phases) { phase in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(phase.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(String(format: "%.1fs", phase.duration))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if !phase.keyMetrics.isEmpty {
                                    ForEach(Array(phase.keyMetrics.keys.sorted()), id: \.self) { key in
                                        if let value = phase.keyMetrics[key] {
                                            DetailRow(
                                                label: key,
                                                value: String(format: "%.2f", value),
                                                small: true
                                            )
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }

                // Detection Method
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Detection Info")
                        .font(.headline)
                    DetailRow(label: "Method", value: maneuver.detectionMethod.rawValue.capitalized)
                }
            }
            .padding()
        }
        .navigationTitle("Maneuver Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatTime(_ time: Date) -> String {
        guard let startTime = flightStartTime else {
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            return formatter.string(from: time)
        }

        let elapsed = time.timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var small: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .font(small ? .caption : .body)
            Spacer()
            Text(value)
                .fontWeight(small ? .regular : .semibold)
                .font(small ? .caption : .body)
        }
    }
}

// MARK: - Maneuver Type Extensions

extension ManeuverType {
    var color: Color {
        switch self {
        case .splitS:
            return .purple
        case .takeoff:
            return .green
        case .landing:
            return .orange
        case .levelFlight:
            return .blue
        case .windUpTurn:
            return .indigo
        case .rollerCoaster:
            return .teal
        case .climb:
            return .mint
        case .descent:
            return .cyan
        case .unknown:
            return .gray
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Import Failed")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Flight Path View

struct FlightPathView: View {
    let dataPoints: [FlightDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flight Path")
                .font(.title3)
                .fontWeight(.bold)

            if hasValidCoordinates {
                VStack(spacing: 4) {
                    Canvas { context, size in
                        drawFlightPath(context: context, size: size)
                    }
                    .frame(height: 300)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    if let stats = coordinateStats {
                        Text("Range: \(String(format: "%.4f", stats.latRange))° lat × \(String(format: "%.4f", stats.lonRange))° lon | \(stats.pointCount) points")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No GPS coordinates available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
    }

    private var hasValidCoordinates: Bool {
        dataPoints.contains { $0.latitude != nil && $0.longitude != nil }
    }

    private var coordinateStats: (latRange: Double, lonRange: Double, pointCount: Int)? {
        let validPoints = dataPoints.compactMap { point -> (Double, Double)? in
            guard let lat = point.latitude, let lon = point.longitude else { return nil }
            return (lat, lon)
        }
        guard !validPoints.isEmpty else { return nil }

        let lats = validPoints.map { $0.0 }
        let lons = validPoints.map { $0.1 }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return nil }

        return (maxLat - minLat, maxLon - minLon, validPoints.count)
    }

    private func drawFlightPath(context: GraphicsContext, size: CGSize) {
        print("=== FLIGHT PATH DEBUG ===")
        print("Canvas size: \(size.width) x \(size.height)")

        // Extract points with valid coordinates and downsample to ~500 points
        let validPoints = dataPoints.compactMap { point -> (Double, Double)? in
            guard let lat = point.latitude, let lon = point.longitude else { return nil }
            return (lat, lon)
        }

        print("Total data points: \(dataPoints.count)")
        print("Valid GPS points: \(validPoints.count)")

        guard !validPoints.isEmpty else {
            print("ERROR: No valid points!")
            return
        }

        // Downsample to reasonable number of points for rendering
        // Use more points for better detail (2000 instead of 500)
        let sampleStride = max(1, validPoints.count / 2000)
        let sampledPoints = Swift.stride(from: 0, to: validPoints.count, by: sampleStride).map { validPoints[$0] }

        print("Sample stride: \(sampleStride)")
        print("Sampled points: \(sampledPoints.count)")

        // Calculate bounds
        let lats = sampledPoints.map { $0.0 }
        let lons = sampledPoints.map { $0.1 }

        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else {
            print("ERROR: Could not calculate bounds!")
            return
        }

        print("Latitude bounds: \(minLat) to \(maxLat)")
        print("Longitude bounds: \(minLon) to \(maxLon)")

        let latRange = maxLat - minLat
        let lonRange = maxLon - minLon

        print("Lat range: \(latRange)°")
        print("Lon range: \(lonRange)°")

        // Add padding
        let padding: CGFloat = 20
        let drawWidth = size.width - 2 * padding
        let drawHeight = size.height - 2 * padding

        // Calculate center point
        let centerLat = (minLat + maxLat) / 2.0

        // Adjust longitude range to account for latitude compression
        // At this latitude, degrees of longitude are shorter than degrees of latitude
        let cosLat = cos(centerLat * .pi / 180.0)
        let adjustedLonRange = lonRange * cosLat

        // Determine which dimension is limiting (maintain aspect ratio)
        let latScale = drawHeight / latRange
        let lonScale = drawWidth / adjustedLonRange
        let scale = min(latScale, lonScale)

        // Calculate actual drawing dimensions
        let actualWidth = CGFloat(adjustedLonRange) * scale
        let actualHeight = CGFloat(latRange) * scale

        // Center the drawing
        let offsetX = (drawWidth - actualWidth) / 2
        let offsetY = (drawHeight - actualHeight) / 2

        // Convert lat/lon to screen coordinates
        func toScreen(_ lat: Double, _ lon: Double) -> CGPoint {
            let x = padding + offsetX + CGFloat((lon - minLon) * cosLat) * scale
            let y = size.height - (padding + offsetY + CGFloat((lat - minLat)) * scale)
            return CGPoint(x: x, y: y)
        }

        // Draw the flight path
        var path = Path()

        if let first = sampledPoints.first {
            path.move(to: toScreen(first.0, first.1))
        }

        for point in sampledPoints.dropFirst() {
            path.addLine(to: toScreen(point.0, point.1))
        }

        // Draw the path with black stroke
        context.stroke(path, with: .color(.black), lineWidth: 2)

        // Draw start point (green)
        if let first = sampledPoints.first {
            let startPoint = toScreen(first.0, first.1)
            context.fill(
                Path(ellipseIn: CGRect(x: startPoint.x - 5, y: startPoint.y - 5, width: 10, height: 10)),
                with: .color(.green)
            )
        }

        // Draw end point (red)
        if let last = sampledPoints.last {
            let endPoint = toScreen(last.0, last.1)
            context.fill(
                Path(ellipseIn: CGRect(x: endPoint.x - 5, y: endPoint.y - 5, width: 10, height: 10)),
                with: .color(.red)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView(document: .constant(FlightCoachDocument.sample))
}
