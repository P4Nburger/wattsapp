import XCTest
@testable import WattsApp

@MainActor
final class PowerPresentationTests: XCTestCase {

    // MARK: - Fixtures

    /// 実機（20W アダプタで充電中）の値
    private var chargingWithTelemetry: PowerStatus {
        PowerStatus(batteryWatts: 13.659, isCharging: true, onAC: true,
                    systemLoadWatts: 5.160, adapterInputWatts: 18.819)
    }

    /// 実機（バッテリー駆動中）の値
    private var onBatteryWithTelemetry: PowerStatus {
        PowerStatus(batteryWatts: -4.396, isCharging: false, onAC: false,
                    systemLoadWatts: 4.396)
    }

    /// テレメトリなし（Intel Mac など）
    private var onBatteryLegacy: PowerStatus {
        PowerStatus(batteryWatts: -12.04, isCharging: false, onAC: false)
    }

    private var acIdleLegacy: PowerStatus {
        PowerStatus(batteryWatts: 0, isCharging: false, onAC: true)
    }

    // MARK: - Battery Icon

    func testBatteryIconThresholds() {
        let expectations: [(Int, String)] = [
            (100, "battery.100"), (76, "battery.100"),
            (75, "battery.75"), (51, "battery.75"),
            (50, "battery.50"), (26, "battery.50"),
            (25, "battery.25"), (11, "battery.25"),
            (10, "battery.0"), (1, "battery.0"), (0, "battery.0"),
        ]
        for (percentage, symbol) in expectations {
            XCTAssertEqual(PowerPresentation.batteryIcon(percentage: percentage), symbol, "\(percentage)%")
        }
    }

    // MARK: - Menu Bar Icon

    func testMenuBarIconForEachPowerState() {
        XCTAssertEqual(PowerPresentation.menuBarIcon(status: nil, batteryPercentage: 50), "questionmark.circle")
        XCTAssertEqual(PowerPresentation.menuBarIcon(status: chargingWithTelemetry, batteryPercentage: 50), "bolt.fill")
        XCTAssertEqual(PowerPresentation.menuBarIcon(status: acIdleLegacy, batteryPercentage: 100), "powerplug.fill")
        XCTAssertEqual(PowerPresentation.menuBarIcon(status: onBatteryLegacy, batteryPercentage: 80), "battery.100")
        XCTAssertEqual(PowerPresentation.menuBarIcon(status: onBatteryLegacy, batteryPercentage: 5), "battery.0")
    }

    func testMenuBarIconOnBatteryWithoutDetailFallsBackToHalf() {
        XCTAssertEqual(PowerPresentation.menuBarIcon(status: onBatteryLegacy, batteryPercentage: nil), "battery.50")
    }

    // MARK: - Update Interval

    func testFixedModesIgnorePowerState() {
        for status in [nil, chargingWithTelemetry, acIdleLegacy, onBatteryLegacy] {
            XCTAssertEqual(PowerPresentation.updateInterval(mode: .fast, status: status), 1.5)
            XCTAssertEqual(PowerPresentation.updateInterval(mode: .slow, status: status), 5.0)
        }
    }

    func testAutomaticModeFollowsPowerState() {
        XCTAssertEqual(PowerPresentation.updateInterval(mode: .automatic, status: chargingWithTelemetry), 2.0)
        XCTAssertEqual(PowerPresentation.updateInterval(mode: .automatic, status: onBatteryLegacy), 3.0)
        XCTAssertEqual(PowerPresentation.updateInterval(mode: .automatic, status: acIdleLegacy), 5.0)
        XCTAssertEqual(PowerPresentation.updateInterval(mode: .automatic, status: nil), 5.0)
    }

    // MARK: - Menu Bar Text

    /// 充電中でも、メニューバーには充電電力 (13.7W) ではなく本体の消費電力 (5.2W) を出す。
    func testMenuBarShowsSystemLoadWhileCharging() {
        XCTAssertEqual(PowerPresentation.menuBarText(status: chargingWithTelemetry), "5.2W")
    }

    func testMenuBarShowsSystemLoadOnBattery() {
        XCTAssertEqual(PowerPresentation.menuBarText(status: onBatteryWithTelemetry), "4.4W")
    }

    func testMenuBarFallsBackToDischargeWithoutTelemetry() {
        XCTAssertEqual(PowerPresentation.menuBarText(status: onBatteryLegacy), "12.0W")
    }

    /// テレメトリがなく AC 接続中は測れないので、アダプタ定格を実測値のように出さない。
    func testMenuBarShowsPlaceholderWhenConsumptionIsUnknown() {
        XCTAssertEqual(PowerPresentation.menuBarText(status: acIdleLegacy), "---W")
        XCTAssertEqual(PowerPresentation.menuBarText(status: nil), "---W")
    }

    // MARK: - Status Lines
    // 文言は表示言語で変わるので、ここでは「どの行を出すか」だけを検証する。

    func testStatusLinesWhileCharging() {
        XCTAssertEqual(
            PowerPresentation.statusLines(status: chargingWithTelemetry, adapterWattage: 20),
            [
                .state(.charging, adapterWatts: 20),
                .consumption(watts: 5.160),
                .adapterInput(watts: 18.819),
                .batteryCharging(watts: 13.659),
            ]
        )
    }

    func testStatusLinesOnBatteryDoNotRepeatDischarge() {
        XCTAssertEqual(
            PowerPresentation.statusLines(status: onBatteryWithTelemetry, adapterWattage: 0),
            [.state(.onBattery, adapterWatts: nil), .consumption(watts: 4.396)]
        )
    }

    func testStatusLinesWhenBatteryAssistsAdapter() {
        let status = PowerStatus(batteryWatts: -3.0, isCharging: false, onAC: true,
                                 systemLoadWatts: 25.0, adapterInputWatts: 22.0)
        XCTAssertEqual(
            PowerPresentation.statusLines(status: status, adapterWattage: 20),
            [
                .state(.pluggedIn, adapterWatts: 20),
                .consumption(watts: 25.0),
                .adapterInput(watts: 22.0),
                .batteryAssist(watts: 3.0),
            ]
        )
    }

    func testStatusLinesOnACWithoutTelemetry() {
        XCTAssertEqual(
            PowerPresentation.statusLines(status: acIdleLegacy, adapterWattage: 96),
            [.state(.pluggedIn, adapterWatts: 96), .consumption(watts: nil)]
        )
    }

    func testStatusLinesWhenUnavailable() {
        XCTAssertEqual(
            PowerPresentation.statusLines(status: nil, adapterWattage: 0),
            [.state(.unavailable, adapterWatts: nil)]
        )
    }

    /// 数値部分は言語によらず同じ表記になる（"5.2W" / "---W"）。
    func testLocalizedTextContainsFormattedWatts() {
        XCTAssertTrue(StatusLine.consumption(watts: 5.16).localizedText.contains("5.2W"))
        XCTAssertTrue(StatusLine.consumption(watts: nil).localizedText.contains("---W"))
        XCTAssertTrue(StatusLine.state(.charging, adapterWatts: 20).localizedText.contains("20W"))
    }
}
