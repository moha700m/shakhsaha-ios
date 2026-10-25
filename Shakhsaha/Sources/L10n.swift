import Foundation
import SwiftUI

enum AppLang: String, CaseIterable, Identifiable {
    case ar, en
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ar: return "العربية"
        case .en: return "English"
        }
    }
}

enum L10n {
    static let storageKey = "shakhsaha.lang"

    /// Arabic is the product default. System locale is ignored until the user picks a language in Settings.
    static var lang: AppLang {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let v = AppLang(rawValue: raw) {
            return v
        }
        return .ar
    }

    static func setLang(_ lang: AppLang) {
        UserDefaults.standard.set(lang.rawValue, forKey: storageKey)
        // Makes iOS pick the matching .lproj (permission prompts, display name) from next launch.
        UserDefaults.standard.set([lang.rawValue], forKey: "AppleLanguages")
    }

    static func t(_ ar: String, _ en: String) -> String { lang == .ar ? ar : en }
}

func L(_ ar: String, _ en: String) -> String { L10n.t(ar, en) }

extension View {
    func appLayout(_ lang: AppLang = L10n.lang) -> some View {
        environment(\.layoutDirection, lang == .ar ? .rightToLeft : .leftToRight)
            .environment(\.locale, Locale(identifier: lang == .ar ? "ar_SA" : "en_US"))
    }
}
