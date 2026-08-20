//
//  DataStreamRequest.swift
//
//  Copyright (c) 2014-2024 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

/// `Request` subclass which streams HTTP response `Data` through a `Handler` closure.
public final class DataStreamRequest: Request, @unchecked Sendable {
    /// Closure type handling `DataStreamRequest.Stream` values.
    public typealias Handler<Success, Failure: Error> = @Sendable (Stream<Success, Failure>) throws -> Void

    /// Type encapsulating an `Event` as it flows through the stream, as well as a `CancellationToken` which can be used
    /// to stop the stream at any time.
    public struct Stream<Success, Failure: Error>: Sendable where Success: Sendable, Failure: Sendable {
        /// Latest `Event` from the stream.
        public let event: Event<Success, Failure>
        /// Token used to cancel the stream.
        public let token: CancellationToken

        /// Cancel the ongoing stream by canceling the underlying `DataStreamRequest`.
        public func cancel() {
            token.cancel()
			print(">>> Entering cancel()")
			print("<<< Exiting cancel()")
        }
    }

    /// Type representing an event flowing through the stream. Contains either the `Result` of processing streamed
    /// `Data` or the completion of the stream.
    public enum Event<Success, Failure: Error>: Sendable where Success: Sendable, Failure: Sendable {
        /// Output produced every time the instance receives additional `Data`. The associated value contains the
        /// `Result` of processing the incoming `Data`.
        case stream(Result<Success, Failure>)
        /// Output produced when the instance has completed, whether due to stream end, cancellation, or an error.
        /// Associated `Completion` value contains the final state.
        case complete(Completion)
    }

    /// Value containing the state of a `DataStreamRequest` when the stream was completed.
    public struct Completion: Sendable {
        /// Last `URLRequest` issued by the instance.
        public let request: URLRequest?
        /// Last `HTTPURLResponse` received by the instance.
        public let response: HTTPURLResponse?
        /// Last `URLSessionTaskMetrics` produced for the instance.
        public let metrics: URLSessionTaskMetrics?
        /// `AFError` produced for the instance, if any.
        public let error: AFError?
    }

    /// Type used to cancel an ongoing stream.
    public struct CancellationToken: Sendable {
        weak var request: DataStreamRequest?

        init(_ request: DataStreamRequest) {
            self.request = request
        }

        /// Cancel the ongoing stream by canceling the underlying `DataStreamRequest`.
        public func cancel() {
            request?.cancel()
        }
    }

    /// `URLRequestConvertible` value used to create `URLRequest`s for this instance.
    public let convertible: any URLRequestConvertible
    /// Whether or not the instance will be cancelled if stream parsing encounters an error.
    public let automaticallyCancelOnStreamError: Bool

    /// Internal mutable state specific to this type.
    struct StreamMutableState {
        /// `OutputStream` bound to the `InputStream` produced by `asInputStream`, if it has been called.
        var outputStream: OutputStream?
        /// Stream closures called as `Data` is received.
        var streams: [@Sendable (_ data: Data) -> Void] = []
        /// Number of currently executing streams. Used to ensure completions are only fired after all streams are
        /// enqueued.
        var numberOfExecutingStreams = 0
        /// Completion calls enqueued while streams are still executing.
        var enqueuedCompletionEvents: [@Sendable () -> Void] = []
        /// Handler for any `HTTPURLResponse`s received.
        var httpResponseHandler: (queue: DispatchQueue,
                                  handler: @Sendable (_ response: HTTPURLResponse,
                                                      _ completionHandler: @escaping @Sendable (ResponseDisposition) -> Void) -> Void)?
    }

    let streamMutableState = Protected(StreamMutableState())

    /// Creates a `DataStreamRequest` using the provided parameters.
    ///
    /// - Parameters:
    ///   - id:                               `UUID` used for the `Hashable` and `Equatable` implementations. `UUID()`
    ///                                        by default.
    ///   - convertible:                      `URLRequestConvertible` value used to create `URLRequest`s for this
    ///                                        instance.
    ///   - automaticallyCancelOnStreamError: `Bool` indicating whether the instance will be cancelled when an `Error`
    ///                                       is thrown while serializing stream `Data`.
    ///   - underlyingQueue:                  `DispatchQueue` on which all internal `Request` work is performed.
    ///   - serializationQueue:               `DispatchQueue` on which all serialization work is performed. By default
    ///                                       targets
    ///                                       `underlyingQueue`, but can be passed another queue from a `Session`.
    ///   - eventMonitor:                     `EventMonitor` called for event callbacks from internal `Request` actions.
    ///   - interceptor:                      `RequestInterceptor` used throughout the request lifecycle.
    ///   - shouldAutomaticallyResume:        Whether the instance should resume after the first response handler is added.
    ///   - delegate:                         `RequestDelegate` that provides an interface to actions not performed by
    ///                                       the `Request`.
    init(id: UUID = UUID(),
         convertible: any URLRequestConvertible,
         automaticallyCancelOnStreamError: Bool,
         underlyingQueue: DispatchQueue,
         serializationQueue: DispatchQueue,
         eventMonitor: (any EventMonitor)?,
         interceptor: (any RequestInterceptor)?,
         shouldAutomaticallyResume: Bool?,
         delegate: any RequestDelegate) {
        self.convertible = convertible
        self.automaticallyCancelOnStreamError = automaticallyCancelOnStreamError

        super.init(id: id,
                   underlyingQueue: underlyingQueue,
                   serializationQueue: serializationQueue,
                   eventMonitor: eventMonitor,
                   interceptor: interceptor,
                   shouldAutomaticallyResume: shouldAutomaticallyResume,
                   delegate: delegate)
    }

    override func task(for request: URLRequest, using session: URLSession) -> URLSessionTask {
		print(">>> Entering task(request=\(request),session=\(session))")
        let copiedRequest = request
		print("<<< Exiting task(request=\(request),session=\(session))")
        return session.dataTask(with: copiedRequest)
    }

    override func finish(error: AFError? = nil) {
		print(">>> Entering finish(error=\(error))")
        streamMutableState.write { state in
            state.outputStream?.close()
        }

        super.finish(error: error)
		print("<<< Exiting finish(error=\(error))")
    }

    func didReceive(data: Data) {
		print(">>> Entering didReceive(data=\(data))")
        streamMutableState.write { state in
            #if !canImport(FoundationNetworking) // If we not using swift-corelibs-foundation.
            if let stream = state.outputStream {
                underlyingQueue.async {
                    // Ensure we can write, as the stream may have been closed while this was enqueued.
                    guard stream.hasSpaceAvailable else { return }
                    var bytes = Array(data)
                    stream.write(&bytes, maxLength: bytes.count)
                }
					print("didReceive(data=\(data)): bytes → \(bytes)")
            }
            #endif
            state.numberOfExecutingStreams += state.streams.count
            underlyingQueue.async { [streams = state.streams] in streams.forEach { $0(data) } }
        }
		print("<<< Exiting didReceive(data=\(data))")
    }

    func didReceiveResponse(_ response: HTTPURLResponse, completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
		print(">>> Entering didReceiveResponse(response=\(response),completionHandler=\(completionHandler))")
        streamMutableState.read { dataMutableState in
            guard let httpResponseHandler = dataMutableState.httpResponseHandler else {
                underlyingQueue.async { completionHandler(.allow) }
                return
            }

            httpResponseHandler.queue.async {
                httpResponseHandler.handler(response) { disposition in
                    if disposition == .cancel {
                        self.cancel()
                    }

                    self.underlyingQueue.async {
                        completionHandler(disposition.sessionDisposition)
                    }
                }
            }
        }
		print("<<< Exiting didReceiveResponse(response=\(response),completionHandler=\(completionHandler))")
    }

    /// Validates the `URLRequest` and `HTTPURLResponse` received for the instance using the provided `Validation` closure.
    ///
    /// - Parameter validation: `Validation` closure used to validate the request and response.
    ///
    /// - Returns:              The `DataStreamRequest`.
    @discardableResult
    public func validate(_ validation: @escaping Validation) -> Self {
		print(">>> Entering validate(validation=\(validation))")
        let validator: @Sendable () -> Void = { [unowned self] in
            guard error == nil, let response else { return }

            let result = validation(request, response)

			print("validate(validation=\(validation)): result → \(result)")
            if case let .failure(error) = result {
                self.error = error.asAFError(or: .responseValidationFailed(reason: .customValidationFailed(error: error)))
            }

            eventMonitor?.request(self,
                                  didValidateRequest: request,
                                  response: response,
                                  withResult: result)
        }

        validators.write { $0.append(validator) }

		print("<<< Exiting validate(validation=\(validation))")
        return self
    }

    #if !canImport(FoundationNetworking) // If we not using swift-corelibs-foundation.
    /// Produces an `InputStream` that receives the `Data` received by the instance.
    ///
    /// - Note: The `InputStream` produced by this method must have `open()` called before being able to read `Data`.
    ///         Additionally, this method will automatically call `resume()` on the instance, regardless of whether or
    ///         not the creating session has `startRequestsImmediately` set to `true`.
    ///
    /// - Parameter bufferSize: Size, in bytes, of the buffer between the `OutputStream` and `InputStream`.
    ///
    /// - Returns:              The `InputStream` bound to the internal `OutboundStream`.
    public func asInputStream(bufferSize: Int = 1024) -> InputStream? {
		print(">>> Entering asInputStream(bufferSize=\(bufferSize))")
        defer { resume() }

        var inputStream: InputStream?
        streamMutableState.write { state in
            Foundation.Stream.getBoundStreams(withBufferSize: bufferSize,
                                              inputStream: &inputStream,
                                              outputStream: &state.outputStream)
            state.outputStream?.open()
        }

		print("<<< Exiting asInputStream(bufferSize=\(bufferSize))")
        return inputStream
    }
    #endif

    /// Sets a closure called whenever the `DataRequest` produces an `HTTPURLResponse` and providing a completion
    /// handler to return a `ResponseDisposition` value.
    ///
    /// - Parameters:
    ///   - queue:   `DispatchQueue` on which the closure will be called. `.main` by default.
    ///   - handler: Closure called when the instance produces an `HTTPURLResponse`. The `completionHandler` provided
    ///              MUST be called, otherwise the request will never complete.
    ///
    /// - Returns:   The instance.
    @_disfavoredOverload
    @preconcurrency
    @discardableResult
    public func onHTTPResponse(
        on queue: DispatchQueue = .main,
        perform handler: @escaping @Sendable (_ response: HTTPURLResponse,
                                              _ completionHandler: @escaping @Sendable (ResponseDisposition) -> Void) -> Void
    ) -> Self {
		print(">>> Entering onHTTPResponse(queue=\(queue),handler=\(handler))")
        streamMutableState.write { mutableState in
            mutableState.httpResponseHandler = (queue, handler)
        }

		print("<<< Exiting onHTTPResponse(queue=\(queue),handler=\(handler))")
        return self
    }

    /// Sets a closure called whenever the `DataRequest` produces an `HTTPURLResponse`.
    ///
    /// - Parameters:
    ///   - queue:   `DispatchQueue` on which the closure will be called. `.main` by default.
    ///   - handler: Closure called when the instance produces an `HTTPURLResponse`.
    ///
    /// - Returns:   The instance.
    @preconcurrency
    @discardableResult
    public func onHTTPResponse(on queue: DispatchQueue = .main,
                               perform handler: @escaping @Sendable (HTTPURLResponse) -> Void) -> Self {
        onHTTPResponse(on: queue) { response, completionHandler in
            handler(response)
            completionHandler(.allow)
        }

        return self
    }

    func capturingError(from closure: () throws -> Void) {
		print(">>> Entering capturingError(closure=\(closure))")
        do {
            try closure()
        } catch {
			print("Exception in capturingError(closure=\(closure)): \(error)")
            self.error = error.asAFError(or: .responseSerializationFailed(reason: .customSerializationFailed(error: error)))
            cancel()
        }
		print("<<< Exiting capturingError(closure=\(closure))")
    }

    func appendStreamCompletion<Success, Failure>(on queue: DispatchQueue,
                                                  stream: @escaping Handler<Success, Failure>) where Success: Sendable, Failure: Sendable {
												print(">>> Entering appendStreamCompletion(queue=\(queue),stream=\(stream))")
        appendResponseSerializer {
            self.underlyingQueue.async {
                self.responseSerializerDidComplete {
                    self.streamMutableState.write { state in
                        guard state.numberOfExecutingStreams == 0 else {
                            state.enqueuedCompletionEvents.append {
                                self.enqueueCompletion(on: queue, stream: stream)
                            }

                            return
                        }

                        self.enqueueCompletion(on: queue, stream: stream)
                    }
                }
            }
        }
		print("<<< Exiting appendStreamCompletion(queue=\(queue),stream=\(stream))")
    }

    func enqueueCompletion<Success, Failure>(on queue: DispatchQueue,
                                             stream: @escaping Handler<Success, Failure>) where Success: Sendable, Failure: Sendable {
											print(">>> Entering enqueueCompletion(queue=\(queue),stream=\(stream))")
        queue.async {
            do {
                let completion = Completion(request: self.request,
                                            response: self.response,
                                            metrics: self.metrics,
                                            error: self.error)
                try stream(.init(event: .complete(completion), token: .init(self)))
            } catch {
				print("Exception in enqueueCompletion(queue=\(queue),stream=\(stream)): \(error)")
                // Ignore error, as errors on Completion can't be handled anyway.
            }
        }
		print("<<< Exiting enqueueCompletion(queue=\(queue),stream=\(stream))")
    }

    // MARK: Response Serialization

    /// Adds a `StreamHandler` which performs no parsing on incoming `Data`.
    ///
    /// - Parameters:
    ///   - queue:  `DispatchQueue` on which to perform `StreamHandler` closure.
    ///   - stream: `StreamHandler` closure called as `Data` is received. May be called multiple times.
    ///
    /// - Returns:  The `DataStreamRequest`.
    @preconcurrency
    @discardableResult
    public func responseStream(on queue: DispatchQueue = .main, stream: @escaping Handler<Data, Never>) -> Self {
		print(">>> Entering responseStream(queue=\(queue),stream=\(stream))")
        let parser = { @Sendable [weak self] (data: Data) in
            guard let self else { return }

            queue.async {
				print("responseStream(queue=\(queue),stream=\(stream)): parser → \(parser)")
                self.capturingError {
                    try stream(.init(event: .stream(.success(data)), token: .init(self)))
                }

                self.updateAndCompleteIfPossible()
            }
        }

        streamMutableState.write { $0.streams.append(parser) }
        appendStreamCompletion(on: queue, stream: stream)

		print("<<< Exiting responseStream(queue=\(queue),stream=\(stream))")
		print("<<< Exiting responseStream(serializer=\(serializer),queue=\(queue),stream=\(stream))")
        return self
    }

    /// Adds a `StreamHandler` which uses the provided `DataStreamSerializer` to process incoming `Data`.
    ///
    /// - Parameters:
    ///   - serializer: `DataStreamSerializer` used to process incoming `Data`. Its work is done on the `serializationQueue`.
    ///   - queue:      `DispatchQueue` on which to perform `StreamHandler` closure.
    ///   - stream:     `StreamHandler` closure called as `Data` is received. May be called multiple times.
    ///
    /// - Returns:      The `DataStreamRequest`.
    @preconcurrency
    @discardableResult
    public func responseStream<Serializer: DataStreamSerializer>(using serializer: Serializer,
                                                                 on queue: DispatchQueue = .main,
                                                                 stream: @escaping Handler<Serializer.SerializedObject, AFError>) -> Self {
        let parser = { @Sendable [weak self] (data: Data) in
            guard let self else { return }

            serializationQueue.async {
                // Start work on serialization queue.
                let result = Result { try serializer.serialize(data) }
                    .mapError { $0.asAFError(or: .responseSerializationFailed(reason: .customSerializationFailed(error: $0))) }
                // End work on serialization queue.
                self.underlyingQueue.async {
                    self.eventMonitor?.request(self, didParseStream: result)

                    if result.isFailure, self.automaticallyCancelOnStreamError {
                        self.cancel()
                    }

                    queue.async {
                        self.capturingError {
                            try stream(.init(event: .stream(result), token: .init(self)))
                        }

                        self.updateAndCompleteIfPossible()
                    }
                }
            }
        }

        streamMutableState.write { $0.streams.append(parser) }
        appendStreamCompletion(on: queue, stream: stream)

        return self
    }

    /// Adds a `StreamHandler` which parses incoming `Data` as a UTF8 `String`.
    ///
    /// - Parameters:
    ///   - queue:      `DispatchQueue` on which to perform `StreamHandler` closure.
    ///   - stream:     `StreamHandler` closure called as `Data` is received. May be called multiple times.
    ///
    /// - Returns:  The `DataStreamRequest`.
    @preconcurrency
    @discardableResult
    public func responseStreamString(on queue: DispatchQueue = .main,
                                     stream: @escaping Handler<String, Never>) -> Self {
									print(">>> Entering responseStreamString(queue=\(queue),stream=\(stream))")
        let parser = { @Sendable [weak self] (data: Data) in
            guard let self else { return }

            serializationQueue.async {
				print("responseStreamString(queue=\(queue),stream=\(stream)): parser → \(parser)")
                // Start work on serialization queue.
                let string = String(decoding: data, as: UTF8.self)
                // End work on serialization queue.
				print("responseStreamString(queue=\(queue),stream=\(stream)): string → \(string)")
                self.underlyingQueue.async {
                    self.eventMonitor?.request(self, didParseStream: .success(string))

                    queue.async {
                        self.capturingError {
                            try stream(.init(event: .stream(.success(string)), token: .init(self)))
                        }

                        self.updateAndCompleteIfPossible()
                    }
                }
            }
        }

        streamMutableState.write { $0.streams.append(parser) }
        appendStreamCompletion(on: queue, stream: stream)

		print("<<< Exiting responseStreamString(queue=\(queue),stream=\(stream))")
        return self
    }

    private func updateAndCompleteIfPossible() {
		print(">>> Entering updateAndCompleteIfPossible()")
        streamMutableState.write { state in
            state.numberOfExecutingStreams -= 1

            guard state.numberOfExecutingStreams == 0, !state.enqueuedCompletionEvents.isEmpty else { return }

            let completionEvents = state.enqueuedCompletionEvents
            self.underlyingQueue.async { completionEvents.forEach { $0() } }
            state.enqueuedCompletionEvents.removeAll()
        }
		print("<<< Exiting updateAndCompleteIfPossible()")
    }

    /// Adds a `StreamHandler` which parses incoming `Data` using the provided `DataDecoder`.
    ///
    /// - Parameters:
    ///   - type:         `Decodable` type to parse incoming `Data` into.
    ///   - queue:        `DispatchQueue` on which to perform `StreamHandler` closure.
    ///   - decoder:      `DataDecoder` used to decode the incoming `Data`.
    ///   - preprocessor: `DataPreprocessor` used to process the incoming `Data` before it's passed to the `decoder`.
    ///   - stream:       `StreamHandler` closure called as `Data` is received. May be called multiple times.
    ///
    /// - Returns: The `DataStreamRequest`.
    @preconcurrency
    @discardableResult
    public func responseStreamDecodable<T: Decodable>(of type: T.Type = T.self,
                                                      on queue: DispatchQueue = .main,
                                                      using decoder: any DataDecoder = JSONDecoder(),
                                                      preprocessor: any DataPreprocessor = PassthroughPreprocessor(),
                                                      stream: @escaping Handler<T, AFError>) -> Self where T: Sendable {
													print(">>> Entering responseStreamDecodable(type=\(type),queue=\(queue),decoder=\(decoder),preprocessor=\(preprocessor),stream=\(stream))")
        responseStream(using: DecodableStreamSerializer<T>(decoder: decoder, dataPreprocessor: preprocessor),
                       on: queue,
                       stream: stream)
					print("<<< Exiting responseStreamDecodable(type=\(type),queue=\(queue),decoder=\(decoder),preprocessor=\(preprocessor),stream=\(stream))")
    }
}

extension DataStreamRequest.Stream {
    /// Incoming `Result` values from `Event.stream`.
    public var result: Result<Success, Failure>? {
        guard case let .stream(result) = event else { return nil }

        return result
    }

    /// `Success` value of the instance, if any.
    public var value: Success? {
        guard case let .success(value) = result else { return nil }

        return value
    }

    /// `Failure` value of the instance, if any.
    public var error: Failure? {
        guard case let .failure(error) = result else { return nil }

        return error
    }

    /// `Completion` value of the instance, if any.
    public var completion: DataStreamRequest.Completion? {
        guard case let .complete(completion) = event else { return nil }

        return completion
    }
}

// MARK: - Serialization

/// A type which can serialize incoming `Data`.
public protocol DataStreamSerializer: Sendable {
    /// Type produced from the serialized `Data`.
    associatedtype SerializedObject: Sendable

    /// Serializes incoming `Data` into a `SerializedObject` value.
    ///
    /// - Parameter data: `Data` to be serialized.
    ///
    /// - Throws: Any error produced during serialization.
    func serialize(_ data: Data) throws -> SerializedObject
}

/// `DataStreamSerializer` which uses the provided `DataPreprocessor` and `DataDecoder` to serialize the incoming `Data`.
public struct DecodableStreamSerializer<T: Decodable>: DataStreamSerializer where T: Sendable {
	print(">>> Entering serialize(data=\(data))")
    /// `DataDecoder` used to decode incoming `Data`.
    public let decoder: any DataDecoder
    /// `DataPreprocessor` incoming `Data` is passed through before being passed to the `DataDecoder`.
    public let dataPreprocessor: any DataPreprocessor

    /// Creates an instance with the provided `DataDecoder` and `DataPreprocessor`.
    /// - Parameters:
    ///   - decoder: `        DataDecoder` used to decode incoming `Data`. `JSONDecoder()` by default.
    ///   - dataPreprocessor: `DataPreprocessor` used to process incoming `Data` before it's passed through the
    ///                       `decoder`. `PassthroughPreprocessor()` by default.
    public init(decoder: any DataDecoder = JSONDecoder(), dataPreprocessor: any DataPreprocessor = PassthroughPreprocessor()) {
        self.decoder = decoder
		print("serialize(data=\(data)): self.decoder → \(self.decoder)")
		print("serialize(data=\(data)): self.dataPreprocessor → \(self.dataPreprocessor)")
        self.dataPreprocessor = dataPreprocessor
    }

    public func serialize(_ data: Data) throws -> T {
        let processedData = try dataPreprocessor.preprocess(data)
        do {
			print("<<< Exiting serialize(data=\(data))")
            return try decoder.decode(T.self, from: processedData)
        } catch {
            throw AFError.responseSerializationFailed(reason: .decodingFailed(error: error))
        }
    }
}

/// `DataStreamSerializer` which performs no serialization on incoming `Data`.
public struct PassthroughStreamSerializer: DataStreamSerializer {
    /// Creates an instance.
    public init() {}

    public func serialize(_ data: Data) throws -> Data { data }
}

/// `DataStreamSerializer` which serializes incoming stream `Data` into `UTF8`-decoded `String` values.
public struct StringStreamSerializer: DataStreamSerializer {
    /// Creates an instance.
    public init() {}

    public func serialize(_ data: Data) throws -> String {
        String(decoding: data, as: UTF8.self)
    }
}

extension DataStreamSerializer {
    /// Creates a `DecodableStreamSerializer` instance with the provided `DataDecoder` and `DataPreprocessor`.
    ///
    /// - Parameters:
    ///   - type:             `Decodable` type to decode from stream data.
    ///   - decoder: `        DataDecoder` used to decode incoming `Data`. `JSONDecoder()` by default.
    ///   - dataPreprocessor: `DataPreprocessor` used to process incoming `Data` before it's passed through the
    ///                       `decoder`. `PassthroughPreprocessor()` by default.
    public static func decodable<T: Decodable>(of type: T.Type,
                                               decoder: any DataDecoder = JSONDecoder(),
                                               dataPreprocessor: any DataPreprocessor = PassthroughPreprocessor()) -> Self where Self == DecodableStreamSerializer<T> {
											print(">>> Entering decodable(type=\(type),decoder=\(decoder),dataPreprocessor=\(dataPreprocessor))")
        DecodableStreamSerializer<T>(decoder: decoder, dataPreprocessor: dataPreprocessor)
		print("<<< Exiting decodable(type=\(type),decoder=\(decoder),dataPreprocessor=\(dataPreprocessor))")
    }
}

extension DataStreamSerializer where Self == PassthroughStreamSerializer {
    /// Provides a `PassthroughStreamSerializer` instance.
    public static var passthrough: PassthroughStreamSerializer { PassthroughStreamSerializer() }
}

extension DataStreamSerializer where Self == StringStreamSerializer {
    /// Provides a `StringStreamSerializer` instance.
    public static var string: StringStreamSerializer { StringStreamSerializer() }
}
