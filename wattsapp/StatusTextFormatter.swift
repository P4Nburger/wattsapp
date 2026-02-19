import Foundation

public struct StatusTextFormatter: Sendable {
    public var noiseFloorWatts: Double
    public var chargingSymbol: String
    public var adapterSymbol: String
    public var batterySymbol: String

    public init(noiseFloorWatts: Double = 0.1,
                chargingSymbol: String = "⚡️",
                adapterSymbol: String = "🔌",
                batterySymbol: String = "🔋") {
        self.noiseFloorWatts = noiseFloorWatts
        self.chargingSymbol = chargingSymbol
        self.adapterSymbol = adapterSymbol
        self.batterySymbol = batterySymbol
    }

    public nonisolated func text(for status: PowerStatus?, adapterWattage: Int) -> String {
        if let status = status {
            if status.onAC {
                let value = max(0.0, status.watts)
                if value >= noiseFloorWatts {
                    return String(format: "%@ %.1fW", chargingSymbol, value)
                } else {
                    if adapterWattage > 0 {
                        return "\(adapterSymbol) \(adapterWattage)W"
                    } else {
                        return "\(adapterSymbol) 0W"
                    }
                }
            } else {
                let discharge = max(0.0, -status.watts)
                return String(format: "%@ %.1fW", batterySymbol, discharge)
            }
        } else {
            if adapterWattage > 0 {
                return "\(adapterSymbol) \(adapterWattage)W"
            } else {
                return "\(batterySymbol) On Battery"
            }
        }
    }
}
