//
//  BuzzerServerResponse.swift
//  Buzzer
//
//  Created by Asiel Cabrera Gonzalez on 29/10/21.
//

import Foundation
import NIO
import NIOHTTP1

open class BuzzerServerResponse {
    
    public var status = HTTPResponseStatus.ok
    public var headers = HTTPHeaders()
    private var didWriteHeader = false
    private var didEnd = false
    
    public var channel: Channel
    
    public init(channel: Channel) {
        self.channel = channel
    }
    
    open func send(_ data: String) {
        
        flushHeader()
        
        var buffer = channel.allocator.buffer(capacity: data.count)
        buffer.writeString(data)
        let part = HTTPServerResponsePart.body(.byteBuffer(buffer))
        
        _ = channel.writeAndFlush(part)
            .flatMapError(handleError)
            .map { self.end() }
    }
    
    private func flushHeader() {
        guard !didWriteHeader else { return } // done already
        didWriteHeader = true
        
        let head = HTTPResponseHead(version: .init(major:1, minor:1),
                                    status: status, headers: headers)
        let part = HTTPServerResponsePart.head(head)
        _ = channel.writeAndFlush(part)
            .flatMapError(handleError)
    }
    
    private func handleError(_ error: Error) -> EventLoopFuture<Void>{
        print("ERROR:", error)
        end()
        return error as! EventLoopFuture<Void>
    }
    
    public func end() {
        guard !didEnd else { return }
        didEnd = true
        _ = channel.writeAndFlush(HTTPServerResponsePart.end(nil))
            .map { self.channel.close() }
    }
}
public extension BuzzerServerResponse {
    
    /// A more convenient header accessor. Not correct for
    /// any header.
    subscript(name: String) -> String? {
        set {
            assert(!didWriteHeader, "header is out!")
            if let v = newValue {
                headers.replaceOrAdd(name: name, value: v)
            }
            else {
                headers.remove(name: name)
            }
        }
        get {
            return headers[name].joined(separator: ", ")
        }
    }
}

public extension BuzzerServerResponse {
    
    /// Send a Codable object as JSON to the client.
    func json<T: Encodable>(_ model: T) {
        // create a Data struct from the Codable object
        let data : Data
        do {
            data = try JSONEncoder().encode(model)
            // setup JSON headers
            self["Content-Type"]   = "application/json"
            self["Content-Length"] = "\(data.count)"
            
            // send the headers and the data
            flushHeader()
            
            var buffer = channel.allocator.buffer(capacity: data.count)
            buffer.writeBytes(data)
            let part = HTTPServerResponsePart.body(.byteBuffer(buffer))
            
            _ = channel.writeAndFlush(part)
                .flatMapError(handleError)
                .map { self.end() }
        }
        catch {
            _ = handleError(error)
        }
    }
}



public extension BuzzerServerResponse {
    
    func render(pathContext : String = #file,
                _ template: String, _ options : Any? = nil)
    {
//        let res = self
        
        // Locate the template file
//        let path = self.path(to: template, ofType: "mustache", in: pathContext) ?? "/dummyDoesNotExist"
        
        //         Read the template file
        //                fs.readFile(path) { err, data in
        //                    guard let data = data else {
        //                        res.status = .internalServerError
        //                        return res.send("Error: \(err as Optional)")
        //                    }
        //
        //                    data.write(bytes: [0]) // cstr terminator
        //
        //                    // Parse the template
        //                    let parser = MustacheParser()
        //                    let tree   : MustacheNode = data.withUnsafeReadableBytes {
        //                        let ba  = $0.baseAddress!
        //                        let bat = ba.assumingMemoryBound(to: CChar.self)
        //                        return parser.parse(cstr: bat)
        //                    }
        //
        //                    // Render the response
        //                    let result = tree.render(object: options)
        //
        //                    // Deliver
        //                    res["Content-Type"] = "text/html"
        //                    res.send(result)
        //                }
    }
    
    private func path(to resource: String, ofType: String,
                      in pathContext: String) -> String?
    {
#if os(iOS) && !arch(x86_64) // iOS support, FIXME: blocking ...
        return Bundle.main.path(forResource: template, ofType: "mustache")
#else
        var url = URL(fileURLWithPath: pathContext)
        url.deleteLastPathComponent()
        url.appendPathComponent("templates", isDirectory: true)
        url.appendPathComponent(resource)
        url.appendPathExtension("mustache")
        return url.path
#endif
    }
}
