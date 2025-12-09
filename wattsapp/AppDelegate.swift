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
    
    // MARK: - Update Interval Mode
    private enum UpdateIntervalMode: Int { case fast, automatic, slow }
    private var updateIntervalMode: UpdateIntervalMode = .automatic

    // MARK: - Menu Items References
    private var statusDetailItem: NSMenuItem?
    private var updateIntervalMenuItem: NSMenuItem?
    private var updateIntervalFastItem: NSMenuItem?
    private var updateIntervalAutoItem: NSMenuItem?
    private var updateIntervalSlowItem: NSMenuItem?
    
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

        // 状態詳細（上部）
        let detail = NSMenuItem(title: "状態: 取得中…", action: nil, keyEquivalent: "")
        detail.isEnabled = false
        menu.addItem(detail)
        self.statusDetailItem = detail

        menu.addItem(NSMenuItem.separator())

        // 更新間隔サブメニュー
        let intervalSubmenu = NSMenu(title: "更新間隔")

        let fast = NSMenuItem(title: "高頻度（約1.5秒）", action: #selector(selectUpdateInterval(_:)), keyEquivalent: "")
        fast.tag = UpdateIntervalMode.fast.rawValue
        fast.target = self
        intervalSubmenu.addItem(fast)
        self.updateIntervalFastItem = fast

        let auto = NSMenuItem(title: "標準（自動）", action: #selector(selectUpdateInterval(_:)), keyEquivalent: "")
        auto.tag = UpdateIntervalMode.automatic.rawValue
        auto.target = self
        intervalSubmenu.addItem(auto)
        self.updateIntervalAutoItem = auto

        let slow = NSMenuItem(title: "低頻度（5秒）", action: #selector(selectUpdateInterval(_:)), keyEquivalent: "")
        slow.tag = UpdateIntervalMode.slow.rawValue
        slow.target = self
        intervalSubmenu.addItem(slow)
        self.updateIntervalSlowItem = slow

        let interval = NSMenuItem()
        interval.title = "更新間隔"
        interval.submenu = intervalSubmenu
        menu.addItem(interval)
        self.updateIntervalMenuItem = interval

        menu.addItem(NSMenuItem.separator())

        // Quit
        menu.addItem(NSMenuItem(title: "Quit WattsConnected", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        self.statusMenu = menu

        refreshUpdateIntervalChecks()
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
        Task.detached { [weak self] in
            await self?.updateWattageAsync()
        }
    }
    
    private func updateMenuItems(with status: PowerStatus?, adapterWattage: Int, effectiveText: String) {
        var parts: [String] = []
        if let st = status {
            if st.onAC {
                let state = st.isCharging ? "充電中" : "AC接続"
                parts.append("状態: \(state)")
                if adapterWattage > 0 {
                    parts.append("アダプタ: \(adapterWattage)W")
                }
            } else {
                parts.append("状態: バッテリー駆動")
            }
        } else {
            parts.append("状態: 取得不可")
            if adapterWattage > 0 { parts.append("アダプタ: \(adapterWattage)W") }
        }
        parts.append("実効: \(effectiveText)")
        statusDetailItem?.title = parts.joined(separator: " / ")
    }

    private func refreshUpdateIntervalChecks() {
        updateIntervalFastItem?.state = (updateIntervalMode == .fast) ? .on : .off
        updateIntervalAutoItem?.state = (updateIntervalMode == .automatic) ? .on : .off
        updateIntervalSlowItem?.state = (updateIntervalMode == .slow) ? .on : .off
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds > 0 else { return "--:--" }
        let m = Int(seconds) / 60
        let h = m / 60
        let min = m % 60
        return String(format: "%d:%02d", h, min)
    }
    
    private func updateWattageAsync() async {
        // Perform data fetching off the main thread
        let status = batteryProvider.currentChargingStatus()
        let adapter = batteryProvider.readAdapterWattage()
        let displayTextComputed = textFormatter.text(for: status, adapterWattage: adapter)

        var desiredInterval: TimeInterval
        switch updateIntervalMode {
        case .fast:
            desiredInterval = 1.5
        case .automatic:
            if let st = status {
                desiredInterval = st.onAC ? (st.isCharging ? Constants.chargingInterval : Constants.slowInterval) : Constants.batteryInterval
            } else {
                desiredInterval = Constants.slowInterval
            }
        case .slow:
            desiredInterval = Constants.slowInterval
        }

        // Hop to main for timer scheduling and UI updates
        await MainActor.run {
            self.scheduleTimerIfNeeded(desiredInterval)
            if self.lastDisplayText != displayTextComputed {
                self.statusItem.button?.title = displayTextComputed
                self.lastDisplayText = displayTextComputed
            }
            self.updateMenuItems(with: status, adapterWattage: adapter, effectiveText: displayTextComputed)
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
    
    @objc private func selectUpdateInterval(_ sender: NSMenuItem) {
        guard let mode = UpdateIntervalMode(rawValue: sender.tag) else { return }
        updateIntervalMode = mode
        refreshUpdateIntervalChecks()
        updateWattage()
    }
}
