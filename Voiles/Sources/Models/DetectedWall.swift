import Foundation
import ARKit
import simd

/// Represents a detected wall surface in the AR scene
struct DetectedWall: Identifiable, Equatable {
    let id: UUID
    let anchorID: UUID
    let center: SIMD3<Float>
    let extent: SIMD3<Float>
    let transform: simd_float4x4
    let classification: WallClassification
    let vertices: [SIMD3<Float>]
    let timestamp: TimeInterval

    /// Whether this wall is currently highlighted for selection
    var isHighlighted: Bool = false

    /// Area of the wall in square meters
    var area: Float {
        extent.x * extent.y
    }

    /// World position of the wall center
    var worldPosition: SIMD3<Float> {
        SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }

    /// Normal vector of the wall surface
    var normal: SIMD3<Float> {
        SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
    }

    init(
        id: UUID = UUID(),
        anchorID: UUID,
        center: SIMD3<Float>,
        extent: SIMD3<Float>,
        transform: simd_float4x4,
        classification: WallClassification = .wall,
        vertices: [SIMD3<Float>] = [],
        timestamp: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.anchorID = anchorID
        self.center = center
        self.extent = extent
        self.transform = transform
        self.classification = classification
        self.vertices = vertices
        self.timestamp = timestamp
    }

    static func == (lhs: DetectedWall, rhs: DetectedWall) -> Bool {
        lhs.id == rhs.id
    }
}

/// Classification of detected surfaces
enum WallClassification: String {
    case wall
    case floor
    case ceiling
    case door
    case window
    case table
    case seat
    case unknown

    init(from arClassification: ARMeshClassification) {
        switch arClassification {
        case .wall:
            self = .wall
        case .floor:
            self = .floor
        case .ceiling:
            self = .ceiling
        case .door:
            self = .door
        case .window:
            self = .window
        case .table:
            self = .table
        case .seat:
            self = .seat
        default:
            self = .unknown
        }
    }
}

/// Represents a wall that has been selected and has a style applied
struct StyledWall: Identifiable {
    let id: UUID
    let wall: DetectedWall
    var style: WallStyle
    var uvScale: Float
    var offset: SIMD2<Float>

    init(wall: DetectedWall, style: WallStyle) {
        self.id = wall.id
        self.wall = wall
        self.style = style
        self.uvScale = style.defaultScale
        self.offset = .zero
    }
}
