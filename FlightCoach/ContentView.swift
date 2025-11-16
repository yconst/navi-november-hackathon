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

// MARK: - Preview

#Preview {
    ContentView(document: .constant(FlightCoachDocument.sample))
}
