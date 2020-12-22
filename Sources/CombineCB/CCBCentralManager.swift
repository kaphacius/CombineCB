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
    private var connectStream = CCBStream<CCBPeripheral>()

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
        manager.connect(peripheral.p, options: options)
        return connectStream.eraseToAnyPublisher()
    }

    internal func cancelPeripheralConnection(
        _ peripheral: CBPeripheral
    ) -> CCBPublisher<CCBPeripheral> {
        manager.cancelPeripheralConnection(peripheral)
        return connectStream.eraseToAnyPublisher()
    }

    private func onPeripheralDisconnect() {
        connectStream = CCBStream<CCBPeripheral>()
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
        connectStream.send(CCBPeripheral(peripheral: peripheral))
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        connectStream
            .send(completion: .failure(.peripheralConnectionError(error)))
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        if let e = error {
            connectStream.send(completion: .failure(.peripheralDisconnectError(e)))
        } else {
            connectStream.send(completion: .finished)
        }

        onPeripheralDisconnect()
    }
}
