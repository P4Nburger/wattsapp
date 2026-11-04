import XCTest
@testable import WattsApp

@MainActor
final class StatusTextFormatterTests: XCTestCase {

    private var formatter: StatusTextFormatter { StatusTextFormatter() }

    // MARK: - 状態が取れないとき

    func testNoStatusWithoutAdapterShowsPlaceholder() {
        XCTAssertEqual(formatter.text(for: nil, adapterWattage: 0), "---W")
    }

    func testNoStatusWithAdapterShowsAdapterRating() {
        XCTAssertEqual(formatter.text(for: nil, adapterWattage: 96), "96W")
    }

    // MARK: - AC 接続

    func testChargingShowsBatteryInputPower() {
        let status = PowerStatus(watts: 25.34, isCharging: true, onAC: true)
        XCTAssertEqual(formatter.text(for: status, adapterWattage: 96), "25.3W")
    }

    /// 現状の仕様: 満充電などで電流がほぼ 0 のときはアダプタ定格を出す。
    /// （実消費電力ではないので、表示値の見直し時にこのテストも更新する）
    func testOnACBelowNoiseFloorFallsBackToAdapterRating() {
        let status = PowerStatus(watts: 0.05, isCharging: false, onAC: true)
        XCTAssertEqual(formatter.text(for: status, adapterWattage: 96), "96W")
    }

    func testOnACBelowNoiseFloorWithoutAdapterShowsZero() {
        let status = PowerStatus(watts: 0.0, isCharging: false, onAC: true)
        XCTAssertEqual(formatter.text(for: status, adapterWattage: 0), "0W")
    }

    // MARK: - バッテリー駆動

    func testOnBatteryShowsDischargeAsPositive() {
        let status = PowerStatus(watts: -12.04, isCharging: false, onAC: false)
        XCTAssertEqual(formatter.text(for: status, adapterWattage: 0), "12.0W")
    }

    func testOnBatteryClampsUnexpectedPositiveToZero() {
        let status = PowerStatus(watts: 3.0, isCharging: false, onAC: false)
        XCTAssertEqual(formatter.text(for: status, adapterWattage: 0), "0.0W")
    }
}
