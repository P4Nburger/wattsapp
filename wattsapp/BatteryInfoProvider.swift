import Foundation
import IOKit.ps
import IOKit.pwr_mgt
import IOKit
import os.log

public struct PowerStatus: Sendable {
    /// バッテリーの充放電電力 (W)。+ が充電、− が放電。
    public let batteryWatts: Double
    public let isCharging: Bool
    public let onAC: Bool
    /// Mac 本体の消費電力 (W)。PowerTelemetryData がある機種（Apple Silicon）のみ。
    public let systemLoadWatts: Double?
    /// 電源アダプタからの入力電力 (W)。PowerTelemetryData がある機種の AC 接続中のみ。
    public let adapterInputWatts: Double?

    public nonisolated init(
        batteryWatts: Double,
        isCharging: Bool,
        onAC: Bool,
        systemLoadWatts: Double? = nil,
        adapterInputWatts: Double? = nil
    ) {
        self.batteryWatts = batteryWatts
        self.isCharging = isCharging
        self.onAC = onAC
        self.systemLoadWatts = systemLoadWatts
        self.adapterInputWatts = adapterInputWatts
    }

    /// Mac 本体の消費電力 (W)。
    /// テレメトリがあればその値を使い、なければバッテリー駆動中の放電電力で代用する。
    /// テレメトリがなく AC 接続中のときは測れないので nil。
    public nonisolated var consumptionWatts: Double? {
        if let systemLoadWatts { return systemLoadWatts }
        if !onAC { return max(0, -batteryWatts) }
        return nil
    }
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

public struct BatteryReading: Sendable {
    public let status: PowerStatus
    public let detail: BatteryDetailInfo?
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

    /// AppleSmartBattery を 1 回だけ読み、状態と（必要なら）詳細を返す。
    public nonisolated func readBattery(includeDetail: Bool) -> BatteryReading? {
        guard let info = readBatteryInfo() else { return nil }
        return BatteryReading(
            status: Self.parseStatus(info),
            detail: includeDetail ? Self.parseDetail(info) : nil
        )
    }

    // MARK: - Parsing (pure, testable)

    public nonisolated static func parseStatus(_ info: [String: Any]) -> PowerStatus {
        let isCharging = (info["IsCharging"] as? Bool) ?? false
        let onAC = (info["ExternalConnected"] as? Bool) ?? false

        // Apple Silicon では PowerTelemetryData に本体の消費電力・入力電力が入っている。
        // 入力 (SystemPowerIn) = 本体 (SystemLoad) + バッテリーへの充電 (BatteryPower) の関係になる。
        let telemetry = info["PowerTelemetryData"] as? [String: Any]
        let systemLoad = milliwattsToWatts(telemetry?["SystemLoad"]).flatMap { $0 > 0 ? $0 : nil }
        let adapterInput = onAC ? milliwattsToWatts(telemetry?["SystemPowerIn"]) : nil

        let batteryWatts: Double
        if let telemetryBatteryWatts = milliwattsToWatts(telemetry?["BatteryPower"]) {
            batteryWatts = telemetryBatteryWatts
        } else if let amperage = signedInt(info["Amperage"]),
                  let voltage = signedInt(info["Voltage"]) {
            // mA × mV = µW
            batteryWatts = Double(amperage) * Double(voltage) / 1_000_000.0
        } else {
            batteryWatts = 0
        }

        return PowerStatus(
            batteryWatts: batteryWatts,
            isCharging: isCharging,
            onAC: onAC,
            systemLoadWatts: systemLoad,
            adapterInputWatts: adapterInput
        )
    }

    /// IORegistry の整数を符号付きで読む。
    /// ioreg では負の値が 18446744073709551265 のような符号なし整数で表示されるが、
    /// ビット列としては符号付き 64bit（この例では -351）。
    /// 符号付きで取れればそのまま、符号なしで来た場合はビット列を符号付きとして読み直す。
    private nonisolated static func signedInt(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let uint = value as? UInt64 { return Int(Int64(bitPattern: uint)) }
        return nil
    }

    private nonisolated static func milliwattsToWatts(_ value: Any?) -> Double? {
        signedInt(value).map { Double($0) / 1000.0 }
    }

    public nonisolated static func parseDetail(_ info: [String: Any]) -> BatteryDetailInfo {
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

        return BatteryDetailInfo(
            currentCapacity: currentCapacity,
            maxCapacity: maxCapacity,
            designCapacity: designCapacity,
            cycleCount: cycleCount,
            temperature: temperature,
            timeToEmpty: validMinutes(info["AvgTimeToEmpty"]),
            timeToFull: validMinutes(info["AvgTimeToFull"]),
            osHealthPercent: osHealthPercent
        )
    }

    /// 65535 は「計算中・不明」を表すので nil にする。
    private nonisolated static func validMinutes(_ value: Any?) -> Int? {
        guard let minutes = value as? Int, minutes > 0, minutes < 65535 else { return nil }
        return minutes
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
