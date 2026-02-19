import Foundation
import Combine
import ServiceManagement

@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            update()
        }
    }
    
    init() {
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }
    
    private func update() {
        do {
            if isEnabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Failed to update Launch at Login status: \(error)")
            // Revert on error
            if isEnabled != (SMAppService.mainApp.status == .enabled) {
                isEnabled = SMAppService.mainApp.status == .enabled
            }
        }
    }
}
