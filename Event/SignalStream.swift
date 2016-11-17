//===--- SignalStream.swift ----------------------------------------------===//
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

internal struct UniqueContainer<T> {
    internal let _id:NSUUID
    
    let content:T
    
    init(content:T) {
        self._id = NSUUID()
        self.content = content
    }
}

extension UniqueContainer : Hashable {
    internal var hashValue: Int {
        get {
            return self._id.hashValue
        }
    }
}

internal func ==<T>(lhs:UniqueContainer<T>, rhs:UniqueContainer<T>) -> Bool {
    return lhs._id == rhs._id
}

public class SignalStream<T> : MovableExecutionContextTenantProtocol {
    public typealias Payload = T
    public typealias Handler = (Payload)->Void
    public typealias SettledTenant = SignalStream<T>
    
    public let context: ExecutionContextProtocol
    
    public func settle(in context: ExecutionContextProtocol) -> SignalStream<T> {
        return SignalStream<Payload>(context: context) { fun in
            self.react { payload in
                fun(payload)
            }
        }
    }
    
    private let _recycle:Off
    private var _handlers:Set<UniqueContainer<(Handler, SignalStream)>>
    
    internal init(context:ExecutionContextProtocol, recycle:@escaping Off) {
        self._recycle = recycle
        self._handlers = []
        self.context = context
    }
    
    internal convenience init(context:ExecutionContextProtocol, advise:(@escaping (Payload)->Void)->Off) {
        var emit:(Payload)->Void = {_ in}
        
        let off = advise { payload in
            emit(payload)
        }
        self.init(context:context, recycle:off)
        
        emit = { [unowned self](payload) in
            self.emit(payload: payload)
        }
    }
    
    deinit {
        _recycle()
    }
    
    internal func emit(payload:Payload) {
        context.immediateIfCurrent {
            for handler in self._handlers {
                handler.content.0(payload)
            }
        }
    }
    
    public func react(_ f:@escaping Handler) -> Off {
        return context.sync {
            let container = UniqueContainer(content: (f, self))
            
            self._handlers.insert(container)
            
            return {
                self._handlers.remove(container)
            }
        }
    }
}

public extension SignalStream {
    public func map<A>(_ f:@escaping (Payload)->A) -> SignalStream<A> {
        return SignalStream<A>(context: self.context) { fun in
            self.react { payload in
                fun(f(payload))
            }
        }
    }
    
    public func filter(_ f:@escaping (Payload)->Bool) -> SignalStream<Payload> {
        return SignalStream<Payload>(context: self.context, advise: { fun in
            self.react { payload in
                if f(payload) {
                    fun(payload)
                }
            }
        })
    }
}

public extension EventEmitter {
    public func on<E : Event>(_ event: E) -> SignalStream<E.Payload> {
        return SignalStream<E.Payload>(context: self.context) { fun in
            self.on(event, handler: fun)
        }
    }
}
