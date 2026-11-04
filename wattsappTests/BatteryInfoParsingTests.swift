import XCTest
@testable import WattsApp

/// AppleSmartBattery の辞書をどう解釈するかのテスト。
/// 実機の `ioreg -rn AppleSmartBattery` の値を模した辞書を使う。
@MainActor
final class BatteryInfoParsingTests: XCTestCase {

    // MARK: - Status（実機の値）

    /// `ioreg -rn AppleSmartBattery` の実測値（バッテリー駆動中）。
    /// ioreg では負の値が巨大な符号なし整数で表示されるので、そのままの値で検証する。
    func testParseStatusOnBatteryFromRealDevice() {
        let info: [String: Any] = [
            "Amperage": UInt64(18446744073709551265),   // = -351 mA
            "Voltage": 12243,
            "IsCharging": false,
            "ExternalConnected": false,
            "PowerTelemetryData": [
                "SystemLoad": 4396,
                "SystemPowerIn": 0,
                "BatteryPower": UInt64(18446744073709547220), // = -4396 mW
            ] as [String: Any],
        ]
        let status = BatteryInfoProvider.parseStatus(info)
        XCTAssertFalse(status.onAC)
        XCTAssertFalse(status.isCharging)
        XCTAssertEqual(status.batteryWatts, -4.396, accuracy: 0.0001)
        XCTAssertEqual(status.systemLoadWatts ?? -1, 4.396, accuracy: 0.0001)
        XCTAssertNil(status.adapterInputWatts)
        XCTAssertEqual(status.consumptionWatts ?? -1, 4.396, accuracy: 0.0001)
    }

    /// 実測値（20W アダプタで充電中）。入力 18.8W = 本体 5.2W + 充電 13.7W。
    func testParseStatusWhileChargingFromRealDevice() {
        let info: [String: Any] = [
            "Amperage": 1097,
            "Voltage": 12685,
            "IsCharging": true,
            "ExternalConnected": true,
            "PowerTelemetryData": [
                "SystemLoad": 5160,
                "SystemPowerIn": 18819,
                "BatteryPower": 13659,
            ] as [String: Any],
        ]
        let status = BatteryInfoProvider.parseStatus(info)
        XCTAssertTrue(status.onAC)
        XCTAssertTrue(status.isCharging)
        XCTAssertEqual(status.batteryWatts, 13.659, accuracy: 0.0001)
        XCTAssertEqual(status.systemLoadWatts ?? -1, 5.160, accuracy: 0.0001)
        XCTAssertEqual(status.adapterInputWatts ?? -1, 18.819, accuracy: 0.0001)
        XCTAssertEqual(status.consumptionWatts ?? -1, 5.160, accuracy: 0.0001)
    }

    // MARK: - Status（テレメトリなし）

    func testParseStatusWithoutTelemetryUsesAmperageTimesVoltage() {
        let info: [String: Any] = [
            "Amperage": -1500,       // mA（放電中は負）
            "Voltage": 12_000,       // mV
            "ExternalConnected": false,
        ]
        let status = BatteryInfoProvider.parseStatus(info)
        XCTAssertEqual(status.batteryWatts, -18.0, accuracy: 0.0001)
        XCTAssertNil(status.systemLoadWatts)
        XCTAssertEqual(status.consumptionWatts ?? -1, 18.0, accuracy: 0.0001)
    }

    func testParseStatusReadsUnsignedNegativeAmperage() {
        let info: [String: Any] = [
            "Amperage": UInt64(18446744073709551265),   // = -351 mA
            "Voltage": 12243,
        ]
        let status = BatteryInfoProvider.parseStatus(info)
        XCTAssertEqual(status.batteryWatts, -4.297293, accuracy: 0.000001)
    }

    func testConsumptionIsUnknownOnACWithoutTelemetry() {
        let info: [String: Any] = ["Amperage": 0, "Voltage": 12_000, "ExternalConnected": true]
        XCTAssertNil(BatteryInfoProvider.parseStatus(info).consumptionWatts)
    }

    func testParseStatusDefaultsWhenKeysAreMissing() {
        let status = BatteryInfoProvider.parseStatus([:])
        XCTAssertEqual(status.batteryWatts, 0)
        XCTAssertFalse(status.isCharging)
        XCTAssertFalse(status.onAC)
        XCTAssertNil(status.systemLoadWatts)
    }

    // MARK: - Detail

    func testParseDetailPrefersRawCapacities() {
        let info: [String: Any] = [
            "AppleRawCurrentCapacity": 4_000,
            "AppleRawMaxCapacity": 5_000,
            "CurrentCapacity": 80,   // Apple Silicon ではパーセント値が入る
            "MaxCapacity": 100,
            "DesignCapacity": 6_000,
        ]
        let detail = BatteryInfoProvider.parseDetail(info)
        XCTAssertEqual(detail.currentCapacity, 4_000)
        XCTAssertEqual(detail.maxCapacity, 5_000)
        XCTAssertEqual(detail.percentage, 80)
    }

    func testParseDetailFallsBackToNonRawCapacities() {
        let info: [String: Any] = ["CurrentCapacity": 3_000, "MaxCapacity": 6_000]
        let detail = BatteryInfoProvider.parseDetail(info)
        XCTAssertEqual(detail.percentage, 50)
    }

    func testParseDetailConvertsTemperatureFromCentiDegrees() {
        let detail = BatteryInfoProvider.parseDetail(["Temperature": 3055])
        XCTAssertEqual(detail.temperature, 30.55, accuracy: 0.0001)
    }

    func testParseDetailTreats65535MinutesAsUnknown() {
        let detail = BatteryInfoProvider.parseDetail([
            "AvgTimeToEmpty": 65535,
            "AvgTimeToFull": 45,
        ])
        XCTAssertNil(detail.timeToEmpty)
        XCTAssertEqual(detail.timeToFull, 45)
    }

    func testParseDetailTreatsZeroMinutesAsUnknown() {
        let detail = BatteryInfoProvider.parseDetail(["AvgTimeToEmpty": 0])
        XCTAssertNil(detail.timeToEmpty)
    }

    // MARK: - Health

    func testHealthPrefersValueProvidedByMacOS() {
        let detail = BatteryInfoProvider.parseDetail([
            "BatteryHealthMaximumCapacityPercent": 91,
            "AppleRawMaxCapacity": 4_000,
            "DesignCapacity": 5_000,
        ])
        XCTAssertEqual(detail.healthPercentage, 91)
    }

    func testHealthFallsBackToMaxOverDesignCapacity() {
        let detail = BatteryInfoProvider.parseDetail([
            "AppleRawMaxCapacity": 4_500,
            "DesignCapacity": 5_000,
        ])
        XCTAssertEqual(detail.healthPercentage, 90)
    }

    func testPercentagesAreCappedAt100() {
        let detail = BatteryInfoProvider.parseDetail([
            "AppleRawCurrentCapacity": 5_100,
            "AppleRawMaxCapacity": 5_000,
            "DesignCapacity": 4_800,
        ])
        XCTAssertEqual(detail.percentage, 100)
        XCTAssertEqual(detail.healthPercentage, 100)
    }
}
