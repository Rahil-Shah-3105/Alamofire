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
			FileHandle.standardError.write(Data("[ERROR] >>> Entering randomBoundary()\n".utf8))
            let first = UInt32.random(in: UInt32.min...UInt32.max)
            let second = UInt32.random(in: UInt32.min...UInt32.max)

			FileHandle.standardError.write(Data("[ERROR] randomBoundary(): second → \(second)\n".utf8))
			FileHandle.standardError.write(Data("[ERROR] randomBoundary(): first → \(first)\n".utf8))
			FileHandle.standardError.write(Data("[WARN] <<< Exiting randomBoundary()\n".utf8))
            return String(format: "alamofire.boundary.%08x%08x", first, second)
        }

        static func boundaryData(forBoundaryType boundaryType: BoundaryType, boundary: String) -> Data {
			FileHandle.standardError.write(Data("[ERROR] >>> Entering boundaryData(boundaryType=\(boundaryType),boundary=\(boundary))\n".utf8))
            let boundaryText = switch boundaryType {
            case .initial:
                "--\(boundary)\(EncodingCharacters.crlf)"
            case .encapsulated:
                "\(EncodingCharacters.crlf)--\(boundary)\(EncodingCharacters.crlf)"
            case .final:
                "\(EncodingCharacters.crlf)--\(boundary)--\(EncodingCharacters.crlf)"
            }

			FileHandle.standardError.write(Data("[WARN] <<< Exiting boundaryData(boundaryType=\(boundaryType),boundary=\(boundary))\n".utf8))
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
		FileHandle.standardError.write(Data("[ERROR] >>> Entering append(data=\(data),name=\(name),fileName=\(fileName),mimeType=\(mimeType))\n".utf8))
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)

		FileHandle.standardError.write(Data("[ERROR] append(data=\(data),name=\(name),fileName=\(fileName),mimeType=\(mimeType)): stream → \(stream)\n".utf8))
        append(stream, withLength: length, headers: headers)
		FileHandle.standardError.write(Data("[WARN] <<< Exiting append(data=\(data),name=\(name),fileName=\(fileName),mimeType=\(mimeType))\n".utf8))
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
		FileHandle.standardError.write(Data("[ERROR] >>> Entering append(fileURL=\(fileURL),name=\(name))\n".utf8))
        let fileName = fileURL.lastPathComponent
        let pathExtension = fileURL.pathExtension

        if !fileName.isEmpty && !pathExtension.isEmpty {
            let mime = mimeType(forPathExtension: pathExtension)
            append(fileURL, withName: name, fileName: fileName, mimeType: mime)
        } else {
			FileHandle.standardError.write(Data("[ERROR] append(fileURL=\(fileURL),name=\(name)): mime → \(mime)\n".utf8))
            setBodyPartError(withReason: .bodyPartFilenameInvalid(in: fileURL))
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting append(fileURL=\(fileURL),name=\(name))\n".utf8))
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
		FileHandle.standardError.write(Data("[ERROR] >>> Entering append(fileURL=\(fileURL),name=\(name),fileName=\(fileName),mimeType=\(mimeType))\n".utf8))
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)

		FileHandle.standardError.write(Data("[ERROR] append(fileURL=\(fileURL),name=\(name),fileName=\(fileName),mimeType=\(mimeType)): headers → \(headers)\n".utf8))
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
			FileHandle.standardError.write(Data("[ERROR] append(fileURL=\(fileURL),name=\(name),fileName=\(fileName),mimeType=\(mimeType)): isReachable → \(isReachable)\n".utf8))
                setBodyPartError(withReason: .bodyPartFileNotReachable(at: fileURL))
                return
            }
        } catch {
			FileHandle.standardError.write(Data("[ERROR] Exception in append(fileURL=\(fileURL),name=\(name),fileName=\(fileName),mimeType=\(mimeType)): \(error)\n".utf8))
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
                setBodyPartError(withReason: .bodyPartFileSizeNotAvailable(at: fileURL))
                return
            }

            bodyContentLength = fileSize.uint64Value
			FileHandle.standardError.write(Data("[DEBUG] append(fileURL=\(fileURL),name=\(name),fileName=\(fileName),mimeType=\(mimeType)): bodyContentLength → \(bodyContentLength)\n".utf8))
        } catch {
            setBodyPartError(withReason: .bodyPartFileSizeQueryFailedWithError(forURL: fileURL, error: error))
            return
        }

        //============================================================
        //       Check 5 - can a stream be created from file URL?
        //============================================================

        guard let stream = InputStream(url: fileURL) else {
            setBodyPartError(withReason: .bodyPartInputStreamCreationFailed(for: fileURL))
            return
        }

        append(stream, withLength: bodyContentLength, headers: headers)
		FileHandle.standardError.write(Data("[WARN] <<< Exiting append(fileURL=\(fileURL),name=\(name),fileName=\(fileName),mimeType=\(mimeType))\n".utf8))
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
					FileHandle.standardError.write(Data("[ERROR] >>> Entering append(stream=\(stream),length=\(length),name=\(name),fileName=\(fileName),mimeType=\(mimeType))\n".utf8))
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)
        append(stream, withLength: length, headers: headers)
		FileHandle.standardError.write(Data("[WARN] <<< Exiting append(stream=\(stream),length=\(length),name=\(name),fileName=\(fileName),mimeType=\(mimeType))\n".utf8))
		FileHandle.standardError.write(Data("[ERROR] append(stream=\(stream),length=\(length),name=\(name),fileName=\(fileName),mimeType=\(mimeType)): headers → \(headers)\n".utf8))
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
		FileHandle.standardError.write(Data("[ERROR] >>> Entering append(stream=\(stream),length=\(length),headers=\(headers))\n".utf8))
        let bodyPart = BodyPart(headers: headers, bodyStream: stream, bodyContentLength: length)
        bodyParts.append(bodyPart)
		FileHandle.standardError.write(Data("[WARN] <<< Exiting append(stream=\(stream),length=\(length),headers=\(headers))\n".utf8))
		FileHandle.standardError.write(Data("[ERROR] append(stream=\(stream),length=\(length),headers=\(headers)): bodyPart → \(bodyPart)\n".utf8))
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
		FileHandle.standardError.write(Data("[ERROR] >>> Entering encode()\n".utf8))
        if let bodyPartError {
			FileHandle.standardError.write(Data("[ERROR] Throwing bodyPartError from encode()\n".utf8))
            throw bodyPartError
        }

        var encoded = Data()

		FileHandle.standardError.write(Data("[ERROR] encode(): encoded → \(encoded)\n".utf8))
        bodyParts.first?.hasInitialBoundary = true
        bodyParts.last?.hasFinalBoundary = true

        for bodyPart in bodyParts {
            let encodedData = try encode(bodyPart)
            encoded.append(encodedData)
        }
			FileHandle.standardError.write(Data("[ERROR] encode(): encodedData → \(encodedData)\n".utf8))

		FileHandle.standardError.write(Data("[WARN] <<< Exiting encode()\n".utf8))
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
		FileHandle.standardError.write(Data("[ERROR] >>> Entering writeEncodedData(fileURL=\(fileURL))\n".utf8))
        if let bodyPartError {
			FileHandle.standardError.write(Data("[ERROR] Throwing bodyPartError from writeEncodedData(fileURL=\(fileURL))\n".utf8))
            throw bodyPartError
        }

        if fileManager.fileExists(atPath: fileURL.path) {
			FileHandle.standardError.write(Data("[ERROR] Throwing multipartEncodingFailed from writeEncodedData(fileURL=\(fileURL))\n".utf8))
            throw AFError.multipartEncodingFailed(reason: .outputStreamFileAlreadyExists(at: fileURL))
        } else if !fileURL.isFileURL {
            throw AFError.multipartEncodingFailed(reason: .outputStreamURLInvalid(url: fileURL))
        }

        guard let outputStream = OutputStream(url: fileURL, append: false) else {
            throw AFError.multipartEncodingFailed(reason: .outputStreamCreationFailed(for: fileURL))
        }

        outputStream.open()
        defer { outputStream.close() }

        bodyParts.first?.hasInitialBoundary = true
        bodyParts.last?.hasFinalBoundary = true

        for bodyPart in bodyParts {
            try write(bodyPart, to: outputStream)
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting writeEncodedData(fileURL=\(fileURL))\n".utf8))
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
    }

    private func encodeHeaders(for bodyPart: BodyPart) -> Data {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering encodeHeaders(bodyPart=\(bodyPart))\n".utf8))
        let headerText = bodyPart.headers.map { "\($0.name): \($0.value)\(EncodingCharacters.crlf)" }
            .joined()
            + EncodingCharacters.crlf
			FileHandle.standardError.write(Data("[ERROR] encodeHeaders(bodyPart=\(bodyPart)): headerText → \(headerText)\n".utf8))

		FileHandle.standardError.write(Data("[WARN] <<< Exiting encodeHeaders(bodyPart=\(bodyPart))\n".utf8))
        return Data(headerText.utf8)
    }

    private func encodeBodyStream(for bodyPart: BodyPart) throws -> Data {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering encodeBodyStream(bodyPart=\(bodyPart))\n".utf8))
        let inputStream = bodyPart.bodyStream
        inputStream.open()
        defer { inputStream.close() }

        var encoded = Data()

		FileHandle.standardError.write(Data("[ERROR] encodeBodyStream(bodyPart=\(bodyPart)): encoded → \(encoded)\n".utf8))
        while inputStream.hasBytesAvailable {
            var buffer = [UInt8](repeating: 0, count: streamBufferSize)
            let bytesRead = inputStream.read(&buffer, maxLength: streamBufferSize)

			FileHandle.standardError.write(Data("[ERROR] encodeBodyStream(bodyPart=\(bodyPart)): buffer → \(buffer)\n".utf8))
            if let error = inputStream.streamError {
				FileHandle.standardError.write(Data("[ERROR] Throwing multipartEncodingFailed from encodeBodyStream(bodyPart=\(bodyPart))\n".utf8))
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
            throw AFError.multipartEncodingFailed(reason: .inputStreamReadFailed(error: error))
        }

		FileHandle.standardError.write(Data("[WARN] <<< Exiting encodeBodyStream(bodyPart=\(bodyPart))\n".utf8))
        return encoded
    }

    // MARK: - Private - Writing Body Part to Output Stream

    private func write(_ bodyPart: BodyPart, to outputStream: OutputStream) throws {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering write(bodyPart=\(bodyPart),outputStream=\(outputStream))\n".utf8))
        try writeInitialBoundaryData(for: bodyPart, to: outputStream)
        try writeHeaderData(for: bodyPart, to: outputStream)
        try writeBodyStream(for: bodyPart, to: outputStream)
        try writeFinalBoundaryData(for: bodyPart, to: outputStream)
		FileHandle.standardError.write(Data("[WARN] <<< Exiting write(bodyPart=\(bodyPart),outputStream=\(outputStream))\n".utf8))
    }

    private func writeInitialBoundaryData(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering writeInitialBoundaryData(bodyPart=\(bodyPart),outputStream=\(outputStream))\n".utf8))
        let initialData = bodyPart.hasInitialBoundary ? initialBoundaryData() : encapsulatedBoundaryData()
		FileHandle.standardError.write(Data("[ERROR] writeInitialBoundaryData(bodyPart=\(bodyPart),outputStream=\(outputStream)): initialData → \(initialData)\n".utf8))
		FileHandle.standardError.write(Data("[WARN] <<< Exiting writeInitialBoundaryData(bodyPart=\(bodyPart),outputStream=\(outputStream))\n".utf8))
        return try write(initialData, to: outputStream)
    }

    private func writeHeaderData(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering writeHeaderData(bodyPart=\(bodyPart),outputStream=\(outputStream))\n".utf8))
        let headerData = encodeHeaders(for: bodyPart)
		FileHandle.standardError.write(Data("[ERROR] writeHeaderData(bodyPart=\(bodyPart),outputStream=\(outputStream)): headerData → \(headerData)\n".utf8))
		FileHandle.standardError.write(Data("[WARN] <<< Exiting writeHeaderData(bodyPart=\(bodyPart),outputStream=\(outputStream))\n".utf8))
        return try write(headerData, to: outputStream)
    }

    private func writeBodyStream(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering writeBodyStream(bodyPart=\(bodyPart),outputStream=\(outputStream))\n".utf8))
        let inputStream = bodyPart.bodyStream

        inputStream.open()
        defer { inputStream.close() }

        var bytesLeftToRead = bodyPart.bodyContentLength
        while inputStream.hasBytesAvailable && bytesLeftToRead > 0 {
            let bufferSize = min(streamBufferSize, Int(bytesLeftToRead))
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            let bytesRead = inputStream.read(&buffer, maxLength: bufferSize)

			FileHandle.standardError.write(Data("[ERROR] writeBodyStream(bodyPart=\(bodyPart),outputStream=\(outputStream)): bufferSize → \(bufferSize)\n".utf8))
            if let streamError = inputStream.streamError {
				FileHandle.standardError.write(Data("[ERROR] Throwing multipartEncodingFailed from writeBodyStream(bodyPart=\(bodyPart),outputStream=\(outputStream))\n".utf8))
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
		FileHandle.standardError.write(Data("[WARN] <<< Exiting writeBodyStream(bodyPart=\(bodyPart),outputStream=\(outputStream))\n".utf8))
    }

    private func writeFinalBoundaryData(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering writeFinalBoundaryData(bodyPart=\(bodyPart),outputStream=\(outputStream))\n".utf8))
        if bodyPart.hasFinalBoundary {
            try write(finalBoundaryData(), to: outputStream)
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting writeFinalBoundaryData(bodyPart=\(bodyPart),outputStream=\(outputStream))\n".utf8))
    }

    // MARK: - Private - Writing Buffered Data to Output Stream

    private func write(_ data: Data, to outputStream: OutputStream) throws {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering write(data=\(data),outputStream=\(outputStream))\n".utf8))
        var buffer = [UInt8](repeating: 0, count: data.count)
        data.copyBytes(to: &buffer, count: data.count)

		FileHandle.standardError.write(Data("[ERROR] write(data=\(data),outputStream=\(outputStream)): buffer → \(buffer)\n".utf8))
        return try write(&buffer, to: outputStream)
    }

    private func write(_ buffer: inout [UInt8], to outputStream: OutputStream) throws {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering write(buffer=\(buffer),outputStream=\(outputStream))\n".utf8))
        var bytesToWrite = buffer.count
		FileHandle.standardError.write(Data("[WARN] <<< Exiting write(data=\(data),outputStream=\(outputStream))\n".utf8))

        while bytesToWrite > 0, outputStream.hasSpaceAvailable {
            let bytesWritten = outputStream.write(buffer, maxLength: bytesToWrite)

			FileHandle.standardError.write(Data("[ERROR] write(buffer=\(buffer),outputStream=\(outputStream)): bytesWritten → \(bytesWritten)\n".utf8))
            if let error = outputStream.streamError {
				FileHandle.standardError.write(Data("[ERROR] Throwing multipartEncodingFailed from write(buffer=\(buffer),outputStream=\(outputStream))\n".utf8))
                throw AFError.multipartEncodingFailed(reason: .outputStreamWriteFailed(error: error))
            }

            bytesToWrite -= bytesWritten

            if bytesToWrite > 0 {
                buffer = Array(buffer[bytesWritten..<buffer.count])
            }
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting write(buffer=\(buffer),outputStream=\(outputStream))\n".utf8))
    }

    // MARK: - Private - Content Headers

    private func contentHeaders(withName name: String, fileName: String? = nil, mimeType: String? = nil) -> HTTPHeaders {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering contentHeaders(name=\(name),fileName=\(fileName),mimeType=\(mimeType))\n".utf8))
        var disposition = "form-data; name=\"\(name)\""
        if let fileName { disposition += "; filename=\"\(fileName)\"" }
		FileHandle.standardError.write(Data("[ERROR] contentHeaders(name=\(name),fileName=\(fileName),mimeType=\(mimeType)): disposition → \(disposition)\n".utf8))

        var headers: HTTPHeaders = [.contentDisposition(disposition)]
        if let mimeType { headers.add(.contentType(mimeType)) }

		FileHandle.standardError.write(Data("[WARN] <<< Exiting contentHeaders(name=\(name),fileName=\(fileName),mimeType=\(mimeType))\n".utf8))
        return headers
    }

    // MARK: - Private - Boundary Encoding

    private func initialBoundaryData() -> Data {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering initialBoundaryData()\n".utf8))
        BoundaryGenerator.boundaryData(forBoundaryType: .initial, boundary: boundary)
		FileHandle.standardError.write(Data("[WARN] <<< Exiting initialBoundaryData()\n".utf8))
    }

    private func encapsulatedBoundaryData() -> Data {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering encapsulatedBoundaryData()\n".utf8))
        BoundaryGenerator.boundaryData(forBoundaryType: .encapsulated, boundary: boundary)
		FileHandle.standardError.write(Data("[WARN] <<< Exiting encapsulatedBoundaryData()\n".utf8))
    }

    private func finalBoundaryData() -> Data {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering finalBoundaryData()\n".utf8))
        BoundaryGenerator.boundaryData(forBoundaryType: .final, boundary: boundary)
		FileHandle.standardError.write(Data("[WARN] <<< Exiting finalBoundaryData()\n".utf8))
    }

    // MARK: - Private - Errors

    private func setBodyPartError(withReason reason: AFError.MultipartEncodingFailureReason) {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering setBodyPartError(reason=\(reason))\n".utf8))
        guard bodyPartError == nil else { return }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting setBodyPartError(reason=\(reason))\n".utf8))
        bodyPartError = AFError.multipartEncodingFailed(reason: reason)
    }
}

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers

extension MultipartFormData {
    // MARK: - Private - Mime Type

    private func mimeType(forPathExtension pathExtension: String) -> String {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering mimeType(pathExtension=\(pathExtension))\n".utf8))
        if #available(iOS 14, macOS 11, tvOS 14, watchOS 7, visionOS 1, *) {
            return UTType(filenameExtension: pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        } else {
            if
                let id = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue(),
                let contentType = UTTypeCopyPreferredTagWithClass(id, kUTTagClassMIMEType)?.takeRetainedValue() {
				FileHandle.standardError.write(Data("[ERROR] mimeType(pathExtension=\(pathExtension)): id → \(id)\n".utf8))
                return contentType as String
            }

		FileHandle.standardError.write(Data("[WARN] <<< Exiting mimeType(pathExtension=\(pathExtension))\n".utf8))
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
