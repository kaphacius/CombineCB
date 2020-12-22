import XCTest
import Combine
@testable import CombineCB
@testable import CoreBluetoothMock

final class CCBPeripheralTests: CCBTestCase {
    func testAllServiceDiscovery() {
        let pD = MockPeripheralDelegate()
        let uuids: Array<CBUUID> = [UUID(), UUID(), UUID()].map(CBUUID.init)
        let mp = CCBCentralManagerTests.mockPeripheral(
            delegate: pD,
            services: CCBTestCase.mockServices(with: uuids)
        )
        CBMCentralManagerMock.simulatePeripherals([mp])
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)
        let ex = expectation(description: "Discovered 3 services")
        CBMCentralManagerMock.simulatePowerOn()

        sut.subscribeToStateChanges()
            .filter({ $0 == .poweredOn })
            .flatMap({ _ -> CCBPublisher<PeripheralDiscovered> in
                sut.scanForPeripherals(withServices: nil, options: nil)
            }).flatMap({ (p: PeripheralDiscovered) -> CCBPeripheralPublisher in
                sut.connect(p.peripheral)
            })
            .flatMap({ (p: CCBPeripheral) -> CCBPeripheralPublisher in
                p.discoverServices()
            }).sink(
                receiveCompletion: { _ in },
                receiveValue: { p in
                    guard let ss = p.p.services else {
                        XCTFail("No services discovered")
                        return
                    }

                    XCTAssert(Set(ss.map(\.uuid)) == Set(uuids), "Discovered unexpected services")

                    ex.fulfill()
                }
            ).store(in: &cancellables)

        waitForExpectations(timeout: 60.0)
    }

    func testCertainServiceDiscovery() {
        let pD = MockPeripheralDelegate()
        let uuids: Array<CBUUID> = [UUID(), UUID(), UUID()].map(CBUUID.init)
        let mp = CCBCentralManagerTests.mockPeripheral(
            delegate: pD,
            services: CCBTestCase.mockServices(with: uuids)
        )
        CBMCentralManagerMock.simulatePeripherals([mp])
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)
        let ex = expectation(description: "Discovered 3 services")
        CBMCentralManagerMock.simulatePowerOn()

        sut.subscribeToStateChanges()
            .filter({ $0 == .poweredOn })
            .flatMap({ _ -> CCBPublisher<PeripheralDiscovered> in
                sut.scanForPeripherals(withServices: nil, options: nil)
            }).flatMap({ (p: PeripheralDiscovered) -> CCBPeripheralPublisher in
                sut.connect(p.peripheral)
            })
            .flatMap({ (p: CCBPeripheral) -> CCBPeripheralPublisher in
                p.discoverServices([uuids.last!])
            }).sink(
                receiveCompletion: { _ in },
                receiveValue: { (p: CCBPeripheral) in
                    guard let s = p.p.services.flatMap(\.first) else {
                        XCTFail("No services discovered")
                        return
                    }

                    XCTAssert(s.uuid == uuids.last!, "Discovered unexpected service")

                    ex.fulfill()
                }
            ).store(in: &cancellables)

        waitForExpectations(timeout: 60.0)
    }

    func testServiceDiscoveryFail() {
        let pD = MockPeripheralDelegate(shouldDiscoverServices: false)
        let uuids: Array<CBUUID> = [UUID(), UUID(), UUID()].map(CBUUID.init)
        let mp = CCBCentralManagerTests.mockPeripheral(
            delegate: pD,
            services: CCBTestCase.mockServices(with: uuids)
        )
        CBMCentralManagerMock.simulatePeripherals([mp])
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)
        let ex = expectation(description: "Discovered 3 services")
        CBMCentralManagerMock.simulatePowerOn()

        sut.subscribeToStateChanges()
            .filter({ $0 == .poweredOn })
            .flatMap({ _ -> CCBPublisher<PeripheralDiscovered> in
                sut.scanForPeripherals(withServices: nil, options: nil)
            }).flatMap({ (p: PeripheralDiscovered) -> CCBPeripheralPublisher in
                sut.connect(p.peripheral)
            })
            .flatMap({ (p: CCBPeripheral) -> CCBPeripheralPublisher in
                p.discoverServices()
            }).sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let ccbError):
                        if case .serviceDiscoveryError(let error) = ccbError,
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

        waitForExpectations(timeout: 60.0)
    }

    func testIncludedServiceDiscovery() {
        let pD = MockPeripheralDelegate()
        let uuids: Array<CBUUID> = [UUID(), UUID(), UUID()].map(CBUUID.init)
        let mockService = CCBTestCase.mockService(
            with: CBUUID(nsuuid: UUID()),
            includedServices: CCBTestCase.mockServices(with: uuids)
        )
        let mp = CCBCentralManagerTests.mockPeripheral(
            delegate: pD,
            services: [mockService]
        )
        CBMCentralManagerMock.simulatePeripherals([mp])
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)
        let ex = expectation(description: "Discovered 3 services")
        CBMCentralManagerMock.simulatePowerOn()

        sut.subscribeToStateChanges()
            .filter({ $0 == .poweredOn })
            .flatMap({ _ -> CCBPublisher<PeripheralDiscovered> in
                sut.scanForPeripherals(withServices: nil, options: nil)
            }).flatMap({ (p: PeripheralDiscovered) -> CCBPeripheralPublisher in
                sut.connect(p.peripheral)
            })
            .flatMap({ (p: CCBPeripheral) -> CCBPeripheralPublisher in
                p.discoverServices()
            })
            .flatMap({ (p: CCBPeripheral) -> CCBPublisher<IncludedServiceDiscovered> in
                p.discoverIncludedServices(
                    [uuids.last!],
                    for: p.p.services!.first!
                )
            }).sink(
                receiveCompletion: { _ in },
                receiveValue: { (response: IncludedServiceDiscovered) in
                    guard let included = response.service.includedServices else {
                        XCTFail("No included services discovered")
                        return
                    }

                    XCTAssert(included.count == 1, "Number of discovered included services is incorrect")
                    XCTAssert(included.first!.uuid == uuids.last!)

                    ex.fulfill()
                }
            ).store(in: &cancellables)

        waitForExpectations(timeout: 60.0)
    }

    func testIncludedServiceDiscoveryFail() {
        let pD = MockPeripheralDelegate(shouldDiscoverIncludedServices: false)
        let uuids: Array<CBUUID> = [UUID(), UUID(), UUID()].map(CBUUID.init)
        let mockService = CCBTestCase.mockService(
            with: CBUUID(nsuuid: UUID()),
            includedServices: CCBTestCase.mockServices(with: uuids)
        )
        let mp = CCBCentralManagerTests.mockPeripheral(
            delegate: pD,
            services: [mockService]
        )
        CBMCentralManagerMock.simulatePeripherals([mp])
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)
        let ex = expectation(description: "Discovered 3 services")
        CBMCentralManagerMock.simulatePowerOn()

        sut.subscribeToStateChanges()
            .filter({ $0 == .poweredOn })
            .flatMap({ _ -> CCBPublisher<PeripheralDiscovered> in
                sut.scanForPeripherals(withServices: nil, options: nil)
            }).flatMap({ (p: PeripheralDiscovered) -> CCBPeripheralPublisher in
                sut.connect(p.peripheral)
            })
            .flatMap({ (p: CCBPeripheral) -> CCBPeripheralPublisher in
                p.discoverServices()
            })
            .flatMap({ (p: CCBPeripheral) -> CCBPublisher<IncludedServiceDiscovered> in
                p.discoverIncludedServices(
                    [uuids.last!],
                    for: p.p.services!.first!
                )
            }).sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let ccbError):
                        if case .includedServiceDiscoveryError(let error) = ccbError,
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

        waitForExpectations(timeout: 60.0)
    }

    func testDiscoverCharacteristics() {
        let pD = MockPeripheralDelegate(shouldDiscoverIncludedServices: false)
        let uuids: Array<CBUUID> = [UUID(), UUID(), UUID()].map(CBUUID.init)
        let mockService = CCBTestCase.mockService(
            with: CBUUID(nsuuid: UUID()),
            characteristics: [
                CCBTestCase.mockCharacteristic(),
                CCBTestCase.mockCharacteristic(),
                CCBTestCase.mockCharacteristic()
            ]
        )
        let mp = CCBCentralManagerTests.mockPeripheral(
            delegate: pD,
            services: [mockService]
        )
        CBMCentralManagerMock.simulatePeripherals([mp])
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)
        let ex = expectation(description: "Discovered 3 services")
        CBMCentralManagerMock.simulatePowerOn()

        sut.subscribeToStateChanges()
            .filter({ $0 == .poweredOn })
            .flatMap({ _ -> CCBPublisher<PeripheralDiscovered> in
                sut.scanForPeripherals(withServices: nil, options: nil)
            }).flatMap({ (p: PeripheralDiscovered) -> CCBPeripheralPublisher in
                sut.connect(p.peripheral)
            })
            .flatMap({ (p: CCBPeripheral) -> CCBPeripheralPublisher in
                p.discoverServices()
            })
            .flatMap({ (p: CCBPeripheral) -> CCBServicePublisher in
                p.discoverCharacteristics(nil, for: p.services.first!)
            }).sink(
                receiveCompletion: { _ in },
                receiveValue: { service in
                    XCTAssert(service.identifier == mockService.identifier, "Service id does not match")
                    XCTAssert(service.characteristics?.count == 3, "Discovered wrong number of characteristics")
                    XCTAssert(service.characteristics!.allSatisfy({ $0.properties == [.read, .write] }), "Discovered wrong characteristics properties")
                    XCTAssert(Set(service.characteristics!.map(\.identifier)) == Set(mockService.characteristics!.map(\.identifier)), "Discovered  characteristics have wrong identifiers")
                    ex.fulfill()
                }
            ).store(in: &cancellables)

        waitForExpectations(timeout: 60.0)
    }

    static var allTests = [
        ("testAllServiceDiscovery", testAllServiceDiscovery),
        ("testCertainServiceDiscovery", testCertainServiceDiscovery),
        ("testServiceDiscoveryFail", testServiceDiscoveryFail)
    ]
}
