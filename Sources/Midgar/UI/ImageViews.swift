import SwiftUI

enum MidgarImageCache {
    static let memory: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 240
        return cache
    }()
}

/// Loads an image from the network through Midgar's cached session, memoizing decoded results.
func midgarLoadImage(_ url: URL?) async -> UIImage? {
    guard let url else { return nil }
    if let cached = MidgarImageCache.memory.object(forKey: url as NSURL) { return cached }
    guard let (data, response) = try? await URLSession.midgar.data(from: url),
          (response as? HTTPURLResponse)?.statusCode == 200,
          let image = UIImage(data: data)
    else { return nil }
    MidgarImageCache.memory.setObject(image, forKey: url as NSURL)
    return image
}

/// Loads a bundled fallback icon shipped with the package (used for apps not yet on the store index).
func midgarBundledIcon(_ appId: String) -> UIImage? {
    guard let url = Bundle.module.url(forResource: appId, withExtension: "png", subdirectory: "fallback-icons"),
          let data = try? Data(contentsOf: url)
    else { return nil }
    return UIImage(data: data)
}

struct IconView: View {
    let app: MidgarApp
    let size: CGFloat

    @State private var image: UIImage?
    @State private var resolved = false

    private var accent: Color { Color(hex: app.accentHex) ?? .accentColor }
    private var corner: CGFloat { size * 0.225 }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if resolved {
                monogram
            } else {
                ShimmerRectangle()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .task(id: app.iconURL) {
            let loaded = await midgarLoadImage(app.iconURL) ?? midgarBundledIcon(app.appId)
            image = loaded
            resolved = true
        }
    }

    private var monogram: some View {
        LinearGradient(colors: [accent, accent.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(
                Text(app.monogram)
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            )
    }
}

struct ScreenshotStrip: View {
    let urls: [URL]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(urls.prefix(10)), id: \.self) { url in
                    ScreenshotImage(url: url)
                }
            }
        }
    }
}

private struct ScreenshotImage: View {
    let url: URL
    private let height: CGFloat = 188

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: height * image.size.width / max(image.size.height, 1), height: height)
            } else if failed {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: height * 0.56, height: height)
            } else {
                ShimmerRectangle().frame(width: height * 0.56, height: height)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
        )
        .task(id: url) {
            if let loaded = await midgarLoadImage(url) {
                image = loaded
            } else {
                failed = true
            }
        }
    }
}
