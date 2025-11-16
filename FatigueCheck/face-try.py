# -- coding: utf-8 --
"""
Created on Sun Dec 29 18:48:12 2019

@author: Lenovo
"""
import os
import cv2
import sys
import time

# Load Haar cascade
#Absolute path
#cascade_path = '/home/happy/gssoc/driver-drowsiness-detection-system/models/haarcascade_frontalface_default.xml'

#relative path
BASE_DIR=os.path.dirname(os.path.abspath(__file__))
cascade_path = os.path.join(BASE_DIR,'models','haarcascade_frontalface_default.xml')


face_cascade = cv2.CascadeClassifier(cascade_path)

# Check if cascade loaded successfully
if face_cascade.empty():
    print(f"[ERROR] Failed to load cascade from {cascade_path}")
    sys.exit(1)

# Start video capture
print("[INFO] Attempting to access webcam...")
cap = cv2.VideoCapture(0)

# Give the camera a moment to initialize
time.sleep(0.5)

if not cap.isOpened():
    print("\n[ERROR] Cannot access webcam.")
    print("\n" + "="*60)
    print("CAMERA PERMISSION ISSUE - macOS Instructions:")
    print("="*60)
    print("1. Open System Preferences (or System Settings on macOS Ventura+)")
    print("2. Go to Security & Privacy (or Privacy & Security)")
    print("3. Select 'Camera' from the left sidebar")
    print("4. Check the box next to 'Terminal' (or your terminal app)")
    print("   - If using VS Code/Cursor, also check the box for that app")
    print("5. Restart the terminal/application and try again")
    print("\nAlternatively, you can grant permission when prompted.")
    print("="*60 + "\n")
    sys.exit(1)

# Test if we can actually read from the camera
ret, test_frame = cap.read()
if not ret or test_frame is None:
    print("\n[ERROR] Camera opened but cannot read frames.")
    print("This usually indicates a permission issue.")
    print("\nPlease grant camera permissions:")
    print("- macOS: System Preferences > Security & Privacy > Camera")
    print("- Enable access for Terminal or your IDE\n")
    cap.release()
    sys.exit(1)

print("[INFO] Camera initialized successfully!")

try:
    while True:
        ret, img = cap.read()

        # Check if frame was captured
        if not ret or img is None:
            print("[WARNING] Failed to read frame from webcam.")
            continue

        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

        try:
            faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=4)
        except cv2.error as e:
            print(f"[ERROR] detectMultiScale failed: {e}")
            continue

        for (x, y, w, h) in faces:
            cv2.rectangle(img, (x, y), (x + w, y + h), (255, 0, 0), 3)

        cv2.imshow('Face Detection', img)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            print("[INFO] Exiting on user request.")
            break

except KeyboardInterrupt:
    print("\n[INFO] Exiting on Ctrl+C")

finally:
    cap.release()
    cv2.destroyAllWindows()
