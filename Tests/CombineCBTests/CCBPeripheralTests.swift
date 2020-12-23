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
        let pD = MockPeripheralDelegate()
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
            .flatMap({ (p: CCBPeripheral) -> CCBDiscoverCharacteristicsPublisher in
                p.discoverCharacteristics(nil, for: p.services.first!)
            }).sink(
                receiveCompletion: { _ in },
                receiveValue: { (peripheral, service) in
                    XCTAssert(service.identifier == mockService.identifier, "Service id does not match")
                    XCTAssert(service.characteristics?.count == 3, "Discovered wrong number of characteristics")
                    XCTAssert(service.characteristics!.allSatisfy({ $0.properties == [.read, .write] }), "Discovered wrong characteristics properties")
                    XCTAssert(Set(service.characteristics!.map(\.identifier)) == Set(mockService.characteristics!.map(\.identifier)), "Discovered  characteristics have wrong identifiers")
                    ex.fulfill()
                }
            ).store(in: &cancellables)

        waitForExpectations(timeout: 60.0)
    }

    func testDiscoverCharacteristicsFail() {
        let pD = MockPeripheralDelegate(shouldDiscoverCharacteristics: false)
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
            .flatMap({ (p: CCBPeripheral) -> CCBDiscoverCharacteristicsPublisher in
                p.discoverCharacteristics(nil, for: p.services.first!)
            }).sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let ccbError):
                        if case .characteristicsDiscoveryError(let error) = ccbError,
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

    func testDiscoverDescriptors() {
        let pD = MockPeripheralDelegate()
        let mockDescriptors = [UUID(), UUID(), UUID()]
            .map(CBUUID.init)
            .map(CCBTestCase.mockDescriptor)
        let mockService = CCBTestCase.mockService(
            with: CBUUID(nsuuid: UUID()),
            characteristics: [
                CCBTestCase.mockCharacteristic(descriptors: mockDescriptors)
            ]
        )
        let mp = CCBCentralManagerTests.mockPeripheral(
            delegate: pD,
            services: [mockService]
        )
        CBMCentralManagerMock.simulatePeripherals([mp])
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)
        let ex = expectation(description: "Discovered 3 descriptors")
        CBMCentralManagerMock.simulatePowerOn()

        sut.subscribeToStateChanges()
            .filter({ $0 == .poweredOn })
            .flatMap({ _ -> CCBPublisher<PeripheralDiscovered> in
                sut.scanForPeripherals(withServices: nil, options: nil)
            }).flatMap({ (p: PeripheralDiscovered) -> CCBPeripheralPublisher in
                sut.connect(p.peripheral)
            }).flatMap({ (p: CCBPeripheral) -> CCBPeripheralPublisher in
                p.discoverServices()
            }).flatMap({ (p: CCBPeripheral) -> CCBDiscoverCharacteristicsPublisher in
                p.discoverCharacteristics(nil, for: p.services.first!)
            }).flatMap({ (peripheral, service) -> CCBDiscoverDescriptorsPublisher in
                peripheral.discoverDescriptors(for: service.characteristics!.first!)
            }).sink(
                receiveCompletion: { _ in },
                receiveValue: { (peripheral, characteristic) in
                    XCTAssert(characteristic.identifier == mockService.characteristics!.first!.identifier, "Service id does not match")
                    XCTAssert(characteristic.descriptors!.count == 3, "Discovered wrong number of descriptors")
                    XCTAssert(Set(characteristic.descriptors!.map(\.identifier)) == Set(mockService.characteristics!.first!.descriptors!.map(\.identifier)), "Discovered  descriptors have wrong identifiers")
                    ex.fulfill()
                }
            ).store(in: &cancellables)

        waitForExpectations(timeout: 60.0)
    }

    func testDiscoverDescriptorsFail() {
        let pD = MockPeripheralDelegate(shouldDiscoverDescriptors: false)
        let mockDescriptors = [UUID(), UUID(), UUID()]
            .map(CBUUID.init)
            .map(CCBTestCase.mockDescriptor)
        let mockService = CCBTestCase.mockService(
            with: CBUUID(nsuuid: UUID()),
            characteristics: [
                CCBTestCase.mockCharacteristic(descriptors: mockDescriptors)
            ]
        )
        let mp = CCBCentralManagerTests.mockPeripheral(
            delegate: pD,
            services: [mockService]
        )
        CBMCentralManagerMock.simulatePeripherals([mp])
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)
        let ex = expectation(description: "Discovered 3 descriptors")
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
            .flatMap({ (p: CCBPeripheral) -> CCBDiscoverCharacteristicsPublisher in
                p.discoverCharacteristics(nil, for: p.services.first!)
            }).flatMap({ (peripheral, service) -> CCBDiscoverDescriptorsPublisher in
                peripheral.discoverDescriptors(for: service.characteristics!.first!)
            }).sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let ccbError):
                        if case .descriptiorsDiscoveryError(let error) = ccbError,
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

    func testWriteCharacteristicValueMultipleChunks() {
        let pD = MockPeripheralDelegate()
        let mockDescriptors = [UUID(), UUID(), UUID()]
            .map(CBUUID.init)
            .map(CCBTestCase.mockDescriptor)
        let mockService = CCBTestCase.mockService(
            with: CBUUID(nsuuid: UUID()),
            characteristics: [
                CCBTestCase.mockCharacteristic(descriptors: mockDescriptors)
            ]
        )
        let mp = CCBCentralManagerTests.mockPeripheral(
            delegate: pD,
            services: [mockService]
        )
        CBMCentralManagerMock.simulatePeripherals([mp])
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)
        let ex = expectation(description: "Data writing finished")
        CBMCentralManagerMock.simulatePowerOn()

        sut.subscribeToStateChanges()
            .filter({ $0 == .poweredOn })
            .flatMap({ _ -> CCBPublisher<PeripheralDiscovered> in
                sut.scanForPeripherals(withServices: nil, options: nil)
            }).flatMap({ (p: PeripheralDiscovered) -> CCBPeripheralPublisher in
                sut.connect(p.peripheral)
            }).flatMap({ (p: CCBPeripheral) -> CCBPeripheralPublisher in
                p.discoverServices()
            }).flatMap({ (p: CCBPeripheral) -> CCBDiscoverCharacteristicsPublisher in
                p.discoverCharacteristics(nil, for: p.services.first!)
            }).flatMap({ (peripheral, service) -> CCBCharacteristicWriteValuePublisher in
                peripheral.writeValue(
                    CCBTestCase.mockData,
                    for: service.characteristics!.first!,
                    type: .withResponse
                )
            }).sink(
                receiveCompletion: { _ in },
                receiveValue: { (peripheral, characteristic) in
                    XCTAssert(pD.data == CCBTestCase.mockData, "Data written is incorrect")
                    ex.fulfill()
                }
            ).store(in: &cancellables)

        waitForExpectations(timeout: 60.0)
    }

    func testWriteCharacteristicValueFailNoData() {
        let pD = MockPeripheralDelegate()
        let mockDescriptors = [UUID(), UUID(), UUID()]
            .map(CBUUID.init)
            .map(CCBTestCase.mockDescriptor)
        let mockService = CCBTestCase.mockService(
            with: CBUUID(nsuuid: UUID()),
            characteristics: [
                CCBTestCase.mockCharacteristic(descriptors: mockDescriptors)
            ]
        )
        let mp = CCBCentralManagerTests.mockPeripheral(
            delegate: pD,
            services: [mockService]
        )
        CBMCentralManagerMock.simulatePeripherals([mp])
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)
        let ex = expectation(description: "Data writing failed due to no data")
        CBMCentralManagerMock.simulatePowerOn()

        sut.subscribeToStateChanges()
            .filter({ $0 == .poweredOn })
            .flatMap({ _ -> CCBPublisher<PeripheralDiscovered> in
                sut.scanForPeripherals(withServices: nil, options: nil)
            }).flatMap({ (p: PeripheralDiscovered) -> CCBPeripheralPublisher in
                sut.connect(p.peripheral)
            }).flatMap({ (p: CCBPeripheral) -> CCBPeripheralPublisher in
                p.discoverServices()
            }).flatMap({ (p: CCBPeripheral) -> CCBDiscoverCharacteristicsPublisher in
                p.discoverCharacteristics(nil, for: p.services.first!)
            }).flatMap({ (peripheral, service) -> CCBCharacteristicWriteValuePublisher in
                peripheral.writeValue(
                    Data(),
                    for: service.characteristics!.first!,
                    type: .withResponse
                )
            }).sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let ccbError):
                        if case .characteristicValueWriteDataMissing = ccbError {
                            ex.fulfill()
                        }
                    default: break
                    }
                },
                receiveValue: { (peripheral, characteristic) in }
            ).store(in: &cancellables)

        waitForExpectations(timeout: 60.0)
    }

    func testWriteCharacteristicValueFail() {
        let pD = MockPeripheralDelegate(shouldWriteData: false)
        let mockDescriptors = [UUID(), UUID(), UUID()]
            .map(CBUUID.init)
            .map(CCBTestCase.mockDescriptor)
        let mockService = CCBTestCase.mockService(
            with: CBUUID(nsuuid: UUID()),
            characteristics: [
                CCBTestCase.mockCharacteristic(descriptors: mockDescriptors)
            ]
        )
        let mp = CCBCentralManagerTests.mockPeripheral(
            delegate: pD,
            services: [mockService]
        )
        CBMCentralManagerMock.simulatePeripherals([mp])
        let mockManager = CBCentralManagerFactory.instance(forceMock: true)
        let sut = CCBCentralManager(manager: mockManager)
        let ex = expectation(description: "Data writing failed due to no data")
        CBMCentralManagerMock.simulatePowerOn()

        sut.subscribeToStateChanges()
            .filter({ $0 == .poweredOn })
            .flatMap({ _ -> CCBPublisher<PeripheralDiscovered> in
                sut.scanForPeripherals(withServices: nil, options: nil)
            }).flatMap({ (p: PeripheralDiscovered) -> CCBPeripheralPublisher in
                sut.connect(p.peripheral)
            }).flatMap({ (p: CCBPeripheral) -> CCBPeripheralPublisher in
                p.discoverServices()
            }).flatMap({ (p: CCBPeripheral) -> CCBDiscoverCharacteristicsPublisher in
                p.discoverCharacteristics(nil, for: p.services.first!)
            }).flatMap({ (peripheral, service) -> CCBCharacteristicWriteValuePublisher in
                peripheral.writeValue(
                    CCBTestCase.mockData,
                    for: service.characteristics!.first!,
                    type: .withResponse
                )
            }).sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let ccbError):
                        if case .characteristicValueWriteError(let error) = ccbError,
                           let nsError = error as NSError? {
                            XCTAssert(nsError.domain == "CCBTests")
                            XCTAssert(nsError.code == 555)
                            ex.fulfill()
                        }
                    default:
                        break
                    }
                },
                receiveValue: { (peripheral, characteristic) in }
            ).store(in: &cancellables)

        waitForExpectations(timeout: 60.0)
    }

    static var allTests = [
        ("testAllServiceDiscovery", testAllServiceDiscovery),
        ("testCertainServiceDiscovery", testCertainServiceDiscovery),
        ("testServiceDiscoveryFail", testServiceDiscoveryFail)
    ]
}
