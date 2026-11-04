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

    // MARK: - Detail Text

    /// メニュー先頭に出す「状態: … / アダプタ: … / 実効: …」の文字列。
    nonisolated static func statusDetailText(status: PowerStatus?, adapterWattage: Int, wattageText: String) -> String {
        var parts: [String] = []
        if let status {
            if status.onAC {
                parts.append("状態: \(status.isCharging ? "充電中" : "AC接続")")
                if adapterWattage > 0 {
                    parts.append("アダプタ: \(adapterWattage)W")
                }
            } else {
                parts.append("状態: バッテリー駆動")
            }
        } else {
            parts.append("状態: 取得不可")
            if adapterWattage > 0 {
                parts.append("アダプタ: \(adapterWattage)W")
            }
        }
        parts.append("実効: \(wattageText)")
        return parts.joined(separator: " / ")
    }
}
