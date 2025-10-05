import SwiftUI

@main
struct WattsConnectedApp: App {
    // この行で、先ほど修正したAppDelegateをアプリに接続します。
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // メニューバーアプリなので、起動時にウィンドウは表示しません。
        // このSettingsシーンは、ウィンドウを非表示にするためのおまじないのようなものです。
        Settings {
            EmptyView()
        }
    }
}
