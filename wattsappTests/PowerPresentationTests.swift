import XCTest
@testable import WattsApp

@MainActor
final class PowerPresentationTests: XCTestCase {

    private var charging: PowerStatus { PowerStatus(watts: 20, isCharging: true, onAC: true) }
    private var acIdle: PowerStatus { PowerStatus(watts: 0, isCharging: false, onAC: true) }
    private var onBattery: PowerStatus { PowerStatus(watts: -10, isCharging: false, onAC: false) }

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
        XCTAssertEqual(PowerPresentation.menuBarIcon(status: charging, batteryPercentage: 50), "bolt.fill")
        XCTAssertEqual(PowerPresentation.menuBarIcon(status: acIdle, batteryPercentage: 100), "powerplug.fill")
        XCTAssertEqual(PowerPresentation.menuBarIcon(status: onBattery, batteryPercentage: 80), "battery.100")
        XCTAssertEqual(PowerPresentation.menuBarIcon(status: onBattery, batteryPercentage: 5), "battery.0")
    }

    func testMenuBarIconOnBatteryWithoutDetailFallsBackToHalf() {
        XCTAssertEqual(PowerPresentation.menuBarIcon(status: onBattery, batteryPercentage: nil), "battery.50")
    }

    // MARK: - Update Interval

    func testFixedModesIgnorePowerState() {
        for status in [nil, charging, acIdle, onBattery] {
            XCTAssertEqual(PowerPresentation.updateInterval(mode: .fast, status: status), 1.5)
            XCTAssertEqual(PowerPresentation.updateInterval(mode: .slow, status: status), 5.0)
        }
    }

    func testAutomaticModeFollowsPowerState() {
        XCTAssertEqual(PowerPresentation.updateInterval(mode: .automatic, status: charging), 2.0)
        XCTAssertEqual(PowerPresentation.updateInterval(mode: .automatic, status: onBattery), 3.0)
        XCTAssertEqual(PowerPresentation.updateInterval(mode: .automatic, status: acIdle), 5.0)
        XCTAssertEqual(PowerPresentation.updateInterval(mode: .automatic, status: nil), 5.0)
    }

    // MARK: - Status Detail Text

    func testStatusDetailTextWhileCharging() {
        let text = PowerPresentation.statusDetailText(status: charging, adapterWattage: 96, wattageText: "20.0W")
        XCTAssertEqual(text, "状態: 充電中 / アダプタ: 96W / 実効: 20.0W")
    }

    func testStatusDetailTextOnBatteryOmitsAdapter() {
        let text = PowerPresentation.statusDetailText(status: onBattery, adapterWattage: 0, wattageText: "10.0W")
        XCTAssertEqual(text, "状態: バッテリー駆動 / 実効: 10.0W")
    }

    func testStatusDetailTextWhenUnavailable() {
        let text = PowerPresentation.statusDetailText(status: nil, adapterWattage: 0, wattageText: "---W")
        XCTAssertEqual(text, "状態: 取得不可 / 実効: ---W")
    }
}
