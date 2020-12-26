import Foundation
import Combine
import CoreBluetooth

public enum CCBError: Error {
    case peripheralConnectionError(Error?)
    case peripheralDisconnectError(Error)
    case serviceDiscoveryError(Error)
    case includedServiceDiscoveryError(Error)
    case characteristicsDiscoveryError(Error)
    case descriptiorsDiscoveryError(Error)
    case characteristicValueWriteDataMissing
    case characteristicValueWriteError(Error)
    case characteristicValueReadError(Error)
    case characteristicUpdateNotificationStateError(Error)
}

public typealias IncludedServiceDiscovered = (
    peripheral: CCBPeripheral,
    service: CBService
)

public typealias CharacteristicsDiscovered = (
    peripheral: CCBPeripheral,
    service: CBService
)

public typealias DescriptorsDiscovered = (
    peripheral: CCBPeripheral,
    characteristic: CBCharacteristic
)

public typealias CharacteristicValueChanged = (
    peripheral: CCBPeripheral,
    characteristic: CBCharacteristic
)

public typealias PeripheralDiscovered = (
    peripheral: CCBPeripheral,
    advertisementData: [String: Any],
    rssi: NSNumber
)

public typealias CCBStream<T> = PassthroughSubject<T, CCBError>
public typealias CCBPeripheralStream = CCBStream<CCBPeripheral>
public typealias CCBDiscoverIncludedServicesStream = CCBStream<IncludedServiceDiscovered>
public typealias CCBDiscoverCharacteristicsStream = CCBStream<CharacteristicsDiscovered>
public typealias CCBDiscoverDescriptorsStream = CCBStream<DescriptorsDiscovered>
public typealias CCBCharacteristicChangeValueStream = CCBStream<CharacteristicValueChanged>
public typealias CCBPublisher<T> = AnyPublisher<T, CCBError>
public typealias CCBPeripheralPublisher = CCBPublisher<CCBPeripheral>
public typealias CCBServicePublisher = CCBPublisher<CBService>
public typealias CCBDiscoverIncludedServicesPublisher = CCBPublisher<IncludedServiceDiscovered>
public typealias CCBDiscoverCharacteristicsPublisher = CCBPublisher<CharacteristicsDiscovered>
public typealias CCBDiscoverDescriptorsPublisher = CCBPublisher<DescriptorsDiscovered>
public typealias CCBCharacteristicChangeValuePublisher = CCBPublisher<CharacteristicValueChanged>
public typealias CBOptions = [String: Any]

extension Data {
    func chunks(of size: Int) -> [Data] {
        stride(from: 0, to: count, by: size)
            .reduce(into: [Data]()) { (running: inout [Data], start: Int) in
                running.append(subdata(in: start..<Swift.min(start.advanced(by: size), count)))
            }
    }
}
