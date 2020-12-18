#if TEST
    import CoreBluetoothMock
#else
    import CoreBluetooth
#endif

import Foundation
import Combine

typealias CCBStream<T> = PassthroughSubject<T, Never>
typealias CCBPublisher<T> = AnyPublisher<T, Never>

typealias PeripheralDiscovered = (
    peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi: NSNumber
)

class CCBCentralManager: NSObject {
    private let manager: CBCentralManager
    private let stateStream = CCBStream<CBManagerState>()
    private let discoverStream = CCBStream<PeripheralDiscovered>()

    internal init(manager: CBCentralManager) {
        self.manager = manager
        super.init()

        manager.delegate = self
    }

    internal func scanForPeripherals(
        withServices services: [CBUUID]?,
        options: [String: Any]?
    ) -> CCBPublisher<PeripheralDiscovered> {
        manager.scanForPeripherals(withServices: services, options: options)
        return discoverStream.eraseToAnyPublisher()
    }

    internal func subscribeToStateChanges() -> CCBPublisher<CBManagerState> {
        stateStream.eraseToAnyPublisher()
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
        discoverStream.send((peripheral, advertisementData, RSSI))
    }
}
