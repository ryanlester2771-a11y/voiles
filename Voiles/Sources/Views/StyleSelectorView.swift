import SwiftUI

/// Style selector view for browsing and selecting wall styles
struct StyleSelectorView: View {
    @ObservedObject var assetManager: AssetManager
    let onStyleSelected: (WallStyle) -> Void
    let onDismiss: () -> Void

    @State private var selectedCategory: StyleCategory?
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Category tabs
            categoryTabs

            // Style grid
            styleGrid
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Select Style")
                .font(.title2.bold())
                .foregroundColor(.white)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All category
                CategoryTab(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )

                ForEach(StyleCategory.allCases) { category in
                    CategoryTab(
                        title: category.rawValue,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Style Grid

    private var styleGrid: some View {
        let styles = filteredStyles

        return ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(styles) { style in
                    StyleCard(
                        style: style,
                        assetManager: assetManager,
                        onSelect: { onStyleSelected(style) }
                    )
                }
            }
            .padding()
        }
        .frame(maxHeight: 400)
    }

    private var filteredStyles: [WallStyle] {
        var styles = assetManager.availableStyles

        if let category = selectedCategory {
            styles = styles.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            styles = assetManager.searchStyles(query: searchText)
        }

        return styles
    }
}

// MARK: - Category Tab

struct CategoryTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.blue : Color.white.opacity(0.1),
                    in: Capsule()
                )
        }
    }
}

// MARK: - Style Card

struct StyleCard: View {
    let style: WallStyle
    @ObservedObject var assetManager: AssetManager
    let onSelect: () -> Void

    @State private var thumbnail: UIImage?
    @State private var isLoading = true

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))

                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .frame(height: 100)

                // Name
                Text(style.name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .task {
            isLoading = true
            thumbnail = await assetManager.loadThumbnail(for: style)
            isLoading = false
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        StyleSelectorView(
            assetManager: AssetManager(),
            onStyleSelected: { _ in },
            onDismiss: {}
        )
    }
}
