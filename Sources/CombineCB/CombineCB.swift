import Foundation
import Combine

enum CCBError: Error {
    case peripheralConnectionError(Error?)
    case peripheralDisconnectError(Error?)
    case serviceDiscoveryError(Error?)
    case includedServiceDiscoveryError(Error)
    case characteristicsDiscoveryError(Error)
}

typealias CCBStream<T> = PassthroughSubject<T, CCBError>
typealias CCBPeripheralStream = CCBStream<CCBPeripheral>
typealias CCBServiceStream = CCBStream<CBService>
typealias CCBPublisher<T> = AnyPublisher<T, CCBError>
typealias CCBPeripheralPublisher = CCBPublisher<CCBPeripheral>
typealias CCBServicePublisher = CCBPublisher<CBService>
typealias CBOptions = [String: Any]
