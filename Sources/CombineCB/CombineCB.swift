import Foundation
import Combine

enum CCBError: Error {
    case peripheralConnectionError(Error?)
    case peripheralDisconnectError(Error?)
    case serviceDiscoveryError(Error?)
    case includedServiceDiscoveryError(Error?)
}

typealias CCBStream<T> = PassthroughSubject<T, CCBError>
typealias CCBConnectStream = CCBStream<CCBPeripheral>
typealias CCBPublisher<T> = AnyPublisher<T, CCBError>
typealias CCBConnectPublisher = CCBPublisher<CCBPeripheral>
typealias CBOptions = [String: Any]
