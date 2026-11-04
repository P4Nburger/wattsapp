import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            DisplaySettingsView()
                .tabItem {
                    Label("Display", systemImage: "eye")
                }
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 420, height: 520)
    }
}

// MARK: - General Tab

struct GeneralSettingsView: View {
    @StateObject private var launchAtLogin = LaunchAtLogin()
    @StateObject private var languageSettings = LanguageSettings()
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin.isEnabled)
            }
            
            Section {
                Picker("Language", selection: $languageSettings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                
                if languageSettings.needsRestart {
                    HStack {
                        Text("Restart WattsApp to apply the new language.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button("Restart Now") {
                            languageSettings.relaunch()
                        }
                    }
                }
            } header: {
                Text("Language")
            }
            
            Section("Update Interval") {
                Picker("Update Interval", selection: $settings.updateIntervalMode) {
                    ForEach(UpdateIntervalMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                
                // Info description for the currently selected mode
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(settings.updateIntervalMode.infoDescription)
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
                Picker("Display Style", selection: $settings.menuBarStyle) {
                    ForEach(AppSettings.MenuBarStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("Choose what appears in the menu bar. The icon changes automatically with the power state.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                Toggle("Battery Level", isOn: $settings.showBatteryPercentage)
                    .help("Shows the current battery charge level as a percentage.")
                Toggle("Battery Health", isOn: $settings.showBatteryHealth)
                    .help("Current maximum capacity compared with the design capacity. The closer to 100 percent, the less the battery has worn.")
                Toggle("Cycle Count", isOn: $settings.showCycleCount)
                    .help("Number of charge cycles. Mac notebook batteries are designed to retain up to 80 percent of their original capacity at 1,000 cycles.")
                Toggle("Temperature", isOn: $settings.showTemperature)
                    .help("Current battery temperature. Staying hot for long periods can shorten battery life.")
                Toggle("Time Remaining / Time to Full", isOn: $settings.showTimeRemaining)
                    .help("Shows the remaining battery time when on battery, and the estimated time to full while charging.")
            } header: {
                Text("Menu Items")
            } footer: {
                Text("Choose which items appear when you click the menu bar icon. Hover over an item for details.")
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
