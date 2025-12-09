import Foundation
import IOKit.ps
import IOKit.pwr_mgt
import IOKit
import os.log

public struct PowerStatus {
    public let watts: Double
    public let isCharging: Bool
    public let onAC: Bool
}

public final class BatteryInfoProvider {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.wattsconnected",
        category: "battery"
    )

    public init() {}

    private func readBatteryInfo() -> [String: Any]? {
        guard let matching = IOServiceMatching("AppleSmartBattery") else { return nil }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)

        if service == 0 {
            logger.warning("AppleSmartBattery service not found")
            return nil
        }

        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(
            service,
            &properties,
            kCFAllocatorDefault,
            0
        )

        IOObjectRelease(service)

        if result != KERN_SUCCESS {
            logger.error("Failed to create CF properties for battery: kern = \(result)")
            return nil
        }

        guard let dict = properties?.takeRetainedValue() as? [String: Any] else {
            logger.error("Battery properties dictionary is missing or invalid")
            return nil
        }

        return dict
    }

    public func currentChargingStatus() -> PowerStatus? {
        guard let info = readBatteryInfo() else { return nil }

        let isCharging = (info["IsCharging"] as? Bool) ?? false
        let onAC = (info["ExternalConnected"] as? Bool) ?? false

        var watts: Double = 0.0
        if let amperage = info["Amperage"] as? Int,
           let voltage = info["Voltage"] as? Int {
            let powerMilliwatts = Double(amperage) * Double(voltage)
            watts = powerMilliwatts / 1_000_000.0
        }

        return PowerStatus(watts: watts, isCharging: isCharging, onAC: onAC)
    }

    public func readAdapterWattage() -> Int {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            logger.debug("snapshot is nil")
            return 0
        }

        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            logger.debug("sources is nil")
            return 0
        }

        var adapterWattage = 0

        for ps in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            if let sourceState = info[kIOPSPowerSourceStateKey] as? String,
               sourceState == kIOPSACPowerValue,
               let watts = info[kIOPSPowerAdapterWattsKey] as? Int {
                adapterWattage = watts
                break
            }
        }

        if adapterWattage == 0 {
            logger.debug("No AC adapter wattage found (may be on battery)")
        }

        return adapterWattage
    }
}
