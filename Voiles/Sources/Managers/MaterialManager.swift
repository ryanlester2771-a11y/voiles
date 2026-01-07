import RealityKit
import ARKit
import UIKit
import Combine

/// Manages PBR material creation and application for wall styles
@MainActor
final class MaterialManager: ObservableObject {
    /// Cache of loaded materials
    private var materialCache: [UUID: Material] = [:]

    /// Cache of loaded textures
    private var textureCache: [String: TextureResource] = [:]

    /// Currently applied style entities
    private var appliedStyleEntities: [UUID: ModelEntity] = []

    /// Reference to AR view
    private weak var arView: ARView?

    /// Style anchor for applied materials
    private var styleAnchor: AnchorEntity?

    /// Loading state
    @Published private(set) var isLoading = false

    private var loadingTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - Setup

    func setup(with arView: ARView) {
        self.arView = arView
        setupStyleAnchor()
    }

    private func setupStyleAnchor() {
        guard let arView = arView else { return }

        let anchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(anchor)
        styleAnchor = anchor
    }

    // MARK: - Material Creation

    func createMaterial(for style: WallStyle) async throws -> Material {
        // Check cache first
        if let cached = materialCache[style.id] {
            return cached
        }

        isLoading = true
        defer { isLoading = false }

        var material = PhysicallyBasedMaterial()

        // Load albedo/base color texture
        if let albedoTexture = await loadTexture(named: style.albedoTexture) {
            material.baseColor = .init(texture: .init(albedoTexture))
        } else {
            // Fallback to a procedural color
            material.baseColor = .init(tint: .white)
        }

        // Load normal map
        if let normalName = style.normalTexture,
           let normalTexture = await loadTexture(named: normalName) {
            material.normal = .init(texture: .init(normalTexture))
        }

        // Load roughness map or use base value
        if let roughnessName = style.roughnessTexture,
           let roughnessTexture = await loadTexture(named: roughnessName) {
            material.roughness = .init(texture: .init(roughnessTexture))
        } else {
            material.roughness = .init(floatLiteral: style.baseRoughness)
        }

        // Load metallic map or use base value
        if let metallicName = style.metallicTexture,
           let metallicTexture = await loadTexture(named: metallicName) {
            material.metallic = .init(texture: .init(metallicTexture))
        } else {
            material.metallic = .init(floatLiteral: style.baseMetallic)
        }

        // Configure texture coordinates for tiling
        material.textureCoordinateTransform = .init(
            scale: SIMD2<Float>(repeating: style.defaultScale),
            rotation: 0
        )

        // Cache the material
        materialCache[style.id] = material

        return material
    }

    func createSimpleMaterial(for style: WallStyle, tint: UIColor = .white) -> SimpleMaterial {
        var material = SimpleMaterial()
        material.color = .init(tint: tint, texture: nil)
        material.metallic = .float(style.baseMetallic)
        material.roughness = .float(style.baseRoughness)
        return material
    }

    // MARK: - Texture Loading

    private func loadTexture(named name: String) async -> TextureResource? {
        // Check cache first
        if let cached = textureCache[name] {
            return cached
        }

        // Try loading from asset catalog
        if let image = UIImage(named: name),
           let cgImage = image.cgImage {
            do {
                let texture = try await TextureResource.generate(
                    from: cgImage,
                    options: .init(semantic: .color)
                )
                textureCache[name] = texture
                return texture
            } catch {
                print("Failed to load texture \(name): \(error)")
            }
        }

        // Try loading from bundle
        if let url = Bundle.main.url(forResource: name, withExtension: "png") ??
                     Bundle.main.url(forResource: name, withExtension: "jpg") {
            do {
                let texture = try await TextureResource(contentsOf: url)
                textureCache[name] = texture
                return texture
            } catch {
                print("Failed to load texture from URL \(url): \(error)")
            }
        }

        return nil
    }

    // MARK: - Style Application

    func applyStyle(
        _ style: WallStyle,
        to wall: DetectedWall,
        uvScale: Float = 1.0,
        offset: SIMD2<Float> = .zero
    ) async {
        guard let anchor = styleAnchor else { return }

        // Cancel any existing loading task for this wall
        loadingTasks[wall.id]?.cancel()

        let task = Task {
            // Remove existing style entity
            removeStyle(from: wall.id)

            guard !Task.isCancelled else { return }

            // Create the style mesh
            let mesh = MeshResource.generatePlane(
                width: wall.extent.x,
                depth: wall.extent.y
            )

            // Create material
            let material: Material
            do {
                material = try await createMaterial(for: style)
            } catch {
                print("Failed to create material: \(error)")
                material = createSimpleMaterial(for: style)
            }

            guard !Task.isCancelled else { return }

            // Create entity
            let entity = ModelEntity(mesh: mesh, materials: [material])

            // Position and orient the entity
            entity.transform = Transform(matrix: wall.transform)
            entity.position = wall.center

            // Rotate to face outward
            entity.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])

            // Apply UV scaling
            await updateUVScale(entity, scale: uvScale * style.defaultScale)

            // Enable shadow receiving
            entity.components.set(GroundingShadowComponent(castsShadow: false, receivesShadow: true))

            anchor.addChild(entity)
            appliedStyleEntities[wall.id] = entity
        }

        loadingTasks[wall.id] = task
        await task.value
        loadingTasks.removeValue(forKey: wall.id)
    }

    func updateUVScale(_ entity: ModelEntity, scale: Float) async {
        guard var material = entity.model?.materials.first as? PhysicallyBasedMaterial else {
            return
        }

        material.textureCoordinateTransform = .init(
            scale: SIMD2<Float>(repeating: scale),
            rotation: 0
        )

        entity.model?.materials = [material]
    }

    func updateStyleTransform(
        for wallID: UUID,
        scale: Float,
        offset: SIMD2<Float>
    ) {
        guard let entity = appliedStyleEntities[wallID],
              var material = entity.model?.materials.first as? PhysicallyBasedMaterial else {
            return
        }

        material.textureCoordinateTransform = .init(
            offset: offset,
            scale: SIMD2<Float>(repeating: scale),
            rotation: 0
        )

        entity.model?.materials = [material]
    }

    func removeStyle(from wallID: UUID) {
        appliedStyleEntities[wallID]?.removeFromParent()
        appliedStyleEntities.removeValue(forKey: wallID)
    }

    // MARK: - Entity Access

    func getStyleEntity(for wallID: UUID) -> ModelEntity? {
        return appliedStyleEntities[wallID]
    }

    // MARK: - Cache Management

    func clearCache() {
        materialCache.removeAll()
        textureCache.removeAll()
    }

    func preloadStyles(_ styles: [WallStyle]) async {
        await withTaskGroup(of: Void.self) { group in
            for style in styles {
                group.addTask {
                    _ = try? await self.createMaterial(for: style)
                }
            }
        }
    }

    // MARK: - Cleanup

    func reset() {
        for task in loadingTasks.values {
            task.cancel()
        }
        loadingTasks.removeAll()

        for entity in appliedStyleEntities.values {
            entity.removeFromParent()
        }
        appliedStyleEntities.removeAll()
    }
}
