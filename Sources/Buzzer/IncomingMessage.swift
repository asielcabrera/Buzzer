//
//  IncomingMessage.swift
//  Buzzer
//
//  Created by Asiel Cabrera Gonzalez on 29/10/21.
//

import Foundation

import NIOHTTP1

open class IncomingMessage {
    
    public let header   : HTTPRequestHead
    public var userInfo = [ String : Any ]()
    
    init(header: HTTPRequestHead) {
        self.header = header
    }
}
