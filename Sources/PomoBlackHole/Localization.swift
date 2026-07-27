import Foundation

enum AppLanguage: String, Codable, CaseIterable {
    case system
    case english
    case simplifiedChinese

    @MainActor
    var title: String {
        switch self {
        case .system: L.text("Follow System")
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }
}

@MainActor
enum L {
    static var language: AppLanguage = .system

    private static var localizationBundle: Bundle {
        let localization: String?
        switch language {
        case .system: localization = nil
        case .english: localization = "en"
        case .simplifiedChinese: localization = "zh-Hans"
        }
        guard let localization,
              let path = Bundle.main.path(forResource: localization, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }

    static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: localizationBundle, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let locale: Locale = switch language {
        case .system: .current
        case .english: Locale(identifier: "en")
        case .simplifiedChinese: Locale(identifier: "zh-Hans")
        }
        return String(format: text(key), locale: locale, arguments: arguments)
    }
}
