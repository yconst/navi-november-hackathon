# FlightCoach Architecture

## Overview

FlightCoach is a **document-based iOS application** where each document represents a single flight session. The app follows a three-phase workflow: **Import → Analyze → Query**. This architecture leverages SwiftUI's `DocumentGroup` for seamless file management with automatic iCloud sync and iOS Files app integration.

**Key Architectural Principles:**
- Document-centric design (one flight per document)
- Separation of concerns (MVVM pattern)
- Async/await for all heavy operations
- On-device analysis with optional cloud-based AI coaching

---

## Table of Contents

1. [Document-Based Architecture](#document-based-architecture)
2. [Three-Phase Workflow](#three-phase-workflow)
3. [Data Flow](#data-flow)
4. [View Hierarchy](#view-hierarchy)
5. [Component Architecture](#component-architecture)
6. [Data Models](#data-models)
7. [Services Layer](#services-layer)
8. [MCP Tool Integration](#mcp-tool-integration)
9. [State Management](#state-management)
10. [Performance Considerations](#performance-considerations)

---

## Document-Based Architecture

### Why Document-Based?

FlightCoach uses SwiftUI's `DocumentGroup` architecture where:
- **Each document = One flight session**
- Documents are stored in iOS Files app
- Automatic iCloud sync enabled
- Native sharing and collaboration support
- Standard iOS document lifecycle

### Document Structure

```swift
struct FlightCoachDocument: FileDocument {
    // Document metadata
    var flightDate: Date
    var pilotName: String?
    var aircraftTailNumber: String?

    // Raw telemetry data
    var telemetryData: [FlightDataPoint]

    // Analysis results (cached)
    var detectedManeuvers: [Maneuver]
    var analysisCompleted: Bool
    var analysisDate: Date?

    // File format
    static var readableContentTypes: [UTType] { [.flightCoachDocument] }

    init(csvURL: URL) {
        // Import CSV during document creation
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Serialize to disk
    }
}
```

### Document Lifecycle

```
┌─────────────────────────────────────────────────────────┐
│                    Document States                      │
└─────────────────────────────────────────────────────────┘

1. NEW DOCUMENT
   ↓
   [User creates new document]
   ↓
   [Prompted to select CSV file]
   ↓
   [CSV imported and parsed]
   ↓

2. ANALYZING
   ↓
   [Maneuver detection runs]
   ↓
   [Performance metrics calculated]
   ↓
   [Document auto-saved]
   ↓

3. READY
   ↓
   [User can query via voice/text]
   ↓
   [Claude responds with visualizations]
   ↓

4. SAVED
   ↓
   [Document stored in Files app]
   ↓
   [Available for future sessions]
```

---

## Three-Phase Workflow

### Phase 1: Import (Document Creation)

**User Action:** Creates new document → Selects CSV file

```swift
// DocumentGroup presents system file picker
@main
struct FlightCoachApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: FlightCoachDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}

// In ContentView: Present file picker on new document
.fileImporter(
    isPresented: $showingFileImporter,
    allowedContentTypes: [.commaSeparatedText]
) { result in
    switch result {
    case .success(let url):
        await importCSV(from: url)
    case .failure(let error):
        showError(error)
    }
}
```

**Data Flow:**
1. User taps "New Document" or "Import CSV"
2. iOS Files picker presented (supports Files app, iCloud Drive, USB drives)
3. User selects CSV file (e.g., `AirForce_Sortie_Aeromod.csv`)
4. `DataLoader` streams CSV (84K rows × 114 columns)
5. Data parsed into `[FlightDataPoint]` array
6. Document created and auto-saved

**CSV Import Details:**
- **Format**: Tab-delimited or comma-separated
- **Size**: ~70 minutes of flight = 84,258 rows
- **Columns**: 114 parameters (see [Data Models](#data-models))
- **Streaming**: Parse line-by-line to avoid memory issues
- **Validation**: Check for required columns, valid timestamps
- **Progress**: Show progress bar during import (5-10 seconds)

---

### Phase 2: Analyze (Automatic Background Processing)

**Trigger:** Automatically after CSV import completes

```swift
class FlightDataViewModel: ObservableObject {
    @Published var analysisState: AnalysisState = .idle
    @Published var progress: Double = 0.0
    @Published var detectedManeuvers: [Maneuver] = []

    func analyzeFlightData() async {
        analysisState = .analyzing

        // Step 1: Detect maneuvers (3-5 seconds)
        progress = 0.2
        let maneuvers = await detectionService.detectAll(in: telemetryData)

        // Step 2: Analyze each maneuver (2-3 seconds per maneuver)
        progress = 0.5
        for maneuver in maneuvers {
            maneuver.metrics = await analyzer.analyze(maneuver)
        }

        // Step 3: Save results to document
        progress = 1.0
        detectedManeuvers = maneuvers
        analysisState = .completed

        // Document auto-saves via @Binding
    }
}
```

**Analysis Pipeline:**

```
RAW CSV DATA (84K rows)
    ↓
┌────────────────────────────────────┐
│   TIER 1: Rule-Based Detection     │
│   - Takeoff (WOW: 1→0)            │
│   - Landing (WOW: 0→1)            │
│   - Level Flight (1g ±0.05)       │
│   - Climbs/Descents               │
│   Time: ~1 second                  │
└────────────────┬───────────────────┘
                 ↓
┌────────────────────────────────────┐
│   TIER 2: Split-S Detection        │
│   Phase 1: Roll inverted           │
│   Phase 2: Pull through            │
│   Phase 3: Recovery                │
│   Time: ~2-3 seconds               │
└────────────────┬───────────────────┘
                 ↓
┌────────────────────────────────────┐
│   Performance Analysis             │
│   - Mach stability score           │
│   - G-onset smoothness             │
│   - Recovery timing                │
│   - Deviation detection            │
│   Time: ~2 seconds per maneuver    │
└────────────────┬───────────────────┘
                 ↓
┌────────────────────────────────────┐
│   Cache Results in Document        │
│   - Detected maneuvers             │
│   - Performance metrics            │
│   - Visualization data (downsampled)│
└────────────────────────────────────┘
```

**Performance Targets:**
- Import 84K rows: **<5 seconds**
- Detect all maneuvers: **<3 seconds**
- Analyze 5 Split-S maneuvers: **<10 seconds**
- **Total**: <20 seconds from import to ready

---

### Phase 3: Query (Interactive Voice/Text Interface)

**User Action:** Asks questions via voice or text

```swift
// Voice Query Flow
struct VoiceQueryView: View {
    @StateObject var speechService = SpeechRecognitionService()
    @StateObject var queryProcessor = QueryProcessor()

    var body: some View {
        VStack {
            // Microphone button
            Button(action: { speechService.startRecording() }) {
                Image(systemName: speechService.isRecording ? "mic.fill" : "mic")
            }

            // Live transcription
            Text(speechService.transcript)
                .foregroundColor(.secondary)

            // Claude response
            if let response = queryProcessor.response {
                QueryResponseView(response: response)
            }
        }
    }
}
```

**Query Processing Pipeline:**

```
USER SPEAKS
    ↓
┌─────────────────────────────────────┐
│   Speech Recognition                │
│   - SFSpeechRecognizer             │
│   - Aviation jargon correction     │
│   - "mock" → "Mach"                │
│   - "splits" → "Split-S"           │
└─────────────┬───────────────────────┘
              ↓
┌─────────────────────────────────────┐
│   Query Classification              │
│   "How did I do on my Split-S?"    │
│   → Route to: analyze_split_s tool │
└─────────────┬───────────────────────┘
              ↓
┌─────────────────────────────────────┐
│   MCP Client (Claude API)           │
│   - Send query + available tools    │
│   - Claude selects tool             │
│   - Returns structured request     │
└─────────────┬───────────────────────┘
              ↓
┌─────────────────────────────────────┐
│   Tool Execution (On-Device)        │
│   - Fetch maneuver data            │
│   - Calculate metrics              │
│   - Generate charts                │
│   - Return JSON response           │
└─────────────┬───────────────────────┘
              ↓
┌─────────────────────────────────────┐
│   Claude Response Generation        │
│   - Natural language summary        │
│   - Coaching recommendations       │
│   - Technique reminders            │
└─────────────┬───────────────────────┘
              ↓
┌─────────────────────────────────────┐
│   UI Update                         │
│   - Display text response          │
│   - Show charts                    │
│   - Highlight metrics              │
└─────────────────────────────────────┘
```

**Example Queries:**
- *"How did I do on my Split-S?"* → `analyze_split_s(maneuver_id: latest)`
- *"Show me Mach control"* → `visualize_parameter(type: "mach")`
- *"Compare my three attempts"* → `compare_maneuvers(ids: [1,2,3])`
- *"What can I improve?"* → `identify_improvements(maneuver_id: latest)`

---

## Data Flow

### Overall System Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                          iOS App                             │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │              View Layer (SwiftUI)                  │    │
│  │  HomeView | ManeuverDetailView | ComparisonView   │    │
│  │  VoiceQueryView | ChartViews | SettingsView       │    │
│  └──────────────────────┬─────────────────────────────┘    │
│                         │ @ObservedObject                   │
│                         ↓                                    │
│  ┌────────────────────────────────────────────────────┐    │
│  │          ViewModel Layer (Combine)                 │    │
│  │  FlightDataViewModel | ManeuverAnalysisViewModel  │    │
│  │  ComparisonViewModel | VoiceQueryViewModel        │    │
│  └──────────────────────┬─────────────────────────────┘    │
│                         │ async/await                       │
│                         ↓                                    │
│  ┌────────────────────────────────────────────────────┐    │
│  │           Services Layer                           │    │
│  │  DataLoader | ManeuverDetectionService            │    │
│  │  PerformanceAnalyzer | MCPClient                  │    │
│  │  SpeechRecognitionService | QueryProcessor        │    │
│  └──────────────────────┬─────────────────────────────┘    │
│                         │                                    │
│                         ↓                                    │
│  ┌────────────────────────────────────────────────────┐    │
│  │              Data Layer                            │    │
│  │  FlightCoachDocument | FlightData | Maneuver      │    │
│  │  PerformanceMetrics | DetectionResult             │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
└────────────┬─────────────────────────────────┬─────────────┘
             │                                  │
             ↓                                  ↓
    ┌────────────────┐                ┌─────────────────┐
    │  Files App     │                │  Claude API     │
    │  iCloud Drive  │                │  (MCP Protocol) │
    │  Local Storage │                │  Coaching Only  │
    └────────────────┘                └─────────────────┘
```

---

## View Hierarchy

### Complete View Structure

```
FlightCoachApp
│
├── DocumentGroup (SwiftUI built-in)
│   │
│   └── ContentView (Root)
│       │
│       ├── IF document.isEmpty
│       │   └── ImportPromptView
│       │       ├── "Import CSV" button
│       │       └── File picker sheet
│       │
│       ├── IF document.isAnalyzing
│       │   └── AnalysisProgressView
│       │       ├── Progress bar
│       │       ├── Status text
│       │       └── Cancel button
│       │
│       └── IF document.isReady
│           └── TabView (Main Interface)
│               │
│               ├── Tab 1: HomeView
│               │   ├── FlightInfoCard
│               │   │   ├── Date, pilot, aircraft
│               │   │   └── Duration, data points
│               │   ├── ManeuverList
│               │   │   └── ForEach(maneuvers)
│               │   │       └── ManeuverCard
│               │   │           ├── Type icon
│               │   │           ├── Time range
│               │   │           ├── Performance score
│               │   │           └── Tap → ManeuverDetailView
│               │   └── FloatingVoiceButton
│               │       └── Sheet: VoiceQueryView
│               │
│               ├── Tab 2: AnalysisView
│               │   ├── PerformanceSummary
│               │   │   ├── Overall stats
│               │   │   └── Best/worst maneuvers
│               │   ├── ManeuverTypeBreakdown
│               │   │   └── Pie chart
│               │   └── TimelineView
│               │       └── Altitude/Mach over time
│               │
│               ├── Tab 3: ComparisonView
│               │   ├── ManeuverSelectionList
│               │   │   └── Multi-select maneuvers
│               │   ├── ComparisonMetricsTable
│               │   │   └── Side-by-side scores
│               │   └── OverlayChartsView
│               │       ├── Mach overlay
│               │       ├── G-loading overlay
│               │       └── Altitude overlay
│               │
│               └── Tab 4: SettingsView
│                   ├── Pilot profile
│                   ├── Detection thresholds
│                   ├── API key config
│                   └── Export options
│
├── ManeuverDetailView (Navigation Destination)
│   ├── Header
│   │   ├── Maneuver type
│   │   ├── Time range
│   │   └── Share button
│   ├── PerformanceScoreGrid
│   │   ├── Mach stability: 8.5/10
│   │   ├── G-onset: 7.2/10
│   │   ├── Recovery: 9.1/10
│   │   └── Overall: 8.3/10
│   ├── ChartsSection
│   │   ├── MachControlChart
│   │   │   ├── Line chart
│   │   │   ├── Databand shading
│   │   │   └── Excursion annotations
│   │   ├── GLoadingChart
│   │   │   ├── Area chart
│   │   │   ├── Phase markers
│   │   │   └── Peak g annotation
│   │   ├── AltitudeLossChart
│   │   │   ├── Line chart
│   │   │   └── Safety margin
│   │   └── AOAChart
│   │       └── Buffet limit line
│   ├── PhaseBreakdownSection
│   │   ├── Phase 1: Roll inverted
│   │   ├── Phase 2: Pull through
│   │   └── Phase 3: Recovery
│   ├── DeviationsSection
│   │   └── List of issues with timestamps
│   └── CoachingSection
│       ├── Strengths
│       ├── Improvements
│       └── Technique reminders
│
└── VoiceQueryView (Sheet)
    ├── VoiceInputSection
    │   ├── Microphone button (pulsing when active)
    │   ├── Live transcript
    │   └── Text input fallback
    ├── QueryHistoryList
    │   └── Previous queries (tappable)
    ├── QueryResponseView
    │   ├── Claude's text response
    │   ├── Embedded charts (if requested)
    │   ├── Metrics grid (if requested)
    │   └── Navigation links (to detailed views)
    └── SuggestedQueries
        └── Quick-tap common questions
```

### View State Management

```swift
// Root ContentView state machine
enum DocumentState {
    case empty              // No CSV imported yet
    case importing         // CSV being parsed
    case analyzing         // Maneuver detection running
    case ready             // Ready for queries
    case error(String)     // Import or analysis failed
}

struct ContentView: View {
    @Binding var document: FlightCoachDocument
    @State private var state: DocumentState = .empty

    var body: some View {
        switch state {
        case .empty:
            ImportPromptView()
        case .importing:
            ImportProgressView()
        case .analyzing:
            AnalysisProgressView()
        case .ready:
            MainTabView()
        case .error(let message):
            ErrorView(message: message)
        }
    }
}
```

---

## Component Architecture

### Key Components

#### 1. ImportPromptView
**Purpose:** First screen for new documents

```swift
struct ImportPromptView: View {
    @State private var showingFilePicker = false

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            Text("Import Flight Data")
                .font(.title)

            Text("Select an IRIG CSV file to begin analysis")
                .foregroundColor(.secondary)

            Button("Choose CSV File") {
                showingFilePicker = true
            }
            .buttonStyle(.borderedProminent)
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.commaSeparatedText, .tabSeparatedText]
            ) { result in
                handleFileSelection(result)
            }
        }
    }
}
```

#### 2. ManeuverCard
**Purpose:** List item showing maneuver summary

```swift
struct ManeuverCard: View {
    let maneuver: Maneuver

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: maneuver.type.icon)
                .font(.title)
                .foregroundColor(maneuver.scoreColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(maneuver.type.displayName)
                    .font(.headline)

                Text(maneuver.timeRangeFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Score badge
            ScoreBadge(score: maneuver.overallScore)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
```

#### 3. MachControlChart
**Purpose:** Visualization of Mach stability

```swift
import Charts

struct MachControlChart: View {
    let data: [DataPoint]
    let targetMach: Double = 0.80
    let databandWidth: Double = 0.02

    var body: some View {
        Chart {
            // Databand shading
            RectangleMark(
                xStart: .value("Start", data.first!.time),
                xEnd: .value("End", data.last!.time),
                yStart: .value("Lower", targetMach - databandWidth),
                yEnd: .value("Upper", targetMach + databandWidth)
            )
            .foregroundStyle(.green.opacity(0.2))

            // Target line
            RuleMark(y: .value("Target", targetMach))
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(dash: [5, 5]))

            // Actual Mach
            ForEach(data) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("Mach", point.mach)
                )
                .foregroundStyle(.black)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // Excursion annotations
            ForEach(data.filter { $0.isExcursion }) { point in
                PointMark(
                    x: .value("Time", point.time),
                    y: .value("Mach", point.mach)
                )
                .foregroundStyle(.red)
                .annotation {
                    Text("⚠️ \(point.mach, format: .number.precision(.fractionLength(3)))")
                        .font(.caption)
                        .padding(4)
                        .background(.yellow.opacity(0.7))
                        .cornerRadius(4)
                }
            }
        }
        .chartYScale(domain: 0.70...0.90)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisValueLabel {
                    if let seconds = value.as(Double.self) {
                        Text("\(seconds, format: .number.precision(.fractionLength(1)))s")
                    }
                }
            }
        }
    }
}
```

#### 4. VoiceQueryView
**Purpose:** Speech-to-text interface

```swift
struct VoiceQueryView: View {
    @StateObject var speechService = SpeechRecognitionService()
    @StateObject var queryProcessor: QueryProcessor
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 20) {
            // Microphone button
            Button {
                if speechService.isRecording {
                    speechService.stopRecording()
                    processQuery(speechService.transcript)
                } else {
                    speechService.startRecording()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(speechService.isRecording ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)

                    Image(systemName: speechService.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                .scaleEffect(speechService.isRecording ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(), value: speechService.isRecording)
            }

            // Transcript
            Text(speechService.transcript)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()

            Divider()

            // Response
            if isProcessing {
                ProgressView("Thinking...")
            } else if let response = queryProcessor.latestResponse {
                QueryResponseView(response: response)
            }

            // Suggested queries
            if !isProcessing && queryProcessor.latestResponse == nil {
                SuggestedQueriesView { query in
                    processQuery(query)
                }
            }
        }
        .padding()
    }

    func processQuery(_ text: String) async {
        isProcessing = true
        await queryProcessor.process(text)
        isProcessing = false
    }
}
```

---

## Data Models

### Core Data Structures

```swift
// Single telemetry data point (20Hz sampling)
struct FlightDataPoint: Identifiable, Codable {
    let id: UUID

    // Timestamp
    let irigTime: Date          // Parsed from "147:21:25:53.500000"
    let deltaIrig: Double       // Time since last sample (should be 0.05s)

    // Critical parameters
    let normalAccel: Double     // NZ_NORMAL_ACCEL (g's)
    let mach: Double            // ADC_MACH
    let altitude: Double        // GPS_ALTITUDE (feet MSL)
    let rollAngle: Double       // EGI_ROLL_ANGLE (degrees)
    let pitchAngle: Double      // EGI_PITCH_ANGLE (degrees)
    let heading: Double         // EGI_TRUE_HEADING (degrees)

    // Rates
    let rollRate: Double        // EGI_ROLL_RATE_P (deg/s)
    let pitchRate: Double       // EGI_PITCH_RATE_Q (deg/s)
    let yawRate: Double         // EGI_YAW_RATE_R (deg/s)

    // Aerodynamics
    let aoa: Double             // ADC_AOA_CORRECTED (units)
    let airspeed: Double        // ADC_TRUE_AIRSPEED (knots)
    let pressureAltitude: Double // ADC_PRESSURE_ALTITUDE (feet)

    // Engine
    let leftEngineRPM: Double   // EED_LEFT_ENGINE_RPM
    let rightEngineRPM: Double  // EED_RIGHT_ENGINE_RPM

    // Control surfaces
    let stabPos: Double         // STAB_POS
    let speedBrakePos: Double   // SPEED_BRK_POS
    let rudderPos: Double       // RUDDER_POS

    // State
    let weightOnWheels: Bool    // ADC_AIR_GND_WOW (1=ground, 0=air)

    // Plus 100+ additional parameters available
}

// Detected maneuver
struct Maneuver: Identifiable, Codable {
    let id: UUID
    let type: ManeuverType

    // Time range
    let startTime: Date
    let endTime: Date
    var duration: TimeInterval { endTime.timeIntervalSince(startTime) }

    // Data indices (for fast lookup)
    let startIndex: Int
    let endIndex: Int

    // Detection metadata
    let confidence: Double      // 0.0 to 1.0
    let detectionMethod: DetectionMethod

    // Performance metrics (calculated during analysis)
    var metrics: PerformanceMetrics?

    // Phase breakdown (for complex maneuvers like Split-S)
    var phases: [ManeuverPhase]?
}

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
        default: return rawValue.capitalized
        }
    }

    var icon: String {
        switch self {
        case .takeoff: return "airplane.departure"
        case .landing: return "airplane.arrival"
        case .splitS: return "arrow.down.right.circle.fill"
        case .windUpTurn: return "arrow.clockwise.circle.fill"
        default: return "circle.fill"
        }
    }
}

// Performance metrics for a maneuver
struct PerformanceMetrics: Codable {
    // Overall score (0-10)
    let overallScore: Double

    // Component scores
    let machStability: Double       // 0-10
    let gOnsetSmoothness: Double   // 0-10
    let recoveryTiming: Double     // 0-10

    // Key metrics
    let machMean: Double
    let machStdDev: Double
    let machMaxExcursion: Double

    let gMax: Double
    let gMin: Double
    let gOnsetTime: Double         // Seconds from 1g to 5g

    let altitudeLoss: Double       // Feet
    let recoveryAltitude: Double   // Feet MSL
    let timeToMinAltitude: Double  // Seconds

    // Safety margins
    let timeSafetyMargin: Double   // TSM (feet or seconds)
    let minAltitudeMargin: Double  // Above hard deck

    // Deviations
    let deviations: [Deviation]
}

struct Deviation: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let severity: Severity
    let parameter: String
    let value: Double
    let expected: Double
    let deviation: Double
    let issue: String
    let recommendation: String

    enum Severity: String, Codable {
        case minor, moderate, major
    }
}

// Phase within a complex maneuver
struct ManeuverPhase: Identifiable, Codable {
    let id: UUID
    let name: String
    let startTime: Date
    let endTime: Date
    let startIndex: Int
    let endIndex: Int
    let description: String
    let keyMetrics: [String: Double]
}
```

### CSV Column Mapping

From the actual data file (114 columns):

```swift
struct CSVColumnMapping {
    // Map CSV column names to FlightDataPoint properties
    static let mapping: [String: KeyPath<FlightDataPoint, Any>] = [
        "IRIG_TIME": \.irigTime,
        "NZ_NORMAL_ACCEL": \.normalAccel,
        "ADC_MACH": \.mach,
        "GPS_ALTITUDE": \.altitude,
        "EGI_ROLL_ANGLE": \.rollAngle,
        "EGI_PITCH_ANGLE": \.pitchAngle,
        "EGI_TRUE_HEADING": \.heading,
        "EGI_ROLL_RATE_P": \.rollRate,
        "EGI_PITCH_RATE_Q": \.pitchRate,
        "EGI_YAW_RATE_R": \.yawRate,
        "ADC_AOA_CORRECTED": \.aoa,
        "ADC_TRUE_AIRSPEED": \.airspeed,
        "ADC_PRESSURE_ALTITUDE": \.pressureAltitude,
        "EED_LEFT_ENGINE_RPM": \.leftEngineRPM,
        "EED_RIGHT_ENGINE_RPM": \.rightEngineRPM,
        "STAB_POS": \.stabPos,
        "SPEED_BRK_POS": \.speedBrakePos,
        "RUDDER_POS": \.rudderPos,
        "ADC_AIR_GND_WOW": \.weightOnWheels
    ]

    // Critical columns that must be present
    static let requiredColumns = [
        "IRIG_TIME",
        "NZ_NORMAL_ACCEL",
        "ADC_MACH",
        "GPS_ALTITUDE",
        "EGI_ROLL_ANGLE",
        "EGI_PITCH_ANGLE"
    ]
}
```

---

## Services Layer

### DataLoader Service

```swift
class DataLoader {
    // Stream CSV to avoid loading 84K rows into memory at once
    func streamCSV(from url: URL) async throws -> AsyncStream<FlightDataPoint> {
        AsyncStream { continuation in
            Task {
                guard let stream = InputStream(url: url) else {
                    continuation.finish()
                    return
                }

                stream.open()
                defer { stream.close() }

                var lineNumber = 0
                var headers: [String] = []

                while stream.hasBytesAvailable {
                    guard let line = readLine(from: stream) else { continue }

                    if lineNumber == 0 {
                        // Parse headers
                        headers = line.components(separatedBy: ",")
                        validateHeaders(headers)
                    } else {
                        // Parse data row
                        if let point = parseDataPoint(line, headers: headers, lineNumber: lineNumber) {
                            continuation.yield(point)
                        }
                    }

                    lineNumber += 1
                }

                continuation.finish()
            }
        }
    }

    private func parseDataPoint(_ line: String, headers: [String], lineNumber: Int) -> FlightDataPoint? {
        let values = line.components(separatedBy: ",")
        guard values.count == headers.count else { return nil }

        var dataDict: [String: String] = [:]
        for (header, value) in zip(headers, values) {
            dataDict[header] = value
        }

        // Parse IRIG timestamp: "147:21:25:53.500000" → Date
        guard let irigTime = parseIRIGTime(dataDict["IRIG_TIME"] ?? "") else { return nil }

        return FlightDataPoint(
            id: UUID(),
            irigTime: irigTime,
            deltaIrig: Double(dataDict["Delta_Irig"] ?? "0") ?? 0,
            normalAccel: Double(dataDict["NZ_NORMAL_ACCEL"] ?? "0") ?? 0,
            mach: Double(dataDict["ADC_MACH"] ?? "0") ?? 0,
            altitude: Double(dataDict["GPS_ALTITUDE"] ?? "0") ?? 0,
            rollAngle: Double(dataDict["EGI_ROLL_ANGLE"] ?? "0") ?? 0,
            pitchAngle: Double(dataDict["EGI_PITCH_ANGLE"] ?? "0") ?? 0,
            heading: Double(dataDict["EGI_TRUE_HEADING"] ?? "0") ?? 0,
            // ... parse remaining 100+ fields
        )
    }

    private func parseIRIGTime(_ timeString: String) -> Date? {
        // Format: "DDD:HH:MM:SS.SSSSSS"
        // Example: "147:21:25:53.500000"
        let components = timeString.components(separatedBy: ":")
        guard components.count == 4 else { return nil }

        let dayOfYear = Int(components[0]) ?? 0
        let hour = Int(components[1]) ?? 0
        let minute = Int(components[2]) ?? 0
        let secondComponents = components[3].components(separatedBy: ".")
        let second = Int(secondComponents[0]) ?? 0
        let microseconds = Int(secondComponents[1] ?? "0") ?? 0

        // Convert to Date (assuming current year)
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        var dateComponents = DateComponents()
        dateComponents.year = Calendar.current.component(.year, from: Date())
        dateComponents.day = dayOfYear
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = second
        dateComponents.nanosecond = microseconds * 1000

        return calendar.date(from: dateComponents)
    }
}
```

### ManeuverDetectionService

```swift
class ManeuverDetectionService {
    private let detectors: [ManeuverDetector] = [
        TakeoffDetector(),
        LandingDetector(),
        LevelFlightDetector(),
        SplitSDetector(),
        // ... more detectors
    ]

    func detectAll(in data: [FlightDataPoint]) async -> [Maneuver] {
        var allManeuvers: [Maneuver] = []

        for detector in detectors {
            let detected = await detector.detect(in: data)
            allManeuvers.append(contentsOf: detected)
        }

        // Sort by time and remove overlaps
        return resolveOverlaps(allManeuvers)
    }
}

// Split-S Detector implementation
class SplitSDetector: ManeuverDetector {
    func detect(in data: [FlightDataPoint]) async -> [Maneuver] {
        var candidates: [Maneuver] = []

        // Phase 1: Find inverted segments (|roll| > 150°)
        let invertedSegments = findInvertedSegments(data)

        for segment in invertedSegments {
            // Phase 2: Check for high-g pull after inversion
            guard segment.endIndex + 100 < data.count else { continue }
            let next5Seconds = Array(data[segment.endIndex...segment.endIndex + 100])

            let maxG = next5Seconds.map(\.normalAccel).max() ?? 0
            guard maxG > 3.0 else { continue }

            // Phase 3: Verify altitude loss
            let startAltitude = data[segment.startIndex].altitude
            let minAltitude = next5Seconds.map(\.altitude).min() ?? startAltitude
            let altitudeLoss = startAltitude - minAltitude

            guard altitudeLoss > 3000 else { continue }

            // Found a Split-S!
            let maneuver = Maneuver(
                id: UUID(),
                type: .splitS,
                startTime: data[segment.startIndex].irigTime,
                endTime: next5Seconds.last!.irigTime,
                startIndex: segment.startIndex,
                endIndex: segment.endIndex + 100,
                confidence: calculateConfidence(segment, next5Seconds),
                detectionMethod: .ruleBased,
                metrics: nil,
                phases: identifyPhases(data, start: segment.startIndex, end: segment.endIndex + 100)
            )

            candidates.append(maneuver)
        }

        return candidates
    }

    private func findInvertedSegments(_ data: [FlightDataPoint]) -> [(startIndex: Int, endIndex: Int)] {
        var segments: [(Int, Int)] = []
        var currentStart: Int?

        for (index, point) in data.enumerated() {
            let isInverted = abs(point.rollAngle) > 150

            if isInverted && currentStart == nil {
                currentStart = index
            } else if !isInverted && currentStart != nil {
                let duration = TimeInterval(index - currentStart!) * 0.05  // 20Hz = 0.05s
                if duration >= 1.0 {  // At least 1 second inverted
                    segments.append((currentStart!, index - 1))
                }
                currentStart = nil
            }
        }

        return segments
    }
}
```

### MCPClient Service

```swift
class MCPClient {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"

    // Available tools
    private let tools: [MCPTool] = [
        DetectManeuversTool(),
        AnalyzeSplitSTool(),
        VisualizeParameterTool(),
        CompareManeuversTool(),
        IdentifyImprovementsTool()
    ]

    func processQuery(_ query: String, flightData: FlightCoachDocument) async throws -> QueryResponse {
        // Build MCP request
        let request = MCPRequest(
            model: "claude-3-5-sonnet-20241022",
            messages: [
                Message(role: "user", content: query)
            ],
            tools: tools.map { $0.definition },
            maxTokens: 1024
        )

        // Send to Claude API
        let response = try await sendRequest(request)

        // Execute requested tools
        var toolResults: [String: Any] = [:]
        for toolCall in response.toolCalls {
            if let tool = tools.first(where: { $0.name == toolCall.name }) {
                let result = try await tool.execute(
                    parameters: toolCall.parameters,
                    flightData: flightData
                )
                toolResults[toolCall.id] = result
            }
        }

        // Get final response from Claude with tool results
        let finalResponse = try await sendRequestWithToolResults(request, toolResults)

        return QueryResponse(
            text: finalResponse.content,
            visualizations: extractVisualizations(toolResults),
            metrics: extractMetrics(toolResults)
        )
    }
}

// Example MCP Tool
struct AnalyzeSplitSTool: MCPTool {
    let name = "analyze_split_s"
    let description = "Analyzes a specific Split-S maneuver in detail"

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: description,
            inputSchema: [
                "maneuver_id": "integer",
                "comparison_reference": "string?"
            ]
        )
    }

    func execute(parameters: [String: Any], flightData: FlightCoachDocument) async throws -> Any {
        guard let maneuverID = parameters["maneuver_id"] as? Int else {
            throw MCPError.invalidParameters
        }

        let maneuver = flightData.detectedManeuvers[maneuverID]
        let analyzer = PerformanceAnalyzer()
        let metrics = await analyzer.analyze(maneuver, in: flightData.telemetryData)

        return [
            "maneuver_id": maneuverID,
            "type": maneuver.type.rawValue,
            "performance_scores": [
                "mach_stability": metrics.machStability,
                "g_onset_smoothness": metrics.gOnsetSmoothness,
                "recovery_timing": metrics.recoveryTiming,
                "overall": metrics.overallScore
            ],
            "key_metrics": [
                "mach_mean": metrics.machMean,
                "mach_std_dev": metrics.machStdDev,
                "g_max": metrics.gMax,
                "g_onset_time": metrics.gOnsetTime,
                "altitude_loss": metrics.altitudeLoss
            ],
            "deviations": metrics.deviations.map { $0.toJSON() }
        ]
    }
}
```

---

## MCP Tool Integration

### Tool Architecture

```
User Query: "How did I do on my Split-S?"
    ↓
┌──────────────────────────────────────┐
│  SpeechRecognitionService            │
│  Transcribes audio to text           │
└──────────────┬───────────────────────┘
               ↓
┌──────────────────────────────────────┐
│  QueryProcessor                      │
│  Classifies intent                   │
└──────────────┬───────────────────────┘
               ↓
┌──────────────────────────────────────┐
│  MCPClient                           │
│  Sends to Claude with tool defs      │
└──────────────┬───────────────────────┘
               ↓
┌──────────────────────────────────────┐
│  Claude API Response                 │
│  {                                   │
│    "tool_calls": [{                  │
│      "name": "analyze_split_s",      │
│      "parameters": {                 │
│        "maneuver_id": 0              │
│      }                               │
│    }]                                │
│  }                                   │
└──────────────┬───────────────────────┘
               ↓
┌──────────────────────────────────────┐
│  Tool Execution (ON-DEVICE)          │
│  AnalyzeSplitSTool.execute()         │
│  - Fetches maneuver from document    │
│  - Calculates performance metrics    │
│  - Returns structured JSON           │
└──────────────┬───────────────────────┘
               ↓
┌──────────────────────────────────────┐
│  Send Tool Results Back to Claude    │
│  Claude generates natural language   │
│  summary with coaching advice        │
└──────────────┬───────────────────────┘
               ↓
┌──────────────────────────────────────┐
│  UI Update                           │
│  - Display text response             │
│  - Show charts (if requested)        │
│  - Highlight key metrics             │
└──────────────────────────────────────┘
```

### Tool Definitions

```swift
// All available MCP tools
enum MCPToolName: String {
    case detectManeuvers = "detect_maneuvers"
    case analyzeSplitS = "analyze_split_s"
    case visualizeParameter = "visualize_parameter"
    case compareManeuvers = "compare_maneuvers"
    case identifyImprovements = "identify_improvements"
    case calculateAerodynamics = "calculate_aerodynamics"
}

struct ToolDefinition: Codable {
    let name: String
    let description: String
    let inputSchema: [String: String]
}
```

---

## State Management

### View Model Pattern

```swift
@MainActor
class FlightDataViewModel: ObservableObject {
    // Published state
    @Published var document: FlightCoachDocument
    @Published var analysisState: AnalysisState = .idle
    @Published var analysisProgress: Double = 0.0
    @Published var error: Error?

    // Services
    private let dataLoader = DataLoader()
    private let detectionService = ManeuverDetectionService()
    private let analyzer = PerformanceAnalyzer()

    // Import CSV
    func importCSV(from url: URL) async {
        analysisState = .importing

        do {
            // Stream and parse CSV
            var dataPoints: [FlightDataPoint] = []
            for await point in try await dataLoader.streamCSV(from: url) {
                dataPoints.append(point)
                analysisProgress = Double(dataPoints.count) / 84000.0 * 0.3
            }

            document.telemetryData = dataPoints

            // Auto-start analysis
            await analyzeData()

        } catch {
            self.error = error
            analysisState = .failed
        }
    }

    // Analyze flight data
    func analyzeData() async {
        analysisState = .analyzing
        analysisProgress = 0.3

        // Detect maneuvers
        let maneuvers = await detectionService.detectAll(in: document.telemetryData)
        document.detectedManeuvers = maneuvers
        analysisProgress = 0.6

        // Analyze each maneuver
        for (index, var maneuver) in maneuvers.enumerated() {
            let metrics = await analyzer.analyze(
                maneuver,
                in: document.telemetryData
            )
            maneuver.metrics = metrics
            document.detectedManeuvers[index] = maneuver

            analysisProgress = 0.6 + (Double(index + 1) / Double(maneuvers.count)) * 0.4
        }

        document.analysisCompleted = true
        document.analysisDate = Date()
        analysisState = .completed
        analysisProgress = 1.0
    }
}

enum AnalysisState {
    case idle
    case importing
    case analyzing
    case completed
    case failed
}
```

---

## Performance Considerations

### Memory Management

**Challenge:** 84K rows × 114 columns = ~10MB raw data

**Solutions:**
1. **Stream CSV parsing** - Don't load entire file at once
2. **Downsample for visualization** - Show every 5th point (300 points instead of 1500)
3. **Lazy loading** - Only parse required columns initially
4. **Background processing** - Use `Task { }` for heavy operations
5. **Cache results** - Store analysis in document to avoid recomputation

```swift
// Downsample for charts
func downsampleForDisplay(_ data: [FlightDataPoint], targetPoints: Int = 300) -> [FlightDataPoint] {
    guard data.count > targetPoints else { return data }
    let step = data.count / targetPoints
    return stride(from: 0, to: data.count, by: step).map { data[$0] }
}
```

### Battery Optimization

**Speech Recognition Limits:**
- Max 5-minute continuous recording
- Auto-stop after 30 seconds of silence
- Background audio processing disabled

**Network Usage:**
- Only call Claude API for coaching (not for analysis)
- Cache API responses locally
- Provide offline mode with pre-computed insights

### App Launch Performance

**Target:** <2 seconds to ready state

**Optimization:**
- Use lazy loading for document list
- Defer heavy operations until after UI appears
- Show placeholder content immediately

---

## Summary

### Key Architectural Decisions

1. **Document-Based App**: Each flight is a self-contained document with embedded analysis
2. **Three-Phase Workflow**: Import → Analyze → Query (clear, sequential UX)
3. **On-Device Analysis**: All detection and scoring happens locally
4. **Claude for Coaching**: AI used only for natural language responses and recommendations
5. **MVVM Pattern**: Clean separation between UI, business logic, and data
6. **Async/Await**: Modern concurrency for responsive UI
7. **Swift Charts**: Native, performant visualizations

### Technology Stack

- **UI**: SwiftUI (iOS 16+)
- **Charts**: Swift Charts
- **Voice**: Speech framework
- **Data**: Codable, DocumentGroup
- **Concurrency**: async/await, AsyncStream
- **AI**: Claude API via MCP

### Next Steps

See [ROADMAP.md](ROADMAP.md) for implementation timeline and [README.md](README.md) for setup instructions.

---

**Last Updated:** 2025-11-15
**Version:** 1.0
**Author:** FlightCoach Development Team
