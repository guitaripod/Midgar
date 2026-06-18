import Foundation

/// Orchestrates the storefront data pipeline:
/// remote catalog → device-region App Store enrichment → curated/bundled fallback,
/// caching the result for instant, offline-capable launches.
actor CatalogService {
    private let session: URLSession
    private let itunes: ITunesClient
    private let cache = DiskCache()

    init(session: URLSession = .midgar) {
        self.session = session
        self.itunes = ITunesClient(session: session)
    }

    /// Last fully-enriched result persisted on disk, for instant first paint. May be empty.
    nonisolated func cachedSnapshot() -> [MidgarApp] {
        DiskCache().loadSnapshot()
    }

    /// Builds the storefront fresh: pulls the curated catalog, enriches with live App Store data for
    /// the user's region, applies exclusions, sorts, and persists the snapshot. Never throws —
    /// always returns the best available data, falling back to the bundled catalog when offline.
    func build(config: MidgarConfig) async -> [MidgarApp] {
        let exclusions = Set(config.resolvedExclusions)
        let entries = await resolveEntries(config: config)
            .filter { !exclusions.contains($0.bundleId.lowercased()) }

        guard !entries.isEmpty else { return [] }

        let live = await itunes.lookup(
            ids: entries.map(\.appId),
            storefront: config.resolvedStorefront
        )

        let apps = entries
            .map { merge(entry: $0, live: live[$0.appId]) }
            .sorted(by: Self.ordering)

        if !apps.isEmpty { cache.saveSnapshot(apps) }
        return apps
    }

    private func resolveEntries(config: MidgarConfig) async -> [CatalogEntry] {
        if let remote = await fetchRemoteCatalog(config: config) {
            cache.saveCatalog(remote)
            return remote
        }
        if let disk = cache.loadCatalog() { return disk }
        return Self.bundledCatalog()
    }

    private func fetchRemoteCatalog(config: MidgarConfig) async -> [CatalogEntry]? {
        var components = URLComponents(url: config.catalogURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "exclude", value: config.resolvedExclusions.joined(separator: ","))
        ]
        guard let url = components?.url else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(CatalogResponse.self, from: data).apps
        } catch {
            return nil
        }
    }

    private func merge(entry: CatalogEntry, live: ITunesApp?) -> MidgarApp {
        MidgarApp(
            appId: entry.appId,
            bundleId: entry.bundleId,
            name: live?.trackName ?? entry.name,
            tagline: entry.tagline,
            genre: live?.primaryGenreName ?? entry.genre,
            accentHex: entry.accent,
            featured: entry.featured ?? false,
            order: entry.order ?? 999,
            iconURL: live?.artworkUrl512 ?? live?.artworkUrl100 ?? entry.icon,
            screenshotURLs: live?.screenshotUrls ?? [],
            rating: live?.averageUserRating,
            ratingCount: live?.userRatingCount,
            formattedPrice: live?.formattedPrice
        )
    }

    static func ordering(_ lhs: MidgarApp, _ rhs: MidgarApp) -> Bool {
        if lhs.featured != rhs.featured { return lhs.featured }
        if lhs.order != rhs.order { return lhs.order < rhs.order }
        return lhs.name < rhs.name
    }

    static func bundledCatalog() -> [CatalogEntry] {
        guard let url = Bundle.module.url(forResource: "catalog.fallback", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let response = try? JSONDecoder().decode(CatalogResponse.self, from: data)
        else { return [] }
        return response.apps
    }
}
