import ARKit
import RealityKit
import UIKit
import Photos

/// Manages high-resolution screenshot capture and sharing
@MainActor
final class CaptureManager: ObservableObject {
    /// Whether capture is in progress
    @Published private(set) var isCapturing = false

    /// Last captured image
    @Published private(set) var lastCapturedImage: UIImage?

    /// Error message if capture fails
    @Published var captureError: String?

    private weak var arView: ARView?

    // MARK: - Setup

    func setup(with arView: ARView) {
        self.arView = arView
    }

    // MARK: - Capture

    func captureScreenshot() async -> UIImage? {
        guard let arView = arView else {
            captureError = "AR view not available"
            return nil
        }

        isCapturing = true
        defer { isCapturing = false }

        // Capture at full resolution
        let snapshot = arView.snapshot(saveToHDR: false)

        lastCapturedImage = snapshot
        return snapshot
    }

    func captureHighResolution() async -> UIImage? {
        guard let arView = arView else {
            captureError = "AR view not available"
            return nil
        }

        isCapturing = true
        defer { isCapturing = false }

        // Request high-resolution capture
        let renderer = UIGraphicsImageRenderer(size: arView.bounds.size, format: .init(for: .init(displayScale: UIScreen.main.scale * 2)))

        let image = renderer.image { _ in
            arView.drawHierarchy(in: arView.bounds, afterScreenUpdates: true)
        }

        lastCapturedImage = image
        return image
    }

    // MARK: - Saving

    func saveToPhotoLibrary(_ image: UIImage) async -> Bool {
        // Request photo library access
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            captureError = "Photo library access denied"
            return false
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return true
        } catch {
            captureError = "Failed to save image: \(error.localizedDescription)"
            return false
        }
    }

    func getJPEGData(for image: UIImage, quality: CGFloat = 0.9) -> Data? {
        return image.jpegData(compressionQuality: quality)
    }

    func getPNGData(for image: UIImage) -> Data? {
        return image.pngData()
    }

    // MARK: - Sharing

    func createShareableImage(_ image: UIImage, withWatermark: Bool = false) -> UIImage {
        guard withWatermark else { return image }

        let renderer = UIGraphicsImageRenderer(size: image.size)

        return renderer.image { context in
            image.draw(at: .zero)

            // Add watermark
            let watermark = "Created with Voiles"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.6)
            ]

            let textSize = watermark.size(withAttributes: attributes)
            let textRect = CGRect(
                x: image.size.width - textSize.width - 20,
                y: image.size.height - textSize.height - 20,
                width: textSize.width,
                height: textSize.height
            )

            // Draw shadow
            let shadowAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .medium),
                .foregroundColor: UIColor.black.withAlphaComponent(0.3)
            ]
            watermark.draw(in: textRect.offsetBy(dx: 2, dy: 2), withAttributes: shadowAttributes)

            // Draw text
            watermark.draw(in: textRect, withAttributes: attributes)
        }
    }

    func share(_ image: UIImage, from viewController: UIViewController) {
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        // Configure for iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(
                x: viewController.view.bounds.midX,
                y: viewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        viewController.present(activityVC, animated: true)
    }

    // MARK: - Cleanup

    func clearLastCapture() {
        lastCapturedImage = nil
        captureError = nil
    }
}
