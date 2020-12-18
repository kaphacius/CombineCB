import XCTest
import Combine
@testable import CombineCB
@testable import CoreBluetoothMock

final class CombineCBTests: XCTestCase {
    var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        cancellables = []
    }

    override func tearDown() {
        cancellables.removeAll()
    }

    func testDiscovery() {
        CBMCentralManagerMock.simulateInitialState(.poweredOff)
        let id = UUID()
        let p: CBMPeripheralSpec = CBMPeripheralSpec
            .simulatePeripheral(identifier: id, proximity: .near)
            .advertising(advertisementData: [CBAdvertisementDataIsConnectable: true])
            .build()
        CBMCentralManagerMock.simulatePeripherals([p])
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)
        CBMCentralManagerMock.simulatePowerOn()

        let discovered = expectation(description: "discovered one peripheral")

        sut.subscribeToStateChanges()
            .filter({ $0 == .poweredOn })
            .flatMap({ _ in
                sut.scanForPeripherals(withServices: nil, options: nil)
            }).sink(receiveValue: { p in
                XCTAssert(p.peripheral.identifier == id, "Discovered peripheral id is incorrect")
                XCTAssert(p.rssi.doubleValue < -25.0, "Discovered peripheral proximity is incorrect")

                discovered.fulfill()
            }).store(in: &cancellables)

        waitForExpectations(timeout: 20.0, handler: nil)
    }

    static var allTests = [
        ("testDiscovery", testDiscovery),
    ]
}
