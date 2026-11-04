import Foundation

/// 電源の状態から「画面に何を出すか」を決める純粋関数群。
/// 副作用を持たないので、ユニットテストで挙動を固定できる。
enum PowerPresentation {

    // MARK: - Update Interval

    nonisolated static let fastInterval: TimeInterval = 1.5
    nonisolated static let chargingInterval: TimeInterval = 2.0
    nonisolated static let batteryInterval: TimeInterval = 3.0
    nonisolated static let slowInterval: TimeInterval = 5.0

    /// 更新モードと電源の状態から、次の更新までの間隔を決める。
    nonisolated static func updateInterval(mode: UpdateIntervalMode, status: PowerStatus?) -> TimeInterval {
        switch mode {
        case .fast:
            return fastInterval
        case .slow:
            return slowInterval
        case .automatic:
            guard let status else { return slowInterval }
            if status.onAC {
                return status.isCharging ? chargingInterval : slowInterval
            }
            return batteryInterval
        }
    }

    // MARK: - Icons

    /// バッテリー残量 (%) に対応する SF Symbol 名。
    /// メニューバーとメニュー内の両方でこの関数を使い、しきい値を一か所にまとめる。
    nonisolated static func batteryIcon(percentage: Int) -> String {
        switch percentage {
        case 76...:    return "battery.100"
        case 51...75:  return "battery.75"
        case 26...50:  return "battery.50"
        case 11...25:  return "battery.25"
        default:       return "battery.0"
        }
    }

    /// メニューバーに出すアイコン。
    nonisolated static func menuBarIcon(status: PowerStatus?, batteryPercentage: Int?) -> String {
        guard let status else { return "questionmark.circle" }
        if status.onAC {
            return status.isCharging ? "bolt.fill" : "powerplug.fill"
        }
        guard let batteryPercentage else { return "battery.50" }
        return batteryIcon(percentage: batteryPercentage)
    }

    // MARK: - Text

    /// これ未満の充放電はノイズとして扱う (W)。
    nonisolated static let noiseFloorWatts: Double = 0.1

    nonisolated static func wattsText(_ watts: Double?) -> String {
        guard let watts else { return "---W" }
        return String(format: "%.1fW", max(0, watts))
    }

    /// メニューバーに出す文字列。常に「Mac 本体の消費電力」を表示する。
    nonisolated static func menuBarText(status: PowerStatus?) -> String {
        wattsText(status?.consumptionWatts)
    }

    /// メニュー先頭に並べる行（状態と電力の内訳）。
    /// 文言への変換は `StatusLine.localizedText` で行うので、ここでの判定は言語に依存しない。
    nonisolated static func statusLines(status: PowerStatus?, adapterWattage: Int) -> [StatusLine] {
        let adapter = adapterWattage > 0 ? adapterWattage : nil

        guard let status else {
            return [.state(.unavailable, adapterWatts: adapter)]
        }

        var lines: [StatusLine] = []
        if status.onAC {
            lines.append(.state(status.isCharging ? .charging : .pluggedIn, adapterWatts: adapter))
        } else {
            lines.append(.state(.onBattery, adapterWatts: nil))
        }

        lines.append(.consumption(watts: status.consumptionWatts))

        if status.onAC, let input = status.adapterInputWatts {
            lines.append(.adapterInput(watts: input))
        }

        // バッテリー駆動中は放電 = 消費電力なので重複して出さない
        if status.batteryWatts >= noiseFloorWatts {
            lines.append(.batteryCharging(watts: status.batteryWatts))
        } else if status.onAC, status.batteryWatts <= -noiseFloorWatts {
            // AC 接続中でも負荷がアダプタの能力を超えるとバッテリーからも給電する
            lines.append(.batteryAssist(watts: -status.batteryWatts))
        }

        return lines
    }
}

// MARK: - Status Line

enum PowerState: Equatable, Sendable {
    case loading
    case unavailable
    case charging
    case pluggedIn
    case onBattery

    nonisolated var localizedText: String {
        switch self {
        case .loading:     return String(localized: "Status: Loading…")
        case .unavailable: return String(localized: "Status: Unavailable")
        case .charging:    return String(localized: "Status: Charging")
        case .pluggedIn:   return String(localized: "Status: Plugged In")
        case .onBattery:   return String(localized: "Status: On Battery")
        }
    }
}

/// メニュー先頭の 1 行。
enum StatusLine: Equatable, Sendable {
    case state(PowerState, adapterWatts: Int?)
    case consumption(watts: Double?)
    case adapterInput(watts: Double)
    case batteryCharging(watts: Double)
    case batteryAssist(watts: Double)

    nonisolated var localizedText: String {
        switch self {
        case let .state(state, adapterWatts):
            let stateText = state.localizedText
            guard let adapterWatts else { return stateText }
            return String(localized: "\(stateText) / Adapter: \(adapterWatts)W")
        case let .consumption(watts):
            return String(localized: "Power Draw: \(PowerPresentation.wattsText(watts))")
        case let .adapterInput(watts):
            return String(localized: "Adapter Input: \(PowerPresentation.wattsText(watts))")
        case let .batteryCharging(watts):
            return String(localized: "Charging Battery: \(PowerPresentation.wattsText(watts))")
        case let .batteryAssist(watts):
            return String(localized: "Battery Assist: \(PowerPresentation.wattsText(watts))")
        }
    }
}
