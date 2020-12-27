#if targetEnvironment(simulator)
    import CoreBluetoothMock
#else
    import CoreBluetooth
#endif
import Foundation
import Combine

public final class CCBCentralManager: NSObject {
    private let manager: CBCentralManager
    private let stateStream = CurrentValueSubject<CBManagerState, CCBError>(.unknown)
    private let discoverStream = CCBStream<PeripheralDiscovered>()
    private var connectStreams: Dictionary<UUID, CCBPeripheralStream> = [:]

    public init(manager: CBCentralManager) {
        self.manager = manager
        super.init()

        manager.delegate = self
    }

    public func subscribeToStateChanges() -> CCBPublisher<CBManagerState> {
        stateStream.eraseToAnyPublisher()
    }

    public func scanForPeripherals(
        withServices services: [CBUUID]? = nil,
        options: [String: Any]? = nil
    ) -> CCBPublisher<PeripheralDiscovered> {
        manager.scanForPeripherals(withServices: services, options: options)
        return discoverStream.eraseToAnyPublisher()
    }

    public func connect(
        _ peripheral: CCBPeripheral,
        options: CBOptions? = nil) -> CCBPeripheralPublisher {
        let stream = connectStream(for: peripheral.id)
        manager.connect(peripheral.p, options: options)
        return stream.eraseToAnyPublisher()
    }

    public func cancelPeripheralConnection(
        _ peripheral: CBPeripheral
    ) -> CCBPeripheralPublisher {
        let stream = connectStream(for: peripheral.identifier)
        manager.cancelPeripheralConnection(peripheral)
        return stream.eraseToAnyPublisher()
    }

    private func onPeripheralDisconnect(with id: UUID) {
        connectStreams.removeValue(forKey: id)
    }

    private func connectStream(for id: UUID) -> CCBPeripheralStream {
        if let s = connectStreams[id] {
            return s
        } else {
            let stream = CCBPeripheralStream()
            connectStreams[id] = stream
            return stream
        }
    }
}

extension CCBCentralManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(
        _ central: CBCentralManager
    ) {
        stateStream.send(central.state)
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber) {
        discoverStream.send((CCBPeripheral(peripheral: peripheral), advertisementData, RSSI))
    }

    public func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        connectStreams[peripheral.identifier]
            .map {
                $0.send(CCBPeripheral(peripheral: peripheral))
            }
    }

    public func centralManager(
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

    public func centralManager(
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
