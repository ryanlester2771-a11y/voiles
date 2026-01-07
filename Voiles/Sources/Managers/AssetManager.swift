import Foundation
import UIKit
import Combine

/// Manages asynchronous loading and caching of style assets
@MainActor
final class AssetManager: ObservableObject {
    /// All available styles
    @Published private(set) var availableStyles: [WallStyle] = []

    /// Styles organized by category
    @Published private(set) var stylesByCategory: [StyleCategory: [WallStyle]] = [:]

    /// Currently loading style IDs
    @Published private(set) var loadingStyleIDs: Set<UUID> = []

    /// Thumbnail cache
    private var thumbnailCache: [UUID: UIImage] = [:]

    /// High-resolution texture cache
    private var textureCache: [String: Data] = [:]

    /// Maximum cache size in bytes (100 MB)
    private let maxCacheSize: Int = 100 * 1024 * 1024

    /// Current cache size
    private var currentCacheSize: Int = 0

    private var loadingTasks: [UUID: Task<UIImage?, Never>] = [:]

    // MARK: - Initialization

    init() {
        loadAvailableStyles()
    }

    // MARK: - Style Loading

    private func loadAvailableStyles() {
        // Load sample styles (replace with actual asset loading)
        availableStyles = WallStyle.sampleStyles

        // Organize by category
        stylesByCategory = Dictionary(grouping: availableStyles) { $0.category }
    }

    func loadStylesFromBundle() async {
        // Load styles from a JSON manifest or asset catalog
        if let url = Bundle.main.url(forResource: "styles", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let styles = try? JSONDecoder().decode([WallStyle].self, from: data) {
            availableStyles = styles
            stylesByCategory = Dictionary(grouping: styles) { $0.category }
        }
    }

    // MARK: - Thumbnail Loading

    func loadThumbnail(for style: WallStyle) async -> UIImage? {
        // Check cache first
        if let cached = thumbnailCache[style.id] {
            return cached
        }

        // Check if already loading
        if let existingTask = loadingTasks[style.id] {
            return await existingTask.value
        }

        loadingStyleIDs.insert(style.id)

        let task = Task<UIImage?, Never> {
            defer {
                Task { @MainActor in
                    loadingStyleIDs.remove(style.id)
                    loadingTasks.removeValue(forKey: style.id)
                }
            }

            // Simulate async loading with slight delay for smoother UI
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

            guard !Task.isCancelled else { return nil }

            // Try loading from asset catalog
            if let image = UIImage(named: style.thumbnailName) {
                await MainActor.run {
                    cacheThumbnail(image, for: style.id)
                }
                return image
            }

            // Try loading from bundle
            if let url = Bundle.main.url(forResource: style.thumbnailName, withExtension: "png") ??
                         Bundle.main.url(forResource: style.thumbnailName, withExtension: "jpg"),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                await MainActor.run {
                    cacheThumbnail(image, for: style.id)
                }
                return image
            }

            // Generate placeholder thumbnail
            let placeholder = generatePlaceholderThumbnail(for: style)
            await MainActor.run {
                cacheThumbnail(placeholder, for: style.id)
            }
            return placeholder
        }

        loadingTasks[style.id] = task
        return await task.value
    }

    private func cacheThumbnail(_ image: UIImage, for styleID: UUID) {
        let imageSize = Int(image.size.width * image.size.height * 4) // RGBA

        // Evict old entries if cache is full
        while currentCacheSize + imageSize > maxCacheSize && !thumbnailCache.isEmpty {
            if let oldestKey = thumbnailCache.keys.first {
                if let oldImage = thumbnailCache.removeValue(forKey: oldestKey) {
                    currentCacheSize -= Int(oldImage.size.width * oldImage.size.height * 4)
                }
            }
        }

        thumbnailCache[styleID] = image
        currentCacheSize += imageSize
    }

    private func generatePlaceholderThumbnail(for style: WallStyle) -> UIImage {
        let size = CGSize(width: 120, height: 120)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Background color based on category
            let backgroundColor: UIColor
            switch style.category {
            case .geometric:
                backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
            case .floral:
                backgroundColor = UIColor(red: 0.8, green: 0.4, blue: 0.5, alpha: 1.0)
            case .abstract:
                backgroundColor = UIColor(red: 0.6, green: 0.3, blue: 0.7, alpha: 1.0)
            case .textured:
                backgroundColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
            case .classic:
                backgroundColor = UIColor(red: 0.7, green: 0.6, blue: 0.4, alpha: 1.0)
            case .modern:
                backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
            }

            backgroundColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw pattern indicator
            UIColor.white.withAlphaComponent(0.3).setStroke()
            let path = UIBezierPath()
            for i in stride(from: 0, to: size.width, by: 20) {
                path.move(to: CGPoint(x: i, y: 0))
                path.addLine(to: CGPoint(x: i, y: size.height))
            }
            for i in stride(from: 0, to: size.height, by: 20) {
                path.move(to: CGPoint(x: 0, y: i))
                path.addLine(to: CGPoint(x: size.width, y: i))
            }
            path.lineWidth = 1
            path.stroke()

            // Draw style name initial
            let initial = String(style.name.prefix(1))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = initial.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            initial.draw(in: textRect, withAttributes: attributes)
        }
    }

    // MARK: - Texture Loading

    func loadTexture(named name: String) async -> Data? {
        // Check cache first
        if let cached = textureCache[name] {
            return cached
        }

        // Load from bundle
        if let url = Bundle.main.url(forResource: name, withExtension: "png") ??
                     Bundle.main.url(forResource: name, withExtension: "jpg"),
           let data = try? Data(contentsOf: url) {
            cacheTexture(data, named: name)
            return data
        }

        return nil
    }

    private func cacheTexture(_ data: Data, named name: String) {
        // Evict old entries if cache is full
        while currentCacheSize + data.count > maxCacheSize && !textureCache.isEmpty {
            if let oldestKey = textureCache.keys.first {
                if let oldData = textureCache.removeValue(forKey: oldestKey) {
                    currentCacheSize -= oldData.count
                }
            }
        }

        textureCache[name] = data
        currentCacheSize += data.count
    }

    // MARK: - Preloading

    func preloadThumbnails(for styles: [WallStyle]) async {
        await withTaskGroup(of: Void.self) { group in
            for style in styles {
                group.addTask {
                    _ = await self.loadThumbnail(for: style)
                }
            }
        }
    }

    func preloadCategory(_ category: StyleCategory) async {
        guard let styles = stylesByCategory[category] else { return }
        await preloadThumbnails(for: styles)
    }

    // MARK: - Search and Filter

    func searchStyles(query: String) -> [WallStyle] {
        guard !query.isEmpty else { return availableStyles }

        let lowercasedQuery = query.lowercased()
        return availableStyles.filter {
            $0.name.lowercased().contains(lowercasedQuery) ||
            $0.category.rawValue.lowercased().contains(lowercasedQuery)
        }
    }

    func styles(for category: StyleCategory) -> [WallStyle] {
        return stylesByCategory[category] ?? []
    }

    // MARK: - Cache Management

    func clearCache() {
        thumbnailCache.removeAll()
        textureCache.removeAll()
        currentCacheSize = 0
    }

    func getCacheSize() -> Int {
        return currentCacheSize
    }

    func cancelAllLoading() {
        for task in loadingTasks.values {
            task.cancel()
        }
        loadingTasks.removeAll()
        loadingStyleIDs.removeAll()
    }
}
