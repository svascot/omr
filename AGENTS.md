# One More Rep (OMR) - Agent Context

One More Rep (OMR) is a native iOS application designed to automate fitness tracking by leveraging real-time AI computer vision and high-performance video recording.

---

## 1. Project Mission & Objective
* **Mission:** Automate the "one more rep every day" movement by providing hands-free tracking and instant "social proof" videos.
* **Core Objective:** A tripoded, hands-free experience where the front camera acts as a digital mirror. Features real-time rep counting and a "The Stitcher" video engine.

## 2. Technical Stack
* **UI Framework:** SwiftUI (strictly native, minimalist style).
* **AI Computer Vision:** Apple Vision Framework (`VNHumanBodyPoseRequest` for reps, `VNHumanHandPoseRequest` for gestures).
* **Media Processing:** AVFoundation (custom `AVAssetWriter` implementation for seamless pause/resume).
* **State Management:** `AppState` (ObservableObject) managing all global navigation and persistence.

## 3. Core Services & Logic

### 🎥 The Stitcher (`CameraManager.swift`)
* Manages a continuous `AVCaptureSession`.
* Records logic-driven video using `AVAssetWriter`.
* **Overlays:** Burned-in Core Graphics overlays (glassmorphic style) that match the app UI exactly.
* **Gestures:** 
    - **Peace Sign:** Finalizes recording.
    - **Open Palm/Wave:** Toggles Pause/Resume/Start.

### 🤖 Movement Engine (`MovementService.swift`)
* **Relaxed Mode (Phase 1):** Tracks the Y-axis displacement of the `.nose` (fallback to `.neck`).
* **Logic:** A state-machine based Peak-to-Valley counter with a `0.05` normalized height threshold.
* **Thread Safety:** Uses a non-isolated `internalRepCount` for background video overlay access.

### 💾 Persistence & History (`AppState.swift`)
* **User:** Fixed to `"vasco"`.
* **Storage:** Every session is saved to `user_data_v2.json`.
* **Navigation:** Supports Home, Recording, Summary, and a detailed History list.

## 4. Design Language (Apple Minimalist)
* **Materials:** Heavy use of `.ultraThinMaterial` and glassmorphism.
* **Typography:** System Rounded fonts, bold/black weights for metrics.
* **Constraint:** Strictly **Portrait Mode** only. No progress rings (numeric counters only).

## 5. Collaboration Rules for AI
1. **Sync Overlays:** UI changes in `RecordingView` MUST be mirrored in `CameraManager.addOverlays`.
2. **Hands-Free First:** Do not replace gestures with buttons for workout controls.
3. **Data Integrity:** `AppState` is the source of truth. Always use `Identifiable` for history models.
