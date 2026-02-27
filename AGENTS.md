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
The `CameraManager` implementation is a high-performance video recorder built on `AVFoundation`.
- **Seamless Recording:** It handles pause/resume by managing a `timeOffsetAtEngine` (CMTime). It subtracts the "pause gap" from the frame timestamps to produce a single, gapless `.mov` file.
- **Core Graphics Pipeline:** Frames are captured in `32BGRA`. Overlays are drawn via `UIGraphicsPushContext` directly on the `CVPixelBuffer` before being appended to the `AVAssetWriterInput`.
- **Robust Gestures:** 
    - **Confidence:** Floor lowered to `0.45` for better low-light performance.
    - **Relative Logic:** Detects gestures by comparing tip heights (Index/Middle vs Ring/Little) relative to the `wrist`, making it orientation-independent.
    - **Temporal Buffering:** Requires `3` consecutive frames of detection before triggering, reducing false positives.
- **Layout Logic:** Centering is handled via `NSMutableParagraphStyle` and `CGRect` calculations to ensure pixel-perfect alignment in the saved file.
* **Gestures:** 
    - **Peace Sign (Two Fingers):** Finalizes recording (Uses relative finger height logic).
    - **Open Palm/Wave:** Toggles Pause/Resume/Start (Uses temporal confirmation buffer).

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
