import SwiftUI
import RealityKit

/// Main view containing the AR experience and UI overlays
struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            // AR View
            ARViewContainer(viewModel: viewModel)
                .ignoresSafeArea()

            // UI Overlays
            VStack {
                // Top bar
                TopBar(
                    state: viewModel.currentState,
                    onReset: { viewModel.resetSession() },
                    onSettings: { showingSettings = true }
                )

                Spacer()

                // Bottom controls based on state
                bottomControls
            }

            // Coaching overlay
            if viewModel.showCoachingOverlay {
                CoachingOverlayView(message: viewModel.errorMessage)
            }

            // Style selector
            if viewModel.showStyleSelector {
                StyleSelectorView(
                    assetManager: viewModel.assetManager,
                    onStyleSelected: { style in
                        viewModel.applyStyle(style)
                    },
                    onDismiss: {
                        viewModel.transitionTo(.selection)
                    }
                )
            }

            // Capture preview
            if let image = viewModel.capturedImage {
                CapturePreviewView(
                    image: image,
                    onSave: {
                        Task {
                            _ = await viewModel.saveCapture()
                        }
                    },
                    onShare: {
                        // Share handled by CapturePreviewView
                    },
                    onDismiss: {
                        viewModel.dismissCapture()
                    }
                )
            }

            // Loading indicator
            if viewModel.isLoading {
                LoadingOverlay()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var bottomControls: some View {
        switch viewModel.currentState {
        case .scanning:
            ScanningControls(wallCount: viewModel.detectedWalls.count)

        case .selection:
            SelectionControls(
                onApplyStyle: {
                    viewModel.transitionTo(.application)
                },
                onCancel: {
                    viewModel.resetSelection()
                    viewModel.transitionTo(.scanning)
                }
            )

        case .application:
            EmptyView()

        case .adjustment:
            AdjustmentControls(
                uvScale: $viewModel.uvScale,
                onScaleChange: { viewModel.updateUVScale($0) },
                onCapture: { viewModel.captureScreenshot() },
                onChangeStyle: { viewModel.transitionTo(.application) },
                onReset: {
                    viewModel.resetSelection()
                    viewModel.transitionTo(.scanning)
                }
            )

        case .capture:
            EmptyView()
        }
    }
}

// MARK: - Top Bar

struct TopBar: View {
    let state: ARViewState
    let onReset: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack {
            // State indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 10, height: 10)

                Text(stateTitle)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            // Actions
            HStack(spacing: 12) {
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }

                Button(action: onSettings) {
                    Image(systemName: "gear")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
        }
        .padding()
    }

    private var stateTitle: String {
        switch state {
        case .scanning: return "Scanning"
        case .selection: return "Wall Selected"
        case .application: return "Choose Style"
        case .adjustment: return "Adjust"
        case .capture: return "Preview"
        }
    }

    private var stateColor: Color {
        switch state {
        case .scanning: return .blue
        case .selection: return .green
        case .application: return .orange
        case .adjustment: return .purple
        case .capture: return .pink
        }
    }
}

// MARK: - Scanning Controls

struct ScanningControls: View {
    let wallCount: Int

    var body: some View {
        VStack(spacing: 16) {
            Text("Move your iPad to detect walls")
                .font(.subheadline)
                .foregroundColor(.white)

            HStack {
                Image(systemName: "square.dashed")
                Text("\(wallCount) wall\(wallCount == 1 ? "" : "s") detected")
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.bottom, 40)
    }
}

// MARK: - Selection Controls

struct SelectionControls: View {
    let onApplyStyle: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Button(action: onCancel) {
                Label("Cancel", systemImage: "xmark")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            Button(action: onApplyStyle) {
                Label("Apply Style", systemImage: "paintbrush")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue, in: Capsule())
            }
        }
        .padding(.bottom, 40)
    }
}

// MARK: - Adjustment Controls

struct AdjustmentControls: View {
    @Binding var uvScale: Float
    let onScaleChange: (Float) -> Void
    let onCapture: () -> Void
    let onChangeStyle: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Scale slider
            HStack {
                Image(systemName: "minus.magnifyingglass")
                    .foregroundColor(.white)

                Slider(value: Binding(
                    get: { Double(uvScale) },
                    set: { onScaleChange(Float($0)) }
                ), in: 0.25...4.0)
                .tint(.white)

                Image(systemName: "plus.magnifyingglass")
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.horizontal)

            // Action buttons
            HStack(spacing: 16) {
                Button(action: onReset) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial, in: Circle())
                }

                Button(action: onChangeStyle) {
                    Image(systemName: "paintbrush")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial, in: Circle())
                }

                Button(action: onCapture) {
                    Image(systemName: "camera.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(Color.blue, in: Circle())
                }

                // Spacers for symmetry
                Color.clear
                    .frame(width: 50, height: 50)
                Color.clear
                    .frame(width: 50, height: 50)
            }
        }
        .padding(.bottom, 40)
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
                .padding(30)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    MainView()
}
