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
            let dataLoader = DataLoader()
            let dataPoints = try await dataLoader.loadCSV(from: url)

            // Update document
            await MainActor.run {
                document.telemetryData = dataPoints
                document.flightDate = dataPoints.first?.irigTime
                document.state = .analyzing
                document.analysisProgress = 0.3

                // Simulate analysis for now (Phase 2 will implement this)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    document.analysisCompleted = true
                    document.analysisDate = Date()
                    document.analysisProgress = 1.0
                    document.state = .ready
                    isLoading = false
                }
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
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Analysis Complete")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
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

            Text("Tap the microphone to ask questions")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top)
        }
        .padding()
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
