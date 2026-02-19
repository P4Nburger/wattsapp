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
    
    // MARK: - Persisted Update Interval
    
    @AppStorage("updateIntervalMode") var savedUpdateIntervalMode: Int = UpdateIntervalMode.automatic.rawValue
    
    private init() {}
}

// Allow MenuBarStyle to be stored via @AppStorage
extension AppSettings.MenuBarStyle: RawRepresentable {}
