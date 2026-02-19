import Foundation

public struct StatusTextFormatter: Sendable {
    public var noiseFloorWatts: Double

    public init(noiseFloorWatts: Double = 0.1) {
        self.noiseFloorWatts = noiseFloorWatts
    }

    /// Returns wattage text WITHOUT emoji icons (icon is handled by SF Symbols in the menu bar).
    public nonisolated func text(for status: PowerStatus?, adapterWattage: Int) -> String {
        if let status = status {
            if status.onAC {
                let value = max(0.0, status.watts)
                if value >= noiseFloorWatts {
                    return String(format: "%.1fW", value)
                } else {
                    return adapterWattage > 0 ? "\(adapterWattage)W" : "0W"
                }
            } else {
                let discharge = max(0.0, -status.watts)
                return String(format: "%.1fW", discharge)
            }
        } else {
            return adapterWattage > 0 ? "\(adapterWattage)W" : "---W"
        }
    }
}
