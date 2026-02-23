# One More Rep (OMR) - Agent Context

This file serves as the primary context for AI agents working on the OMR project. It contains the project mission, technical requirements, and current progress.

---

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
* **Hand Gestures:** 
    * **Open Palm:** Toggle Pause/Resume recording.
    * **Peace Sign (Two Fingers):** Stop recording and finalize the session.

---

## 3. Workflow & Interface Mockups

### Screen 1: Home / Readiness
* **Header:** Large Title font with a personalized greeting ("Hello, Santiago!").
* **Streak Badge:** A prominent "pill-shaped" glassmorphic container displaying a fire icon and the current daily count.
* **Primary Action:** A large, high-contrast "Train" button anchored at the bottom.

### Screen 2: Recording / Workout (Core Engine)
* **Viewfinder:** Full-screen front-facing camera feed.
* **Counter (Top Left):** "REPS" label with a huge, bold numeric counter.
* **Interaction Overlays (Bottom):** Large buttons for Pause/Resume and Stop, with gesture hint icons.
* **UX Note:** Hands-free interaction is the priority.

### Screen 3: Training Stats / Summary
* **Header:** "Training Stats" in centered Title font.
* **Stats Grid:** Reps, Time, and New Streak.
* **Footer Actions:** "Save Session" (Primary) and "Discard" (Secondary).

---

## 4. Technical Logic & Core Ideas

### Movement Engine (Relaxed Mode)
* **Logic:** Tracking the vertical Y-axis displacement of the head/neck.
* **Calibration:** Establish a "baseline" starting height at the beginning of each set.
* **Counting:** A rep is registered when the tracked point moves a certain distance from the baseline and returns.

### Video Management
* **Real-time Stitching:** Record directly into a single buffer. 
* **Phase 2 Exports:** Burned-in UI and Time-lapse options.

### Scalability (Phase 2)
* Decoupled architecture to support `UserSessionManager` for backend syncing (Supabase/Vercel).

---

## 5. Constraints & Rules

* **Design:** Apple Minimalist (SF Symbols, system materials, high white-space).
* **Navigation:** Strictly Portrait Mode.
* **Hardware:** Front Camera (Mirror effect).
* **Frameworks:** SwiftUI, Apple Vision Framework (`VNHumanBodyPoseRequest` & `VNHumanHandPoseRequest`), AVFoundation.

