# FlightCoach Development Roadmap

## Project Overview
FlightCoach is an iOS post-flight analysis tool for T-38 aircraft that combines speech-to-text, Claude AI-powered natural language understanding, and rich telemetry visualization to provide pilots with actionable coaching during debriefing sessions.

**Platform**: iOS/iPadOS (SwiftUI)
**Timeline**: 1-day hackathon (12 hours)
**Primary Focus**: Split-S maneuver analysis
**Tech Stack**: Swift, SwiftUI, Claude API (via MCP), Speech Recognition
**User Workflow**: Import CSV → Auto-analyze → Voice query (see [ARCHITECTURE.md](ARCHITECTURE.md))

**Documentation**:
- [README.md](README.md) - User guide and installation
- [ARCHITECTURE.md](ARCHITECTURE.md) - Technical architecture and design
- This document - Development roadmap and timeline

---

## Phase 1: Foundation (Hours 1-2) ✅ COMPLETE

### 1.1 Data Infrastructure ✅
- **Priority**: CRITICAL
- **Tasks**:
  - [x] Create `FlightDataPoint` model (Codable) for IRIG CSV parsing
  - [x] Implement CSV parser with timestamp handling (DDD:HH:MM:SS.SSSSSS format)
  - [x] Data validation and quality checks (sentinel values, unit standardization)
  - [x] Create `DataLoader` actor with async/await support
  - [x] Implement IRIG timestamp parsing in GMT timezone
- **Output**: `Models/FlightDataPoint.swift`, `Services/DataLoader.swift`
- **Success Criteria**: ✅ Load sample flight data from Files app without errors
- **Tests**: 10/10 DataLoaderTests passing

### 1.2 Project Structure Setup ✅
- **Priority**: CRITICAL
- **Tasks**:
  - [x] Create folder structure:
    - `Models/` - Data models (FlightDataPoint, Maneuver, PerformanceMetrics)
    - `Services/` - Data loading (DataLoader)
    - `ViewModels/` - Observable objects for views
    - `Views/` - SwiftUI views
    - `Utilities/` - Helpers, extensions
    - `Detectors/` - Maneuver detection algorithms
  - [x] Configure Info.plist for document types (CSV support)
- **Output**: Organized Xcode project structure

### 1.3 Document Model Extension ✅
- **Priority**: HIGH
- **Tasks**:
  - [x] Extend `FlightCoachDocument` to handle three-phase workflow (Import → Analyze → Query)
  - [x] Implement state machine for document states: empty → importing → analyzing → ready → error
  - [x] Add flight data storage and serialization (Codable with JSON)
  - [x] Implement document metadata (flight date, pilot info, aircraft tail number)
  - [x] Cache analysis results in document to avoid recomputation
- **Output**: Enhanced `FlightCoachDocument.swift`
- **Reference**: See [ARCHITECTURE.md](ARCHITECTURE.md#document-lifecycle) for state diagram
- **Tests**: 18/18 FlightCoachDocumentTests passing

### 1.4 Core Models ✅
- **Priority**: CRITICAL
- **Tasks**:
  - [x] Create `Maneuver` model with type enum, phases, confidence scoring
  - [x] Create `PerformanceMetrics` model with scoring and deviations
  - [x] Create `ManeuverPhase` model for phase-level analysis
  - [x] Implement computed properties (duration, isAirborne, isInverted)
  - [x] Add sample data for SwiftUI previews
- **Output**: `Models/Maneuver.swift`, `Models/PerformanceMetrics.swift`
- **Tests**: 21/21 model tests passing (FlightDataPointTests + ManeuverTests)

### 1.5 Basic UI ✅
- **Priority**: HIGH
- **Tasks**:
  - [x] Rewrite `ContentView.swift` with state-based navigation
  - [x] Create `ImportPromptView` for empty state
  - [x] Create `AnalysisProgressView` for analyzing state
  - [x] Create `ReadyView` for completed analysis
  - [x] Create `ErrorView` for error handling
  - [x] Implement file importer for CSV selection
- **Output**: Complete state-based UI in `ContentView.swift`
- **Success Criteria**: ✅ Build succeeds, UI responds to document state changes

### Phase 1 Summary
- **Status**: ✅ COMPLETE (100% done)
- **Time Spent**: ~2 hours
- **Test Coverage**: 49/49 tests passing (100%)
- **Files Created**: 8 Swift files + 4 test files + 1 CSV fixture
- **Build Status**: ✅ Clean build, no warnings

---

## Phase 2: Maneuver Detection (Hours 3-6)

### 2.1 Detection Infrastructure
- **Priority**: CRITICAL
- **Tasks**:
  - [ ] Create `Maneuver` model with phase information
  - [ ] Create `ManeuverDetector` protocol
  - [ ] Implement `DetectionResult` with confidence scores
  - [ ] Create `ManeuverDetectionService` coordinator
- **Output**: `Models/Maneuver.swift`, `Services/ManeuverDetectionService.swift`

### 2.2 TIER 1 Detection (Rule-Based, Easy)
- **Priority**: HIGH
- **Target Accuracy**: 85-95%
- **Tasks**:
  - [ ] `TakeoffDetector` - WOW transition (1→0)
  - [ ] `LandingDetector` - WOW transition (0→1)
  - [ ] `LevelFlightDetector` - 1g trim shots
  - [ ] `ClimbDescentDetector` - Steady altitude changes
- **Output**: `Detectors/Tier1/` classes
- **Time Estimate**: 1.5 hours

### 2.3 TIER 2 Detection - SPLIT-S FOCUS
- **Priority**: CRITICAL
- **Target Accuracy**: 75-85%
- **Tasks**:
  - [ ] Create `SplitSDetector` class
  - [ ] Implement three-phase detection:
    - Phase 1: Roll inverted (0° → 150-180°)
    - Phase 2: Pull through (negative g → 3-5g)
    - Phase 3: Recovery (back to 1g, upright)
  - [ ] Add confidence scoring algorithm
  - [ ] Handle edge cases (aborted maneuvers)
  - [ ] Unit tests for detection accuracy
- **Output**: `Detectors/SplitSDetector.swift`
- **Time Estimate**: 2.5 hours
- **Success Criteria**: Detect 80%+ of Split-S with <10% false positives

### 2.4 Manual Override UI
- **Priority**: MEDIUM
- **Tasks**:
  - [ ] Create maneuver list view with manual add/edit
  - [ ] Time range picker for manual selection
  - [ ] Save manual annotations with document
- **Output**: `Views/ManeuverListView.swift`
- **Time Estimate**: 30 minutes

---

## Phase 3: Analysis Engine (Hours 7-8)

### 3.1 Performance Scoring
- **Priority**: CRITICAL
- **Tasks**:
  - [ ] Create `PerformanceAnalyzer` class
  - [ ] Implement Mach stability scoring
  - [ ] Implement g-onset smoothness scoring
  - [ ] Implement recovery timing scoring
  - [ ] Calculate key metrics (std dev, TSM, altitude loss)
- **Output**: `Services/PerformanceAnalyzer.swift`
- **Time Estimate**: 1 hour

### 3.2 Phase Breakdown
- **Priority**: HIGH
- **Tasks**:
  - [ ] Create `PhaseAnalyzer` for Split-S segmentation
  - [ ] Extract per-phase metrics
  - [ ] Identify deviation points
  - [ ] Generate quality assessment text
- **Output**: `Services/PhaseAnalyzer.swift`
- **Time Estimate**: 45 minutes

### 3.3 Comparison Engine
- **Priority**: MEDIUM
- **Tasks**:
  - [ ] Create `ManeuverComparator` class
  - [ ] Side-by-side metrics comparison
  - [ ] Time-series data alignment
  - [ ] Best performer identification
- **Output**: `Services/ManeuverComparator.swift`
- **Time Estimate**: 30 minutes

---

## Phase 4: Visualization (Hours 8-9)

### 4.1 Chart Infrastructure
- **Priority**: CRITICAL
- **Tasks**:
  - [ ] Use Swift Charts framework (iOS 16+)
  - [ ] Create reusable chart components
  - [ ] Implement databand shading
  - [ ] Add annotation markers
- **Output**: `Views/Charts/` components

### 4.2 Core Visualizations
- **Priority**: CRITICAL
- **Tasks**:
  - [ ] `MachControlChart` - with databand and target line
  - [ ] `GLoadingChart` - with phase annotations
  - [ ] `AltitudeLossChart` - with safety margins
  - [ ] `MultiParameterDashboard` - 2x2 grid layout
- **Output**: Individual chart view files
- **Time Estimate**: 1.5 hours

### 4.3 Interactive Features
- **Priority**: MEDIUM
- **Tasks**:
  - [ ] Tap-to-highlight data points
  - [ ] Zoom and pan gestures
  - [ ] Time synchronization across charts
  - [ ] Export chart images
- **Time Estimate**: 30 minutes

---

## Phase 5: Claude AI Integration (Hours 9-10)

### 5.1 MCP Client Setup
- **Priority**: HIGH
- **Tasks**:
  - [ ] Create `MCPClient` for Claude API communication
  - [ ] Implement tool definitions as Swift structs
  - [ ] Handle async/await API calls
  - [ ] Add error handling and retries
- **Output**: `Services/MCPClient.swift`
- **Time Estimate**: 45 minutes

### 5.2 Tool Implementations
- **Priority**: CRITICAL
- **Tools to implement**:
  - [ ] `detect_maneuvers` - Return detected maneuvers as JSON
  - [ ] `analyze_split_s` - Return performance analysis
  - [ ] `visualize_parameter` - Trigger chart generation
  - [ ] `compare_maneuvers` - Return comparison data
- **Output**: `Services/MCPTools/` classes
- **Time Estimate**: 45 minutes

### 5.3 Coaching Recommendations
- **Priority**: MEDIUM
- **Tasks**:
  - [ ] Create `CoachingEngine` class
  - [ ] Implement priority-based improvement suggestions
  - [ ] Add technique reminders from documentation
  - [ ] Generate natural language assessments
- **Output**: `Services/CoachingEngine.swift`
- **Time Estimate**: 30 minutes

---

## Phase 6: Voice Interface (Hours 10-11)

### 6.1 Speech Recognition
- **Priority**: HIGH
- **Tasks**:
  - [ ] Integrate `Speech` framework
  - [ ] Request microphone permissions
  - [ ] Implement live transcription
  - [ ] Add aviation jargon post-processing
  - [ ] Create phonetic corrections dictionary
- **Output**: `Services/SpeechRecognitionService.swift`
- **Time Estimate**: 45 minutes

### 6.2 Voice UI
- **Priority**: HIGH
- **Tasks**:
  - [ ] Create floating microphone button
  - [ ] Show live transcription text
  - [ ] Display processing indicator
  - [ ] Text input fallback option
  - [ ] Query history list
- **Output**: `Views/VoiceQueryView.swift`
- **Time Estimate**: 30 minutes

### 6.3 Query Processing
- **Priority**: HIGH
- **Tasks**:
  - [ ] Create `QueryProcessor` class
  - [ ] Route queries to appropriate tools
  - [ ] Handle ambiguous requests with confirmation
  - [ ] Generate response views
- **Output**: `Services/QueryProcessor.swift`
- **Time Estimate**: 30 minutes

---

## Phase 7: UI/UX Polish (Hours 11-12)

### 7.1 Main Views
- **Priority**: CRITICAL
- **Tasks**:
  - [ ] `HomeView` - Flight data import and overview
  - [ ] `ManeuverDetailView` - Single maneuver analysis
  - [ ] `ComparisonView` - Multi-maneuver comparison
  - [ ] `SettingsView` - Preferences and configuration
- **Output**: Updated `Views/` folder
- **Time Estimate**: 45 minutes

### 7.2 Navigation & Flow
- **Priority**: HIGH
- **Tasks**:
  - [ ] Implement NavigationStack (iOS 16+)
  - [ ] Tab bar for main sections
  - [ ] Deep linking to specific maneuvers
  - [ ] State restoration
- **Time Estimate**: 30 minutes

### 7.3 Demo Preparation
- **Priority**: CRITICAL
- **Tasks**:
  - [ ] Load sample flight data file
  - [ ] Pre-detect maneuvers for demo
  - [ ] Create demo script with queries
  - [ ] Test end-to-end flow
  - [ ] Polish animations and transitions
- **Time Estimate**: 45 minutes

---

## iOS-Specific Considerations

### Platform Features

#### iOS 17+ Features (Optional)
- [ ] Swift Charts enhancements
- [ ] SwiftData for persistent storage (instead of documents)
- [ ] Widget support for quick stats
- [ ] Live Activities for ongoing analysis

#### iPad Optimization
- [ ] Multi-column layout with NavigationSplitView
- [ ] Drag and drop for CSV files
- [ ] External display support for presentations
- [ ] Pencil support for annotations

#### Accessibility
- [ ] VoiceOver support for all views
- [ ] Dynamic Type support
- [ ] High contrast mode
- [ ] Voice Control compatibility

### Data Management

#### Document-Based App
- Current architecture uses `DocumentGroup`
- Each flight session = separate document
- Documents stored in Files app
- Supports iCloud sync automatically

#### Alternative: SwiftData (iOS 17+)
- Persistent database for all flights
- Query and filter across sessions
- Historical performance tracking
- Automatic CloudKit sync

**Recommendation**: Keep document-based for hackathon, consider SwiftData for post-hackathon

---

## Technical Architecture

### MVVM Pattern
```
Models/
├── FlightData.swift          // Core telemetry data
├── Maneuver.swift            // Detected maneuver
├── PerformanceMetrics.swift  // Analysis results
└── FlightSession.swift       // Complete flight metadata

ViewModels/
├── FlightDataViewModel.swift      // Main data coordinator
├── ManeuverAnalysisViewModel.swift // Single maneuver analysis
└── ComparisonViewModel.swift      // Multi-maneuver comparison

Views/
├── HomeView.swift
├── ManeuverDetailView.swift
├── ComparisonView.swift
├── Charts/
│   ├── MachControlChart.swift
│   ├── GLoadingChart.swift
│   └── AltitudeLossChart.swift
└── Components/
    ├── VoiceQueryButton.swift
    ├── ManeuverCard.swift
    └── MetricsGrid.swift

Services/
├── DataLoader.swift
├── ManeuverDetectionService.swift
├── PerformanceAnalyzer.swift
├── MCPClient.swift
├── SpeechRecognitionService.swift
└── CoachingEngine.swift

Detectors/
├── ManeuverDetector.swift (protocol)
├── SplitSDetector.swift
├── TakeoffDetector.swift
└── LandingDetector.swift
```

---

## Dependencies

### Native Frameworks
- **SwiftUI** - UI framework
- **Charts** - Data visualization (iOS 16+)
- **Speech** - Voice recognition
- **Combine** - Reactive programming
- **Foundation** - Data parsing, networking

### Third-Party (via SPM)
- **None required for MVP** - Use native frameworks

### Optional Enhancements
- **Alamofire** - Networking (if complex API needs)
- **SwiftCSV** - CSV parsing helper
- **TipKit** - User onboarding (iOS 17+)

---

## Risk Mitigation Strategies

### High-Risk Areas

#### 1. CSV Parsing Performance (iOS-Specific)
- **Challenge**: Large CSV files may cause memory issues on device
- **Mitigation**:
  - Stream parsing instead of loading entire file
  - Process on background queue
  - Show progress indicator
  - Limit initial load to 10,000 rows, paginate rest

#### 2. Speech Recognition Accuracy
- **Challenge**: Aviation terms not in default vocabulary
- **Mitigation**:
  - Use `SFSpeechRecognizer` with custom vocabulary
  - Post-process transcriptions (mock→Mach)
  - Always show text for confirmation
  - Provide quick-action buttons for common queries

#### 3. Chart Performance
- **Challenge**: Rendering thousands of data points at 20Hz
- **Mitigation**:
  - Downsample data for display (every 5th point)
  - Use Swift Charts' built-in optimization
  - Render on background thread
  - Limit visible time window, allow scrolling

#### 4. Network Latency (Claude API)
- **Challenge**: Query responses may be slow
- **Mitigation**:
  - Show immediate loading state
  - Cache responses locally
  - Implement request cancellation
  - Provide offline mode with pre-computed analysis

---

## Success Criteria

### Minimum Viable Product (MVP)
- [ ] Import IRIG CSV file from Files app
- [ ] Parse and display flight data
- [ ] Detect at least 1 Split-S maneuver (80% accuracy)
- [ ] Calculate 3 performance scores (Mach, g-onset, recovery)
- [ ] Display 2 charts (Mach, g-loading)
- [ ] Accept voice query: "How did I do on my Split-S?"
- [ ] Generate coaching recommendation

### Stretch Goals
- [ ] Detect 3+ maneuver types
- [ ] Full voice interaction for all queries
- [ ] Comparison view for multiple attempts
- [ ] Export PDF debrief report
- [ ] iPad-optimized layout
- [ ] Widget for quick stats

---

## Post-Hackathon Roadmap

### Version 1.1 (Week 2)
- [ ] Additional maneuver types (Wind-Up Turn, Roller Coaster)
- [ ] Historical performance tracking
- [ ] User preferences and settings
- [ ] Tutorial/onboarding flow

### Version 1.2 (Month 1)
- [ ] Multi-pilot support with profiles
- [ ] iCloud sync for documents
- [ ] Export to PDF/CSV
- [ ] Instructor mode with annotations

### Version 2.0 (Month 3)
- [ ] SwiftData migration for persistent storage
- [ ] Apple Watch companion app
- [ ] iPad Pro optimization with multi-window
- [ ] SharePlay for collaborative debrief
- [ ] Vision Pro spatial visualization (future)

### Long-Term Vision
- [ ] Real-time analysis (if live telemetry available)
- [ ] Predictive coaching with ML
- [ ] Multi-aircraft support (F-16, F-35)
- [ ] Integration with flight scheduling systems
- [ ] Instructor dashboard web portal

---

## Testing Strategy

### Unit Tests
- [ ] CSV parser with malformed data
- [ ] Maneuver detection algorithms
- [ ] Performance calculation accuracy
- [ ] Data interpolation logic

### UI Tests
- [ ] File import flow
- [ ] Voice query interaction
- [ ] Chart rendering
- [ ] Navigation between views

### Manual Testing
- [ ] Test with real flight data
- [ ] Validate detection accuracy with domain expert
- [ ] Voice recognition with aviation terminology
- [ ] Performance on older devices (iPhone 12)

---

## Key Performance Targets

### App Performance
- **Launch time**: <2 seconds
- **CSV import**: <5 seconds for typical flight (1-hour at 20Hz = 72,000 rows)
- **Maneuver detection**: <3 seconds
- **Chart rendering**: <1 second
- **Voice query response**: <5 seconds (including API call)

### Memory Usage
- **Target**: <200 MB for typical flight data
- **Maximum**: <500 MB with all visualizations

### Battery Impact
- **Voice recognition**: Moderate drain (limit to 5-minute sessions)
- **Background processing**: Minimal (use efficient algorithms)

---

## Resources & References

### Apple Documentation
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Swift Charts](https://developer.apple.com/documentation/charts)
- [Speech Framework](https://developer.apple.com/documentation/speech)
- [CSV Parsing in Swift](https://developer.apple.com/documentation/foundation/url)

### Key Flight Parameters
- Sampling rate: 20 Hz (0.05s intervals)
- Critical parameter: `NZ_NORMAL_ACCEL` (g-loading)
- Mach target: ±0.02M databand
- G-onset ideal: 2.0-2.5 seconds
- Recovery margin: >1000 ft safety

### External APIs
- Claude API via Anthropic
- Model Context Protocol (MCP) for tool calling

---

**Last Updated**: 2025-11-15
**Version**: 2.0 (iOS/Swift Edition)
**Target Platform**: iOS 16+ / iPadOS 16+
**Xcode Version**: 15.0+
**Swift Version**: 5.9+
