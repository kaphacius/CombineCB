import Foundation
import Combine

enum CCBError: Error {
    case peripheralConnectionError(Error?)
    case peripheralDisconnectError(Error)
    case serviceDiscoveryError(Error)
    case includedServiceDiscoveryError(Error)
    case characteristicsDiscoveryError(Error)
    case descriptiorsDiscoveryError(Error)
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

typealias CCBStream<T> = PassthroughSubject<T, CCBError>
typealias CCBPeripheralStream = CCBStream<CCBPeripheral>
typealias CCBDiscoverIncludedServicesStream = CCBStream<IncludedServiceDiscovered>
typealias CCBDiscoverCharacteristicsStream = CCBStream<CharacteristicsDiscovered>
typealias CCBDiscoverDescriptorsStream = CCBStream<DescriptorsDiscovered>
typealias CCBPublisher<T> = AnyPublisher<T, CCBError>
typealias CCBPeripheralPublisher = CCBPublisher<CCBPeripheral>
typealias CCBServicePublisher = CCBPublisher<CBService>
typealias CCBDiscoverIncludedServicesPublisher = CCBPublisher<IncludedServiceDiscovered>
typealias CCBDiscoverCharacteristicsPublisher = CCBPublisher<CharacteristicsDiscovered>
typealias CCBDiscoverDescriptorsPublisher = CCBPublisher<DescriptorsDiscovered>
typealias CBOptions = [String: Any]
