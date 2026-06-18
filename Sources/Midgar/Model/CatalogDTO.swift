import Foundation

struct CatalogResponse: Codable {
    let version: Int
    let updatedAt: String?
    let apps: [CatalogEntry]
}

struct CatalogEntry: Codable {
    let appId: String
    let bundleId: String
    let name: String
    let tagline: String?
    let genre: String?
    let accent: String?
    let featured: Bool?
    let order: Int?
    let icon: URL?
}
