import Foundation
import IOKit.ps
import IOKit.pwr_mgt
import IOKit
import os.log

public struct PowerStatus: Sendable {
    public let watts: Double
    public let isCharging: Bool
    public let onAC: Bool
}

public struct BatteryDetailInfo: Sendable {
    public let currentCapacity: Int      // 現在の容量 (mAh)
    public let maxCapacity: Int          // 最大容量 (mAh)
    public let designCapacity: Int       // 設計容量 (mAh)
    public let cycleCount: Int           // 充電サイクル数
    public let temperature: Double       // 温度 (°C)
    public let timeToEmpty: Int?         // 残り時間 (分), nil = 計算不可
    public let timeToFull: Int?          // 満充電までの時間 (分), nil = 計算不可
    public let osHealthPercent: Int?     // macOS が提供するバッテリー健康度 (%)
    
    /// バッテリー残量 (0-100%)
    public nonisolated var percentage: Int {
        guard maxCapacity > 0 else { return 0 }
        return min(100, (currentCapacity * 100) / maxCapacity)
    }
    
    /// バッテリー健康度 (0-100%)
    public nonisolated var healthPercentage: Int {
        // macOS が直接提供する値を優先
        if let osHealth = osHealthPercent, osHealth > 0 {
            return osHealth
        }
        // フォールバック: 計算で求める
        guard designCapacity > 0, maxCapacity > 0 else { return 0 }
        return min(100, (maxCapacity * 100) / designCapacity)
    }
}

public final class BatteryInfoProvider: Sendable {
    private nonisolated let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.wattsconnected",
        category: "battery"
    )

    public nonisolated init() {}

    private nonisolated func readBatteryInfo() -> [String: Any]? {
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

    public nonisolated func currentChargingStatus() -> PowerStatus? {
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

    public nonisolated func detailedBatteryInfo() -> BatteryDetailInfo? {
        guard let info = readBatteryInfo() else { return nil }

        // Apple Silicon: AppleRawCurrentCapacity/AppleRawMaxCapacity are mAh
        // Intel: CurrentCapacity/MaxCapacity are mAh
        // On Apple Silicon, CurrentCapacity/MaxCapacity may return percentages
        let currentCapacity = (info["AppleRawCurrentCapacity"] as? Int)
            ?? (info["CurrentCapacity"] as? Int)
            ?? 0
        let maxCapacity = (info["AppleRawMaxCapacity"] as? Int)
            ?? (info["MaxCapacity"] as? Int)
            ?? 0
        let designCapacity = (info["DesignCapacity"] as? Int) ?? 0
        let cycleCount = (info["CycleCount"] as? Int) ?? 0
        
        // macOS が提供するバッテリー健康度（Apple Silicon で利用可能）
        let osHealthPercent = info["BatteryHealthMaximumCapacityPercent"] as? Int

        // Temperature is in centi-degrees (e.g., 2930 = 29.30°C)
        let rawTemp = (info["Temperature"] as? Int) ?? 0
        let temperature = Double(rawTemp) / 100.0

        let timeToEmpty: Int? = {
            guard let minutes = info["AvgTimeToEmpty"] as? Int, minutes > 0, minutes < 65535 else { return nil }
            return minutes
        }()

        let timeToFull: Int? = {
            guard let minutes = info["AvgTimeToFull"] as? Int, minutes > 0, minutes < 65535 else { return nil }
            return minutes
        }()

        return BatteryDetailInfo(
            currentCapacity: currentCapacity,
            maxCapacity: maxCapacity,
            designCapacity: designCapacity,
            cycleCount: cycleCount,
            temperature: temperature,
            timeToEmpty: timeToEmpty,
            timeToFull: timeToFull,
            osHealthPercent: osHealthPercent
        )
    }

    public nonisolated func readAdapterWattage() -> Int {
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
