//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import XCTest
@testable import NIO
@testable import NIOHTTP1

private extension ByteBuffer {
    func assertContainsOnly(_ string: String) {
        let innerData = self.string(at: self.readerIndex, length: self.readableBytes)!
        XCTAssertEqual(innerData, string)
    }
}

class HTTPEncoderTests: XCTestCase {
    private func sendResponse(withStatus status: HTTPResponseStatus, andHeaders headers: HTTPHeaders) -> ByteBuffer {
        let channel = EmbeddedChannel()
        defer {
            XCTAssertFalse(try! channel.finish())
        }

        try! channel.pipeline.add(handler: HTTPResponseEncoder(allocator: channel.allocator)).wait()
        var switchingResponse = HTTPResponseHead(version: HTTPVersion(major: 1, minor:1), status: status)
        switchingResponse.headers = headers
        try! channel.writeOutbound(data: HTTPResponsePart.head(switchingResponse))
        return channel.readOutbound()!
    }

    func testNoAutoHeadersFor101() throws {
        let writtenData = sendResponse(withStatus: .switchingProtocols, andHeaders: HTTPHeaders())
        writtenData.assertContainsOnly("HTTP/1.1 101 Switching Protocols\r\n\r\n")
    }

    func testNoAutoHeadersForCustom1XX() throws {
        let headers = HTTPHeaders([("Link", "</styles.css>; rel=preload; as=style")])
        let writtenData = sendResponse(withStatus: .custom(code: 103, reasonPhrase: "Early Hints"), andHeaders: headers)
        writtenData.assertContainsOnly("HTTP/1.1 103 Early Hints\r\nlink: </styles.css>; rel=preload; as=style\r\n\r\n")
    }

    func testNoAutoHeadersFor204() throws {
        let writtenData = sendResponse(withStatus: .noContent, andHeaders: HTTPHeaders())
        writtenData.assertContainsOnly("HTTP/1.1 204 No Content\r\n\r\n")
    }

    func testNoContentLengthHeadersFor101() throws {
        let headers = HTTPHeaders([("content-length", "0")])
        let writtenData = sendResponse(withStatus: .switchingProtocols, andHeaders: headers)
        writtenData.assertContainsOnly("HTTP/1.1 101 Switching Protocols\r\n\r\n")
    }

    func testNoContentLengthHeadersForCustom1XX() throws {
        let headers = HTTPHeaders([("Link", "</styles.css>; rel=preload; as=style"), ("content-length", "0")])
        let writtenData = sendResponse(withStatus: .custom(code: 103, reasonPhrase: "Early Hints"), andHeaders: headers)
        writtenData.assertContainsOnly("HTTP/1.1 103 Early Hints\r\nlink: </styles.css>; rel=preload; as=style\r\n\r\n")
    }

    func testNoContentLengthHeadersFor204() throws {
        let headers = HTTPHeaders([("content-length", "0")])
        let writtenData = sendResponse(withStatus: .noContent, andHeaders: headers)
        writtenData.assertContainsOnly("HTTP/1.1 204 No Content\r\n\r\n")
    }

    func testNoTransferEncodingHeadersFor101() throws {
        let headers = HTTPHeaders([("transfer-encoding", "chunked")])
        let writtenData = sendResponse(withStatus: .switchingProtocols, andHeaders: headers)
        writtenData.assertContainsOnly("HTTP/1.1 101 Switching Protocols\r\n\r\n")
    }

    func testNoTransferEncodingHeadersForCustom1XX() throws {
        let headers = HTTPHeaders([("Link", "</styles.css>; rel=preload; as=style"), ("transfer-encoding", "chunked")])
        let writtenData = sendResponse(withStatus: .custom(code: 103, reasonPhrase: "Early Hints"), andHeaders: headers)
        writtenData.assertContainsOnly("HTTP/1.1 103 Early Hints\r\nlink: </styles.css>; rel=preload; as=style\r\n\r\n")
    }

    func testNoTransferEncodingHeadersFor204() throws {
        let headers = HTTPHeaders([("transfer-encoding", "chunked")])
        let writtenData = sendResponse(withStatus: .noContent, andHeaders: headers)
        writtenData.assertContainsOnly("HTTP/1.1 204 No Content\r\n\r\n")
    }
}
