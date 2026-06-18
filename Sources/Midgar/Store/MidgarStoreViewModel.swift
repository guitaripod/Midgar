import SwiftUI

@MainActor
final class MidgarStoreViewModel: ObservableObject {

    enum State {
        case loading
        case loaded([MidgarApp])
        case empty
    }

    @Published private(set) var state: State = .loading
    @Published var presentedApp: MidgarApp?

    let config: MidgarConfig
    private let service = CatalogService()
    private lazy var telemetry = Telemetry(config: config)
    private var impressed = Set<String>()
    private var didLoad = false

    init(config: MidgarConfig) {
        self.config = config
    }

    /// First load: paint the cached snapshot instantly (if any), then refresh from the network.
    func load() async {
        guard !didLoad else { return }
        didLoad = true
        let cached = service.cachedSnapshot()
        if !cached.isEmpty { state = .loaded(cached) }
        await refresh()
    }

    func refresh() async {
        let apps = await service.build(config: config)
        if !apps.isEmpty {
            state = .loaded(apps)
        } else if case .loaded = state {
            return
        } else {
            state = .empty
        }
    }

    func open(_ app: MidgarApp) {
        telemetry.send(.tap, appId: app.appId)
        presentedApp = app
    }

    func registerImpression(_ app: MidgarApp) {
        guard impressed.insert(app.appId).inserted else { return }
        telemetry.send(.impression, appId: app.appId)
    }
}
