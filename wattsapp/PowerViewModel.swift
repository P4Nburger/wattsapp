import Foundation
import Combine
import IOKit.ps

final class PowerViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var menuBarText: String = "---W"
    @Published var menuBarIcon: String = "bolt.fill"
    @Published var statusLines: [StatusLine] = [.state(.loading, adapterWatts: nil)]
    @Published var batteryDetail: BatteryDetailInfo?

    // MARK: - Private Properties

    private static let timerTolerance: Double = 0.2

    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var timer: Timer?
    private var currentInterval: TimeInterval?
    private var settingsCancellable: AnyCancellable?

    private let batteryProvider = BatteryInfoProvider()

    // MARK: - Init

    init() {
        // 設定（表示項目・更新間隔など）が変わったら即座に再取得する
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
        // .commonModes: メニューを開いている間（イベントトラッキング中）も通知を受け取る
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }

    // MARK: - Update Logic

    func updateWattage() {
        let batteryProvider = self.batteryProvider

        // Read settings on MainActor before entering detached task
        let s = AppSettings.shared
        let mode = s.updateIntervalMode
        let needsDetail = s.showBatteryPercentage
            || s.showBatteryHealth
            || s.showCycleCount
            || s.showTemperature
            || s.showTimeRemaining
            || s.menuBarStyle != .textOnly  // icon needs battery % to pick the right SF Symbol

        Task.detached {
            let reading = batteryProvider.readBattery(includeDetail: needsDetail)
            let status = reading?.status
            let detail = reading?.detail
            let adapter = batteryProvider.readAdapterWattage()

            let menuBarText = PowerPresentation.menuBarText(status: status)
            let icon = PowerPresentation.menuBarIcon(status: status, batteryPercentage: detail?.percentage)
            let interval = PowerPresentation.updateInterval(mode: mode, status: status)
            let lines = PowerPresentation.statusLines(status: status, adapterWattage: adapter)

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.scheduleTimerIfNeeded(interval)
                self.menuBarText = menuBarText
                self.menuBarIcon = icon
                self.statusLines = lines
                self.batteryDetail = detail
            }
        }
    }

    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()
        currentInterval = interval

        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateWattage()
        }
        t.tolerance = interval * Self.timerTolerance
        // .common: メニューを開いている間もタイマーを止めない
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func scheduleTimerIfNeeded(_ newInterval: TimeInterval) {
        if timer == nil || currentInterval.map({ abs(newInterval - $0) > 0.01 }) ?? true {
            scheduleTimer(interval: newInterval)
        }
    }
}
