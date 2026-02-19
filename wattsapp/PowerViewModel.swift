import Foundation
import Combine
import Cocoa
import IOKit.ps

private enum Constants: Sendable {
    nonisolated static let chargingInterval: TimeInterval = 2.0
    nonisolated static let batteryInterval: TimeInterval = 3.0
    nonisolated static let slowInterval: TimeInterval = 5.0
    nonisolated static let timerTolerance: Double = 0.2
}

enum UpdateIntervalMode: Int, CaseIterable, Identifiable, Sendable {
    case fast
    case automatic
    case slow
    
    var id: Int { rawValue }
    
    nonisolated var title: String {
        switch self {
        case .fast: return "高頻度（約1.5秒）"
        case .automatic: return "標準（自動）"
        case .slow: return "低頻度（5秒）"
        }
    }
    
    nonisolated var infoDescription: String {
        switch self {
        case .fast:
            return "約1.5秒ごとに更新します。リアルタイムで変化を追いたい時に便利ですが、バッテリー消費がやや増えます。"
        case .automatic:
            return "電源の状態に応じて自動で間隔を調整します。充電中は2秒、バッテリー駆動中は3秒、AC接続（非充電）時は5秒で更新します。"
        case .slow:
            return "5秒ごとに更新します。バッテリー消費を抑えたい場合におすすめです。"
        }
    }
}

class PowerViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var menuBarText: String = "---W"
    @Published var menuBarIcon: String = "bolt.fill"
    @Published var statusDetailText: String = "状態: 取得中…"
    @Published var batteryDetail: BatteryDetailInfo?
    @Published var updateIntervalMode: UpdateIntervalMode = .automatic {
        didSet {
            AppSettings.shared.savedUpdateIntervalMode = updateIntervalMode.rawValue
            updateWattage()
        }
    }
    
    // MARK: - Private Properties
    
    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var timer: Timer?
    private var currentInterval: TimeInterval = 3.0
    private var settingsCancellable: AnyCancellable?
    
    private let batteryProvider = BatteryInfoProvider()
    private let textFormatter = StatusTextFormatter()
    
    // MARK: - Init
    
    init() {
        // Restore persisted update interval
        if let saved = UpdateIntervalMode(rawValue: AppSettings.shared.savedUpdateIntervalMode) {
            updateIntervalMode = saved
        }
        
        // Listen for settings changes to re-render menu bar text
        settingsCancellable = AppSettings.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateWattage()
            }
        
        startMonitoring()
    }
    
    // MARK: - Monitoring Setup
    
    private func startMonitoring() {
        updateWattage()
        setupPowerSourceNotification()
    }
    
    private func setupPowerSourceNotification() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let runLoopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let viewModel = Unmanaged<PowerViewModel>
                .fromOpaque(context)
                .takeUnretainedValue()
            
            Task { @MainActor in
                viewModel.updateWattage()
            }
        }, context).takeRetainedValue()
        
        self.powerSourceRunLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
    }
    
    // MARK: - Update Logic
    
    func updateWattage() {
        let batteryProvider = self.batteryProvider
        let textFormatter = self.textFormatter
        let currentMode = self.updateIntervalMode
        
        // Read settings on MainActor before entering detached task
        let s = AppSettings.shared
        let needsDetail = s.showBatteryPercentage
            || s.showBatteryHealth
            || s.showCycleCount
            || s.showTemperature
            || s.showTimeRemaining
            || s.menuBarStyle != .textOnly  // icon needs battery % to pick the right SF Symbol
        
        Task.detached {
            let status = batteryProvider.currentChargingStatus()
            let adapter = batteryProvider.readAdapterWattage()
            let detail = needsDetail ? batteryProvider.detailedBatteryInfo() : nil
            let displayTextComputed = textFormatter.text(for: status, adapterWattage: adapter)
            
            // Determine icon
            let icon: String = {
                guard let st = status else { return "questionmark.circle" }
                if st.onAC {
                    return st.isCharging ? "bolt.fill" : "powerplug.fill"
                } else {
                    guard let d = detail else { return "battery.50" }
                    let pct = d.percentage
                    switch pct {
                    case 76...100: return "battery.100"
                    case 51...75:  return "battery.75"
                    case 26...50:  return "battery.50"
                    case 11...25:  return "battery.25"
                    default:       return "battery.0"
                    }
                }
            }()
            
            // Determine interval
            let desiredInterval: TimeInterval = {
                switch currentMode {
                case .fast:
                    return 1.5
                case .automatic:
                    if let st = status {
                        return st.onAC ? (st.isCharging ? Constants.chargingInterval : Constants.slowInterval) : Constants.batteryInterval
                    } else {
                        return Constants.slowInterval
                    }
                case .slow:
                    return Constants.slowInterval
                }
            }()
            
            // Construct detail text
            var parts: [String] = []
            if let st = status {
                if st.onAC {
                    let state = st.isCharging ? "充電中" : "AC接続"
                    parts.append("状態: \(state)")
                    if adapter > 0 {
                        parts.append("アダプタ: \(adapter)W")
                    }
                } else {
                    parts.append("状態: バッテリー駆動")
                }
            } else {
                parts.append("状態: 取得不可")
                if adapter > 0 { parts.append("アダプタ: \(adapter)W") }
            }
            parts.append("実効: \(displayTextComputed)")
            let detailText = parts.joined(separator: " / ")
            
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.scheduleTimerIfNeeded(desiredInterval)
                self.menuBarText = displayTextComputed
                self.menuBarIcon = icon
                self.statusDetailText = detailText
                self.batteryDetail = detail
            }
        }
    }
    
    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()
        currentInterval = interval
        
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateWattage()
        }
        t.tolerance = interval * Constants.timerTolerance
        timer = t
    }
    
    private func scheduleTimerIfNeeded(_ newInterval: TimeInterval) {
        if abs(newInterval - currentInterval) > 0.01 || timer == nil {
            scheduleTimer(interval: newInterval)
        }
    }
}
