import ARKit
import RealityKit
import Combine

/// Manages the AR session lifecycle and configuration
@MainActor
final class ARSessionManager: NSObject, ObservableObject {
    /// The AR view instance
    private(set) var arView: ARView?

    /// Whether the session is currently running
    @Published private(set) var isSessionRunning = false

    /// Current tracking state
    @Published private(set) var trackingState: ARCamera.TrackingState = .notAvailable

    /// Whether LiDAR is available
    @Published private(set) var isLiDARAvailable = false

    /// Whether scene reconstruction is available
    @Published private(set) var isSceneReconstructionSupported = false

    /// Delegate for session events
    weak var delegate: ARSessionManagerDelegate?

    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        checkDeviceCapabilities()
    }

    // MARK: - Device Capabilities

    private func checkDeviceCapabilities() {
        isLiDARAvailable = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        isSceneReconstructionSupported = ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
    }

    // MARK: - Session Management

    func setupARView(_ arView: ARView) {
        self.arView = arView
        arView.session.delegate = self
        configureARView(arView)
    }

    private func configureARView(_ arView: ARView) {
        // Configure rendering options
        arView.renderOptions = [
            .disablePersonOcclusion,
            .disableDepthOfField,
            .disableMotionBlur
        ]

        // Enable environment texturing for realistic lighting
        arView.environment.sceneUnderstanding.options = []

        if isSceneReconstructionSupported {
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
            arView.environment.sceneUnderstanding.options.insert(.receivesLighting)
        }

        // Configure debug options (disable for production)
        #if DEBUG
        // arView.debugOptions = [.showSceneUnderstanding, .showAnchorOrigins]
        #endif
    }

    func startSession() {
        guard let arView = arView else { return }

        let configuration = createConfiguration()
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
    }

    func pauseSession() {
        arView?.session.pause()
        isSessionRunning = false
    }

    func resetSession() {
        guard let arView = arView else { return }

        let configuration = createConfiguration()
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    private func createConfiguration() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()

        // Enable vertical plane detection for walls
        configuration.planeDetection = [.vertical]

        // Enable environment texturing for realistic lighting
        configuration.environmentTexturing = .automatic

        // Enable light estimation
        configuration.isLightEstimationEnabled = true

        // Enable scene reconstruction if LiDAR is available
        if isSceneReconstructionSupported {
            configuration.sceneReconstruction = .meshWithClassification
        }

        // Enable frame semantics for depth and segmentation
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }

        return configuration
    }

    // MARK: - Hit Testing

    func performHitTest(at point: CGPoint) -> ARRaycastResult? {
        guard let arView = arView else { return nil }

        let results = arView.raycast(
            from: point,
            allowing: .existingPlaneGeometry,
            alignment: .vertical
        )

        return results.first
    }

    func performEntityHitTest(at point: CGPoint) -> Entity? {
        guard let arView = arView else { return nil }
        return arView.entity(at: point)
    }
}

// MARK: - ARSessionDelegate

extension ARSessionManager: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in
            trackingState = frame.camera.trackingState
            delegate?.arSessionManager(self, didUpdateFrame: frame)
        }
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        Task { @MainActor in
            delegate?.arSessionManager(self, didAddAnchors: anchors)
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        Task { @MainActor in
            delegate?.arSessionManager(self, didUpdateAnchors: anchors)
        }
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        Task { @MainActor in
            delegate?.arSessionManager(self, didRemoveAnchors: anchors)
        }
    }

    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        Task { @MainActor in
            trackingState = camera.trackingState
            delegate?.arSessionManager(self, trackingStateChanged: camera.trackingState)
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            isSessionRunning = false
            delegate?.arSessionManagerWasInterrupted(self)
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in
            resetSession()
            delegate?.arSessionManagerInterruptionEnded(self)
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            delegate?.arSessionManager(self, didFailWithError: error)
        }
    }
}

// MARK: - Delegate Protocol

@MainActor
protocol ARSessionManagerDelegate: AnyObject {
    func arSessionManager(_ manager: ARSessionManager, didUpdateFrame frame: ARFrame)
    func arSessionManager(_ manager: ARSessionManager, didAddAnchors anchors: [ARAnchor])
    func arSessionManager(_ manager: ARSessionManager, didUpdateAnchors anchors: [ARAnchor])
    func arSessionManager(_ manager: ARSessionManager, didRemoveAnchors anchors: [ARAnchor])
    func arSessionManager(_ manager: ARSessionManager, trackingStateChanged state: ARCamera.TrackingState)
    func arSessionManager(_ manager: ARSessionManager, didFailWithError error: Error)
    func arSessionManagerWasInterrupted(_ manager: ARSessionManager)
    func arSessionManagerInterruptionEnded(_ manager: ARSessionManager)
}

// MARK: - Default Implementations

extension ARSessionManagerDelegate {
    func arSessionManager(_ manager: ARSessionManager, didUpdateFrame frame: ARFrame) {}
    func arSessionManager(_ manager: ARSessionManager, didAddAnchors anchors: [ARAnchor]) {}
    func arSessionManager(_ manager: ARSessionManager, didUpdateAnchors anchors: [ARAnchor]) {}
    func arSessionManager(_ manager: ARSessionManager, didRemoveAnchors anchors: [ARAnchor]) {}
    func arSessionManager(_ manager: ARSessionManager, trackingStateChanged state: ARCamera.TrackingState) {}
    func arSessionManager(_ manager: ARSessionManager, didFailWithError error: Error) {}
    func arSessionManagerWasInterrupted(_ manager: ARSessionManager) {}
    func arSessionManagerInterruptionEnded(_ manager: ARSessionManager) {}
}
