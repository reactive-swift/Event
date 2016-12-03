//===--- EventEmitter.swift ----------------------------------------------===//
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

import Boilerplate
import ExecutionContext

internal struct Listener {
    internal let _id:NSUUID
    internal let listener:(Signal<Any>)->Void
    internal let event:HashableContainer
    
    internal init<Payload>(event:HashableContainer, listener:@escaping (Signal<Payload>)->Void) {
        self._id = NSUUID()
        self.event = event
        self.listener = { signature, payload in
            guard let payload = payload as? Payload else {
                return
            }
            
            listener((signature, payload))
        }
    }
}

extension Listener : Hashable {
    internal var hashValue: Int {
        get {
            return self._id.hashValue
        }
    }
}

internal func ==(lhs:Listener, rhs:Listener) -> Bool {
    return lhs._id == rhs._id
}

public protocol EventEmitter : AnyObject, ExecutionContextTenantProtocol, SignatureProvider {
    var dispatcher:EventDispatcher {get}
}

public extension EventEmitter {
    public var signature: Int {
        get {
            return dispatcher.signature
        }
    }
}

public typealias Off = ()->Void

public extension EventEmitter {
    internal func on<E : Event>(_ event: E, handler:@escaping (Signal<E.Payload>)->Void) -> Off {
        let listener = dispatcher.addListener(event: event, context: context, handler: handler)
        return { [weak self]()->Void in
            self?.dispatcher.removeListener(listener: listener, context: self!.context)
        }
    }
    
    public func emit<E : Event>(_ event: E, payload:E.Payload, signature:Set<Int> = []) {
        dispatcher.dispatch(event, context: context, payload: payload, signature: signature)
    }
}

public struct HashableContainer : Hashable {
    private let _hash:Int
    internal let _equator:(Any)->Bool
    public let value:Any
    
    public init<T: Hashable>(hashable:T) {
        self._hash = hashable.hashValue
        self._equator = { other in
            guard let other = other as? T else {
                return false
            }
            return hashable == other
        }
        self.value = hashable
    }
    
    public var hashValue: Int {
        get {
            return self._hash
        }
    }
}

public func ==(lhs:HashableContainer, rhs:HashableContainer) -> Bool {
    return lhs._equator(rhs.value)
}

public class EventDispatcher : SignatureProvider {
    private var registry:Dictionary<HashableContainer,Set<Listener>> = [:]
    
    public init() {
    }
    
    internal func addListener<E : Event>(event: E, context:ExecutionContextProtocol, handler:@escaping (Signal<E.Payload>)->Void) -> Listener {
        return context.sync {
            let container = HashableContainer(hashable: event)
            let listener = Listener(event: container, listener: handler)
            
            if self.registry[container] == nil {
                self.registry[container] = Set()
            }
            
            self.registry[container]?.insert(listener)
            
            return listener
        }
    }
    
    internal func removeListener(listener:Listener, context:ExecutionContextProtocol) {
        context.immediateIfCurrent {
            let _ = self.registry[listener.event]?.remove(listener)
        }
    }
    
    internal func dispatch<E : Event>(_ event:E, context:ExecutionContextProtocol, payload:E.Payload, signature:Set<Int>) {
        let sig = self.signature
        
        if signature.contains(sig) {
            return
        }
        
        var sigset = signature
        sigset.insert(sig)
        
        context.immediateIfCurrent {
            let container = HashableContainer(hashable: event)
            
            if let listeners = self.registry[container] {
                for listener in listeners {
                    listener.listener((sigset, payload))
                }
            }
        }
    }
}
