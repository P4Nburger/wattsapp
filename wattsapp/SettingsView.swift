import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("一般", systemImage: "gearshape")
                }
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 400, height: 440)
    }
}

struct GeneralSettingsView: View {
    @StateObject private var launchAtLogin = LaunchAtLogin()
    
    var body: some View {
        Form {
            Section {
                Toggle("ログイン時に起動", isOn: $launchAtLogin.isEnabled)
            } footer: {
                Text("Macへのログイン時に自動的にアプリを起動します。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
