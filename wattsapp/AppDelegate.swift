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
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.wattsconnected",
        category: "battery"
    )
    
    private let batteryProvider = BatteryInfoProvider()
    private var textFormatter = StatusTextFormatter()
    
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
                title: "Quit WattsConnected",
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
        var desiredInterval: TimeInterval = Constants.slowInterval
        
        let status = batteryProvider.currentChargingStatus()
        let adapter = batteryProvider.readAdapterWattage()
        let displayTextComputed = textFormatter.text(for: status, adapterWattage: adapter)
        
        if let st = status {
            if st.onAC {
                desiredInterval = st.isCharging ? Constants.chargingInterval : Constants.slowInterval
            } else {
                desiredInterval = Constants.batteryInterval
            }
        } else {
            desiredInterval = Constants.slowInterval
        }
        
        displayText = displayTextComputed
        
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
