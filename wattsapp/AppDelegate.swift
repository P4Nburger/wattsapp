import Cocoa
import IOKit.ps
import IOKit.pwr_mgt
import IOKit
import os.log

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Constants
    
    private enum Constants {
        static let noiseFloorWatts: Double = 0.1
        static let chargingInterval: TimeInterval = 2.0
        static let batteryInterval: TimeInterval = 3.0
        static let acInterval: TimeInterval = 5.0
        static let slowInterval: TimeInterval = 5.0
        static let timerTolerance: Double = 0.2
    }
    
    // MARK: - Properties
    
    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var currentInterval: TimeInterval = 3.0
    private var lastDisplayText: String?
    private var statusMenu: NSMenu?
    private let logger = Logger(subsystem: "com.wattsconnected.app", category: "battery")
    
    // MARK: - App Lifecycle
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusItem()
        setupMenu()
        updateWattage()
        scheduleTimer(interval: Constants.batteryInterval)
        setupPowerSourceNotification()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // RunLoopSourceのクリーンアップ
        if let source = powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
            powerSourceRunLoopSource = nil
        }
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - UI Setup
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "---W"
        statusItem.button?.setAccessibilityLabel("Power usage")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Quit WattsApp",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        self.statusMenu = menu
    }
    
    // MARK: - Power Source Notification
    
    private func setupPowerSourceNotification() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let runLoopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let appDelegate = Unmanaged<AppDelegate>
                .fromOpaque(context)
                .takeUnretainedValue()
            appDelegate.updateWattage()
        }, context).takeRetainedValue()
        
        self.powerSourceRunLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
    }
    
    // MARK: - Battery Info via IORegistry
    
    private func readBatteryInfo() -> [String: Any]? {
        guard let matching = IOServiceMatching("AppleSmartBattery") else { return nil }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        
        if service == 0 {
            logger.warning("AppleSmartBattery service not found")
            return nil
        }
        
        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(
            service,
            &properties,
            kCFAllocatorDefault,
            0
        )
        
        IOObjectRelease(service)
        
        if result != KERN_SUCCESS {
            logger.error("Failed to create CF properties for battery: kern = \(result)")
            return nil
        }
        
        guard let dict = properties?.takeRetainedValue() as? [String: Any] else {
            logger.error("Battery properties dictionary is missing or invalid")
            return nil
        }
        
        return dict
    }
    
    private func currentChargingStatus() -> (watts: Double, isCharging: Bool, onAC: Bool)? {
        guard let info = readBatteryInfo() else { return nil }
        
        let isCharging = (info["IsCharging"] as? Bool) ?? false
        let onAC = (info["ExternalConnected"] as? Bool) ?? false
        
        if let amperage = info["Amperage"] as? Int,
           let voltage = info["Voltage"] as? Int {
            // Amperage: mA, Voltage: mV -> Power: mW
            let powerMilliwatts = Double(amperage) * Double(voltage)
            let watts = powerMilliwatts / 1_000_000.0
            return (watts, isCharging, onAC)
        }
        
        return (0.0, isCharging, onAC)
    }
    
    // MARK: - Adapter Wattage Fallback
    
    private func readAdapterWattage() -> Int {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        var adapterWattage = 0
        
        for ps in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, ps)
                .takeRetainedValue() as? [String: Any] else { continue }
            
            if let sourceState = info[kIOPSPowerSourceStateKey] as? String,
               sourceState == kIOPSACPowerValue,
               let watts = info[kIOPSPowerAdapterWattsKey] as? Int {
                adapterWattage = watts
                break
            }
        }
        
        if adapterWattage == 0 {
            logger.debug("No AC adapter wattage found (may be on battery)")
        }
        
        return adapterWattage
    }
    
    // MARK: - Timer Scheduling
    
    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()
        currentInterval = interval
        
        let t = Timer.scheduledTimer(
            timeInterval: interval,
            target: self,
            selector: #selector(updateWattage),
            userInfo: nil,
            repeats: true
        )
        t.tolerance = interval * Constants.timerTolerance
        timer = t
    }
    
    private func scheduleTimerIfNeeded(_ newInterval: TimeInterval) {
        if abs(newInterval - currentInterval) > 0.01 {
            scheduleTimer(interval: newInterval)
        }
    }
    
    // MARK: - Update Logic
    
    @objc func updateWattage() {
        var displayText = "—"
        let threshold = Constants.noiseFloorWatts
        var desiredInterval: TimeInterval = Constants.slowInterval
        
        if let status = currentChargingStatus() {
            if status.onAC {
                let wattsToShow = max(0.0, status.watts)
                let value = wattsToShow
                
                if value >= threshold {
                    displayText = String(format: "⚡️ %.1fW", value)
                } else {
                    let adapter = readAdapterWattage()
                    if adapter > 0 {
                        displayText = "🔌 \(adapter)W"
                    } else {
                        displayText = "🔌 0W"
                    }
                }
                desiredInterval = status.isCharging ? Constants.chargingInterval : Constants.slowInterval
            } else {
                // バッテリー駆動時: 放電電力（正の大きさ）を表示
                let discharge = max(0.0, -status.watts)
                displayText = String(format: "🔋 %.1fW", discharge)
                desiredInterval = Constants.batteryInterval
            }
        } else {
            // フォールバック: アダプタ定格ワット数 or バッテリー表示
            let wattage = readAdapterWattage()
            if wattage > 0 {
                displayText = "🔌 \(wattage)W"
            } else {
                displayText = "🔋 On Battery"
            }
            desiredInterval = Constants.slowInterval
        }
        
        scheduleTimerIfNeeded(desiredInterval)
        
        DispatchQueue.main.async {
            if self.lastDisplayText != displayText {
                self.statusItem.button?.title = displayText
                self.lastDisplayText = displayText
            }
        }
    }
    
    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { return }
        let isLeft = (event.type == .leftMouseUp)
        let isRight = (event.type == .rightMouseUp)
        
        if (isLeft || isRight), let menu = statusMenu {
            statusItem.popUpMenu(menu)
        }
    }
}
