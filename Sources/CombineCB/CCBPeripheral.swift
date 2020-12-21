#if TEST
    import CoreBluetoothMock
#else
    import CoreBluetooth
#endif

import Foundation
import Combine

typealias IncludedServiceDiscovered = (
    peripheral: CCBPeripheral,
    service: CBService
)

class CCBPeripheral: NSObject {
    private let peripheral: CBPeripheral
    private let serviceDiscoverStream = CCBStream<CCBPeripheral>()
    private let includedServiceDiscoverStream = CCBStream<IncludedServiceDiscovered>()

    internal var p: CBPeripheral { peripheral }

    internal init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        super.init()

        peripheral.delegate = self
    }

    internal func discoverServices(
        _ serviceUUIDs: [CBUUID]? = nil
    ) -> CCBPublisher<CCBPeripheral> {
        peripheral.discoverServices(serviceUUIDs)
        return serviceDiscoverStream.eraseToAnyPublisher()
    }

    internal func discoverIncludedServices(
        _ serviceUUIDs: [CBUUID]? = nil,
        for service: CBService
    ) -> CCBPublisher<IncludedServiceDiscovered> {
        peripheral.discoverIncludedServices(serviceUUIDs, for: service)
        return includedServiceDiscoverStream.eraseToAnyPublisher()
    }
}

extension CCBPeripheral: CBPeripheralDelegate {
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        if let e = error {
            serviceDiscoverStream
                .send(completion: .failure(.serviceDiscoveryError(e)))
        } else {
            serviceDiscoverStream
                .send(self)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverIncludedServicesFor service: CBService,
        error: Error?
    ) {
        if let e = error {
            includedServiceDiscoverStream
                .send(completion: .failure(.includedServiceDiscoveryError(e)))
        } else {
            includedServiceDiscoverStream
                .send((self, service))
        }
    }
}
