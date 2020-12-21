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
        includedServices incl: [CBMServiceMock] = []
    ) -> CBMServiceMock {
        let mock = CBMServiceMock(type: uuid, primary: true)
        mock.includedServices = incl
        return mock
    }
}

class MockPeripheralDelegate: CBMPeripheralSpecDelegate {
    internal init(
        shouldConnect: Bool = true,
        shouldDiscoverServices: Bool = true,
        shouldDiscoverIncludedServices: Bool = true,
        services: [CBMServiceMock] = []) {
        self.shouldConnect = shouldConnect
        self.shouldDiscoverServices = shouldDiscoverServices
        self.shouldDiscoverIncludedServices = shouldDiscoverIncludedServices
        self.services = services
    }

    let shouldConnect: Bool
    let shouldDiscoverServices: Bool
    let shouldDiscoverIncludedServices: Bool
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
}
