# One More Rep (OMR)

**One More Rep (OMR)** is a native iPhone application designed to automate the "one more rep every day" fitness trend. By leveraging AI motion tracking and real-time video management, OMR provides a hands-free, seamless experience for tracking and sharing your progress.

## 🚀 Mission

To empower fitness enthusiasts and beginners to participate in progressive volume challenges (push-ups, pull-ups, squats) through an automated, hands-free experience that provides instant "social proof."

## ✨ Core Features

-   **🤖 AI Rep Counting:** Real-time repetition counting using Apple's Vision framework.
    -   **Relaxed Mode (Currently Implementing):** Forgiving logic tracking general vertical displacement.
    -   **Strict Mode (Phase 2):** High-precision validation using full pose estimation.
-   **🎬 The Stitcher:** A background video engine that allows pausing and resuming recording into a single, continuous file—no post-processing delays.
-   **🖐️ Gesture-Based Interaction:** Fully hands-free control via front-facing camera gestures:
    -   **Open Palm:** Toggle Pause/Resume recording.
    -   **Peace Sign:** Stop recording and finalize the session.
-   **🔥 Streak Management:** Built-in daily streak tracking to keep you motivated.

## 🎨 Design Principles

-   **Apple Minimalist:** Adheres strictly to Apple's design language—San Francisco typography, SF Symbols, and system materials.
-   **Infinite Progress:** Uses raw numeric counters instead of progress rings for an "infinite" feel.
-   **Portrait Optimized:** Designed specifically for portrait orientation on a digital mirror (front camera) setup.

## 🛠️ Tech Stack

-   **UI:** SwiftUI
-   **AI/Vision:** Apple Vision Framework (`VNHumanBodyPoseRequest`, `VNHumanHandPoseRequest`)
-   **Media:** AVFoundation (`AVAssetWriter`, `AVAssetReader`)
-   **Language:** Swift

## 📈 Roadmap & Current Progress

### Current Status
- [x] Tech stack and design architecture finalized.
- [x] Workflow and interface mockups defined.
- [ ] Implementing `CameraManager.swift` and `MovementService.swift`.

### Phase 2 Goals
- [ ] **Strict Mode:** Technical perfection validation (e.g., elbow angles).
- [ ] **Enhanced Video Exports:** Burned-in UI overlays and time-lapse options.
- [ ] **Global Leaderboards:** Multi-user support with backend sync (Supabase/Vercel).

## 📄 License

*Internal Project - Santiago Vasco*
