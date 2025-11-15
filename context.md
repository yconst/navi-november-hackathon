# T-38 Split-S Post-Flight Analysis Tool - Project Context Document

## Project Overview

### Objective
Build a **post-flight analysis tool** for T-38 aircraft that uses:
- Speech-to-Text (STT) for pilot voice queries
- MCP (Model Context Protocol) tools for data analysis and visualization
- LLM (Claude) for natural language understanding and coaching
- Rich telemetry data from flight recordings

### Use Case
**Location**: Debriefing room with internet connection  
**Timing**: Post-flight, during data analysis session  
**Users**: Pilots + Instructors reviewing recorded telemetry  
**Goal**: Answer key questions:
- "How did I do in my Split-S?"
- "Can you cite a specific Split-S as guidance for me?"
- "What can I do better in my next attempt?"
- Provide verbal prompts and get back formatted data/visualizations

### Timeline
**1-day hackathon** (12 hours)

---

## Data Structure

### Source Format
IRIG time-series CSV data at **20Hz sampling rate** (0.05s intervals)

### Available Parameters

#### Orientation & Rates
- `EGI_ROLL_ANGLE` - Roll angle (degrees)
- `EGI_PITCH_ANGLE` - Pitch angle (degrees)
- `EGI_TRUE_HEADING` - Heading (degrees)
- `EGI_ROLL_RATE_P` - Roll rate (deg/s)
- `EGI_PITCH_RATE_Q` - Pitch rate (deg/s)
- `EGI_YAW_RATE_R` - Yaw rate (deg/s)

#### Accelerations
- `NZ_NORMAL_ACCEL` - Normal load factor (g's) - **CRITICAL PARAMETER**
- `NX_LONG_ACCEL` - Longitudinal acceleration (g's)
- `NY_LATERAL_ACCEL` - Lateral acceleration (g's)

#### Flight State
- `ADC_MACH` - Mach number
- `ADC_COMPUTED_AIRSPEED` - Calibrated airspeed (KCAS)
- `ADC_TRUE_AIRSPEED` - True airspeed (knots)
- `GPS_ALTITUDE` - GPS altitude (feet MSL)
- `ADC_PRESSURE_ALTITUDE` - Pressure altitude (feet)
- `ADC_AOA_CORRECTED` - Angle of attack (units)

#### Control Surfaces
- `STAB_POS` - Stabilator position
- `SPEED_BRK_POS` - Speed brake position
- `RUD_PED_POS` - Rudder pedal position
- `RUDDER_POS` - Rudder position

#### Engine Data
- `EED_LEFT_ENGINE_RPM` - Left engine RPM (N1)
- `EED_RIGHT_ENGINE_RPM` - Right engine RPM (N1)
- `LEFT_FUEL_FLOW` - Left engine fuel flow
- `RIGHT_FUEL_FLOW` - Right engine fuel flow
- `EED_LEFT_ENGINE_EGT` - Exhaust gas temperature

#### Other
- `ADC_AIR_GND_WOW` - Weight on wheels (0=airborne, 1=ground)
- `IRIG_TIME` - Timestamp (format: DDD:HH:MM:SS.SSSSSS)

---

## Key Maneuvers and Detection Strategies

### TIER 1: Easy Detection (Rule-Based) - 85-95% Accuracy

#### 1. Takeoff
**Signature**:
- `ADC_AIR_GND_WOW`: 1 → 0 (state transition)
- `GPS_ALTITUDE`: increases from ~0
- `AIRSPEED`: increases from 0 to >100 knots
- `NZ_NORMAL_ACCEL`: ~1.0g throughout

**Detection Method**: Simple state transition
**Confidence**: 99%

#### 2. Landing
**Signature**:
- `ADC_AIR_GND_WOW`: 0 → 1 (reverse of takeoff)
- `GPS_ALTITUDE`: decreases to ~0
- `AIRSPEED`: decreases to <60 knots

**Detection Method**: Simple state transition
**Confidence**: 99%

#### 3. 1g Trim Shots (Level Flight)
**Signature**:
- `NZ_NORMAL_ACCEL`: 0.95 < g < 1.05 (sustained >10s)
- `altitude_variance`: < 100 ft
- `PITCH_RATE_Q`: ≈ 0
- `ROLL_RATE_P`: ≈ 0
- `ADC_MACH`: constant ±0.02

**Detection Method**: Statistical stability analysis over sliding window
**Confidence**: 95%

#### 4. Steady Climbs
**Signature**:
- `GPS_ALTITUDE`: steadily increasing
- `NZ_NORMAL_ACCEL`: ~1.0g
- `PITCH_ANGLE`: positive (5-15°)
- `vertical_speed`: > 0 (sustained)

**Detection Method**: Monotonic altitude increase + attitude check
**Confidence**: 90%

#### 5. Steady Descents
**Signature**:
- `GPS_ALTITUDE`: steadily decreasing
- `SPEED_BRK_POS`: often extended
- `PITCH_ANGLE`: negative
- `vertical_speed`: < 0 (sustained)

**Detection Method**: Monotonic altitude decrease
**Confidence**: 90%

---

### TIER 2: Moderate Detection (Hybrid Rule-Based + Validation) - 75-85% Accuracy

#### 6. Split-S (PRIMARY FOCUS)
**Signature**:

**Phase 1 - Roll Inverted**:
- `EGI_ROLL_ANGLE`: 0° → 150-180° (within 2-3s)

**Phase 2 - Pull Through**:
- `PITCH_ANGLE`: positive → negative → positive
- `NZ_NORMAL_ACCEL`: 1g → <0g → 3-5g
- `GPS_ALTITUDE`: rapid loss (4000-5000 ft)

**Phase 3 - Recovery**:
- `EGI_ROLL_ANGLE`: → 0° (upright)
- `NZ_NORMAL_ACCEL`: peak 4-5g, then → 1g

**Key Parameters for Quality Assessment**:
- **Mach Control**: Target ±0.02M from databand center (e.g., 0.78-0.82M for 0.8M target)
- **G-Onset Rate**: 1g to 5g should take 2-3 seconds (smooth)
- **Recovery Altitude**: Minimum altitude should have safe margin (>1000 ft above limit)
- **Time Safety Margin (TSM)**: Difference between available recovery time and required recovery time

**Challenges**:
- Distinguishing from barrel roll or other inverted maneuvers
- Partial/aborted Split-S detection
- Entry/exit point ambiguity

**Detection Method**: Rule-based candidate detection + ML validation
**Rule Confidence**: 80-85%

**Documentation Notes**:
- "Padlocked on Mach" - pilot should maintain constant Mach throughout
- "Mach increasing: Faster aft stick" - correction technique
- "Greatest danger is overspeed, not over-G"
- At constant Mach, altitude change required to reach target g is physics-determined
- Recovery: If dive >75°, better to keep pulling through

#### 7. Wind-Up Turn
**Signature**:

**Phase 1 - Entry**:
- `EGI_ROLL_ANGLE`: 0° → 30-60° (sustained bank)

**Phase 2 - G-Loading Increase**:
- `NZ_NORMAL_ACCEL`: 1g → 2g → 3g → 4g+ (gradual increase)
- `ADC_MACH`: decreasing (due to induced drag)
- `GPS_ALTITUDE`: maintained (±500 ft)

**Phase 3 - Buffet/Termination**:
- `ADC_AOA`: approaching 0.95 units
- Wing rock: increasing lateral oscillations in `ROLL_RATE_P`

**Challenges**:
- Distinguishing from normal sustained turn
- Detecting buffet onset from roll rate oscillations
- Variable g-onset rates

**Detection Method**: Rule-based with g-loading profile analysis
**Confidence**: 75-80%

---

### TIER 3: Hard Detection (ML-Preferred) - 60-75% Accuracy with Rules Alone

#### 8. Roller Coaster
**Signature**:
- `NZ_NORMAL_ACCEL`: 0g ↔ 2g (cyclic, 3-5 cycles)
- `GPS_ALTITUDE`: sinusoidal (±1000 ft variation)
- `ADC_MACH`: target constant (0.78-0.82M)
- `PITCH_ANGLE`: large positive/negative swings
- `PITCH_RATE_Q`: high magnitude oscillations

**Target Profile**:
- Start at 1g trim in center of altitude band
- Target 0g and minimum databand Mach
- Target 0 pitch rate and ~1g passing databand center at target Mach

**Challenges**:
- Distinguishing from turbulence or poor flying
- Mach control quality assessment
- Cycle counting and amplitude variation
- Smooth intentional pattern vs rough unintentional oscillations

**Why ML Helps**: Can learn "smooth, intentional" pattern characteristics

**Rule Confidence**: 60-70%  
**ML Confidence**: 85-90%

#### 9. High-Speed Transonic Maneuvers (1.1M Split-S, Roller Coaster)
**Signature**:
- `ADC_MACH`: >1.0 (supersonic)
- Shock wave effects (not directly measured)
- Center of pressure shifts
- Different control effectiveness
- Wave drag appearance

**Changes from Subsonic** (per documentation):
- More stable (CP shifts aft)
- More stick motion required for target g
- Less pitch change to stay in databand
- Deceleration-induced pitch changes during transonic transition

**Challenges**:
- Shock wave detection must be inferred
- Complex transonic aerodynamics
- Deceleration-induced pitch changes
- Limited labeled examples

**Why ML Helps**: Can learn subtle transonic signature differences

**Rule Confidence**: 55-65%  
**ML Confidence**: 80-85%

---

## Hybrid Detection Strategy (RECOMMENDED APPROACH)

### Architecture: Two-Stage Detection System
```
┌─────────────────────────────────────────────────┐
│         Stage 1: Rule-Based Segmentation        │
│   Fast, deterministic, handles simple cases     │
└────────────┬────────────────────────────────────┘
             │
             ├──> TIER 1 Maneuvers (Takeoff, Landing, 1g Trim)
             │    → Labeled directly, high confidence
             │
             ├──> TIER 2 Maneuvers (Split-S, Wind-Up Turn)
             │    → Candidate detected, send to ML for validation
             │
             └──> TIER 3 Maneuvers (Roller Coaster, Transonic)
                  → Weak candidates, send to ML for classification
                  
┌─────────────────────────────────────────────────┐
│      Stage 2: ML-Based Classification           │
│   Slower, learns nuances, handles ambiguity     │
└─────────────────────────────────────────────────┘
             │
             ├──> Validates TIER 2 candidates
             ├──> Classifies TIER 3 maneuvers
             └──> Assesses maneuver quality scores
```

### Feature Engineering for ML

Extract these features for each detected segment:

**Statistical Features**:
- `g_mean`: Mean normal load factor
- `g_std`: Standard deviation of g-loading
- `g_max`: Maximum g-loading
- `g_min`: Minimum g-loading
- `g_range`: Max - Min g-loading

**Rate Features**:
- `pitch_rate_max`: Maximum absolute pitch rate
- `roll_rate_max`: Maximum absolute roll rate
- `pitch_rate_std`: Pitch rate variability

**Altitude Features**:
- `altitude_loss`: Start altitude - End altitude
- `altitude_variance`: Standard deviation of altitude
- `max_altitude_change_rate`: Maximum vertical speed

**Mach/Speed Features**:
- `mach_std`: Mach stability (lower is better)
- `mach_mean`: Average Mach number
- `mach_max_excursion`: Maximum deviation from mean

**Temporal Features**:
- `duration_seconds`: Length of maneuver
- `zero_crossings`: Number of times g crosses 1.0 (for oscillating maneuvers)

**Spectral Features**:
- `dominant_frequency`: Main frequency in g-loading oscillations (FFT)
- `spectral_entropy`: Complexity measure

**Phase Features** (for complex maneuvers):
- `inverted_time_fraction`: Proportion of time with |roll| > 150°
- `negative_g_time_fraction`: Proportion of time with g < 0

---

## MCP Tools Architecture

### Tool 1: `detect_maneuvers`
**Purpose**: Identify all maneuvers in flight data

**Parameters**:
```json
{
  "maneuver_type": "split-s" | "roller-coaster" | "wind-up-turn" | "all",
  "time_range": "optional ISO 8601 time range",
  "confidence_threshold": 0.7
}
```

**Returns**:
```json
{
  "maneuvers": [
    {
      "id": 1,
      "type": "split-s",
      "start_time": "147:21:25:53.500",
      "end_time": "147:21:26:08.350",
      "duration_seconds": 14.85,
      "entry_altitude": 25000,
      "exit_altitude": 20100,
      "entry_mach": 0.81,
      "min_altitude": 19800,
      "detection_method": "rule-based",
      "confidence": 0.92
    }
  ],
  "summary": {
    "total_maneuvers": 3,
    "by_type": {"split-s": 3}
  }
}
```

**Implementation Notes**:
- Use rule-based detection for TIER 1
- Use hybrid detection for TIER 2/3
- Return confidence scores for all detections

---

### Tool 2: `analyze_split_s`
**Purpose**: Deep analysis of specific Split-S maneuver

**Parameters**:
```json
{
  "maneuver_id": 1,
  "comparison_reference": "optimal" | "previous_attempt" | "instructor_demo" | null
}
```

**Returns**:
```json
{
  "maneuver_id": 1,
  "type": "split-s",
  "performance_scores": {
    "mach_stability": 8.5,
    "g_onset_smoothness": 7.2,
    "recovery_timing": 9.1,
    "overall": 8.3
  },
  "key_metrics": {
    "mach_mean": 0.803,
    "mach_std_dev": 0.018,
    "mach_max_excursion": 0.042,
    "mach_target": 0.80,
    "databand_lower": 0.78,
    "databand_upper": 0.82,
    "g_max": 5.2,
    "g_onset_time": 2.3,
    "altitude_loss": 4900,
    "recovery_altitude": 20100,
    "target_recovery_altitude": 19000,
    "tsm_margin": 1200
  },
  "phases": {
    "roll_inverted": {
      "start_time": "147:21:25:53.500",
      "end_time": "147:21:25:56.200",
      "duration": 2.7,
      "max_roll_angle": 178.5
    },
    "pull_through": {
      "start_time": "147:21:25:56.200",
      "end_time": "147:21:26:04.800",
      "duration": 8.6,
      "min_g": -0.3,
      "max_g": 5.2
    },
    "recovery": {
      "start_time": "147:21:26:04.800",
      "end_time": "147:21:26:08.350",
      "duration": 3.55
    }
  },
  "deviations": [
    {
      "timestamp": "147:21:25:58.200",
      "severity": "moderate",
      "parameter": "ADC_MACH",
      "value": 0.842,
      "expected": 0.800,
      "deviation": 0.042,
      "issue": "Mach excursion above databand",
      "recommendation": "Faster aft stick rate needed during pull initiation"
    }
  ],
  "quality_assessment": "Good execution with minor Mach control issue during pull phase"
}
```

**Calculation Details**:

**Mach Stability Score**:
```
score = 10 - (mach_std_dev / 0.01) * 2
where mach_std_dev < 0.01 → score = 10 (perfect)
      mach_std_dev = 0.05 → score = 0 (poor)
```

**G-Onset Smoothness Score**:
```
g_onset_time = time from 1g to 5g
ideal_time = 2.5 seconds
score = 10 - |g_onset_time - ideal_time| * 3
```

**Recovery Timing Score**:
```
altitude_margin = recovery_altitude - target_recovery_altitude
score = min(10, altitude_margin / 200)
where 2000 ft margin = 10 points
      0 ft margin = 0 points
```

---

### Tool 3: `compare_maneuvers`
**Purpose**: Side-by-side comparison of multiple attempts

**Parameters**:
```json
{
  "maneuver_ids": [1, 2, 3],
  "metrics": ["mach", "g_loading", "altitude", "aoa"],
  "comparison_type": "overlay" | "table"
}
```

**Returns**:
```json
{
  "comparison_summary": {
    "best_overall": 1,
    "best_mach_control": 1,
    "best_g_smoothness": 2,
    "best_recovery": 1
  },
  "detailed_comparison": [
    {
      "maneuver_id": 1,
      "scores": {
        "mach_stability": 8.5,
        "g_smoothness": 7.2,
        "recovery_timing": 9.1,
        "overall": 8.3
      },
      "key_metrics": {
        "mach_std": 0.018,
        "g_onset_time": 2.3,
        "altitude_loss": 4900
      }
    },
    {
      "maneuver_id": 2,
      "scores": {
        "mach_stability": 6.1,
        "g_smoothness": 8.9,
        "recovery_timing": 7.5,
        "overall": 7.5
      },
      "key_metrics": {
        "mach_std": 0.035,
        "g_onset_time": 2.1,
        "altitude_loss": 5200
      }
    }
  ],
  "insights": [
    "Maneuver 1 had the best Mach control with only 0.018 std dev",
    "Maneuver 2 had the smoothest g-onset at 2.1 seconds",
    "Maneuver 1 had the most conservative recovery with 1200ft margin"
  ],
  "time_series_data": {
    "timestamps_normalized": [0, 0.05, 0.10, ...],
    "maneuver_1_mach": [0.81, 0.80, 0.80, ...],
    "maneuver_2_mach": [0.81, 0.79, 0.78, ...],
    "maneuver_1_g": [1.0, 1.0, 0.8, ...],
    "maneuver_2_g": [1.0, 1.1, 0.9, ...]
  }
}
```

---

### Tool 4: `visualize_parameter`
**Purpose**: Generate time-series plots with annotations

**Parameters**:
```json
{
  "maneuver_id": 1,
  "parameters": ["mach", "g_loading", "altitude", "aoa"],
  "show_databand": true,
  "annotate_issues": true,
  "plot_type": "single" | "multi_panel" | "overlay"
}
```

**Returns**:
```json
{
  "plot_type": "multi_panel",
  "format": "base64_png",
  "image_data": "iVBORw0KGgoAAAANS...",
  "plot_config": {
    "panels": [
      {
        "title": "Mach Number vs Time",
        "y_axis": "Mach",
        "databand_upper": 0.82,
        "databand_lower": 0.78,
        "target_value": 0.80,
        "annotations": [
          {
            "time": 12.3,
            "text": "Mach excursion: 0.85M",
            "severity": "warning"
          }
        ]
      },
      {
        "title": "G-Loading vs Time",
        "y_axis": "Normal Load Factor (g)",
        "target_range": [4.5, 5.5],
        "annotations": [
          {
            "time": 8.5,
            "text": "Peak g: 5.2",
            "severity": "info"
          }
        ]
      }
    ]
  },
  "metadata": {
    "generated_at": "2024-11-15T14:23:45Z",
    "duration_seconds": 14.85,
    "resolution": "1200x800"
  }
}
```

**Visualization Guidelines**:

**Mach Control Plot**:
- X-axis: Time (seconds from maneuver start)
- Y-axis: Mach number
- Shaded regions: Databand (e.g., 0.78-0.82M for 0.8M target)
- Target line: Center of databand (0.80M)
- Annotations: Mark excursions with warning symbols
- Color coding: Green (within databand), Yellow (minor excursion), Red (major excursion)

**G-Loading Profile**:
- X-axis: Time (seconds)
- Y-axis: Normal load factor (g's)
- Reference lines: 1g, 0g, 5g
- Shaded regions: Target g-range
- Annotations: Mark key events (roll complete, pull start, peak g, recovery)
- Show g-onset rate (slope from 1g to 5g)

**Altitude Loss Curve**:
- X-axis: Time (seconds)
- Y-axis: Altitude (feet MSL)
- Reference lines: Entry altitude, minimum safe altitude
- Annotation: Total altitude loss, TSM margin
- Color coding: Safe (green), Caution (yellow), Danger (red)

**Multi-Parameter Dashboard**:
```
┌─────────────────────────┬─────────────────────────┐
│  Mach vs Time           │  G-Loading vs Time      │
│  [plot with databand]   │  [plot with phases]     │
│                         │                         │
│  ⚠️  1 excursion        │  ✓ Smooth onset         │
└─────────────────────────┴─────────────────────────┘
┌─────────────────────────┬─────────────────────────┐
│  Altitude vs Time       │  AOA vs Time            │
│  [plot with TSM]        │  [plot with limits]     │
│                         │                         │
│  ✓ Safe recovery        │  Max: 0.94 units        │
└─────────────────────────┴─────────────────────────┘
```

---

### Tool 5: `calculate_aerodynamics`
**Purpose**: Compute CL and CD per documentation formulas

**Parameters**:
```json
{
  "maneuver_id": 1,
  "aircraft_weight": 11500,
  "wing_area": 170,
  "output_points": 100
}
```

**Returns**:
```json
{
  "aerodynamic_data": {
    "cl_values": [0.42, 0.45, 0.51, 0.68, 0.85, 0.87, 0.82, ...],
    "cd_values": [0.028, 0.031, 0.038, 0.052, 0.071, 0.078, 0.069, ...],
    "aoa_values": [0.15, 0.20, 0.30, 0.50, 0.80, 0.94, 0.85, ...],
    "timestamps": ["147:21:25:53.500", "147:21:25:54.000", ...]
  },
  "key_points": {
    "max_cl": {
      "value": 0.87,
      "aoa": 0.94,
      "timestamp": "147:21:26:04.800",
      "phase": "recovery"
    },
    "max_cd": {
      "value": 0.078,
      "timestamp": "147:21:26:04.800",
      "induced_drag_fraction": 0.85
    }
  },
  "drag_polar_data": {
    "cl_range": [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
    "cd_range": [0.025, 0.028, 0.035, 0.048, 0.068, 0.095]
  }
}
```

**Calculation Formulas** (from documentation):

**Coefficient of Lift (CL)**:
```
CL = (2 × nZ × W) / (γ × Pa × M² × S)

where:
  nZ = Normal load factor (from NZ_NORMAL_ACCEL)
  W = Aircraft weight (pounds)
  γ = 1.4 (ratio of specific heats for air)
  Pa = Pressure altitude (from ADC_PRESSURE_ALTITUDE)
  M = Mach number (from ADC_MACH)
  S = Wing reference area (170 sq ft for T-38)
```

**Coefficient of Drag (CD)**:
```
First calculate Drag force:
D = Thrust - (Ps × Weight / V) - W × sin(θ)

Then:
CD = D / (½ × ρ × V² × S)

where:
  Thrust = Engine thrust (from engine model/tables)
  Ps = Specific Excess Power = (1/g)(dV/dt) + dh/dt
  V = True airspeed (from ADC_TRUE_AIRSPEED)
  θ = Flight path angle
  ρ = Air density (from altitude/temperature)
  S = Wing area
```

---

### Tool 6: `identify_improvements`
**Purpose**: AI-driven coaching recommendations

**Parameters**:
```json
{
  "maneuver_id": 1,
  "pilot_experience_level": "student" | "intermediate" | "advanced",
  "focus_areas": ["mach_control", "g_onset", "recovery"] | "all"
}
```

**Returns**:
```json
{
  "overall_assessment": "Good execution with room for improvement in Mach control",
  "strengths": [
    {
      "area": "Recovery Altitude Management",
      "score": 9.1,
      "details": "Excellent altitude awareness. Recovery initiated at 20,100 ft with 1,200 ft safety margin.",
      "keep_doing": "Maintain this conservative approach to recovery timing."
    }
  ],
  "improvements": [
    {
      "priority": 1,
      "area": "Mach Control",
      "current_score": 6.5,
      "target_score": 9.0,
      "issue": "Mach excursion to 0.85M (0.05M above databand) at 12.3 seconds into maneuver",
      "root_cause": "Insufficient aft stick rate during pull initiation",
      "recommendation": "Increase aft stick rate earlier in the pull phase. Aim to be 'padlocked on Mach' per technique guide. When Mach increases, apply faster aft stick.",
      "reference_timestamp": "147:21:25:58.200",
      "technique_tip": "From documentation: 'Mach increasing: Faster aft stick. Mach decreasing: Slower aft stick'",
      "expected_improvement": "Reducing Mach std dev from 0.035 to <0.020 would improve score to 8.5"
    },
    {
      "priority": 2,
      "area": "G-Onset Smoothness",
      "current_score": 7.2,
      "target_score": 9.0,
      "issue": "G-onset from 1g to 5g completed in 2.8 seconds (target: 2.0-2.5s)",
      "root_cause": "Slightly delayed pull initiation",
      "recommendation": "Initiate pull 0.5 seconds earlier after roll complete. This allows more time for smooth g-onset and better Mach control.",
      "expected_improvement": "Target g-onset time of 2.3 seconds would improve score to 9.0"
    }
  ],
  "technique_reminders": [
    "Documentation states: 'At constant Mach, you can't change the altitude change required to get to 5g'",
    "Recovery guideline: 'If dive is >75°, it is better to keep pulling through'",
    "Safety note: 'The greatest danger of the Split-S is overspeed, not over-G'"
  ],
  "comparison_to_standard": {
    "instructor_demo_mach_std": 0.012,
    "your_mach_std": 0.035,
    "gap": "You're 2.9x more variable than standard"
  }
}
```

**Coaching Logic**:

**Priority 1 Issues** (Score <7.0):
- Critical performance deficiencies
- Safety concerns
- Requires immediate attention

**Priority 2 Issues** (Score 7.0-8.5):
- Good but improvable
- Refinement opportunities
- Polish for proficiency

**Priority 3 Issues** (Score 8.5-9.5):
- Minor refinements
- Advanced techniques
- Margin improvement

---

### Tool 7: `export_debrief`
**Purpose**: Generate formatted report

**Parameters**:
```json
{
  "flight_date": "2024-11-15",
  "pilot_name": "Optional",
  "instructor_name": "Optional",
  "maneuvers_to_include": [1, 2, 3],
  "format": "pdf" | "html" | "markdown"
}
```

**Returns**:
```json
{
  "report_url": "https://storage.../debrief_2024-11-15.pdf",
  "format": "pdf",
  "page_count": 8,
  "sections": [
    "executive_summary",
    "flight_profile",
    "maneuver_details",
    "performance_comparison",
    "improvement_recommendations",
    "appendix_data"
  ],
  "generated_at": "2024-11-15T14:30:00Z"
}
```

**Report Structure**:

**Page 1 - Executive Summary**:
- Flight info (date, pilot, aircraft)
- Total maneuvers performed
- Overall performance score
- Key achievements
- Top 3 improvement areas

**Page 2-3 - Flight Profile**:
- Timeline of all maneuvers
- Altitude/Mach profile graph
- Fuel usage
- Duration

**Pages 4-6 - Maneuver Details** (one page per maneuver):
- 4-panel visualization
- Performance scores
- Key metrics table
- Specific recommendations

**Page 7 - Comparison Analysis**:
- Side-by-side comparison of attempts
- Progress tracking (if historical data available)
- Best practices identified

**Page 8 - Appendix**:
- Raw data summary
- Calculation methods
- References to flight manual sections

---

## Voice Interaction Examples

### Example 1: General Overview
**Pilot**: *"How did I do on my Split-S maneuvers today?"*

**System Reasoning**:
1. Call `detect_maneuvers(maneuver_type="split-s")`
2. For each detected Split-S, call `analyze_split_s(maneuver_id=X)`
3. Generate summary and comparison

**Voice Response**:
"You completed 3 Split-S maneuvers today. Your best was attempt #2 with an overall score of 8.7 out of 10. Your Mach control was excellent with only 0.015M standard deviation. Attempt #1 scored 8.3 and attempt #3 scored 7.5. Let me show you the comparison..."

**Visual Display**: Comparison table + bar chart of scores

---

### Example 2: Specific Maneuver Deep-Dive
**Pilot**: *"Show me my second Split-S in detail"*

**System Reasoning**:
1. Call `analyze_split_s(maneuver_id=2)`
2. Call `visualize_parameter(maneuver_id=2, parameters=["mach", "g_loading", "altitude", "aoa"])`

**Voice Response**:
"Your second Split-S started at 25,000 feet at Mach 0.81. You maintained excellent Mach control throughout with only one minor excursion at 12 seconds. The pull-through was smooth with 5.1g peak loading, and recovery was conservative at 20,300 feet, giving you a 1,300 foot safety margin. Here's the detailed trace..."

**Visual Display**: 4-panel plot with annotations

---

### Example 3: Improvement Guidance
**Pilot**: *"What can I do better on my next Split-S?"*

**System Reasoning**:
1. Identify most recent maneuver
2. Call `identify_improvements(maneuver_id=latest, pilot_experience_level="student")`
3. Call `compare_maneuvers(maneuver_ids=[previous_attempts])` to show trends

**Voice Response**:
"Your main improvement area is g-onset rate. In attempt #3, you pulled from 1g to 5g in just 1.4 seconds, which is too rapid for smooth energy management. The documentation recommends 2 to 3 seconds. Look at how attempt #2 had a smoother 2.3-second onset - try to replicate that feel. This will also help your Mach control since rapid pulls tend to cause Mach excursions."

**Visual Display**: G-loading comparison plot highlighting onset rates

---

### Example 4: Comparison Request
**Pilot**: *"Compare my third attempt to the instructor's demo"*

**System Reasoning**:
1. Call `compare_maneuvers(maneuver_ids=[3, instructor_demo_id])`
2. Call `visualize_parameter(plot_type="overlay")` for both maneuvers

**Voice Response**:
"Here's your attempt overlaid with the instructor's reference. Notice how the instructor maintained Mach within plus or minus 0.01M throughout, while yours varied by plus or minus 0.03M. The instructor also started the pull 0.8 seconds earlier, which gave more time for smooth g-onset and better recovery margin. Your recovery altitude was actually better than the demo - 200 feet more conservative - which shows good altitude awareness."

**Visual Display**: Overlay plot with two different colored traces

---

### Example 5: Technical Query
**Pilot**: *"What was my coefficient of lift at the recovery point?"*

**System Reasoning**:
1. Call `calculate_aerodynamics(maneuver_id=X)`
2. Identify recovery timestamp (max g-loading)
3. Extract CL value at that point

**Voice Response**:
"At your recovery point - 5.2g at 20,100 feet - your coefficient of lift was 0.87. This corresponds to an angle of attack of 0.94 units, which is just below the 0.95 buffet limit mentioned in the documentation. You were using nearly all available lift without exceeding limits. Here's your CL versus AOA curve for the entire maneuver..."

**Visual Display**: CL vs AOA plot with recovery point highlighted

---

### Example 6: Quality Assessment
**Pilot**: *"Was my Mach control good enough?"*

**System Reasoning**:
1. Call `analyze_split_s(maneuver_id=latest)` to get Mach metrics
2. Compare to standards (±0.02M databand target)
3. Provide contextualized answer

**Voice Response**:
"Your Mach standard deviation was 0.028M, which is just slightly outside the ideal range of 0.02M or less. You had one excursion to 0.85M at 12.3 seconds, which put you 0.03M above the upper databand limit of 0.82M. This is in the 'acceptable but improvable' range - your score was 7.8 out of 10. Instructor demos typically achieve 0.012M standard deviation. You're close to the standard, just need a bit more precision on the stick inputs during the pull."

**Visual Display**: Mach trace with databand, highlighting the excursion

---

## Key Challenges and Mitigation Strategies

### Challenge 1: Maneuver Detection Algorithm (Biggest Challenge)

**Problem**: Distinguishing intentional maneuvers from turbulence, poor flying, or other similar maneuvers

**Research-Based Solution**: Hybrid rule-based + ML approach
- Use rule-based detection for TIER 1 (high confidence, simple patterns)
- Use ML for TIER 2/3 (complex patterns, quality assessment)
- Bootstrap ML training with rule-based labels

**Time Allocation**: 6-8 hours (50% of hackathon)

**Mitigation Strategies**:
1. **Start Simple**: Implement TIER 1 detectors first (takeoff, landing, trim shots)
2. **Manual Tagging Fallback**: For hackathon demo, allow manual maneuver tagging
3. **Focus on Split-S**: Perfect one maneuver type rather than mediocre detection for all
4. **Use Configuration File**: Create JSON config with approximate start/end times as backup

**Example Simplified Approach**:
```python
# Rule-based candidate detection
def detect_split_s_candidates(data):
    """Find potential Split-S maneuvers"""
    candidates = []
    
    # Look for inverted flight segments
    inverted_mask = (np.abs(data['EGI_ROLL_ANGLE']) > 150)
    inverted_segments = find_continuous_segments(inverted_mask, min_duration=1.0)
    
    for segment in inverted_segments:
        # Check if followed by high-g pull
        next_5_seconds = data[segment.end_idx:segment.end_idx + 100]  # 5s @ 20Hz
        if next_5_seconds['NZ_NORMAL_ACCEL'].max() > 3.0:
            # Check for altitude loss
            altitude_loss = data['GPS_ALTITUDE'].iloc[segment.start_idx] - \
                          next_5_seconds['GPS_ALTITUDE'].min()
            if altitude_loss > 3000:
                candidates.append({
                    'start_idx': segment.start_idx,
                    'confidence': 0.85,
                    'type': 'split-s'
                })
    
    return candidates
```

---

### Challenge 2: MCP Tool Integration

**Problem**: Getting LLM to reliably call correct tools with correct parameters

**Mitigation Strategies**:
1. **Clear Tool Descriptions**: Write detailed docstrings with examples
2. **Parameter Validation**: Implement robust error handling
3. **Conversation State**: Track context across turns
4. **Hardcoded Patterns**: For common queries, use regex patterns as backup

**Example Tool Description**:
```python
def analyze_split_s(maneuver_id: int, comparison_reference: str = None):
    """
    Analyze a specific Split-S maneuver in detail.
    
    Use this tool when the pilot asks about a specific maneuver's performance,
    quality, or wants detailed metrics.
    
    Args:
        maneuver_id: Integer ID of the maneuver (from detect_maneuvers)
        comparison_reference: Optional reference for comparison
            - "optimal": Compare to ideal performance
            - "previous_attempt": Compare to pilot's last Split-S
            - "instructor_demo": Compare to instructor's reference
            - null: No comparison, just analyze this maneuver
    
    Returns:
        Detailed performance analysis including scores, metrics, phases,
        and specific recommendations.
    
    Example queries that should use this tool:
    - "Show me my second Split-S"
    - "How did I do on the Split-S at 25,000 feet?"
    - "Analyze my last Split-S maneuver"
    - "What was wrong with my first attempt?"
    """
    # Implementation...
```

---

### Challenge 3: Data Parsing and Quality

**Problem**: Inconsistent timestamps, missing data, unit ambiguities

**Mitigation Strategies**:
1. **Robust Parser**: Handle multiple timestamp formats
2. **Data Validation**: Check for null/sentinel values
3. **Unit Standardization**: Convert everything to standard units on load
4. **Interpolation**: Fill small gaps (<1 second) with linear interpolation

**Example Data Loading**:
```python
def load_flight_data(csv_path):
    """Load and validate IRIG telemetry data"""
    df = pd.read_csv(csv_path, delimiter='\t')
    
    # Parse IRIG timestamp (DDD:HH:MM:SS.SSSSSS)
    df['timestamp'] = pd.to_datetime(
        df['IRIG_TIME'], 
        format='%j:%H:%M:%S.%f',
        errors='coerce'
    )
    
    # Handle missing/sentinel values
    df = df.replace(-999, np.nan)  # Common sentinel value
    
    # Unit standardization
    df['altitude_ft'] = df['GPS_ALTITUDE']  # Already in feet
    df['mach'] = df['ADC_MACH']  # Already dimensionless
    
    # Quality checks
    assert df['timestamp'].notna().all(), "Invalid timestamps detected"
    assert (df['NZ_NORMAL_ACCEL'] >= -2).all(), "Impossible g-loading detected"
    assert (df['ADC_MACH'] >= 0).all(), "Negative Mach number detected"
    
    # Interpolate small gaps
    df = df.interpolate(method='linear', limit=20)  # Max 1 second gap @ 20Hz
    
    return df
```

---

### Challenge 4: Visualization Performance

**Problem**: Generating high-quality plots quickly

**Mitigation Strategies**:
1. **Pre-compute Templates**: Create plot templates once
2. **Downsample for Display**: Show every 5th point for long traces
3. **Lazy Loading**: Generate plots only when requested
4. **Cache Results**: Store generated plots for repeat queries

**Example Efficient Plotting**:
```python
import matplotlib.pyplot as plt
import matplotlib.patches as patches

def plot_mach_control(maneuver_data, target_mach=0.80, databand_width=0.02):
    """Generate Mach control plot efficiently"""
    
    # Downsample if too many points
    if len(maneuver_data) > 300:
        step = len(maneuver_data) // 300
        plot_data = maneuver_data.iloc[::step]
    else:
        plot_data = maneuver_data
    
    fig, ax = plt.subplots(figsize=(10, 6))
    
    # Time axis (relative to maneuver start)
    time = (plot_data['timestamp'] - plot_data['timestamp'].iloc[0]).dt.total_seconds()
    
    # Databand shading (pre-computed coordinates)
    ax.axhspan(
        target_mach - databand_width, 
        target_mach + databand_width,
        alpha=0.2, color='green', label='Databand'
    )
    
    # Target line
    ax.axhline(target_mach, color='blue', linestyle='--', linewidth=1, label='Target')
    
    # Actual Mach trace
    ax.plot(time, plot_data['ADC_MACH'], color='black', linewidth=2, label='Actual')
    
    # Annotate excursions (pre-computed)
    excursions = plot_data[
        (plot_data['ADC_MACH'] > target_mach + databand_width) |
        (plot_data['ADC_MACH'] < target_mach - databand_width)
    ]
    for idx, row in excursions.iterrows():
        t = (row['timestamp'] - plot_data['timestamp'].iloc[0]).total_seconds()
        ax.annotate(
            f'⚠️ {row["ADC_MACH"]:.3f}M',
            xy=(t, row['ADC_MACH']),
            xytext=(10, 10),
            textcoords='offset points',
            bbox=dict(boxstyle='round', fc='yellow', alpha=0.7),
            arrowprops=dict(arrowstyle='->', color='red')
        )
    
    ax.set_xlabel('Time (seconds)', fontsize=12)
    ax.set_ylabel('Mach Number', fontsize=12)
    ax.set_title('Mach Control During Split-S', fontsize=14, fontweight='bold')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # Convert to base64 for web display
    import io
    import base64
    
    buf = io.BytesIO()
    fig.savefig(buf, format='png', dpi=100, bbox_inches='tight')
    buf.seek(0)
    img_base64 = base64.b64encode(buf.read()).decode('utf-8')
    plt.close(fig)
    
    return img_base64
```

---

### Challenge 5: Voice Interface Reliability

**Problem**: STT accuracy with aviation jargon

**Mitigation Strategies**:
1. **Custom Vocabulary**: Train STT with aviation terms
2. **Phonetic Alternatives**: Recognize "mock" → "Mach", "splits" → "Split-S"
3. **Confirmation Prompts**: "Did you mean Split-S maneuver #2?"
4. **Text Fallback**: Allow typed queries as backup
5. **Button Shortcuts**: Provide quick-access buttons for common queries

**Example STT Post-Processing**:
```python
def clean_aviation_speech(transcribed_text):
    """Correct common STT errors with aviation terms"""
    corrections = {
        'mock': 'Mach',
        'mock number': 'Mach number',
        'splits': 'Split-S',
        'split ess': 'Split-S',
        'ay oh ay': 'AOA',
        'a o a': 'AOA',
        'G loading': 'g-loading',
        'jee loading': 'g-loading',
        'altitude MSL': 'altitude',
        'tree thousand': 'three thousand'
    }
    
    cleaned = transcribed_text
    for wrong, right in corrections.items():
        cleaned = cleaned.replace(wrong, right)
    
    return cleaned
```

---

### Challenge 6: Domain Knowledge Translation

**Problem**: Encoding flight test expertise into code

**Mitigation Strategies**:
1. **Partner with Domain Expert**: Have flight test instructor on team
2. **Extract from Documentation**: Mine provided PDFs for rules
3. **Conservative Thresholds**: Use wide margins for safety
4. **Explicit Citations**: Reference documentation in recommendations

**Key Domain Knowledge Extracted**:

**Split-S Technique** (from documentation):
- "Padlocked on Mach" - maintain constant Mach throughout
- "Mach increasing: Faster aft stick"
- "Mach decreasing: Slower aft stick"
- "G onset rate determined by physics for constant Mach"
- "Greatest danger is overspeed, not over-G"
- "If dive is >75°, better to keep pulling through"

**Quality Standards**:
- Mach stability: ±0.02M from target (excellent), ±0.05M (acceptable)
- G-onset time: 2.0-2.5 seconds ideal
- Recovery altitude: >1000 ft safety margin
- AOA limit: 0.95 units (buffet onset)

**Scoring Rubric** (synthesized from documentation):
```python
def score_split_s_quality(metrics):
    """Score Split-S from 0-10 based on documentation standards"""
    scores = {}
    
    # Mach Control (Documentation: "padlocked on Mach")
    if metrics['mach_std'] < 0.01:
        scores['mach'] = 10.0
    elif metrics['mach_std'] < 0.02:
        scores['mach'] = 9.0
    elif metrics['mach_std'] < 0.03:
        scores['mach'] = 7.0
    elif metrics['mach_std'] < 0.05:
        scores['mach'] = 5.0
    else:
        scores['mach'] = max(0, 5.0 - (metrics['mach_std'] - 0.05) * 20)
    
    # G-Onset Smoothness (Documentation: "g onset rate determined by physics")
    ideal_onset_time = 2.5  # seconds from 1g to 5g
    onset_error = abs(metrics['g_onset_time'] - ideal_onset_time)
    scores['g_onset'] = max(0, 10.0 - onset_error * 3.0)
    
    # Recovery Timing (Documentation: TSM - Time Safety Margin)
    altitude_margin = metrics['recovery_altitude'] - metrics['min_safe_altitude']
    if altitude_margin > 2000:
        scores['recovery'] = 10.0
    elif altitude_margin > 1000:
        scores['recovery'] = 8.0
    elif altitude_margin > 500:
        scores['recovery'] = 6.0
    else:
        scores['recovery'] = max(0, 4.0 * altitude_margin / 500)
    
    # Overall
    scores['overall'] = (scores['mach'] * 0.4 + 
                        scores['g_onset'] * 0.3 + 
                        scores['recovery'] * 0.3)
    
    return scores
```

---

## Implementation Timeline (12-Hour Hackathon)

### Hours 1-2: Foundation
- **Data Loading & Parsing**
  - CSV parser for IRIG format