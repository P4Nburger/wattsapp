import SwiftUI

@main
struct WattsConnectedApp: App {
    @StateObject private var viewModel = PowerViewModel()
    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(viewModel: viewModel, settings: settings)
        } label: {
            menuBarLabel
        }
        
        Settings {
            SettingsView()
        }
    }
    
    @ViewBuilder
    private var menuBarLabel: some View {
        switch settings.menuBarStyle {
        case .iconAndText:
            HStack(spacing: 4) {
                Image(systemName: viewModel.menuBarIcon)
                Text(viewModel.menuBarText)
            }
        case .textOnly:
            Text(viewModel.menuBarText)
        case .iconOnly:
            Image(systemName: viewModel.menuBarIcon)
        }
    }
}

// MARK: - Menu Content

struct MenuContentView: View {
    @ObservedObject var viewModel: PowerViewModel
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        // Power Status
        Text(viewModel.statusDetailText)
        
        if let detail = viewModel.batteryDetail {
            let hasVisibleItems = settings.showBatteryPercentage
                || settings.showBatteryHealth
                || settings.showCycleCount
                || settings.showTemperature
                || settings.showTimeRemaining
            
            if hasVisibleItems {
                Divider()
            }
            
            if settings.showBatteryPercentage {
                Label("バッテリー残量: \(detail.percentage)%", systemImage: batteryIcon(for: detail))
                    .help("現在のバッテリー残量")
            }
            if settings.showBatteryHealth {
                Label("バッテリー健康度: \(detail.healthPercentage)%", systemImage: "heart.fill")
                    .help("設計容量に対する現在の最大容量の割合。100%に近いほどバッテリーの劣化が少ないことを示します。")
            }
            if settings.showCycleCount {
                Label("サイクル数: \(detail.cycleCount)回", systemImage: "arrow.triangle.2.circlepath")
                    .help("バッテリーの充放電サイクル回数。Apple は最大 1000 サイクルまで設計しています。")
            }
            if settings.showTemperature {
                Label(String(format: "温度: %.1f°C", detail.temperature), systemImage: "thermometer.medium")
                    .help("バッテリーの現在の温度。高温が続くとバッテリー寿命に影響します。")
            }
            if settings.showTimeRemaining {
                if let timeToFull = detail.timeToFull {
                    Label("満充電まで: \(formatMinutes(timeToFull))", systemImage: "bolt.fill")
                        .help("現在の充電速度に基づく満充電までの予想時間")
                }
                if let timeToEmpty = detail.timeToEmpty {
                    Label("残り使用時間: \(formatMinutes(timeToEmpty))", systemImage: "clock")
                        .help("現在の消費電力に基づくバッテリー使用可能な残り時間")
                }
            }
        }
        
        Divider()
        
        // Settings
        if #available(macOS 14.0, *) {
            SettingsLink {
                Text("設定...")
            }
        } else {
            Button("設定...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
        
        Divider()
        
        // Quit
        Button("Quit WattsApp") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
    
    // MARK: - Helpers
    
    private func batteryIcon(for detail: BatteryDetailInfo) -> String {
        let pct = detail.percentage
        switch pct {
        case 76...100: return "battery.100"
        case 51...75:  return "battery.75"
        case 26...50:  return "battery.50"
        case 1...25:   return "battery.25"
        default:       return "battery.0"
        }
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)分"
        }
        let h = minutes / 60
        let m = minutes % 60
        return m > 0 ? "\(h)時間\(m)分" : "\(h)時間"
    }
}
