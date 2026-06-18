import SwiftUI

/// The storefront screen. Embed it directly, or present it via the
/// ``SwiftUI/View/midgarStore(isPresented:config:)`` modifier or ``Midgar/present(from:config:)``.
public struct MidgarStoreView: View {
    @StateObject private var model: MidgarStoreViewModel
    @Environment(\.dismiss) private var dismiss

    public init(config: MidgarConfig = .default) {
        _model = StateObject(wrappedValue: MidgarStoreViewModel(config: config))
    }

    private var accent: Color { model.config.accent ?? .accentColor }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle(model.config.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary, Color(.tertiarySystemFill))
                        }
                        .accessibilityLabel("Close")
                    }
                }
        }
        .tint(accent)
        .task { await model.load() }
        .fullScreenCover(item: $model.presentedApp) { app in
            StoreProductView(appId: app.appId, fallbackURL: app.storeURL) {
                model.presentedApp = nil
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            SkeletonList()
        case .empty:
            EmptyStateView(accent: accent) {
                Task { await model.refresh() }
            }
        case .loaded(let apps):
            List {
                ForEach(apps) { app in
                    AppRowView(
                        app: app,
                        accent: accent,
                        onOpen: { model.open(app) },
                        onImpression: { model.registerImpression(app) }
                    )
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                    .listRowSeparator(.visible)
                }
            }
            .listStyle(.plain)
            .refreshable { await model.refresh() }
        }
    }
}
