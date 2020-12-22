#if TEST
    import CoreBluetoothMock
#else
    import CoreBluetooth
#endif

import Foundation
import Combine

typealias PeripheralDiscovered = (
    peripheral: CCBPeripheral,
    advertisementData: [String: Any],
    rssi: NSNumber
)

class CCBCentralManager: NSObject {
    private let manager: CBCentralManager
    private let stateStream = CurrentValueSubject<CBManagerState, CCBError>(.unknown)
    private let discoverStream = CCBStream<PeripheralDiscovered>()
    private var connectStreams: Dictionary<UUID, CCBConnectStream> = [:]

    internal init(manager: CBCentralManager) {
        self.manager = manager
        super.init()

        manager.delegate = self
    }

    internal func subscribeToStateChanges() -> CCBPublisher<CBManagerState> {
        stateStream.eraseToAnyPublisher()
    }

    internal func scanForPeripherals(
        withServices services: [CBUUID]? = nil,
        options: [String: Any]? = nil
    ) -> CCBPublisher<PeripheralDiscovered> {
        manager.scanForPeripherals(withServices: services, options: options)
        return discoverStream.eraseToAnyPublisher()
    }

    internal func connect(
        _ peripheral: CCBPeripheral,
        options: CBOptions? = nil) -> CCBPublisher<CCBPeripheral> {
        let stream = connectStream(for: peripheral.id)
        manager.connect(peripheral.p, options: options)
        return stream.eraseToAnyPublisher()
    }

    internal func cancelPeripheralConnection(
        _ peripheral: CBPeripheral
    ) -> CCBPublisher<CCBPeripheral> {
        let stream = connectStream(for: peripheral.identifier)
        manager.cancelPeripheralConnection(peripheral)
        return stream.eraseToAnyPublisher()
    }

    func onPeripheralDisconnect(with id: UUID) {
        connectStreams.removeValue(forKey: id)
    }

    private func connectStream(for id: UUID) -> CCBConnectStream {
        if let s = connectStreams[id] {
            return s
        } else {
            let stream = CCBConnectStream()
            connectStreams[id] = stream
            return stream
        }
    }
}

extension CCBCentralManager: CBCentralManagerDelegate {
    internal func centralManagerDidUpdateState(
        _ central: CBCentralManager
    ) {
        stateStream.send(central.state)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber) {
        discoverStream.send((CCBPeripheral(peripheral: peripheral), advertisementData, RSSI))
    }

    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        connectStreams[peripheral.identifier]
            .map {
                $0.send(CCBPeripheral(peripheral: peripheral))
            }
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        connectStreams[peripheral.identifier]
            .map {
                $0.send(completion: .failure(.peripheralConnectionError(error)))
            }
        onPeripheralDisconnect(with: peripheral.identifier)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        let stream = connectStream(for: peripheral.identifier)

        if let e = error {
            stream.send(completion: .failure(.peripheralDisconnectError(e)))
        } else {
            stream.send(completion: .finished)
        }

        onPeripheralDisconnect(with: peripheral.identifier)
    }
}
