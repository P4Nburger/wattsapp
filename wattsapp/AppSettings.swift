import SwiftUI
import Combine

/// App-wide user preferences, persisted via @AppStorage (UserDefaults).
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // MARK: - Menu Bar Display
    
    enum MenuBarStyle: String, CaseIterable, Identifiable {
        case iconAndText = "iconAndText"
        case textOnly = "textOnly"
        case iconOnly = "iconOnly"
        
        nonisolated var id: String { rawValue }
        
        nonisolated var title: String {
            switch self {
            case .iconAndText: return "アイコン＋テキスト"
            case .textOnly:    return "テキストのみ"
            case .iconOnly:    return "アイコンのみ"
            }
        }
    }
    
    @AppStorage("menuBarStyle") var menuBarStyle: MenuBarStyle = .iconAndText
    
    // MARK: - Menu Item Visibility
    
    @AppStorage("showBatteryPercentage") var showBatteryPercentage: Bool = true
    @AppStorage("showBatteryHealth") var showBatteryHealth: Bool = true
    @AppStorage("showCycleCount") var showCycleCount: Bool = false
    @AppStorage("showTemperature") var showTemperature: Bool = false
    @AppStorage("showTimeRemaining") var showTimeRemaining: Bool = true
    
    // MARK: - Update Interval
    
    /// 保存形式は従来どおり Int（rawValue）なので、既存ユーザーの設定はそのまま引き継がれる。
    @AppStorage("updateIntervalMode") var updateIntervalMode: UpdateIntervalMode = .automatic
    
    private init() {}
}

// Allow MenuBarStyle to be stored via @AppStorage
extension AppSettings.MenuBarStyle: RawRepresentable {}

// MARK: - Update Interval Mode

enum UpdateIntervalMode: Int, CaseIterable, Identifiable, Sendable {
    case fast
    case automatic
    case slow
    
    nonisolated var id: Int { rawValue }
    
    nonisolated var title: String {
        switch self {
        case .fast: return "高頻度（約1.5秒）"
        case .automatic: return "標準（自動）"
        case .slow: return "低頻度（5秒）"
        }
    }
    
    nonisolated var infoDescription: String {
        switch self {
        case .fast:
            return "約1.5秒ごとに更新します。リアルタイムで変化を追いたい時に便利ですが、バッテリー消費がやや増えます。"
        case .automatic:
            return "電源の状態に応じて自動で間隔を調整します。充電中は2秒、バッテリー駆動中は3秒、AC接続（非充電）時は5秒で更新します。"
        case .slow:
            return "5秒ごとに更新します。バッテリー消費を抑えたい場合におすすめです。"
        }
    }
}
