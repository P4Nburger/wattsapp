import SwiftUI

@main
struct WattsConnectedApp: App {
    @StateObject private var viewModel = PowerViewModel()

    var body: some Scene {
        MenuBarExtra(viewModel.menuBarText) {
            // Power Status Section
            Text(viewModel.statusDetailText)
            
            if let detail = viewModel.batteryDetail {
                Divider()
                
                // Battery Info Section
                Label("バッテリー残量: \(detail.percentage)%", systemImage: batteryIcon(for: detail))
                Label("バッテリー健康度: \(detail.healthPercentage)%", systemImage: "heart.fill")
                Label("サイクル数: \(detail.cycleCount)回", systemImage: "arrow.triangle.2.circlepath")
                Label(String(format: "温度: %.1f°C", detail.temperature), systemImage: "thermometer.medium")
                
                if let timeToFull = detail.timeToFull {
                    Label("満充電まで: \(formatMinutes(timeToFull))", systemImage: "bolt.fill")
                }
                if let timeToEmpty = detail.timeToEmpty {
                    Label("残り使用時間: \(formatMinutes(timeToEmpty))", systemImage: "clock")
                }
            }
            
            Divider()
            
            // Update Interval
            Menu("更新間隔") {
                Picker("更新間隔", selection: $viewModel.updateIntervalMode) {
                    ForEach(UpdateIntervalMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.inline)
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
            Button("Quit WattsConnected") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        
        Settings {
            SettingsView()
        }
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
