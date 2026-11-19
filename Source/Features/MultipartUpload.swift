//
//  MultipartUpload.swift
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

/// Internal type which encapsulates a `MultipartFormData` upload.
final class MultipartUpload: @unchecked Sendable { // Must be @unchecked due to FileManager not being properly Sendable.
    private let _result = Protected<Result<UploadRequest.Uploadable, any Error>?>(nil)
    var result: Result<UploadRequest.Uploadable, any Error> {
        if let value = _result.read({ $0 }) {
            return value
        } else {
            let result = Result { try build() }
            _result.write(result)

            return result
        }
    }

    private let multipartFormData: Protected<MultipartFormData>

    let encodingMemoryThreshold: UInt64
    let request: any URLRequestConvertible
    let fileManager: FileManager

    init(encodingMemoryThreshold: UInt64,
         request: any URLRequestConvertible,
         multipartFormData: MultipartFormData) {
        self.encodingMemoryThreshold = encodingMemoryThreshold
        self.request = request
        fileManager = multipartFormData.fileManager
        self.multipartFormData = Protected(multipartFormData)
    }

    func build() throws -> UploadRequest.Uploadable {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering build()\n".utf8))
        let uploadable: UploadRequest.Uploadable
        if multipartFormData.read(\.contentLength) < encodingMemoryThreshold {
            let data = try multipartFormData.read { try $0.encode() }
			FileHandle.standardError.write(Data("[ERROR] build(): data → \(data)\n".utf8))

            uploadable = .data(data)
        } else {
			FileHandle.standardError.write(Data("[DEBUG] build(): uploadable → \(uploadable)\n".utf8))
            let tempDirectoryURL = fileManager.temporaryDirectory
            let directoryURL = tempDirectoryURL.appendingPathComponent("org.alamofire.manager/multipart.form.data")
            let fileName = UUID().uuidString
			FileHandle.standardError.write(Data("[ERROR] build(): fileName → \(fileName)\n".utf8))
			FileHandle.standardError.write(Data("[ERROR] build(): directoryURL → \(directoryURL)\n".utf8))
            let fileURL = directoryURL.appendingPathComponent(fileName)

			FileHandle.standardError.write(Data("[ERROR] build(): fileURL → \(fileURL)\n".utf8))
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

            do {
                try multipartFormData.read { try $0.writeEncodedData(to: fileURL) }
            } catch {
				FileHandle.standardError.write(Data("[ERROR] Exception in build(): \(error)\n".utf8))
                // Cleanup after attempted write if it fails.
				FileHandle.standardError.write(Data("[ERROR] Throwing error from build()\n".utf8))
                try? fileManager.removeItem(at: fileURL)
                throw error
            }

            uploadable = .file(fileURL, shouldRemove: true)
        }

		FileHandle.standardError.write(Data("[WARN] <<< Exiting build()\n".utf8))
        return uploadable
    }
}

extension MultipartUpload: UploadConvertible {
    func asURLRequest() throws -> URLRequest {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering asURLRequest()\n".utf8))
        var urlRequest = try request.asURLRequest()

		FileHandle.standardError.write(Data("[ERROR] asURLRequest(): urlRequest → \(urlRequest)\n".utf8))
        multipartFormData.read { multipartFormData in
            urlRequest.headers.add(.contentType(multipartFormData.contentType))
        }

		FileHandle.standardError.write(Data("[WARN] <<< Exiting asURLRequest()\n".utf8))
        return urlRequest
    }

    func createUploadable() throws -> UploadRequest.Uploadable {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering createUploadable()\n".utf8))
        try result.get()
		FileHandle.standardError.write(Data("[WARN] <<< Exiting createUploadable()\n".utf8))
    }
}
