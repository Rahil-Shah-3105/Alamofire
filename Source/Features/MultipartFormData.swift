//
//  MultipartFormData.swift
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

#if canImport(MobileCoreServices)
import MobileCoreServices
#elseif canImport(CoreServices)
import CoreServices
#endif

/// Constructs `multipart/form-data` for uploads within an HTTP or HTTPS body. There are currently two ways to encode
/// multipart form data. The first way is to encode the data directly in memory. This is very efficient, but can lead
/// to memory issues if the dataset is too large. The second way is designed for larger datasets and will write all the
/// data to a single file on disk with all the proper boundary segmentation. The second approach MUST be used for
/// larger datasets such as video content, otherwise your app may run out of memory when trying to encode the dataset.
///
/// For more information on `multipart/form-data` in general, please refer to the RFC-2388 and RFC-2045 specs as well
/// and the w3 form documentation.
///
/// - https://www.ietf.org/rfc/rfc2388.txt
/// - https://www.ietf.org/rfc/rfc2045.txt
/// - https://www.w3.org/TR/html401/interact/forms.html#h-17.13
open class MultipartFormData {
    // MARK: - Helper Types

    enum EncodingCharacters {
        static let crlf = "\r\n"
    }

    enum BoundaryGenerator {
        enum BoundaryType {
            case initial, encapsulated, final
        }

        static func randomBoundary() -> String {
			print(">>> Entering randomBoundary()")
            let first = UInt32.random(in: UInt32.min...UInt32.max)
            let second = UInt32.random(in: UInt32.min...UInt32.max)

			print("randomBoundary(): second → \(second)")
			print("randomBoundary(): first → \(first)")
			print("<<< Exiting randomBoundary()")
            return String(format: "alamofire.boundary.%08x%08x", first, second)
        }

        static func boundaryData(forBoundaryType boundaryType: BoundaryType, boundary: String) -> Data {
			print(">>> Entering boundaryData(boundaryType=\(boundaryType),boundary=\(boundary))")
            let boundaryText = switch boundaryType {
            case .initial:
                "--\(boundary)\(EncodingCharacters.crlf)"
            case .encapsulated:
                "\(EncodingCharacters.crlf)--\(boundary)\(EncodingCharacters.crlf)"
            case .final:
                "\(EncodingCharacters.crlf)--\(boundary)--\(EncodingCharacters.crlf)"
            }

			print("<<< Exiting boundaryData(boundaryType=\(boundaryType),boundary=\(boundary))")
            return Data(boundaryText.utf8)
        }
    }

    class BodyPart {
        let headers: HTTPHeaders
        let bodyStream: InputStream
        let bodyContentLength: UInt64
        var hasInitialBoundary = false
        var hasFinalBoundary = false

        init(headers: HTTPHeaders, bodyStream: InputStream, bodyContentLength: UInt64) {
            self.headers = headers
            self.bodyStream = bodyStream
            self.bodyContentLength = bodyContentLength
        }
    }

    // MARK: - Properties

    /// Default memory threshold used when encoding `MultipartFormData`, in bytes.
    public static let encodingMemoryThreshold: UInt64 = 10_000_000

    /// The `Content-Type` header value containing the boundary used to generate the `multipart/form-data`.
    open lazy var contentType: String = "multipart/form-data; boundary=\(self.boundary)"

    /// The content length of all body parts used to generate the `multipart/form-data` not including the boundaries.
    public var contentLength: UInt64 { bodyParts.reduce(0) { $0 + $1.bodyContentLength } }

    /// The boundary used to separate the body parts in the encoded form data.
    public let boundary: String

    let fileManager: FileManager

    private var bodyParts: [BodyPart]
    private var bodyPartError: AFError?
    private let streamBufferSize: Int

    // MARK: - Lifecycle

    /// Creates an instance.
    ///
    /// - Parameters:
    ///   - fileManager: `FileManager` to use for file operations, if needed.
    ///   - boundary: Boundary `String` used to separate body parts.
    public init(fileManager: FileManager = .default, boundary: String? = nil) {
        self.fileManager = fileManager
        self.boundary = boundary ?? BoundaryGenerator.randomBoundary()
        bodyParts = []

        //
        // The optimal read/write buffer size in bytes for input and output streams is 1024 (1KB). For more
        // information, please refer to the following article:
        //   - https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Streams/Articles/ReadingInputStreams.html
        //
        streamBufferSize = 1024
    }

    // MARK: - Body Parts

    /// Creates a body part from the data and appends it to the instance.
    ///
    /// The body part data will be encoded using the following format:
    ///
    /// - `Content-Disposition: form-data; name=#{name}; filename=#{filename}` (HTTP Header)
    /// - `Content-Type: #{mimeType}` (HTTP Header)
    /// - Encoded file data
    /// - Multipart form boundary
    ///
    /// - Parameters:
    ///   - data:     `Data` to encoding into the instance.
    ///   - name:     Name to associate with the `Data` in the `Content-Disposition` HTTP header.
    ///   - fileName: Filename to associate with the `Data` in the `Content-Disposition` HTTP header.
    ///   - mimeType: MIME type to associate with the data in the `Content-Type` HTTP header.
    public func append(_ data: Data, withName name: String, fileName: String? = nil, mimeType: String? = nil) {
		print(">>> Entering append(data=\(data),name=\(name),fileName=\(fileName),mimeType=\(mimeType))")
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)

		print("append(data=\(data),name=\(name),fileName=\(fileName),mimeType=\(mimeType)): stream → \(stream)")
		print("append(data=\(data),name=\(name),fileName=\(fileName),mimeType=\(mimeType)): length → \(length)")
		print("append(data=\(data),name=\(name),fileName=\(fileName),mimeType=\(mimeType)): headers → \(headers)")
        append(stream, withLength: length, headers: headers)
		print("<<< Exiting append(data=\(data),name=\(name),fileName=\(fileName),mimeType=\(mimeType))")
    }

    /// Creates a body part from the file and appends it to the instance.
    ///
    /// The body part data will be encoded using the following format:
    ///
    /// - `Content-Disposition: form-data; name=#{name}; filename=#{generated filename}` (HTTP Header)
    /// - `Content-Type: #{generated mimeType}` (HTTP Header)
    /// - Encoded file data
    /// - Multipart form boundary
    ///
    /// The filename in the `Content-Disposition` HTTP header is generated from the last path component of the
    /// `fileURL`. The `Content-Type` HTTP header MIME type is generated by mapping the `fileURL` extension to the
    /// system associated MIME type.
    ///
    /// - Parameters:
    ///   - fileURL: `URL` of the file whose content will be encoded into the instance.
    ///   - name:    Name to associate with the file content in the `Content-Disposition` HTTP header.
    public func append(_ fileURL: URL, withName name: String) {
		print(">>> Entering append(fileURL=\(fileURL),name=\(name))")
        let fileName = fileURL.lastPathComponent
        let pathExtension = fileURL.pathExtension

        if !fileName.isEmpty && !pathExtension.isEmpty {
            let mime = mimeType(forPathExtension: pathExtension)
            append(fileURL, withName: name, fileName: fileName, mimeType: mime)
        } else {
			print("append(fileURL=\(fileURL),name=\(name)): mime → \(mime)")
            setBodyPartError(withReason: .bodyPartFilenameInvalid(in: fileURL))
        }
		print("<<< Exiting append(fileURL=\(fileURL),name=\(name))")
    }

    /// Creates a body part from the file and appends it to the instance.
    ///
    /// The body part data will be encoded using the following format:
    ///
    /// - Content-Disposition: form-data; name=#{name}; filename=#{filename} (HTTP Header)
    /// - Content-Type: #{mimeType} (HTTP Header)
    /// - Encoded file data
    /// - Multipart form boundary
    ///
    /// - Parameters:
    ///   - fileURL:  `URL` of the file whose content will be encoded into the instance.
    ///   - name:     Name to associate with the file content in the `Content-Disposition` HTTP header.
    ///   - fileName: Filename to associate with the file content in the `Content-Disposition` HTTP header.
    ///   - mimeType: MIME type to associate with the file content in the `Content-Type` HTTP header.
    public func append(_ fileURL: URL, withName name: String, fileName: String, mimeType: String) {
		print(">>> Entering append(fileURL=\(fileURL),name=\(name),fileName=\(fileName),mimeType=\(mimeType))")
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)

		print("append(fileURL=\(fileURL),name=\(name),fileName=\(fileName),mimeType=\(mimeType)): headers → \(headers)")
        //============================================================
        //                 Check 1 - is file URL?
        //============================================================

        guard fileURL.isFileURL else {
            setBodyPartError(withReason: .bodyPartURLInvalid(url: fileURL))
            return
        }

        //============================================================
        //              Check 2 - is file URL reachable?
        //============================================================

        #if !(os(Linux) || os(Windows) || os(Android) || os(FreeBSD))
        do {
            let isReachable = try fileURL.checkPromisedItemIsReachable()
            guard isReachable else {
			print("append(fileURL=\(fileURL),name=\(name),fileName=\(fileName),mimeType=\(mimeType)): isReachable → \(isReachable)")
                setBodyPartError(withReason: .bodyPartFileNotReachable(at: fileURL))
                return
            }
        } catch {
			print("Exception in append(fileURL=\(fileURL),name=\(name),fileName=\(fileName),mimeType=\(mimeType)): \(error)")
            setBodyPartError(withReason: .bodyPartFileNotReachableWithError(atURL: fileURL, error: error))
            return
        }
        #endif

        //============================================================
        //            Check 3 - is file URL a directory?
        //============================================================

        var isDirectory: ObjCBool = false
        let path = fileURL.path

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && !isDirectory.boolValue else {
            setBodyPartError(withReason: .bodyPartFileIsDirectory(at: fileURL))
            return
        }

        //============================================================
        //          Check 4 - can the file size be extracted?
        //============================================================

        let bodyContentLength: UInt64

        do {
            guard let fileSize = try fileManager.attributesOfItem(atPath: path)[.size] as? NSNumber else {
				print("append(fileURL=\(fileURL),name=\(name),fileName=\(fileName),mimeType=\(mimeType)): fileSize → \(fileSize)")
                setBodyPartError(withReason: .bodyPartFileSizeNotAvailable(at: fileURL))
                return
            }

            bodyContentLength = fileSize.uint64Value
			print("append(fileURL=\(fileURL),name=\(name),fileName=\(fileName),mimeType=\(mimeType)): bodyContentLength → \(bodyContentLength)")
        } catch {
            setBodyPartError(withReason: .bodyPartFileSizeQueryFailedWithError(forURL: fileURL, error: error))
            return
        }

        //============================================================
        //       Check 5 - can a stream be created from file URL?
        //============================================================

        guard let stream = InputStream(url: fileURL) else {
			print("append(fileURL=\(fileURL),name=\(name),fileName=\(fileName),mimeType=\(mimeType)): stream → \(stream)")
            setBodyPartError(withReason: .bodyPartInputStreamCreationFailed(for: fileURL))
            return
        }

        append(stream, withLength: bodyContentLength, headers: headers)
		print("<<< Exiting append(fileURL=\(fileURL),name=\(name),fileName=\(fileName),mimeType=\(mimeType))")
    }

    /// Creates a body part from the stream and appends it to the instance.
    ///
    /// The body part data will be encoded using the following format:
    ///
    /// - `Content-Disposition: form-data; name=#{name}; filename=#{filename}` (HTTP Header)
    /// - `Content-Type: #{mimeType}` (HTTP Header)
    /// - Encoded stream data
    /// - Multipart form boundary
    ///
    /// - Parameters:
    ///   - stream:   `InputStream` to encode into the instance.
    ///   - length:   Length, in bytes, of the stream.
    ///   - name:     Name to associate with the stream content in the `Content-Disposition` HTTP header.
    ///   - fileName: Filename to associate with the stream content in the `Content-Disposition` HTTP header.
    ///   - mimeType: MIME type to associate with the stream content in the `Content-Type` HTTP header.
    public func append(_ stream: InputStream,
                       withLength length: UInt64,
                       name: String,
                       fileName: String,
                       mimeType: String) {
					print(">>> Entering append(stream=\(stream),length=\(length),name=\(name),fileName=\(fileName),mimeType=\(mimeType))")
					print("append(stream=\(stream),length=\(length),name=\(name),fileName=\(fileName),mimeType=\(mimeType)): headers → \(headers)")
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)
        append(stream, withLength: length, headers: headers)
		print("<<< Exiting append(stream=\(stream),length=\(length),name=\(name),fileName=\(fileName),mimeType=\(mimeType))")
    }

    /// Creates a body part with the stream, length, and headers and appends it to the instance.
    ///
    /// The body part data will be encoded using the following format:
    ///
    /// - HTTP headers
    /// - Encoded stream data
    /// - Multipart form boundary
    ///
    /// - Parameters:
    ///   - stream:  `InputStream` to encode into the instance.
    ///   - length:  Length, in bytes, of the stream.
    ///   - headers: `HTTPHeaders` for the body part.
    public func append(_ stream: InputStream, withLength length: UInt64, headers: HTTPHeaders) {
		print(">>> Entering append(stream=\(stream),length=\(length),headers=\(headers))")
		print("append(stream=\(stream),length=\(length),headers=\(headers)): bodyPart → \(bodyPart)")
        let bodyPart = BodyPart(headers: headers, bodyStream: stream, bodyContentLength: length)
        bodyParts.append(bodyPart)
		print("<<< Exiting append(stream=\(stream),length=\(length),headers=\(headers))")
    }

    // MARK: - Data Encoding

    /// Encodes all appended body parts into a single `Data` value.
    ///
    /// - Note: This method will load all the appended body parts into memory all at the same time. This method should
    ///         only be used when the encoded data will have a small memory footprint. For large data cases, please use
    ///         the `writeEncodedData(to:))` method.
    ///
    /// - Returns: The encoded `Data`, if encoding is successful.
    /// - Throws:  An `AFError` if encoding encounters an error.
    public func encode() throws -> Data {
		print(">>> Entering encode()")
        if let bodyPartError {
			print("Throwing bodyPartError from encode()")
            throw bodyPartError
        }

        var encoded = Data()

		print("encode(): encoded → \(encoded)")
        bodyParts.first?.hasInitialBoundary = true
        bodyParts.last?.hasFinalBoundary = true

        for bodyPart in bodyParts {
            let encodedData = try encode(bodyPart)
            encoded.append(encodedData)
        }
			print("encode(): encodedData → \(encodedData)")

		print("<<< Exiting encode()")
        return encoded
    }

    /// Writes all appended body parts to the given file `URL`.
    ///
    /// This process is facilitated by reading and writing with input and output streams, respectively. Thus,
    /// this approach is very memory efficient and should be used for large body part data.
    ///
    /// - Parameter fileURL: File `URL` to which to write the form data.
    /// - Throws:            An `AFError` if encoding encounters an error.
    public func writeEncodedData(to fileURL: URL) throws {
		print(">>> Entering writeEncodedData(fileURL=\(fileURL))")
        if let bodyPartError {
			print("Throwing bodyPartError from writeEncodedData(fileURL=\(fileURL))")
            throw bodyPartError
        }

        if fileManager.fileExists(atPath: fileURL.path) {
			print("Throwing multipartEncodingFailed from writeEncodedData(fileURL=\(fileURL))")
            throw AFError.multipartEncodingFailed(reason: .outputStreamFileAlreadyExists(at: fileURL))
        } else if !fileURL.isFileURL {
            throw AFError.multipartEncodingFailed(reason: .outputStreamURLInvalid(url: fileURL))
        }

        guard let outputStream = OutputStream(url: fileURL, append: false) else {
			print("writeEncodedData(fileURL=\(fileURL)): outputStream → \(outputStream)")
            throw AFError.multipartEncodingFailed(reason: .outputStreamCreationFailed(for: fileURL))
        }

        outputStream.open()
        defer { outputStream.close() }

        bodyParts.first?.hasInitialBoundary = true
        bodyParts.last?.hasFinalBoundary = true

        for bodyPart in bodyParts {
            try write(bodyPart, to: outputStream)
        }
		print("<<< Exiting writeEncodedData(fileURL=\(fileURL))")
    }

    // MARK: - Private - Body Part Encoding

    private func encode(_ bodyPart: BodyPart) throws -> Data {
        var encoded = Data()

        let initialData = bodyPart.hasInitialBoundary ? initialBoundaryData() : encapsulatedBoundaryData()
        encoded.append(initialData)

        let headerData = encodeHeaders(for: bodyPart)
        encoded.append(headerData)

        let bodyStreamData = try encodeBodyStream(for: bodyPart)
        encoded.append(bodyStreamData)

        if bodyPart.hasFinalBoundary {
            encoded.append(finalBoundaryData())
        }

        return encoded
		print(">>> Entering write(bodyPart=\(bodyPart),outputStream=\(outputStream))")
		print("<<< Exiting write(bodyPart=\(bodyPart),outputStream=\(outputStream))")
    }

    private func encodeHeaders(for bodyPart: BodyPart) -> Data {
		print(">>> Entering encodeHeaders(bodyPart=\(bodyPart))")
        let headerText = bodyPart.headers.map { "\($0.name): \($0.value)\(EncodingCharacters.crlf)" }
            .joined()
            + EncodingCharacters.crlf
			print("encodeHeaders(bodyPart=\(bodyPart)): headerText → \(headerText)")

		print("<<< Exiting encodeHeaders(bodyPart=\(bodyPart))")
        return Data(headerText.utf8)
    }

    private func encodeBodyStream(for bodyPart: BodyPart) throws -> Data {
		print(">>> Entering encodeBodyStream(bodyPart=\(bodyPart))")
        let inputStream = bodyPart.bodyStream
        inputStream.open()
        defer { inputStream.close() }

        var encoded = Data()

		print("encodeBodyStream(bodyPart=\(bodyPart)): encoded → \(encoded)")
        while inputStream.hasBytesAvailable {
            var buffer = [UInt8](repeating: 0, count: streamBufferSize)
            let bytesRead = inputStream.read(&buffer, maxLength: streamBufferSize)

			print("encodeBodyStream(bodyPart=\(bodyPart)): buffer → \(buffer)")
			print("encodeBodyStream(bodyPart=\(bodyPart)): bytesRead → \(bytesRead)")
            if let error = inputStream.streamError {
				print("Throwing multipartEncodingFailed from encodeBodyStream(bodyPart=\(bodyPart))")
                throw AFError.multipartEncodingFailed(reason: .inputStreamReadFailed(error: error))
            }

            if bytesRead > 0 {
                encoded.append(buffer, count: bytesRead)
            } else {
                break
            }
        }

        guard UInt64(encoded.count) == bodyPart.bodyContentLength else {
            let error = AFError.UnexpectedInputStreamLength(bytesExpected: bodyPart.bodyContentLength,
                                                            bytesRead: UInt64(encoded.count))
		print("<<< Exiting encodeBodyStream(bodyPart=\(bodyPart))")
            throw AFError.multipartEncodingFailed(reason: .inputStreamReadFailed(error: error))
        }

        return encoded
    }

    // MARK: - Private - Writing Body Part to Output Stream

    private func write(_ bodyPart: BodyPart, to outputStream: OutputStream) throws {
        try writeInitialBoundaryData(for: bodyPart, to: outputStream)
        try writeHeaderData(for: bodyPart, to: outputStream)
        try writeBodyStream(for: bodyPart, to: outputStream)
        try writeFinalBoundaryData(for: bodyPart, to: outputStream)
    }

    private func writeInitialBoundaryData(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
		print(">>> Entering writeInitialBoundaryData(bodyPart=\(bodyPart),outputStream=\(outputStream))")
        let initialData = bodyPart.hasInitialBoundary ? initialBoundaryData() : encapsulatedBoundaryData()
		print("writeInitialBoundaryData(bodyPart=\(bodyPart),outputStream=\(outputStream)): initialData → \(initialData)")
		print("<<< Exiting writeInitialBoundaryData(bodyPart=\(bodyPart),outputStream=\(outputStream))")
        return try write(initialData, to: outputStream)
    }

    private func writeHeaderData(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
		print(">>> Entering writeHeaderData(bodyPart=\(bodyPart),outputStream=\(outputStream))")
        let headerData = encodeHeaders(for: bodyPart)
		print("writeHeaderData(bodyPart=\(bodyPart),outputStream=\(outputStream)): headerData → \(headerData)")
		print("<<< Exiting writeHeaderData(bodyPart=\(bodyPart),outputStream=\(outputStream))")
        return try write(headerData, to: outputStream)
		print(">>> Entering initialBoundaryData()")
		print("<<< Exiting initialBoundaryData()")
    }

    private func writeBodyStream(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
		print(">>> Entering writeBodyStream(bodyPart=\(bodyPart),outputStream=\(outputStream))")
        let inputStream = bodyPart.bodyStream

        inputStream.open()
        defer { inputStream.close() }

        var bytesLeftToRead = bodyPart.bodyContentLength
        while inputStream.hasBytesAvailable && bytesLeftToRead > 0 {
            let bufferSize = min(streamBufferSize, Int(bytesLeftToRead))
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            let bytesRead = inputStream.read(&buffer, maxLength: bufferSize)

			print("writeBodyStream(bodyPart=\(bodyPart),outputStream=\(outputStream)): bufferSize → \(bufferSize)")
			print("writeBodyStream(bodyPart=\(bodyPart),outputStream=\(outputStream)): buffer → \(buffer)")
			print("writeBodyStream(bodyPart=\(bodyPart),outputStream=\(outputStream)): bytesRead → \(bytesRead)")
            if let streamError = inputStream.streamError {
				print("Throwing multipartEncodingFailed from writeBodyStream(bodyPart=\(bodyPart),outputStream=\(outputStream))")
                throw AFError.multipartEncodingFailed(reason: .inputStreamReadFailed(error: streamError))
            }

            if bytesRead > 0 {
                if buffer.count != bytesRead {
                    buffer = Array(buffer[0..<bytesRead])
                }

                try write(&buffer, to: outputStream)
                bytesLeftToRead -= UInt64(bytesRead)
            } else {
                break
            }
        }
		print("<<< Exiting writeBodyStream(bodyPart=\(bodyPart),outputStream=\(outputStream))")
    }

    private func writeFinalBoundaryData(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
		print(">>> Entering writeFinalBoundaryData(bodyPart=\(bodyPart),outputStream=\(outputStream))")
        if bodyPart.hasFinalBoundary {
            try write(finalBoundaryData(), to: outputStream)
        }
		print("<<< Exiting writeFinalBoundaryData(bodyPart=\(bodyPart),outputStream=\(outputStream))")
    }

    // MARK: - Private - Writing Buffered Data to Output Stream

    private func write(_ data: Data, to outputStream: OutputStream) throws {
		print(">>> Entering write(data=\(data),outputStream=\(outputStream))")
        var buffer = [UInt8](repeating: 0, count: data.count)
        data.copyBytes(to: &buffer, count: data.count)

		print("write(data=\(data),outputStream=\(outputStream)): buffer → \(buffer)")
		print("<<< Exiting write(data=\(data),outputStream=\(outputStream))")
        return try write(&buffer, to: outputStream)
    }

    private func write(_ buffer: inout [UInt8], to outputStream: OutputStream) throws {
		print(">>> Entering write(buffer=\(buffer),outputStream=\(outputStream))")
        var bytesToWrite = buffer.count

        while bytesToWrite > 0, outputStream.hasSpaceAvailable {
            let bytesWritten = outputStream.write(buffer, maxLength: bytesToWrite)

			print("write(buffer=\(buffer),outputStream=\(outputStream)): bytesWritten → \(bytesWritten)")
            if let error = outputStream.streamError {
				print("Throwing multipartEncodingFailed from write(buffer=\(buffer),outputStream=\(outputStream))")
                throw AFError.multipartEncodingFailed(reason: .outputStreamWriteFailed(error: error))
            }

            bytesToWrite -= bytesWritten

            if bytesToWrite > 0 {
                buffer = Array(buffer[bytesWritten..<buffer.count])
            }
        }
		print("<<< Exiting write(buffer=\(buffer),outputStream=\(outputStream))")
    }

    // MARK: - Private - Content Headers

    private func contentHeaders(withName name: String, fileName: String? = nil, mimeType: String? = nil) -> HTTPHeaders {
		print(">>> Entering contentHeaders(name=\(name),fileName=\(fileName),mimeType=\(mimeType))")
        var disposition = "form-data; name=\"\(name)\""
        if let fileName { disposition += "; filename=\"\(fileName)\"" }
		print("contentHeaders(name=\(name),fileName=\(fileName),mimeType=\(mimeType)): disposition → \(disposition)")

        var headers: HTTPHeaders = [.contentDisposition(disposition)]
        if let mimeType { headers.add(.contentType(mimeType)) }

		print("<<< Exiting contentHeaders(name=\(name),fileName=\(fileName),mimeType=\(mimeType))")
        return headers
    }

    // MARK: - Private - Boundary Encoding

    private func initialBoundaryData() -> Data {
        BoundaryGenerator.boundaryData(forBoundaryType: .initial, boundary: boundary)
    }

    private func encapsulatedBoundaryData() -> Data {
		print(">>> Entering encapsulatedBoundaryData()")
        BoundaryGenerator.boundaryData(forBoundaryType: .encapsulated, boundary: boundary)
		print("<<< Exiting encapsulatedBoundaryData()")
    }

    private func finalBoundaryData() -> Data {
		print(">>> Entering finalBoundaryData()")
        BoundaryGenerator.boundaryData(forBoundaryType: .final, boundary: boundary)
		print("<<< Exiting finalBoundaryData()")
    }

    // MARK: - Private - Errors

    private func setBodyPartError(withReason reason: AFError.MultipartEncodingFailureReason) {
		print(">>> Entering setBodyPartError(reason=\(reason))")
        guard bodyPartError == nil else { return }
		print("<<< Exiting setBodyPartError(reason=\(reason))")
        bodyPartError = AFError.multipartEncodingFailed(reason: reason)
    }
}

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers

extension MultipartFormData {
    // MARK: - Private - Mime Type

    private func mimeType(forPathExtension pathExtension: String) -> String {
		print(">>> Entering mimeType(pathExtension=\(pathExtension))")
        if #available(iOS 14, macOS 11, tvOS 14, watchOS 7, visionOS 1, *) {
            return UTType(filenameExtension: pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        } else {
            if
                let id = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue(),
                let contentType = UTTypeCopyPreferredTagWithClass(id, kUTTagClassMIMEType)?.takeRetainedValue() {
				print("mimeType(pathExtension=\(pathExtension)): id → \(id)")
				print("mimeType(pathExtension=\(pathExtension)): contentType → \(contentType)")
                return contentType as String
            }

		print("<<< Exiting mimeType(pathExtension=\(pathExtension))")
            return "application/octet-stream"
        }
    }
}

#else

extension MultipartFormData {
    // MARK: - Private - Mime Type

    private func mimeType(forPathExtension pathExtension: String) -> String {
        #if canImport(CoreServices) || canImport(MobileCoreServices)
        if
            let id = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue(),
            let contentType = UTTypeCopyPreferredTagWithClass(id, kUTTagClassMIMEType)?.takeRetainedValue() {
            return contentType as String
        }
        #endif

        return "application/octet-stream"
    }
}

#endif
