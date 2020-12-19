//
//  CCBCentralManager.swift
//  
//
//  Created by Yurii Zadoianchuk on 19/12/2020.
//

#if TEST
    import CoreBluetoothMock
#else
    import CoreBluetooth
#endif

import Foundation
import Combine

typealias PeripheralDiscovered = (
    peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi: NSNumber
)

class CCBCentralManager: NSObject {
    private let manager: CBCentralManager
    private let stateStream = CurrentValueSubject<CBManagerState, CCBError>(.unknown)
    private let discoverStream = CCBStream<PeripheralDiscovered>()
    private let connectStream = CCBStream<CBPeripheral>()

    internal init(manager: CBCentralManager) {
        self.manager = manager
        super.init()

        manager.delegate = self
    }

    internal func subscribeToStateChanges() -> CCBPublisher<CBManagerState> {
        stateStream.eraseToAnyPublisher()
    }

    internal func scanForPeripherals(
        withServices services: [CBUUID]?,
        options: [String: Any]?
    ) -> CCBPublisher<PeripheralDiscovered> {
        manager.scanForPeripherals(withServices: services, options: options)
        return discoverStream.eraseToAnyPublisher()
    }

    internal func connect(
        _ peripheral: CBPeripheral,
        options: CBOptions?) -> CCBPublisher<CBPeripheral> {
        manager.connect(peripheral, options: options)
        return connectStream.eraseToAnyPublisher()
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

    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        connectStream.send(peripheral)
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        connectStream.send(completion: .failure(.peripheralConnectionError(error)))
    }
}
