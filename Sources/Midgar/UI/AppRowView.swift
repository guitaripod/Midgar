import SwiftUI

struct AppRowView: View {
    let app: MidgarApp
    let accent: Color
    let onOpen: () -> Void
    let onImpression: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                IconView(app: app, size: 60)

                VStack(alignment: .leading, spacing: 3) {
                    if app.featured {
                        FeaturedTag(accent: accent)
                    }
                    Text(app.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let tagline = app.tagline, !tagline.isEmpty {
                        Text(tagline)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    MetaLine(app: app)
                }

                Spacer(minLength: 8)

                GetButton(label: app.priceLabel, accent: accent, action: onOpen)
            }

            if !app.screenshotURLs.isEmpty {
                ScreenshotStrip(urls: app.screenshotURLs)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .onAppear(perform: onImpression)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the App Store product page")
    }

    private var accessibilityLabel: String {
        var parts = [app.name]
        if let tagline = app.tagline { parts.append(tagline) }
        if app.hasRating, let rating = app.rating {
            parts.append(String(format: "rated %.1f stars", rating))
        }
        parts.append(app.priceLabel == "GET" ? "Free" : app.priceLabel)
        return parts.joined(separator: ", ")
    }
}
