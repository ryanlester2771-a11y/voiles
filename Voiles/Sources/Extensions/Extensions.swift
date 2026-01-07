import Foundation
import simd
import UIKit
import RealityKit

// MARK: - SIMD Extensions

extension SIMD3 where Scalar == Float {
    /// Distance to another point
    func distance(to other: SIMD3<Float>) -> Float {
        return simd_distance(self, other)
    }

    /// Normalized vector
    var normalized: SIMD3<Float> {
        return simd_normalize(self)
    }

    /// Length of vector
    var length: Float {
        return simd_length(self)
    }
}

extension simd_float4x4 {
    /// Extract position from transform matrix
    var position: SIMD3<Float> {
        return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }

    /// Extract forward direction from transform matrix
    var forward: SIMD3<Float> {
        return SIMD3<Float>(-columns.2.x, -columns.2.y, -columns.2.z)
    }

    /// Extract up direction from transform matrix
    var up: SIMD3<Float> {
        return SIMD3<Float>(columns.1.x, columns.1.y, columns.1.z)
    }

    /// Extract right direction from transform matrix
    var right: SIMD3<Float> {
        return SIMD3<Float>(columns.0.x, columns.0.y, columns.0.z)
    }

    /// Create translation matrix
    static func translation(_ translation: SIMD3<Float>) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1)
        return matrix
    }

    /// Create scale matrix
    static func scale(_ scale: SIMD3<Float>) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.0.x = scale.x
        matrix.columns.1.y = scale.y
        matrix.columns.2.z = scale.z
        return matrix
    }
}

// MARK: - UIColor Extensions

extension UIColor {
    /// Create color from hex string
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }

    /// Convert to SIMD3 for RealityKit
    var simd3: SIMD3<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: nil)
        return SIMD3<Float>(Float(r), Float(g), Float(b))
    }
}

// MARK: - CGPoint Extensions

extension CGPoint {
    /// Distance to another point
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }

    /// Midpoint between two points
    func midpoint(to other: CGPoint) -> CGPoint {
        return CGPoint(x: (x + other.x) / 2, y: (y + other.y) / 2)
    }
}

// MARK: - Array Extensions

extension Array {
    /// Safe subscript that returns nil for out-of-bounds access
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Float Extensions

extension Float {
    /// Clamp value between min and max
    func clamped(to range: ClosedRange<Float>) -> Float {
        return min(max(self, range.lowerBound), range.upperBound)
    }

    /// Linear interpolation
    func lerp(to: Float, t: Float) -> Float {
        return self + (to - self) * t
    }

    /// Convert degrees to radians
    var radians: Float {
        return self * .pi / 180
    }

    /// Convert radians to degrees
    var degrees: Float {
        return self * 180 / .pi
    }
}

// MARK: - Entity Extensions

extension Entity {
    /// Find first child entity of specific type
    func findEntity<T: Entity>(ofType type: T.Type) -> T? {
        if let entity = self as? T {
            return entity
        }

        for child in children {
            if let found = child.findEntity(ofType: type) {
                return found
            }
        }

        return nil
    }

    /// Get all child entities of specific type
    func findEntities<T: Entity>(ofType type: T.Type) -> [T] {
        var results: [T] = []

        if let entity = self as? T {
            results.append(entity)
        }

        for child in children {
            results.append(contentsOf: child.findEntities(ofType: type))
        }

        return results
    }
}

// MARK: - ModelEntity Extensions

extension ModelEntity {
    /// Create a simple plane entity with material
    static func createPlane(
        width: Float,
        height: Float,
        material: Material
    ) -> ModelEntity {
        let mesh = MeshResource.generatePlane(width: width, depth: height)
        return ModelEntity(mesh: mesh, materials: [material])
    }

    /// Create a simple box entity with material
    static func createBox(
        size: SIMD3<Float>,
        material: Material
    ) -> ModelEntity {
        let mesh = MeshResource.generateBox(size: size)
        return ModelEntity(mesh: mesh, materials: [material])
    }
}

// MARK: - View Extensions

import SwiftUI

extension View {
    /// Apply modifier conditionally
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Hide view conditionally
    @ViewBuilder
    func hidden(_ shouldHide: Bool) -> some View {
        if shouldHide {
            self.hidden()
        } else {
            self
        }
    }
}

// MARK: - Task Extensions

extension Task where Success == Never, Failure == Never {
    /// Sleep for specified seconds
    static func sleep(seconds: Double) async throws {
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
