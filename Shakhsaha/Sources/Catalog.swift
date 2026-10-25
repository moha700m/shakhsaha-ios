import Foundation

struct CostRange: Codable, Hashable { let min: Int; let max: Int }

struct RemoteCatalog: Codable {
    var version: Int
    var updated: String?
    var costs: [String: CostRange]          // DTC -> SAR
    var systemCosts: [String: CostRange]    // fallback by system
    var tipsAr: [String]?
    var tipsEn: [String]?
    var heatLimitC: Double?
}

/// Remote content on GitHub Pages so prices and tips can change without an app update.
@MainActor
final class CatalogStore: ObservableObject {
    static let url = URL(string: "https://moha700m.github.io/shakhsaha-ios/catalog.json")!
    @Published var catalog: RemoteCatalog = CatalogStore.bundled
    private let cacheKey = "shakhsaha.catalog"

    init() {
        if let d = UserDefaults.standard.data(forKey: cacheKey), let c = try? JSONDecoder().decode(RemoteCatalog.self, from: d) { catalog = c }
    }

    func refresh() async {
        var r = URLRequest(url: Self.url); r.cachePolicy = .reloadIgnoringLocalCacheData; r.timeoutInterval = 10
        guard let (d, _) = try? await URLSession.shared.data(for: r),
              let c = try? JSONDecoder().decode(RemoteCatalog.self, from: d), c.version >= catalog.version else { return }
        catalog = c
        UserDefaults.standard.set(d, forKey: cacheKey)
    }

    func cost(for info: DTCInfo) -> CostRange {
        Self.cost(for: info, in: catalog)
    }

    nonisolated static func cost(for info: DTCInfo, in c: RemoteCatalog) -> CostRange {
        c.costs[info.code] ?? c.systemCosts[info.system] ?? CostRange(min: 150, max: 1200)
    }

    var tips: [String] { (L10n.lang == .ar ? catalog.tipsAr : catalog.tipsEn) ?? [] }

    nonisolated static let bundled = RemoteCatalog(
        version: 1, updated: "2026-10-25",
        costs: ["P0420": .init(min: 800, max: 2800), "P0300": .init(min: 200, max: 900), "P0301": .init(min: 150, max: 600),
                "P0171": .init(min: 150, max: 900), "P0217": .init(min: 300, max: 1500), "P0128": .init(min: 150, max: 450),
                "P0562": .init(min: 250, max: 1200), "P0442": .init(min: 30, max: 350), "P0455": .init(min: 30, max: 400)],
        systemCosts: ["emissions": .init(min: 200, max: 1500), "ignition": .init(min: 150, max: 700), "fuel": .init(min: 150, max: 1200),
                      "cooling": .init(min: 150, max: 1500), "electrical": .init(min: 150, max: 1200), "transmission": .init(min: 400, max: 6000),
                      "engine": .init(min: 300, max: 3500), "network": .init(min: 200, max: 1500), "chassis": .init(min: 200, max: 1200), "body": .init(min: 150, max: 1500)],
        tipsAr: ["في الصيف افحص البطارية كل ٣ شهور، الحر يقصّر عمرها.", "لا تفتح غطا الرديتر والمكينة حارة."],
        tipsEn: ["Check your battery every 3 months in summer.", "Never open the radiator cap while hot."],
        heatLimitC: 105)
}
