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
}

class PowerViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var menuBarText: String = "---W"
    @Published var statusDetailText: String = "状態: 取得中…"
    @Published var batteryDetail: BatteryDetailInfo?
    @Published var updateIntervalMode: UpdateIntervalMode = .automatic {
        didSet {
            updateWattage()
        }
    }
    
    // MARK: - Private Properties
    
    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var timer: Timer?
    private var currentInterval: TimeInterval = 3.0
    
    private let batteryProvider = BatteryInfoProvider()
    private let textFormatter = StatusTextFormatter()
    
    // MARK: - Init
    
    init() {
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
        
        Task.detached {
            let status = batteryProvider.currentChargingStatus()
            let adapter = batteryProvider.readAdapterWattage()
            let detail = batteryProvider.detailedBatteryInfo()
            let displayTextComputed = textFormatter.text(for: status, adapterWattage: adapter)
            
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
                if self.menuBarText != displayTextComputed {
                    self.menuBarText = displayTextComputed
                }
                if self.statusDetailText != detailText {
                    self.statusDetailText = detailText
                }
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
