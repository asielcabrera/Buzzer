import Foundation
import NIO
import NIOHTTP1

public struct Buzzer {
    public private(set) var text = "Hello, World!"

    public init() {
    }
}

let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

public class Buzz: Router {
    
    public override init() {}
    
    public func listen(_ port: Int) {
        let reuseAddrOpt = ChannelOptions.socket(
            SocketOptionLevel(SOL_SOCKET),
            SO_REUSEADDR)
        
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(reuseAddrOpt, value: 1)
        
            .childChannelInitializer({ channel in
                channel.pipeline.configureHTTPServerPipeline()
                    .flatMap { _ in
                        channel.pipeline.addHandler(BuzzHandler(router: self))
                    }
            })
        
            .childChannelOption(ChannelOptions.socket(
                IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(reuseAddrOpt, value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead,
                                value: 1)
        
        do {
            let defaultHost = "127.0.0.1"
            let serverChannel =
            try bootstrap.bind(host: defaultHost, port: port)
                .wait()
            print("Server running on:", serverChannel.localAddress!)
            
            try serverChannel.closeFuture.wait() // runs forever
        }
        catch {
            fatalError("failed to start server: \(error)")
        }
    }
}

final class BuzzHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart
    
    public var router : Router
    
    public init(router: Router) {
        self.router = router
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let header):
            let req = IncomingMessage(header: header)
            let res = BuzzerServerResponse(channel: context.channel)
            
            router.handle(request: req, response: res) {
                (items : Any...) in // the final handler
                res.status = .notFound
                res.send("No middleware handled the request!")
            }
        case .body, .end: break
        }
    }
}

public enum fs {
    
    static let threadPool: NIOThreadPool = {
        let tp = NIOThreadPool(numberOfThreads: 4)
        tp.start()
        return tp
    }()
    
    static let fileIO = NonBlockingFileIO(threadPool: threadPool)
    
    public static
    func readFile(_ path    : String,
                  eventLoop : EventLoop? = nil,
                  maxSize   : Int = 1024 * 1024,
                  _ cb: @escaping ( Error?, ByteBuffer? ) -> ())
    {
        let eventLoop = eventLoop
        ?? MultiThreadedEventLoopGroup.currentEventLoop
        ?? group.next()
        
        func emit(error: Error? = nil, result: ByteBuffer? = nil) {
            if eventLoop.inEventLoop { cb(error, result) }
            else { eventLoop.execute { cb(error, result) } }
        }
        
        threadPool.submit {
            assert($0 == .active, "unexpected cancellation")
            
            let fh : NIOFileHandle
            do { // Blocking:
                fh = try NIOFileHandle(path: path)
            }
            catch { return emit(error: error) }
            
            fileIO.read(fileHandle : fh, byteCount: maxSize,
                        allocator  : ByteBufferAllocator(),
                        eventLoop  : eventLoop)
                .map         { try? fh.close(); emit(result: $0) }
                .whenFailure { try? fh.close(); emit(error:  $0) }
        }
    }
}

