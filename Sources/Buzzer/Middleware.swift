//
//  Middleware.swift
//  Buzzer
//
//  Created by Asiel Cabrera Gonzalez on 29/10/21.
//

import Foundation

public typealias Next = ( Any... ) -> Void

public typealias Middleware =
( IncomingMessage,
  BuzzerServerResponse,
  @escaping Next ) -> Void
