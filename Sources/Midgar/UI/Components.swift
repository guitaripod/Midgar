import SwiftUI

struct ShimmerRectangle: View {
    @State private var animate = false

    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.16))
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.22), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .scaleEffect(x: 3, y: 1, anchor: .center)
                .offset(x: animate ? 240 : -240)
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    animate = true
                }
            }
    }
}

struct GetButton: View {
    let label: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(.footnote.weight(.bold))
                .foregroundStyle(accent)
                .frame(minWidth: 62)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(accent.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct MetaLine: View {
    let app: MidgarApp

    var body: some View {
        HStack(spacing: 4) {
            if app.hasRating, let rating = app.rating {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.yellow)
                Text(String(format: "%.1f", rating))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let count = app.ratingCount, count > 0 {
                    Text("(\(count))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            if let genre = app.genre, !genre.isEmpty {
                if app.hasRating {
                    Text("·").font(.caption2).foregroundStyle(.tertiary)
                }
                Text(genre).font(.caption).foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
    }
}

struct FeaturedTag: View {
    let accent: Color

    var body: some View {
        Text("FEATURED")
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.5)
            .foregroundStyle(accent)
    }
}
