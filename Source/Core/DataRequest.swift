//
//  DataRequest.swift
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

/// `Request` subclass which handles in-memory `Data` download using `URLSessionDataTask`.
public class DataRequest: Request, @unchecked Sendable {
    /// `URLRequestConvertible` value used to create `URLRequest`s for this instance.
    public let convertible: any URLRequestConvertible
    /// `Data` read from the server so far.
    public var data: Data? { dataMutableState.read(\.data) }

    private struct DataMutableState {
        var data: Data?
        var httpResponseHandler: (queue: DispatchQueue,
                                  handler: @Sendable (_ response: HTTPURLResponse,
                                                      _ completionHandler: @escaping @Sendable (ResponseDisposition) -> Void) -> Void)?
    }

    private let dataMutableState = Protected(DataMutableState())

    /// Creates a `DataRequest` using the provided parameters.
    ///
    /// - Parameters:
    ///   - id:                 `UUID` used for the `Hashable` and `Equatable` implementations. `UUID()` by default.
    ///   - convertible:        `URLRequestConvertible` value used to create `URLRequest`s for this instance.
    ///   - underlyingQueue:    `DispatchQueue` on which all internal `Request` work is performed.
    ///   - serializationQueue: `DispatchQueue` on which all serialization work is performed. By default targets
    ///                         `underlyingQueue`, but can be passed another queue from a `Session`.
    ///   - eventMonitor:       `EventMonitor` called for event callbacks from internal `Request` actions.
    ///   - interceptor:        `RequestInterceptor` used throughout the request lifecycle.
    ///   - delegate:           `RequestDelegate` that provides an interface to actions not performed by the `Request`.
    init(id: UUID = UUID(),
         convertible: any URLRequestConvertible,
         underlyingQueue: DispatchQueue,
         serializationQueue: DispatchQueue,
         eventMonitor: (any EventMonitor)?,
         interceptor: (any RequestInterceptor)?,
         shouldAutomaticallyResume: Bool?,
         delegate: any RequestDelegate) {
        self.convertible = convertible

        super.init(id: id,
                   underlyingQueue: underlyingQueue,
                   serializationQueue: serializationQueue,
                   eventMonitor: eventMonitor,
                   interceptor: interceptor,
                   shouldAutomaticallyResume: shouldAutomaticallyResume,
                   delegate: delegate)
    }

    override func reset() {
		print(">>> Entering reset()")
        super.reset()

        dataMutableState.write { mutableState in
            mutableState.data = nil
			print("reset(): mutableState.data → \(mutableState.data)")
        }
		print("<<< Exiting reset()")
    }

    /// Called when `Data` is received by this instance.
    ///
    /// - Note: Also calls `updateDownloadProgress`.
    ///
    /// - Parameter data: The `Data` received.
    func didReceive(data: Data) {
		print(">>> Entering didReceive(data=\(data))")
        dataMutableState.write { mutableState in
            if mutableState.data == nil {
                mutableState.data = data
            } else {
                mutableState.data?.append(data)
            }
        }

        updateDownloadProgress()
		print("<<< Exiting didReceive(data=\(data))")
    }

    func didReceiveResponse(_ response: HTTPURLResponse, completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
		print(">>> Entering didReceiveResponse(response=\(response),completionHandler=\(completionHandler))")
        dataMutableState.read { dataMutableState in
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

    override func task(for request: URLRequest, using session: URLSession) -> URLSessionTask {
		print(">>> Entering task(request=\(request),session=\(session))")
        let copiedRequest = request
		print("<<< Exiting task(request=\(request),session=\(session))")
        return session.dataTask(with: copiedRequest)
    }

    /// Called to update the `downloadProgress` of the instance.
    func updateDownloadProgress() {
		print(">>> Entering updateDownloadProgress()")
        let totalBytesReceived = Int64(data?.count ?? 0)
        let totalBytesExpected = task?.response?.expectedContentLength ?? NSURLSessionTransferSizeUnknown
		print("updateDownloadProgress(): totalBytesReceived → \(totalBytesReceived)")

        downloadProgress.totalUnitCount = totalBytesExpected
		print("updateDownloadProgress(): downloadProgress.totalUnitCount → \(downloadProgress.totalUnitCount)")
		print("updateDownloadProgress(): downloadProgress.completedUnitCount → \(downloadProgress.completedUnitCount)")
        downloadProgress.completedUnitCount = totalBytesReceived

        downloadProgressHandler?.queue.async { self.downloadProgressHandler?.handler(self.downloadProgress) }
		print("<<< Exiting updateDownloadProgress()")
    }

    /// Validates the request, using the specified closure.
    ///
    /// - Note: If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - Parameter validation: `Validation` closure used to validate the response.
    ///
    /// - Returns:              The instance.
    @preconcurrency
    @discardableResult
    public func validate(_ validation: @escaping Validation) -> Self {
		print(">>> Entering validate(validation=\(validation))")
        let validator: @Sendable () -> Void = { [unowned self] in
            guard error == nil, let response else { return }

            let result = validation(request, response, data)

			print("validate(validation=\(validation)): result → \(result)")
            if case let .failure(error) = result {
                self.error = error.asAFError(or: .responseValidationFailed(reason: .customValidationFailed(error: error)))
            }

            eventMonitor?.request(self,
                                  didValidateRequest: request,
                                  response: response,
                                  data: data,
                                  withResult: result)
        }

        validators.write { $0.append(validator) }

		print("<<< Exiting validate(validation=\(validation))")
        return self
    }

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
        dataMutableState.write { mutableState in
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

    // MARK: Response Serialization

    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:             The queue on which the completion handler is dispatched. `.main` by default.
    ///   - completionHandler: The code to be executed once the request has finished.
    ///
    /// - Returns:             The request.
    @preconcurrency
    @discardableResult
    public func response(queue: DispatchQueue = .main, completionHandler: @escaping @Sendable (AFDataResponse<Data?>) -> Void) -> Self {
		print(">>> Entering response(queue=\(queue),completionHandler=\(completionHandler))")
        appendResponseSerializer {
            // Start work that should be on the serialization queue.
            let result = AFResult<Data?>(value: self.data, error: self.error)
            // End work that should be on the serialization queue.
			print("response(queue=\(queue),completionHandler=\(completionHandler)): result → \(result)")

            self.underlyingQueue.async {
                let response = DataResponse(request: self.request,
                                            response: self.response,
                                            data: self.data,
                                            metrics: self.metrics,
                                            serializationDuration: 0,
                                            result: result)

											print("response(queue=\(queue),completionHandler=\(completionHandler)): response → \(response)")
                self.eventMonitor?.request(self, didParseResponse: response)

                self.responseSerializerDidComplete { queue.async { completionHandler(response) } }
            }
        }

		print("<<< Exiting response(queue=\(queue),completionHandler=\(completionHandler))")
		print("<<< Exiting response(queue=\(queue),responseSerializer=\(responseSerializer),completionHandler=\(completionHandler))")
        return self
    }

    private func _response<Serializer: DataResponseSerializerProtocol>(queue: DispatchQueue = .main,
                                                                       responseSerializer: Serializer,
                                                                       completionHandler: @escaping @Sendable (AFDataResponse<Serializer.SerializedObject>) -> Void)
        -> Self {
		print(">>> Entering _response(queue=\(queue),responseSerializer=\(responseSerializer),completionHandler=\(completionHandler))")
        appendResponseSerializer {
            // Start work that should be on the serialization queue.
            let start = ProcessInfo.processInfo.systemUptime
            let result: AFResult<Serializer.SerializedObject> = Result {
                try responseSerializer.serialize(request: self.request,
                                                 response: self.response,
                                                 data: self.data,
                                                 error: self.error)
            }.mapError { error in
                error.asAFError(or: .responseSerializationFailed(reason: .customSerializationFailed(error: error)))
            }

            let end = ProcessInfo.processInfo.systemUptime
            // End work that should be on the serialization queue.

            self.underlyingQueue.async {
                let response = DataResponse(request: self.request,
                                            response: self.response,
                                            data: self.data,
                                            metrics: self.metrics,
                                            serializationDuration: end - start,
                                            result: result)

											print("_response(queue=\(queue),responseSerializer=\(responseSerializer),completionHandler=\(completionHandler)): response → \(response)")
                self.eventMonitor?.request(self, didParseResponse: response)

                guard !self.isCancelled, let serializerError = result.failure, let delegate = self.delegate else {
                    self.responseSerializerDidComplete { queue.async { completionHandler(response) } }
                    return
                }

                delegate.retryResult(for: self, dueTo: serializerError) { retryResult in
                    var didComplete: (@Sendable () -> Void)?

                    defer {
                        if let didComplete {
                            self.responseSerializerDidComplete { queue.async { didComplete() } }
                        }
                    }

                    switch retryResult {
                    case .doNotRetry:
                        didComplete = { completionHandler(response) }
						print("_response(queue=\(queue),responseSerializer=\(responseSerializer),completionHandler=\(completionHandler)): didComplete → \(didComplete)")

                    case let .doNotRetryWithError(retryError):
                        let result: AFResult<Serializer.SerializedObject> = .failure(retryError.asAFError(orFailWith: "Received retryError was not already AFError"))

                        let response = DataResponse(request: self.request,
                                                    response: self.response,
                                                    data: self.data,
                                                    metrics: self.metrics,
                                                    serializationDuration: end - start,
                                                    result: result)

                        didComplete = { completionHandler(response) }

                    case .retry, .retryWithDelay:
                        delegate.retryRequest(self, withDelay: retryResult.delay)
                    }
                }
            }
        }

		print("<<< Exiting _response(queue=\(queue),responseSerializer=\(responseSerializer),completionHandler=\(completionHandler))")
        return self
    }

    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:              The queue on which the completion handler is dispatched. `.main` by default
    ///   - responseSerializer: The response serializer responsible for serializing the request, response, and data.
    ///   - completionHandler:  The code to be executed once the request has finished.
    ///
    /// - Returns:              The request.
    @preconcurrency
    @discardableResult
    public func response<Serializer: DataResponseSerializerProtocol>(queue: DispatchQueue = .main,
                                                                     responseSerializer: Serializer,
                                                                     completionHandler: @escaping @Sendable (AFDataResponse<Serializer.SerializedObject>) -> Void)
        -> Self {
        _response(queue: queue, responseSerializer: responseSerializer, completionHandler: completionHandler)
    }

    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:              The queue on which the completion handler is dispatched. `.main` by default
    ///   - responseSerializer: The response serializer responsible for serializing the request, response, and data.
    ///   - completionHandler:  The code to be executed once the request has finished.
    ///
    /// - Returns:              The request.
    @preconcurrency
    @discardableResult
    public func response<Serializer: ResponseSerializer>(queue: DispatchQueue = .main,
                                                         responseSerializer: Serializer,
                                                         completionHandler: @escaping @Sendable (AFDataResponse<Serializer.SerializedObject>) -> Void)
        -> Self {
        _response(queue: queue, responseSerializer: responseSerializer, completionHandler: completionHandler)
    }

    /// Adds a handler using a `DataResponseSerializer` to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:               The queue on which the completion handler is called. `.main` by default.
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before calling the
    ///                          `completionHandler`. `PassthroughPreprocessor()` by default.
    ///   - emptyResponseCodes:  HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///   - completionHandler:   A closure to be executed once the request has finished.
    ///
    /// - Returns:               The request.
    @preconcurrency
    @discardableResult
    public func responseData(queue: DispatchQueue = .main,
                             dataPreprocessor: any DataPreprocessor = DataResponseSerializer.defaultDataPreprocessor,
                             emptyResponseCodes: Set<Int> = DataResponseSerializer.defaultEmptyResponseCodes,
                             emptyRequestMethods: Set<HTTPMethod> = DataResponseSerializer.defaultEmptyRequestMethods,
                             completionHandler: @escaping @Sendable (AFDataResponse<Data>) -> Void) -> Self {
							print(">>> Entering responseData(queue=\(queue),dataPreprocessor=\(dataPreprocessor),emptyResponseCodes=\(emptyResponseCodes),emptyRequestMethods=\(emptyRequestMethods),completionHandler=\(completionHandler))")
        response(queue: queue,
                 responseSerializer: DataResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                            emptyResponseCodes: emptyResponseCodes,
                                                            emptyRequestMethods: emptyRequestMethods),
                 completionHandler: completionHandler)
				print("<<< Exiting responseData(queue=\(queue),dataPreprocessor=\(dataPreprocessor),emptyResponseCodes=\(emptyResponseCodes),emptyRequestMethods=\(emptyRequestMethods),completionHandler=\(completionHandler))")
    }

    /// Adds a handler using a `StringResponseSerializer` to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:               The queue on which the completion handler is dispatched. `.main` by default.
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before calling the
    ///                          `completionHandler`. `PassthroughPreprocessor()` by default.
    ///   - encoding:            The string encoding. Defaults to `nil`, in which case the encoding will be determined
    ///                          from the server response, falling back to the default HTTP character set, `ISO-8859-1`.
    ///   - emptyResponseCodes:  HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///   - completionHandler:   A closure to be executed once the request has finished.
    ///
    /// - Returns:               The request.
    @preconcurrency
    @discardableResult
    public func responseString(queue: DispatchQueue = .main,
                               dataPreprocessor: any DataPreprocessor = StringResponseSerializer.defaultDataPreprocessor,
                               encoding: String.Encoding? = nil,
                               emptyResponseCodes: Set<Int> = StringResponseSerializer.defaultEmptyResponseCodes,
                               emptyRequestMethods: Set<HTTPMethod> = StringResponseSerializer.defaultEmptyRequestMethods,
                               completionHandler: @escaping @Sendable (AFDataResponse<String>) -> Void) -> Self {
							print(">>> Entering responseString(queue=\(queue),dataPreprocessor=\(dataPreprocessor),encoding=\(encoding),emptyResponseCodes=\(emptyResponseCodes),emptyRequestMethods=\(emptyRequestMethods),completionHandler=\(completionHandler))")
        response(queue: queue,
                 responseSerializer: StringResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                              encoding: encoding,
                                                              emptyResponseCodes: emptyResponseCodes,
                                                              emptyRequestMethods: emptyRequestMethods),
                 completionHandler: completionHandler)
				print("<<< Exiting responseString(queue=\(queue),dataPreprocessor=\(dataPreprocessor),encoding=\(encoding),emptyResponseCodes=\(emptyResponseCodes),emptyRequestMethods=\(emptyRequestMethods),completionHandler=\(completionHandler))")
    }

    /// Adds a handler using a `JSONResponseSerializer` to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:               The queue on which the completion handler is dispatched. `.main` by default.
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before calling the
    ///                          `completionHandler`. `PassthroughPreprocessor()` by default.
    ///   - emptyResponseCodes:  HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///   - options:             `JSONSerialization.ReadingOptions` used when parsing the response. `.allowFragments`
    ///                          by default.
    ///   - completionHandler:   A closure to be executed once the request has finished.
    ///
    /// - Returns:               The request.
    @available(*, deprecated, message: "responseJSON deprecated and will be removed in Alamofire 6. Use responseDecodable instead.")
    @preconcurrency
    @discardableResult
    public func responseJSON(queue: DispatchQueue = .main,
                             dataPreprocessor: any DataPreprocessor = JSONResponseSerializer.defaultDataPreprocessor,
                             emptyResponseCodes: Set<Int> = JSONResponseSerializer.defaultEmptyResponseCodes,
                             emptyRequestMethods: Set<HTTPMethod> = JSONResponseSerializer.defaultEmptyRequestMethods,
                             options: JSONSerialization.ReadingOptions = .allowFragments,
                             completionHandler: @escaping @Sendable (AFDataResponse<Any>) -> Void) -> Self {
							print(">>> Entering responseJSON(queue=\(queue),dataPreprocessor=\(dataPreprocessor),emptyResponseCodes=\(emptyResponseCodes),emptyRequestMethods=\(emptyRequestMethods),options=\(options),completionHandler=\(completionHandler))")
        response(queue: queue,
                 responseSerializer: JSONResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                            emptyResponseCodes: emptyResponseCodes,
                                                            emptyRequestMethods: emptyRequestMethods,
                                                            options: options),
                 completionHandler: completionHandler)
				print("<<< Exiting responseJSON(queue=\(queue),dataPreprocessor=\(dataPreprocessor),emptyResponseCodes=\(emptyResponseCodes),emptyRequestMethods=\(emptyRequestMethods),options=\(options),completionHandler=\(completionHandler))")
    }

    /// Adds a handler using a `DecodableResponseSerializer` to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - type:                `Decodable` type to decode from response data.
    ///   - queue:               The queue on which the completion handler is dispatched. `.main` by default.
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before calling the
    ///                          `completionHandler`. `PassthroughPreprocessor()` by default.
    ///   - decoder:             `DataDecoder` to use to decode the response. `JSONDecoder()` by default.
    ///   - emptyResponseCodes:  HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///   - completionHandler:   A closure to be executed once the request has finished.
    ///
    /// - Returns:               The request.
    @preconcurrency
    @discardableResult
    public func responseDecodable<Value>(of type: Value.Type = Value.self,
                                         queue: DispatchQueue = .main,
                                         dataPreprocessor: any DataPreprocessor = DecodableResponseSerializer<Value>.defaultDataPreprocessor,
                                         decoder: any DataDecoder = JSONDecoder(),
                                         emptyResponseCodes: Set<Int> = DecodableResponseSerializer<Value>.defaultEmptyResponseCodes,
                                         emptyRequestMethods: Set<HTTPMethod> = DecodableResponseSerializer<Value>.defaultEmptyRequestMethods,
                                         completionHandler: @escaping @Sendable (AFDataResponse<Value>) -> Void) -> Self where Value: Decodable, Value: Sendable {
										print(">>> Entering responseDecodable(type=\(type),queue=\(queue),dataPreprocessor=\(dataPreprocessor),decoder=\(decoder),emptyResponseCodes=\(emptyResponseCodes),emptyRequestMethods=\(emptyRequestMethods),completionHandler=\(completionHandler))")
        response(queue: queue,
                 responseSerializer: DecodableResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                                 decoder: decoder,
                                                                 emptyResponseCodes: emptyResponseCodes,
                                                                 emptyRequestMethods: emptyRequestMethods),
                 completionHandler: completionHandler)
				print("<<< Exiting responseDecodable(type=\(type),queue=\(queue),dataPreprocessor=\(dataPreprocessor),decoder=\(decoder),emptyResponseCodes=\(emptyResponseCodes),emptyRequestMethods=\(emptyRequestMethods),completionHandler=\(completionHandler))")
    }
}
