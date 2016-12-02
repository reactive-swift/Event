//===--- SignalNode.swift ----------------------------------------------===//
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

import ExecutionContext

public protocol SignalNodeProtocol : SignalStreamProtocol, SignalEndpoint {
}

open class SignalNode<T> : SignalStream<T>, SignalNodeProtocol {
    public init(context: ExecutionContextProtocol = ExecutionContext.current) {
        super.init(context: context, recycle: {})
    }
    
    public func signal(signature:Set<Int>, payload:Payload) {
        self.emit(signal: (signature, payload))
    }
}

public extension SignalNodeProtocol {
    public func emit(payload:Payload) {
        self <= payload
    }
}

public extension SignalNodeProtocol {
    public func bind<SN : SignalNodeProtocol>(to node: SN) -> Off where SN.Payload == Payload {
        let forth = pour(to: node)
        let back = subscribe(to: node)
        
        return {
            forth()
            back()
        }
    }
}
