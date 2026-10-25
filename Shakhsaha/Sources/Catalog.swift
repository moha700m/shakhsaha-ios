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
    var cityFactors: [String: Double]?      // riyadh, jeddah, dammam, ...
    var dealerFactor: Double?
    var fuelPrices: [String: Double]?       // "91", "95", "diesel" SAR/L
    var heatTipsAr: [String]?
    var heatTipsEn: [String]?
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

    var cities: [(String, String)] { [("riyadh", L("الرياض", "Riyadh")), ("jeddah", L("جدة", "Jeddah")), ("dammam", L("الدمام", "Dammam")), ("makkah", L("مكة", "Makkah")), ("madinah", L("المدينة", "Madinah")), ("qassim", L("القصيم", "Qassim")), ("abha", L("أبها", "Abha")), ("tabuk", L("تبوك", "Tabuk"))] }
    func factor(_ city: String) -> Double { catalog.cityFactors?[city] ?? Self.bundled.cityFactors?[city] ?? 1 }
    var dealer: Double { catalog.dealerFactor ?? 1.8 }
    func fuelPrice(_ k: String) -> Double { catalog.fuelPrices?[k] ?? Self.bundled.fuelPrices?[k] ?? 2.33 }
    var heatTips: [String] { (L10n.lang == .ar ? (catalog.heatTipsAr ?? Self.bundled.heatTipsAr) : (catalog.heatTipsEn ?? Self.bundled.heatTipsEn)) ?? [] }
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
        heatLimitC: 105,
        cityFactors: ["riyadh": 1.0, "jeddah": 1.05, "dammam": 0.95, "makkah": 1.05, "madinah": 0.97, "qassim": 0.9, "abha": 0.92, "tabuk": 0.93],
        dealerFactor: 1.8,
        fuelPrices: ["91": 2.18, "95": 2.33, "diesel": 1.66],
        heatTipsAr: ["لا توقف السيارة تحت الشمس والمكيف شغّال مدة طويلة.", "البطارية تموت في الصيف أكثر من الشتاء، افحصها لو عمرها فوق سنتين.", "لو الحرارة طلعت فوق النص طفّ المكيف وشغّل الدفاية لين توقف."],
        heatTipsEn: ["Avoid long idling in the sun with A/C on.", "Batteries die more in summer; test if older than 2 years.", "If temp rises past middle, switch off A/C and turn the heater on until you stop."])
}
