import XCTest
@testable import WattsApp

/// AppleSmartBattery の辞書をどう解釈するかのテスト。
/// 実機の `ioreg -rn AppleSmartBattery` の値を模した辞書を使う。
@MainActor
final class BatteryInfoParsingTests: XCTestCase {

    // MARK: - Status

    func testParseStatusComputesWattsFromMilliampsAndMillivolts() {
        let info: [String: Any] = [
            "Amperage": -1500,       // mA（放電中は負）
            "Voltage": 12_000,       // mV
            "IsCharging": false,
            "ExternalConnected": false,
        ]
        let status = BatteryInfoProvider.parseStatus(info)
        XCTAssertEqual(status.watts, -18.0, accuracy: 0.0001)
        XCTAssertFalse(status.isCharging)
        XCTAssertFalse(status.onAC)
    }

    func testParseStatusDefaultsWhenKeysAreMissing() {
        let status = BatteryInfoProvider.parseStatus([:])
        XCTAssertEqual(status.watts, 0)
        XCTAssertFalse(status.isCharging)
        XCTAssertFalse(status.onAC)
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
