import SwiftUI

public extension View {
    /// Presents the Midgar storefront as a sheet when `isPresented` becomes `true`.
    ///
    /// ```swift
    /// .midgarStore(isPresented: $showMoreApps)
    /// ```
    func midgarStore(isPresented: Binding<Bool>, config: MidgarConfig = .default) -> some View {
        sheet(isPresented: isPresented) {
            MidgarStoreView(config: config)
                .presentationDragIndicator(.visible)
        }
    }
}

/// A drop-in settings/about row ("More Apps" with a chevron) that opens the storefront on tap.
///
/// ```swift
/// Section { MidgarMoreAppsRow() }
/// ```
public struct MidgarMoreAppsRow: View {
    private let title: String
    private let systemImage: String
    private let config: MidgarConfig
    @State private var presented = false

    public init(
        title: String = "More Apps",
        systemImage: String = "square.grid.2x2.fill",
        config: MidgarConfig = .default
    ) {
        self.title = title
        self.systemImage = systemImage
        self.config = config
    }

    public var body: some View {
        Button {
            presented = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body)
                    .foregroundStyle(config.accent ?? .accentColor)
                    .frame(width: 28, alignment: .center)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .midgarStore(isPresented: $presented, config: config)
    }
}

/// A button with a caller-supplied label that opens the storefront.
///
/// ```swift
/// MidgarMoreAppsButton { Label("More Apps", systemImage: "square.grid.2x2.fill") }
/// ```
public struct MidgarMoreAppsButton<Label: View>: View {
    private let config: MidgarConfig
    private let label: Label
    @State private var presented = false

    public init(config: MidgarConfig = .default, @ViewBuilder label: () -> Label) {
        self.config = config
        self.label = label()
    }

    public var body: some View {
        Button { presented = true } label: { label }
            .midgarStore(isPresented: $presented, config: config)
    }
}
