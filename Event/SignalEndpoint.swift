//===--- SignalEndpoint.swift ----------------------------------------------===//
//Copyright (c) 2016 Crossroad Labs s.r.o.
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at
//
//http://www.apache.org/licenses/LICENSE-2.0
//
//Unless required by applicable law or agreed to in writing, software
//distributed under the License is distributed on an "AS IS" BASIS,
//WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//See the License for the specific language governing permissions and
//limitations under the License.
//===----------------------------------------------------------------------===//

import Foundation

public protocol SignalEndpoint {
    associatedtype Payload
    
    func consume(payload:Payload)
}

public extension SignalStreamProtocol {
    public func pour<SE : SignalEndpoint>(to endpoint: SE) -> Off where SE.Payload == Payload {
        return self.react(endpoint.consume)
    }
}

public extension SignalEndpoint {
    public func subscribe<SS : SignalStreamProtocol>(to stream: SS) -> Off where SS.Payload == Payload {
        return stream.react(self.consume)
    }
}

public class SignalReactor<T> : SignalEndpoint {
    let _f: (Payload)->Void
    
    public init(_ f: @escaping (Payload)->Void) {
        self._f = f
    }
    
    public typealias Payload = T
    
    public func consume(payload:Payload) {
        _f(payload)
    }
}

//infix operator <= : ComparisonPrecedence
infix operator => : ComparisonPrecedence

public extension SignalEndpoint {
    public static func <=(endpoint:Self, payload:Payload?) {
        if let payload = payload {
            endpoint.consume(payload: payload)
        }
    }
    
    public static func =>(payload:Payload?, endpoint:Self) {
        endpoint <= payload
    }
}
