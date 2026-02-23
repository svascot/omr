
# PROJECT OVERVIEW: One More Rep (OMR)

## 1. High-Level Summary

* **Mission:** To create a native iPhone application that automates the "one more rep every day" fitness trend. The app uses AI to count repetitions in real-time and manages video recording to provide seamless "social proof."
* **Target Audience:** Fitness enthusiasts and beginners participating in progressive volume challenges (push-ups, pull-ups, squats).
* **Core Objective:** A hands-free, tripod-based experience where the user interacts with the app via the front-facing camera using AI motion tracking and hand gestures.

---

## 2. Definitions & Glossary

* **Antigravity:** The Google AI-powered development environment (Project IDX/AI IDE) used for this project.
* **Relaxed Mode (Phase 1 Focus):** A forgiving rep-counting logic that tracks general vertical displacement (up/down movement of a central point like the head or neck) rather than technical perfection.
* **Strict Mode (Phase 2):** A high-precision mode utilizing full pose estimation to validate exercise technique (e.g., elbow angles < 90° for push-ups).
* **The Stitcher:** A background video engine using `AVAssetWriter` that allows the user to pause and resume recording, resulting in one single, continuous video file without post-processing delays.
* **Hand Gestures:** * **Open Palm:** Toggle Pause/Resume recording.
* **Peace Sign (Two Fingers):** Stop recording and finalize the session.



---

## 3. Workflow & Interface Mockups

*Use these structural definitions to build the SwiftUI views.*

### Screen 1: Home / Readiness

* **Header:** Large Title font with a personalized greeting (e.g., "Hello, Santi!").
* **Streak Badge:** A prominent "pill-shaped" material container displaying a fire icon and the current daily count (e.g., 🔥 85).
* **Primary Action:** A large, high-contrast "Train" button anchored at the bottom to launch the camera session.

### Screen 2: Recording / Workout (Core Engine)

* **Viewfinder:** Full-screen front-facing camera feed.
* **Counter (Top Left):** "Reps" label with a large, bold numeric counter (Unlimited/Infinite count).
* **Interaction Overlays (Bottom):** * **Center:** A circular Pause/Resume icon (Visual mirror of the "Open Palm" gesture).
* **Right:** A square Finish/Stop icon (Visual mirror of the "Peace Sign" gesture).


* **UX Note:** No buttons should be strictly required for interaction; all controls are accessible via hand gestures detected by the Vision framework.

### Screen 3: Training Stats / Summary

* **Header:** "Training Stats" in centered Title font.
* **Stats Grid:**
* **Reps:** Total repetitions completed.
* **Time:** Total session duration (e.g., 20:05 min).
* **New Streak:** Incremented daily streak (e.g., 86).


* **Footer Actions:**
* **Save (Primary):** Large button to finalize the session and commit the video to storage.
* **Discard (Secondary):** Small "X" or "Delete" button to scrap the session.



---

## 4. Technical Logic & Core Ideas

### Movement Engine (Relaxed Mode)

* **Logic:** Tracking the vertical Y-axis displacement of the head/neck.
* **Calibration:** The app must establish a "baseline" starting height at the beginning of each set.
* **Counting:** A rep is registered when the tracked point moves  distance from the baseline and returns.

### Video Management

* **Real-time Stitching:** Record directly into a single buffer. When "Paused," the app stops feeding frames; when "Resumed," it continues in the same file.
* **Phase 2 Exports:** * **Burned-in UI:** Toggle to export the video with the rep counter visible on the frame.
* **Time-lapse:** Option to export the final video at speeds of x2, x4, or x8.



### Scalability (Multi-Tenancy) Phase 2

* The architecture must be decoupled so that a `UserSessionManager` can eventually sync stats to a backend (e.g., Supabase/Vercel) for multi-user support and global leaderboards.

---

## 5. Constraints & Rules

* **Design Language:** Strictly "Apple Minimalist." Use San Francisco typography, SF Symbols, system materials (blur effects), and high white-space ratios.
* **No Progress Rings:** Do not use circular progress bars; use raw numeric counters for an "infinite" feel.
* **Orientation:** Strictly **Portrait Mode** only.
* **Hardware:** Optimized for the **Front Camera** to act as a digital mirror.
* **Frameworks:** Native and Free only.
* **UI:** SwiftUI.
* **AI:** Apple Vision Framework (`VNHumanBodyPoseRequest` & `VNHumanHandPoseRequest`).
* **Media:** `AVFoundation`.



---

## 6. Current Progress

* **Completed:** Tech stack finalized; workflow and mockups defined; project metadata established.
* **Current Task:** Implementing `CameraManager.swift` (AVFoundation) and `MovementService.swift` (Vision Framework) to handle the gesture-based recording and rep counting.

---

## 7. Mockups descriptions:

* **Screen 1: Home / Readiness**
This screen welcomes the user and puts their streak front and center to build momentum.

Clean Typography: Large, bold title greeting.

Streak Badge: A prominent "pill" using a system material (glassy background) with a flame icon and the current streak count.

Primary Action: A large, full-width "Train" button using the app's accent color (e.g., system blue) for clear call-to-action.

* **Screen 2: Recording / Workout (The Core Engine)**
This is the main interface, designed to be viewed from a distance while the iPhone is on a tripod.

Immersive Viewfinder: The front camera feed fills the screen.

High-Legibility Counter: The rep count ("13") is huge, bold, and placed at the top left with a subtle shadow for readability against any background.

Gesture-First Controls: The bottom buttons (Pause/Resume, Stop) are large and translucent. Crucially, I added small gesture hint icons (Open Palm near Pause, Peace Sign near Stop) to remind the user of the hands-free controls.

* **Screen 3: Training Stats / Summary**
A clean summary screen to review performance before saving.

Clear Hierarchy: A large title, followed by a clean grid layout for stats (Reps, Time, New Streak).

Primary & Secondary Actions: A large, dominant "Save Session" button for the main goal, with a smaller, less prominent "X" button below it for discarding the session.
