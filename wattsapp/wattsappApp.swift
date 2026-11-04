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
        ForEach(Array(viewModel.statusLines.enumerated()), id: \.offset) { _, line in
            Text(line.localizedText)
        }
        
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
                Label("Battery Level: \(percentText(detail.percentage))", systemImage: PowerPresentation.batteryIcon(percentage: detail.percentage))
                    .help("Current battery charge level.")
            }
            if settings.showBatteryHealth {
                Label("Battery Health: \(percentText(detail.healthPercentage))", systemImage: "heart.fill")
                    .help("Current maximum capacity compared with the design capacity. The closer to 100 percent, the less the battery has worn.")
            }
            if settings.showCycleCount {
                Label("Cycle Count: \(detail.cycleCount)", systemImage: "arrow.triangle.2.circlepath")
                    .help("Number of charge cycles. Mac notebook batteries are designed to retain up to 80 percent of their original capacity at 1,000 cycles.")
            }
            if settings.showTemperature {
                Label("Temperature: \(temperatureText(detail.temperature))", systemImage: "thermometer.medium")
                    .help("Current battery temperature. Staying hot for long periods can shorten battery life.")
            }
            if settings.showTimeRemaining {
                if let timeToFull = detail.timeToFull {
                    Label("Time to Full: \(formatMinutes(timeToFull))", systemImage: "bolt.fill")
                        .help("Estimated time until fully charged at the current charging rate.")
                }
                if let timeToEmpty = detail.timeToEmpty {
                    Label("Time Remaining: \(formatMinutes(timeToEmpty))", systemImage: "clock")
                        .help("Estimated battery time remaining at the current power draw.")
                }
            }
        }
        
        Divider()
        
        // Settings
        if #available(macOS 14.0, *) {
            OpenSettingsButton()
        } else {
            Button("Settings…") {
                // メニューバー専用アプリ（LSUIElement）は設定ウインドウが前面に出ないことがあるので明示的にアクティブにする
                NSApp.activate(ignoringOtherApps: true)
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
    
    /// "%" を含む文字列はローカライズのキーに入れず、値として渡す
    private func percentText(_ value: Int) -> String {
        "\(value)%"
    }

    private func temperatureText(_ celsius: Double) -> String {
        String(format: "%.1f°C", celsius)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return String(localized: "\(minutes) min")
        }
        let h = minutes / 60
        let m = minutes % 60
        return m > 0 ? String(localized: "\(h) hr \(m) min") : String(localized: "\(h) hr")
    }
}

// MARK: - Open Settings (macOS 14+)

/// 設定を開くボタン。
///
/// `SettingsLink` はウインドウを開くだけでアプリをアクティブにしないため、
/// メニューバー専用アプリ（LSUIElement）では設定ウインドウが他のアプリの後ろに開いてしまう。
/// 先にアプリをアクティブにしてから開く。
@available(macOS 14.0, *)
private struct OpenSettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings…") {
            NSApp.activate()
            openSettings()
        }
    }
}
