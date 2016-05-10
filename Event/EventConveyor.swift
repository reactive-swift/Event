//===--- EventConveyor.swift ----------------------------------------------===//
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
    private let _id:NSUUID
    
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

public class EventConveyor<T> : MovableExecutionContextTenantProtocol {
    public typealias Payload = T
    public typealias Handler = Payload->Void
    public typealias SettledTenant = EventConveyor<T>
    
    public let context: ExecutionContextType
    
    public func settle(in context: ExecutionContextType) -> EventConveyor<T> {
        return EventConveyor<Payload>(context: context) { fun in
            self.react { payload in
                fun(payload)
            }
        }
    }
    
    private let _recycle:Off
    private var _handlers:Set<UniqueContainer<(Handler, EventConveyor)>>
    
    private init(context:ExecutionContextType, recycle:Off = {}) {
        self._recycle = recycle
        self._handlers = []
        self.context = context
    }
    
    private convenience init(context:ExecutionContextType, advise:(Payload->Void)->Off) {
        var emit:(Payload)->Void = {_ in}
        
        let off = advise { payload in
            emit(payload)
        }
        self.init(context:context, recycle:off)
        
        emit = { [unowned self](payload) in
            self.emit(payload)
        }
    }
    
    deinit {
        _recycle()
    }
    
    private func emit(payload:Payload) {
        context.immediateIfCurrent {
            for handler in self._handlers {
                handler.content.0(payload)
            }
        }
    }
    
    public func react(f:Handler) -> Off {
        return context.sync {
            let container = UniqueContainer(content: (f, self))
            
            self._handlers.insert(container)
            
            return {
                self._handlers.remove(container)
            }
        }
    }
}

public extension EventConveyor {
    public func map<A>(f:Payload->A) -> EventConveyor<A> {
        return EventConveyor<A>(context: self.context) { fun in
            self.react { payload in
                fun(f(payload))
            }
        }
    }
    
    public func filter(f:Payload->Bool) -> EventConveyor<Payload> {
        return EventConveyor<Payload>(context: self.context) { fun in
            self.react { payload in
                if f(payload) {
                    fun(payload)
                }
            }
        }
    }
}

public extension EventEmitterProtocol {
    public func on<E : EventProtocol>(event: E) -> EventConveyor<E.Payload> {
        return EventConveyor<E.Payload>(context: self.context) { fun in
            self.on(event, handler: fun)
        }
    }
}