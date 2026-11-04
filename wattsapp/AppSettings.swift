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
            case .iconAndText: return String(localized: "Icon and Text")
            case .textOnly:    return String(localized: "Text Only")
            case .iconOnly:    return String(localized: "Icon Only")
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
        case .fast: return String(localized: "Frequent (about 1.5 s)")
        case .automatic: return String(localized: "Standard (Automatic)")
        case .slow: return String(localized: "Infrequent (5 s)")
        }
    }
    
    nonisolated var infoDescription: String {
        switch self {
        case .fast:
            return String(localized: "Updates about every 1.5 seconds. Handy for following changes in real time, but uses slightly more battery.")
        case .automatic:
            return String(localized: "Adjusts the interval to the power state: every 2 seconds while charging, 3 seconds on battery, and 5 seconds when plugged in but not charging.")
        case .slow:
            return String(localized: "Updates every 5 seconds. Recommended if you want to save battery.")
        }
    }
}
