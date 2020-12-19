import XCTest
import Combine
@testable import CombineCB
@testable import CoreBluetoothMock

final class CCBCentralManagerTests: XCTestCase {
    var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        cancellables = []
    }

    override func tearDown() {
        cancellables.removeAll()
    }

    func testStateChange() {
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)

        var expectedState: CBManagerState = .unknown
        let exOn = expectation(description: "Expected poweredOn state")
        let exOff = expectation(description: "Expected poweredOff state")
        let exUnknown = expectation(description: "Expected unknown state")

        sut.subscribeToStateChanges()
            .sink(receiveValue: { state in
                XCTAssert(state == expectedState, "Manager state is incorrect")
                switch state {
                case .poweredOn: exOn.fulfill()
                case .poweredOff: exOff.fulfill()
                case .unknown: exUnknown.fulfill()
                default: XCTFail("unexpected state")
                }
            }).store(in: &cancellables)

        wait(for: [exUnknown], timeout: 1.0)

        expectedState = .poweredOn
        CBMCentralManagerMock.simulatePowerOn()
        wait(for: [exOn], timeout: 1.0)

        expectedState = .poweredOff
        CBMCentralManagerMock.simulatePowerOff()
        wait(for: [exOff], timeout: 1.0)
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

        waitForExpectations(timeout: 1.0, handler: nil)
    }

    static var allTests = [
        ("testDiscovery", testDiscovery),
        ("testStateChange", testStateChange),
    ]
}
