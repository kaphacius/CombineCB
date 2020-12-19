import Foundation
import Combine

typealias CCBStream<T> = PassthroughSubject<T, Never>
typealias CCBPublisher<T> = AnyPublisher<T, Never>
