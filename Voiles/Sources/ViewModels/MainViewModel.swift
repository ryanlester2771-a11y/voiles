import SwiftUI
import ARKit
import RealityKit
import Combine

/// Main view model coordinating AR session and UI state
@MainActor
final class MainViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var currentState: ARViewState = .scanning
    @Published var selectedWallID: UUID?
    @Published var appliedStyle: WallStyle?
    @Published var uvScale: Float = 1.0
    @Published var patternOffset: SIMD2<Float> = .zero
    @Published var isTrackingReady = false
    @Published var showCoachingOverlay = true
    @Published var showStyleSelector = false
    @Published var capturedImage: UIImage?
    @Published var errorMessage: String?
    @Published var isLoading = false

    /// Detected walls
    @Published var detectedWalls: [DetectedWall] = []

    // MARK: - Managers

    let sessionManager = ARSessionManager()
    let wallDetectionManager = WallDetectionManager()
    let occlusionManager = OcclusionManager()
    let materialManager = MaterialManager()
    let lightingManager = LightingManager()
    let assetManager = AssetManager()
    let captureManager = CaptureManager()

    // MARK: - Private Properties

    private var arView: ARView?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Bind wall detection updates
        wallDetectionManager.$detectedWalls
            .receive(on: DispatchQueue.main)
            .assign(to: &$detectedWalls)

        // Bind loading state
        materialManager.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)

        // Bind capture
        captureManager.$lastCapturedImage
            .receive(on: DispatchQueue.main)
            .assign(to: &$capturedImage)
    }

    // MARK: - AR View Setup

    func setupARView(_ arView: ARView) {
        self.arView = arView

        // Setup all managers
        sessionManager.setupARView(arView)
        sessionManager.delegate = self

        wallDetectionManager.setup(with: arView)
        occlusionManager.setup(with: arView)
        materialManager.setup(with: arView)
        lightingManager.setup(with: arView)
        captureManager.setup(with: arView)

        // Start session
        sessionManager.startSession()
    }

    // MARK: - State Management

    func transitionTo(_ state: ARViewState) {
        currentState = state

        switch state {
        case .scanning:
            resetSelection()
            wallDetectionManager.clearHighlights()
            showCoachingOverlay = !isTrackingReady

        case .selection:
            showStyleSelector = false

        case .application:
            showStyleSelector = true

        case .adjustment:
            showStyleSelector = false

        case .capture:
            showStyleSelector = false
        }
    }

    // MARK: - Wall Selection

    func handleTap(at point: CGPoint) {
        guard let arView = arView else { return }

        switch currentState {
        case .scanning, .selection:
            // Try to select a wall
            if let wall = wallDetectionManager.findWall(at: point, in: arView) {
                selectWall(wall)
            }

        case .application, .adjustment:
            // Tap on applied style could show options
            break

        case .capture:
            break
        }
    }

    func selectWall(_ wall: DetectedWall) {
        selectedWallID = wall.id
        wallDetectionManager.highlightWall(wall.id, highlighted: true)
        transitionTo(.selection)
    }

    func resetSelection() {
        selectedWallID = nil
        appliedStyle = nil
        uvScale = 1.0
        patternOffset = .zero
    }

    // MARK: - Style Application

    func applyStyle(_ style: WallStyle) {
        guard let wallID = selectedWallID,
              let wall = detectedWalls.first(where: { $0.id == wallID }) else {
            return
        }

        appliedStyle = style
        uvScale = style.defaultScale

        Task {
            await materialManager.applyStyle(style, to: wall, uvScale: uvScale, offset: patternOffset)
            wallDetectionManager.highlightWall(wallID, highlighted: false)
            transitionTo(.adjustment)
        }
    }

    func updateUVScale(_ scale: Float) {
        uvScale = max(0.25, min(4.0, scale))

        guard let wallID = selectedWallID else { return }
        materialManager.updateStyleTransform(for: wallID, scale: uvScale, offset: patternOffset)
    }

    func updatePatternOffset(_ offset: SIMD2<Float>) {
        patternOffset = offset

        guard let wallID = selectedWallID else { return }
        materialManager.updateStyleTransform(for: wallID, scale: uvScale, offset: patternOffset)
    }

    // MARK: - Capture

    func captureScreenshot() {
        Task {
            if let image = await captureManager.captureScreenshot() {
                capturedImage = image
                transitionTo(.capture)
            }
        }
    }

    func saveCapture() async -> Bool {
        guard let image = capturedImage else { return false }
        return await captureManager.saveToPhotoLibrary(image)
    }

    func dismissCapture() {
        capturedImage = nil
        captureManager.clearLastCapture()
        transitionTo(appliedStyle != nil ? .adjustment : .scanning)
    }

    // MARK: - Session Control

    func pauseSession() {
        sessionManager.pauseSession()
    }

    func resumeSession() {
        sessionManager.startSession()
    }

    func resetSession() {
        sessionManager.resetSession()
        wallDetectionManager.reset()
        materialManager.reset()
        resetSelection()
        transitionTo(.scanning)
    }
}

// MARK: - ARSessionManagerDelegate

extension MainViewModel: ARSessionManagerDelegate {
    func arSessionManager(_ manager: ARSessionManager, didUpdateFrame frame: ARFrame) {
        // Process occlusion
        occlusionManager.processFrame(frame)

        // Process lighting
        lightingManager.processLightEstimate(frame.lightEstimate)

        // Update tracking state
        let isTracking = frame.camera.trackingState == .normal
        if isTracking != isTrackingReady {
            isTrackingReady = isTracking
            showCoachingOverlay = !isTracking
        }
    }

    func arSessionManager(_ manager: ARSessionManager, didAddAnchors anchors: [ARAnchor]) {
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                wallDetectionManager.processPlaneAnchor(planeAnchor)
            } else if let meshAnchor = anchor as? ARMeshAnchor {
                wallDetectionManager.processMeshAnchor(meshAnchor)
            } else if let probeAnchor = anchor as? AREnvironmentProbeAnchor {
                lightingManager.processEnvironmentProbeAnchor(probeAnchor)
            }
        }
    }

    func arSessionManager(_ manager: ARSessionManager, didUpdateAnchors anchors: [ARAnchor]) {
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                wallDetectionManager.processPlaneAnchor(planeAnchor)
            } else if let meshAnchor = anchor as? ARMeshAnchor {
                wallDetectionManager.processMeshAnchor(meshAnchor)
            } else if let probeAnchor = anchor as? AREnvironmentProbeAnchor {
                lightingManager.processEnvironmentProbeAnchor(probeAnchor)
            }
        }
    }

    func arSessionManager(_ manager: ARSessionManager, didRemoveAnchors anchors: [ARAnchor]) {
        for anchor in anchors {
            wallDetectionManager.removeWall(anchorID: anchor.identifier)
        }
    }

    func arSessionManager(_ manager: ARSessionManager, trackingStateChanged state: ARCamera.TrackingState) {
        switch state {
        case .normal:
            isTrackingReady = true
            showCoachingOverlay = false
            errorMessage = nil
        case .notAvailable:
            isTrackingReady = false
            showCoachingOverlay = true
            errorMessage = "AR tracking not available"
        case .limited(let reason):
            isTrackingReady = false
            showCoachingOverlay = true
            switch reason {
            case .excessiveMotion:
                errorMessage = "Slow down movement"
            case .insufficientFeatures:
                errorMessage = "Point at a textured surface"
            case .initializing:
                errorMessage = "Initializing AR..."
            case .relocalizing:
                errorMessage = "Relocalizing..."
            @unknown default:
                errorMessage = "Limited tracking"
            }
        }
    }

    func arSessionManager(_ manager: ARSessionManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }

    func arSessionManagerWasInterrupted(_ manager: ARSessionManager) {
        errorMessage = "Session interrupted"
    }

    func arSessionManagerInterruptionEnded(_ manager: ARSessionManager) {
        errorMessage = nil
    }
}
