#!/usr/bin/env python3
"""
Camera Permission Test Script
This script helps diagnose camera access issues on macOS
"""
import cv2
import sys
import platform

def test_camera():
    print("="*60)
    print("Camera Access Test")
    print("="*60)
    print(f"Platform: {platform.system()} {platform.release()}")
    print()
    
    # Try to open camera
    print("[1/3] Attempting to open camera...")
    cap = cv2.VideoCapture(0)
    
    if not cap.isOpened():
        print("❌ FAILED: Cannot open camera device")
        print()
        print_camera_permission_instructions()
        return False
    
    print("✓ Camera device opened")
    print()
    
    # Try to read a frame
    print("[2/3] Attempting to read frame from camera...")
    import time
    time.sleep(0.5)  # Give camera time to initialize
    
    ret, frame = cap.read()
    cap.release()
    
    if not ret or frame is None:
        print("❌ FAILED: Cannot read frames from camera")
        print()
        print_camera_permission_instructions()
        return False
    
    print("✓ Successfully read frame from camera")
    print(f"  Frame size: {frame.shape[1]}x{frame.shape[0]}")
    print()
    
    # Success
    print("[3/3] Camera test complete")
    print("✓ Camera is working correctly!")
    print("="*60)
    return True

def print_camera_permission_instructions():
    print("="*60)
    print("HOW TO FIX CAMERA PERMISSIONS ON macOS:")
    print("="*60)
    print()
    print("Method 1: System Settings (macOS Ventura+)")
    print("  1. Open System Settings")
    print("  2. Click 'Privacy & Security' in the sidebar")
    print("  3. Click 'Camera'")
    print("  4. Enable the toggle for:")
    print("     - Terminal (if running from terminal)")
    print("     - Python (if it appears)")
    print("     - Cursor (if running from Cursor)")
    print("     - VS Code (if running from VS Code)")
    print()
    print("Method 2: System Preferences (macOS Monterey and earlier)")
    print("  1. Open System Preferences")
    print("  2. Click 'Security & Privacy'")
    print("  3. Click the 'Privacy' tab")
    print("  4. Select 'Camera' from the left sidebar")
    print("  5. Check the box for your terminal/IDE")
    print()
    print("Method 3: Trigger Permission Prompt")
    print("  - Run this script from Terminal (not through GUI)")
    print("  - macOS should show a permission prompt")
    print("  - Click 'OK' when prompted")
    print()
    print("After granting permissions:")
    print("  - Close and restart your terminal/IDE")
    print("  - Run this test script again to verify")
    print("="*60)

if __name__ == "__main__":
    success = test_camera()
    sys.exit(0 if success else 1)



