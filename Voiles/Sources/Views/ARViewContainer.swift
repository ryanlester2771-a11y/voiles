import SwiftUI
import RealityKit
import ARKit

/// UIViewRepresentable wrapper for ARView with gesture handling
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: MainViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure AR view
        arView.automaticallyConfigureSession = false

        // Setup gesture recognizers
        setupGestures(arView, context: context)

        // Setup view model
        viewModel.setupARView(arView)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Updates handled by view model
    }

    private func setupGestures(_ arView: ARView, context: Context) {
        // Tap gesture for wall selection
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tapGesture)

        // Pinch gesture for scaling
        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        arView.addGestureRecognizer(pinchGesture)

        // Pan gesture for offset
        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        panGesture.minimumNumberOfTouches = 2
        arView.addGestureRecognizer(panGesture)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        let viewModel: MainViewModel
        private var initialScale: Float = 1.0
        private var initialOffset: SIMD2<Float> = .zero

        init(viewModel: MainViewModel) {
            self.viewModel = viewModel
        }

        @MainActor
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended else { return }

            let location = gesture.location(in: gesture.view)
            viewModel.handleTap(at: location)
        }

        @MainActor
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard viewModel.currentState == .adjustment else { return }

            switch gesture.state {
            case .began:
                initialScale = viewModel.uvScale

            case .changed:
                let newScale = initialScale / Float(gesture.scale)
                viewModel.updateUVScale(newScale)

            default:
                break
            }
        }

        @MainActor
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard viewModel.currentState == .adjustment else { return }

            switch gesture.state {
            case .began:
                initialOffset = viewModel.patternOffset

            case .changed:
                guard let view = gesture.view else { return }
                let translation = gesture.translation(in: view)

                // Convert screen translation to UV offset
                let uvOffset = SIMD2<Float>(
                    Float(translation.x) / Float(view.bounds.width) * viewModel.uvScale,
                    Float(translation.y) / Float(view.bounds.height) * viewModel.uvScale
                )

                viewModel.updatePatternOffset(initialOffset + uvOffset)

            default:
                break
            }
        }
    }
}
