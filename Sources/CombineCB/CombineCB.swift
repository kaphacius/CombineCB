import Foundation
import Combine

enum CCBError: Error {
    case peripheralConnectionError(Error?)
    case peripheralDisconnectError(Error?)
    case serviceDiscoveryError(Error?)
    case includedServiceDiscoveryError(Error?)
}

typealias CCBStream<T> = PassthroughSubject<T, CCBError>
typealias CCBPublisher<T> = AnyPublisher<T, CCBError>
typealias CBOptions = [String: Any]
