import Foundation
import UIKit

/// Represents a decorative wall style with PBR material properties
struct WallStyle: Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let category: StyleCategory
    let thumbnailName: String

    /// Base color/albedo texture name
    let albedoTexture: String

    /// Normal map texture name for surface detail
    let normalTexture: String?

    /// Roughness map texture name (white = rough, black = smooth)
    let roughnessTexture: String?

    /// Metallic map texture name
    let metallicTexture: String?

    /// Base roughness value (0.0 = mirror, 1.0 = matte)
    let baseRoughness: Float

    /// Base metallic value (0.0 = dielectric, 1.0 = metal)
    let baseMetallic: Float

    /// Default tiling scale
    let defaultScale: Float

    init(
        id: UUID = UUID(),
        name: String,
        category: StyleCategory,
        thumbnailName: String,
        albedoTexture: String,
        normalTexture: String? = nil,
        roughnessTexture: String? = nil,
        metallicTexture: String? = nil,
        baseRoughness: Float = 0.5,
        baseMetallic: Float = 0.0,
        defaultScale: Float = 1.0
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.thumbnailName = thumbnailName
        self.albedoTexture = albedoTexture
        self.normalTexture = normalTexture
        self.roughnessTexture = roughnessTexture
        self.metallicTexture = metallicTexture
        self.baseRoughness = baseRoughness
        self.baseMetallic = baseMetallic
        self.defaultScale = defaultScale
    }
}

/// Categories for organizing wall styles
enum StyleCategory: String, CaseIterable, Identifiable {
    case geometric = "Geometric"
    case floral = "Floral"
    case abstract = "Abstract"
    case textured = "Textured"
    case classic = "Classic"
    case modern = "Modern"

    var id: String { rawValue }
}

// MARK: - Sample Styles

extension WallStyle {
    /// Sample styles for demonstration (replace with actual assets)
    static let sampleStyles: [WallStyle] = [
        // Geometric
        WallStyle(
            name: "Hexagon Grid",
            category: .geometric,
            thumbnailName: "style_hexagon_thumb",
            albedoTexture: "style_hexagon_albedo",
            normalTexture: "style_hexagon_normal",
            baseRoughness: 0.6,
            defaultScale: 1.0
        ),
        WallStyle(
            name: "Diamond Pattern",
            category: .geometric,
            thumbnailName: "style_diamond_thumb",
            albedoTexture: "style_diamond_albedo",
            normalTexture: "style_diamond_normal",
            baseRoughness: 0.5,
            defaultScale: 0.8
        ),
        WallStyle(
            name: "Chevron",
            category: .geometric,
            thumbnailName: "style_chevron_thumb",
            albedoTexture: "style_chevron_albedo",
            baseRoughness: 0.4,
            defaultScale: 1.2
        ),

        // Floral
        WallStyle(
            name: "Rose Garden",
            category: .floral,
            thumbnailName: "style_rose_thumb",
            albedoTexture: "style_rose_albedo",
            normalTexture: "style_rose_normal",
            baseRoughness: 0.7,
            defaultScale: 0.6
        ),
        WallStyle(
            name: "Tropical Leaves",
            category: .floral,
            thumbnailName: "style_tropical_thumb",
            albedoTexture: "style_tropical_albedo",
            baseRoughness: 0.5,
            defaultScale: 0.7
        ),
        WallStyle(
            name: "Botanical",
            category: .floral,
            thumbnailName: "style_botanical_thumb",
            albedoTexture: "style_botanical_albedo",
            normalTexture: "style_botanical_normal",
            baseRoughness: 0.6,
            defaultScale: 0.8
        ),

        // Abstract
        WallStyle(
            name: "Watercolor Wash",
            category: .abstract,
            thumbnailName: "style_watercolor_thumb",
            albedoTexture: "style_watercolor_albedo",
            baseRoughness: 0.8,
            defaultScale: 0.5
        ),
        WallStyle(
            name: "Marble Swirl",
            category: .abstract,
            thumbnailName: "style_marble_thumb",
            albedoTexture: "style_marble_albedo",
            normalTexture: "style_marble_normal",
            roughnessTexture: "style_marble_roughness",
            baseRoughness: 0.3,
            defaultScale: 0.6
        ),
        WallStyle(
            name: "Ink Splash",
            category: .abstract,
            thumbnailName: "style_ink_thumb",
            albedoTexture: "style_ink_albedo",
            baseRoughness: 0.5,
            defaultScale: 0.7
        ),

        // Textured
        WallStyle(
            name: "Linen Weave",
            category: .textured,
            thumbnailName: "style_linen_thumb",
            albedoTexture: "style_linen_albedo",
            normalTexture: "style_linen_normal",
            roughnessTexture: "style_linen_roughness",
            baseRoughness: 0.9,
            defaultScale: 2.0
        ),
        WallStyle(
            name: "Brushed Metal",
            category: .textured,
            thumbnailName: "style_brushedmetal_thumb",
            albedoTexture: "style_brushedmetal_albedo",
            normalTexture: "style_brushedmetal_normal",
            roughnessTexture: "style_brushedmetal_roughness",
            baseRoughness: 0.4,
            baseMetallic: 0.9,
            defaultScale: 1.5
        ),
        WallStyle(
            name: "Concrete",
            category: .textured,
            thumbnailName: "style_concrete_thumb",
            albedoTexture: "style_concrete_albedo",
            normalTexture: "style_concrete_normal",
            roughnessTexture: "style_concrete_roughness",
            baseRoughness: 0.95,
            defaultScale: 1.0
        ),

        // Classic
        WallStyle(
            name: "Damask",
            category: .classic,
            thumbnailName: "style_damask_thumb",
            albedoTexture: "style_damask_albedo",
            normalTexture: "style_damask_normal",
            baseRoughness: 0.6,
            defaultScale: 0.8
        ),
        WallStyle(
            name: "Toile",
            category: .classic,
            thumbnailName: "style_toile_thumb",
            albedoTexture: "style_toile_albedo",
            baseRoughness: 0.7,
            defaultScale: 0.6
        ),
        WallStyle(
            name: "Herringbone",
            category: .classic,
            thumbnailName: "style_herringbone_thumb",
            albedoTexture: "style_herringbone_albedo",
            normalTexture: "style_herringbone_normal",
            baseRoughness: 0.5,
            defaultScale: 1.0
        ),

        // Modern
        WallStyle(
            name: "Minimalist Lines",
            category: .modern,
            thumbnailName: "style_lines_thumb",
            albedoTexture: "style_lines_albedo",
            baseRoughness: 0.4,
            defaultScale: 1.0
        ),
        WallStyle(
            name: "Color Block",
            category: .modern,
            thumbnailName: "style_colorblock_thumb",
            albedoTexture: "style_colorblock_albedo",
            baseRoughness: 0.5,
            defaultScale: 0.5
        ),
        WallStyle(
            name: "Terrazzo",
            category: .modern,
            thumbnailName: "style_terrazzo_thumb",
            albedoTexture: "style_terrazzo_albedo",
            normalTexture: "style_terrazzo_normal",
            baseRoughness: 0.4,
            defaultScale: 0.8
        ),
    ]
}
