#if TEST
    import CoreBluetoothMock
#else
    import CoreBluetooth
#endif

import Foundation
import Combine

class CCBPeripheral: NSObject {
    private let peripheral: CBPeripheral
    private let serviceDiscoverStream = CCBStream<CCBPeripheral>()
    private let includedServiceDiscoverStream = CCBStream<IncludedServiceDiscovered>()
    private var characteristicsDiscoverStreams: Dictionary<CBUUID, CCBDiscoverCharacteristicsStream> = [:]
    private var descriptorsDiscoverStreams: Dictionary<CBUUID, CCBDiscoverDescriptorsStream> = [:]

    internal var p: CBPeripheral { peripheral }
    internal var id: UUID { peripheral.identifier }
    internal var services: [CBService] { peripheral.services ?? [] }

    internal init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        super.init()

        peripheral.delegate = self
    }

    internal func discoverServices(
        _ serviceUUIDs: [CBUUID]? = nil
    ) -> CCBPeripheralPublisher {
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

    internal func discoverCharacteristics(
        _ characteristicUUIDs: [CBUUID]?,
        for service: CBService
    ) -> CCBPublisher<CharacteristicsDiscovered> {
        let stream = characteristicsDiscoverStream(for: service.uuid)
        peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
        return stream.eraseToAnyPublisher()
    }

    internal func discoverDescriptors(
        for characteristic: CBCharacteristic
    ) -> CCBDiscoverDescriptorsPublisher {
        let stream = descriptorsDiscoverStream(for: characteristic.uuid)
        peripheral.discoverDescriptors(for: characteristic)
        return stream.eraseToAnyPublisher()
    }

    private func characteristicsDiscoverStream(
        for id: CBUUID
    ) -> CCBDiscoverCharacteristicsStream {
        if let s = characteristicsDiscoverStreams[id] {
            return s
        } else {
            let stream = CCBStream<CharacteristicsDiscovered>()
            characteristicsDiscoverStreams[id] = stream
            return stream
        }
    }

    private func descriptorsDiscoverStream(
        for id: CBUUID
    ) -> CCBDiscoverDescriptorsStream {
        if let s = descriptorsDiscoverStreams[id] {
            return s
        } else {
            let stream = CCBDiscoverDescriptorsStream()
            descriptorsDiscoverStreams[id] = stream
            return stream
        }
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

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        let stream = characteristicsDiscoverStream(for: service.uuid)

        if let e = error {
            stream.send(completion: .failure(.characteristicsDiscoveryError(e)))
        } else {
            stream.send((self, service))
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverDescriptorsFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        let stream = descriptorsDiscoverStream(for: characteristic.uuid)

        if let e = error {
            stream.send(completion: .failure(.descriptiorsDiscoveryError(e)))
        } else {
            stream.send((self, characteristic))
        }
    }
}
