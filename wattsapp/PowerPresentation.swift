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
    nonisolated static func statusLines(status: PowerStatus?, adapterWattage: Int) -> [String] {
        let adapterSuffix = adapterWattage > 0 ? " / アダプタ: \(adapterWattage)W" : ""

        guard let status else {
            return ["状態: 取得不可" + adapterSuffix]
        }

        var lines: [String] = []
        if status.onAC {
            lines.append("状態: \(status.isCharging ? "充電中" : "AC接続")" + adapterSuffix)
        } else {
            lines.append("状態: バッテリー駆動")
        }

        lines.append("消費電力: \(wattsText(status.consumptionWatts))")

        if status.onAC, let input = status.adapterInputWatts {
            lines.append("アダプタからの入力: \(wattsText(input))")
        }

        // バッテリー駆動中は放電 = 消費電力なので重複して出さない
        if status.batteryWatts >= noiseFloorWatts {
            lines.append("バッテリーへの充電: \(wattsText(status.batteryWatts))")
        } else if status.onAC, status.batteryWatts <= -noiseFloorWatts {
            // AC 接続中でも負荷がアダプタの能力を超えるとバッテリーからも給電する
            lines.append("バッテリーからの補助: \(wattsText(-status.batteryWatts))")
        }

        return lines
    }
}
