import SwiftUI
import Combine

/// Represents the current state of the AR visualization workflow
enum ARViewState: Equatable {
    case scanning
    case selection
    case application
    case adjustment
    case capture
}

/// Shared application state managing the AR session workflow
@MainActor
final class AppState: ObservableObject {
    /// Current workflow state
    @Published var currentState: ARViewState = .scanning

    /// Currently selected wall identifier
    @Published var selectedWallID: UUID?

    /// Currently applied style
    @Published var appliedStyle: WallStyle?

    /// UV scale for pattern tiling (1.0 = original size)
    @Published var uvScale: Float = 1.0

    /// Pattern offset for repositioning
    @Published var patternOffset: SIMD2<Float> = .zero

    /// Whether AR tracking is established
    @Published var isTrackingReady: Bool = false

    /// Whether LiDAR is available on this device
    @Published var hasLiDAR: Bool = false

    /// Detected walls in the scene
    @Published var detectedWalls: [DetectedWall] = []

    /// Loading state for async operations
    @Published var isLoading: Bool = false

    /// Error message to display
    @Published var errorMessage: String?

    /// Captured image data
    @Published var capturedImage: UIImage?

    /// Minimum UV scale
    let minUVScale: Float = 0.25

    /// Maximum UV scale
    let maxUVScale: Float = 4.0

    // MARK: - Actions

    func selectWall(_ wallID: UUID) {
        selectedWallID = wallID
        currentState = .selection
    }

    func applyStyle(_ style: WallStyle) {
        guard selectedWallID != nil else { return }
        appliedStyle = style
        currentState = .application
    }

    func enterAdjustmentMode() {
        guard appliedStyle != nil else { return }
        currentState = .adjustment
    }

    func enterCaptureMode() {
        currentState = .capture
    }

    func resetToScanning() {
        currentState = .scanning
        selectedWallID = nil
        appliedStyle = nil
        uvScale = 1.0
        patternOffset = .zero
    }

    func updateUVScale(_ scale: Float) {
        uvScale = max(minUVScale, min(maxUVScale, scale))
    }

    func updatePatternOffset(_ offset: SIMD2<Float>) {
        patternOffset = offset
    }

    func setCapturedImage(_ image: UIImage?) {
        capturedImage = image
        if image != nil {
            currentState = .capture
        }
    }

    func dismissCapture() {
        capturedImage = nil
        currentState = appliedStyle != nil ? .adjustment : .scanning
    }
}
