import SwiftUI

/// Settings view for app configuration
struct SettingsView: View {
    @ObservedObject var viewModel: MainViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var occlusionEnabled = true
    @State private var personSegmentationEnabled = true
    @State private var dynamicLightingEnabled = true
    @State private var showDebugInfo = false

    var body: some View {
        NavigationStack {
            List {
                // AR Settings
                Section("AR Settings") {
                    Toggle("Object Occlusion", isOn: $occlusionEnabled)
                        .onChange(of: occlusionEnabled) { _, newValue in
                            viewModel.occlusionManager.setOcclusionEnabled(newValue)
                        }

                    Toggle("Person Segmentation", isOn: $personSegmentationEnabled)
                        .onChange(of: personSegmentationEnabled) { _, newValue in
                            viewModel.occlusionManager.setPersonSegmentationEnabled(newValue)
                        }

                    Toggle("Dynamic Lighting", isOn: $dynamicLightingEnabled)
                        .onChange(of: dynamicLightingEnabled) { _, newValue in
                            viewModel.lightingManager.setDynamicLightingEnabled(newValue)
                        }
                }

                // Device Info
                Section("Device Capabilities") {
                    HStack {
                        Text("LiDAR Scanner")
                        Spacer()
                        Text(viewModel.sessionManager.isLiDARAvailable ? "Available" : "Not Available")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Scene Reconstruction")
                        Spacer()
                        Text(viewModel.sessionManager.isSceneReconstructionSupported ? "Supported" : "Not Supported")
                            .foregroundColor(.secondary)
                    }
                }

                // Debug
                Section("Debug") {
                    Toggle("Show Debug Info", isOn: $showDebugInfo)

                    if showDebugInfo {
                        HStack {
                            Text("Detected Walls")
                            Spacer()
                            Text("\(viewModel.detectedWalls.count)")
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Cache Size")
                            Spacer()
                            Text(formatBytes(viewModel.assetManager.getCacheSize()))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Ambient Intensity")
                            Spacer()
                            Text("\(Int(viewModel.lightingManager.ambientIntensity)) lux")
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Color Temperature")
                            Spacer()
                            Text("\(Int(viewModel.lightingManager.colorTemperature))K")
                                .foregroundColor(.secondary)
                        }
                    }

                    Button("Clear Asset Cache") {
                        viewModel.assetManager.clearCache()
                    }
                    .foregroundColor(.red)
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)

                    Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            occlusionEnabled = viewModel.occlusionManager.isOcclusionEnabled
            personSegmentationEnabled = viewModel.occlusionManager.isPersonSegmentationEnabled
            dynamicLightingEnabled = viewModel.lightingManager.isDynamicLightingEnabled
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#Preview {
    SettingsView(viewModel: MainViewModel())
}
