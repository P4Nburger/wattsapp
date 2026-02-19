import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("一般", systemImage: "gearshape")
                }
            
            DisplaySettingsView()
                .tabItem {
                    Label("表示", systemImage: "eye")
                }
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 420, height: 460)
    }
}

// MARK: - General Tab

struct GeneralSettingsView: View {
    @StateObject private var launchAtLogin = LaunchAtLogin()
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some View {
        Form {
            Section("起動") {
                Toggle("ログイン時に起動", isOn: $launchAtLogin.isEnabled)
            }
            
            Section("更新間隔") {
                Picker("更新間隔", selection: Binding(
                    get: {
                        UpdateIntervalMode(rawValue: settings.savedUpdateIntervalMode) ?? .automatic
                    },
                    set: { newValue in
                        settings.savedUpdateIntervalMode = newValue.rawValue
                    }
                )) {
                    ForEach(UpdateIntervalMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                
                // Info description for the currently selected mode
                let currentMode = UpdateIntervalMode(rawValue: settings.savedUpdateIntervalMode) ?? .automatic
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(currentMode.infoDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Display Tab

struct DisplaySettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some View {
        Form {
            Section {
                Picker("表示スタイル", selection: $settings.menuBarStyle) {
                    ForEach(AppSettings.MenuBarStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
            } header: {
                Text("メニューバー")
            } footer: {
                Text("メニューバーに表示する内容を選べます。アイコンは電源の状態に応じて自動で変わります。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                Toggle("バッテリー残量（%）", isOn: $settings.showBatteryPercentage)
                    .help("現在のバッテリー残量をパーセンテージで表示します。")
                Toggle("バッテリー健康度", isOn: $settings.showBatteryHealth)
                    .help("設計容量に対する現在の最大容量の割合です。100%に近いほどバッテリーの劣化が少ないことを示します。")
                Toggle("サイクル数", isOn: $settings.showCycleCount)
                    .help("バッテリーの充放電サイクル回数です。Apple はノートブックのバッテリーを最大 1000 サイクルまで設計しています。")
                Toggle("温度", isOn: $settings.showTemperature)
                    .help("バッテリーの現在の温度です。高温はバッテリーの寿命に影響する可能性があります。")
                Toggle("残り時間 / 満充電時間", isOn: $settings.showTimeRemaining)
                    .help("バッテリー駆動時は使用可能な残り時間、充電中は満充電までの予想時間を表示します。")
            } header: {
                Text("メニュー項目")
            } footer: {
                Text("メニューバーをクリックした際に表示される項目を選べます。各項目にマウスを合わせると詳しい説明が表示されます。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    SettingsView()
}
