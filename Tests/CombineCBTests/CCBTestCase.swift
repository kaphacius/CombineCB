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
}

class MockPeripheralDelegate: CBMPeripheralSpecDelegate {
    internal init(
        shouldConnect: Bool = true,
        shouldDiscoverServices: Bool = true,
        shouldDiscoverIncludedServices: Bool = true,
        shouldDiscoverCharacteristics: Bool = true,
        shouldDiscoverDescriptors: Bool = true,
        services: [CBMServiceMock] = []) {
        self.shouldConnect = shouldConnect
        self.shouldDiscoverServices = shouldDiscoverServices
        self.shouldDiscoverIncludedServices = shouldDiscoverIncludedServices
        self.shouldDiscoverCharacteristics = shouldDiscoverCharacteristics
        self.shouldDiscoverDescriptors = shouldDiscoverDescriptors
        self.services = services
    }

    let shouldConnect: Bool
    let shouldDiscoverServices: Bool
    let shouldDiscoverIncludedServices: Bool
    let shouldDiscoverCharacteristics: Bool
    let shouldDiscoverDescriptors: Bool
    let services: [CBMServiceMock]

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
}
