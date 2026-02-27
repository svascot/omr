# Claude Technical Context: OMR Project

Deep-dive technical context and architecture for advanced AI development on the One More Rep (OMR) project.

---

## 🏗️ Architecture Deep-Dive

### 1. The Video Engine ("The Stitcher")
The `CameraManager` implementation is a high-performance video recorder built on `AVFoundation`.
- **Seamless Recording:** It handles pause/resume by managing a `timeOffsetAtEngine` (CMTime). It subtracts the "pause gap" from the frame timestamps to produce a single, gapless `.mov` file.
- **Core Graphics Pipeline:** Frames are captured in `32BGRA`. Overlays are drawn via `UIGraphicsPushContext` directly on the `CVPixelBuffer` before being appended to the `AVAssetWriterInput`.
- **Layout Logic:** Centering is handled via `NSMutableParagraphStyle` and `CGRect` calculations to ensure pixel-perfect alignment in the saved file.

### 2. State-Based Navigation
The app follows a flat navigation structure managed by `AppState.AppScreen`:
- `.home`: Progress overview and "Train" entry point.
- `.recording`: Live feed with active processing.
- `.summary`: Post-action review and video saving.
- `.history`: Scrollable list of `SessionStats` fetched from `user_data_v2.json`.

### 3. Vision Detection Pipeline
`MovementService` runs concurrently with the video output.
- **Tracking Point:** Primary is `.nose`, secondary is `.neck`.
- **Hysteresis:** The state machine (`.up` <-> `.down`) prevents flickering counts during subtle micro-movements.
- **Performance:** Detection runs on the `videoQueue` to avoid blocking the main thread or the UI.

## 🛠️ Implementation Guidelines

### Coding Style
- **SwiftUI:** Use `@StateObject` for services. Prefer `Capsule()` and `RoundedRectangle(cornerRadius: 24)` with `.ultraThinMaterial`.
- **Concurrency:** Services are `@MainActor`, but performance-critical logic in `CameraManager` use `nonisolated` methods with thread-safe properties.

### Data Model (`SessionStats`)
- **Structure:** `Identifiable`, `Codable`. Includes `id: UUID`, `date: Date`, `user: String`, `reps: Int`, and durations.
- **Update Rule:** Never mutate the history array directly without calling `saveData()`.

### Layout Constants
- **Standard Padding:** `24` for horizontal margins.
- **Stat Cards:** Aspect ratio/sizing should match the premium "pill" design in `HomeView`.

## ⏭️ Roadmap Targets
- **Strict Mode:** Implementing elbow/joint angle calculation using normalized Vision coordinates.
- **Video Post-Ops:** Time-lapse processing using `AVAssetReader` to re-encode the captured file at higher speeds.
