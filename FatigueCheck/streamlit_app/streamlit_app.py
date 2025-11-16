import streamlit as st
import cv2
import mediapipe as mp
import numpy as np
import threading
import base64
import time
from collections import deque

# ==============================
# CONFIGURATION - Improved Defaults
# ==============================
# EAR_THRESHOLD: Lower = more sensitive (0.20-0.30 typical range)
# Research shows: Normal eyes open = 0.25-0.35, Closed = 0.15-0.20
DEFAULT_EAR_THRESHOLD = 0.22  # More sensitive than 0.25
DEFAULT_CONSEC_FRAMES = 15    # ~1 second at 15fps (was 20 = ~1.3s)

# Baseline calibration for individual users
BASELINE_SAMPLES = 30  # Number of frames to collect for baseline

# ==============================
# UTILITIES
# ==============================
def euclidean(p1, p2):
    return np.linalg.norm(np.array(p1) - np.array(p2))

def calculate_ear(landmarks, eye_indices):
    p1, p2 = landmarks[eye_indices[1]], landmarks[eye_indices[5]]
    p3, p4 = landmarks[eye_indices[2]], landmarks[eye_indices[4]]
    p5, p6 = landmarks[eye_indices[0]], landmarks[eye_indices[3]]

    vertical1 = euclidean(p2, p4)
    vertical2 = euclidean(p3, p5)
    horizontal = euclidean(p1, p6)

    ear = (vertical1 + vertical2) / (2.0 * horizontal)
    return ear

def play_alarm():
    try:
        from playsound import playsound
        playsound('alarm.mp3')
    except:
        st.warning("⚠️ Audio alert failed to play.")

# ==============================
# DROWSINESS DETECTION LOGIC
# ==============================
def run_drowsiness_detector(ear_threshold, consec_frames, use_baseline, camera_index):
    mp_face = mp.solutions.face_mesh
    face_mesh = mp_face.FaceMesh(
        refine_landmarks=True,
        max_num_faces=1,
        min_detection_confidence=0.6,
        min_tracking_confidence=0.7
    )
    
    # Try camera index 0 first, then fallback to 1
    cap = cv2.VideoCapture(1)
    if not cap.isOpened():
        st.error("❌ Cannot access webcam. Please check permissions (System Settings → Privacy & Security → Camera).")
        return

    # Main display areas
    status_indicator = st.empty()  # Top-right status dot
    alert_placeholder = st.empty()  # Large alert banner (only when drowsy)
    video_container = st.empty()    # Video feed
    
    # Hidden sidebar for minimal UI
    sidebar_placeholder = st.sidebar.empty()

    frame_count = 0
    alarm_thread = None
    start_time = time.time()
    drowsy_detected = False
    last_alert_time = 0
    alert_cooldown = 2.0  # Seconds between alerts
    last_status_update = 0
    # Robust detection helpers
    WINDOW_SIZE = 20            # sliding window size for EAR smoothing
    MIN_BELOW = 15              # require at least this many lows in the window
    OPEN_HYST = 0.02            # hysteresis margin to consider "clearly open"
    OPEN_RESET_FRAMES = 5       # frames above hysteresis to reset counters
    ear_window = deque(maxlen=WINDOW_SIZE)
    open_counter = 0
    
    # Baseline calibration
    baseline_ear_values = deque(maxlen=BASELINE_SAMPLES)
    baseline_calibrated = False
    baseline_ear = 0.0
    calibration_frames = 0

    # Minimal startup message
    if use_baseline:
        st.info("📊 **Calibrating...** Keep your eyes open and look at the camera.")
    else:
        st.markdown("<div style='text-align: center; color: #9ca3af; padding: 1rem;'>🟢 System Active • Monitoring in progress</div>", unsafe_allow_html=True)
        time.sleep(1)

    while cap.isOpened():
        ret, img = cap.read()
        if not ret:
            st.warning("⚠️ Unable to read from camera.")
            break

        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        results = face_mesh.process(img_rgb)

        ear = 0.0
        face_detected = False

        if results.multi_face_landmarks:
            face_detected = True
            for face_landmarks in results.multi_face_landmarks:
                h, w, _ = img.shape
                landmarks = [(int(l.x * w), int(l.y * h)) for l in face_landmarks.landmark]

                left_eye = [362, 385, 387, 263, 373, 380]
                right_eye = [33, 160, 158, 133, 153, 144]

                left_ear = calculate_ear(landmarks, left_eye)
                right_ear = calculate_ear(landmarks, right_eye)
                ear = (left_ear + right_ear) / 2.0
                
                # Baseline calibration
                if use_baseline and not baseline_calibrated:
                    baseline_ear_values.append(ear)
                    calibration_frames += 1
                    if calibration_frames >= BASELINE_SAMPLES:
                        baseline_ear = np.mean(baseline_ear_values)
                        # Adjust threshold based on baseline (10% below baseline)
                        ear_threshold = max(0.15, baseline_ear * 0.90)
                        baseline_calibrated = True
                        st.success(f"✅ Baseline calibrated! Your normal EAR: {baseline_ear:.3f}, Threshold: {ear_threshold:.3f}")
                        time.sleep(2)

                # Determine drowsiness threshold
                if use_baseline and baseline_calibrated:
                    current_threshold = max(0.15, baseline_ear * 0.90)
                else:
                    current_threshold = ear_threshold

                # Update smoothing window and counters
                ear_window.append(ear)
                if ear < current_threshold:
                    frame_count += 1  # consecutive low counter (legacy)
                    open_counter = 0
                else:
                    # only reset if we are clearly above with hysteresis for enough frames
                    if ear > (current_threshold + OPEN_HYST):
                        open_counter += 1
                        if open_counter >= OPEN_RESET_FRAMES:
                            frame_count = 0
                            drowsy_detected = False
                    else:
                        open_counter = 0

                # Robust drowsiness condition:
                # 1) classic consecutive low frames OR
                # 2) at least MIN_BELOW of last WINDOW_SIZE frames below threshold
                below_count = sum(1 for v in ear_window if v < current_threshold)
                robust_drowsy = (frame_count >= consec_frames) or (below_count >= MIN_BELOW and len(ear_window) == WINDOW_SIZE)

                # Check for drowsiness
                if robust_drowsy:
                    drowsy_detected = True
                    current_time = time.time()
                    
                    # Visual overlay on video - prominent red alert
                    overlay = img.copy()
                    cv2.rectangle(overlay, (0, 0), (img.shape[1], img.shape[0]), (0, 0, 255), -1)
                    cv2.addWeighted(overlay, 0.3, img, 0.7, 0, img)
                    
                    # Large alert text on video
                    text = "DROWSINESS DETECTED"
                    font_scale = 2.0
                    thickness = 4
                    (text_width, text_height), baseline = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, font_scale, thickness)
                    text_x = (img.shape[1] - text_width) // 2
                    text_y = (img.shape[0] + text_height) // 2
                    
                    # Text shadow
                    cv2.putText(img, text, (text_x + 3, text_y + 3),
                                cv2.FONT_HERSHEY_SIMPLEX, font_scale, (0, 0, 0), thickness + 2)
                    # Main text
                    cv2.putText(img, text, (text_x, text_y),
                                cv2.FONT_HERSHEY_SIMPLEX, font_scale, (255, 255, 255), thickness)
                    
                    # Status indicator - red blinking
                    status_indicator.markdown(
                        '<div class="status-indicator status-red"></div>',
                        unsafe_allow_html=True
                    )
                    
                    # Large alert banner (only show if cooldown passed)
                    if current_time - last_alert_time > alert_cooldown:
                        with alert_placeholder.container():
                            st.markdown(f"""
                            <div class="drowsy-alert">
                                <h1 style='color: white; margin: 0; font-size: 3rem;'>⚠️ ALERT ⚠️</h1>
                                <h2 style='color: white; margin: 1rem 0; font-size: 2rem;'>DROWSINESS DETECTED</h2>
                                <p style='color: white; font-size: 1.2rem; margin: 1rem 0;'>
                                    <strong>Immediate action required</strong>
                                </p>
                                <p style='color: rgba(255,255,255,0.9); font-size: 1rem; margin-top: 1.5rem;'>
                                    System detected prolonged eye closure<br>
                                    Please ensure you are alert and focused
                                </p>
                            </div>
                            """, unsafe_allow_html=True)
                        last_alert_time = current_time
                    
                    # Audio alert
                    if alarm_thread is None or not alarm_thread.is_alive():
                        alarm_thread = threading.Thread(target=play_alarm)
                        alarm_thread.start()
                else:
                    # Normal state - minimal display
                    drowsy_detected = False
                    current_time = time.time()
                    
                    # Clear alert when awake
                    if current_time - last_status_update > 0.5:  # Update status every 0.5s
                        alert_placeholder.empty()
                        # Green status indicator
                        status_indicator.markdown(
                            '<div class="status-indicator status-green"></div>',
                            unsafe_allow_html=True
                        )
                        last_status_update = current_time
                    
                    # Minimal video overlay - only small indicator in corner
                    cv2.circle(img, (img.shape[1] - 30, 30), 10, (0, 255, 0), -1)
                    cv2.circle(img, (img.shape[1] - 30, 30), 12, (0, 255, 0), 2)
        else:
            # No face detected - minimal warning
            frame_count = 0
            alert_placeholder.empty()
            status_indicator.markdown(
                '<div class="status-indicator" style="background: #f59e0b; box-shadow: 0 0 20px rgba(245, 158, 11, 0.6);"></div>',
                unsafe_allow_html=True
            )
            # Small text in corner
            cv2.putText(img, "No face detected", (img.shape[1] - 200, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 165, 255), 2)

        # Display video frame - centered and clean
        with video_container.container():
            st.markdown('<div class="video-container">', unsafe_allow_html=True)
            st.image(img, channels="BGR")
            st.markdown('</div>', unsafe_allow_html=True)
        
        # Minimal sidebar - only show technical info if needed (collapsed by default)
        # Only update sidebar occasionally to reduce UI updates
        elapsed = int(time.time() - start_time)
        if st.session_state.get("show_tech_info", False) and (elapsed % 5 == 0 or drowsy_detected):
            with sidebar_placeholder.container():
                st.sidebar.markdown("---")
                if face_detected:
                    st.sidebar.metric("EAR", f"{ear:.3f}")
                    st.sidebar.metric("Low Frames", frame_count)
                    if use_baseline and baseline_calibrated:
                        st.sidebar.caption(f"Baseline: {baseline_ear:.3f}")
                st.sidebar.metric("Runtime", f"{elapsed}s")
                st.sidebar.markdown("---")

    cap.release()
    alert_placeholder.empty()
    status_indicator.empty()
    st.markdown("""
    <div style='text-align: center; padding: 2rem; color: #9ca3af;'>
        <h3>Monitoring Stopped</h3>
        <p>System has been deactivated</p>
    </div>
    """, unsafe_allow_html=True)

# ==============================
# STREAMLIT APP CONFIG
# ==============================
st.set_page_config(
    page_title="Drowsiness Alert System",
    layout="wide",
    page_icon="✈️",
    initial_sidebar_state="collapsed"
)

# Custom CSS for professional, minimal UI
st.markdown("""
<style>
    /* Hide Streamlit branding */
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
    header {visibility: hidden;}
    
    /* Professional dark theme */
    .stApp {
        background: linear-gradient(135deg, #0a0e27 0%, #1a1f3a 100%);
    }
    
    /* Alert styling */
    .drowsy-alert {
        background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%);
        color: white;
        padding: 2rem;
        border-radius: 12px;
        box-shadow: 0 8px 32px rgba(220, 38, 38, 0.4);
        animation: pulse 2s infinite;
        text-align: center;
        margin: 1rem 0;
    }
    
    @keyframes pulse {
        0%, 100% { transform: scale(1); }
        50% { transform: scale(1.02); }
    }
    
    /* Status indicator */
    .status-indicator {
        position: fixed;
        top: 20px;
        right: 20px;
        width: 20px;
        height: 20px;
        border-radius: 50%;
        z-index: 1000;
    }
    
    .status-green {
        background: #10b981;
        box-shadow: 0 0 20px rgba(16, 185, 129, 0.6);
    }
    
    .status-red {
        background: #ef4444;
        box-shadow: 0 0 20px rgba(239, 68, 68, 0.8);
        animation: blink 1s infinite;
    }
    
    @keyframes blink {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.5; }
    }
    
    /* Clean video container */
    .video-container {
        background: #000;
        border-radius: 8px;
        padding: 10px;
        box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3);
    }
    
    /* Minimal text */
    h1 {
        color: #f3f4f6;
        font-weight: 300;
        letter-spacing: 2px;
    }
    
    .subtitle {
        color: #9ca3af;
        font-size: 0.9rem;
        margin-top: -10px;
    }
</style>
""", unsafe_allow_html=True)

# Header - minimal and professional
col1, col2, col3 = st.columns([1, 2, 1])
with col2:
    st.markdown("""
    <h1 style='text-align: center; margin-bottom: 0;'>DROWSINESS ALERT SYSTEM</h1>
    <p class='subtitle' style='text-align: center;'>Active Monitoring • Alert-Only Display</p>
    """, unsafe_allow_html=True)

# Persistent sidebar toggle for technical info
st.sidebar.checkbox("📊 Show Technical Info", key="show_tech_info")

# ==============================
# CONFIGURATION PANEL - Collapsed by default for clean UI
# ==============================
with st.expander("⚙️ System Configuration", expanded=False):
    col1, col2 = st.columns(2)
    
    with col1:
        ear_threshold = st.slider(
            "EAR Threshold",
            min_value=0.15,
            max_value=0.35,
            value=DEFAULT_EAR_THRESHOLD,
            step=0.01,
            help="Lower = more sensitive. Normal range: 0.20-0.30. Eyes open typically 0.25-0.35, closed 0.15-0.20"
        )
    
    with col2:
        consec_frames = st.slider(
            "Consecutive Frames",
            min_value=5,
            max_value=30,
            value=DEFAULT_CONSEC_FRAMES,
            step=1,
            help="Number of consecutive frames with low EAR before alert. Higher = less sensitive to brief blinks"
        )
    
    use_baseline = st.checkbox(
        "Use Baseline Calibration",
        value=False,
        help="Calibrate threshold based on your normal eye state for personalized detection"
    )
    
    camera_index = st.selectbox(
        "Camera Index",
        options=[0, 1],
        index=0,
        help="Try 0 for built-in camera, 1 for external camera"
    )
    
    st.markdown("---")
    st.markdown("### 📖 How It Works")
    st.markdown("""
    **Eye Aspect Ratio (EAR)** measures eye openness:
    - **EAR > Threshold**: Eyes open (awake) ✅
    - **EAR < Threshold**: Eyes closed (drowsy) ⚠️
    
    **Detection Logic**:
    1. Calculate EAR for both eyes
    2. If EAR stays below threshold for **{} frames** → Alert triggered
    3. This prevents false alarms from normal blinking
    
    **Recommended Settings**:
    - **Sensitive**: EAR 0.20, Frames 10-12
    - **Balanced**: EAR 0.22, Frames 15 (default)
    - **Conservative**: EAR 0.25, Frames 20
    """.format(consec_frames))

# ==============================
# START/STOP CONTROL - Prominent and clean
# ==============================
st.markdown("<br>", unsafe_allow_html=True)

col1, col2, col3 = st.columns([1, 2, 1])
with col2:
    start_button = st.button(
        "▶️ START MONITORING",
        type="primary",
        use_container_width=True,
        help="Begin real-time drowsiness detection"
    )

if start_button:
    run_drowsiness_detector(ear_threshold, consec_frames, use_baseline, camera_index)

# Footer - minimal
st.markdown("""
<div style='text-align: center; color: #6b7280; padding: 2rem 0; font-size: 0.85rem;'>
    Alert-Only Display • No redundant notifications • Professional monitoring system
</div>
""", unsafe_allow_html=True)

