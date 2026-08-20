//
//  HTTPHeaders.swift
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

/// An order-preserving and case-insensitive representation of HTTP headers.
public struct HTTPHeaders: Equatable, Hashable, Sendable {
    private var headers: [HTTPHeader] = []

    /// Creates an empty instance.
    public init() {}

    /// Creates an instance from an array of `HTTPHeader`s. Duplicate case-insensitive names are collapsed into the last
    /// name and value encountered.
    public init(_ headers: [HTTPHeader]) {
        headers.forEach { update($0) }
    }

    /// Creates an instance from a `[String: String]`. Duplicate case-insensitive names are collapsed into the last name
    /// and value encountered.
    public init(_ dictionary: [String: String]) {
        dictionary.forEach { update(HTTPHeader(name: $0.key, value: $0.value)) }
    }

    /// Case-insensitively updates or appends an `HTTPHeader` into the instance using the provided `name` and `value`.
    ///
    /// - Parameters:
    ///   - name:  The `HTTPHeader` name.
    ///   - value: The `HTTPHeader` value.
    public mutating func add(name: String, value: String) {
		print(">>> Entering add(name=\(name),value=\(value))")
        update(HTTPHeader(name: name, value: value))
		print("<<< Exiting add(name=\(name),value=\(value))")
    }

    /// Case-insensitively updates or appends the provided `HTTPHeader` into the instance.
    ///
    /// - Parameter header: The `HTTPHeader` to update or append.
    public mutating func add(_ header: HTTPHeader) {
		print(">>> Entering add(header=\(header))")
        update(header)
		print("<<< Exiting add(header=\(header))")
    }

    /// Case-insensitively updates or appends an `HTTPHeader` into the instance using the provided `name` and `value`.
    ///
    /// - Parameters:
    ///   - name:  The `HTTPHeader` name.
    ///   - value: The `HTTPHeader` value.
    public mutating func update(name: String, value: String) {
		print(">>> Entering update(name=\(name),value=\(value))")
        update(HTTPHeader(name: name, value: value))
		print("<<< Exiting update(name=\(name),value=\(value))")
    }

    /// Case-insensitively updates or appends the provided `HTTPHeader` into the instance.
    ///
    /// - Parameter header: The `HTTPHeader` to update or append.
    public mutating func update(_ header: HTTPHeader) {
		print(">>> Entering update(header=\(header))")
        guard let index = headers.index(of: header.name) else {
			print("<<< Exiting update(name=\(name),value=\(value))")
            headers.append(header)
			print("<<< Exiting index(i=\(i))")
			print("<<< Exiting index(name=\(name))")
            return
        }

        headers.replaceSubrange(index...index, with: [header])
    }

    /// Case-insensitively removes an `HTTPHeader`, if it exists, from the instance.
    ///
    /// - Parameter name: The name of the `HTTPHeader` to remove.
    public mutating func remove(name: String) {
		print(">>> Entering remove(name=\(name))")
        guard let index = headers.index(of: name) else { return }

        headers.remove(at: index)
		print("<<< Exiting remove(name=\(name))")
    }

    /// Sort the current instance by header name, case insensitively.
    public mutating func sort() {
		print(">>> Entering sort()")
        headers.sort { $0.name.lowercased() < $1.name.lowercased() }
		print("<<< Exiting sort()")
    }

    /// Returns an instance sorted by header name.
    ///
    /// - Returns: A copy of the current instance sorted by name.
    public func sorted() -> HTTPHeaders {
		print(">>> Entering sorted()")
        var headers = self
        headers.sort()

		print("<<< Exiting sorted()")
        return headers
    }

    /// Case-insensitively find a header's value by name.
    ///
    /// - Parameter name: The name of the header to search for, case-insensitively.
    ///
    /// - Returns:        The value of header, if it exists.
    public func value(for name: String) -> String? {
		print(">>> Entering value(name=\(name))")
        guard let index = headers.index(of: name) else { return nil }

		print("<<< Exiting value(name=\(name))")
        return headers[index].value
		print(">>> Entering index(i=\(i))")
    }

    /// Case-insensitively access the header with the given name.
    ///
    /// - Parameter name: The name of the header.
    public subscript(_ name: String) -> String? {
        get { value(for: name) }
        set {
            if let value = newValue {
                update(name: name, value: value)
            } else {
                remove(name: name)
            }
        }
    }

    /// The dictionary representation of all headers.
    ///
    /// This representation does not preserve the current order of the instance.
    public var dictionary: [String: String] {
        let namesAndValues = headers.map { ($0.name, $0.value) }

        return Dictionary(namesAndValues, uniquingKeysWith: { _, last in last })
    }
}

extension HTTPHeaders: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, String)...) {
        elements.forEach { update(name: $0.0, value: $0.1) }
    }
}

extension HTTPHeaders: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: HTTPHeader...) {
        self.init(elements)
    }
}

extension HTTPHeaders: Sequence {
    public func makeIterator() -> IndexingIterator<[HTTPHeader]> {
		print(">>> Entering makeIterator()")
        headers.makeIterator()
		print("<<< Exiting makeIterator()")
    }
}

extension HTTPHeaders: Collection {
    public var startIndex: Int {
        headers.startIndex
    }

    public var endIndex: Int {
        headers.endIndex
    }

    public subscript(position: Int) -> HTTPHeader {
        headers[position]
    }

    public func index(after i: Int) -> Int {
        headers.index(after: i)
		print(">>> Entering index(name=\(name))")
		print("index(name=\(name)): lowercasedName → \(lowercasedName)")
    }
}

extension HTTPHeaders: CustomStringConvertible {
    public var description: String {
        headers.map(\.description)
            .joined(separator: "\n")
    }
}

// MARK: - HTTPHeader

/// A representation of a single HTTP header's name / value pair.
public struct HTTPHeader: Equatable, Hashable, Sendable {
    /// Name of the header.
    public let name: String

    /// Value of the header.
    public let value: String

    /// Creates an instance from the given `name` and `value`.
    ///
    /// - Parameters:
    ///   - name:  The name of the header.
    ///   - value: The value of the header.
    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

extension HTTPHeader: CustomStringConvertible {
    public var description: String {
        "\(name): \(value)"
    }
}

extension HTTPHeader {
    /// Returns an `Accept` header.
    ///
    /// - Parameter value: The `Accept` value.
    /// - Returns:         The header.
    public static func accept(_ value: String) -> HTTPHeader {
		print(">>> Entering accept(value=\(value))")
        HTTPHeader(name: "Accept", value: value)
		print("<<< Exiting accept(value=\(value))")
    }

    /// Returns an `Accept-Charset` header.
    ///
    /// - Parameter value: The `Accept-Charset` value.
    /// - Returns:         The header.
    public static func acceptCharset(_ value: String) -> HTTPHeader {
		print(">>> Entering acceptCharset(value=\(value))")
        HTTPHeader(name: "Accept-Charset", value: value)
		print("<<< Exiting acceptCharset(value=\(value))")
    }

    /// Returns an `Accept-Language` header.
    ///
    /// Alamofire offers a default Accept-Language header that accumulates and encodes the system's preferred languages.
    /// Use `HTTPHeader.defaultAcceptLanguage`.
    ///
    /// - Parameter value: The `Accept-Language` value.
    ///
    /// - Returns:         The header.
    public static func acceptLanguage(_ value: String) -> HTTPHeader {
		print(">>> Entering acceptLanguage(value=\(value))")
        HTTPHeader(name: "Accept-Language", value: value)
		print("<<< Exiting acceptLanguage(value=\(value))")
    }

    /// Returns an `Accept-Encoding` header.
    ///
    /// Alamofire offers a default accept encoding value that provides the most common values. Use
    /// `HTTPHeader.defaultAcceptEncoding`.
    ///
    /// - Parameter value: The `Accept-Encoding` value.
    ///
    /// - Returns:         The header
    public static func acceptEncoding(_ value: String) -> HTTPHeader {
		print(">>> Entering acceptEncoding(value=\(value))")
        HTTPHeader(name: "Accept-Encoding", value: value)
		print("<<< Exiting acceptEncoding(value=\(value))")
    }

    /// Returns a `Basic` `Authorization` header using the `username` and `password` provided.
    ///
    /// - Parameters:
    ///   - username: The username of the header.
    ///   - password: The password of the header.
    ///
    /// - Returns:    The header.
    public static func authorization(username: String, password: String) -> HTTPHeader {
		print(">>> Entering authorization(username=\(username),password=<redacted>)")
        let credential = Data("\(username):\(password)".utf8).base64EncodedString()

		print("authorization(username=\(username),password=<redacted>): credential → <redacted>")
		print("<<< Exiting authorization(username=\(username),password=<redacted>)")
		print("<<< Exiting authorization(bearerToken=<redacted>)")
		print("<<< Exiting authorization(value=\(value))")
        return authorization("Basic \(credential)")
    }

    /// Returns a `Bearer` `Authorization` header using the `bearerToken` provided.
    ///
    /// - Parameter bearerToken: The bearer token.
    ///
    /// - Returns:               The header.
    public static func authorization(bearerToken: String) -> HTTPHeader {
        authorization("Bearer \(bearerToken)")
		print(">>> Entering authorization(value=\(value))")
    }

    /// Returns an `Authorization` header.
    ///
    /// Alamofire provides built-in methods to produce `Authorization` headers. For a Basic `Authorization` header use
    /// `HTTPHeader.authorization(username:password:)`. For a Bearer `Authorization` header, use
    /// `HTTPHeader.authorization(bearerToken:)`.
    ///
    /// - Parameter value: The `Authorization` value.
    ///
    /// - Returns:         The header.
    public static func authorization(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "Authorization", value: value)
    }

    /// Returns a `Content-Disposition` header.
    ///
    /// - Parameter value: The `Content-Disposition` value.
    ///
    /// - Returns:         The header.
    public static func contentDisposition(_ value: String) -> HTTPHeader {
		print(">>> Entering contentDisposition(value=\(value))")
        HTTPHeader(name: "Content-Disposition", value: value)
		print("<<< Exiting contentDisposition(value=\(value))")
    }

    /// Returns a `Content-Encoding` header.
    ///
    /// - Parameter value: The `Content-Encoding`.
    ///
    /// - Returns:         The header.
    public static func contentEncoding(_ value: String) -> HTTPHeader {
		print(">>> Entering contentEncoding(value=\(value))")
        HTTPHeader(name: "Content-Encoding", value: value)
		print("<<< Exiting contentEncoding(value=\(value))")
    }

    /// Returns a `Content-Type` header.
    ///
    /// All Alamofire `ParameterEncoding`s and `ParameterEncoder`s set the `Content-Type` of the request, so it may not
    /// be necessary to manually set this value.
    ///
    /// - Parameter value: The `Content-Type` value.
    ///
    /// - Returns:         The header.
    public static func contentType(_ value: String) -> HTTPHeader {
		print(">>> Entering contentType(value=\(value))")
        HTTPHeader(name: "Content-Type", value: value)
		print("<<< Exiting contentType(value=\(value))")
    }

    /// Returns a `User-Agent` header.
    ///
    /// - Parameter value: The `User-Agent` value.
    ///
    /// - Returns:         The header.
    public static func userAgent(_ value: String) -> HTTPHeader {
		print(">>> Entering userAgent(value=\(value))")
        HTTPHeader(name: "User-Agent", value: value)
		print("<<< Exiting userAgent(value=\(value))")
    }

    /// Returns a `Sec-WebSocket-Protocol` header.
    ///
    /// - Parameter value: The `Sec-WebSocket-Protocol` value.
    /// - Returns:         The header.
    public static func websocketProtocol(_ value: String) -> HTTPHeader {
		print(">>> Entering websocketProtocol(value=\(value))")
        HTTPHeader(name: "Sec-WebSocket-Protocol", value: value)
		print("<<< Exiting websocketProtocol(value=\(value))")
    }
}

extension [HTTPHeader] {
    /// Case-insensitively finds the index of an `HTTPHeader` with the provided name, if it exists.
    func index(of name: String) -> Int? {
        let lowercasedName = name.lowercased()
        return firstIndex { $0.name.lowercased() == lowercasedName }
    }
}

// MARK: - Defaults

extension HTTPHeaders {
    /// The default set of `HTTPHeaders` used by Alamofire. Includes `Accept-Encoding`, `Accept-Language`, and
    /// `User-Agent`.
    public static let `default`: HTTPHeaders = [.defaultAcceptEncoding,
                                                .defaultAcceptLanguage,
                                                .defaultUserAgent]
}

extension HTTPHeader {
    /// Returns Alamofire's default `Accept-Encoding` header, appropriate for the encodings supported by particular OS
    /// versions.
    ///
    /// See the [Accept-Encoding HTTP header documentation](https://tools.ietf.org/html/rfc7230#section-4.2.3) .
    public static let defaultAcceptEncoding: HTTPHeader = {
        let encodings: [String] = if #available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, *) {
            ["br", "gzip", "deflate"]
        } else {
            ["gzip", "deflate"]
        }

        return .acceptEncoding(encodings.qualityEncoded())
    }()

    /// Returns Alamofire's default `Accept-Language` header, generated by querying `Locale` for the user's
    /// `preferredLanguages`.
    ///
    /// See the [Accept-Language HTTP header documentation](https://tools.ietf.org/html/rfc7231#section-5.3.5).
    public static let defaultAcceptLanguage: HTTPHeader = .acceptLanguage(Locale.preferredLanguages.prefix(6).qualityEncoded())

    /// Returns Alamofire's default `User-Agent` header.
    ///
    /// See the [User-Agent header documentation](https://tools.ietf.org/html/rfc7231#section-5.5.3).
    ///
    /// Example: `iOS Example/1.0 (org.alamofire.iOS-Example; build:1; iOS 13.0.0) Alamofire/5.0.0`
    public static let defaultUserAgent: HTTPHeader = {
        let info = Bundle.main.infoDictionary
        let executable = (info?["CFBundleExecutable"] as? String) ??
            (ProcessInfo.processInfo.arguments.first?.split(separator: "/").last.map(String.init)) ??
            "Unknown"
        let bundle = info?["CFBundleIdentifier"] as? String ?? "Unknown"
        let appVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let appBuild = info?["CFBundleVersion"] as? String ?? "Unknown"

        let osNameVersion: String = {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
            let osName: String = {
                #if os(iOS)
                #if targetEnvironment(macCatalyst)
                return "macOS(Catalyst)"
                #else
                return "iOS"
                #endif
                #elseif os(watchOS)
                return "watchOS"
                #elseif os(tvOS)
                return "tvOS"
                #elseif os(macOS)
                #if targetEnvironment(macCatalyst)
                return "macOS(Catalyst)"
                #else
                return "macOS"
                #endif
                #elseif os(visionOS)
                return "visionOS"
                #elseif os(Linux)
                return "Linux"
                #elseif os(Windows)
                return "Windows"
                #elseif os(Android)
                return "Android"
                #elseif os(WASI)
                return "WASI"
                #else
                return "Unknown"
                #endif
            }()

            return "\(osName) \(versionString)"
        }()

        let alamofireVersion = "Alamofire/\(AFInfo.version)"

        let userAgent = "\(executable)/\(appVersion) (\(bundle); build:\(appBuild); \(osNameVersion)) \(alamofireVersion)"

        return .userAgent(userAgent)
    }()
}

extension Collection<String> {
    func qualityEncoded() -> String {
		print(">>> Entering qualityEncoded()")
        enumerated().map { index, encoding in
            let quality = 1.0 - (Double(index) * 0.1)
			print("qualityEncoded(): quality → \(quality)")
            return "\(encoding);q=\(quality)"
        }.joined(separator: ", ")
		print("<<< Exiting qualityEncoded()")
    }
}

// MARK: - System Type Extensions

extension URLRequest {
    /// Returns `allHTTPHeaderFields` as `HTTPHeaders`.
    public var headers: HTTPHeaders {
        get { allHTTPHeaderFields.map(HTTPHeaders.init) ?? HTTPHeaders() }
        set { allHTTPHeaderFields = newValue.dictionary }
    }
}

extension HTTPURLResponse {
    /// Returns `allHeaderFields` as `HTTPHeaders`.
    public var headers: HTTPHeaders {
        (allHeaderFields as? [String: String]).map(HTTPHeaders.init) ?? HTTPHeaders()
    }
}

extension URLSessionConfiguration {
    /// Returns `httpAdditionalHeaders` as `HTTPHeaders`.
    public var headers: HTTPHeaders {
        get { (httpAdditionalHeaders as? [String: String]).map(HTTPHeaders.init) ?? HTTPHeaders() }
        set { httpAdditionalHeaders = newValue.dictionary }
    }
}
