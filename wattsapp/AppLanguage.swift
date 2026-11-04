import AppKit
import Combine

/// アプリの表示言語。
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case japanese = "ja"
    case english = "en"

    nonisolated var id: String { rawValue }

    /// 言語名はその言語自身の表記で出す（どの言語で表示中でも見つけられるように）。
    nonisolated var displayName: String {
        switch self {
        case .system:   return String(localized: "System Default")
        case .japanese: return "日本語"
        case .english:  return "English"
        }
    }
}

/// 表示言語の設定。
///
/// macOS の「システム設定 > 一般 > 言語と地域 > アプリケーション」と同じく、
/// アプリのドメインの `AppleLanguages` を書き換える。反映にはアプリの再起動が必要。
final class LanguageSettings: ObservableObject {
    private static let appleLanguagesKey = "AppleLanguages"

    /// 起動時点の設定（＝いま画面に出ている言語）。再起動が必要かの判定に使う。
    private static let languageAtLaunch: AppLanguage = readSavedLanguage()

    @Published var language: AppLanguage {
        didSet { save() }
    }

    var needsRestart: Bool { language != Self.languageAtLaunch }

    init() {
        // static let は初回アクセス時に評価されるので、保存し直す前に起動時の値を確定させておく
        _ = Self.languageAtLaunch
        language = Self.readSavedLanguage()
    }

    /// 新しいインスタンスを起動してから自分を終了する。
    func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            if let error {
                print("Failed to relaunch: \(error)")
                return
            }
            Task { @MainActor in
                NSApp.terminate(nil)
            }
        }
    }

    // MARK: - Persistence

    /// アプリ自身のドメインだけを見る（`UserDefaults.standard` 経由だとシステム全体の設定も混ざるため）。
    private static func readSavedLanguage() -> AppLanguage {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let languages = UserDefaults.standard.persistentDomain(forName: bundleID)?[appleLanguagesKey] as? [String],
              let first = languages.first
        else { return .system }

        if first.hasPrefix("ja") { return .japanese }
        if first.hasPrefix("en") { return .english }
        return .system
    }

    private func save() {
        switch language {
        case .system:
            UserDefaults.standard.removeObject(forKey: Self.appleLanguagesKey)
        case .japanese, .english:
            UserDefaults.standard.set([language.rawValue], forKey: Self.appleLanguagesKey)
        }
    }
}
