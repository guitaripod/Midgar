import SwiftUI

struct SkeletonList: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: 12) {
                    ShimmerRectangle()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 13.5, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        ShimmerRectangle().frame(width: 150, height: 13).clipShape(Capsule())
                        ShimmerRectangle().frame(width: 210, height: 11).clipShape(Capsule())
                        ShimmerRectangle().frame(width: 90, height: 10).clipShape(Capsule())
                    }
                    Spacer()
                    ShimmerRectangle().frame(width: 62, height: 28).clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            Spacer()
        }
        .padding(.top, 8)
        .accessibilityHidden(true)
    }
}

struct EmptyStateView: View {
    let accent: Color
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Nothing here yet")
                .font(.headline)
            Text("Check your connection and try again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: onRetry) {
                Text("Retry")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 22)
                    .background(accent.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
