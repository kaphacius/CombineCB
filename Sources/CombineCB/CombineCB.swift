import Foundation
import Combine

enum CCBError: Error {
    case peripheralConnectionError(Error?)
    case peripheralDisconnectError(Error)
    case serviceDiscoveryError(Error)
    case includedServiceDiscoveryError(Error)
    case characteristicsDiscoveryError(Error)
    case descriptiorsDiscoveryError(Error)
    case characteristicValueWriteDataMissing
    case characteristicValueWriteError(Error)
    case characteristicValueReadError(Error)
}

typealias IncludedServiceDiscovered = (
    peripheral: CCBPeripheral,
    service: CBService
)

typealias CharacteristicsDiscovered = (
    peripheral: CCBPeripheral,
    service: CBService
)

typealias DescriptorsDiscovered = (
    peripheral: CCBPeripheral,
    characteristic: CBCharacteristic
)

typealias CharacteristicValueChanged = (
    peripheral: CCBPeripheral,
    characteristic: CBCharacteristic
)

typealias CCBStream<T> = PassthroughSubject<T, CCBError>
typealias CCBPeripheralStream = CCBStream<CCBPeripheral>
typealias CCBDiscoverIncludedServicesStream = CCBStream<IncludedServiceDiscovered>
typealias CCBDiscoverCharacteristicsStream = CCBStream<CharacteristicsDiscovered>
typealias CCBDiscoverDescriptorsStream = CCBStream<DescriptorsDiscovered>
typealias CCBCharacteristicChangeValueStream = CCBStream<CharacteristicValueChanged>
typealias CCBPublisher<T> = AnyPublisher<T, CCBError>
typealias CCBPeripheralPublisher = CCBPublisher<CCBPeripheral>
typealias CCBServicePublisher = CCBPublisher<CBService>
typealias CCBDiscoverIncludedServicesPublisher = CCBPublisher<IncludedServiceDiscovered>
typealias CCBDiscoverCharacteristicsPublisher = CCBPublisher<CharacteristicsDiscovered>
typealias CCBDiscoverDescriptorsPublisher = CCBPublisher<DescriptorsDiscovered>
typealias CCBCharacteristicChangeValuePublisher = CCBPublisher<CharacteristicValueChanged>
typealias CBOptions = [String: Any]

extension Data {
    func chunks(of size: Int) -> [Data] {
        stride(from: 0, to: count, by: size)
            .reduce(into: [Data]()) { (running: inout [Data], start: Int) in
                running.append(subdata(in: start..<Swift.min(start.advanced(by: size), count)))
            }
    }
}
