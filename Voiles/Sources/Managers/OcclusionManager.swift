import ARKit
import RealityKit
import CoreImage
import Metal

/// Manages occlusion and depth handling for realistic AR rendering
@MainActor
final class OcclusionManager: ObservableObject {
    /// Whether occlusion is enabled
    @Published var isOcclusionEnabled = true

    /// Whether person segmentation is enabled
    @Published var isPersonSegmentationEnabled = true

    /// Current depth map (for debugging/visualization)
    @Published private(set) var currentDepthMap: CVPixelBuffer?

    /// Current segmentation mask
    @Published private(set) var currentSegmentationMask: CVPixelBuffer?

    private weak var arView: ARView?
    private let ciContext = CIContext()

    // MARK: - Setup

    func setup(with arView: ARView) {
        self.arView = arView
        configureOcclusion()
    }

    private func configureOcclusion() {
        guard let arView = arView else { return }

        // Enable scene understanding for occlusion
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
            arView.environment.sceneUnderstanding.options.insert(.receivesLighting)
        }

        // Configure person occlusion if supported
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            arView.renderOptions.remove(.disablePersonOcclusion)
        }
    }

    // MARK: - Frame Processing

    func processFrame(_ frame: ARFrame) {
        // Extract depth map
        if let sceneDepth = frame.sceneDepth {
            currentDepthMap = sceneDepth.depthMap
        } else if let smoothedSceneDepth = frame.smoothedSceneDepth {
            currentDepthMap = smoothedSceneDepth.depthMap
        }

        // Extract segmentation mask
        if let segmentationBuffer = frame.segmentationBuffer {
            currentSegmentationMask = segmentationBuffer
        }
    }

    // MARK: - Depth Analysis

    func getDepthAtPoint(_ point: CGPoint, frameSize: CGSize) -> Float? {
        guard let depthMap = currentDepthMap else { return nil }

        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)

        // Convert screen point to depth buffer coordinates
        let x = Int(point.x / frameSize.width * CGFloat(depthWidth))
        let y = Int(point.y / frameSize.height * CGFloat(depthHeight))

        guard x >= 0, x < depthWidth, y >= 0, y < depthHeight else { return nil }

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return nil }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let offset = y * bytesPerRow + x * MemoryLayout<Float32>.stride
        let depthPointer = baseAddress.advanced(by: offset).assumingMemoryBound(to: Float32.self)

        return depthPointer.pointee
    }

    // MARK: - Segmentation

    func isPointOnPerson(_ point: CGPoint, frameSize: CGSize) -> Bool {
        guard let segmentationMask = currentSegmentationMask else { return false }

        let maskWidth = CVPixelBufferGetWidth(segmentationMask)
        let maskHeight = CVPixelBufferGetHeight(segmentationMask)

        let x = Int(point.x / frameSize.width * CGFloat(maskWidth))
        let y = Int(point.y / frameSize.height * CGFloat(maskHeight))

        guard x >= 0, x < maskWidth, y >= 0, y < maskHeight else { return false }

        CVPixelBufferLockBaseAddress(segmentationMask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(segmentationMask, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(segmentationMask) else { return false }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(segmentationMask)
        let offset = y * bytesPerRow + x
        let maskValue = baseAddress.advanced(by: offset).assumingMemoryBound(to: UInt8.self).pointee

        return maskValue > 128
    }

    // MARK: - Occlusion Mesh Generation

    func createOcclusionMesh(from anchor: ARMeshAnchor) -> MeshResource? {
        let geometry = anchor.geometry
        let vertices = geometry.vertices
        let faces = geometry.faces

        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        // Extract vertex positions
        for i in 0..<vertices.count {
            let vertexPointer = vertices.buffer.contents()
                .advanced(by: i * vertices.stride)
                .assumingMemoryBound(to: SIMD3<Float>.self)
            positions.append(vertexPointer.pointee)
        }

        // Extract face indices
        for i in 0..<faces.count {
            let indexPointer = faces.buffer.contents()
                .advanced(by: i * 3 * MemoryLayout<UInt32>.stride)
                .assumingMemoryBound(to: UInt32.self)

            for j in 0..<3 {
                indices.append(indexPointer.advanced(by: j).pointee)
            }
        }

        // Create mesh descriptor
        var descriptor = MeshDescriptor(name: "OcclusionMesh")
        descriptor.positions = MeshBuffer(positions)
        descriptor.primitives = .triangles(indices)

        return try? MeshResource.generate(from: [descriptor])
    }

    // MARK: - Settings

    func setOcclusionEnabled(_ enabled: Bool) {
        isOcclusionEnabled = enabled

        guard let arView = arView else { return }

        if enabled {
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
        } else {
            arView.environment.sceneUnderstanding.options.remove(.occlusion)
        }
    }

    func setPersonSegmentationEnabled(_ enabled: Bool) {
        isPersonSegmentationEnabled = enabled

        guard let arView = arView else { return }

        if enabled {
            arView.renderOptions.remove(.disablePersonOcclusion)
        } else {
            arView.renderOptions.insert(.disablePersonOcclusion)
        }
    }

    // MARK: - Cleanup

    func reset() {
        currentDepthMap = nil
        currentSegmentationMask = nil
    }
}
