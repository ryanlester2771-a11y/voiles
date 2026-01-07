import ARKit
import RealityKit
import Combine

/// Manages wall detection and mesh generation for AR surfaces
@MainActor
final class WallDetectionManager: ObservableObject {
    /// Currently detected walls
    @Published private(set) var detectedWalls: [DetectedWall] = []

    /// Currently highlighted wall ID
    @Published var highlightedWallID: UUID?

    /// Minimum wall area to consider (in square meters)
    var minimumWallArea: Float = 0.5

    /// The AR view reference
    private weak var arView: ARView?

    /// Entity for wall highlight visualization
    private var wallHighlightEntities: [UUID: ModelEntity] = [:]

    /// Root anchor for wall visualizations
    private var wallAnchor: AnchorEntity?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Setup

    func setup(with arView: ARView) {
        self.arView = arView
        setupWallAnchor()
    }

    private func setupWallAnchor() {
        guard let arView = arView else { return }

        let anchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(anchor)
        wallAnchor = anchor
    }

    // MARK: - Wall Detection

    func processPlaneAnchor(_ anchor: ARPlaneAnchor) {
        guard anchor.alignment == .vertical else { return }

        let extent = SIMD3<Float>(anchor.planeExtent.width, anchor.planeExtent.height, 0)
        let center = SIMD3<Float>(anchor.center.x, anchor.center.y, anchor.center.z)

        // Filter out small surfaces
        let area = extent.x * extent.y
        guard area >= minimumWallArea else { return }

        let wall = DetectedWall(
            anchorID: anchor.identifier,
            center: center,
            extent: extent,
            transform: anchor.transform,
            classification: .wall
        )

        updateWall(wall)
        updateWallVisualization(for: wall)
    }

    func processMeshAnchor(_ anchor: ARMeshAnchor) {
        // Process mesh classifications if available
        guard let classifications = anchor.geometry.classification else { return }

        // Find wall faces in the mesh
        let wallFaces = extractWallFaces(from: anchor, classifications: classifications)

        for (index, face) in wallFaces.enumerated() {
            let wallID = UUID(uuidString: "\(anchor.identifier.uuidString)-\(index)") ?? UUID()
            let wall = DetectedWall(
                id: wallID,
                anchorID: anchor.identifier,
                center: face.center,
                extent: face.extent,
                transform: anchor.transform,
                classification: .wall,
                vertices: face.vertices
            )

            updateWall(wall)
        }
    }

    private func extractWallFaces(
        from anchor: ARMeshAnchor,
        classifications: ARGeometrySource
    ) -> [(center: SIMD3<Float>, extent: SIMD3<Float>, vertices: [SIMD3<Float>])] {
        var wallFaces: [(center: SIMD3<Float>, extent: SIMD3<Float>, vertices: [SIMD3<Float>])] = []

        let geometry = anchor.geometry
        let vertices = geometry.vertices
        let faces = geometry.faces

        // Group vertices by classification
        var wallVertices: [SIMD3<Float>] = []

        for faceIndex in 0..<faces.count {
            let classificationIndex = faceIndex
            guard classificationIndex < classifications.count else { continue }

            let classification = classifications.buffer.contents()
                .advanced(by: classificationIndex * MemoryLayout<UInt8>.stride)
                .assumingMemoryBound(to: UInt8.self)
                .pointee

            guard ARMeshClassification(rawValue: Int(classification)) == .wall else { continue }

            // Get face vertices
            let indexOffset = faceIndex * 3
            for i in 0..<3 {
                let vertexIndex = faces.buffer.contents()
                    .advanced(by: (indexOffset + i) * MemoryLayout<UInt32>.stride)
                    .assumingMemoryBound(to: UInt32.self)
                    .pointee

                let vertexOffset = Int(vertexIndex) * vertices.stride
                let vertexPointer = vertices.buffer.contents().advanced(by: vertexOffset)
                let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee

                wallVertices.append(vertex)
            }
        }

        guard !wallVertices.isEmpty else { return wallFaces }

        // Calculate bounding box
        var minPoint = SIMD3<Float>(repeating: .infinity)
        var maxPoint = SIMD3<Float>(repeating: -.infinity)

        for vertex in wallVertices {
            minPoint = min(minPoint, vertex)
            maxPoint = max(maxPoint, vertex)
        }

        let center = (minPoint + maxPoint) / 2
        let extent = maxPoint - minPoint

        wallFaces.append((center: center, extent: extent, vertices: wallVertices))

        return wallFaces
    }

    private func updateWall(_ wall: DetectedWall) {
        if let index = detectedWalls.firstIndex(where: { $0.anchorID == wall.anchorID }) {
            detectedWalls[index] = wall
        } else {
            detectedWalls.append(wall)
        }
    }

    func removeWall(anchorID: UUID) {
        detectedWalls.removeAll { $0.anchorID == anchorID }
        removeWallVisualization(for: anchorID)
    }

    // MARK: - Wall Visualization

    private func updateWallVisualization(for wall: DetectedWall) {
        guard let anchor = wallAnchor else { return }

        // Remove existing visualization
        if let existingEntity = wallHighlightEntities[wall.id] {
            existingEntity.removeFromParent()
        }

        // Create shimmer/grid visualization mesh
        let mesh = MeshResource.generatePlane(
            width: wall.extent.x,
            depth: wall.extent.y
        )

        var material = SimpleMaterial()
        material.color = .init(
            tint: UIColor(white: 1.0, alpha: 0.15),
            texture: nil
        )
        material.metallic = .float(0.0)
        material.roughness = .float(1.0)

        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.transform = Transform(matrix: wall.transform)
        entity.position = wall.center

        // Rotate to face outward (planes are horizontal by default)
        entity.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])

        anchor.addChild(entity)
        wallHighlightEntities[wall.id] = entity
    }

    private func removeWallVisualization(for anchorID: UUID) {
        let wallsToRemove = detectedWalls.filter { $0.anchorID == anchorID }
        for wall in wallsToRemove {
            wallHighlightEntities[wall.id]?.removeFromParent()
            wallHighlightEntities.removeValue(forKey: wall.id)
        }
    }

    func highlightWall(_ wallID: UUID, highlighted: Bool) {
        guard let entity = wallHighlightEntities[wallID] else { return }

        var material = SimpleMaterial()
        material.color = .init(
            tint: highlighted ?
                UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.4) :
                UIColor(white: 1.0, alpha: 0.15),
            texture: nil
        )
        material.metallic = .float(0.0)
        material.roughness = .float(1.0)

        entity.model?.materials = [material]
        highlightedWallID = highlighted ? wallID : nil
    }

    func clearHighlights() {
        for wallID in wallHighlightEntities.keys {
            highlightWall(wallID, highlighted: false)
        }
        highlightedWallID = nil
    }

    // MARK: - Hit Testing

    func findWall(at point: CGPoint, in arView: ARView) -> DetectedWall? {
        let results = arView.raycast(
            from: point,
            allowing: .existingPlaneGeometry,
            alignment: .vertical
        )

        guard let result = results.first,
              let anchor = result.anchor as? ARPlaneAnchor else {
            return nil
        }

        return detectedWalls.first { $0.anchorID == anchor.identifier }
    }

    // MARK: - Cleanup

    func reset() {
        detectedWalls.removeAll()
        for entity in wallHighlightEntities.values {
            entity.removeFromParent()
        }
        wallHighlightEntities.removeAll()
        highlightedWallID = nil
    }
}
