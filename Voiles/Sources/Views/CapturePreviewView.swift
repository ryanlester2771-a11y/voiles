import SwiftUI

/// Preview view for captured screenshots with share/save options
struct CapturePreviewView: View {
    let image: UIImage
    let onSave: () -> Void
    let onShare: () -> Void
    let onDismiss: () -> Void

    @State private var showingSaveConfirmation = false
    @State private var saveError: String?

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                // Image preview
                imagePreview

                // Actions
                actionButtons
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text("Preview")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            // Spacer for symmetry
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding()
    }

    // MARK: - Image Preview

    private var imagePreview: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding()
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 24) {
            // Save button
            ActionButton(
                icon: "square.and.arrow.down",
                title: "Save",
                action: {
                    onSave()
                    showingSaveConfirmation = true
                }
            )

            // Share button
            ShareLink(item: Image(uiImage: image), preview: SharePreview("Voiles Design", image: Image(uiImage: image))) {
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.blue, in: Circle())

                    Text("Share")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            // Retake button
            ActionButton(
                icon: "camera",
                title: "Retake",
                action: onDismiss
            )
        }
        .padding(.vertical, 32)
        .alert("Saved!", isPresented: $showingSaveConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Image saved to your photo library.")
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(.ultraThinMaterial, in: Circle())

                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

#Preview {
    CapturePreviewView(
        image: UIImage(systemName: "photo")!,
        onSave: {},
        onShare: {},
        onDismiss: {}
    )
}
