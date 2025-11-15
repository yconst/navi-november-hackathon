# FlightCoach

[![Platform](https://img.shields.io/badge/platform-iOS%2016%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Xcode](https://img.shields.io/badge/Xcode-15.0%2B-blue.svg)](https://developer.apple.com/xcode/)

**FlightCoach** is an iOS post-flight analysis tool for T-38 aircraft that combines AI-powered natural language understanding with rich telemetry visualization to provide pilots with actionable coaching during debriefing sessions.

> Transform your flight data into insights. Ask questions. Get better.

**Documentation**:
- This document - User guide and setup instructions
- [ARCHITECTURE.md](ARCHITECTURE.md) - Technical architecture and design details
- [ROADMAP.md](ROADMAP.md) - Development roadmap and implementation plan
- [context.md](context.md) - Complete project specification

---

## Features

### Core Capabilities

- **Intelligent Maneuver Detection** - Automatically identifies Split-S, Wind-Up Turns, Roller Coasters, and more from IRIG telemetry data
- **Voice-Powered Queries** - Ask natural questions: *"How did I do on my Split-S?"* or *"What can I improve?"*
- **Performance Scoring** - Quantitative assessment of Mach control, g-onset smoothness, and recovery timing
- **Rich Visualizations** - Interactive charts showing Mach, g-loading, altitude, and angle of attack with databands and annotations
- **AI Coaching** - Claude-powered recommendations based on T-38 flight manual techniques
- **Comparison Analysis** - Side-by-side comparison of multiple attempts to track improvement

### Technical Highlights

- **Native iOS/iPadOS** - Built with SwiftUI and Swift Charts for optimal performance
- **Document-Based Architecture** - Each flight session is a separate document with automatic iCloud sync
- **Speech Recognition** - Aviation terminology support with phonetic corrections
- **Offline Capable** - All analysis runs on-device; Claude API used only for coaching insights
- **Real-Time Processing** - Analyzes 20Hz telemetry data (84,000 data points per hour) in seconds

---

## How It Works

FlightCoach follows a simple **three-phase workflow**:

### Phase 1: Import
1. Create a new document or open an existing flight session
2. Select your IRIG CSV file (from Files app, iCloud Drive, or USB device)
3. App streams and parses ~84,000 telemetry data points (takes 5-10 seconds)

### Phase 2: Analyze (Automatic)
1. Detects maneuvers automatically (Split-S, Wind-Up Turns, climbs, etc.)
2. Calculates performance scores (Mach stability, g-onset smoothness, recovery timing)
3. Identifies deviations and generates insights
4. Takes 15-20 seconds, runs in background with progress indicator

### Phase 3: Query (Interactive)
1. Ask questions via voice: *"How did I do on my Split-S?"*
2. Claude AI routes your query to the appropriate analysis tool
3. View visualizations, metrics, and coaching recommendations
4. All analysis happens on-device (fast, private, offline-capable)

### Document-Based Architecture

FlightCoach uses iOS's native document architecture, where each flight session is a separate document stored in the Files app. This provides:
- **Automatic iCloud sync** across your devices
- **Easy sharing** with instructors via standard iOS sharing
- **Multi-window support** on iPad (compare flights side-by-side)
- **Standard file management** using iOS Files app

For technical details, see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Screenshots

*Coming soon - UI development in progress*

---

## Requirements

### Development
- **macOS**: 13.0+ (Ventura or later)
- **Xcode**: 15.0+
- **Swift**: 5.9+

### Runtime
- **iOS**: 16.0+
- **iPadOS**: 16.0+
- **Storage**: 100 MB minimum (varies with flight data)

### External Dependencies
- **Claude API Key** (for AI coaching features) - Get yours at [console.anthropic.com](https://console.anthropic.com)
- **Microphone Access** (for voice queries) - Permission requested on first use

---

## Installation

### Clone the Repository

```bash
git clone https://github.com/yourusername/FlightCoach.git
cd FlightCoach
```

### Open in Xcode

```bash
open FlightCoach.xcodeproj
```

### Configure API Keys

1. Create a `Config.xcconfig` file (not tracked in git):
```bash
cp Config.xcconfig.template Config.xcconfig
```

2. Add your Claude API key:
```
ANTHROPIC_API_KEY = your_api_key_here
```

3. The app will read this at runtime for AI features

### Build and Run

1. Select your target device or simulator (iOS 16+)
2. Press `Cmd+R` or click the Run button
3. Grant microphone permissions when prompted

---

## Usage

### Quick Start

FlightCoach follows the three-phase workflow described in [How It Works](#how-it-works):

#### Phase 1: Import Your Flight Data
1. Launch FlightCoach and create a new document (or open an existing one)
2. Tap **"Import CSV"** when prompted
3. Select your IRIG telemetry file from Files app, iCloud, or USB drive
4. Wait for parsing (~5-10 seconds for 70 minutes of flight data)

#### Phase 2: Automatic Analysis
1. Analysis begins automatically after import
2. Watch the progress indicator as maneuvers are detected
3. Review the detected maneuvers list (Split-S, Wind-Up Turns, etc.)
4. Tap any maneuver card to view detailed performance analysis
5. Analysis completes in 15-20 seconds

#### Phase 3: Interactive Queries
1. Tap the **microphone button** (floating action button)
2. Ask questions naturally:
   - *"How did I do on my Split-S?"*
   - *"Show me the Mach control chart"*
   - *"What can I improve?"*
   - *"Compare my three Split-S attempts"*
3. View Claude's response with visualizations and coaching
4. Explore charts interactively (zoom, pan, tap for details)

**Tip**: All your documents are saved in Files app and sync via iCloud automatically.

### Sample Queries

```
"How did I do on my Split-S?"
"Show me the Mach control for maneuver 2"
"What was my g-onset time?"
"Compare my three Split-S attempts"
"What can I improve?"
"What was my recovery altitude?"
"Show me the altitude loss curve"
```

### Data Format

FlightCoach expects IRIG telemetry CSV files with the following structure:

```csv
IRIG_TIME,EGI_ROLL_ANGLE,EGI_PITCH_ANGLE,NZ_NORMAL_ACCEL,ADC_MACH,GPS_ALTITUDE,...
147:21:25:53.500,2.3,5.1,1.02,0.81,25000,...
147:21:25:53.550,3.1,5.3,1.01,0.81,24998,...
...
```

**Key Parameters**:
- `IRIG_TIME` - Timestamp (DDD:HH:MM:SS.SSSSSS format)
- `NZ_NORMAL_ACCEL` - Normal load factor (g's) **[CRITICAL]**
- `ADC_MACH` - Mach number
- `GPS_ALTITUDE` - Altitude (feet MSL)
- `EGI_ROLL_ANGLE` - Roll angle (degrees)
- `EGI_PITCH_ANGLE` - Pitch angle (degrees)
- Plus 60+ additional parameters (see [context.md](context.md))

**Sampling Rate**: 20 Hz (one sample every 0.05 seconds)

---

## Project Structure

```
FlightCoach/
├── FlightCoach/
│   ├── FlightCoachApp.swift          # App entry point
│   ├── FlightCoachDocument.swift     # Document model
│   ├── ContentView.swift             # Main view
│   │
│   ├── Models/                       # Data models
│   │   ├── FlightData.swift         # Telemetry data
│   │   ├── Maneuver.swift           # Detected maneuver
│   │   └── PerformanceMetrics.swift # Analysis results
│   │
│   ├── ViewModels/                   # View models (MVVM)
│   │   ├── FlightDataViewModel.swift
│   │   └── ManeuverAnalysisViewModel.swift
│   │
│   ├── Views/                        # SwiftUI views
│   │   ├── HomeView.swift
│   │   ├── ManeuverDetailView.swift
│   │   ├── ComparisonView.swift
│   │   └── Charts/                   # Visualization components
│   │       ├── MachControlChart.swift
│   │       ├── GLoadingChart.swift
│   │       └── AltitudeLossChart.swift
│   │
│   ├── Services/                     # Business logic
│   │   ├── DataLoader.swift         # CSV parsing
│   │   ├── ManeuverDetectionService.swift
│   │   ├── PerformanceAnalyzer.swift
│   │   ├── MCPClient.swift          # Claude API client
│   │   └── SpeechRecognitionService.swift
│   │
│   ├── Detectors/                    # Maneuver detection algorithms
│   │   ├── ManeuverDetector.swift   # Protocol
│   │   ├── SplitSDetector.swift     # Split-S detection
│   │   ├── TakeoffDetector.swift
│   │   └── LandingDetector.swift
│   │
│   └── Utilities/                    # Helpers
│       ├── Extensions.swift
│       └── Constants.swift
│
├── FlightCoachTests/                 # Unit tests
├── FlightCoachUITests/               # UI tests
├── context.md                        # Project specification
├── ROADMAP.md                        # Development plan
└── README.md                         # This file
```

---

## Architecture

### Design Pattern: MVVM (Model-View-ViewModel)

```
┌─────────────────────────────────────────────┐
│               Views (SwiftUI)               │
│  HomeView, ManeuverDetailView, Charts      │
└───────────────────┬─────────────────────────┘
                    │ @ObservedObject
                    ↓
┌─────────────────────────────────────────────┐
│            ViewModels (Combine)             │
│  FlightDataViewModel, ManeuverAnalysisVM   │
└───────────────────┬─────────────────────────┘
                    │ async/await
                    ↓
┌─────────────────────────────────────────────┐
│         Services (Business Logic)           │
│  DataLoader, DetectionService, Analyzer    │
└───────────────────┬─────────────────────────┘
                    │
                    ↓
┌─────────────────────────────────────────────┐
│           Models (Data Layer)               │
│  FlightData, Maneuver, PerformanceMetrics  │
└─────────────────────────────────────────────┘
```

### Data Flow

1. **Import**: User selects CSV → `DataLoader` parses → `FlightData` model created
2. **Detection**: `ManeuverDetectionService` runs detectors → `Maneuver` objects created
3. **Analysis**: `PerformanceAnalyzer` calculates scores → `PerformanceMetrics` generated
4. **Query**: User speaks → `SpeechRecognitionService` transcribes → `MCPClient` sends to Claude → Response displayed
5. **Visualization**: ViewModel prepares data → Swift Charts renders → User interacts

---

## Maneuver Detection

FlightCoach uses a **hybrid rule-based + ML approach** for maneuver detection:

### TIER 1: Rule-Based (85-95% Accuracy)
- **Takeoff** - WOW sensor transition (1→0)
- **Landing** - WOW sensor transition (0→1)
- **Level Flight** - Sustained 1g ±0.05 for >10 seconds
- **Climbs/Descents** - Monotonic altitude change

### TIER 2: Hybrid Detection (75-85% Accuracy)
- **Split-S** - Roll inverted → pull through → recovery
  - Phase 1: Roll 0° → 150-180° (2-3 seconds)
  - Phase 2: G-loading 1g → <0g → 3-5g
  - Phase 3: Altitude loss 4000-5000 ft, recovery to 1g
- **Wind-Up Turn** - Sustained bank with increasing g-loading
- **Roller Coaster** - Cyclic 0g ↔ 2g oscillations

### Detection Algorithm (Split-S Example)

```swift
func detectSplitS(in data: [FlightDataPoint]) -> [Maneuver] {
    var candidates: [Maneuver] = []

    // Phase 1: Find inverted segments (|roll| > 150°)
    let invertedSegments = findContinuousSegments(
        where: { abs($0.rollAngle) > 150 },
        minDuration: 1.0
    )

    // Phase 2: Check for high-g pull after inversion
    for segment in invertedSegments {
        let next5Seconds = data[segment.endIndex ..< segment.endIndex + 100]

        if next5Seconds.map(\.normalAccel).max() ?? 0 > 3.0 {
            // Phase 3: Verify altitude loss
            let altitudeLoss = data[segment.startIndex].altitude -
                               next5Seconds.map(\.altitude).min()!

            if altitudeLoss > 3000 {
                candidates.append(Maneuver(
                    type: .splitS,
                    startTime: segment.startTime,
                    confidence: calculateConfidence(segment, next5Seconds)
                ))
            }
        }
    }

    return candidates
}
```

---

## Performance Scoring

### Mach Stability Score (0-10)

```swift
func scoreMachStability(machStdDev: Double) -> Double {
    switch machStdDev {
    case 0..<0.01: return 10.0  // Perfect
    case 0.01..<0.02: return 9.0  // Excellent
    case 0.02..<0.03: return 7.0  // Good
    case 0.03..<0.05: return 5.0  // Acceptable
    default: return max(0, 5.0 - (machStdDev - 0.05) * 20)
    }
}
```

**Target**: ±0.02M databand (e.g., 0.78-0.82M for 0.80M target)

### G-Onset Smoothness Score (0-10)

```swift
func scoreGOnset(onsetTime: Double) -> Double {
    let ideal = 2.5  // seconds from 1g to 5g
    let error = abs(onsetTime - ideal)
    return max(0, 10.0 - error * 3.0)
}
```

**Target**: 2.0-2.5 seconds for smooth onset

### Recovery Timing Score (0-10)

```swift
func scoreRecovery(altitudeMargin: Double) -> Double {
    switch altitudeMargin {
    case 2000...: return 10.0  // Excellent margin
    case 1000..<2000: return 8.0  // Good margin
    case 500..<1000: return 6.0  // Adequate margin
    default: return max(0, 4.0 * altitudeMargin / 500)
    }
}
```

**Target**: >1000 ft above minimum safe altitude

---

## API Integration

### Claude API (via Model Context Protocol)

FlightCoach uses MCP tools to provide structured data to Claude:

```swift
// Example MCP Tool Definition
struct AnalyzeSplitSTool: MCPTool {
    let name = "analyze_split_s"
    let description = "Analyzes a specific Split-S maneuver in detail"

    struct Parameters: Codable {
        let maneuverID: Int
        let comparisonReference: String?
    }

    struct Response: Codable {
        let performanceScores: PerformanceScores
        let keyMetrics: KeyMetrics
        let deviations: [Deviation]
        let qualityAssessment: String
    }

    func execute(params: Parameters) async throws -> Response {
        let maneuver = await fetchManeuver(id: params.maneuverID)
        let analyzer = PerformanceAnalyzer()
        return try await analyzer.analyze(maneuver)
    }
}
```

### Available MCP Tools

1. `detect_maneuvers` - Find all maneuvers in flight data
2. `analyze_split_s` - Deep analysis of specific Split-S
3. `visualize_parameter` - Generate time-series charts
4. `compare_maneuvers` - Side-by-side comparison
5. `identify_improvements` - AI coaching recommendations
6. `calculate_aerodynamics` - CL/CD calculations (advanced)

---

## Development

### Building from Source

```bash
# Clone the repo
git clone https://github.com/yourusername/FlightCoach.git
cd FlightCoach

# Open in Xcode
open FlightCoach.xcodeproj

# Select target device (iOS 16+ simulator or device)
# Press Cmd+B to build
```

### Running Tests

```bash
# Run unit tests
Cmd+U in Xcode

# Or via command line
xcodebuild test -project FlightCoach.xcodeproj -scheme FlightCoach -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Code Style

- **SwiftLint**: Configured for consistent style (see `.swiftlint.yml`)
- **Naming**: Use descriptive names (`machStandardDeviation` not `msd`)
- **Documentation**: Document public APIs with `///` comments
- **MARK**: Use `// MARK: -` for section organization

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/wind-up-turn-detection

# Make changes and commit
git add .
git commit -m "Add Wind-Up Turn detection algorithm"

# Push and create PR
git push origin feature/wind-up-turn-detection
```

---

## Testing

### Unit Tests

Located in `FlightCoachTests/`:

```swift
// Example test
class SplitSDetectorTests: XCTestCase {
    func testDetectsSplitSWithHighConfidence() {
        let detector = SplitSDetector()
        let testData = loadTestFlightData("split_s_sample.csv")

        let maneuvers = detector.detect(in: testData)

        XCTAssertEqual(maneuvers.count, 3)
        XCTAssertGreaterThan(maneuvers[0].confidence, 0.8)
    }
}
```

### UI Tests

Located in `FlightCoachUITests/`:

```swift
func testVoiceQueryFlow() {
    let app = XCUIApplication()
    app.launch()

    // Tap microphone button
    app.buttons["VoiceMicrophone"].tap()

    // Simulate voice input (mocked)
    app.textFields["VoiceQuery"].typeText("How did I do on my Split-S?")

    // Verify response displayed
    XCTAssert(app.staticTexts["ManeuverScore"].exists)
}
```

### Test Coverage Goal

- **Models**: 90%+
- **Services**: 80%+
- **Detectors**: 85%+
- **ViewModels**: 75%+
- **Views**: 50%+ (UI tests)

---

## Performance Optimization

### Memory Management

```swift
// Stream large CSV files instead of loading entirely
func streamCSV(url: URL) async throws -> AsyncStream<FlightDataPoint> {
    AsyncStream { continuation in
        Task {
            guard let stream = InputStream(url: url) else { return }
            stream.open()
            defer { stream.close() }

            // Read line-by-line
            while stream.hasBytesAvailable {
                if let line = readLine(from: stream) {
                    let point = try parse(line)
                    continuation.yield(point)
                }
            }
            continuation.finish()
        }
    }
}
```

### Chart Optimization

```swift
// Downsample for display
func downsample(_ data: [DataPoint], targetCount: Int = 300) -> [DataPoint] {
    guard data.count > targetCount else { return data }
    let step = data.count / targetCount
    return stride(from: 0, to: data.count, by: step).map { data[$0] }
}
```

### Battery Optimization

- Limit speech recognition sessions to 5 minutes
- Use background queues for heavy processing
- Cache API responses to minimize network calls
- Throttle chart updates during pan/zoom gestures

---

## Troubleshooting

### Common Issues

#### CSV Import Fails
**Problem**: "Unable to parse CSV file"
**Solution**:
- Ensure file uses tab-delimited format (not comma)
- Check IRIG timestamp format: `DDD:HH:MM:SS.SSSSSS`
- Verify all required columns present (see Data Format section)

#### No Maneuvers Detected
**Problem**: "No Split-S maneuvers found"
**Solution**:
- Lower confidence threshold in Settings
- Manually tag maneuvers using time range picker
- Verify roll angle data is present and valid
- Check that g-loading exceeds 3.0 during pull

#### Voice Recognition Not Working
**Problem**: Microphone button disabled
**Solution**:
- Grant microphone permission in Settings → FlightCoach
- Restart app after granting permission
- Ensure device not in Silent mode (affects some APIs)
- Use text input fallback if issues persist

#### Claude API Errors
**Problem**: "Unable to fetch coaching recommendations"
**Solution**:
- Verify API key in Config.xcconfig
- Check internet connection
- Review API usage limits at console.anthropic.com
- Analysis works offline; only coaching requires API

---

## Contributing

We welcome contributions! Please follow these guidelines:

### Reporting Bugs

1. Check existing [Issues](https://github.com/yourusername/FlightCoach/issues)
2. Create new issue with:
   - Device and iOS version
   - Steps to reproduce
   - Expected vs actual behavior
   - Screenshots if applicable

### Suggesting Features

1. Open [Discussion](https://github.com/yourusername/FlightCoach/discussions)
2. Describe use case and proposed solution
3. Tag with `enhancement` label

### Pull Requests

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for new functionality
4. Ensure all tests pass (`Cmd+U`)
5. Update documentation
6. Commit with clear message
7. Push and open PR

### Code Review Process

- PRs reviewed within 2-3 business days
- Must pass CI/CD checks
- Requires 1 approval from maintainer
- Squash merge preferred

---

## Roadmap

See [ROADMAP.md](ROADMAP.md) for detailed development plan.

### Version 1.0 (Current - Hackathon MVP)
- ✅ CSV import and parsing
- ✅ Split-S detection
- ✅ Basic visualizations
- ✅ Voice query support
- ✅ Claude integration

### Version 1.1 (Week 2)
- [ ] Wind-Up Turn and Roller Coaster detection
- [ ] Historical performance tracking
- [ ] User preferences
- [ ] Tutorial flow

### Version 1.2 (Month 1)
- [ ] Multi-pilot profiles
- [ ] iCloud sync
- [ ] PDF export
- [ ] Instructor annotations

### Version 2.0 (Month 3)
- [ ] SwiftData migration
- [ ] Apple Watch app
- [ ] iPad Pro multi-window
- [ ] SharePlay collaboration

### Long-Term
- [ ] Vision Pro spatial visualization
- [ ] Multi-aircraft support (F-16, F-35)
- [ ] Real-time analysis
- [ ] Predictive ML coaching

---

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2025 FlightCoach Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Acknowledgments

- **T-38 Flight Manual** - Source of technique guidelines and performance standards
- **Anthropic Claude** - AI coaching engine
- **Apple Swift Charts** - Visualization framework
- **The Swift Community** - For amazing tools and libraries

---

## Contact

**Project Lead**: [Your Name](mailto:your.email@example.com)

**Project Link**: [https://github.com/yourusername/FlightCoach](https://github.com/yourusername/FlightCoach)

**Bug Reports**: [GitHub Issues](https://github.com/yourusername/FlightCoach/issues)

**Discussions**: [GitHub Discussions](https://github.com/yourusername/FlightCoach/discussions)

---

## Support

If you find FlightCoach useful, please consider:

- ⭐ Starring the repository
- 🐛 Reporting bugs
- 💡 Suggesting features
- 🔀 Contributing code
- 📢 Sharing with other pilots

---

**Built with ❤️ for aviators who want to fly better, one maneuver at a time.**

*Blue skies and tailwinds!*
