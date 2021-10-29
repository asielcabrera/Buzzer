import Foundation
import NIO
import NIOHTTP1

public struct Buzzer {
    public private(set) var text = "Hello, World!"

    public init() {
    }
}

let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

open class Buzz: Router {
    
    public override init() {}
    
    open func listen(_ port: Int) {
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
