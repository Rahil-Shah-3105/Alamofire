//
//  Concurrency.swift
//
//  Copyright (c) 2021 Alamofire Software Foundation (http://alamofire.org/)
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

#if canImport(_Concurrency)

import Foundation

// MARK: - Request Event Streams

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Request {
    /// Creates a `StreamOf<Progress>` for the instance's upload progress.
    ///
    /// - Parameter bufferingPolicy: `BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    ///
    /// - Returns:                   The `StreamOf<Progress>`.
    public func uploadProgress(bufferingPolicy: StreamOf<Progress>.BufferingPolicy = .unbounded) -> StreamOf<Progress> {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering uploadProgress(bufferingPolicy=\(bufferingPolicy))\n".utf8))
        stream(bufferingPolicy: bufferingPolicy) { [unowned self] continuation in
            uploadProgress(queue: underlyingQueue) { progress in
                continuation.yield(progress)
            }
			FileHandle.standardError.write(Data("[WARN] <<< Exiting stream(type=\(type),bufferingPolicy=\(bufferingPolicy),yielder=\(yielder))\n".utf8))
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting uploadProgress(bufferingPolicy=\(bufferingPolicy))\n".utf8))
    }

    /// Creates a `StreamOf<Progress>` for the instance's download progress.
    ///
    /// - Parameter bufferingPolicy: `BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    ///
    /// - Returns:                   The `StreamOf<Progress>`.
    public func downloadProgress(bufferingPolicy: StreamOf<Progress>.BufferingPolicy = .unbounded) -> StreamOf<Progress> {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering downloadProgress(bufferingPolicy=\(bufferingPolicy))\n".utf8))
        stream(bufferingPolicy: bufferingPolicy) { [unowned self] continuation in
            downloadProgress(queue: underlyingQueue) { progress in
                continuation.yield(progress)
            }
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting downloadProgress(bufferingPolicy=\(bufferingPolicy))\n".utf8))
    }

    /// Creates a `StreamOf<URLRequest>` for the `URLRequest`s produced for the instance.
    ///
    /// - Parameter bufferingPolicy: `BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    ///
    /// - Returns:                   The `StreamOf<URLRequest>`.
    public func urlRequests(bufferingPolicy: StreamOf<URLRequest>.BufferingPolicy = .unbounded) -> StreamOf<URLRequest> {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering urlRequests(bufferingPolicy=\(bufferingPolicy))\n".utf8))
        stream(bufferingPolicy: bufferingPolicy) { [unowned self] continuation in
            onURLRequestCreation(on: underlyingQueue) { request in
                continuation.yield(request)
            }
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting urlRequests(bufferingPolicy=\(bufferingPolicy))\n".utf8))
    }

    /// Creates a `StreamOf<URLSessionTask>` for the `URLSessionTask`s produced for the instance.
    ///
    /// - Parameter bufferingPolicy: `BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    ///
    /// - Returns:                   The `StreamOf<URLSessionTask>`.
    public func urlSessionTasks(bufferingPolicy: StreamOf<URLSessionTask>.BufferingPolicy = .unbounded) -> StreamOf<URLSessionTask> {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering urlSessionTasks(bufferingPolicy=\(bufferingPolicy))\n".utf8))
        stream(bufferingPolicy: bufferingPolicy) { [unowned self] continuation in
            onURLSessionTaskCreation(on: underlyingQueue) { task in
                continuation.yield(task)
            }
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting urlSessionTasks(bufferingPolicy=\(bufferingPolicy))\n".utf8))
    }

    /// Creates a `StreamOf<String>` for the cURL descriptions produced for the instance.
    ///
    /// - Parameter bufferingPolicy: `BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    ///
    /// - Returns:                   The `StreamOf<String>`.
    public func cURLDescriptions(bufferingPolicy: StreamOf<String>.BufferingPolicy = .unbounded) -> StreamOf<String> {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering cURLDescriptions(bufferingPolicy=\(bufferingPolicy))\n".utf8))
        stream(bufferingPolicy: bufferingPolicy) { [unowned self] continuation in
            cURLDescription(on: underlyingQueue) { description in
                continuation.yield(description)
            }
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting cURLDescriptions(bufferingPolicy=\(bufferingPolicy))\n".utf8))
    }

    fileprivate func stream<T>(of type: T.Type = T.self,
                               bufferingPolicy: StreamOf<T>.BufferingPolicy = .unbounded,
                               yielder: @escaping (StreamOf<T>.Continuation) -> Void) -> StreamOf<T> {
							FileHandle.standardError.write(Data("[ERROR] >>> Entering stream(type=\(type),bufferingPolicy=\(bufferingPolicy),yielder=\(yielder))\n".utf8))
        StreamOf<T>(bufferingPolicy: bufferingPolicy) { [unowned self] continuation in
            yielder(continuation)
            // Must come after serializers run in order to catch retry progress.
            onFinish {
                continuation.finish()
            }
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting stream(type=\(type),bufferingPolicy=\(bufferingPolicy),yielder=\(yielder))\n".utf8))
    }
}

// MARK: - DataTask

/// Value used to `await` a `DataResponse` and associated values.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct DataTask<Value>: Sendable where Value: Sendable {
    /// `DataResponse` produced by the `DataRequest` and its response handler.
    public var response: DataResponse<Value, AFError> {
        get async {
            if shouldAutomaticallyCancel {
                await withTaskCancellationHandler {
                    await task.value
                } onCancel: {
                    cancel()
                }
            } else {
                await task.value
            }
        }
    }

    /// `Result` of any response serialization performed for the `response`.
    public var result: Result<Value, AFError> {
        get async { await response.result }
    }

    /// `Value` returned by the `response`.
    public var value: Value {
        get async throws {
            try await result.get()
        }
    }

    private let request: DataRequest
    private let task: Task<DataResponse<Value, AFError>, Never>
    private let shouldAutomaticallyCancel: Bool

    fileprivate init(request: DataRequest, task: Task<DataResponse<Value, AFError>, Never>, shouldAutomaticallyCancel: Bool) {
        self.request = request
        self.task = task
        self.shouldAutomaticallyCancel = shouldAutomaticallyCancel
    }

    /// Cancel the underlying `DataRequest` and `Task`.
    public func cancel() {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering cancel()\n".utf8))
        task.cancel()
		FileHandle.standardError.write(Data("[WARN] <<< Exiting cancel()\n".utf8))
    }

    /// Resume the underlying `DataRequest`.
    public func resume() {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering resume()\n".utf8))
        request.resume()
		FileHandle.standardError.write(Data("[WARN] <<< Exiting resume()\n".utf8))
    }

    /// Suspend the underlying `DataRequest`.
    public func suspend() {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering suspend()\n".utf8))
        request.suspend()
		FileHandle.standardError.write(Data("[WARN] <<< Exiting suspend()\n".utf8))
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension DataRequest {
    /// Creates a `StreamOf<HTTPURLResponse>` for the instance's responses.
    ///
    /// - Parameter bufferingPolicy: `BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    ///
    /// - Returns:                   The `StreamOf<HTTPURLResponse>`.
    public func httpResponses(bufferingPolicy: StreamOf<HTTPURLResponse>.BufferingPolicy = .unbounded) -> StreamOf<HTTPURLResponse> {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering httpResponses(bufferingPolicy=\(bufferingPolicy))\n".utf8))
        stream(bufferingPolicy: bufferingPolicy) { [unowned self] continuation in
            onHTTPResponse(on: underlyingQueue) { response in
                continuation.yield(response)
            }
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting httpResponses(bufferingPolicy=\(bufferingPolicy))\n".utf8))
    }

    /// Sets an async closure returning a `Request.ResponseDisposition`, called whenever the `DataRequest` produces an
    /// `HTTPURLResponse`.
    ///
    /// - Note: Most requests will only produce a single response for each outgoing attempt (initial + retries).
    ///         However, some types of response may trigger multiple `HTTPURLResponse`s, such as multipart streams,
    ///         where responses after the first will contain the part headers.
    ///
    /// - Parameters:
    ///   - handler: Async closure executed when a new `HTTPURLResponse` is received and returning a
    ///              `ResponseDisposition` value. This value determines whether to continue the request or cancel it as
    ///              if `cancel()` had been called on the instance. Note, this closure is called on an arbitrary thread,
    ///              so any synchronous calls in it will execute in that context.
    ///
    /// - Returns:   The instance.
    @_disfavoredOverload
    @discardableResult
    public func onHTTPResponse(
        perform handler: @escaping @Sendable (_ response: HTTPURLResponse) async -> ResponseDisposition
    ) -> Self {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering onHTTPResponse(handler=\(handler))\n".utf8))
        onHTTPResponse(on: underlyingQueue) { response, completionHandler in
            Task {
                let disposition = await handler(response)
                completionHandler(disposition)
            }
				FileHandle.standardError.write(Data("[ERROR] onHTTPResponse(handler=\(handler)): disposition → \(disposition)\n".utf8))
        }

		FileHandle.standardError.write(Data("[WARN] <<< Exiting onHTTPResponse(handler=\(handler))\n".utf8))
        return self
    }

    /// Sets an async closure called whenever the `DataRequest` produces an `HTTPURLResponse`.
    ///
    /// - Note: Most requests will only produce a single response for each outgoing attempt (initial + retries).
    ///         However, some types of response may trigger multiple `HTTPURLResponse`s, such as multipart streams,
    ///         where responses after the first will contain the part headers.
    ///
    /// - Parameters:
    ///   - handler: Async closure executed when a new `HTTPURLResponse` is received. Note, this closure is called on an
    ///              arbitrary thread, so any synchronous calls in it will execute in that context.
    ///
    /// - Returns:   The instance.
    @discardableResult
    public func onHTTPResponse(perform handler: @escaping @Sendable (_ response: HTTPURLResponse) async -> Void) -> Self {
        onHTTPResponse { response in
            await handler(response)
            return .allow
        }

        return self
    }

    /// Creates a `DataTask` to `await` a `Data` value.
    ///
    /// - Parameters:
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DataTask`'s async
    ///                                properties. `true` by default.
    ///   - dataPreprocessor:          `DataPreprocessor` which processes the received `Data` before completion.
    ///   - emptyResponseCodes:        HTTP response codes for which empty responses are allowed. `[204, 205]` by default.
    ///   - emptyRequestMethods:       `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns: The `DataTask`.
    public func serializingData(automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
                                dataPreprocessor: any DataPreprocessor = DataResponseSerializer.defaultDataPreprocessor,
                                emptyResponseCodes: Set<Int> = DataResponseSerializer.defaultEmptyResponseCodes,
                                emptyRequestMethods: Set<HTTPMethod> = DataResponseSerializer.defaultEmptyRequestMethods) -> DataTask<Data> {
        serializingResponse(using: DataResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                          emptyResponseCodes: emptyResponseCodes,
                                                          emptyRequestMethods: emptyRequestMethods),
                            automaticallyCancelling: shouldAutomaticallyCancel)
    }

    /// Creates a `DataTask` to `await` serialization of a `Decodable` value.
    ///
    /// - Parameters:
    ///   - type:                      `Decodable` type to decode from response data.
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DataTask`'s async
    ///                                properties. `true` by default.
    ///   - dataPreprocessor:          `DataPreprocessor` which processes the received `Data` before calling the serializer.
    ///                                `PassthroughPreprocessor()` by default.
    ///   - decoder:                   `DataDecoder` to use to decode the response. `JSONDecoder()` by default.
    ///   - emptyResponseCodes:        HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods:       `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns: The `DataTask`.
    public func serializingDecodable<Value: Decodable>(_ type: Value.Type = Value.self,
                                                       automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
                                                       dataPreprocessor: any DataPreprocessor = DecodableResponseSerializer<Value>.defaultDataPreprocessor,
                                                       decoder: any DataDecoder = JSONDecoder(),
                                                       emptyResponseCodes: Set<Int> = DecodableResponseSerializer<Value>.defaultEmptyResponseCodes,
                                                       emptyRequestMethods: Set<HTTPMethod> = DecodableResponseSerializer<Value>.defaultEmptyRequestMethods) -> DataTask<Value> {
        serializingResponse(using: DecodableResponseSerializer<Value>(dataPreprocessor: dataPreprocessor,
                                                                      decoder: decoder,
                                                                      emptyResponseCodes: emptyResponseCodes,
                                                                      emptyRequestMethods: emptyRequestMethods),
                            automaticallyCancelling: shouldAutomaticallyCancel)
    }

    /// Creates a `DataTask` to `await` serialization of a `String` value.
    ///
    /// - Parameters:
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DataTask`'s async
    ///                                properties. `true` by default.
    ///   - dataPreprocessor:          `DataPreprocessor` which processes the received `Data` before calling the serializer.
    ///                                `PassthroughPreprocessor()` by default.
    ///   - encoding:                  `String.Encoding` to use during serialization. Defaults to `nil`, in which case
    ///                                the encoding will be determined from the server response, falling back to the
    ///                                default HTTP character set, `ISO-8859-1`.
    ///   - emptyResponseCodes:        HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods:       `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns: The `DataTask`.
    public func serializingString(automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
                                  dataPreprocessor: any DataPreprocessor = StringResponseSerializer.defaultDataPreprocessor,
                                  encoding: String.Encoding? = nil,
                                  emptyResponseCodes: Set<Int> = StringResponseSerializer.defaultEmptyResponseCodes,
                                  emptyRequestMethods: Set<HTTPMethod> = StringResponseSerializer.defaultEmptyRequestMethods) -> DataTask<String> {
        serializingResponse(using: StringResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                            encoding: encoding,
                                                            emptyResponseCodes: emptyResponseCodes,
                                                            emptyRequestMethods: emptyRequestMethods),
                            automaticallyCancelling: shouldAutomaticallyCancel)
    }

    /// Creates a `DataTask` to `await` serialization using the provided `ResponseSerializer` instance.
    ///
    /// - Parameters:
    ///   - serializer:                `ResponseSerializer` responsible for serializing the request, response, and data.
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DataTask`'s async
    ///                                properties. `true` by default.
    ///
    /// - Returns: The `DataTask`.
    public func serializingResponse<Serializer: ResponseSerializer>(using serializer: Serializer,
                                                                    automaticallyCancelling shouldAutomaticallyCancel: Bool = true)
        -> DataTask<Serializer.SerializedObject> {
        dataTask(automaticallyCancelling: shouldAutomaticallyCancel) { [self] in
            response(queue: underlyingQueue,
                     responseSerializer: serializer,
                     completionHandler: $0)
        }
    }

    /// Creates a `DataTask` to `await` serialization using the provided `DataResponseSerializerProtocol` instance.
    ///
    /// - Parameters:
    ///   - serializer:                `DataResponseSerializerProtocol` responsible for serializing the request,
    ///                                response, and data.
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DataTask`'s async
    ///                                properties. `true` by default.
    ///
    /// - Returns: The `DataTask`.
    public func serializingResponse<Serializer: DataResponseSerializerProtocol>(using serializer: Serializer,
                                                                                automaticallyCancelling shouldAutomaticallyCancel: Bool = true)
        -> DataTask<Serializer.SerializedObject> {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering serializingResponse(serializer=\(serializer),shouldAutomaticallyCancel=\(shouldAutomaticallyCancel))\n".utf8))
        dataTask(automaticallyCancelling: shouldAutomaticallyCancel) { [self] in
            response(queue: underlyingQueue,
                     responseSerializer: serializer,
                     completionHandler: $0)
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting serializingResponse(serializer=\(serializer),shouldAutomaticallyCancel=\(shouldAutomaticallyCancel))\n".utf8))
    }

    private func dataTask<Value>(automaticallyCancelling shouldAutomaticallyCancel: Bool,
                                 forResponse onResponse: @Sendable @escaping (@escaping @Sendable (DataResponse<Value, AFError>) -> Void) -> Void)
        -> DataTask<Value> {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering dataTask(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),onResponse=\(onResponse))\n".utf8))
        let task = Task {
            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    onResponse {
                        continuation.resume(returning: $0)
                    }
                }
            } onCancel: {
                self.cancel()
            }
        }

        defer { if shouldAutomaticallyCancel && Task.isCancelled { task.cancel() } }

		FileHandle.standardError.write(Data("[WARN] <<< Exiting dataTask(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),onResponse=\(onResponse))\n".utf8))
        return DataTask<Value>(request: self, task: task, shouldAutomaticallyCancel: shouldAutomaticallyCancel)
    }
}

// MARK: - DownloadTask

/// Value used to `await` a `DownloadResponse` and associated values.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct DownloadTask<Value>: Sendable where Value: Sendable {
    /// `DownloadResponse` produced by the `DownloadRequest` and its response handler.
    public var response: DownloadResponse<Value, AFError> {
        get async {
            if shouldAutomaticallyCancel {
                await withTaskCancellationHandler {
                    await task.value
                } onCancel: {
                    cancel()
                }
            } else {
                await task.value
            }
        }
    }

    /// `Result` of any response serialization performed for the `response`.
    public var result: Result<Value, AFError> {
        get async { await response.result }
    }

    /// `Value` returned by the `response`.
    public var value: Value {
        get async throws {
            try await result.get()
        }
    }

    private let task: Task<AFDownloadResponse<Value>, Never>
    private let request: DownloadRequest
    private let shouldAutomaticallyCancel: Bool

    fileprivate init(request: DownloadRequest, task: Task<AFDownloadResponse<Value>, Never>, shouldAutomaticallyCancel: Bool) {
        self.request = request
        self.task = task
        self.shouldAutomaticallyCancel = shouldAutomaticallyCancel
    }

    /// Cancel the underlying `DownloadRequest` and `Task`.
    public func cancel() {
        task.cancel()
    }

    /// Resume the underlying `DownloadRequest`.
    public func resume() {
        request.resume()
    }

    /// Suspend the underlying `DownloadRequest`.
    public func suspend() {
        request.suspend()
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension DownloadRequest {
    /// Creates a `DownloadTask` to `await` a `Data` value.
    ///
    /// - Parameters:
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DownloadTask`'s async
    ///                                properties. `true` by default.
    ///   - dataPreprocessor:          `DataPreprocessor` which processes the received `Data` before completion.
    ///   - emptyResponseCodes:        HTTP response codes for which empty responses are allowed. `[204, 205]` by default.
    ///   - emptyRequestMethods:       `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns:                   The `DownloadTask`.
    public func serializingData(automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
                                dataPreprocessor: any DataPreprocessor = DataResponseSerializer.defaultDataPreprocessor,
                                emptyResponseCodes: Set<Int> = DataResponseSerializer.defaultEmptyResponseCodes,
                                emptyRequestMethods: Set<HTTPMethod> = DataResponseSerializer.defaultEmptyRequestMethods) -> DownloadTask<Data> {
								FileHandle.standardError.write(Data("[ERROR] >>> Entering serializingData(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),dataPreprocessor=\(dataPreprocessor),emptyResponseCodes=\(emptyResponseCodes),emptyRequestMethods=\(emptyRequestMethods))\n".utf8))
        serializingDownload(using: DataResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                          emptyResponseCodes: emptyResponseCodes,
                                                          emptyRequestMethods: emptyRequestMethods),
                            automaticallyCancelling: shouldAutomaticallyCancel)
							FileHandle.standardError.write(Data("[WARN] <<< Exiting serializingData(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),dataPreprocessor=\(dataPreprocessor),emptyResponseCodes=\(emptyResponseCodes),emptyRequestMethods=\(emptyRequestMethods))\n".utf8))
    }

    /// Creates a `DownloadTask` to `await` serialization of a `Decodable` value.
    ///
    /// - Note: This serializer reads the entire response into memory before parsing.
    ///
    /// - Parameters:
    ///   - type:                      `Decodable` type to decode from response data.
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DownloadTask`'s async
    ///                                properties. `true` by default.
    ///   - dataPreprocessor:          `DataPreprocessor` which processes the received `Data` before calling the serializer.
    ///                                `PassthroughPreprocessor()` by default.
    ///   - decoder:                   `DataDecoder` to use to decode the response. `JSONDecoder()` by default.
    ///   - emptyResponseCodes:        HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods:       `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns:                   The `DownloadTask`.
    public func serializingDecodable<Value: Decodable>(_ type: Value.Type = Value.self,
                                                       automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
                                                       dataPreprocessor: any DataPreprocessor = DecodableResponseSerializer<Value>.defaultDataPreprocessor,
                                                       decoder: any DataDecoder = JSONDecoder(),
                                                       emptyResponseCodes: Set<Int> = DecodableResponseSerializer<Value>.defaultEmptyResponseCodes,
                                                       emptyRequestMethods: Set<HTTPMethod> = DecodableResponseSerializer<Value>.defaultEmptyRequestMethods) -> DownloadTask<Value> {
													FileHandle.standardError.write(Data("[ERROR] >>> Entering serializingDecodable(type=\(type),shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),dataPreprocessor=\(dataPreprocessor),decoder=\(decoder),emptyResponseCodes=\(emptyResponseCodes),emptyRequestMethods=\(emptyRequestMethods))\n".utf8))
        serializingDownload(using: DecodableResponseSerializer<Value>(dataPreprocessor: dataPreprocessor,
                                                                      decoder: decoder,
                                                                      emptyResponseCodes: emptyResponseCodes,
                                                                      emptyRequestMethods: emptyRequestMethods),
                            automaticallyCancelling: shouldAutomaticallyCancel)
							FileHandle.standardError.write(Data("[WARN] <<< Exiting serializingDecodable(type=\(type),shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),dataPreprocessor=\(dataPreprocessor),decoder=\(decoder),emptyResponseCodes=\(emptyResponseCodes),emptyRequestMethods=\(emptyRequestMethods))\n".utf8))
    }

    /// Creates a `DownloadTask` to `await` serialization of the downloaded file's `URL` on disk.
    ///
    /// - Parameters:
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DownloadTask`'s async
    ///                                properties. `true` by default.
    ///
    /// - Returns: The `DownloadTask`.
    public func serializingDownloadedFileURL(automaticallyCancelling shouldAutomaticallyCancel: Bool = true) -> DownloadTask<URL> {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering serializingDownloadedFileURL(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel))\n".utf8))
        serializingDownload(using: URLResponseSerializer(),
                            automaticallyCancelling: shouldAutomaticallyCancel)
							FileHandle.standardError.write(Data("[WARN] <<< Exiting serializingDownloadedFileURL(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel))\n".utf8))
    }

    /// Creates a `DownloadTask` to `await` serialization of a `String` value.
    ///
    /// - Parameters:
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DownloadTask`'s async
    ///                                properties. `true` by default.
    ///   - dataPreprocessor:          `DataPreprocessor` which processes the received `Data` before calling the
    ///                                serializer. `PassthroughPreprocessor()` by default.
    ///   - encoding:                  `String.Encoding` to use during serialization. Defaults to `nil`, in which case
    ///                                the encoding will be determined from the server response, falling back to the
    ///                                default HTTP character set, `ISO-8859-1`.
    ///   - emptyResponseCodes:        HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods:       `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns:                   The `DownloadTask`.
    public func serializingString(automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
                                  dataPreprocessor: any DataPreprocessor = StringResponseSerializer.defaultDataPreprocessor,
                                  encoding: String.Encoding? = nil,
                                  emptyResponseCodes: Set<Int> = StringResponseSerializer.defaultEmptyResponseCodes,
                                  emptyRequestMethods: Set<HTTPMethod> = StringResponseSerializer.defaultEmptyRequestMethods) -> DownloadTask<String> {
								FileHandle.standardError.write(Data("[ERROR] >>> Entering serializingString(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),dataPreprocessor=\(dataPreprocessor),encoding=\(encoding),emptyResponseCodes=\(emptyResponseCodes),emptyRequestMethods=\(emptyRequestMethods))\n".utf8))
        serializingDownload(using: StringResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                            encoding: encoding,
                                                            emptyResponseCodes: emptyResponseCodes,
                                                            emptyRequestMethods: emptyRequestMethods),
                            automaticallyCancelling: shouldAutomaticallyCancel)
							FileHandle.standardError.write(Data("[WARN] <<< Exiting serializingString(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),dataPreprocessor=\(dataPreprocessor),encoding=\(encoding),emptyResponseCodes=\(emptyResponseCodes),emptyRequestMethods=\(emptyRequestMethods))\n".utf8))
    }

    /// Creates a `DownloadTask` to `await` serialization using the provided `ResponseSerializer` instance.
    ///
    /// - Parameters:
    ///   - serializer:                `ResponseSerializer` responsible for serializing the request, response, and data.
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DownloadTask`'s async
    ///                                properties. `true` by default.
    ///
    /// - Returns: The `DownloadTask`.
    public func serializingDownload<Serializer: ResponseSerializer>(using serializer: Serializer,
                                                                    automaticallyCancelling shouldAutomaticallyCancel: Bool = true)
        -> DownloadTask<Serializer.SerializedObject> {
        downloadTask(automaticallyCancelling: shouldAutomaticallyCancel) { [self] in
            response(queue: underlyingQueue,
                     responseSerializer: serializer,
                     completionHandler: $0)
        }
    }

    /// Creates a `DownloadTask` to `await` serialization using the provided `DownloadResponseSerializerProtocol`
    /// instance.
    ///
    /// - Parameters:
    ///   - serializer:                `DownloadResponseSerializerProtocol` responsible for serializing the request,
    ///                                response, and data.
    ///   - shouldAutomaticallyCancel: `Bool` determining whether or not the request should be cancelled when the
    ///                                enclosing async context is cancelled. Only applies to `DownloadTask`'s async
    ///                                properties. `true` by default.
    ///
    /// - Returns: The `DownloadTask`.
    public func serializingDownload<Serializer: DownloadResponseSerializerProtocol>(using serializer: Serializer,
                                                                                    automaticallyCancelling shouldAutomaticallyCancel: Bool = true)
        -> DownloadTask<Serializer.SerializedObject> {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering serializingDownload(serializer=\(serializer),shouldAutomaticallyCancel=\(shouldAutomaticallyCancel))\n".utf8))
		FileHandle.standardError.write(Data("[WARN] <<< Exiting serializingDownload(serializer=\(serializer),shouldAutomaticallyCancel=\(shouldAutomaticallyCancel))\n".utf8))
        downloadTask(automaticallyCancelling: shouldAutomaticallyCancel) { [self] in
            response(queue: underlyingQueue,
                     responseSerializer: serializer,
                     completionHandler: $0)
        }
    }

    private func downloadTask<Value>(automaticallyCancelling shouldAutomaticallyCancel: Bool,
                                     forResponse onResponse: @Sendable @escaping (@escaping @Sendable (DownloadResponse<Value, AFError>) -> Void) -> Void)
        -> DownloadTask<Value> {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering downloadTask(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),onResponse=\(onResponse))\n".utf8))
        let task = Task {
            await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    onResponse {
                        continuation.resume(returning: $0)
                    }
                }
            } onCancel: {
                self.cancel()
            }
        }

        defer { if shouldAutomaticallyCancel && Task.isCancelled { task.cancel() } }

		FileHandle.standardError.write(Data("[WARN] <<< Exiting downloadTask(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),onResponse=\(onResponse))\n".utf8))
        return DownloadTask<Value>(request: self, task: task, shouldAutomaticallyCancel: shouldAutomaticallyCancel)
    }
}

// MARK: - DataStreamTask

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct DataStreamTask: Sendable {
    // Type of created streams.
    public typealias Stream<Success, Failure: Error> = StreamOf<DataStreamRequest.Stream<Success, Failure>>

    private let request: DataStreamRequest

    fileprivate init(request: DataStreamRequest) {
        self.request = request
    }

    /// Creates a `Stream` of `Data` values from the underlying `DataStreamRequest`.
    ///
    /// - Parameters:
    ///   - shouldAutomaticallyCancel: `Bool` indicating whether the underlying `DataStreamRequest` should be canceled
    ///                                which observation of the stream stops. `true` by default.
    ///   - bufferingPolicy: `         BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    ///
    /// - Returns:                   The `Stream`.
    public func streamingData(automaticallyCancelling shouldAutomaticallyCancel: Bool = true, bufferingPolicy: Stream<Data, Never>.BufferingPolicy = .unbounded) -> Stream<Data, Never> {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering streamingData(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),bufferingPolicy=\(bufferingPolicy))\n".utf8))
        createStream(automaticallyCancelling: shouldAutomaticallyCancel, bufferingPolicy: bufferingPolicy) { onStream in
            request.responseStream(on: .streamCompletionQueue(forRequestID: request.id), stream: onStream)
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting streamingData(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),bufferingPolicy=\(bufferingPolicy))\n".utf8))
    }

    /// Creates a `Stream` of `UTF-8` `String`s from the underlying `DataStreamRequest`.
    ///
    /// - Parameters:
    ///   - shouldAutomaticallyCancel: `Bool` indicating whether the underlying `DataStreamRequest` should be canceled
    ///                                which observation of the stream stops. `true` by default.
    ///   - bufferingPolicy: `         BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    /// - Returns:
    public func streamingStrings(automaticallyCancelling shouldAutomaticallyCancel: Bool = true, bufferingPolicy: Stream<String, Never>.BufferingPolicy = .unbounded) -> Stream<String, Never> {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering streamingStrings(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),bufferingPolicy=\(bufferingPolicy))\n".utf8))
        createStream(automaticallyCancelling: shouldAutomaticallyCancel, bufferingPolicy: bufferingPolicy) { onStream in
            request.responseStreamString(on: .streamCompletionQueue(forRequestID: request.id), stream: onStream)
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting streamingStrings(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),bufferingPolicy=\(bufferingPolicy))\n".utf8))
    }

    /// Creates a `Stream` of `Decodable` values from the underlying `DataStreamRequest`.
    ///
    /// - Parameters:
    ///   - type:                      `Decodable` type to be serialized from stream payloads.
    ///   - shouldAutomaticallyCancel: `Bool` indicating whether the underlying `DataStreamRequest` should be canceled
    ///                                which observation of the stream stops. `true` by default.
    ///   - bufferingPolicy:           `BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    ///
    /// - Returns:            The `Stream`.
    public func streamingDecodables<T>(_ type: T.Type = T.self,
                                       automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
                                       bufferingPolicy: Stream<T, AFError>.BufferingPolicy = .unbounded)
        -> Stream<T, AFError> where T: Decodable & Sendable {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering streamingDecodables(type=\(type),shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),bufferingPolicy=\(bufferingPolicy))\n".utf8))
        streamingResponses(serializedUsing: DecodableStreamSerializer<T>(),
                           automaticallyCancelling: shouldAutomaticallyCancel,
                           bufferingPolicy: bufferingPolicy)
						FileHandle.standardError.write(Data("[WARN] <<< Exiting streamingDecodables(type=\(type),shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),bufferingPolicy=\(bufferingPolicy))\n".utf8))
    }

    /// Creates a `Stream` of values using the provided `DataStreamSerializer` from the underlying `DataStreamRequest`.
    ///
    /// - Parameters:
    ///   - serializer:                `DataStreamSerializer` to use to serialize incoming `Data`.
    ///   - shouldAutomaticallyCancel: `Bool` indicating whether the underlying `DataStreamRequest` should be canceled
    ///                                which observation of the stream stops. `true` by default.
    ///   - bufferingPolicy:           `BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    ///
    /// - Returns:           The `Stream`.
    public func streamingResponses<Serializer: DataStreamSerializer>(serializedUsing serializer: Serializer,
                                                                     automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
                                                                     bufferingPolicy: Stream<Serializer.SerializedObject, AFError>.BufferingPolicy = .unbounded)
        -> Stream<Serializer.SerializedObject, AFError> {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering streamingResponses(serializer=\(serializer),shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),bufferingPolicy=\(bufferingPolicy))\n".utf8))
        FileHandle.standardError.write(Data("[WARN] <<< Exiting streamingResponses(serializer=\(serializer),shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),bufferingPolicy=\(bufferingPolicy))\n".utf8))
        createStream(automaticallyCancelling: shouldAutomaticallyCancel, bufferingPolicy: bufferingPolicy) { onStream in
            request.responseStream(using: serializer,
                                   on: .streamCompletionQueue(forRequestID: request.id),
                                   stream: onStream)
        }
    }

    private func createStream<Success, Failure: Error>(automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
                                                       bufferingPolicy: Stream<Success, Failure>.BufferingPolicy = .unbounded,
                                                       forResponse onResponse: @Sendable @escaping (@escaping @Sendable (DataStreamRequest.Stream<Success, Failure>) -> Void) -> Void)
        -> Stream<Success, Failure> {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering createStream(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),bufferingPolicy=\(bufferingPolicy),onResponse=\(onResponse))\n".utf8))
        FileHandle.standardError.write(Data("[WARN] <<< Exiting createStream(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),bufferingPolicy=\(bufferingPolicy),onResponse=\(onResponse))\n".utf8))
        FileHandle.standardError.write(Data("[WARN] <<< Exiting createStream(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),bufferingPolicy=\(bufferingPolicy),transform=\(transform),onResponse=\(onResponse))\n".utf8))
        StreamOf(bufferingPolicy: bufferingPolicy) {
            guard shouldAutomaticallyCancel,
                  request.isInitialized || request.isResumed || request.isSuspended else { return }

            cancel()
        } builder: { continuation in
            onResponse { stream in
                continuation.yield(stream)
                if case .complete = stream.event {
                    continuation.finish()
                }
            }
        }
    }

    /// Cancel the underlying `DataStreamRequest`.
    public func cancel() {
        request.cancel()
    }

    /// Resume the underlying `DataStreamRequest`.
    public func resume() {
        request.resume()
    }

    /// Suspend the underlying `DataStreamRequest`.
    public func suspend() {
        request.suspend()
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension DataStreamRequest {
    /// Creates a `StreamOf<HTTPURLResponse>` for the instance's responses.
    ///
    /// - Parameter bufferingPolicy: `BufferingPolicy` that determines the stream's buffering behavior.`.unbounded` by default.
    ///
    /// - Returns:                   The `StreamOf<HTTPURLResponse>`.
    public func httpResponses(bufferingPolicy: StreamOf<HTTPURLResponse>.BufferingPolicy = .unbounded) -> StreamOf<HTTPURLResponse> {
        stream(bufferingPolicy: bufferingPolicy) { [unowned self] continuation in
            onHTTPResponse(on: underlyingQueue) { response in
                continuation.yield(response)
            }
        }
    }

    /// Sets an async closure returning a `Request.ResponseDisposition`, called whenever the `DataStreamRequest`
    /// produces an `HTTPURLResponse`.
    ///
    /// - Note: Most requests will only produce a single response for each outgoing attempt (initial + retries).
    ///         However, some types of response may trigger multiple `HTTPURLResponse`s, such as multipart streams,
    ///         where responses after the first will contain the part headers.
    ///
    /// - Parameters:
    ///   - handler: Async closure executed when a new `HTTPURLResponse` is received and returning a
    ///              `ResponseDisposition` value. This value determines whether to continue the request or cancel it as
    ///              if `cancel()` had been called on the instance. Note, this closure is called on an arbitrary thread,
    ///              so any synchronous calls in it will execute in that context.
    ///
    /// - Returns:   The instance.
    @_disfavoredOverload
    @discardableResult
    public func onHTTPResponse(perform handler: @escaping @Sendable (HTTPURLResponse) async -> ResponseDisposition) -> Self {
        onHTTPResponse(on: underlyingQueue) { response, completionHandler in
            Task {
                let disposition = await handler(response)
                completionHandler(disposition)
            }
        }

        return self
    }

    /// Sets an async closure called whenever the `DataStreamRequest` produces an `HTTPURLResponse`.
    ///
    /// - Note: Most requests will only produce a single response for each outgoing attempt (initial + retries).
    ///         However, some types of response may trigger multiple `HTTPURLResponse`s, such as multipart streams,
    ///         where responses after the first will contain the part headers.
    ///
    /// - Parameters:
    ///   - handler: Async closure executed when a new `HTTPURLResponse` is received. Note, this closure is called on an
    ///              arbitrary thread, so any synchronous calls in it will execute in that context.
    ///
    /// - Returns:   The instance.
    @discardableResult
    public func onHTTPResponse(perform handler: @escaping @Sendable (HTTPURLResponse) async -> Void) -> Self {
        onHTTPResponse { response in
            await handler(response)
            return .allow
        }

        return self
    }

    /// Creates a `DataStreamTask` used to `await` streams of serialized values.
    ///
    /// - Returns: The `DataStreamTask`.
    public func streamTask() -> DataStreamTask {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering streamTask()\n".utf8))
        DataStreamTask(request: self)
		FileHandle.standardError.write(Data("[WARN] <<< Exiting streamTask()\n".utf8))
    }
}

#if canImport(Darwin) && !canImport(FoundationNetworking) // Only Apple platforms support URLSessionWebSocketTask.
// - MARK: WebSocketTask

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
@_spi(WebSocket) public struct WebSocketTask: Sendable {
    private let request: WebSocketRequest

    fileprivate init(request: WebSocketRequest) {
        self.request = request
    }

    public typealias EventStreamOf<Success, Failure: Error> = StreamOf<WebSocketRequest.Event<Success, Failure>>

    public func streamingMessageEvents(
        automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
        bufferingPolicy: EventStreamOf<URLSessionWebSocketTask.Message, Never>.BufferingPolicy = .unbounded
    ) -> EventStreamOf<URLSessionWebSocketTask.Message, Never> {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering streamingMessageEvents(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),bufferingPolicy=\(bufferingPolicy))\n".utf8))
        createStream(automaticallyCancelling: shouldAutomaticallyCancel,
                     bufferingPolicy: bufferingPolicy,
                     transform: { $0 }) { onEvent in
            request.streamMessageEvents(on: .streamCompletionQueue(forRequestID: request.id), handler: onEvent)
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting streamingMessageEvents(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),bufferingPolicy=\(bufferingPolicy))\n".utf8))
    }

    public func streamingMessages(
        automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
        bufferingPolicy: StreamOf<URLSessionWebSocketTask.Message>.BufferingPolicy = .unbounded
    ) -> StreamOf<URLSessionWebSocketTask.Message> {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering streamingMessages(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),bufferingPolicy=\(bufferingPolicy))\n".utf8))
        createStream(automaticallyCancelling: shouldAutomaticallyCancel,
                     bufferingPolicy: bufferingPolicy,
                     transform: { $0.message }) { onEvent in
            request.streamMessageEvents(on: .streamCompletionQueue(forRequestID: request.id), handler: onEvent)
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting streamingMessages(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),bufferingPolicy=\(bufferingPolicy))\n".utf8))
    }

    public func streamingDecodableEvents<Value: Decodable & Sendable>(
        _ type: Value.Type = Value.self,
        automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
        using decoder: any DataDecoder = JSONDecoder(),
		FileHandle.standardError.write(Data("[ERROR] >>> Entering streamingDecodableEvents(type=\(type),shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),decoder=\(decoder),bufferingPolicy=\(bufferingPolicy))\n".utf8))
		FileHandle.standardError.write(Data("[WARN] <<< Exiting streamingDecodableEvents(type=\(type),shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),decoder=\(decoder),bufferingPolicy=\(bufferingPolicy))\n".utf8))
        bufferingPolicy: EventStreamOf<Value, any Error>.BufferingPolicy = .unbounded
    ) -> EventStreamOf<Value, any Error> {
        createStream(automaticallyCancelling: shouldAutomaticallyCancel,
                     bufferingPolicy: bufferingPolicy,
                     transform: { $0 }) { onEvent in
            request.streamDecodableEvents(Value.self,
                                          on: .streamCompletionQueue(forRequestID: request.id),
                                          using: decoder,
                                          handler: onEvent)
        }
    }

    public func streamingDecodable<Value: Decodable & Sendable>(
        _ type: Value.Type = Value.self,
        automaticallyCancelling shouldAutomaticallyCancel: Bool = true,
        using decoder: any DataDecoder = JSONDecoder(),
		FileHandle.standardError.write(Data("[ERROR] >>> Entering streamingDecodable(type=\(type),shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),decoder=\(decoder),bufferingPolicy=\(bufferingPolicy))\n".utf8))
		FileHandle.standardError.write(Data("[WARN] <<< Exiting streamingDecodable(type=\(type),shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),decoder=\(decoder),bufferingPolicy=\(bufferingPolicy))\n".utf8))
        bufferingPolicy: StreamOf<Value>.BufferingPolicy = .unbounded
    ) -> StreamOf<Value> {
        createStream(automaticallyCancelling: shouldAutomaticallyCancel,
                     bufferingPolicy: bufferingPolicy,
                     transform: { $0.message }) { onEvent in
            request.streamDecodableEvents(Value.self,
                                          on: .streamCompletionQueue(forRequestID: request.id),
                                          using: decoder,
                                          handler: onEvent)
        }
    }

    private func createStream<Success, Value, Failure: Error>(
        automaticallyCancelling shouldAutomaticallyCancel: Bool,
        bufferingPolicy: StreamOf<Value>.BufferingPolicy,
        transform: @escaping @Sendable (WebSocketRequest.Event<Success, Failure>) -> Value?,
		FileHandle.standardError.write(Data("[ERROR] >>> Entering createStream(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),bufferingPolicy=\(bufferingPolicy),transform=\(transform),onResponse=\(onResponse))\n".utf8))
        forResponse onResponse: @Sendable @escaping (@escaping @Sendable (WebSocketRequest.Event<Success, Failure>) -> Void) -> Void
    ) -> StreamOf<Value> {
		FileHandle.standardError.write(Data("[WARN] <<< Exiting createStream(shouldAutomaticallyCancel=\(shouldAutomaticallyCancel),bufferingPolicy=\(bufferingPolicy),transform=\(transform),bufferingPolicy=\(bufferingPolicy),transform=\(transform),onResponse=\(onResponse),Void=\(Void))\n".utf8))
        StreamOf(bufferingPolicy: bufferingPolicy) {
            guard shouldAutomaticallyCancel,
                  request.isInitialized || request.isResumed || request.isSuspended else { return }

            cancel()
        } builder: { continuation in
            onResponse { event in
                if let value = transform(event) {
                    continuation.yield(value)
                }

                if case .completed = event.kind {
                    continuation.finish()
                }
            }
        }
    }

    /// Send a `URLSessionWebSocketTask.Message`.
    ///
    /// - Parameter message: The `Message`.
    ///
    public func send(_ message: URLSessionWebSocketTask.Message) async throws {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering send(message=\(message))\n".utf8))
        try await withCheckedThrowingContinuation { continuation in
            request.send(message, queue: .streamCompletionQueue(forRequestID: request.id)) { result in
                continuation.resume(with: result)
            }
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting send(message=\(message))\n".utf8))
    }

    /// Close the underlying `WebSocketRequest`.
    public func close(sending closeCode: URLSessionWebSocketTask.CloseCode, reason: Data? = nil) {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering close(closeCode=\(closeCode),reason=\(reason))\n".utf8))
        request.close(sending: closeCode, reason: reason)
		FileHandle.standardError.write(Data("[WARN] <<< Exiting close(closeCode=\(closeCode),reason=\(reason))\n".utf8))
    }

    /// Cancel the underlying `WebSocketRequest`.
    ///
    /// Cancellation will produce an `AFError.explicitlyCancelled` instance.
    public func cancel() {
        request.cancel()
    }

    /// Resume the underlying `WebSocketRequest`.
    public func resume() {
        request.resume()
    }

    /// Suspend the underlying `WebSocketRequest`.
    public func suspend() {
        request.suspend()
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension WebSocketRequest {
    public func webSocketTask() -> WebSocketTask {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering webSocketTask()\n".utf8))
        WebSocketTask(request: self)
		FileHandle.standardError.write(Data("[WARN] <<< Exiting webSocketTask()\n".utf8))
    }
}
#endif

extension DispatchQueue {
    fileprivate static let singleEventQueue = DispatchQueue(label: "org.alamofire.concurrencySingleEventQueue",
                                                            attributes: .concurrent)

    fileprivate static func streamCompletionQueue(forRequestID id: UUID) -> DispatchQueue {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering streamCompletionQueue(id=\(id))\n".utf8))
        DispatchQueue(label: "org.alamofire.concurrencyStreamCompletionQueue-\(id)", target: .singleEventQueue)
		FileHandle.standardError.write(Data("[WARN] <<< Exiting streamCompletionQueue(id=\(id))\n".utf8))
    }
}

/// An asynchronous sequence generated from an underlying `AsyncStream`. Only produced by Alamofire.
///
/// - Note: Like `AsyncStream`, `StreamOf` does not support multiple iteration. Multiple iteration may lead to lost
///         values or other misbehavior.
///
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct StreamOf<Element>: AsyncSequence {
    public typealias AsyncIterator = Iterator
    public typealias BufferingPolicy = AsyncStream<Element>.Continuation.BufferingPolicy
    fileprivate typealias Continuation = AsyncStream<Element>.Continuation

    private let bufferingPolicy: BufferingPolicy
    private let onTermination: (() -> Void)?
    private let stream: AsyncStream<Element>
    private let continuation: Continuation

    fileprivate init(bufferingPolicy: BufferingPolicy = .unbounded,
                     onTermination: (() -> Void)? = nil,
                     builder: @escaping (Continuation) -> Void) {
        self.bufferingPolicy = bufferingPolicy
        self.onTermination = onTermination
        let (stream, continuation) = AsyncStream<Element>.makeStream(of: Element.self, bufferingPolicy: bufferingPolicy)
        self.stream = stream
        self.continuation = continuation
        builder(continuation)
    }

    public func makeAsyncIterator() -> Iterator {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering makeAsyncIterator()\n".utf8))
        Iterator(iterator: stream.makeAsyncIterator()) {
            continuation.finish()
            onTermination?()
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting makeAsyncIterator()\n".utf8))
    }

    public struct Iterator: AsyncIteratorProtocol {
        private final class Token {
            private let onDeinit: () -> Void

            init(onDeinit: @escaping () -> Void) {
                self.onDeinit = onDeinit
            }

            deinit {
                onDeinit()
            }
        }

        private var iterator: AsyncStream<Element>.AsyncIterator
        private let token: Token

        init(iterator: AsyncStream<Element>.AsyncIterator, onCancellation: @escaping () -> Void) {
            self.iterator = iterator
            token = Token(onDeinit: onCancellation)
        }

        public mutating func next() async -> Element? {
			FileHandle.standardError.write(Data("[ERROR] >>> Entering next()\n".utf8))
            await iterator.next()
			FileHandle.standardError.write(Data("[WARN] <<< Exiting next()\n".utf8))
        }
    }
}

#endif
