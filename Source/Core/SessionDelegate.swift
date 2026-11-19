//
//  SessionDelegate.swift
//
//  Copyright (c) 2014-2018 Alamofire Software Foundation (http://alamofire.org/)
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

/// Class which implements the various `URLSessionDelegate` methods to connect various Alamofire features.
open class SessionDelegate: NSObject, @unchecked Sendable {
    private let fileManager: FileManager

    weak var stateProvider: (any SessionStateProvider)?
    var eventMonitor: (any EventMonitor)?
    var sessionInvalidationCleanup = Protected<(() -> Void)?>(nil)

    /// Creates an instance from the given `FileManager`.
    ///
    /// - Parameter fileManager: `FileManager` to use for underlying file management, such as moving downloaded files.
    ///                          `.default` by default.
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Internal method to find and cast requests while maintaining some integrity checking.
    ///
    /// - Parameters:
    ///   - task: The `URLSessionTask` for which to find the associated `Request`.
    ///   - type: The `Request` subclass type to cast any `Request` associate with `task`.
    func request<R: Request>(for task: URLSessionTask, as type: R.Type) -> R? {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering request(task=\(task),type=\(type))\n".utf8))
        guard let provider = stateProvider else {
            assertionFailure("StateProvider is nil for task \(task.taskIdentifier).")
            return nil
        }

        return provider.request(for: task) as? R
    }
}

/// Type which provides various `Session` state values.
protocol SessionStateProvider: AnyObject, Sendable {
    var serverTrustManager: ServerTrustManager? { get }
    var redirectHandler: (any RedirectHandler)? { get }
    var cachedResponseHandler: (any CachedResponseHandler)? { get }

    func request(for task: URLSessionTask) -> Request?
    func didGatherMetricsForTask(_ task: URLSessionTask)
    func didCompleteTask(_ task: URLSessionTask, completion: @escaping () -> Void)
    func credential(for task: URLSessionTask, in protectionSpace: URLProtectionSpace) -> URLCredential?
    func cancelRequestsForSessionInvalidation(with error: (any Error)?)
}

// MARK: URLSessionDelegate

extension SessionDelegate: URLSessionDelegate {
    open func urlSession(_ session: URLSession, didBecomeInvalidWithError error: (any Error)?) {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering urlSession(session=\(session),error=\(error))\n".utf8))
        eventMonitor?.urlSession(session, didBecomeInvalidWithError: error)

        // When invalidated due to Session.deinit, stateProvider will already have dropped to nil.
        stateProvider?.cancelRequestsForSessionInvalidation(with: error)

        let sessionInvalidationCleanup = sessionInvalidationCleanup.write {
            let cleanup = $0
            $0 = nil
            return cleanup
        }
        sessionInvalidationCleanup?()
		FileHandle.standardError.write(Data("[WARN] <<< Exiting urlSession(session=\(session),error=\(error))\n".utf8))
    }
}

// MARK: URLSessionTaskDelegate

extension SessionDelegate: URLSessionTaskDelegate {
    /// Result of a `URLAuthenticationChallenge` evaluation.
    typealias ChallengeEvaluation = (disposition: URLSession.AuthChallengeDisposition, credential: URLCredential?, error: AFError?)

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         didReceive challenge: URLAuthenticationChallenge,
                         completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
						FileHandle.standardError.write(Data("[ERROR] >>> Entering urlSession(session=\(session),task=\(task),challenge=\(challenge),completionHandler=\(completionHandler))\n".utf8))
        eventMonitor?.urlSession(session, task: task, didReceive: challenge)

        let evaluation: ChallengeEvaluation = switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest, NSURLAuthenticationMethodNTLM,
             NSURLAuthenticationMethodNegotiate:
            attemptCredentialAuthentication(for: challenge, belongingTo: task)
        #if canImport(Security)
        case NSURLAuthenticationMethodServerTrust:
            attemptServerTrustAuthentication(with: challenge)
        case NSURLAuthenticationMethodClientCertificate:
            attemptCredentialAuthentication(for: challenge, belongingTo: task)
        #endif
        default:
            (.performDefaultHandling, nil, nil)
        }

        if let error = evaluation.error {
            stateProvider?.request(for: task)?.didFailTask(task, earlyWithError: error)
        }

        completionHandler(evaluation.disposition, evaluation.credential)
    }

    #if canImport(Security)
    /// Evaluates the server trust `URLAuthenticationChallenge` received.
    ///
    /// - Parameter challenge: The `URLAuthenticationChallenge`.
    ///
    /// - Returns:             The `ChallengeEvaluation`.
    func attemptServerTrustAuthentication(with challenge: URLAuthenticationChallenge) -> ChallengeEvaluation {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering attemptServerTrustAuthentication(challenge=\(challenge))\n".utf8))
        let host = challenge.protectionSpace.host

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust
        else {
            return (.performDefaultHandling, nil, nil)
        }

        do {
            guard let evaluator = try stateProvider?.serverTrustManager?.serverTrustEvaluator(forHost: host) else {
                return (.performDefaultHandling, nil, nil)
            }

            try evaluator.evaluate(trust, forHost: host)

            return (.useCredential, URLCredential(trust: trust), nil)
        } catch {
			FileHandle.standardError.write(Data("[ERROR] Exception in attemptServerTrustAuthentication(challenge=\(challenge)): \(error)\n".utf8))
			FileHandle.standardError.write(Data("[WARN] <<< Exiting attemptServerTrustAuthentication(challenge=\(challenge))\n".utf8))
            return (.cancelAuthenticationChallenge, nil, error.asAFError(or: .serverTrustEvaluationFailed(reason: .customEvaluationFailed(error: error))))
        }
    }
    #endif

    /// Evaluates the credential-based authentication `URLAuthenticationChallenge` received for `task`.
    ///
    /// - Parameters:
    ///   - challenge: The `URLAuthenticationChallenge`.
    ///   - task:      The `URLSessionTask` which received the challenge.
    ///
    /// - Returns:     The `ChallengeEvaluation`.
    func attemptCredentialAuthentication(for challenge: URLAuthenticationChallenge,
                                         belongingTo task: URLSessionTask) -> ChallengeEvaluation {
										FileHandle.standardError.write(Data("[ERROR] >>> Entering attemptCredentialAuthentication(challenge=\(challenge),task=\(task))\n".utf8))
        guard challenge.previousFailureCount == 0 else {
            return (.rejectProtectionSpace, nil, nil)
        }

        guard let credential = stateProvider?.credential(for: task, in: challenge.protectionSpace) else {
            return (.performDefaultHandling, nil, nil)
        }

        return (.useCredential, credential, nil)
    }

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         didSendBodyData bytesSent: Int64,
                         totalBytesSent: Int64,
                         totalBytesExpectedToSend: Int64) {
						FileHandle.standardError.write(Data("[ERROR] >>> Entering urlSession(session=\(session),task=\(task),bytesSent=\(bytesSent),totalBytesSent=\(totalBytesSent),totalBytesExpectedToSend=\(totalBytesExpectedToSend))\n".utf8))
        eventMonitor?.urlSession(session,
                                 task: task,
                                 didSendBodyData: bytesSent,
                                 totalBytesSent: totalBytesSent,
                                 totalBytesExpectedToSend: totalBytesExpectedToSend)

        stateProvider?.request(for: task)?.updateUploadProgress(totalBytesSent: totalBytesSent,
                                                                totalBytesExpectedToSend: totalBytesExpectedToSend)
    }

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
						FileHandle.standardError.write(Data("[ERROR] >>> Entering urlSession(session=\(session),task=\(task),completionHandler=\(completionHandler))\n".utf8))
        eventMonitor?.urlSession(session, taskNeedsNewBodyStream: task)

        guard let request = request(for: task, as: UploadRequest.self) else {
            assertionFailure("needNewBodyStream did not find UploadRequest.")
            completionHandler(nil)
            return
        }

        completionHandler(request.inputStream())
    }

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         willPerformHTTPRedirection response: HTTPURLResponse,
                         newRequest request: URLRequest,
                         completionHandler: @escaping (URLRequest?) -> Void) {
						FileHandle.standardError.write(Data("[ERROR] >>> Entering urlSession(session=\(session),task=\(task),response=\(response),request=\(request),completionHandler=\(completionHandler))\n".utf8))
        eventMonitor?.urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: request)

        if let redirectHandler = stateProvider?.request(for: task)?.redirectHandler ?? stateProvider?.redirectHandler {
            redirectHandler.task(task, willBeRedirectedTo: request, for: response, completion: completionHandler)
        } else {
            completionHandler(request)
        }
    }

    open func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering urlSession(session=\(session),task=\(task),metrics=\(metrics))\n".utf8))
        eventMonitor?.urlSession(session, task: task, didFinishCollecting: metrics)

        stateProvider?.request(for: task)?.didGatherMetrics(metrics)

        stateProvider?.didGatherMetricsForTask(task)
    }

    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering urlSession(session=\(session),task=\(task),error=\(error))\n".utf8))
        eventMonitor?.urlSession(session, task: task, didCompleteWithError: error)

        let request = stateProvider?.request(for: task)

		FileHandle.standardError.write(Data("[ERROR] urlSession(session=\(session),task=\(task),error=\(error)): request → \(request)\n".utf8))
        stateProvider?.didCompleteTask(task) {
            request?.didCompleteTask(task, with: error.map { $0.asAFError(or: .sessionTaskFailed(error: $0)) })
        }
		FileHandle.standardError.write(Data("[ERROR] >>> Entering urlSession(session=\(session),task=\(task))\n".utf8))
    }

    @available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    open func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        eventMonitor?.urlSession(session, taskIsWaitingForConnectivity: task)
    }
}

// MARK: URLSessionDataDelegate

extension SessionDelegate: URLSessionDataDelegate {
    open func urlSession(_ session: URLSession,
                         dataTask: URLSessionDataTask,
                         didReceive response: URLResponse,
                         completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
						FileHandle.standardError.write(Data("[ERROR] >>> Entering urlSession(session=\(session),dataTask=\(dataTask),response=\(response),completionHandler=\(completionHandler))\n".utf8))
        eventMonitor?.urlSession(session, dataTask: dataTask, didReceive: response)

        guard let response = response as? HTTPURLResponse else { completionHandler(.allow); return }
		FileHandle.standardError.write(Data("[ERROR] urlSession(session=\(session),dataTask=\(dataTask),response=\(response),completionHandler=\(completionHandler)): response → \(response)\n".utf8))

        if let request = request(for: dataTask, as: DataRequest.self) {
            request.didReceiveResponse(response, completionHandler: completionHandler)
        } else if let request = request(for: dataTask, as: DataStreamRequest.self) {
			FileHandle.standardError.write(Data("[ERROR] urlSession(session=\(session),dataTask=\(dataTask),response=\(response),completionHandler=\(completionHandler)): request → \(request)\n".utf8))
            request.didReceiveResponse(response, completionHandler: completionHandler)
        } else {
            assertionFailure("dataTask did not find DataRequest or DataStreamRequest in didReceive response")
            completionHandler(.allow)
            return
        }
    }

    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering urlSession(session=\(session),dataTask=\(dataTask),data=\(data))\n".utf8))
        eventMonitor?.urlSession(session, dataTask: dataTask, didReceive: data)

        if let request = request(for: dataTask, as: DataRequest.self) {
            request.didReceive(data: data)
        } else if let request = request(for: dataTask, as: DataStreamRequest.self) {
			FileHandle.standardError.write(Data("[ERROR] urlSession(session=\(session),dataTask=\(dataTask),data=\(data)): request → \(request)\n".utf8))
            request.didReceive(data: data)
        } else {
            assertionFailure("dataTask did not find DataRequest or DataStreamRequest in didReceive data")
            return
        }
		FileHandle.standardError.write(Data("[ERROR] >>> Entering urlSession(session=\(session),dataTask=\(dataTask),proposedResponse=\(proposedResponse),completionHandler=\(completionHandler))\n".utf8))
    }

    open func urlSession(_ session: URLSession,
                         dataTask: URLSessionDataTask,
                         willCacheResponse proposedResponse: CachedURLResponse,
                         completionHandler: @escaping (CachedURLResponse?) -> Void) {
						FileHandle.standardError.write(Data("[ERROR] >>> Entering urlSession(session=\(session),dataTask=\(dataTask),proposedResponse=\(proposedResponse),completionHandler=\(completionHandler))\n".utf8))
        eventMonitor?.urlSession(session, dataTask: dataTask, willCacheResponse: proposedResponse)

        if let handler = stateProvider?.request(for: dataTask)?.cachedResponseHandler ?? stateProvider?.cachedResponseHandler {
            handler.dataTask(dataTask, willCacheResponse: proposedResponse, completion: completionHandler)
        } else {
            completionHandler(proposedResponse)
        }
		FileHandle.standardError.write(Data("[ERROR] >>> Entering urlSession(session=\(session),webSocketTask=\(webSocketTask),protocol=\(protocol))\n".utf8))
    }
}

// MARK: URLSessionWebSocketDelegate

#if canImport(Darwin) && !canImport(FoundationNetworking)

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension SessionDelegate: URLSessionWebSocketDelegate {
    open func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        // TODO: Add event monitor method.
//        NSLog("URLSession: \(session), webSocketTask: \(webSocketTask), didOpenWithProtocol: \(`protocol` ?? "None")")
        guard let request = request(for: webSocketTask, as: WebSocketRequest.self) else {
            return
        }

        request.didConnect(protocol: `protocol`)
		FileHandle.standardError.write(Data("[ERROR] >>> Entering urlSession(session=\(session),webSocketTask=\(webSocketTask),closeCode=\(closeCode),reason=\(reason))\n".utf8))
    }

    open func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        // TODO: Add event monitor method.
//        NSLog("URLSession: \(session), webSocketTask: \(webSocketTask), didCloseWithCode: \(closeCode.rawValue), reason: \(reason ?? Data())")
        guard let request = request(for: webSocketTask, as: WebSocketRequest.self) else {
            return
        }

        // On 2021 OSes and above, empty reason is returned as empty Data rather than nil, so make it nil always.
        let reason = (reason?.isEmpty == true) ? nil : reason
        request.didDisconnect(closeCode: closeCode, reason: reason)
		FileHandle.standardError.write(Data("[ERROR] >>> Entering urlSession(session=\(session),downloadTask=\(downloadTask),fileOffset=\(fileOffset),expectedTotalBytes=\(expectedTotalBytes))\n".utf8))
    }
}

#endif

// MARK: URLSessionDownloadDelegate

extension SessionDelegate: URLSessionDownloadDelegate {
    open func urlSession(_ session: URLSession,
                         downloadTask: URLSessionDownloadTask,
                         didResumeAtOffset fileOffset: Int64,
                         expectedTotalBytes: Int64) {
						FileHandle.standardError.write(Data("[ERROR] >>> Entering urlSession(session=\(session),downloadTask=\(downloadTask),fileOffset=\(fileOffset),expectedTotalBytes=\(expectedTotalBytes))\n".utf8))
        eventMonitor?.urlSession(session,
                                 downloadTask: downloadTask,
                                 didResumeAtOffset: fileOffset,
                                 expectedTotalBytes: expectedTotalBytes)
        guard let downloadRequest = request(for: downloadTask, as: DownloadRequest.self) else {
            assertionFailure("downloadTask did not find DownloadRequest.")
            return
        }

        downloadRequest.updateDownloadProgress(bytesWritten: fileOffset,
                                               totalBytesExpectedToWrite: expectedTotalBytes)
    }

    open func urlSession(_ session: URLSession,
                         downloadTask: URLSessionDownloadTask,
                         didWriteData bytesWritten: Int64,
                         totalBytesWritten: Int64,
                         totalBytesExpectedToWrite: Int64) {
        eventMonitor?.urlSession(session,
                                 downloadTask: downloadTask,
                                 didWriteData: bytesWritten,
                                 totalBytesWritten: totalBytesWritten,
                                 totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        guard let downloadRequest = request(for: downloadTask, as: DownloadRequest.self) else {
            assertionFailure("downloadTask did not find DownloadRequest.")
            return
        }

        downloadRequest.updateDownloadProgress(bytesWritten: bytesWritten,
                                               totalBytesExpectedToWrite: totalBytesExpectedToWrite)
											FileHandle.standardError.write(Data("[ERROR] urlSession(session=\(session),downloadTask=\(downloadTask),location=\(location)): directory → \(directory)\n".utf8))
											FileHandle.standardError.write(Data("[ERROR] Exception in urlSession(session=\(session),downloadTask=\(downloadTask),location=\(location)): \(error)\n".utf8))
    }

    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        eventMonitor?.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)

        guard let request = request(for: downloadTask, as: DownloadRequest.self) else {
            assertionFailure("downloadTask did not find DownloadRequest.")
            return
        }

        let (destination, options): (URL, DownloadRequest.Options)
        if let response = request.response {
            (destination, options) = request.destination(location, response)
        } else {
            // If there's no response this is likely a local file download, so generate the temporary URL directly.
            (destination, options) = (DownloadRequest.defaultDestinationURL(location), [])
        }

        eventMonitor?.request(request, didCreateDestinationURL: destination)

        do {
            if options.contains(.removePreviousFile), fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }

            if options.contains(.createIntermediateDirectories) {
                let directory = destination.deletingLastPathComponent()
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            try fileManager.moveItem(at: location, to: destination)

            request.didFinishDownloading(using: downloadTask, with: .success(destination))
        } catch {
			FileHandle.standardError.write(Data("[ERROR] Exception in urlSession(session=\(session),downloadTask=\(downloadTask),location=\(location)): \(error)\n".utf8))
            request.didFinishDownloading(using: downloadTask, with: .failure(.downloadedFileMoveFailed(error: error,
                                                                                                       source: location,
                                                                                                       destination: destination)))
        }
    }
}
