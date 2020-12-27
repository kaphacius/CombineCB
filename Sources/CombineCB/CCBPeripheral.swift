#if targetEnvironment(simulator)
    import CoreBluetoothMock
#else
    import CoreBluetooth
#endif
import Foundation
import Combine

final public class CCBPeripheral: NSObject {
    private let peripheral: CBPeripheral
    private let serviceDiscoverStream = CCBStream<CCBPeripheral>()
    private var includedServicesDiscoverStreams: Dictionary<CBUUID, CCBDiscoverIncludedServicesStream> = [:]
    private var characteristicsDiscoverStreams: Dictionary<CBUUID, CCBDiscoverCharacteristicsStream> = [:]
    private var descriptorsDiscoverStreams: Dictionary<CBUUID, CCBDiscoverDescriptorsStream> = [:]
    private var characteristicValueWriters: Dictionary<CBUUID, CCBCharacteristicValueWriter> = [:]
    private var characteristicReadValueStreams: Dictionary<CBUUID, CCBCharacteristicChangeValueStream> = [:]
    private var characteristicNotifyValueStreams: Dictionary<CBUUID, CCBCharacteristicChangeValueStream> = [:]

    var p: CBPeripheral { peripheral }
    var id: UUID { peripheral.identifier }
    var services: [CBService] { peripheral.services ?? [] }

    public init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        super.init()

        peripheral.delegate = self
    }

    public func discoverServices(
        _ serviceUUIDs: [CBUUID]? = nil
    ) -> CCBPeripheralPublisher {
        peripheral.discoverServices(serviceUUIDs)
        return serviceDiscoverStream.eraseToAnyPublisher()
    }

    public func discoverIncludedServices(
        _ serviceUUIDs: [CBUUID]? = nil,
        for service: CBService
    ) -> CCBPublisher<IncludedServiceDiscovered> {
        peripheral.discoverIncludedServices(serviceUUIDs, for: service)
        return includedServicesDiscoverStream(for: service.uuid).eraseToAnyPublisher()
    }

    public func discoverCharacteristics(
        _ characteristicUUIDs: [CBUUID]?,
        for service: CBService
    ) -> CCBPublisher<CharacteristicsDiscovered> {
        peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
        return characteristicsDiscoverStream(for: service.uuid).eraseToAnyPublisher()
    }

    public func discoverDescriptors(
        for characteristic: CBCharacteristic
    ) -> CCBDiscoverDescriptorsPublisher {
        peripheral.discoverDescriptors(for: characteristic)
        return descriptorsDiscoverStream(for: characteristic.uuid).eraseToAnyPublisher()
    }

    public func writeValue(
        _ data: Data,
        for characteristic: CBCharacteristic,
        type: CBCharacteristicWriteType
    ) -> CCBCharacteristicChangeValuePublisher {
        let writer = CCBCharacteristicValueWriter(
            data: data,
            chunkSize: peripheral.maximumWriteValueLength(for: type),
            writeType: type,
            stream: CCBCharacteristicChangeValueStream()
        )
        characteristicValueWriters[characteristic.uuid] = writer

        guard writer.hasRemainingChunks,
              let nc = writer.nextChunk else {
            return Fail(error: CCBError.characteristicValueWriteDataMissing).eraseToAnyPublisher()
        }

        peripheral.writeValue(nc, for: characteristic, type: type)

        return writer.stream.eraseToAnyPublisher()
    }

    public func readValue(
        for characteristic: CBCharacteristic
    ) -> CCBCharacteristicChangeValuePublisher {
        peripheral.readValue(for: characteristic)
        return characteristicReadValueStream(for: characteristic.uuid).eraseToAnyPublisher()
    }

    public func setNotifyValue(
        _ enabled: Bool,
        for characteristic: CBCharacteristic
    ) -> CCBCharacteristicChangeValuePublisher {
        peripheral.setNotifyValue(enabled, for: characteristic)
        return characteristicNotifyValueStream(for: characteristic.uuid).eraseToAnyPublisher()
    }

    private func includedServicesDiscoverStream(
        for id: CBUUID
    ) -> CCBDiscoverIncludedServicesStream {
        if let s = includedServicesDiscoverStreams[id] {
            return s
        } else {
            let stream = CCBDiscoverIncludedServicesStream()
            includedServicesDiscoverStreams[id] = stream
            return stream
        }
    }

    private func characteristicsDiscoverStream(
        for id: CBUUID
    ) -> CCBDiscoverCharacteristicsStream {
        if let s = characteristicsDiscoverStreams[id] {
            return s
        } else {
            let stream = CCBDiscoverCharacteristicsStream()
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

    private func characteristicReadValueStream(
        for id: CBUUID
    ) -> CCBCharacteristicChangeValueStream {
        if let s = characteristicReadValueStreams[id] {
            return s
        } else {
            let stream = CCBCharacteristicChangeValueStream()
            characteristicReadValueStreams[id] = stream
            return stream
        }
    }

    private func characteristicNotifyValueStream(
        for id: CBUUID
    ) -> CCBCharacteristicChangeValueStream {
        if let s = characteristicNotifyValueStreams[id] {
            return s
        } else {
            let stream = CCBCharacteristicChangeValueStream()
            characteristicNotifyValueStreams[id] = stream
            return stream
        }
    }
}

extension CCBPeripheral: CBPeripheralDelegate {
    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        if let e = error {
            serviceDiscoverStream.send(completion: .failure(.serviceDiscoveryError(e)))
        } else {
            serviceDiscoverStream.send(self)
            serviceDiscoverStream.send(completion: .finished)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverIncludedServicesFor service: CBService,
        error: Error?
    ) {
        let stream = includedServicesDiscoverStream(for: service.uuid)

        if let e = error {
            stream.send(completion: .failure(.includedServiceDiscoveryError(e)))
        } else {
            stream.send((self, service))
            stream.send(completion: .finished)
        }

        includedServicesDiscoverStreams.removeValue(forKey: service.uuid)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        let stream = characteristicsDiscoverStream(for: service.uuid)

        if let e = error {
            stream.send(completion: .failure(.characteristicsDiscoveryError(e)))
        } else {
            stream.send((self, service))
            stream.send(completion: .finished)
        }

        characteristicsDiscoverStreams.removeValue(forKey: service.uuid)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverDescriptorsFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        let stream = descriptorsDiscoverStream(for: characteristic.uuid)

        if let e = error {
            stream.send(completion: .failure(.descriptiorsDiscoveryError(e)))
        } else {
            stream.send((self, characteristic))
            stream.send(completion: .finished)
        }

        descriptorsDiscoverStreams.removeValue(forKey: characteristic.uuid)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let writer = characteristicValueWriters[characteristic.uuid] else {
            return
        }

        if let e = error {
            writer.stream.send(completion: .failure(.characteristicValueWriteError(e)))
            characteristicValueWriters.removeValue(forKey: characteristic.uuid)
        } else if writer.hasRemainingChunks,
           let nc = writer.nextChunk {
            peripheral.writeValue(nc, for: characteristic, type: writer.writeType)
        } else {
            writer.stream.send((self, characteristic))
            writer.stream.send(completion: .finished)
            characteristicValueWriters.removeValue(forKey: characteristic.uuid)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if characteristic.isNotifying {
            if let e = error {
                characteristicNotifyValueStream(for: characteristic.uuid)
                    .send(completion: .failure(.characteristicValueReadError(e)))
                characteristicsDiscoverStreams.removeValue(forKey: characteristic.uuid)
            } else {
                characteristicNotifyValueStream(for: characteristic.uuid)
                    .send((self, characteristic))
            }
        } else {
            if let e = error {
                characteristicReadValueStream(for: characteristic.uuid)
                    .send(completion: .failure(.characteristicValueReadError(e)))
            } else {
                characteristicReadValueStream(for: characteristic.uuid)
                    .send((self, characteristic))
                characteristicReadValueStream(for: characteristic.uuid)
                    .send(completion: .finished)
            }
            characteristicReadValueStreams.removeValue(forKey: characteristic.uuid)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        let stream = characteristicNotifyValueStream(for: characteristic.uuid)

        if let e = error {
            stream.send(completion: .failure(.characteristicUpdateNotificationStateError(e)))
            characteristicNotifyValueStreams.removeValue(forKey: characteristic.uuid)
        } else if characteristic.isNotifying == false {
            stream.send(completion: .finished)
            characteristicNotifyValueStreams.removeValue(forKey: characteristic.uuid)
        }
    }
 }

class CCBCharacteristicValueWriter {
    private var chunks: [Data]
    internal let stream: CCBCharacteristicChangeValueStream
    internal let writeType: CBCharacteristicWriteType

    internal var hasRemainingChunks: Bool { chunks.isEmpty == false }
    internal var nextChunk: Data? { chunks.removeFirst() }

    init(
        data: Data,
        chunkSize: Int,
        writeType: CBCharacteristicWriteType,
        stream: CCBCharacteristicChangeValueStream
    ) {
        self.chunks = data.chunks(of: chunkSize)
        self.writeType = writeType
        self.stream = stream
    }
}
