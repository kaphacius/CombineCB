import XCTest
import Combine
@testable import CombineCB
@testable import CoreBluetoothMock

final class CCBCentralManagerTests: CCBTestCase {
    func testStateChange() {
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)

        var expectedState: CBManagerState = .unknown
        let exOn = expectation(description: "Expected poweredOn state")
        let exOff = expectation(description: "Expected poweredOff state")
        let exUnknown = expectation(description: "Expected unknown state")

        sut.subscribeToStateChanges()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { state in
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
        wait(for: [exOff], timeout: 3.0)
    }

    func testDiscovery() {
        let id = UUID()
        let p: CBMPeripheralSpec = CCBCentralManagerTests.mockPeripheral(withId: id)
        CBMCentralManagerMock.simulatePeripherals([p])
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)
        CBMCentralManagerMock.simulatePowerOn()

        let discovered = expectation(description: "discovered one peripheral")

        sut.subscribeToStateChanges()
            .filter({ $0 == .poweredOn })
            .flatMap({ _ in
                sut.scanForPeripherals(withServices: nil, options: nil)
            }).sink(
                receiveCompletion: { _ in },
                receiveValue: { p in
                    XCTAssert(p.peripheral.p.identifier == id, "Discovered peripheral id is incorrect")
                XCTAssert(p.rssi.doubleValue < -25.0, "Discovered peripheral proximity is incorrect")

                discovered.fulfill()
            }).store(in: &cancellables)

        waitForExpectations(timeout: 10.0)
    }

    func testPeripheralConnection() {
        let pD = MockPeripheralDelegate()
        let p = CCBCentralManagerTests.mockPeripheral(delegate: pD)
        CBMCentralManagerMock.simulatePeripherals([p])
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)
        let ex = expectation(description: "Connected to peripheral")
        CBMCentralManagerMock.simulatePowerOn()
        sut.subscribeToStateChanges()
            .filter({ $0 == .poweredOn })
            .flatMap({ _ -> CCBPublisher<PeripheralDiscovered> in
                sut.scanForPeripherals(withServices: nil, options: nil)
            }).flatMap({ (p: PeripheralDiscovered) -> CCBPeripheralPublisher in
                sut.connect(p.peripheral, options: nil)
            }).sink(
                receiveCompletion: { _  in },
                receiveValue: { peripheral in
                    XCTAssert(
                        peripheral.p.identifier == p.identifier,
                        "Conected peripheral id is incorrect"
                    )
                    ex.fulfill()
                }).store(in: &cancellables)

        waitForExpectations(timeout: 10.0)
    }

    func testMultiplePeripheralsConnection() {
        let pD = MockPeripheralDelegate()
        CBMCentralManagerMock.simulatePeripherals([
            CCBCentralManagerTests.mockPeripheral(delegate: pD),
            CCBCentralManagerTests.mockPeripheral(delegate: pD)
        ])
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)
        let ex = expectation(description: "Connected to peripherals")
        ex.expectedFulfillmentCount = 2
        var scannedPeripherals: Array<CCBPeripheral> = []
        CBMCentralManagerMock.simulatePowerOn()
        sut.subscribeToStateChanges()
            .filter({ $0 == .poweredOn })
            .flatMap({ _ -> CCBPublisher<PeripheralDiscovered> in
                sut.scanForPeripherals(withServices: nil, options: nil)
            }).sink(
                receiveCompletion: { _  in },
                receiveValue: { (peripheral: PeripheralDiscovered) in
                    scannedPeripherals.append(peripheral.peripheral)
                }).store(in: &cancellables)

        let predicate = NSPredicate { _,_ in scannedPeripherals.count == 2 }
        wait(for: [expectation(for: predicate, evaluatedWith: nil)], timeout: 10.0)

        let disconnectExpectation = expectation(description: "Disconnected from peripherals")
        disconnectExpectation.expectedFulfillmentCount = 2

        _ = scannedPeripherals
            .map({ (sp: CCBPeripheral) -> Void in
                sut.connect(sp)
                    .sink(receiveCompletion: { _ in
                        disconnectExpectation.fulfill()
                    }, receiveValue: { p in
                        ex.fulfill()
                    }).store(in: &cancellables)
            })

        wait(for: [ex], timeout: 10.0)

        _ = scannedPeripherals.map { (p: CCBPeripheral) in
            sut.cancelPeripheralConnection(p.p)
        }

        wait(for: [disconnectExpectation], timeout: 10.0)
    }

    func testPeripheralConnectionFail() {
        let pD = MockPeripheralDelegate(shouldConnect: false)
        let p = CCBCentralManagerTests.mockPeripheral(delegate: pD)
        CBMCentralManagerMock.simulatePeripherals([p])
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)
        let ex = expectation(description: "Connected to peripheral")
        CBMCentralManagerMock.simulatePowerOn()
        sut.subscribeToStateChanges()
            .filter({ $0 == .poweredOn })
            .flatMap({ _ -> CCBPublisher<PeripheralDiscovered> in
                sut.scanForPeripherals(withServices: nil, options: nil)
            }).flatMap({ (p: PeripheralDiscovered) -> CCBPeripheralPublisher in
                sut.connect(p.peripheral, options: nil)
            }).sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let ccbError):
                        if case .peripheralConnectionError(let error) = ccbError,
                           let nsError = error as NSError? {
                            XCTAssert(nsError.domain == "CCBTests")
                            XCTAssert(nsError.code == 555)
                            ex.fulfill()
                        }
                    default: break
                    }
                },
                receiveValue: { _ in }
            ).store(in: &cancellables)

        waitForExpectations(timeout: 10.0)
    }

    func testPeripheralDisconnect() {
        // TODO: Fix when I know how

        return

        let pD = MockPeripheralDelegate()
        let p = CCBCentralManagerTests.mockPeripheral(delegate: pD)
        CBMCentralManagerMock.simulatePeripherals([p])
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)
        let ex = expectation(description: "Disconnected from peripheral")
        var connected: Bool = false
        CBMCentralManagerMock.simulatePowerOn()
        sut.subscribeToStateChanges()
            .filter({ $0 == .poweredOn })
            .flatMap({ _ -> CCBPublisher<PeripheralDiscovered> in
                sut.scanForPeripherals(withServices: nil, options: nil)
            }).flatMap({ (p: PeripheralDiscovered) -> CCBPeripheralPublisher in
                connected = true
                return sut.connect(p.peripheral, options: nil)
            }).sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        ex.fulfill()
                    default:
                        break
                    }
                },
                receiveValue: { _ in }
            ).store(in: &cancellables)

        let predicate = NSPredicate { _, _ in connected }
        wait(
            for: [expectation(for: predicate, evaluatedWith: nil, handler: nil)],
            timeout: 10.0
        )

        CBMCentralManagerMock.peripheral(p, didDisconnectWithError: nil)

        waitForExpectations(timeout: 20.0)
    }

    func testPeripheralDisconnectWithError() {
        let pD = MockPeripheralDelegate()
        let p = CCBCentralManagerTests.mockPeripheral(delegate: pD)
        CBMCentralManagerMock.simulatePeripherals([p])
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)
        let ex = expectation(description: "Disconnected from peripheral")
        var connected: Bool = false
        CBMCentralManagerMock.simulatePowerOn()
        sut.subscribeToStateChanges()
            .filter({ $0 == .poweredOn })
            .flatMap({ _ -> CCBPublisher<PeripheralDiscovered> in
                sut.scanForPeripherals(withServices: nil, options: nil)
            }).flatMap({ (p: PeripheralDiscovered) -> CCBPeripheralPublisher in
                connected = true
                return sut.connect(p.peripheral, options: nil)
            }).sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let ccbError):
                        if case .peripheralDisconnectError(let error) = ccbError,
                           let nsError = error as NSError? {
                            XCTAssert(nsError.domain == "CCBTests")
                            XCTAssert(nsError.code == 555)
                            ex.fulfill()
                        }
                    default: break
                    }
                },
                receiveValue: { _ in }
            ).store(in: &cancellables)

        let predicate = NSPredicate { _, _ in connected }
        wait(
            for: [expectation(for: predicate, evaluatedWith: nil, handler: nil)],
            timeout: 10.0
        )

        CBMCentralManagerMock.peripheral(p, didDisconnectWithError: CCBTestCase.error)

        waitForExpectations(timeout: 20.0)
    }

    static var allTests = [
        ("testDiscovery", testDiscovery),
        ("testStateChange", testStateChange),
    ]
}
