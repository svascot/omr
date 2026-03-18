# One More Rep (OMR)

**One More Rep (OMR)** is a premium, AI-powered native iPhone application designed to automate the "one more rep every day" fitness trend. By leveraging on-device neural tracking and real-time video stitching, OMR provides a high-end, hands-free experience for tracking and sharing your physical progress.

## 🚀 Mission

To empower athletes and fitness enthusiasts to dominate progressive volume challenges (push-ups, pull-ups, squats) through an automated, hands-free experience that provides instant, verified "social proof."

## ✨ Features

- **🤖 Anatomical AI Tracking**: High-precision repetition counting for **Push-ups**, **Squats**, and **Pull-ups**. OMR uses advanced joint-angle math (monitoring elbows and knees) to ensure perfect counting accuracy regardless of your distance from the camera.
- **🎬 Seamless Video Stitcher**: A sophisticated background video engine that allows you to pause and resume recording into a single, continuous file—ready for sharing the moment you finish.
- **🖐️ Hands-Free Interaction**: 
    - **AirPods Controls**: Start, pause, or resume your session with a single tap on your AirPods.
    - **Hand Gestures**: Use a "Peace Sign" gesture to finish your session and an "Open Palm" to toggle recording.
- **⏱️ Rest Timer**: A large, high-visibility resting timer automatically appears in the center of the screen the moment you pause, keeping your training intensity on track.
- **💎 Premium Glassmorphic UI**: A stunning, state-of-the-art interface built with premium materials, micro-animations, and custom typography optimized for focused workouts.
- **📊 Session Analytics & History**: Custom-name your training sessions, track your total reps, sets, and active time, and manage your daily streaks.
- **🏋️ Manual Training Mode**: A camera-free tracking mode with a live timer, a scrollable wheel picker for rep selection, and a set log. Perfect for quick sessions where you just want to log your reps without video recording.
- **🌙 Never-Sleep Mode**: OMR automatically prevents your iPhone screen from auto-locking or dimming during your training session.

## 🛠️ Tech Stack & Rationale

- **SwiftUI**: Utilized for its declarative efficiency in building a reactive, high-performance UI with advanced glassmorphic effects.
- **Apple Vision Framework**: Provides industry-leading, on-device AI for real-time body and hand pose estimation. We use this for privacy-first tracking that doesn't require an internet connection.
- **AVFoundation**: Powers the custom camera logic and real-time video stitching, ensuring zero lag between finishing a workout and saving the video.
- **Combine**: Used for clean, reactive state management across multiple services (Camera, Movement, and Motion).
- **PhotoKit**: Integrated for secure, direct-to-gallery video saving.

## 📈 Roadmap & Current Progress

### Current Status
- Project architecture and design system implementation.
- Real-time anatomical tracking for multi-movements (Neural Engine).
- Hands-free gesture and peripheral control integration.
- Local persistence and history management logic.
- Premium UI implementation and state synchronization.

### Phase 2 Goals
- **Smart Form Coaching**: Real-time voice feedback on joint range-of-motion.
- **Enhanced Video Exports**: Dynamic UI overlays burned directly into the shared video.
- **Cloud Sync & Leaderboards**: Multi-tenant backend for community challenges and global rankings.
- **Apple Watch Companion**: Heart rate integration and haptic feedback for reps.

## 📄 License

*Internal Project - Santiago Vasco*

