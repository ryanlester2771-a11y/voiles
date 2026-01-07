import ARKit
import RealityKit
import Combine

/// Manages dynamic lighting and environment probes for realistic AR rendering
@MainActor
final class LightingManager: ObservableObject {
    /// Current ambient light intensity (0-2000 lumens)
    @Published private(set) var ambientIntensity: CGFloat = 1000

    /// Current ambient color temperature (Kelvin)
    @Published private(set) var colorTemperature: CGFloat = 6500

    /// Current light direction estimate
    @Published private(set) var primaryLightDirection: SIMD3<Float>?

    /// Whether dynamic lighting is enabled
    @Published var isDynamicLightingEnabled = true

    private weak var arView: ARView?
    private var environmentProbeAnchors: [AREnvironmentProbeAnchor] = []
    private var directionalLight: DirectionalLight?
    private var lightAnchor: AnchorEntity?

    // MARK: - Setup

    func setup(with arView: ARView) {
        self.arView = arView
        configureLighting()
        setupLightAnchor()
    }

    private func configureLighting() {
        guard let arView = arView else { return }

        // Enable automatic environment lighting
        arView.environment.lighting.intensityExponent = 1.0

        // Configure scene understanding for lighting
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            arView.environment.sceneUnderstanding.options.insert(.receivesLighting)
        }
    }

    private func setupLightAnchor() {
        guard let arView = arView else { return }

        let anchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(anchor)
        lightAnchor = anchor

        // Create directional light for shadow casting
        let light = DirectionalLight()
        light.light.intensity = 1000
        light.light.color = .white
        light.shadow = DirectionalLightComponent.Shadow(
            maximumDistance: 10,
            depthBias: 0.001
        )
        light.look(at: .zero, from: SIMD3<Float>(0, 5, 5), relativeTo: nil)

        anchor.addChild(light)
        directionalLight = light
    }

    // MARK: - Light Estimation Processing

    func processLightEstimate(_ lightEstimate: ARLightEstimate?) {
        guard isDynamicLightingEnabled, let estimate = lightEstimate else { return }

        ambientIntensity = estimate.ambientIntensity
        colorTemperature = estimate.ambientColorTemperature

        updateLighting()
    }

    func processDirectionalLightEstimate(_ estimate: ARDirectionalLightEstimate?) {
        guard isDynamicLightingEnabled, let estimate = estimate else { return }

        primaryLightDirection = estimate.primaryLightDirection
        updateDirectionalLight(estimate)
    }

    private func updateLighting() {
        guard let arView = arView else { return }

        // Normalize intensity (ARKit provides 0-2000 lumens)
        let normalizedIntensity = Float(ambientIntensity / 1000.0)
        arView.environment.lighting.intensityExponent = normalizedIntensity

        // Update directional light intensity
        directionalLight?.light.intensity = Float(ambientIntensity)

        // Apply color temperature
        let color = colorFromTemperature(colorTemperature)
        directionalLight?.light.color = color
    }

    private func updateDirectionalLight(_ estimate: ARDirectionalLightEstimate) {
        guard let light = directionalLight else { return }

        // Update light direction
        let direction = estimate.primaryLightDirection
        light.look(
            at: SIMD3<Float>.zero,
            from: -direction * 5,
            relativeTo: nil
        )

        // Update intensity based on estimate
        light.light.intensity = estimate.primaryLightIntensity
    }

    // MARK: - Environment Probes

    func processEnvironmentProbeAnchor(_ anchor: AREnvironmentProbeAnchor) {
        // Store probe for potential custom use
        if !environmentProbeAnchors.contains(where: { $0.identifier == anchor.identifier }) {
            environmentProbeAnchors.append(anchor)
        }

        // RealityKit handles environment probes automatically
        // but we can use this for custom effects
        if let texture = anchor.environmentTexture {
            updateEnvironmentReflections(with: texture)
        }
    }

    private func updateEnvironmentReflections(with texture: MTLTexture) {
        guard let arView = arView else { return }

        // RealityKit uses environment probes automatically
        // This hook is available for custom shader implementations
        do {
            let resource = try EnvironmentResource.generate(fromEquirectangular: texture)
            arView.environment.lighting.resource = resource
        } catch {
            print("Failed to create environment resource: \(error)")
        }
    }

    // MARK: - Color Temperature

    private func colorFromTemperature(_ kelvin: CGFloat) -> UIColor {
        // Convert color temperature to RGB using approximation
        let temp = kelvin / 100.0
        var red: CGFloat
        var green: CGFloat
        var blue: CGFloat

        // Red
        if temp <= 66 {
            red = 255
        } else {
            red = temp - 60
            red = 329.698727446 * pow(red, -0.1332047592)
            red = max(0, min(255, red))
        }

        // Green
        if temp <= 66 {
            green = temp
            green = 99.4708025861 * log(green) - 161.1195681661
        } else {
            green = temp - 60
            green = 288.1221695283 * pow(green, -0.0755148492)
        }
        green = max(0, min(255, green))

        // Blue
        if temp >= 66 {
            blue = 255
        } else if temp <= 19 {
            blue = 0
        } else {
            blue = temp - 10
            blue = 138.5177312231 * log(blue) - 305.0447927307
            blue = max(0, min(255, blue))
        }

        return UIColor(
            red: red / 255.0,
            green: green / 255.0,
            blue: blue / 255.0,
            alpha: 1.0
        )
    }

    // MARK: - Shadow Configuration

    func configureShadowReceiving(for entity: Entity, enabled: Bool) {
        if enabled {
            entity.components.set(GroundingShadowComponent(castsShadow: false, receivesShadow: true))
        } else {
            entity.components.remove(GroundingShadowComponent.self)
        }
    }

    func configureShadowCasting(for entity: Entity, enabled: Bool) {
        if enabled {
            entity.components.set(GroundingShadowComponent(castsShadow: true, receivesShadow: false))
        } else {
            entity.components.remove(GroundingShadowComponent.self)
        }
    }

    // MARK: - Settings

    func setDynamicLightingEnabled(_ enabled: Bool) {
        isDynamicLightingEnabled = enabled

        if !enabled {
            // Reset to default lighting
            ambientIntensity = 1000
            colorTemperature = 6500
            updateLighting()
        }
    }

    // MARK: - Cleanup

    func reset() {
        environmentProbeAnchors.removeAll()
        ambientIntensity = 1000
        colorTemperature = 6500
        primaryLightDirection = nil
        updateLighting()
    }
}
