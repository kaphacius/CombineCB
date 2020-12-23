import XCTest
import Combine
@testable import CombineCB
@testable import CoreBluetoothMock

class CCBTestCase: XCTestCase {
    static let error = NSError(domain: "CCBTests", code: 555, userInfo: nil)

    var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        cancellables = []
    }

    override func tearDown() {
        cancellables.removeAll()
        CBMCentralManagerMock.tearDownSimulation()
    }

    static func mockPeripheral(
        withId id: UUID = UUID(),
        proximity: CBMProximity = .near,
        delegate: CBMPeripheralSpecDelegate? = nil,
        services: [CBMServiceMock] = []
    ) -> CBMPeripheralSpec {
        CBMPeripheralSpec
            .simulatePeripheral(identifier: id, proximity: proximity)
            .advertising(advertisementData: [CBAdvertisementDataIsConnectable: true])
            .connectable(name: "MockPeripheral", services: services, delegate: delegate)
            .build()
    }

    static func mockServices(with uuids: [CBUUID]) -> [CBMServiceMock] {
        uuids.map { uuid in
            CBMServiceMock(type: uuid, primary: true)
        }
    }

    static func mockService(
        with uuid: CBUUID,
        includedServices incl: [CBMServiceMock] = [],
        characteristics: [CBMCharacteristicMock] = []
    ) -> CBMServiceMock {
        let mock = CBMServiceMock(
            type: uuid,
            primary: true
        )
        mock.characteristics = characteristics
        mock.includedServices = incl
        return mock
    }

    static func mockCharacteristic(
        with uuid: CBUUID =  CBUUID(nsuuid: UUID()),
        properties: CBMCharacteristicProperties = [.read, .write],
        descriptors: [CBMDescriptorMock] = []
    ) -> CBMCharacteristicMock {
        let mock = CBMCharacteristicMock(
            type: uuid,
            properties: properties
        )
        mock.descriptors = descriptors
        return mock
    }

    static func mockDescriptor(
        with uuid: CBUUID =  CBUUID(nsuuid: UUID())
    ) -> CBMDescriptorMock {
        CBMDescriptorMock(type: uuid)
    }

    static let mockData: Data = Data(
        Array(repeating: 0, count: 3001)
        .enumerated()
        .map({ UInt8($0.offset % 2) })
    )

    static let mockSmallData: Data = Data(
        Array(repeating: 0, count: 100)
        .enumerated()
        .map({ UInt8($0.offset % 2) })
    )
}

class MockPeripheralDelegate: CBMPeripheralSpecDelegate {
    internal init(
        shouldConnect: Bool = true,
        shouldDiscoverServices: Bool = true,
        shouldDiscoverIncludedServices: Bool = true,
        shouldDiscoverCharacteristics: Bool = true,
        shouldDiscoverDescriptors: Bool = true,
        shouldWriteData: Bool = true,
        shouldReadData: Bool = true,
        data: Data = Data()) {
        self.shouldConnect = shouldConnect
        self.shouldDiscoverServices = shouldDiscoverServices
        self.shouldDiscoverIncludedServices = shouldDiscoverIncludedServices
        self.shouldDiscoverCharacteristics = shouldDiscoverCharacteristics
        self.shouldDiscoverDescriptors = shouldDiscoverDescriptors
        self.shouldWriteData = shouldWriteData
        self.shouldReadData = shouldReadData
        self.data = data
    }

    let shouldConnect: Bool
    let shouldDiscoverServices: Bool
    let shouldDiscoverIncludedServices: Bool
    let shouldDiscoverCharacteristics: Bool
    let shouldDiscoverDescriptors: Bool
    let shouldWriteData: Bool
    var shouldReadData: Bool
    var data: Data

    func peripheralDidReceiveConnectionRequest(
        _ peripheral: CBMPeripheralSpec
    ) -> Result<Void, Error> {
        if shouldConnect {
            return .success(())
        } else {
            return .failure(CCBTestCase.error)
        }
    }

    func peripheral(
        _ peripheral: CBMPeripheralSpec,
        didReceiveServiceDiscoveryRequest serviceUUIDs: [CBMUUID]?
    ) -> Result<Void, Error> {
        if shouldDiscoverServices {
            return .success(())
        } else {
            return .failure(CCBTestCase.error)
        }
    }

    func peripheral(
        _ peripheral: CBMPeripheralSpec,
        didReceiveIncludedServiceDiscoveryRequest serviceUUIDs: [CBMUUID]?,
        for service: CBMService
    ) -> Result<Void, Error> {
        if shouldDiscoverIncludedServices {
            return .success(())
        } else {
            return .failure(CCBTestCase.error)
        }
    }

    func peripheral(
        _ peripheral: CBMPeripheralSpec,
        didReceiveCharacteristicsDiscoveryRequest characteristicUUIDs: [CBMUUID]?,
        for service: CBMService
    ) -> Result<Void, Error> {
        if shouldDiscoverCharacteristics {
            return .success(())
        } else {
            return .failure(CCBTestCase.error)
        }
    }

    func peripheral(
        _ peripheral: CBMPeripheralSpec,
        didReceiveDescriptorsDiscoveryRequestFor characteristic: CBMCharacteristic
    ) -> Result<Void, Error> {
        if shouldDiscoverDescriptors {
            return .success(())
        } else {
            return .failure(CCBTestCase.error)
        }
    }

    func peripheral(
        _ peripheral: CBMPeripheralSpec,
        didReceiveWriteRequestFor characteristic: CBMCharacteristic,
        data: Data
    ) -> Result<Void, Error> {
        if shouldWriteData {
            self.data.append(data)
            return .success(())
        } else {
            return .failure(CCBTestCase.error)
        }
    }

    func peripheral(
        _ peripheral: CBMPeripheralSpec,
        didReceiveReadRequestFor charateristic: CBMCharacteristic
    ) -> Result<Data, Error> {
        if shouldReadData {
            return .success(data)
        } else {
            return .failure(CCBTestCase.error)
        }
    }
}
